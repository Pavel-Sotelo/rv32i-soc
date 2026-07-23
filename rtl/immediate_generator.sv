`timescale 1ns / 1ps

module immediate_generator(

    input logic [31:0] instruction,
    output logic [31:0] imm

    );
    
    always_comb begin
    
        //opcode instruction format case
        case(instruction[6:0])
    
        //Sign-extended immediate:
    
            //I-Type:
            7'h03, 7'h13: imm = { {20{instruction[31]}} , instruction[31:20] }; 
            
            //U-Type (upper immediate, NO sign-extend):
            7'h17, 7'h37: imm = {instruction[31:12], 12'b0 };
    
            //S-Type
            7'h23: imm = { {20{instruction[31]}} , instruction[31:25] , instruction[11:7] };
            
            //R-Type has no immediate format
            
            //B-Type (LSB is always zero in even addresses):
            7'h63: imm = { {19{instruction[31]}} , instruction[31] , instruction[7] , instruction[30:25] , instruction[11:8] , 1'b0};
            
            //J-Type
            7'h6F: imm = { {12{instruction[31]}} , instruction[31] , instruction[19:12] , instruction[20] , instruction[30:21] , 1'b0};
            
            //default invalid opcode
            default: imm = 32'h0;                         
    
        endcase
    end    
    
endmodule
