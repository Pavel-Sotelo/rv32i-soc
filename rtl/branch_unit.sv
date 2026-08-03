`timescale 1ns / 1ps

module branch_unit(

    input logic [31:0] alu_result,
    input logic branch,
    input logic [2:0] funct3,
    
    output logic take_branch

    );
    
    always_comb begin
    
        if(branch) begin
    
            case(funct3)
        
                3'b000: take_branch = alu_result == 32'd0;   //beq
                3'b001: take_branch = alu_result != 32'd0;   //bne
    
                default: take_branch = 1'b0;    
            endcase
    
        end else begin
            take_branch = 1'b0;  
        end
       
    end
 
endmodule
