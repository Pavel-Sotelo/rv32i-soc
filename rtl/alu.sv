`timescale 1ns / 1ps

module alu(

    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0] operation,
    output logic [31:0] result

);

    always_comb begin    

        case (operation)
        
            //add
            4'b0000: result = a + b;
            //sub            
            4'b1000: result = a - b;
            //sll        
            4'b0001: result = a << b[4:0];
            //slt
            4'b0010: result = ($signed(a) < $signed(b))? 32'b1 : 32'b0; 
            //sltu
            4'b0011: result = a < b? 32'b1 : 32'b0;
            //xor
            4'b0100: result = a ^ b; 
            //srl
            4'b0101: result = a >> b[4:0];            
            //sra
            4'b1101: result = $signed(a) >>> b[4:0];
            //or
            4'b0110: result = a | b;
            //and
            4'b0111: result = a & b; 

            default: result = 32'd0;
        endcase
    end

endmodule