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
