`timescale 1ns / 1ps

module forwarding_unit(

    //Inputs
        input logic [4:0] id_ex_rs1,
        input logic [4:0] id_ex_rs2,
        input logic [4:0] ex_wb_rd,
        input logic ex_wb_reg_write,

    //Outputs        
        output logic forward_rs1,
        output logic forward_rs2

    );
    
    // 1-back hazard forwarding module
    
    assign forward_rs1 = ex_wb_reg_write && (ex_wb_rd != 5'b0) && (ex_wb_rd == id_ex_rs1);
    assign forward_rs2 = ex_wb_reg_write && (ex_wb_rd != 5'b0) && (ex_wb_rd == id_ex_rs2);    
        
endmodule
