`timescale 1ns / 1ps

module pc(

    input logic clk,
    input logic reset,
    input logic [31:0] next_pc,
    input logic stall,
    output logic [31:0] out_pc

);

    always_ff @(posedge clk) begin
    
        if(reset)
            out_pc <= 32'd0;
        else if (~stall)
            out_pc <= next_pc;
    
    end

endmodule
