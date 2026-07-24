`timescale 1ns / 1ps

module tb_if_id();

    localparam CLK_PERIOD = 10;
    
    logic clk;    
    logic reset;
    
    //if_stage I/O
    
        logic use_target;
        logic [31:0] pc_target;
        
        logic [31:0] instruction;
        logic [31:0] if_out_current_pc;

    //id_stage I/O
      
        logic wb_write_enable;
        logic [31:0] wb_write_value;
        logic [4:0] wb_rd;

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
        logic [31:0] id_out_current_pc;  

    //DUT if_stage
    if_stage #(
        .PROGRAM("program_all_formats.hex")
    ) DUT_IF (
    
        .clk(clk),
        .reset(reset),
        
        .use_target(use_target),
        .pc_target(pc_target),
        
        .instruction(instruction),
        .out_current_pc(if_out_current_pc)
    
    );

    //DUT id_stage
    id_stage DUT_ID(

        .clk(clk),
        .reset(reset),
        
        .instruction(instruction),
        .current_pc(if_out_current_pc),
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
        .out_current_pc(id_out_current_pc)    
    
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
        $display("Start of if_id testbench");
        
        /*    
            Corner cases to cover:
    
                1. Fetch and decode a program containing one instruction of each format(R, I, S, B, U, J).
                   For each, we'll verify the instruction reaches ID intact, and that ID produces the correct fields
                   (rd, funct3, immediate) and all 8 control signals. This is an integration test, each module is
                   already tested, here we verify they are wired together correctly.

        */

        //initialize DUT_IF inputs and raise RESET to avoid X's in out_pc
        reset = 1;  use_target = 0;  pc_target = 32'd0;
    
        //initialize DUT_ID inputs, as well as raising reset to avoid X's in register_file
        wb_write_enable = 0;  wb_write_value = 32'd0;  wb_rd = 5'd0;
    
        @(posedge clk); #1;

        reset = 0;

        //TC1:
        
            //FIRST CYCLE: PC = 0 sends address and one cycle later, we'll get imem[0]         

            @(posedge clk);
            #1;         
            
            //imem[0]
            $display("");
            $display("imem[0] output checking:");
                           
            check("address 0 got imem[0] one cycle after", instruction, 32'h002081b3); #1;
            
                //now we check INSTRUCTION DECODE stage outputs
                //imem[0] is add x3, x1, x2 (R-type)
                check("imem[0] got rd = x3", rd, 5'd3);
                check("got out_current_pc = 0 when pc was 0", id_out_current_pc, 5'd0);
                check("got out_funct3 = 0000 in add instruction", out_funct3, 5'b0000);
                
                //control signal output's for imem[0]
                check_control("R-type instruction (add x3,x2,x1) returned all control signals right", 1, 1, 4'b0000, 0, 0, 2'b00, 0 , 0);
            
            //now in this cycle, address is 4, after this cycle, the instruction should be imem[1]
            
            @(posedge clk); 
            #1;         
        
            //imem[1]
            $display("");
            $display("imem[1] output checking:");
                         
            check("address 4 got imem[1] one cycle after", instruction, 32'hffb00093); #1;
            
            //now we check INSTRUCTION DECODE stage outputs
            //imem[1] is addi x1, x0, -5  (I-type arithmetic)
            check("imem[1] got rd = x1", rd, 5'd1);
            check("got out_funct3 = 000 in addi instruction", out_funct3, 3'b000);
            check("got immediate = -5 in addi instruction", immediate, 32'hfffffffb);

            //control signal outputs for imem[1]
            check_control("I-type instruction (addi x1,x0,-5) returned all control signals right", 1, 0, 4'b0000, 0, 0, 2'b00, 0, 0);
            
            //now in this cycle, address is 8, after this cycle, the instruction should be imem[2]
            
            @(posedge clk); 
            #1;             
        
            //imem[2]
            $display("");
            $display("imem[2] output checking:"); 
               
            check("address 8 got imem[2] one cycle after", instruction, 32'h00a02223); #1;
    
                //now we check INSTRUCTION DECODE stage outputs
                //imem[2] is sw x10, 4(x0)  (S-type)
                check("got out_funct3 = 010 in sw instruction", out_funct3, 3'b010);
                check("got immediate = 4 in sw instruction", immediate, 32'h00000004);
    
                //control signal outputs for imem[2]
                check_control("S-type instruction (sw x10,4(x0)) returned all control signals right", 0, 0, 4'b0000, 0, 1, 2'b00, 0, 0);
    
            //now in this cycle, address is 12, after this cycle, the instruction should be imem[3]
    
            @(posedge clk);
            #1;
    
            //imem[3]
            $display("");
            $display("imem[3] output checking:");
                
            check("address 12 got imem[3] one cycle after", instruction, 32'hfe208ce3); #1;
    
                //now we check INSTRUCTION DECODE stage outputs
                //imem[3] is beq x1, x2, -8  (B-type)
                check("got out_funct3 = 000 in beq instruction", out_funct3, 3'b000);
                check("got immediate = -8 in beq instruction", immediate, 32'hfffffff8);
    
                //control signal outputs for imem[3]
                check_control("B-type instruction (beq x1,x2,-8) returned all control signals right", 0, 0, 4'b1000, 0, 0, 2'b00, 1, 0);
    
            //now in this cycle, address is 16, after this cycle, the instruction should be imem[4]
    
            @(posedge clk);
            #1;
    
            //imem[4]
            $display("");
            $display("imem[4] output checking:");
                
            check("address 16 got imem[4] one cycle after", instruction, 32'h12345037); #1;
    
                //now we check INSTRUCTION DECODE stage outputs
                //imem[4] is lui x0, 0x12345  (U-type)
                check("imem[4] got rd = x0", rd, 5'd0);
                check("got immediate = 0x12345000 in lui instruction", immediate, 32'h12345000);
    
                //control signal outputs for imem[4]
                check_control("U-type instruction (lui x0,0x12345) returned all control signals right", 1, 0, 4'b0000, 0, 0, 2'b00, 0, 0);
    
            //now in this cycle, address is 20, after this cycle, the instruction should be imem[5]
    
            @(posedge clk);
            #1;
    
            //imem[5]
            $display("");
            $display("imem[5] output checking:");
                
            check("address 20 got imem[5] one cycle after", instruction, 32'h008000ef); #1;
    
                //now we check INSTRUCTION DECODE stage outputs
                //imem[5] is jal x1, 8  (J-type)
                check("imem[5] got rd = x1", rd, 5'd1);
                check("got immediate = 8 in jal instruction", immediate, 32'h00000008);
    
                //control signal outputs for imem[5]
                check_control("J-type instruction (jal x1,8) returned all control signals right", 1, 0, 4'b0000, 0, 0, 2'b11, 0, 1);            
            
            @(posedge clk);
            #1;        
            
             
        //End of TC1.
 
        $display("");
        $display("End of id_if testbench");
        $display("");
    
        $finish;
    end    


endmodule
