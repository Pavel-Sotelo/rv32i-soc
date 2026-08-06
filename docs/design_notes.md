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

## PC (Program Counter)

- **Reset is a must here, unlike instruction memory.** The PC is a flip-flop with
  no other initialization path — at power-up it holds garbage, and the CPU would
  fetch from a random address. Instruction memory needs no reset because `$readmemh`
  loads it before cycle 0; the PC has no equivalent, so reset is the only way it
  gets a defined starting value (byte address 0, the first instruction).

- **Synchronous reset.** The clock always runs on the FPGA and reset comes from a
  button, not a power-on condition, so a synchronous reset is sufficient. It keeps
  timing analysis simple (reset is just another synchronous input) and avoids the
  asynchronous de-assert metastability problem. Consistent with the register file.

- **Pure register, no adder or mux inside.** The PC only stores whatever address it
  is given; computing the next address (PC+4 vs. a branch/jump target) lives in the
  fetch stage above it. Same separation as the ALU, which doesn't contain the mux
  selecting its own operands. This keeps the PC trivially testable in isolation —
  drive a value, check it latches.

## IF Stage (Instruction Fetch)

- **Contains the PC, the +4 adder, the target mux, and the instruction memory.**
  The fetch loop is closed inside this module: PC output → +4 → mux → PC input, with
  the PC output also driving the memory's address.

- **One selector and one address handle both branches and jumps.** `use_target` and
  `pc_target` are inputs, not something IF computes. IF has no idea what a branch is;
  it is a dumb mux that loads `pc_target` when told to. The decision is made in EX
  (branches compare first, jumps are unconditional) and travels backward to IF,
  because IF is where the PC physically lives and therefore the only place it can be
  written. Branch and jump share these wires because from the PC's point of view they
  are the same action — the conditional/unconditional distinction is resolved upstream.

- **This backward flow is the source of the branch penalty.** By the time EX resolves
  a branch, IF has already fetched the next sequential instruction, which must be
  discarded. In a 3-stage pipeline that costs ~1 cycle — small enough that branch
  prediction is deferred (see the architecture note in the README).

