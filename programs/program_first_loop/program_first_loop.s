addi x1, x0, 0      # sum = 0
addi x2, x0, 0      # counter = 0
addi x3, x0, 4      # limit
addi x0, x0, 0      # spacer
addi x0, x0, 0      # spacer

# loop:  
add  x1, x1, x3     # address 20 (loop starts here)  
addi x2, x2, 1      # counter++
addi x0, x0, 0      # filler 1
addi x0, x0, 0      # filler 2
bne  x2, x3, -16    # immediate -16, lets return to loop (address 36 - 16 = 20)