`timescale 1ns / 1ps

module id_stage(

    //Inputs
    
        input logic clk,
        input logic reset,
        
        input logic [31:0] instruction,
        input logic [31:0] current_pc,
        
        //instantiation of register_file in ID to get the 2 reads locally and get only the write of WB
        //(instead of instantiating regiter_file on WB and having to send 2 reads externally)
        input logic wb_write_enable,
        input logic [31:0] wb_write_value,
        input logic [4:0] wb_rd,
        
        
    //Outputs
    
        output logic [31:0] reg_value_1,
        output logic [31:0] reg_value_2,
        
        output logic [31:0] immediate,
        
        output logic [4:0] rd,
       
        //Output to evaluate result of a branch instruction
        output logic [2:0] out_funct3,
    
        output logic reg_write,              
        output logic reg_or_imm,              
        output logic [3:0] alu_op,            
        output logic read_mem,                
        output logic write_mem,               
        output logic [1:0] write_back_src,    
        output logic branch,                  
        output logic jump,
        
        output logic [31:0] out_current_pc    
    
    );

    assign out_current_pc = current_pc;
    assign out_funct3 = instruction[14:12];
    assign rd = instruction[11:7];
    
  
    register_file reg_file (
    
        .clk(clk),
        .reset(reset),
        .rs1(instruction[19:15]),
        .rs2(instruction[24:20]),
        .write_enable(wb_write_enable),
        .write_value(wb_write_value),
        .rd(wb_rd),
        .out_rs1(reg_value_1),
        .out_rs2(reg_value_2)

    );
    
    control_unit c_unit (
    
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .funct7(instruction[30]),
        
        .reg_write(reg_write),
        .reg_or_imm(reg_or_imm),
        .alu_op(alu_op),
        .read_mem(read_mem),
        .write_mem(write_mem),
        .write_back_src(write_back_src),
        .branch(branch),
        .jump(jump)
        
    );
    
    
    immediate_generator imm_gen (
    
        .instruction(instruction),
        .imm(immediate)        
        
    );        

    
endmodule
