#include <stdio.h>
#include <stdint.h> //to use uint32_t (32 bit width unsigned integer)


//CPUState struct
typedef struct {

    uint32_t regs [32];     //32 registers (x0 to x31)
    uint32_t pc;            //Program Counter (PC)
    uint32_t imem [256];    //Instruction memory with 256 words
     uint8_t dmem [1024];   //Data memory, 1024 bytes
    uint32_t program_size;  //store the number of instructions the program has

} CPUState;

//decode slicing for all instruction formats
typedef struct {

    uint32_t opcode, rd, funct3, rs1, rs2, funct7;
    int32_t imm;    

} DecodeInstruction;


//prototypes
void load_program_add_5_3(CPUState *cpu);
void load_program_6_instr(CPUState *cpu);
uint32_t fetch(CPUState *cpu);
uint32_t decode_opcode(uint32_t instruction);
void decode_r_type(uint32_t instruction, DecodeInstruction *decode);
void decode_i_type(uint32_t instruction, DecodeInstruction *decode);
void decode_s_type(uint32_t instruction, DecodeInstruction *decode);
void decode_u_type(uint32_t instruction, DecodeInstruction *decode);
void execute_r_type(DecodeInstruction *decode, CPUState *cpu);
void execute_i_type_load(DecodeInstruction *decode, CPUState *cpu);
void execute_s_type(DecodeInstruction *decode, CPUState *cpu);
void execute_u_type_lui(DecodeInstruction *decode, CPUState *cpu);
void execute_i_type_arithmetic(DecodeInstruction *decode, CPUState *cpu);




//main function

int main ()
{
    //declarations

    uint32_t instruction = 0;
    uint32_t t_format = 0;
    int instruction_count = 0;
    CPUState cpu_state = {0};
    DecodeInstruction decode_instruction = {0};
    

    //load the program (hex instructions)

    load_program_6_instr(&cpu_state);

    for(uint32_t i = 0; i < cpu_state.program_size; i++)
    {
        printf("\nimem[%d] holds the 32-bit instruction: %08x", i, cpu_state.imem[i]);
    }
    printf("\n");

    //PC Cycle
    cpu_state.pc = 0;
    while(cpu_state.pc < cpu_state.program_size * 4)
    {


        //Fetch


        instruction = fetch(&cpu_state);
        printf("\nPC Address %d - Instruction %d: %08x", cpu_state.pc, (cpu_state.pc/4), instruction);
        


        //Decode


        t_format = decode_opcode(instruction);

        switch(t_format)
        {
            //R-Type
            case 0x33:
                decode_r_type(instruction, &decode_instruction);
                printf("\nDecode R-Type completed. - opcode = %d - rd = x%d - funct3 = %d - rs1 = x%d - rs2 = x%d - funct7 = %d\n"
                , decode_instruction.opcode, decode_instruction.rd, decode_instruction.funct3, decode_instruction.rs1, decode_instruction.rs2, decode_instruction.funct7);               
            break;

            //I-Type (for both I-type load and arithmetic)
            case 0x03:
            case 0x13:
                decode_i_type(instruction, &decode_instruction);
                printf("\nDecode I-Type completed. - opcode = %d - rd = x%d - funct3 = %d - rs1 = x%d - imm = %d\n"
                , decode_instruction.opcode, decode_instruction.rd, decode_instruction.funct3, decode_instruction.rs1, decode_instruction.imm);               
            break;               

            //S-Type
            case 0x23:
                decode_s_type(instruction, &decode_instruction);
                printf("\nDecode S-Type completed. - opcode = %d - imm = %d - funct3 = %d - rs1 = x%d - rs2 = x%d\n"
                , decode_instruction.opcode, decode_instruction.imm, decode_instruction.funct3, decode_instruction.rs1, decode_instruction.rs2);               
            break;
            
            //U-Type
            case 0x37:
                decode_u_type(instruction, &decode_instruction);
                printf("\nDecode U-Type completed. - opcode = %d - rd = x%d - imm = %d\n"
                , decode_instruction.opcode, decode_instruction.rd, decode_instruction.imm);               
            break;            


            default:
                printf("\nopcode doesn't match any instruction format - Error.");
                return 0;
            break;

        }


        //we put the pc incrementer here, in case an execute wants to overwrite it (branch)
        cpu_state.pc += 4; 



        //Execute


        switch(t_format)
        {
            //R-Type
            case 0x33:
                execute_r_type(&decode_instruction, &cpu_state);
                printf("rd = x%d now holds the number %u\n", decode_instruction.rd, cpu_state.regs[decode_instruction.rd]);                  
            break;

            //I-Type arithmetic
            case 0x13:
                execute_i_type_arithmetic(&decode_instruction, &cpu_state);
                printf("rd = x%d now holds the number %u\n", decode_instruction.rd, cpu_state.regs[decode_instruction.rd]);                   
            break; 

            //I-Type load
            case 0x03:
                execute_i_type_load(&decode_instruction, &cpu_state);
                printf("rd = x%d now holds the data memory number: %u\n", decode_instruction.rd, cpu_state.regs[decode_instruction.rd]);                   
            break;

            //S-Type
            case 0x23:
                execute_s_type(&decode_instruction, &cpu_state);
                printf("dmem[%u] now holds the 32-bit number of rs2 (%x)\n", cpu_state.regs[decode_instruction.rs1] + decode_instruction.imm, cpu_state.regs[decode_instruction.rs2]);                   
            break;

            //U-Type (lui)
            case 0x37:
                execute_u_type_lui(&decode_instruction, &cpu_state);
                printf("rd = x%d now holds upper immediate: %u\n", decode_instruction.rd, cpu_state.regs[decode_instruction.rd]);                   
            break;            


            default:
                printf("\nopcode doesn't match any instruction format - Error.");
                return 0;
            break;

        } 
    
        //count the number of instructions the ISS has done, for now we'll just put a 10,000 limit
        instruction_count++;
        if(instruction_count > 10000)
        {
            printf("Intruction limit reached (%d instructions) at PC = %d - Possible infinite loop. Exiting...", instruction_count, cpu_state.pc);        
            break;
        }


        //hardwire x0 to 0 always
        cpu_state.regs[0] = 0;    
    }

return 0;
}











