`timescale 1ns / 1ps

module ex_stage(

    input logic clk,

    //Inputs

        input logic [31:0] reg_value_1,          
        input logic [31:0] reg_value_2,        
        
        input logic [31:0] immediate,          
        
        input logic [4:0] rd,           
       
        //input to evaluate result of a branch instruction
        input logic [2:0] funct3,
    
        input logic reg_write,              
        input logic reg_or_imm,              
        input logic [3:0] alu_op,            
        //read_mem is not necessary in EX stage (see design_notes)              
        input logic write_mem,               
        input logic [1:0] write_back_src,    
        input logic branch,                  
        input logic jump,
        
        input logic [31:0] current_pc,
        input logic [31:0] current_pc_plus_4,
        
    //Outputs

        output logic out_reg_write,
        output logic  [4:0] out_rd,  
        output logic  [1:0] out_write_back_src,
        
        output logic [31:0] alu_result,
        output logic [31:0] d_mem_read_data,
        //EX is where current_pc gets worked (PC + immediate for branch and jump targets) so it doesn't need to get outputted again
        output logic [31:0] out_current_pc_plus_4           

    );

    assign out_reg_write = reg_write;
    assign out_rd = rd;
    assign out_write_back_src = write_back_src;
    assign out_current_pc_plus_4 = current_pc_plus_4;

    //ALU second operand logic
    logic [31:0] alu_second_operand;
    assign alu_second_operand = reg_or_imm? reg_value_2 : immediate; 


    alu alu_inst (
    
        .a(reg_value_1),
        .b(alu_second_operand),
        
        .operation(alu_op),
        .result(alu_result)
    
    );
    
    data_memory data_memory_inst (
    
        .clk(clk),
        .addr(alu_result),
        .write_enable(write_mem),
        .write_data(reg_value_2),
        .read_data(d_mem_read_data)
    
    );


endmodule
