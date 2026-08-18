#  register description:

    #  x10 = UART base
    #  x1  = STATUS register
    #  x2  = byte in/byte out
    #  x3  = comparison constant
    #  x4  = counter for 'c', survives across iterations
    #  x5,x6,x7 = fibonacci working registers    
    #  x8  = previous byte received, for 'p'

# setup:
    lui  x10, 0x1          # UART base
    addi x4, x0, 48        # counter starts at '0'
    addi x8, x0, 45        # previous byte starts as '-', nothing typed yet

# wait_rx loop (address 12):
    lw   x1, 8(x10)        # read STATUS
    andi x1, x1, 2         # Mask only done bit
    beq  x1, x0, -8        # return to loop (PC + imm = 20 - 8 = 12) if done is 0

    lw   x2, 4(x10)        # done=1, load RX_DATA byte into x2

# dispatch:

    addi x3, x0, 102       # 'f'
    beq  x2, x3, 40        # fibonacci (PC + imm = 32 + 40 = 72)

    addi x3, x0, 99        # 'c'
    beq  x2, x3, 72        # counter (PC + imm = 40 + 72 = 112)

    addi x3, x0, 112       # 'p'
    beq  x2, x3, 76        # previous byte (PC + imm = 48 + 76 = 124)

    addi x3, x0, 122       # 'z'
    beq  x2, x3, 76        # check counter (PC + imm = 56 + 76 = 132)

    addi x8, x2, 0         # remember this byte for a later 'p'
    addi x2, x2, -32       # default: uppercase it

    beq  x0, x0, 84        # send (PC + imm = 68 + 84 = 152)

# command bodies:

    # Fibonacci (address 72):  # 'f': compute and send F(12) = 233

        addi x7, x0, 0         # counter = 0
        addi x3, x0, 12        # limit = 12

        addi x5, x0, 0         # prev = 0
        addi x6, x0, 1         # curr = 1

        add  x2, x5, x6        # next = prev + curr  (loop start, address 88)
        add  x5, x0, x6        # curr -> prev
        add  x6, x0, x2        # next -> curr
        addi x7, x7, 1         # counter++
        bne  x7, x3, -16       # loop returner (PC + imm = 104 - 16 = 88)

        beq  x0, x0, 44        # send (PC + imm = 108 + 44 = 152)


    # Counter (address 112):   # 'c': send counter, then advance it

        addi x2, x4, 0
        addi x4, x4, 1

        beq  x0, x0, 32        # send (PC + imm = 120 + 32 = 152)


    # Previous byte (address 124):  # 'p': send the last non-command byte typed

        addi x2, x8, 0

        beq  x0, x0, 24        # send (PC + imm = 128 + 24 = 152)


    # Check counter = 0 (address 132):  # 'z': has 'c' been pressed yet?
                       
        addi x3, x0, 48        # '0', the counter's untouched value
        addi x2, x0, 89        # 'Y'
        beq  x4, x3, 12        # send (PC + imm = 140 + 12 = 152)
        addi x2, x0, 78        # 'N'

        beq  x0, x0, 4         # send (PC + imm = 148 + 4 = 152)


# send (address 152):

    # wait_tx loop:

        lw   x1, 8(x10)        # read STATUS
        andi x1, x1, 1         # Mask only tx_busy bit
        bne  x1, x0, -8        # return to wait_tx (PC + imm = 160 - 8 = 152) if tx_busy is 1

    sw   x2, 0(x10)        # transmit
    beq  x0, x0, -156      # back to wait_rx (PC + imm = 168 - 156 = 12)