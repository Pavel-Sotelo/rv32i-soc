`timescale 1ns / 1ps

module register_file(

    input logic clk,
    input logic reset,

    input logic [4:0] rs1,    
    input logic [4:0] rs2,
    input logic write_enable,
    input logic [31:0] write_value, 
    input logic [4:0] rd,
    
    output logic [31:0] out_rs1,
    output logic [31:0] out_rs2
    
    );
    
    //MATRIX REGISTER: 32 registers, each one holding a 32-bit number (32x32)
    logic [31:0] register [31:0];
    
    //read registers, x0 forced to read 0, ISA RISC-V specification
    assign out_rs1 = (rs1 == 5'b0)? 32'b0 : register [rs1];
    assign out_rs2 = (rs2 == 5'b0)? 32'b0 : register [rs2];
    
    always_ff @(posedge clk) begin
    
        //reset is for waverform purposes , to start all register values to 0 and not X's
        if(reset) begin
          
          for(int i = 0; i < 32; i = i + 1) 
                register[i] <= 32'b0;   
                
        end else if (write_enable) begin
    
            register[rd] <= write_value;
 
        end
    
    end

endmodule