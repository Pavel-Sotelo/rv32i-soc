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
- [x] Instruction memory
- [x] ISS skeleton (C reference model) — CPUState, fetch/decode/execute, R-type + I-type arithmetic
- [ ] ISS complete — loads, stores, branches, jumps
- [ ] Decode / control
- [ ] Datapath integration (single program running)
- [ ] Co-simulation (RTL vs ISS)
- [ ] Pipelining + forwarding
- [ ] Timing closure / Fmax
- [ ] AXI4-Lite integration (CPU ↔ UART)

## Architecture
Harvard architecture — instruction and data memories are two separate BRAM blocks,
so instruction fetch and data access don't contend for a single memory port.

## Structure
- `rtl/` — SystemVerilog source
- `tb/`  — testbenches
- `iss/` — C instruction-set simulator (golden reference model)
- `docs/` — design notes and bug logs

## Target
Xilinx Artix-7 (Basys 3), Vivado.