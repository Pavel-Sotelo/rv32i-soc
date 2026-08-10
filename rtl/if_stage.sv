`timescale 1ns / 1ps

module if_stage#(
    parameter string PROGRAM = "program_add_5_3.hex"
)(

    input logic clk,    
    input logic reset,  
    input logic use_target,
    input logic [31:0] pc_target,
    input logic stall,
    
    output logic [31:0] out_instruction,
    output logic [31:0] out_current_pc,
    output logic [31:0] out_current_pc_plus_4

    );
    
    logic [31:0] current_pc;
    logic [31:0] next_pc;
    logic [31:0] current_pc_plus_4;
    
    assign current_pc_plus_4 = current_pc + 32'd4; 
    assign next_pc = use_target? pc_target : current_pc_plus_4;
    
    always_ff @(posedge clk) begin
 
        if(reset) begin

            out_current_pc <= 32'd0;
            out_current_pc_plus_4 <= 32'd4;

        end else if (~stall) begin

            out_current_pc <= current_pc;
            out_current_pc_plus_4 <= current_pc_plus_4;

        end

     end

    pc program_counter (
    
        .clk(clk),  
        .reset(reset),
        .next_pc(next_pc),
        .stall(stall),
        .out_pc(current_pc)
    
    );   
    
    instruction_memory #(
        .PROGRAM(PROGRAM)
    ) 
    imem (
    
        .clk(clk),
        .addr(current_pc),
        .instruction(out_instruction)
    
    );    
     
endmodule
