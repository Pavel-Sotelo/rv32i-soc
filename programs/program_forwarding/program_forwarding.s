addi x1, x0, 5          # x1 = 5
addi x2, x1, 3          # ALU result forwarded, 1-back: x2 = 8
add  x3, x2, x1         # ALU 1-back (x2) + bypass 2-back (x1): x3 = 13
sub  x7, x3, x2         # x3 is 1-back, x2 is 2-back: x7 = 5

addi x4, x0, 42
sw   x4, 0(x0)          # rs2 forwarding on store data, 1-back
lw   x5, 0(x0)          # x5 = 42
addi x6, x5, 3          # LOAD forwarded, 1-back: x6 = 45