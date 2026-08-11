addi x1, x0, 42
sw   x1, 0(x0)         # store to data memory
lw   x5, 0(x0)         # x5 = 42, normal load

lui  x10, 0x1          # x10 = 0x1000
addi x6, x0, 65        # 'A'
sw   x6, 0(x10)        # transmit over the UART
lw   x13, 8(x10)       # read STATUS, should stall