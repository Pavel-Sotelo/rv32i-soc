import sys

# PYTHON ASSEMBLER

# mnemonic case, which we can get the format, opcode, funct3 and funct7
# mnemonic -> (format, opcode, funct3, funct7)
mnemonic_case = {

    # R-type
    "add":   ("R",  0x33, 0x0, 0x00),
    "sub":   ("R",  0x33, 0x0, 0x20),
    "sll":   ("R",  0x33, 0x1, 0x00),
    "slt":   ("R",  0x33, 0x2, 0x00),
    "sltu":  ("R",  0x33, 0x3, 0x00),
    "xor":   ("R",  0x33, 0x4, 0x00),
    "srl":   ("R",  0x33, 0x5, 0x00),
    "sra":   ("R",  0x33, 0x5, 0x20),
    "or":    ("R",  0x33, 0x6, 0x00),
    "and":   ("R",  0x33, 0x7, 0x00),

    # I-type arithmetic
    "addi":  ("I",  0x13, 0x0, None),
    "slti":  ("I",  0x13, 0x2, None),
    "sltiu": ("I",  0x13, 0x3, None),
    "xori":  ("I",  0x13, 0x4, None),
    "ori":   ("I",  0x13, 0x6, None),
    "andi":  ("I",  0x13, 0x7, None),

    # I-type shifts, immediate is a 5-bit (max 31 positions), funct7 in bits 31:25
    "slli":  ("IS",  0x13, 0x1, 0x00),
    "srli":  ("IS",  0x13, 0x5, 0x00),
    "srai":  ("IS",  0x13, 0x5, 0x20),

    # loads
    "lw":    ("IL", 0x03, 0x2, None),

    # stores
    "sw":    ("S",  0x23, 0x2, None),

    # branches
    "beq":   ("B",  0x63, 0x0, None),
    "bne":   ("B",  0x63, 0x1, None),
    "blt":   ("B",  0x63, 0x4, None),
    "bge":   ("B",  0x63, 0x5, None),
    "bltu":  ("B",  0x63, 0x6, None),
    "bgeu":  ("B",  0x63, 0x7, None),

    # upper immediates
    "lui":   ("U",  0x37, None, None),
    "auipc": ("U",  0x17, None, None),

    # jumps
    "jal":   ("J",  0x6F, None, None),
    "jalr":  ("IL", 0x67, 0x0, None),
}



# FUNCTIONS


# Function to remove x in register and set 5-bit width
def reg(part):
    return int(part[1:]) & 0x1F

# Function to assemble and encode each instruction
def assemble_instr(instr):    

    # Convert instruction string into a list
    instr = instr.replace("," , " ").replace("(", " ").replace(")", " ")
    parts = instr.split()

    # with mnemonic, we can get the format, opcode, funct3 and funct7
    mnemonic = parts[0]
    fmt, opcode, funct3, funct7 = mnemonic_case[mnemonic] 

    match fmt:

        case "R":
            rd  = reg(parts[1])    
            rs1 = reg(parts[2])
            rs2 = reg(parts[3])

            # Encode R-type instruction
            word = (funct7 << 25) | (rs2 << 20) | (rs1 << 15)  | (funct3  << 12) | (rd << 7) | opcode


        case "I":
            rd  = reg(parts[1])    
            rs1 = reg(parts[2])
            imm = int(parts[3], 0) & 0xFFF

            # Encode I-type instruction
            word = (imm << 20) | (rs1 << 15) | (funct3  << 12) | (rd << 7) | opcode

        case "IS":
            rd    = reg(parts[1])
            rs1   = reg(parts[2])
            shamt = int(parts[3], 0) & 0x1F   # 5 bit shift amount, bits 24:20

            # Encode I-type shift instruction
            word = (funct7 << 25) | (shamt << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode     

        case "IL":
            rd  = reg(parts[1]) 
            imm = int(parts[2], 0) & 0xFFF
            rs1 = reg(parts[3])

            # Encode I-type load instruction
            word = (imm << 20) | (rs1 << 15) | (funct3  << 12) | (rd << 7) | opcode

        case "S": 
            rs2 = reg(parts[1])
            imm = int(parts[2], 0) & 0xFFF
            rs1 = reg(parts[3])

            imm_hi = (imm >> 5) & 0x7F  # imm[11:5]
            imm_lo = imm & 0x1F         # imm [4:0]

            # Encode S-type instruction
            word = (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (funct3  << 12) | (imm_lo << 7) | opcode


        case "B":
            rs1 = reg(parts[1])
            rs2 = reg(parts[2])
            imm = int(parts[3], 0) & 0x1FFF

            imm_12 = (imm >> 12) & 0x1 
            imm_10_5 = (imm >> 5) & 0x3F   
            imm_4_1 = (imm >> 1) & 0xF
            imm_11 = (imm >> 11) & 0x1

            # Encode B-type instruction
            word = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode


        case "U":
            rd  = reg(parts[1])
            imm = int(parts[2], 0) & 0xFFFFF

            # Encode U-type instruction
            word = (imm << 12) | (rd  << 7) | opcode 

        case "J":
            rd  = reg(parts[1])
            imm = int(parts[2], 0) & 0x1FFFFF

            imm_20 = (imm >> 20) & 0x1 
            imm_10_1 = (imm >> 1) & 0x3FF   
            imm_11 = (imm >> 11) & 0x1
            imm_19_12 = (imm >> 12) & 0xFF

            # Encode J-type instruction
            word =  (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd  << 7) | opcode          


    return word


# main function that loops every line of the input .s file, and calls assemble_instr in each iteration

def main(src_s_file, out_hex_file):
    with open(src_s_file) as src:
        with open(out_hex_file, "w") as out:
            for line in src:
                line = line.split("#")[0].strip()
                if line == "":              
                    continue
                word = assemble_instr(line)
                out.write(f"{word:08x}\n")


# script to call main function in command (.s input file, .hex out file)
# you only put .s file and it brings you .hex file in the same folder

# example: py asm.py "C:\Users\programs\program_test.s"

src = sys.argv[1]
out = src.replace(".s", ".hex")
main(src, out)