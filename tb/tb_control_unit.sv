`timescale 1ns / 1ps

module tb_control_unit();

        //DUT inputs
        logic [6:0] opcode;
        logic [2:0] funct3;
        logic funct7;        
        
        //DUT outputs
        logic reg_write;               
        logic reg_or_imm;              
        logic [3:0] alu_op;           
        logic read_mem;                
        logic write_mem;               
        logic [1:0] write_back_src;    
        logic branch;                  
        logic jump;                     


    //DUT
    control_unit DUT (
    
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        
        .reg_write(reg_write),
        .reg_or_imm(reg_or_imm),
        .alu_op(alu_op),
        .read_mem(read_mem),
        .write_mem(write_mem),
        .write_back_src(write_back_src),
        .branch(branch),
        .jump(jump)
        
    );
    

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


    //Main simulation block

    initial begin
    
        $display("");
        $display("Start of control unit testbench");
    
        /*
            Corner cases to cover:
            
                1. One test per opcode, as well as testing funct7 and funct3 concatenation, in I-Type arithmetic and R-Type
                2. default case (feed an invalid opcode), confirm safe values (no reg_write, no mem_write, no branch/jump, etc.)
                  
        */
    
        //initialize DUT inputs
        opcode = 7'd0;  funct3 = 3'd0;  funct7 = 1'd0;
        
        #10;
        
        //TC1:
        
            //OPCODE: 3 DECIMAL (I-TYPE, LOAD)
            
                opcode = 7'h03; #1;
                check_control("I-type load", 1, 0, 4'b0000, 1, 0, 2'b01, 0 , 0);
                
                #10;
                
            
            //OPCODE 19 DECIMAL (I-TYPE, ARITHMETIC)
            
                opcode = 7'h13;
                
                //we will send a random ALU operation with funct7 (SRA)
                funct7 = 1;
                funct3 = 3'b101;
                
                #1;
                check_control("I-type arithmetic", 1, 0, 4'b1101, 0, 0, 2'b00, 0 , 0);
                
                #10;
                
                
            //OPCODE 35 DECIMAL (S-TYPE, STORE)
        
                opcode = 7'h23; #1;
                check_control("S-Type", 0, 0, 4'b0000, 0, 1, 2'b00, 0 , 0);
                
                #10;         
       
            //OPCODE 51 DECIMAL (R-TYPE) 
        
                opcode = 7'h33;
                
                //we will send a random ALU operation with funct7 (SUB)
                funct7 = 1;
                funct3 = 3'b000;
                
                #1;
                check_control("R-Type", 1, 1, 4'b1000, 0, 0, 2'b00, 0 , 0);
                
                #10;                        
    
    
            //OPCODE 55 DECIMAL (U-TYPE, only lui)
        
                opcode = 7'h37; #1;
                check_control("U-Type", 1, 0, 4'b0000, 0, 0, 2'b00, 0 , 0);
                
                #10;
                
            //OPCODE 99 DECIMAL (B-TYPE, Branch)
        
                opcode = 7'h63; #1;
                check_control("B-Type", 0, 0, 4'b1000, 0, 0, 2'b00, 1 , 0);
                
                #10;                        
    
            //OPCODE 111 DECIMAL (J-TYPE, only jal)
        
                opcode = 7'h6F; #1;
                check_control("J-Type", 1, 0, 4'b0000, 0, 0, 2'b11, 0 , 1);
                
                #10;           
        
        
        
        //TC2:
        
                //Feed an invalid opcode
                opcode = 7'h49; #1;
                check_control("Default invalid opcode", 0, 0, 4'b0000, 0, 0, 2'b00, 0 , 0);
                
                #10;                  
    
        $display("End of control unit testbench");        
        $display("");
    
        $finish;
    end

endmodule
