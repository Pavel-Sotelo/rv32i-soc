`timescale 1ns / 1ps 

module tb_ex_stage();

    localparam CLK_PERIOD = 10;

    logic clk;

    //DUT Inputs

        logic [31:0] reg_value_1;          
        logic [31:0] reg_value_2;           
        logic [31:0] immediate;             
        logic [4:0] rd;           
        logic [2:0] funct3;
        logic reg_write;              
        logic reg_or_imm;              
        logic [3:0] alu_op;                   
        logic write_mem;               
        logic [1:0] write_back_src;    
        logic branch;                  
        logic jump;
        logic [31:0] current_pc;
        logic [31:0] current_pc_plus_4;
        
    //DUT Outputs

        logic out_reg_write;
        logic  [4:0] out_rd;  
        logic  [1:0] out_write_back_src;  
        logic out_use_target;
        logic [31:0] out_pc_target;    
        logic [31:0] out_alu_result;
        logic [31:0] out_d_mem_read_data;
        logic [31:0] out_current_pc_plus_4;        

    //DUT instantiation
    
    ex_stage DUT (
    
        .clk(clk),
        .reg_value_1(reg_value_1),
        .reg_value_2(reg_value_2),
        .immediate(immediate),
        .rd(rd),
        .funct3(funct3),
        .reg_write(reg_write),
        .reg_or_imm(reg_or_imm),
        .alu_op(alu_op),
        .write_mem(write_mem),
        .write_back_src(write_back_src),
        .branch(branch),
        .jump(jump),
        .current_pc(current_pc),
        .current_pc_plus_4(current_pc_plus_4),
        
        .out_reg_write(out_reg_write),
        .out_rd(out_rd),
        .out_write_back_src(out_write_back_src),
        .out_use_target(out_use_target),
        .out_pc_target(out_pc_target),
        .out_alu_result(out_alu_result),
        .out_d_mem_read_data(out_d_mem_read_data),
        .out_current_pc_plus_4(out_current_pc_plus_4)

    );
     
    //Task's

        //check task
        task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
            if (got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $error("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);
    
        endtask


    //Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;


    //main stimulus
    initial begin

        $display("");
        $display("Start of ex_stage testbench:");
    
        //initialize ALL DUT inputs to zero, to avoid X's in simulation
        reg_value_1 = 32'd0;
        reg_value_2 = 32'd0;
        immediate = 32'd0;
        rd = 5'd0;
        funct3 = 3'd0;
        reg_write = 1'b0;
        reg_or_imm = 1'b0;
        alu_op = 4'd0;
        write_mem = 1'b0;
        write_back_src = 2'd0;
        branch = 1'b0;
        jump = 1'b0;
        current_pc = 32'd0;
        current_pc_plus_4 = 32'd0;

        /*
            Corner cases to cover:
        
                Note: the ALU, branch_unit and data memory have their own testbenches, so 
                this one only covers logic that exists in ex_stage itself.
        
                1. Operand mux: reg_or_imm HIGH selects reg_value_2, LOW selects immediate.
                   Checked through out_alu_result, so the ALU result gives a different sum.
        
                2. Data memory wiring: store a value at an ALU computed address (synchronous write),
                   then at the next cycle, we read the same value one cycle later (synchronous read).
        
                3. Branch target adder: out_pc_target = current_pc + immediate.Positive 
                   immediate (forward) and negative (backward loop, which also proves the 
                   immediate arrives sign-extended).
        
                4. use_target gating: out_use_target = take_branch | jump. Jump asserts it
                   alone, a taken beq asserts it through the full chain (ALU to branch_unit),
                   neither leaves it low.
        
                5. Pass throughs: rd, reg_write, write_back_src, current_pc_plus_4 cross
                   unchanged. rd = 31 sets all five bits, catching a truncated port width.
        */            
    
        $display("");
        //TC1:
        
            //Set values in operands
            reg_value_1 = 32'd1;
            reg_value_2 = 32'd34; immediate = 32'd302; #1;
            
            //We're going to add both operands and see the result
            alu_op = 3'b000; //add
        
            //First we set reg_or_imm = 1 (reg_value_2)
            reg_or_imm = 1; #1;
            check("TC1 reg_or_imm = 1 sets alu_second_operand = reg_value_2, we get out_alu_result = 35", out_alu_result, 32'd35);     
            #10;
    
            //now with reg_or_imm = 0 (immediate)
            reg_or_imm = 0; #1;
            check("TC1 reg_or_imm = 0 sets alu_second_operand = immediate, we get out_alu_result = 303", out_alu_result, 32'd303);    
            #10;
    
        //End of TC1.
    
        $display("");
        //TC2:

            //write 583 to address 16
            reg_value_1 = 32'd0; immediate = 32'd16; //equivalent to 16(x0)
            
            reg_or_imm = 1'b0;  //ALU sees immediate
            alu_op = 4'b0000;   //add
            
            reg_value_2 = 32'd583;  //this is the store data
            write_mem = 1'b1;
            #1;
            
            check("TC2 out_alu_result = 16 (address)", out_alu_result, 32'd16);
            
            //synchronous write
            @(posedge clk); #1;
            write_mem = 1'b0;
            
            //read it back, address is still 16
            
            //synchronous read
            @(posedge clk); #1;
            check("TC2 read back 583 from address 16", out_d_mem_read_data, 32'd583);    
            #10;
    
        //End of TC2.
    
        $display("");
        //TC3:    

            //branch target, positive immediate
            current_pc = 32'd100;
            immediate = 32'd8;
            #1;
            
            check("TC3 out_pc_target = 108 (100 + 8)", out_pc_target, 32'd108);
            #10;
        
            //branch target, negative immediate (backward branch is what a loop uses)
            current_pc = 32'd100;
            immediate  = -32'd8;  // -8
            #1;
            check("TC3 out_pc_target = 92 (100 - 8)", out_pc_target, 32'd92);
            #10; 
                   
        //End of TC3.
        
        $display("");    
        //TC4:    

            //jump alone asserts use_target (branch low, ALU result irrelevant)
            branch = 1'b0; jump = 1'b1;
            #1;
            check("TC4 use_target = 1 when jump is HIGH", out_use_target, 1'b1);
            #10;
                     
            //now we set the signals that generate take_branch = 1 on branch_unit submodule
            branch = 1'b1; jump = 1'b0;
            funct3 = 3'b000;       //beq
            reg_value_1 = 32'd7; 
            reg_value_2 = 32'd7;
            reg_or_imm  = 1'b1;   //ALU sees reg_value_2
            alu_op = 4'b1000;     //SUB is 0 when equal
            #1;
            check("TC4 use_target = 1 on taken beq (taken_branch", out_use_target, 1'b1);
            #10;
            
            //neither branch nor jump leaves use_target low
            branch = 1'b0;
            jump= 1'b0;
            #1;
            check("TC4 use_target = 0 when no branch or jump", out_use_target, 1'b0);
            #10;  
        
        $display("");        
        //TC5:
        
            rd = 5'd31;     //all 5 bits set
            reg_write = 1'b1;
            write_back_src = 2'b01;
            current_pc_plus_4 = 32'd104;
            #1;
            check("TC5 out_rd = 31 (full 5 bits)", out_rd, 5'd31);
            check("TC5 out_reg_write passed through", out_reg_write, 1'b1);
            check("TC5 out_write_back_src passed through", out_write_back_src, 2'b01);
            check("TC5 out_current_pc_plus_4 passed", out_current_pc_plus_4, 32'd104);
            #10;
        
        //End of TC5
            
        $display("");
        $display("End of ex_stage testbench.");
        $display("");            
            
        $finish;
    end

endmodule
