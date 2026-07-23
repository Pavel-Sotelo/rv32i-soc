# rv32i-soc

A RISC-V RV32I system-on-chip built from scratch on a Basys 3 FPGA (Xilinx Artix-7).

A custom RV32I CPU connected over an AXI4-Lite interconnect to a UART bring-up
interface, verified by running the same programs on both the RTL and a C
instruction set simulator (ISS) written from scratch, and comparing the final
register and memory state.

**Status: in progress** — CPU core under construction.

## Progress
- [x] ALU — RV32I integer ops (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU), 9-case testbench
- [x] Register file (32×32, 2 read / 1 write, x0 hardwired)
- [x] Instruction memory (BRAM ROM, $readmemh program load)
- [x] ISS skeleton (C reference model) — CPUState, fetch/decode/execute, R-type + I-type arithmetic
- [x] IF stage — PC register, fetch logic, branch/jump target mux
- [x] ID stage — control unit, immediate generator (all 6 formats), register file read
- [ ] ISS complete — loads, stores, branches, jumps
- [ ] EX + WB stages (single program running)
- [ ] Co-simulation (RTL vs ISS)
- [ ] Pipelining + forwarding
- [ ] Timing closure / Fmax
- [ ] AXI4-Lite integration (CPU ↔ UART)

## Architecture
Harvard architecture — instruction and data memories are two separate BRAM blocks, so
instruction fetch and data access don't contend for a single memory port.

**Three stages (IF/ID, EX, WB)** rather than the textbook five. Fewer stages mean fewer
data hazards to resolve and a shorter branch penalty (~1 cycle), which gets a correct,
working CPU sooner. A five-stage upgrade is planned, at which point branch prediction
becomes worth adding — in a three-stage pipeline the penalty is small enough that a
predictor recovers almost nothing.

## Structure
- `rtl/` — SystemVerilog source
- `tb/` — testbenches
- `iss/` — C instruction-set simulator (golden reference model)
- `programs/` — hex programs loaded into instruction memory
- `docs/` — design notes and bug logs

## Target
Xilinx Artix-7 (Basys 3), Vivado.