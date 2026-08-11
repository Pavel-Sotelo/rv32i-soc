addi x2, x0, 0      # counter = 0
addi x3, x0, 12     # limit = 12 (F(12) = 233, max number a byte can send in fibonacci)

addi x4, x0, 0      # prev = 0
addi x5, x0, 1      # curr = 1

# fibonacci loop:
add  x6, x4, x5     # prev + curr  (loop start, address 16)
add  x4, x0, x5     # curr -> prev
add  x5, x0, x6     # next -> curr
addi x2, x2,  1     # counter++
bne  x2, x3, -16    # loop returner (PC + imm = 32 - 16 = 16)

# send final fibonacci byte (233 decimal) to UART:

lui x10, 0x1        # x10 = 0x1000 (UART address)
sw   x5, 0(x10)     # write 233 to UART

# done:
beq x0, x0, 0    # finish program, PC stays here forever (PC + imm = 44 + 0 = 44)