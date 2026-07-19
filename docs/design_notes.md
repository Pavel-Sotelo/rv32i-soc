# Design Notes

Design decisions for each module.

## ALU

- **Internal 4-bit `alu_opcode`, encoded as `{funct7[5], funct3}`.** ADD/SUB share a
  funct3 (`000`) and SRL/SRA share a funct3 (`101`), so 3 bits can't separate
  them — the one differing funct7 bit is needed as a tiebreaker. Rather than
  inventing an arbitrary code, the op is the ISA's own fields passed through,
  which keeps the decoder nearly free (no translation table) and makes the RTL
  traceable to the spec. Mapping funct3/funct7 to `alu_opcode` is the decoder's
  job, not the ALU's.

- **Pure combinational, no clock, no flags register.** RV32I has no condition-code
  register — branches compare directly — so no zero/carry flags are generated.

- **Shift amount uses only `b[4:0]`.** A 32-bit operand has only 32 shift positions
  (0–31), which needs exactly 5 bits; the upper bits of `b` are ignored (free in
  hardware). Shift amount therefore wraps mod 32 — shift by 32 == shift by 0,
  leaving the operand unchanged (not zeroed). Tested as a corner case.

- **Signedness applied per-operation, not globally.** Only SLT and SRA read `a`/`b`
  as signed (`$signed`); SLTU and SRL are unsigned; ADD/SUB/AND/OR/XOR/SLL are
  sign-neutral (two's-complement makes the interpretation irrelevant). Overflow is
  ignored per spec — ADD/SUB keep the low 32 bits; no exception is raised.

- **Unused op codes return 0 via `default`.** Six of the sixteen 4-bit codes are
  unassigned; they produce 0 rather than X, keeping the output defined for any input.

## Register File

- **x0 forced at read, not write.** The zero guarantee lives at the observation
  point (the read port), so a stray or buggy write to slot 0 can never corrupt
  x0's behavior.

- **Flip-flops, not BRAM.** Needs 3 simultaneous accesses per cycle (2 read + 1
  write); BRAM offers only 2 ports, so BRAM is physically incapable. Constraint,
  not preference.

- **Synchronous reset that zeros the array.** Chosen for clean waveforms and
  co-simulation, not required for correctness — programs always write a register
  before reading it. Documented as a deliberate choice.

- **Combinational read + non-blocking write means a same-cycle read of the
  register being written returns the OLD value;** the new value lands one cycle
  later. This is the read-during-write hazard that forwarding addresses in the
  pipeline (Step 8).

## Instruction Memory

- **BRAM storage, not flip-flops.** 256 words x 32 bits would cost ~8,000
  flip-flops out of ~40,000 on the Artix-7 — too large a share of the chip for
  one memory. BRAM stores it in dedicated blocks at zero flip-flop cost. The
  same size argument as the register file, but the opposite conclusion, because
  the access pattern differs (see below).

- **Synchronous read — a consequence of BRAM, not a preference.** BRAM's output
  is registered by construction (the SRAM read result is sensed, regenerated to
  full strength, and captured in an output register). So the instruction appears
  one cycle after the address is presented. This 1-cycle latency is absorbed by
  the fetch pipeline stage. The registered output also keeps the combinational
  path short, which helps Fmax.

- **Why BRAM here but flip-flops for the register file.** Instruction memory
  needs only one access per cycle (a single fetch) and tolerates 1-cycle
  latency, so BRAM fits. The register file needs three simultaneous accesses
  (2 reads + 1 write) and combinational reads — BRAM offers only 2 ports and
  cannot read combinationally, so it must be flip-flops. Two independent reasons
  push each memory to opposite implementations.

- **BRAM is inferred, not instantiated.** The module describes a clocked read of
  a memory array; the synthesis tool recognizes that pattern and maps it onto a
  BRAM block. No vendor primitive or IP is instantiated, which keeps the design
  portable. (Explicit instantiation via the Block Memory Generator or xpm_memory
  is possible but was deliberately avoided for portability.)

- **Byte address to word index (`addr[9:2]`).** The PC counts in bytes (0, 4, 8,
  12...) because instructions are 4 bytes apart; the memory array is indexed by
  word (0, 1, 2, 3...). Converting means dropping the bottom 2 bits of the
  address — they are always 00 for aligned instructions and carry no
  information. This is a division by 4 that costs nothing in hardware (just wire
  up the upper bits). For 256 words the index is 8 bits: `addr[9:2]` (start at
  bit 2 to drop the byte offset, 8 bits wide to reach 256 words).

- **No reset.** It is a ROM: it comes up pre-loaded with the program via
  `$readmemh` before cycle 0. A reset that cleared the array would destroy the
  program, so there is no reset port. (The register file needed a reset because
  it is working storage that starts empty; instruction memory starts full.)

- **Program loaded with `$readmemh` in an `initial` block.** The program is a
  hex text file (one 32-bit instruction per line); `$readmemh` reads it into the
  array at time 0 — line 1 to slot 0, line 2 to slot 1, and so on. `initial`
  fits because loading is a one-time setup action. This works in both simulation
  and synthesis (it sets the BRAM's power-up contents on the FPGA).

- **Parameterized program filename (`parameter string PROGRAM`).** The hex
  filename is a module parameter with a default, so a testbench can load a
  different program without editing the module. The testbench instantiated the
  module with the same default program, so no override was needed this time,
  but the parameter is there so future testbenches can load different programs
  without touching the module.

## Instruction Set Simulator (ISS)

The ISS is a C reference model of the same CPU: the identical fetch/decode/execute
loop expressed in software instead of hardware. Its purpose is to be a *golden
model* — a trusted answer key that the RTL can be compared against, instruction by
instruction, during co-simulation (Step 7). It is deliberately slow and
inspectable rather than fast, because a reference model's value is trustworthiness,
not speed.

- **`uint32_t` for registers and instructions, not `int`.** `int` has no
  guaranteed width, but RV32I registers are exactly 32 bits. Exact-width types
  make the ISS wrap and truncate identically to the hardware. Unsigned is used
  because unsigned overflow is well-defined in C (wraps mod 2^32, exactly like
  bits falling off a register), while signed overflow is undefined behavior — a
  reference model that could vary by compiler or optimization level would be
  worthless.

- **Signedness applied per-operation, not globally.** Registers store raw bits as
  `uint32_t`; only the operations that need signed interpretation cast at the
  point of use — `(int32_t)` for SLT/SLTI and for SRA/SRAI's arithmetic shift.
  This is the same rule as the ALU: the bits are neutral, the instruction decides
  how to read them.

- **C has one `>>`; SystemVerilog has two.** SystemVerilog distinguishes `>>`
  (logical) from `>>>` (arithmetic). C has only `>>`, and which behavior you get
  depends on the operand's type — unsigned shifts in zeros, signed shifts in the
  sign bit. So SRL/SRLI shift the `uint32_t` directly, and SRA/SRAI cast to
  `int32_t` first.

- **Immediates are sign-extended in decode, once.** `(int32_t)instruction >> 20`
  extracts bits 31:20 and sign-extends in a single operation: the cast makes the
  shift arithmetic, so the vacated top bits are filled with copies of bit 31. This
  works because RISC-V deliberately places every immediate's sign bit at bit 31 —
  the ISA is designed so sign extension is free. No mask is applied afterward, as
  that would erase the extension. `imm` is stored as `int32_t`; SLTIU casts it
  back to unsigned, matching the spec's "sign-extend first, compare unsigned".

- **Shift amounts masked to 5 bits.** Both register-sourced (R-type) and
  immediate-sourced (I-type) shift amounts are masked with `& 0x1F`, mirroring the
  ALU's `b[4:0]`. For I-type shifts this also isolates the shift amount from the
  upper immediate bits, which RISC-V reuses as a funct7-equivalent to distinguish
  SRLI from SRAI.

- **x0 enforced centrally, once per instruction.** Rather than guarding every
  write site (which would need a duplicated check in each execute path and would
  break instructions whose side effects matter even when rd is x0), `regs[0]` is
  reset to zero at the end of each loop iteration. Different mechanism from the
  RTL (which forces it at the read port) but the same guarantee, and it covers
  every instruction path automatically.

- **PC incremented before execute.** The default next PC is PC+4, applied before
  the execute step, so a branch or jump can simply overwrite `pc` and have its
  write win. This mirrors the hardware, where PC+4 is the default and control-flow
  instructions override it.

- **State zero-initialized at startup (`CPUState cpu_state = {0}`).** C gives no
  guarantee about uninitialized memory, so registers would otherwise hold stack
  garbage — the software equivalent of the X's the RTL register file's reset
  exists to eliminate. Zeroing the whole struct gives the ISS a known starting
  state.

- **Instruction cap as a diagnostic.** Execution stops after a fixed number of
  instructions and reports the count and PC. Once branches exist, a buggy program
  can loop forever; without a cap the ISS simply hangs and teaches nothing. The
  cap converts a hang into a message that says where it was spinning.

- **Decode grouped by format, execute dispatched by opcode.** Several opcodes
  share the I-type layout (0x03 loads and 0x13 immediate arithmetic slice
  identically), so they share one decode routine via fall-through case labels.
  Execute then switches on the opcode separately, because those same fields drive
  completely different behavior. This reflects the ISA: the opcode picks the
  format for decode, and the instruction family for execute.
