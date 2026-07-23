`timescale 1ns / 1ps

module if_stage#(
    parameter string PROGRAM = "program_add_5_3.hex"
)(

    input logic clk,    
    input logic reset,  
    input logic use_target,
    input logic [31:0] pc_target,
    
    output logic [31:0] instruction,
    output logic [31:0] out_current_pc

    );
    
    logic [31:0] current_pc;
    logic [31:0] next_pc;
    
    
    assign next_pc = use_target? pc_target : (current_pc + 32'd4);
    
    always_ff @(posedge clk) begin
 
        if(reset)
            out_current_pc <= 32'd0;    
        else
            out_current_pc <= current_pc; 
     end

    pc program_counter (
    
        .clk(clk),  
        .reset(reset),
        .next_pc(next_pc),
        .out_pc(current_pc)
    
    );   
    
    instruction_memory #(
        .PROGRAM(PROGRAM)
    ) 
    imem (
    
        .clk(clk),
        .addr(current_pc),
        .instruction(instruction)
    
    );    
     
endmodule
