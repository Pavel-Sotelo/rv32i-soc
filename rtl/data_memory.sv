`timescale 1ns / 1ps

module data_memory(

        input logic clk,
        input logic [31:0] addr,
        input logic write_enable,
        input logic [31:0] write_data,

        output logic [31:0] read_data
        
    );
    
    logic [31:0] d_memory [255:0];
    
    always_ff @(posedge clk) begin
    
    //The address works with 4 multipliers (byte addresses), but the instruction memory is 0,1,2,3 (word addresses , occupies 4 bytes)
    //so we cut the lower 2 bits (divide by 4 in binary) to match both instructions. we set another 2 upper bits to finish the cut lower bits

        //read data memory (synchronous read)
        read_data <= d_memory[addr[9:2]];
    
        //write into data memory (synchronous as well)
        if(write_enable) begin
        
            d_memory[addr[9:2]] <= write_data;

        end

    end
     
endmodule
