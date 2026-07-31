# rv32i-soc

A RISC-V RV32I system-on-chip built from scratch on a Basys 3 FPGA (Xilinx Artix-7).

A custom RV32I CPU connected over an AXI4-Lite interconnect to a UART bring-up
interface, verified by running the same programs on both the RTL and a C
instruction set simulator (ISS) written from scratch, and comparing the final
register and memory state.

**Status: in progress** — CPU core executes straight-line programs; branches and jumps next.

## Progress
- [x] ALU — RV32I integer ops (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU), 9-case testbench
- [x] Register file (32×32, 2 read / 1 write, x0 hardwired)
- [x] Instruction memory (BRAM ROM, $readmemh program load)
- [x] ISS skeleton (C reference model) — CPUState, fetch/decode/execute, R-type + I-type arithmetic
- [x] IF stage — PC register, fetch logic, branch/jump target mux
- [x] ID stage — control unit, immediate generator (all 6 formats), register file read
- [x] ISS — loads (LW), stores (SW), LUI, store-load round-trip
- [x] Data memory (BRAM, synchronous read, byte→word addressing)
- [x] EX + WB stage modules (ALU path, memory path, write-back mux)
- [x] First working CPU — top module, straight-line program executing
- [ ] Branch and jump resolution (EX → IF redirect, 2-cycle flush)
- [ ] ISS — branches (BEQ), jumps (JAL)
- [ ] ISS complete — loads, stores, branches, jumps
- [ ] Co-simulation (RTL vs ISS)
- [ ] Forwarding (data hazard resolution)
- [ ] Timing closure / Fmax
- [ ] AXI4-Lite integration (CPU ↔ UART)

## Architecture

Harvard architecture — instruction and data memories are separate BRAM blocks,
so fetch and data access never contend for one memory port.

### Update, 30 July 2026: this core is 4-stage, not 3-stage

I first described this design as 3-stage (IF/ID, EX, WB), because I counted the
pipeline registers I wrote myself, and I wrote two. But a pipeline register is
any register that separates two stages — it does not matter who put it there.
Counting that way gives three boundaries and four stages.

The one I missed is IF→ID. My instruction memory is BRAM, and BRAM reads are
synchronous: the instruction arrives one cycle after the address is presented.
That output register is a pipeline register — I just didn't type it. So fetch
gets its own cycle, and IF and ID are separate stages.

I had already used this exact reasoning elsewhere in the design. There is no MEM
stage here because the data memory's output register serves as the EX→WB
boundary. The instruction memory's output register is the same construct at
IF→ID. Either both count as boundaries or neither does, so the design is
4-stage: IF, ID, EX, WB.

| boundary | provided by |
|---|---|
| IF → ID | instruction BRAM output register |
| ID → EX | pipeline register I wrote (14 signals) |
| EX → WB | pipeline register I wrote (5 signals), plus the data memory BRAM output register for the loaded value |

One consequence: branches resolve in EX, which is stage 3, so two wrongly
fetched instructions sit behind it in ID and IF. The branch penalty is 2 cycles,
not 1 as I had assumed.

### Why I kept 4 stages instead of merging ID and EX

Once I knew it was 4-stage, a real design question followed: 

**Should i merge ID/EX into one stage (IF, ID/EX, WB)?**

ID is purely combinational — field slicing, control decode, immediate
generation, and the register file read. The only thing separating it from EX is
a pipeline register I put there myself, and I could remove it. That would give a
genuine 3-stage pipeline with better CPI: the branch penalty drops to 1 cycle,
and the hazard distance shrinks from 3 instructions to 2.

I decided not to answer this by arguing. I built the first working CPU as
4-stage, added timing constraints for the Basys 3's 100 MHz clock, ran
implementation, and read the critical paths.

**Baseline timing.** Post-implementation at 100 MHz. **This is a straight-line
CPU — branch and jump resolution and forwarding are not built yet, and both add
logic to the EX path. These numbers will get worse as those go in, and they are
a starting point, not the final Fmax.**

| metric | value |
|---|---|
| WNS | 4.187 ns → Fmax ~172 MHz |
| failing endpoints | 0 |
| worst path | instruction BRAM output → register file read → ID/EX register |
| ID critical path | 5.814 ns |
| EX critical path | 5.503 ns |

Two things came out of this.

**The split is balanced.** A pipeline's clock period is set by its slowest
stage, so if ID took 5.8 ns and EX took 2 ns, the clock would still be 5.8 ns
and EX would sit idle for most of every cycle — The fix would be slicing the
slowest stage into 2 stages if i want more fmax, and I would have paid for that
boundary in flip-flops, latency, and branch penalty without getting speed back.
At 5.814 ns and 5.503 ns the two stages are within 0.31 ns, so both use nearly
the whole period and there's no reason to slice.

**Merging them would not close timing.** Chained in one clock period, ID and EX
come to roughly 11 ns, and the period at 100 MHz is 10 ns. There is no margin to
spend, and forwarding lands directly on the EX path later, which would only make
the merged version worse.

So I kept 4 stages and chose frequency over CPI: I pay a 2-cycle branch penalty
in exchange for timing closure with margin. The planned upgrade is 4 → 5 stages,
splitting MEM back out of EX, which is one clean change from here.

**One more thing the report showed.** The worst path has only 2 levels of logic,
and 4.796 ns of its 5.814 ns total is net delay — wires, not gates — on a signal
with a fanout of 66. Pipelining fixes a path by cutting a long chain of gates
into two shorter chains, but there is no long chain here to cut, and a register
in the middle does not make a wire shorter. So more stages would not help this
path; reducing fanout and improving placement would. That is what the timing
work later in the project targets.

## Structure
- `rtl/` — SystemVerilog source
- `tb/` — testbenches
- `iss/` — C instruction-set simulator (golden reference model)
- `programs/` — hex programs loaded into instruction memory
- `docs/` — design notes and bug logs

## Target
Xilinx Artix-7 (Basys 3), Vivado.
