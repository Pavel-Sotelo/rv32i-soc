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

---

## 2026-08-17 — Branch flush killed one instruction too many, and it took three days

**Module:** `rv32i_top.sv`

**Cause:** The echo program read a byte from the UART and sent it straight back. On
hardware, typing a character filled the terminal with that character repeating without
end. Typing a different one switched the stream over to the new character but never
stopped it. In simulation the same program transmitted the first byte several times over
and then polled forever, while the UART wrapper sat holding a second received byte that
the CPU never collected.

**Root cause:** The branch/jump flush cleared the control signals of **two**
instructions behind a taken branch, but only **one** wrong-path instruction is ever in
flight.

`ex_stage` drives `out_use_target` and `out_pc_target` combinationally, and `if_stage`
feeds them straight into the `next_pc` mux:

```systemverilog
assign next_pc = use_target ? pc_target : current_pc_plus_4;
```

So on the very cycle the branch sits in EX, the fetch stage is already reading from the
target. Counting what is in flight at that moment:

| stage | holds | verdict |
|---|---|---|
| EX | the branch, redirect asserted this cycle | resolving |
| ID | instruction fetched after the branch | wrong path, must die |
| IF | already fetching from `pc_target` | correct path, must live |

One wrong instruction, not two. The flush is applied at the ID→EX boundary, so each
cycle it is active neuters exactly one instruction crossing into EX. `second_flush`
extended it for a second cycle — and by then the instruction at that boundary was the
*first instruction of the branch target*, which is on the correct path.

The two-cycle width is correct for a design where the redirect is registered out of EX.
Here it is combinational, which buys back a cycle, and the flush width was never
adjusted to match.

**Why every earlier program still passed.** A flushed instruction is not removed, only
stripped of `reg_write`, `read_mem`, `write_mem`, `branch` and `jump` — it becomes a
`nop`. Whether that matters depends entirely on what sits at the branch target:

- **Straight-line program** — no branches, so no flushes at all.
- **First loop, forwarding, UART stall** — the victim was arithmetic inside a loop body
  and was re-executed on a later pass, or its effect never reached a register the test
  compared.
- **Fibonacci** — the `bne` targets an `add` 16 bytes back. The killed value was
  recomputed by the loop, and F(12) came out as 233 exactly as the ISS predicted.

Co-simulation compares **final register state**. A defect whose effect is recomputed on
a later iteration converges to the same answer, so RTL and ISS agreed every time. Four
programs, all green, for weeks.

The echo program broke the pattern for one reason. `wait_rx` is three instructions:

```
04: lw   x1, 8(x10)     <- the flush victim
08: andi x1, x1, 2
0c: beq  x1, x0, -8     <- taken, redirects to 04
```

The target is only 8 bytes back, so the extra flush cycle landed on the `lw` at `0x04`
and cleared its `read_mem` before it reached EX. That load is not arithmetic that can be
recomputed — it is the AXI4-Lite read that fetches STATUS. With `read_mem` low no bus
transaction is issued at all, and `x1` keeps whatever the previous read left in it.

The first character was read correctly because at start-up the CPU reached `wait_rx`
before any branch had been taken, so that first `lw` went through cleanly: STATUS was
read, the done bit was set, and the byte was echoed. From then on every pass arrived
through the loop-back branch with the `lw` at `0x04` neutered, so `x1` kept the STATUS
word from that one good read — done bit still set. `wait_rx` fell through on every pass
without ever consulting the peripheral again, RX_DATA was re-read, and the byte was sent
out over and over.

The stream tracked whatever the wrapper happened to be holding, which is why typing a
different character switched the output to that character instead of stopping it: the RX
side was working the whole time and kept updating `CAPTURED_RX_BYTE`. Only the CPU's
view of STATUS was frozen.

**Fix:** flush one instruction, not two. `second_flush` and its logic were deleted and
the five control signals now gate on `ex_if_use_target` alone:

```systemverilog
id_ex_reg_write <= ex_if_use_target ? 1'b0 : id_reg_write;
id_ex_read_mem  <= ex_if_use_target ? 1'b0 : id_read_mem;
id_ex_write_mem <= ex_if_use_target ? 1'b0 : id_write_mem;
id_ex_branch    <= ex_if_use_target ? 1'b0 : id_branch;
id_ex_jump      <= ex_if_use_target ? 1'b0 : id_jump;
```

The fix is entirely subtraction. Nothing was added.

**How it was caught.** Three days, and almost all of that time was spent looking in the
wrong module. The symptom pointed at the UART, so the search started there and stayed
there far too long. What was actually ruled out along the way:

- **The program.** Decoded straight from the hex, instruction by instruction: every
  opcode, register field and branch offset was correct, including all three backward
  branch immediates. The software was never at fault.
- **The wrapper.** A monitor on `CAPTURED_DONE` showed the second byte being captured
  correctly at 449.4 µs with the right value. The wrapper did its job.
- **The stall.** `ex_if_use_target` and `stall` were never high in the same cycle, so no
  redirect was being discarded by the pipeline freeze.
- **The branch unit.** Replacing the loop-back `beq` with an unconditional `jal` failed
  in exactly the same way, which cleared the comparison logic and `id_ex_branch`.
- **The program layout.** Padding the branch shadow with `nop`s changed nothing.

Each of those eliminated a module without identifying the fault, and a dozen speculative
RTL changes were tried and reverted in between. The thing that actually found it was a
**PC trace**: printing `if_current_pc`, `ex_is_uart`, `id_ex_read_mem`, `stall` and
`ex_if_use_target` every cycle for forty cycles, long after the second byte had arrived.

That trace showed the loop running `04 → 08 → 0c → 10 → 14` as expected, and
`id_ex_read_mem = 0` on **every single line**. A program counter sitting on a `lw` while
`read_mem` reads zero is a contradiction that only the flush can produce. The fix
followed in minutes; the two days before it were spent without that one measurement.

**What this says about the verification.** The suite was strong at the module level —
every module has its own testbench — and strong at final-state comparison through the
ISS. It was blind to a defect that is invisible in final state, and every program written
before this one happened to be forgiving in exactly that way. It took a program where a
flushed instruction was a peripheral read, which cannot be recomputed by a later
iteration, to make the fault observable at all.

`tb_rv32i_echo` now sends **two** bytes and checks both the number of transmissions and
the value of each. Counting alone is not enough either: at one point during debugging the
design transmitted exactly once and carried the wrong byte, which a pulse count would
have passed.