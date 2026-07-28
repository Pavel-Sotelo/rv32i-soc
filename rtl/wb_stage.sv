`timescale 1ns / 1ps

module wb_stage(

    //Inputs

        input logic reg_write,
        input logic  [4:0] rd,
        
        //00 if value written to the register is ALU result, 01 if it's a read value from data memory, 11 if it's PC + 4 (return address) 
        input logic  [1:0] write_back_src,
        
        input logic [31:0] alu_result,
        input logic [31:0] d_mem_read_data,
        input logic [31:0] current_pc_plus_4,                  

    //Outputs

        output logic out_wb_write_enable,
        output logic [4:0] out_wb_rd,
        output logic [31:0] out_wb_write_value
        
    );
    
    assign out_wb_write_enable = reg_write;
    assign out_wb_rd = rd;
    
    always_comb begin
       
            case(write_back_src)
            
                //rd is ALU result
                2'b00: out_wb_write_value = alu_result; 
                
                //rd is data memory value (lw)
                2'b01: out_wb_write_value = d_mem_read_data;
            
                //rd is return address of jal (PC + 4)
                2'b11: out_wb_write_value = current_pc_plus_4;
            
                default: out_wb_write_value = 32'dx; //x to see for a bug in waveform, instead of 0 (legitimate value)      
            endcase
           
    end
 
endmodule