//functions


    //load program_add_5_3 to the instruction memory
    void load_program_add_5_3(CPUState *cpu)
    {

        cpu->imem[0] = 0x00500093;    
        cpu->imem[1] = 0x00300113; 
        cpu->imem[2] = 0x002081b3;

        //store the number of instructions
        cpu->program_size = 3;
    }


    //load program_6_instr to the instruction memory
    void load_program_6_instr(CPUState *cpu)
    {

        cpu->imem[0] = 0x123452b7;    
        cpu->imem[1] = 0x67828293; 
        cpu->imem[2] = 0x00800093;
        cpu->imem[3] = 0x005081b3;    
        cpu->imem[4] = 0x0030a023; 
        cpu->imem[5] = 0x0000a203;


        //store the number of instructions
        cpu->program_size = 6;
    }



    //fetch
    uint32_t fetch(CPUState *cpu)
    {
        return cpu->imem[(cpu->pc)/4];
    }

    //decode opcode to know the type format
    uint32_t decode_opcode(uint32_t instruction)
    {
        return (instruction & 0x7F);         
    }



    //decode an r_type instruction
    void decode_r_type(uint32_t instruction, DecodeInstruction *decode)
    {
        //opcode
        decode->opcode = instruction & 0x7F;
        //rd
        decode->rd = (instruction >> 7) & 0x1F;
        //funct3
        decode->funct3 = (instruction >> 12) & 0x7;
        //rs1
        decode->rs1 = (instruction >> 15) & 0x1F;
        //rs2
        decode->rs2 = (instruction >> 20) & 0x1F;
        //funct7
        decode->funct7 = (instruction >> 25);                 
    }



    //decode an I_type instruction
    void decode_i_type(uint32_t instruction, DecodeInstruction *decode)
    {
        //opcode
        decode->opcode = instruction & 0x7F;
        //rd
        decode->rd = (instruction >> 7) & 0x1F;
        //funct3
        decode->funct3 = (instruction >> 12) & 0x7;
        //rs1
        decode->rs1 = (instruction >> 15) & 0x1F;
        //imm (casted to signed for the >> to extend its sign bit)
        decode->imm = (int32_t)(instruction) >> 20;
        //funct7 (for SRAi)
        decode->funct7 = (instruction >> 25);              
    }



    //decode an s_type instruction
    void decode_s_type(uint32_t instruction, DecodeInstruction *decode)
    {
        //opcode
        decode->opcode = instruction & 0x7F;
        //imm
        decode->imm = (int32_t)( ( ((instruction >> 7) & 0x1F) | ((instruction >> 20) & 0xFE0) ) << 20 ) >> 20;              
        //funct3
        decode->funct3 = (instruction >> 12) & 0x7;
        //rs1
        decode->rs1 = (instruction >> 15) & 0x1F;
        //rs2
        decode->rs2 = (instruction >> 20) & 0x1F;
   
    }    



    //decode a u_type instruction
    void decode_u_type(uint32_t instruction, DecodeInstruction *decode)
    {
        //opcode
        decode->opcode = instruction & 0x7F;
        //rd
        decode->rd = (instruction >> 7) & 0x1F;
        //imm (without sign-extend, bit 31 is already in the upper immediate)
        decode->imm = instruction & 0xFFFFF000;              
    }



    //execute an r_type instruction
    void execute_r_type(DecodeInstruction *decode, CPUState *cpu)
    {
        switch(decode->funct3)
        {
            //ADD and SUB (same funct3, differ by funct7)  
            case 0x0:

                if(decode->funct7 == 0x20)
                {
                    cpu->regs[decode->rd] = cpu->regs[decode->rs1] - cpu->regs[decode->rs2];        
                }
                else if (decode->funct7 == 0x0)
                {
                    cpu->regs[decode->rd] = cpu->regs[decode->rs1] + cpu->regs[decode->rs2];    
                } 
                else
                {
                    printf("\nfunct7 ERROR in ADD/SUB"); 
                    return;
                }
            break;

            //SLL
            case 0x1: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] << (cpu->regs[decode->rs2] & 0x1F);
            break;

            
            //SLT (Signed)
            case 0x2: {
                cpu->regs[decode->rd] = ((int32_t)cpu->regs[decode->rs1]) < ((int32_t)cpu->regs[decode->rs2]);
            break;
            }

            //SLTU (Unsigned)
            case 0x3: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] < cpu->regs[decode->rs2]; 
            break;            
   
            //XOR
            case 0x4: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] ^ cpu->regs[decode->rs2]; 
            break;
            
            //SRL and SRA (same funct3, differ by funct7)  
            case 0x5: {

                //SRA
                if(decode->funct7 == 0x20)
                {   
                    cpu->regs[decode->rd] = ((int32_t)cpu->regs[decode->rs1]) >> (cpu->regs[decode->rs2] & 0x1F);        
                }
                //SRL
                else if (decode->funct7 == 0x0)
                {
                    cpu->regs[decode->rd] = cpu->regs[decode->rs1] >> (cpu->regs[decode->rs2] & 0x1F);    
                } 
                else
                {
                    printf("\nfunct7 ERROR in SRL/SRA"); 
                    return;
                }
            break;
            }

            //OR
            case 0x6: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] | cpu->regs[decode->rs2]; 
            break;            
            
            //AND
            case 0x7: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] & cpu->regs[decode->rs2]; 
            break;     

        }
    }



    //execute an I_type load instruction
    void execute_i_type_load(DecodeInstruction *decode, CPUState *cpu)
    {
        switch(decode->funct3)
        {
            //lw
            case 0x2: {
                        uint32_t address = decode->imm + cpu->regs[decode->rs1];

                        if(address + 3 < 1024) {

                            cpu->regs[decode->rd] = (uint32_t)cpu->dmem[address]             |
                                                    ((uint32_t)cpu->dmem[address + 1] << 8)  |  
                                                    ((uint32_t)cpu->dmem[address + 2] << 16) |
                                                    ((uint32_t)cpu->dmem[address + 3] << 24);
                        } else 
                        {
                            printf("load out of bounds (+1024) at address %u\n", address); return;      
                        }                                                                         
            break;
            }

            default:
                printf("funct3 I-type load doesn't match any instruction - Error."); 
            return;

        }
    }



    //execute an S_type instruction
    void execute_s_type(DecodeInstruction *decode, CPUState *cpu)
    {
        switch(decode->funct3)
        {
            //sw
            case 0x2: {
                        uint32_t address = decode->imm + cpu->regs[decode->rs1];

                        if(address + 3 < 1024) {

                            cpu->dmem[address] = cpu->regs[decode->rs2]           & 0xFF;
                            cpu->dmem[address + 1] = (cpu->regs[decode->rs2] >>  8) & 0xFF;
                            cpu->dmem[address + 2] = (cpu->regs[decode->rs2] >> 16) & 0xFF;
                            cpu->dmem[address + 3] = (cpu->regs[decode->rs2] >> 24) & 0xFF; 

                        } else 
                        {
                            printf("write out of bounds (+1024) at address %u\n", address); return;      
                        }  
            break;
            }
            default:
                printf("funct3 S-type doesn't match any instruction - Error."); 
            return;

        }
    }



    //execute a u_type lui instruction
    void execute_u_type_lui(DecodeInstruction *decode, CPUState *cpu)
    {
        cpu->regs[decode->rd] = decode->imm;    
    }
    
    

    //execute an I_type arithmetic instruction
    void execute_i_type_arithmetic(DecodeInstruction *decode, CPUState *cpu)
    {
        switch(decode->funct3)
        {
            //ADDi
            case 0x0:
                    cpu->regs[decode->rd] = cpu->regs[decode->rs1] + decode->imm;    
            break;

            //SLLi
            case 0x1:           
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] << (decode->imm & 0x1F);
            break;

            
            //SLTi (Signed)
            case 0x2: 
                cpu->regs[decode->rd] = ((int32_t)cpu->regs[decode->rs1]) < decode->imm;
            break;
            

            //SLTiU (Unsigned)
            case 0x3: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] < (uint32_t)decode->imm; 
            break;            
   
            //XORi
            case 0x4: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] ^ decode->imm; 
            break;
            
            //SRLi and SRAi (same funct3, differ by funct7)  
            case 0x5: 

                //SRAi
                if(decode->funct7 == 0x20)
                {   
                    cpu->regs[decode->rd] = ((int32_t)cpu->regs[decode->rs1]) >> (decode->imm & 0x1F);        
                }
                //SRLi
                else if (decode->funct7 == 0x0)
                {
                    cpu->regs[decode->rd] = cpu->regs[decode->rs1] >> (decode->imm & 0x1F);    
                } 
                else
                {
                    printf("\nfunct7 ERROR in SRLi/SRAi"); 
                    return;     
                }
            break;
            

            //ORi
            case 0x6: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] | decode->imm; 
            break;            
            
            //ANDi
            case 0x7: 
                cpu->regs[decode->rd] = cpu->regs[decode->rs1] & decode->imm; 
            break;     

        }
    }