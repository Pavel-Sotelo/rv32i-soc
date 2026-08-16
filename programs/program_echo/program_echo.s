lui x10, 0x1        # UART base

# echo loop (starts at adress 4):

# wait rx (done) loop:

lw   x1, 8(x10)     # read STATUS
andi x1, x1, 2      # Mask only done bit
beq  x1, x0, -8     # return to loop (PC = 4) if done is 0

lw x2, 4(x10)       # done=1, load RX_DATA byte into register

# wait tx (~tx_busy) loop, prevents dropping transmitted byte:

lw   x1, 8(x10)     # read STATUS
andi x1, x1, 1      # Mask only tx_busy bit
bne  x1, x0, -8     # return to loop (PC = 20) if tx_busy is 1

sw x2, 0(x10)       # echo it back

beq x0, x0, -32     # return to echo loop