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

## 2026-08-16 — Branch flush killed one instruction too many, and it took three days

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


---

## 2026-08-17 — The instruction memory's output register is a pipeline register, and I was treating it as neither

**Module:** `instruction_memory.sv`, `rv32i_top.sv`

**Cause:** With the program finally loading, the interpreter still failed, in two
different ways at once. `wait_tx` never exited, so a command either sent nothing or sent
1683 copies of a byte. And when bytes did come out, the wrong ones did: `c` and `p` both
answered `'Y'`, which is the reply belonging to `z`.

**Root cause:** one register, unaccounted for, producing two separate bugs.

The instruction memory has a registered output — it has to, because
`(* rom_style = "block" *)` forces it into a block RAM and a BRAM physically cannot do a
combinational read:

```systemverilog
always_ff @(posedge clk) instruction <= inst_memory[addr[9:2]];
```

That `<=` means there are **two flops in series** between `next_pc` and an instruction
arriving in decode:

```
next_pc ──►[PC register]──► current_pc ──►[ROM output register]──► instruction
              flop 1                             flop 2
```

I knew this. It is written down in this repo — the README says the IF→ID boundary is
"provided by the instruction memory output register", and that reasoning is what made me
call the core 4-stage instead of 3-stage. What I had not done is treat that register the
way I treat the pipeline registers I wrote myself. **Every pipeline register needs a
stall enable and a flush.** This one had neither, and each omission produced its own bug.

### Bug A: no stall enable, so instructions were destroyed mid-flight

When a `lw` from the UART stalls the pipeline, freezing means nothing moves. The PC froze
correctly. The ROM output register kept clocking, because nothing told it not to.

The poison is that the ROM always runs one address *ahead* of the instruction it is
currently delivering. So during the stall it re-delivered the address it was frozen on
and overwrote the instruction that was waiting to be decoded:

| cycle | ROM address (frozen) | ROM delivers |
|---|---|---|
| 1 | 168 | 164 `andi` — correct |
| 2 | 168 | 168 `bne` — **the `andi` is gone** |
| 3 | 168 | 168 `bne` |

The `andi x1, x1, 1` in `wait_tx` was fetched and never executed. It masks STATUS down to
the `tx_busy` bit; without it `x1` kept the raw STATUS word `6`, `bne x1, x0` saw
non-zero, and the poll looped forever.

**Fix:** hold the register when the pipeline holds.

```systemverilog
always_ff @(posedge clk)
    if (!stall)
        instruction <= inst_memory[addr[9:2]];
```

A block RAM with a clock enable, which is still a block RAM — no resource cost.

### Bug B: no flush, so two wrong instructions leaked, not one

This is the one that took the longest, because I had reasoned it out before and reached
the opposite conclusion — and my reasoning was correct for the design I *thought* I had.

What I believed: `use_target` is combinational out of EX, so on the very cycle the branch
resolves, `next_pc` already points at the target. One wrong instruction in flight, kill
one. That is exactly right **if fetch is combinational** — address in, instruction out,
same cycle.

With two flops in series it takes two clock edges for a redirect to become a new
instruction. The first edge changes the address. The second changes the data. In between,
one more wrong instruction gets through:

| cycle | ROM address | instruction in ID |
|---|---|---|
| T | B+8 | **B+4** — wrong path |
| T+1 | target | **B+8** — wrong path |
| T+2 | target+4 | target — correct, must survive |

So the redirect is right and immediate, as I thought. It is the *instruction* that lags
by an extra cycle, not the address.

In the dispatch chain that was fatal, because the leaked instruction is itself a branch:

```
addr 48:  beq x2, x3, do_count    taken, redirect to 116
addr 52:  beq x2, x3, do_zero     B+4, correctly killed
addr 56:  ...                     B+8, executed anyway
```

The instruction at B+8 ran, compared, decided it also matched, and issued its own
redirect. The CPU reached `do_count`, was pulled straight back out, landed in `do_prev`,
fell through into `do_zero` and sent `'Y'`. One leaked instruction hijacked the entire
dispatcher, which is why three unrelated commands all answered with the same wrong byte.

**Why the earlier two-cycle flush did not work.** It also killed for two cycles, but the
wrong two. It was built on a free-running counter (`second_flush` / `flush_count`) with no
`~stall` gate, so its window started late and drifted whenever the pipeline froze:

| cycle | in ID | old counter flush | new flush |
|---|---|---|---|
| T | B+4 | kill | kill |
| T+1 | B+8 | missed | kill |
| T+2 | **target** | **killed — wrong** | survives |

Same count, window shifted by one. Deleting it on 16 August was the right call — a flush
that kills the branch target is worse than one that leaks an instruction — but the
correct answer was never "one cycle". It was "two cycles, correctly aligned".

**Fix:** a one-cycle delay line instead of a counter.

```systemverilog
logic flush_delayed;
always_ff @(posedge clk_75) begin
    if (sys_reset)      flush_delayed <= 1'b0;
    else if (~stall)    flush_delayed <= ex_if_use_target;
end

logic flush;
assign flush = ex_if_use_target | flush_delayed;
```

Three properties make it land where the counter did not. It is an echo of `use_target`
rather than an independent count, so it cannot drift. It is anchored to the same edge the
redirect fires, which is the same edge `B+4` sits in ID. And `~stall` freezes it with the
pipeline, so the window holds position instead of sliding past the instructions it exists
to kill — the same `~stall` that gates the ID→EX register, because the flush and the
pipeline have to move together or not at all.

The five control signals then gate on `flush` instead of `ex_if_use_target`.

**How it was caught.** A PC trace again, but this time printing the fetched instruction
word beside the PC, which is what made both bugs visible as plain contradictions:

- Bug A: `pc=164` held constant across a stall while `inst` changed from `0010f093`
  (`andi`) to `fe009ce3` (`bne`). The PC frozen and the instruction moving is only
  possible if they are separate registers and only one of them is being held.
- Bug B: `use_target=1` on the line for `pc=76`, then the next line is `pc=80` with `x3`
  changing to `0xc` — that is `addi x3, x0, 12` at address 80 executing — and only then
  does `pc=156`, the target, appear. Two lines between the redirect and the target, not
  one.

`x3` becoming `0xc` had been in every trace I took, from the very first one, and I read
past it four times because x3 is a scratch register and the value looked harmless.

**Why the earlier programs survived both.** The same reason as the flush bug the day
before: the data was forgiving.

- **Echo survived bug A** because after the byte is read, STATUS is `0`. The `andi` masks
  `0` down to `0`. Losing the instruction changed nothing at all.
- **Echo survived bug B** because the leaked instruction wrote a scratch register that
  was overwritten before anything read it.
- **Fibonacci survived both** because co-simulation compares final register state, and
  the leaked instructions were arithmetic recomputed on the next loop pass.

The command interpreter broke because STATUS was `6` this time — the receiver flag still
set — and because the leaked instruction was a `beq` inside a chain of `beq`s, the one
context where a stray instruction can steer the program somewhere else entirely.

**What this says about the verification.** Second time in two days that a bug lived
through weeks of passing tests because the programs happened not to expose it. The
pattern is the same and worth naming: a test that passes tells you the output matched, not
that the design is correct. Echo passed with two live bugs in the fetch path. It would
have kept passing.

The thing that changed the odds was writing a program with different *shapes* in it — a
peripheral read that cannot be recomputed, a nonzero status word, a chain of branches
where control flow is the thing under test. Not more tests. Different ones.
