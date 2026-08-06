`timescale 1ns / 1ps

module rv32i_top #(
    
    parameter string PROGRAM = "program_forwarding.hex"
    
    )(

    input logic clk,
    input logic reset,
    
    //debug output: without an observable port, implementation deletes the design
    output logic [15:0] led
    
    ); 

    //CPU 4-stage internal output signals:

    //if_stage
    
        //outputs
            logic [31:0] if_instruction;
            logic [31:0] if_current_pc;
            logic [31:0] if_current_pc_plus_4;


    //id_stage     

        //outputs
            logic [4:0] id_rs1;       
            logic [4:0] id_rs2;          
            logic [31:0] id_reg_value_1;       
            logic [31:0] id_reg_value_2;           
            logic [31:0] id_immediate;       
            logic [4:0] id_rd;
            logic [2:0] id_funct3; 
            logic id_reg_write;             
            logic id_reg_or_imm;              
            logic [3:0] id_alu_op;            
            logic id_read_mem;                
            logic id_write_mem;              
            logic [1:0] id_write_back_src;    
            logic id_branch;                  
            logic id_jump;     
            logic [31:0] id_current_pc;
            logic [31:0] id_current_pc_plus_4;      
    
         //pipeline register outputs
            logic [4:0] id_ex_rs1;       
            logic [4:0] id_ex_rs2;           
            logic [31:0] id_ex_reg_value_1;       
            logic [31:0] id_ex_reg_value_2;           
            logic [31:0] id_ex_immediate;       
            logic [4:0] id_ex_rd;
            logic [2:0] id_ex_funct3; 
            logic id_ex_reg_write;             
            logic id_ex_reg_or_imm;              
            logic [3:0] id_ex_alu_op;                            
            logic id_ex_write_mem;              
            logic [1:0] id_ex_write_back_src;    
            logic id_ex_branch;                  
            logic id_ex_jump;     
            logic [31:0] id_ex_current_pc;
            logic [31:0] id_ex_current_pc_plus_4;    
            
               
    //ex_stage
                      
        //outputs
            logic ex_reg_write;
            logic  [4:0] ex_rd;  
            logic  [1:0] ex_write_back_src;
            logic [31:0] ex_alu_result;
            logic [31:0] ex_d_mem_read_data;
            logic [31:0] ex_current_pc_plus_4;           

        //outputs of EX -> IF, combinational (no flop, must arrive same cycle) 
            logic ex_if_use_target;
            logic [31:0] ex_if_pc_target;            

        //pipeline register outputs
            logic ex_wb_reg_write;
            logic  [4:0] ex_wb_rd;  
            logic  [1:0] ex_wb_write_back_src;
            logic [31:0] ex_wb_alu_result;
            logic [31:0] ex_wb_current_pc_plus_4;   
    
        
    
    //wb_stage                 
    
        //outputs
            logic wb_write_enable;
            logic [4:0] wb_rd;
            logic [31:0] wb_write_value;    
    
////////////////////////////////////////////////////////////////////////    


    //Signal to do the 2nd cycle-flush of a branch/jump instruction
    logic second_flush;
    
    
    //Signals for forwarding unit (1-back data hazard fix)
    logic forward_rs1;
    logic forward_rs2;


    //Assign led output that shows value's being written - only for synthesis purposes
    assign led = wb_write_value[15:0];


    //Pipeline output register boundary's
    always_ff @(posedge clk) begin
    
        //reset to avoid X's in simulation
        if (reset) begin
        
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;        
            id_ex_reg_value_1 <= 32'b0;
            id_ex_reg_value_2 <= 32'b0;
            id_ex_immediate <= 32'b0;
            id_ex_rd <= 5'b0;
            id_ex_funct3 <= 3'b0;
            second_flush <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_write_mem <= 1'b0;
            id_ex_reg_or_imm <= 1'b0;
            id_ex_alu_op <= 4'b0;
            id_ex_write_back_src <= 2'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_current_pc <= 32'b0;
            id_ex_current_pc_plus_4 <= 32'b0;
    
            ex_wb_reg_write <= 1'b0;
            ex_wb_rd <= 5'b0;
            ex_wb_write_back_src <= 2'b0;
            ex_wb_alu_result <= 32'b0;
            ex_wb_current_pc_plus_4 <= 32'b0;
        
        
        end else begin
        
                
            //Boundary 1: ID->EX 
            id_ex_rs1 <= id_rs1;
            id_ex_rs2 <= id_rs2;            
            id_ex_reg_value_1 <= id_reg_value_1;
            id_ex_reg_value_2 <= id_reg_value_2;
            id_ex_immediate <= id_immediate;
            id_ex_rd <= id_rd;
            id_ex_funct3 <= id_funct3;
            
            //Branch/jump 2-cycle flush
            second_flush <= ex_if_use_target; 
            id_ex_reg_write <= (ex_if_use_target | second_flush)? 1'b0 : id_reg_write;
            id_ex_write_mem <= (ex_if_use_target | second_flush)? 1'b0 : id_write_mem;
            
                  
            id_ex_reg_or_imm <= id_reg_or_imm;
            id_ex_alu_op <= id_alu_op;
            id_ex_write_back_src <= id_write_back_src;
            
            //A flushed instruction can still set use_target (redirecting a PC address that we NOT want)
            //so we set the same branch/jump 2-cycle flush logic too
            id_ex_branch <= (ex_if_use_target | second_flush)? 1'b0 : id_branch;
            id_ex_jump   <= (ex_if_use_target | second_flush)? 1'b0 : id_jump;
            
            
            id_ex_current_pc <= id_current_pc;
            id_ex_current_pc_plus_4 <= id_current_pc_plus_4;
            
            //Boundary 2: EX->WB
            ex_wb_reg_write <= ex_reg_write;
            ex_wb_rd <= ex_rd;
            ex_wb_write_back_src <= ex_write_back_src;
            ex_wb_alu_result <= ex_alu_result;
            ex_wb_current_pc_plus_4 <= ex_current_pc_plus_4;         

        end
        
    end
    

    //4-stage instantiations    
    
    
        //if_stage
        if_stage #(
            .PROGRAM(PROGRAM)
        ) if_inst (
        
            //inputs
            .clk(clk),
            .reset(reset),
            
            .use_target(ex_if_use_target),
            .pc_target(ex_if_pc_target),
            
            //outputs
            .out_instruction(if_instruction),
            .out_current_pc(if_current_pc),
            .out_current_pc_plus_4(if_current_pc_plus_4)
        
        );
        
    
        //id_stage
        id_stage id_inst (
    
            //inputs
            .clk(clk),
            .reset(reset),
            
            .instruction(if_instruction),
            .current_pc(if_current_pc),
            .current_pc_plus_4(if_current_pc_plus_4),
            .wb_write_enable(wb_write_enable),
            .wb_write_value(wb_write_value),
            .wb_rd(wb_rd),
        
            //outputs
            .out_rs1(id_rs1),
            .out_rs2(id_rs2),
            .out_reg_value_1(id_reg_value_1),
            .out_reg_value_2(id_reg_value_2),
            .out_immediate(id_immediate),
            .out_rd(id_rd),
            .out_funct3(id_funct3),
            .out_reg_write(id_reg_write),              
            .out_reg_or_imm(id_reg_or_imm),              
            .out_alu_op(id_alu_op),            
            .out_read_mem(id_read_mem),                
            .out_write_mem(id_write_mem),                
            .out_write_back_src(id_write_back_src),    
            .out_branch(id_branch),                  
            .out_jump(id_jump),
            .out_current_pc(id_current_pc),
            .out_current_pc_plus_4(id_current_pc_plus_4)    
        
        );    
    
          
            ex_stage ex_inst (
    
            //inputs
            .clk(clk),
    
            .forward_rs1(forward_rs1),
            .forward_rs2(forward_rs2),
            .forward_value(wb_write_value),
            .reg_value_1(id_ex_reg_value_1),          
            .reg_value_2(id_ex_reg_value_2),                    
            .immediate(id_ex_immediate),                    
            .rd(id_ex_rd),           
            .funct3(id_ex_funct3),
            .reg_write(id_ex_reg_write),              
            .reg_or_imm(id_ex_reg_or_imm),              
            .alu_op(id_ex_alu_op),                           
            .write_mem(id_ex_write_mem),                
            .write_back_src(id_ex_write_back_src),    
            .branch(id_ex_branch),                  
            .jump(id_ex_jump),
            .current_pc(id_ex_current_pc),
            .current_pc_plus_4(id_ex_current_pc_plus_4),
            
            //outputs
            .out_reg_write(ex_reg_write),
            .out_rd(ex_rd),  
            .out_write_back_src(ex_write_back_src),
            .out_use_target(ex_if_use_target),
            .out_pc_target(ex_if_pc_target),
            .out_alu_result(ex_alu_result),
            .out_d_mem_read_data(ex_d_mem_read_data),
            .out_current_pc_plus_4(ex_current_pc_plus_4)           
    
        );    

    
        wb_stage wb_inst (
        
            //inputs
            .reg_write(ex_wb_reg_write),
            .rd(ex_wb_rd),
            .write_back_src(ex_wb_write_back_src),
            .alu_result(ex_wb_alu_result),
            .d_mem_read_data(ex_d_mem_read_data),
            .current_pc_plus_4(ex_wb_current_pc_plus_4),
            
            //outputs
            .out_wb_write_enable(wb_write_enable),
            .out_wb_rd(wb_rd),
            .out_wb_write_value(wb_write_value)
            
        );
        
             
        forwarding_unit fwd_inst (
            
            //inputs
            .id_ex_rs1(id_ex_rs1),
            .id_ex_rs2(id_ex_rs2),
            .ex_wb_rd(ex_wb_rd),
            .ex_wb_reg_write(ex_wb_reg_write),
            
            //outputs
            .forward_rs1(forward_rs1),
            .forward_rs2(forward_rs2)
            
        );        
        
        
endmodule