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
