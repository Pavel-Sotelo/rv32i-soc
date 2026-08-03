# Bug Log

Bugs found during development, with root cause and how they were caught.

---

## 2026-07-22 — I-type `alu_op` corrupted by negative immediates

**Module:** `control_unit.sv`

**Cause:** `addi x5, x1, -8` produced `alu_op = 4'b1000` (SUB) instead of `4'b0000` (ADD).

**Root cause:** The control unit computed `alu_op = {funct7, funct3}` for opcode `0x13`,
where `funct7` is wired to `instruction[30]`. In I-type instructions there is no funct7
field — bits 31:20 are the immediate. For a negative immediate, sign extension sets bit 30
to 1, which corrupted the top bit of `alu_op` and turned ADD into SUB.

Bit 30 is only a valid discriminator for I-type when `funct3 == 3'b101`, where the ISA
reuses it to distinguish `srli` from `srai`.

**Fix:** In the `0x13` case, use `{funct7, funct3}` only when `funct3 == 3'b101`; otherwise
force the top bit to zero (`{1'b0, funct3}`).

**How it was caught:** Integration test in `tb_id_stage` decoding `addi x5, x1, -8`. The
`control_unit` unit test had passed because its I-type test vector used `funct3 = 101`
(srai) — the one funct3 value where bit 30 is genuinely meaningful.

---

## 2026-08-02 — `reg_or_imm` low for B-type, so branches never resolved

**Module:** `control_unit.sv`

**Cause:** The first program with a loop never terminated. The counter incremented
past its limit indefinitely — `bne` was taken on every iteration, including the one
where its two operands were equal.

**Root cause:** The B-type case set `reg_or_imm = 0`. In `ex_stage` the operand mux is
`reg_or_imm ? reg_value_2 : immediate`, so the ALU received the branch offset instead
of `rs2`. A `bne x2, x3, -16` therefore computed `x2 + 16` rather than `x2 - x3`. That
result is never zero, so `take_branch` was asserted unconditionally.

Branches compare two registers, so B-type belongs with R-type on this signal, not with
the I- and S-types that use an immediate.

**Fix:** `reg_or_imm = 1` for opcode `0x63`.

**How it was caught:** The first loop program. Neither existing test could have found
it: the straight-line program contains no branches, and `tb_ex_stage` drives
`reg_or_imm` by hand rather than taking it from `control_unit`, so it verified the mux
against its own assumption instead of against the decoder. The bug lived precisely in
the gap between two modules that were each individually correct.
