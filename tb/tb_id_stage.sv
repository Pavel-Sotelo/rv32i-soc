`timescale 1ns / 1ps

module tb_id_stage();

    localparam CLK_PERIOD = 10;
    
    //DUT inputs
    logic clk;
    logic reset;
        
    logic [31:0] instruction;
    logic [31:0] current_pc;    
    logic wb_write_enable;
    logic [31:0] wb_write_value;
    logic [4:0] wb_rd;

    //DUT outputs
    logic [31:0] reg_value_1;
    logic [31:0] reg_value_2;      
    logic [31:0] immediate;       
    logic [4:0] rd;
    logic [2:0] out_funct3; 
    logic reg_write;             
    logic reg_or_imm;              
    logic [3:0] alu_op;            
    logic read_mem;                
    logic write_mem;              
    logic [1:0] write_back_src;    
    logic branch;                  
    logic jump;     
    logic [31:0] out_current_pc;  
 
        
    //DUT instantiation
    id_stage DUT(

        .clk(clk),
        .reset(reset),
        
        .instruction(instruction),
        .current_pc(current_pc),
        .wb_write_enable(wb_write_enable),
        .wb_write_value(wb_write_value),
        .wb_rd(wb_rd),
    
        .reg_value_1(reg_value_1),
        .reg_value_2(reg_value_2),
        .immediate(immediate),
        .rd(rd),
        .out_funct3(out_funct3),
        .reg_write(reg_write),              
        .reg_or_imm(reg_or_imm),              
        .alu_op(alu_op),            
        .read_mem(read_mem),                
        .write_mem(write_mem),                
        .write_back_src(write_back_src),    
        .branch(branch),                  
        .jump(jump),
        .out_current_pc(out_current_pc)    
    
    );    

    
    //Task's

        //check task
        task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
            if (got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $error("FAIL %s - got %0h, expected %0h (time: %0t)", label, got, expected, $time);
    
        endtask


        //write task
        task do_write(input logic [4:0] address, input logic [31:0] value, input logic task_write_enable);
        
            wb_rd = address;
            wb_write_value = value;
            wb_write_enable = task_write_enable;
            
            @(posedge clk);
            #1;
            
            wb_write_enable = 0;
        
        endtask
        
        
        //check control signals task
        task check_control(
        
        input string label,
        
            //exp = expected
            input logic exp_reg_write, 
            input logic exp_reg_or_imm, 
            input logic [3:0] exp_alu_op, 
            input logic exp_read_mem, 
            input logic exp_write_mem, 
            input logic [1:0] exp_write_back_src, 
            input logic exp_branch, 
            input logic exp_jump
            
        );
        
            logic flag;
            flag = 0;
                    
            if(reg_write !== exp_reg_write) begin
                $error("FAIL %s: reg_write - got: %0b, expected: %0b (time: %0t)", label, reg_write, exp_reg_write, $time); 
                flag = 1;
            end 
                   
            if(reg_or_imm !== exp_reg_or_imm) begin
                $error("FAIL %s: reg_or_imm - got: %0b, expected: %0b (time: %0t)", label, reg_or_imm, exp_reg_or_imm, $time); 
                flag = 1;
            end
                             
            if(alu_op !== exp_alu_op) begin
                $error("FAIL %s: alu_op - got: %0b, expected: %0b (time: %0t)", label, alu_op, exp_alu_op, $time); 
                flag = 1;
            end 
                 
            if(read_mem !== exp_read_mem) begin
                $error("FAIL %s: read_mem - got: %0b, expected: %0b (time: %0t)", label, read_mem, exp_read_mem, $time); 
                flag = 1;
            end
                                   
            if(write_mem !== exp_write_mem) begin
                $error("FAIL %s: write_mem - got: %0b, expected: %0b (time: %0t)", label, write_mem, exp_write_mem, $time); 
                flag = 1;
            end
                
            if(write_back_src !== exp_write_back_src) begin
                $error("FAIL %s: write_back_src - got: %0b, expected: %0b (time: %0t)", label, write_back_src, exp_write_back_src, $time); 
                flag = 1;
            end
                              
            if(branch !== exp_branch) begin
                $error("FAIL %s: branch - got: %0b, expected: %0b (time: %0t)", label, branch, exp_branch, $time); 
                flag = 1;
            end
                
            if(jump !== exp_jump) begin
                $error("FAIL %s: jump - got: %0b, expected: %0b (time: %0t)", label, jump, exp_jump, $time); 
                flag = 1;             
            end
                 
            if(!flag)
                $display("PASS %s - all 8 control signals are correct. (time: %0t)", label, $time);       
                            
        endtask        

    //End of task's


    //clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;
    
    
    initial begin
    
        $display("");
        $display("Start of id_stage testbench");
        $display("");
        
    /*    
        Corner cases to cover:

            1. Write 5 to x1, and 3 to x2, then loading instruction = 0x002081b3 (add x3,x1,x2) and see correct outputs
               (reg_value_1=5, reg_value_2=3, rd=3, alu_op=0000, reg_or_imm=1, reg_write=1, read_mem=0, write_mem=0, write_back_src=00, branch=0, jump=0)

            2. Now we will sent an I-type arithmetic instruction (addi x5,x1,-8) to check immediate output, as well we will
               send a PC address to check the PC output, and we'll check out_funct3 (to finally test all remaining outputs that didn't got
               check in TC1)

    */

        //initialize DUT inputs, as well as raising reset to avoid X's in register_file
        reset = 1;  instruction = 32'd0;  current_pc = 32'd0;  wb_write_enable = 0;  wb_write_value = 32'd0;  wb_rd = 5'd0;
    
        repeat(2) @(posedge clk);
        #1;
    
        reset = 0;
        
        @(posedge clk);
        #1;
    
        //TC1:
        
            //write 5 to x1 (write register is sequential, we have to wait 1 cycle)
            do_write(5'd1, 32'd5, 1);
    
            @(posedge clk);
            #1;
    
            //write 3 to x2
            do_write(5'd2, 32'd3, 1);
    
            @(posedge clk);
            #1;
    
            //now we send the instruction (add x3,x1,x2) and combinationally we will get all outputs
            instruction = 32'h002081b3; #1;
    
            //check if register values got correctly read, and if rd got sent correctly
            check("TC1 got reg_value_1 = 5 decimal", reg_value_1, 32'd5);     
            check("TC1 got reg_value_2 = 3 decimal", reg_value_2, 32'd3);
            check("TC1 got rd = x3", rd, 5'd3);
    
            //check all control signals
            check_control("TC1 R-type instruction (add x3,x2,x1) returned all control signals right", 1, 1, 4'b0000, 0, 0, 2'b00, 0 , 0);
    
            #10;
         
         //End of TC1.
         
        $display("");
            
        //TC2:
                
            //First we send the instruction (addi x5,x1,-8)
            instruction = 32'hFF808293;     
                
            //as well we send a PC address
            current_pc = 32'd12; #1;
            
            //check 32-bit sign-extended immediate
            check("TC2 got 32-bit sign-extended immediate = -8 decimal", immediate, 32'hFFFFFFF8);
            //check rd = x5
            check("TC2 got rd = x5", rd, 5'd5);
            //check out_current_pc
            check("TC2 got out_current_pc = 12 when pc is 12", out_current_pc, 5'd12);
            //check out_funct3
            check("TC2 got out_funct3 = 0000 in addi instruction", out_funct3, 5'b0000);
            
            //check all control signals
            check_control("TC2 I-type instruction (addi x5,x1,-8) returned all control signals right",  1, 0, 4'b0000, 0, 0, 2'b00, 0 , 0);
                
            #10;
    
        //End of TC2.
        
        $display("");
        $display("End of id_stage testbench");
        $display("");
    
        $finish;
    end

endmodule
