`timescale 1ns / 1ps

module tb_immediate_generator();

    //DUT inputs
    logic [31:0] instruction;
    logic [31:0] imm;    

    //DUT
    immediate_generator DUT (
    
        .instruction(instruction),
        .imm(imm)        
        
    );

    //check task
    task check (input string label, input logic [31:0] got, input logic [31:0] expected);

        if (got === expected)
            $display("PASS %s (time: %0t)", label, $time);
        else
            $error("FAIL %s - got %0h, expected %0h (time: %0t)", label, got, expected, $time);

    endtask
    

    //main stimulus
    initial begin
    
        $display("");
        $display("Start of immediate generator testbench");
        /*
            Corner cases to cover:
        
                1. Sending one instruction per format, with a known immediate , as well as sending some instructions 
                   with negative immediates to test that sign-extension works well
        
                2. Invalid opcode to test default case (immediate must be all zeros)
        
        */
    
        //initialize DUT inputs
        instruction = 32'b0; #10;
        

        //TC1:
        
            //I-Type with imm = -5 decimal
            
                //instruction is addi x1,x0,-5
                instruction = 32'hFFB00093; #1;          
            
                check("I-Type instruction with -5 immediate correctly got sign-extended", imm, 32'hFFFFFFFB);
            
                #10;
            
            //U-Type (upper immediate, low 12 zeroed)
            
                //instruction is lui x0,0x12345
                instruction = 32'h12345037; #1;          
            
                check("U-Type instruction with imm = 0x12345 correctly got low 12 zeroed (0x12345000)", imm, 32'h12345000);
            
                #10;            
    
            //S-Type with imm = 4 decimal
            
                 //instruction is sw x10,4(x0)
                instruction = 32'h00A02223; #1;          
            
                check("S-Type instruction with 4 immediate correctly got sign-extended", imm, 32'h00000004);
            
                #10;                
    
            //B-Type with imm = -8 decimal
            
                 //instruction is beq x1,x2,-8
                instruction = 32'hFE208CE3; #1;          
            
                check("B-Type instruction with -8 immediate correctly got sign-extended", imm, 32'hFFFFFFF8);
            
                #10;       
    
            //J-Type with imm = 8 decimal
            
                 //instruction is jal x1,8
                instruction = 32'h008000EF; #1;          
            
                check("J-Type instruction with 8 immediate correctly got sign-extended", imm, 32'h00000008);
            
                #10;        
            
        //End of TC1
        
        
        //TC2
       
            //invalid opcode
            instruction = 32'hFE208F43; #1;          
                
            check("Invalid instruction with invalid opcode got all zeros on immediate", imm, 32'h00000000);
                
            #10;               
            
        //End of TC2       
    
        $display("End of immediate generator testbench");
        $display("");
        
        $finish;
    end

endmodule
