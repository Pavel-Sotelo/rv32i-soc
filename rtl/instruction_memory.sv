`timescale 1ns / 1ps

module instruction_memory #(
    parameter string PROGRAM = "program_5_3.hex"   //modifiable parameter if we want to change to another program in the testbench
)(

    input logic clk,
    input logic [31:0] addr,
    output logic [31:0] instruction      
    
    );
    
    //set of instructions
    logic [31:0] memory [255:0];
    
    //load parameter .hex file to load a program
    //initial indicates that the program runs once at the very start
    initial $readmemh(PROGRAM, memory);
    
    
    //Register output: the instruction memory has 256 words in total (8 bits).
    //The address works with 4 multipliers, but the instruction memory is 0,1,2,3...
    //so we cut the lower 2 bits (divide by 4 in binary) to match both instructions. we set another 2 upper bits to finish the cut lower bits    
    always_ff @(posedge clk) instruction <= memory[addr[9:2]];

endmodule