- **`out_current_pc` is registered, not a direct wire.** The instruction arrives one
  cycle after its address is presented (BRAM's registered read), so a combinational
  PC output would be one cycle *ahead* of its instruction — EX would pair an
  instruction with the wrong PC and compute branch targets against it. Registering
  the PC delays it by exactly the memory's latency so the two travel together. This
  is a pipeline register in miniature, built early because IF is otherwise not
  self-consistent.

- **Why the PC (not `next_pc`) is what travels downstream.** Branch and jump targets
  are PC-relative: `target = current_pc + offset`. Using `next_pc` would be circular,
  since that is the value being computed. `jal` also needs `PC+4` as its return
  address, which EX derives from `current_pc`, so one output covers both needs.

- **Startup fill and reset interaction (known quirk).** Reset holds the PC steady but
  does not stop the instruction memory clocking, so the two can drift out of step at
  startup depending on how long reset is asserted. `tb_if_stage` requires an extra
  reset cycle for the address-0 read to be observable before the PC advances;
  `tb_if_id` does not. The RTL is correct in both cases — this is about when the
  first fetch is observable, not about the design. **Root cause of the difference
  between the two testbenches is not yet determined; open item to revisit.** In the
  full pipeline this disappears, because stall control freezes the PC and the memory
  together rather than only the PC (Step 8).

## Control Unit

- **Pure combinational, no clock, no state.** Opcode in, control signals out. It is a
  lookup table implemented in logic: each instruction maps to one fixed configuration
  of the datapath's muxes and enables.

- **The datapath/control split.** Everything else in the design is datapath — things
  that hold, move, or transform data. Control touches no data; it produces the switch
  settings that determine *which paths are active*. This is what makes a fixed
  datapath general-purpose: the same wires and the same ALU run `add` one cycle and
  `lw` the next, because control reconfigures them.

- **Switches on opcode, not format.** Several opcodes share a bit layout but behave
  differently — `0x03` (loads) and `0x13` (immediate arithmetic) are both I-format,
  but only one touches memory. Format determines *layout* (the immediate generator's
  concern); opcode determines *behavior* (the control unit's). One `case` branch per
  opcode, with all instructions in that group sharing the same control signals.

- **`alu_op` is derived, not a constant.** For R-type and I-arithmetic the operation
  comes from the instruction's own fields — `{funct7[5], funct3}` — which is exactly
  the encoding the ALU was designed to take. Every other signal is a fixed value per
  opcode; `alu_op` is the one that varies within a case.

- **Only `funct7[5]` is taken as an input, not all seven bits.** It is the only bit
  that carries information in RV32I (ADD/SUB, SRL/SRA); the rest are always zero.
  Taking one bit matches the ALU's `alu_opcode` encoding and makes the dependency
  explicit.

- **Branches use a fixed SUB, with funct3 passed downstream.** All branches perform
  the same ALU operation (`rs1 - rs2`); funct3 selects the *condition applied to the
  result* (zero for `beq`, non-zero for `bne`), which is evaluated in EX, not in the
  ALU. So unlike arithmetic instructions, funct3 here does not select the ALU
  operation — it selects a post-ALU test, which is why funct3 is an output of ID.

- **`branch` and `jump` are separate signals.** Both ultimately redirect the PC, but
  EX decides them differently: a jump is unconditional, a branch is conditional on
  the comparison. A single signal could not tell EX whether to check a condition.

- **`write_back_src` is 2 bits, not 1.** Three distinct sources can be written to a
  register: the ALU result (arithmetic), the memory value (loads), and `PC+4` (`jal`'s
  return address). `jal`'s return address is computed by the fetch-side adder, not the
  ALU — during a jump the ALU result is the *target*, not the return address — so it
  is genuinely a third source.

- **Safe defaults for unrecognized opcodes.** The `default` case clears `reg_write`,
  `write_mem`, `branch`, and `jump`, so a garbage instruction cannot corrupt register
  or memory state.

- **Deliberately incomplete.** Covers the minimum ISA (R-type, I-arithmetic, LW, SW,
  LUI, BEQ, JAL). `auipc`, `jalr`, and the remaining instruction variants are winter
  work; the module grows alongside the instructions the datapath can actually execute.

## Immediate Generator

- **Switches on format, not opcode** — the mirror image of the control unit. `0x03`
  and `0x13` share one case here because their immediate layouts are identical, even
  though they are separate cases in the control unit.

- **Five different reassembly patterns.** I-type is contiguous (bits 31:20). S-type is
  split in two (31:25 and 11:7) because stores need two source registers occupying the
  middle of the instruction. B-type and J-type are split *and* reordered. U-type is a
  20-bit field that is *positioned* in the upper bits rather than sign-extended.

- **Why the scrambling exists.** RISC-V arranges immediates so the same immediate bit
  tends to come from the same instruction bit across formats. Each bit that changes
  position between formats costs a mux; keeping them consistent means most immediate
  bits are plain wires. The encoding is deliberately harder for humans to read in
  exchange for a smaller, faster decoder — the right trade, since humans read the spec
  once and hardware decodes billions of instructions.

- **The sign bit is always at instruction bit 31, in every format.** Sign extension is
  therefore identical regardless of format — replicate bit 31 — with no
  format-dependent logic. Implemented with the replication operator
  (`{{20{instruction[31]}}, ...}`) rather than relying on signed/unsigned assignment
  rules, which are context-dependent and easy to get subtly wrong.

- **B-type and J-type append an implicit `1'b0`.** Branch and jump targets are always
  even (instructions are 4 bytes apart), so bit 0 of the offset is always zero and is
  not stored. The encoded field holds bits 12:1 (B) or 20:1 (J), and the hardware
  appends the zero — doubling the reachable range at no encoding cost.

- **U-type is positioned, not sign-extended.** `lui` places its 20 bits in bits 31:12
  with the low 12 zeroed, because its purpose is building the upper half of a large
  constant (typically paired with `addi` for the lower 12).

- **R-type has no case.** R-type has no immediate; it falls to the `default` and
  produces zero, which is harmless since the control unit sets `reg_or_imm` to select
  `rs2` for those instructions.

## ID Stage (Instruction Decode)

- **Field slicing lives inline; the control unit and immediate generator are separate
  modules.** Slicing rd/rs1/rs2/funct3/opcode is pure wire tapping with nothing to get
  wrong and nothing worth testing in isolation, so it stays in the wrapper — the same
  reasoning that kept the +4 adder inside `if_stage`. The control unit and immediate
  generator are substantial self-contained logic that each deserve their own
  testbench, so they are separate modules.

- **Every field is extracted unconditionally, even when unused.** An `addi` still
  reads `rs2`; a `sw` still produces an `rd`. Wire taps and register reads are free
  and non-destructive, and gating them would require logic to decide *whether* to
  extract — more hardware than the extraction itself, and a sequential
  decide-then-read dependency that lengthens the critical path. The datapath produces
  every possibility in parallel; the control signals select which ones matter.

- **The register file lives in ID, with WB's write ports exposed as inputs.** It is a
  single shared resource: ID reads it, WB writes it. Placing it in ID keeps the
  timing-critical read local (ID must have operand values ready for EX within the
  cycle), and routes only the write signals backward rather than sending indices
  forward and values back. Instantiating it in both stages would create two separate
  register files — writes in one would be invisible to reads in the other.

- **`wb_rd` is a separate input from the locally sliced `rd`.** In a pipeline they
  belong to different instructions: ID's `rd` is the instruction being decoded, while
  WB's `rd` is an older instruction whose result is now ready. Each instruction's `rd`
  travels forward with it and arrives at the write port alongside its own result.

- **funct3 is an output.** EX needs it to select the branch condition (`beq` vs `bne`),
  since all branches share one ALU operation and differ only in the test applied to
  the result.

- **ID adds no latency.** Field slicing, control generation, immediate generation, and
  register reads are all combinational, so everything ID produces is valid in the same
  cycle the instruction arrives. The only latency in the fetch/decode path is the
  instruction memory's one-cycle read.

---

## Data Memory

- **Word-wide array (`[31:0] mem[256]`), while the ISS uses a byte array
  (`uint8_t dmem[1024]`).** Same 8192-bit capacity, different organization, and
  observably identical for co-simulation. The ISS is byte-addressed because that
  is what the spec describes and because it forces little-endian assembly to be
  written out explicitly (which is what proved the SW/LW round trip). The RTL is
  word-wide because BRAM has only two ports and cannot deliver four independent
  bytes in a cycle. Each model uses the organization that suits its purpose.

- **Synchronous read — a consequence of BRAM, same as instruction memory.** The
  address is presented in one cycle, `read_data` is valid one clock edge later.
  This latency is not a cost to be hidden: it aligns exactly with the EX→WB
  boundary, so the loaded value arrives at WB in the same cycle the ALU result
  would have. That alignment is what lets one write-back mux serve both.

- **No reset.** A reset that cleared the array would prevent BRAM inference and
  cost thousands of flip-flops. Unwritten locations therefore read as X in
  simulation, which is correct and useful: X on an address that was never
  written is expected, while X on an address that *was* just written is a bug.
  The X is a diagnostic, not noise.

- **Read-first (read-before-write) on a same-address collision.** Both statements
  in the `always_ff` are non-blocking, so on a simultaneous read and write to the
  same word, the read is served from the pre-edge contents and returns the *old*
  value while the write still lands. This is not a coding accident — it is the
  standard Xilinx read-first mode, and it follows from the non-blocking style
  rather than from statement order. Write-first (read-through) would require
  deliberately forwarding the write data to the output.

- **The collision cannot occur in this pipeline anyway.** Both LW and SW perform
  their memory access in EX, so only one instruction touches data memory in any
  cycle. Read-first vs. write-first is therefore unobservable in the current
  design. It is documented because it becomes observable the moment the pipeline
  deepens or a second port is added.

- **No read enable.** The memory reads unconditionally on every edge, including
  for instructions that never touch memory. This is harmless: a plain BRAM has no
  side effects on read, and `write_back_src` already decides whether the value is
  used. Gating the read would duplicate a decision that is already encoded.
  This changes with memory-mapped I/O (a read can pop a FIFO or clear a status
  flag) and with a power budget (gating saves dynamic power) — both arrive with
  AXI4-Lite, and the enable comes back then.

- **Byte address to word index (`addr[9:2]`).** Identical reasoning to instruction
  memory: the ALU produces byte addresses (0, 4, 8, 12...), the array is indexed
  by word. Dropping the low two bits is a free division by four. A consequence
  worth stating: byte addresses 8, 9, 10 and 11 all select word 2, which is
  correct for word-aligned access and is tested as such.

- **Known limits, deliberately accepted.** `addr[9:2]` silently wraps past 1024
  bytes rather than faulting, and alignment is assumed rather than checked.
  Neither matters for the programs this CPU runs; both are winter work, together
  with the byte/halfword variants (LB/LH/SB/SH) that would require lane enables.

---

## EX Stage (Execute)

- **The operand mux sits on ALU input B only.** Input A is always `reg_value_1`;
  `reg_or_imm` selects between `reg_value_2` and `immediate` on input B. Every
  instruction the datapath currently executes reads rs1 as its first operand, so
  a mux on input A would be hardware with no case that uses it. (It becomes
  necessary for `jal`, where the first operand is the PC — see the branch work.)

- **`alu_second_operand` is a named wire, not an inline expression in the port
  connection.** The mux output costs nothing either way, but a named signal can
  be probed in the waveform while an expression inside a port connection cannot.
  General rule adopted here: anything representing a *decision* — a mux output, a
  computed address, an enable — gets a name; bit slices and constants stay inline.

- **`reg_value_2` bypasses the ALU entirely for stores.** For SW the ALU computes
  the address (`rs1 + imm`) while the value to be stored goes straight from the
  register file to the memory's write port. Two independent uses of the two
  register reads in the same cycle.

- **`read_mem` is generated by the control unit but not routed into EX.** Nothing
  in EX would consume it (see the data memory note on read gating), and an input
  port that nothing reads is noise in every instantiation and every waveform. The
  signal stays in `control_unit`, where it is already tested, and is left
  unconnected until AXI4-Lite needs it. General rule: generate control where
  decode happens, consume it where it is needed, and do not route a signal through
  a module that does not use it.

- **`current_pc` enters EX and stops there; `current_pc_plus_4` passes through.**
  Branch and jump targets are `current_pc + immediate`, computed in EX, so the raw
  PC has no consumer downstream. `PC+4` has one — `jal`'s return address in WB — so
  it continues as a pass-through, alongside `rd`, `reg_write`, and
  `write_back_src`.

- **`data_memory` is instantiated inside EX (for now).** EX is currently its only
  client, so hierarchy matches ownership — the same reasoning that puts the ALU in
  EX, the register file in ID, and instruction memory in IF. The trade-off is that
  co-simulation must reach the array hierarchically
  (`ex_stage_inst.data_memory_inst.d_memory`). Both memories move to the top level
  when AXI4-Lite arrives and memory becomes a bus device shared with peripherals
  rather than private to one stage.

- **There is no MEM stage.** A stage is defined by a pipeline register separating
  two logic blocks; no register sits before the memory access, so memory folds
  into EX and the access completes across the existing EX→WB boundary. A textbook
  5-stage separates MEM because it models memory as asynchronous and slow (a
  teaching simplification — real designs use synchronous SRAM too). Real 5-stage
  CPUs separate it because of cache tag comparison, hit/miss, and way selection,
  which is genuine combinational work. Neither applies here: synchronous BRAM, no
  cache, and the BRAM's own output register supplies the boundary flop. If a cache
  is ever added, MEM comes back.

- **Branch ports are declared but unimplemented.** `funct3`, `branch`, `jump`, and
  `current_pc` are wired and unused. This is sequencing, not oversight: branch
  resolution produces a *backward* signal to IF, so it cannot be built or tested
  until the top module exists and instructions are flowing. Declaring the ports now
  means the branch logic drops in later without rewiring anything.

---

## WB Stage (Write Back)

- **One mux and three wires. No state, no clock, no arithmetic.** WB selects the
  value to write and forwards it, `rd`, and `reg_write` to the register file's
  write port. It is the cheapest stage in the pipeline, and deliberately so —
  everything expensive already happened in EX.

- **Three write-back sources, hence a 2-bit selector.** ALU result (arithmetic and
  `lui`), memory read data (`lw`), and `PC+4` (`jal`'s return address). The third
  is genuinely distinct: during a jump the ALU result is the *target*, not the
  return address, so `PC+4` cannot come from the ALU.

- **`PC+4` is carried from IF, not recomputed in WB.** Both designs are correct and
  cost the same 64 flip-flops, because the PC has to be pipelined forward to WB in
  either case; recomputing adds a second 32-bit adder on top. More important than
  the gate count: the value is computed once at its natural source, so there is no
  second place that can disagree with the first. General rule adopted here —
  compute a value once and route it, rather than recomputing it downstream.

- **The mux runs unconditionally; `reg_write` is not used to gate the value.**
  When `reg_write` is low the register file ignores the write entirely, so forcing
  the data to zero would buy nothing and would hide, in the waveform, which value
  *would* have been written. The enable is a plain pass-through assign.

- **`default` returns X, not 0.** `2'b10` is unassigned in the encoding, so
  reaching it means the control unit is broken. X propagates loudly into the
  register file and shows up immediately in co-simulation; 0 looks like a
  plausible value and hides the fault. In synthesis X means don't-care, so the
  tool optimizes the mux rather than building logic for an unreachable case. Fail
  loud, not silent.

- **No register file inside WB.** It lives in ID, which reads it; WB only drives
  the write port backward. Instantiating it in both places would create two
  independent register files whose contents diverge.

- **WB exists because of loads, and every instruction pays for it.** An ALU result
  is ready at the end of EX; a loaded value is not ready until the start of WB. The
  pipeline is a fixed structure, so an `add` occupies WB for a full cycle to write
  a value that was available one cycle earlier. Pipeline depth is set by the
  longest-latency operation and every instruction pays that cost — the alternative
  is out-of-order completion, which requires write-port arbitration, a reorder
  buffer, and precise-exception machinery. Not worth it at this scale.

---

## Pipeline Registers and Hierarchy

- **Pipeline registers live in the top module; stage modules stay combinational.**
  A pipeline register is a flop on *every* signal crossing a stage boundary, and a
  boundary exists between modules, not inside one. Keeping the two hand-written ones
  in `rv32i_top` puts both boundaries (ID→EX and EX→WB) in a single file where the
  partition is visible at a glance, and leaves each stage independently testable
  with a simple combinational testbench. Production cores go both ways — CV32E40P
  registers stage outputs inside each stage module — so this is a readability
  choice, not a correctness one.

- **Why every crossing signal needs a flop, not just the data.** By the time an
  instruction's result reaches WB, a different instruction occupies EX. A wire
  always shows the present, so an unflopped `rd` would name the *next* instruction's
  destination register — WB would write the right value into the wrong register.
  The same applies to `reg_write` and `write_back_src`: an instruction's control
  information has to travel forward with the instruction itself, and a flip-flop is
  the only mechanism that moves information forward in time.

- **`d_mem_read_data` is the one crossing signal not flopped by hand.** The BRAM's
  built-in output register already provides that flop. The boundary needed by the
  timing budget and the boundary imposed by the memory technology coincide at the
  same place, which is why there is no MEM stage and why the EX→WB crossing costs
  no extra hardware.

- **The flops inside `if_stage` are the IF→ID pipeline register.** `out_current_pc`
  and `out_current_pc_plus_4` are registered so they arrive aligned with
  `instruction`, which the BRAM delivers one cycle after the address. All three
  cross the same boundary; the only difference is who wrote the flop. This was
  first described as "latency alignment, not a pipeline register" — a distinction
  that does not survive scrutiny, since a register separating two stages is a
  pipeline register regardless of which module it sits in.

- **Stage count: four, not three (30 Jul 2026).** The design was first described as
  3-stage (IF/ID, EX, WB) by counting only the pipeline registers written by hand.
  Counting register boundaries gives four stages: the instruction BRAM's output
  register separates IF from ID exactly as the data memory's output register
  separates EX from WB. Either both count or neither does. Consequence: branches
  resolve in EX with two wrongly-fetched instructions behind them, so the penalty
  is 2 cycles, not 1. The measured comparison against a merged ID/EX partition is
  in the README.

- **Flat named signals per boundary, not packed structs.** Each boundary could be one
  `typedef struct packed`, making the flop a single line and adding a signal a
  one-line edit. Flat signals were chosen for bring-up: `id_ex_rd` appears by name in
  the waveform, while `id_ex_q.rd` sits inside a collapsed blob. The cost is 19
  declarations and two verbose `always_ff` branches. Worth revisiting once the design
  stops changing.

- **Three live copies of most signals, so the prefix names the stage.** `id_rd` (the
  combinational output of ID), `id_ex_rd` (the pipeline register), and `ex_rd` all
  exist simultaneously and belong to three different instructions. Naming the
  register after the *boundary* rather than the stage avoids the collision between
  "the flopped value entering EX" and "the value EX produces".

- **Every signal travels only as far as its last consumer.** `current_pc` is flopped
  into EX and stops there — the branch target adder is its only client.
  `current_pc_plus_4` continues to WB for JAL's return address. `instruction` crosses
  only IF→ID and is consumed entirely by decode, so it never enters the pipeline
  registers at all. The rule is "born where, last used where": a signal gets one flop
  per boundary it actually crosses, and none for boundaries another register already
  provides.

- **All pipeline registers reset to zero, though only two need to.** Functionally only
  `reg_write` and `write_mem` require reset — they cause side effects, while the rest
  is data nobody acts on when the enables are low. Everything is reset anyway to keep
  X's out of the waveform during bring-up. This is not free on an Artix-7: a global
  reset net on datapath registers can block flop packing and hurt timing. If reset
  fanout appears in a timing report, the datapath resets come out and the control
  resets stay.

- **`PROGRAM` is a parameter threaded from the testbench down to
  `instruction_memory`.** Running a different program should not require editing RTL.
  A default is kept so `rv32i_top` still elaborates standalone, which is what makes
  schematic inspection and synthesis possible without a wrapper.

---

## Branch and Jump Resolution

- **Branches resolve in EX, giving a 2-cycle penalty.** When the branch resolves,
  wrongly-fetched instructions occupy both ID and IF. Resolving in ID instead would
  cost 1 cycle rather than 2, since only IF would hold a wrong instruction — but it
  lengthens the ID critical path and requires forwarding into ID as well as EX.
  Deferred, and worth revisiting against measured timing.

- **`branch_unit` is a separate module.** The branch conditions are self-contained
  decode logic worth testing in isolation, the same reasoning that made
  `control_unit` and `immediate_generator` separate rather than inline. Field slicing
  stays inline because there is nothing to get wrong; six conditions with signed and
  unsigned variants is not that.

- **The target adder is separate from the ALU, and computes unconditionally.** The
  ALU performs the comparison (SUB), so it cannot also compute `current_pc +
  immediate` in the same cycle. More importantly, using `take_branch` to select the
  ALU's operands would be a combinational loop: the mux would wait on the comparison,
  and the comparison would wait on the mux. The decision and the target are produced
  in parallel; `use_target` only decides whether `if_stage` acts on the target. Same
  pattern as ID extracting every field unconditionally — produce every possibility,
  let control select.

- **`reg_or_imm` must be high for B-type.** Branches compare two registers, so the
  ALU's second operand is `reg_value_2`, not the immediate. This was initially wrong
  and is recorded in the bug log.

- **Only BEQ and BNE are implemented; the other four need a design decision.** Both
  come directly from the SUB result — zero for BEQ, non-zero for BNE — so they cost
  nothing beyond the existing `alu_op`. `blt`/`bge`/`bltu`/`bgeu` cannot be derived
  from the sign bit of `rs1 - rs2`, because the subtraction can overflow: for
  `rs1 = -2147483648`, `rs2 = 1`, the stored result is positive and the sign bit
  reports the wrong ordering. The correct signed test is sign XOR overflow, and the
  unsigned test is the borrow-out — neither of which this ALU exposes. The options
  are to make `alu_op` funct3-dependent (SLT/SLTU already exist and are correct), to
  add a dedicated comparator, or to expose overflow and carry flags. Deferred until
  a program needs them; the demo programs use counted loops, which need only `bne`.

- **The redirect path carries no pipeline register.** `use_target` and `pc_target` run
  from `ex_stage` to `if_stage` combinationally. A flop there would delay the redirect
  by a cycle and grow the penalty from 2 to 3, and the wrongly-fetched instruction
  count with it. Feedback against the pipeline direction is safe here because the PC
  register closes the loop — the same reason the write-back path into `id_stage` is
  not a combinational loop.

- **The flush kills four signals for two consecutive cycles.** `reg_write` and
  `write_mem` are the two that change architectural state; `branch` and `jump` are
  killed alongside them so a squashed instruction cannot itself assert `use_target`
  and redirect the PC to a wrong address. Everything else — the ALU result, the
  immediate, `rd` — flows through as harmless garbage, because nothing acts on it
  once the enables are low.

- **Two cycles, because the wrong instructions arrive at the boundary one cycle
  apart.** When the branch resolves in EX, the instruction behind it is in ID and the
  next one is in IF. The first reaches the ID→EX register on the following edge, the
  second one edge later. A single-cycle gate would catch only the first, so a flag
  registers `use_target` and extends the squash by one cycle.

- **Killing happens at the ID→EX boundary, not later.** `write_mem` is consumed in EX,
  so by WB the memory write has already happened — squashing in WB would be too late
  for stores. Killing at the earliest boundary also handles both enables in one place
  rather than spreading the logic across two registers.

- **Nothing needs to be killed in IF.** `if_stage` redirects the PC in the same cycle,
  so whatever was being fetched is simply replaced. Only the two instructions already
  past IF need squashing.

- **JAL leaves the ALU idle.** The target comes from the dedicated adder, and the
  value written to `rd` is `current_pc_plus_4` selected by `write_back_src = 2'b11`.
  Whatever the ALU computes is discarded by the write-back mux. `alu_op` for the jump
  opcode should still be a defined value rather than a don't-care, so X's do not
  propagate into the waveform.

---

## Bring-Up and Integration

- **Straight-line before branches.** The first top-module bring-up ran only
  instructions needing no PC redirection, with `use_target` tied low. Branch logic was
  added afterward as a separate step. Integrating the pipeline and the branch path at
  once means a failure has two possible causes — wiring or branch logic — with no way
  to tell which. Bringing up the straight-line datapath first established a known-good
  pipeline, so any later failure was localized. Same principle as the UART's five-stage
  bring-up: each step isolates one failure domain. It worked: the `reg_or_imm` bug
  surfaced the moment the first branch executed, and the pipeline was already trusted.

- **Branch control signals were flopped into EX before they were used.** `funct3`,
  `branch`, `jump` and `current_pc` crossed ID→EX during straight-line bring-up even
  though nothing read them yet. Synthesis removes flops that feed nothing, so the
  interim cost was zero, and adding the branch path required no top-module signal
  changes.

- **Test programs leave three instructions between a write and its use.** There is no
  forwarding yet, so a result only becomes readable once it reaches the register file
  three cycles later. Anything closer reads a stale value — not a bug, just what a
  pipeline without forwarding does. The fillers inside the loop program exist for this
  reason and are documented in the `.s` source so they are not mistaken for padding.

- **The CPU has no output ports, which breaks synthesis but not simulation.** With only
  `clk` and `reset`, `opt_design` finds nothing observable and deletes the entire design
  ("the design is empty"). Simulation is unaffected, since the simulator keeps every
  internal signal and the testbench reaches the register file hierarchically. A debug
  output is required before any timing report means anything; the real answer is the
  UART, once AXI4-Lite lands.

- **Stage testbenches cover only what the stage itself contains.** `tb_ex_stage` does
  not re-test the ALU or the data memory — both have their own testbenches. It covers
  the operand mux, the wiring into the submodules, the target adder, the `use_target`
  gating, and the pass-throughs. A submodule testbench drives its ports directly and
  therefore cannot catch a miswiring at the parent level, which is exactly the class of
  bug the implicit-net failure turned out to be.

- **ISA coverage is partial through v1.0, by decision.** The demo programs (Fibonacci,
  factorial, a directed co-simulation test) are counted loops using word-aligned memory
  access, so they need arithmetic and logic R/I-types, `lw`, `sw`, `lui`, `beq` and
  `bne`. Byte and halfword accesses would require lane enables in `data_memory`; the
  remaining branches require the comparison decision above. Neither is on the path to
  the project's goals, which are bus integration, co-simulation, measured timing, and
  verification discipline. Completeness belongs with the compliance suite, later.

- **Memory is word-only and naturally aligned.** `data_memory` indexes with `addr[9:2]`,
  so the low two bits are ignored — a misaligned address silently accesses the
  containing word rather than trapping. The RISC-V spec permits either behaviour.
  Acceptable while only LW and SW exist; byte and halfword accesses would force the
  question.


---

## FPGA Fabric — what the resource report is counting

Notes on the primitives behind the utilisation numbers, since the report means
nothing without them.

- **LUTs compute; flip-flops store.** A look-up table is a small memory holding a
  truth table — feed it up to six input bits and it returns the answer. Every mux,
  comparison, decode and arithmetic operation becomes LUTs. A flip-flop holds one
  bit and updates on the clock edge. They sit side by side in a slice, which
  matches how the RTL reads: logic computes a value, a register captures it. This
  design uses 483 LUTs (ALU, control unit, immediate generator, forwarding
  comparisons, every mux) and 537 flip-flops (the register file's 1024 bits, both
  pipeline registers, the PC, the instruction memory output register).

- **Block RAM comes in fixed sizes.** The XC7A35T has 50 tiles of 36 Kb — the
  1,800 Kb figure on the box. A tile splits once into two independent 18 Kb
  halves, and no further; that is a property of the silicon. The data memory is
  256 words × 32 bits = 8 Kb, so it takes one 18 Kb half and Vivado reports 0.50
  of a tile. The remaining 10 Kb of that half is wasted, and a second small memory
  could occupy the other half of the same tile.

- **IO are physical package pins, and they are the scarce resource.** Every port
  on the top module becomes a pin: `clk`, `reset`, and 16 LEDs, so 18 of 106.
  Internal signals cost nothing; pins cost immediately. Setting a stage module as
  top by mistake asks for 316 pins and fails placement outright — a useful
  accident, since it makes the asymmetry obvious.

- **The ALU's adder uses dedicated carry hardware, not LUTs.** Adding two 32-bit
  numbers is a chain: each bit's result depends on the carry from the bit below,
  so bit 0 must settle before bit 1, and so on. Built from ordinary LUTs that
  would be very slow, so the fabric provides CARRY4 blocks — four bits of carry
  each, with dedicated fast wiring. A 32-bit adder uses eight of them. This is why
  a path with nine elements in series can still spend only 2.7 ns computing: most
  of those elements are carry blocks, not general logic.

---

## Reading a Timing Report

- **Delay splits into two kinds, and they have opposite fixes.** Vivado reports
  *logic delay* (time inside gates) separately from *net delay* (time travelling
  on wires between them). A path that is logic-limited has too many gates in
  series, and the fix is a pipeline register splitting one long chain into two
  short ones. A path that is net-limited spends its time in transit, and
  pipelining does nothing — a register in the middle does not shorten a wire. The
  fix there is physical: closer placement, or fewer destinations to reach.

- **Fanout is how many places one signal must drive.** High fanout is slow twice
  over: more gate inputs to switch, and no way to place all the destinations
  nearby. The standard fix is replication — build a second copy of the driving
  register, same input and clock, and split the loads between them. Same
  behaviour, shorter wires. In this design `ex_wb_rd` reaches 129 places: the
  forwarding comparators, the write-back mux, and the register file's write port.

- **`Fmax = 1 / (period − WNS)` is a floor, not the answer.** The formula assumes
  the critical path's delay is a fixed property of the design. It is not: the
  placer and router stop optimising once the constraint is met. Measured from a
  relaxed 100 MHz build the formula gave 118 MHz; tightening the constraint step
  by step until setup failed gave 150.6 MHz — the same RTL, a better physical
  arrangement, a 27% gap. The only honest way to get Fmax is to push until it
  breaks.

- **The reported critical path at a loose constraint is not the real bottleneck.**
  At 100 MHz with 1.5 ns of slack, the worst path was inside the data memory. At
  6.640 ns it was the forwarding comparison feeding the store data path. Squeezing
  the design is what makes the true limiter surface.
