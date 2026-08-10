`timescale 1ns / 1ps

module ex_stage(

    input logic clk,

    //Inputs

        //Forwarding input signals:
        
        input logic forward_rs1,
        input logic forward_rs2,
        input logic [31:0] forward_value,
            
        //Normal inputs: 
        
        input logic [31:0] reg_value_1,          
        input logic [31:0] reg_value_2,        
        
        input logic [31:0] immediate,          
        
        input logic [4:0] rd,           
       
        //input to evaluate result of a branch instruction
        input logic [2:0] funct3,
    
        input logic reg_write,              
        input logic reg_or_imm,              
        input logic [3:0] alu_op,            
        //read_mem is not necessary in EX stage (see design_notes)              
        input logic write_mem,               
        input logic [1:0] write_back_src,    
        input logic branch,                  
        input logic jump,
        
        input logic [31:0] current_pc,
        input logic [31:0] current_pc_plus_4,
        
    //Outputs

        output logic out_reg_write,
        output logic  [4:0] out_rd,  
        output logic  [1:0] out_write_back_src,
        
        //Output forwarded rs2 to feed write_data to AXI4-Lite UART
        output logic [31:0] out_forwarded_rs2,
        
        output logic out_use_target,
        output logic [31:0] out_pc_target,
        
        output logic [31:0] out_alu_result,
        output logic [31:0] out_d_mem_read_data,
        //EX is where current_pc gets worked (PC + immediate for branch and jump targets),
        //so it doesn't need to get outputted again.
        output logic [31:0] out_current_pc_plus_4,
        
        
    //UART flag address
            
        output logic out_is_uart           

    );
    

    //Drive general outputs to wb
    
        assign out_reg_write = reg_write;
        assign out_rd = rd;
        assign out_write_back_src = write_back_src;
        assign out_current_pc_plus_4 = current_pc_plus_4;
    
    
    //forward_value is wb_write_value, already muxed by write_back_src, so it is
    //correct for ALU results, loads (data_memory) and JAL return addresses
        
        assign out_forwarded_rs2 = forward_rs2 ? forward_value : reg_value_2; 
    
    
    //ALU operands logic
    
        logic [31:0] alu_first_operand;
        logic [31:0] alu_second_operand;
        
        assign alu_first_operand = forward_rs1 ? forward_value : reg_value_1;
        //forwarding applies only when the operand is a register, so reg_or_imm selects first
        assign alu_second_operand = reg_or_imm? out_forwarded_rs2 : immediate;
    
    
    //Branch/jump logic
    
        logic take_branch;
        
        //Branch/jump flag, driven by branch_unit(take_branch) or jump
        assign out_use_target = take_branch | jump;
        
        //branch/jump adder (ALU already performs SUB on branch, so we need another adder for PC + imm)
        assign out_pc_target  = current_pc + immediate;
    
    
    //UART address flag signal
    
        assign out_is_uart = out_alu_result[12];
    


    //Instantiations:

    alu alu_inst (
    
        .a(alu_first_operand),
        .b(alu_second_operand),
        
        .operation(alu_op),
        .result(out_alu_result)
    
    );
    
    //Currently branch_unit only drives beq and bne
    branch_unit branch_unit_inst (
    
        .alu_result(out_alu_result),
        .branch(branch),
        .funct3(funct3),
        
        .take_branch(take_branch)
        
    );
       
 
    data_memory data_memory_inst (
    
        .clk(clk),
        .addr(out_alu_result),
        .write_enable(write_mem & (~out_is_uart)),
        .write_data(out_forwarded_rs2),
        .read_data(out_d_mem_read_data)
    
    );


endmodule
