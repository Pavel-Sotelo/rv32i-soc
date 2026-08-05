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

---

## 2026-08-04 — Blocking assignment in `pc.sv` shifted every fetch by one instruction

**Module:** `pc.sv`

**Cause:** Inside `always_ff`, the else branch used `=` instead of `<=`. I do not
know when this was introduced — a typo made while editing something else, and
nothing failed, so it went unnoticed.

**Root cause:** A blocking assignment updates immediately rather than at the end
of the timestep, so the PC advanced within the same clock edge.
`instruction_memory` samples `addr` on that edge and captured the already-advanced
address, returning the *next* instruction. Every fetch was off by one.

**Fix:** `out_pc <= next_pc;`

**How it was caught:** A new forwarding test gave wrong results. Printing the PC
and the fetched instruction every cycle showed the PC reading 0 while the
instruction was `imem[1]` — the first instruction never executed.

**Why it survived:** A second bug cancelled it. `second_flush` was never reset in
`rv32i_top`, so it held X out of reset and the flush squashed the first
instruction. One bug skipped an instruction, the other shifted every fetch forward
by one, and together they produced correct output for days.

The stage testbenches could not have caught it: `tb_if_stage` checks that the PC
increments, `tb_id_stage` that instructions decode — both true. What was wrong is
the relationship between them, which no single-module testbench can observe.

**After the fix:** all three CPU programs re-run and pass with the normal
one-cycle reset, so the fetch is genuinely corrected. A three-cycle reset had made
the symptom vanish during debugging, but that was a workaround.

---

## 2026-08-04 — Forwarding `ex_wb_alu_result` was wrong for loads and jumps

**Module:** `ex_stage.sv`, `rv32i_top.sv`

**Cause:** With forwarding working for arithmetic, a load followed immediately by
a use still read a stale operand: `lw x1, 0(x0)` then `addi x2, x1, 3` gave
`x2 = 3` instead of 45.

**Root cause:** The forwarding mux selected `ex_wb_alu_result`. For a load that
register holds the memory *address*, not the loaded value — the data arrives on
`d_mem_read_data`. The same applies to JAL, whose result is `current_pc_plus_4`.
The forwarding unit was correctly deciding *whether* to forward, but the datapath
was forwarding the wrong value.

**Fix:** Forward `wb_write_value` instead. `wb_stage` has already selected among
the ALU result, the loaded data and the JAL return address using `write_back_src`,
so a single signal is correct for all three and the forwarding select stays 1 bit.
The alternative — widening the mux and passing `write_back_src` into the
forwarding unit — would have duplicated a mux that already exists.

**How it was caught:** A directed load-use program, written specifically to test
whether the hazard existed. Confirmed by printing `d_mem_read_data`,
`write_back_src`, `id_ex_rs1` and `ex_wb_rd` in the cycle the dependent
instruction was in EX: all four were correct, which proved the value was available
and the problem was mux selection rather than timing.