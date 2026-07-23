`timescale 1ns / 1ps

module control_unit(

        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input logic funct7,        //funct7[5] (1-bit signal)
        
        output logic reg_write,               //1 for write result in a register, 0 if not
        output logic reg_or_imm,              //1 if 2nd ALU operand is a register, 0 if it's an immediate
        output logic [3:0] alu_op,            //4 bit ALU operation 
        output logic read_mem,                //1 if instruction reads memory, 0 if not
        output logic write_mem,               //1 if instruction writes memory, 0 if not
        output logic [1:0] write_back_src,    //00 if value written to the register is ALU result, 01 if it's the value from memory, 11 if it's PC + 4 (jal)
        output logic branch,                  //1 if it's branch instruction, 0 if not
        output logic jump                     //1 if it's jump instruction, 0 if not

    );
    
    always_comb begin
    
        case(opcode)
    
            //OPCODE 3 DECIMAL (I-TYPE, LOAD)
            7'h03: begin
                        reg_write = 1;       
                        reg_or_imm = 0;
                        alu_op = 4'b0000; //ADD operation (Register value + immediate = memory address)
                        read_mem = 1;
                        write_mem = 0;
                        write_back_src = 2'b01;
                        branch = 0;
                        jump = 0;            
                     end        
    
            //OPCODE 19 DECIMAL (I-TYPE, ARITHMETIC)
            7'h13: begin
                        reg_write = 1;       
                        reg_or_imm = 0;
                        
                        if (funct3 == 3'b101)
                            alu_op = {funct7, funct3};  //srli/srai needs funct7 to select one of them
                        else
                            alu_op = {1'b0, funct3};   //otherwise bit 30 is imm data, not funct7 , must be forced to 0           
                     
                        read_mem = 0;
                        write_mem = 0;
                        write_back_src = 2'b00;
                        branch = 0;
                        jump = 0;            
                     end  
                     
            //OPCODE 35 DECIMAL (S-TYPE, STORE)             
            7'h23: begin
                        reg_write = 0;       
                        reg_or_imm = 0;
                        alu_op =  4'b0000; 
                        read_mem = 0;
                        write_mem = 1;
                        write_back_src = 2'b00; //don't care
                        branch = 0;
                        jump = 0;            
                     end     
    
            //OPCODE 51 DECIMAL (R-TYPE)             
            7'h33: begin
                        reg_write = 1;       
                        reg_or_imm = 1;
                        alu_op = {funct7, funct3}; 
                        read_mem = 0;
                        write_mem = 0;
                        write_back_src = 2'b00;
                        branch = 0;
                        jump = 0;            
                     end        
    
    
            //OPCODE 55 DECIMAL (U-TYPE, only lui)             
            7'h37: begin
                        reg_write = 1;       
                        reg_or_imm = 0;
                        alu_op = 4'b0000; //no ALU operation, default zero
                        read_mem = 0;
                        write_mem = 0;
                        write_back_src = 2'b00;
                        branch = 0;
                        jump = 0;            
                     end        
        
            //OPCODE 99 DECIMAL (B-TYPE, Branch)             
            7'h63: begin
                        reg_write = 0;       
                        reg_or_imm = 0;
                        alu_op = 4'b1000; //equal is derived by rs1 - rs2 == 0
                        read_mem = 0;
                        write_mem = 0;
                        write_back_src = 2'b00; //don't care
                        branch = 1;
                        jump = 0;            
                     end            
    
            //OPCODE 111 DECIMAL (J-TYPE, only jal)             
            7'h6F: begin
                        reg_write = 1;       
                        reg_or_imm = 0;
                        alu_op = 4'b0000; //ADD: PC + Offset (imm)
                        read_mem = 0;
                        write_mem = 0;
                        write_back_src = 2'b11;
                        branch = 0;
                        jump = 1;            
                     end            
    
         default: begin
                        reg_write = 0;       
                        reg_or_imm = 0;
                        alu_op = 4'b0000; 
                        read_mem = 0;
                        write_mem = 0;
                        write_back_src = 2'b00;
                        branch = 0;
                        jump = 0;              
                  end
    
        endcase
    
    end   
    
endmodule
