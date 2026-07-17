`timescale 1ns / 1ps

module tb_instruction_memory();

    localparam CLK_PERIOD = 10;

    logic clk;
    logic [31:0] addr;
    logic [31:0] instruction;

    instruction_memory #(
        .PROGRAM("program_add_5_3.hex")
    ) 
    DUT (
    
        .clk(clk),
        .addr(addr),
        .instruction(instruction)
    
    );

    //clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //TASKS
    
    //check task
    task check (input string label, input logic [31:0] got, input logic [31:0] expected);

        if (got === expected)
            $display("PASS %s (time: %0t)", label, $time);
        else
            $error("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);

    endtask

    /* 
    Description of the short program to test:
    
            program_add_5_3.hex
            3 instruction test program for the instruction memory:
            
            addi x1, x0, 5   =>  x1 = 5
            addi x2, x0, 3   =>  x2 = 3
            add  x3, x1, x2  =>  x3 = 8
            
            Loads two immediates into registers and adds them
   */ 

    initial begin
    
         $display("");
         $display("Beginning of Instruction memory testbench");
    
         //initialize DUT inputs
         addr = 32'd0;
    
        /*
            Corner cases to cover:
            
                1. Sequential reads return the right instructions: Address 0, 4, 8 returns 0,1,2 memory instructions, this will also check the byte to word conversion
                2. When we send an address , we check the instruction output before the clock edge , to check if the output dont got updated (old instruction)
        */
    
    
        //TC1:
        
            //First, we request address 0
            addr = 32'd0;
            
            //We wait to get the sychronous read
            @(posedge clk);
            #1;
            
            //we check if the address 0 gives us the instruction of memory[0]
            check("TC1a - Address 0 got the instruction memory[0] after 1 clock cycle", instruction, 32'h00500093);
          
            
            //now, we request address 4
            
            addr = 32'd4;
            
            //We wait to get the sychronous read
            @(posedge clk);
            #1;
            
            //we check if the address 4 gives us the instruction of memory[1]
            check("TC1b - Address 4 got the instruction memory[1] after 1 clock cycle", instruction, 32'h00300113);

    
            //Finally we request address 8

            addr = 32'd8;
            
            //We wait to get the sychronous read
            @(posedge clk);
            #1;
            
            //we check if the address 8 gives us the instruction of memory[2]
            check("TC1c - Address 8 got the instruction memory[2] after 1 clock cycle", instruction, 32'h002081b3);            
            
            //End of TC1
                
    
            //TC2:
            
                //We will request a new address (address 0) but e will read the instruction output
                //The expected output should be memory[2] (from the last address of TC1)
                
                addr = 32'd0;
    
                //we check if the output still hold its old instruction
                check("TC2a - instruction output did not update before the clock edge. Success", instruction, 32'h002081b3); 
        
                @(posedge clk);
                #1;    
                
                check("TC2b - instruction output now updated after the clock edge. Success", instruction, 32'h00500093);
                
                @(posedge clk);
                #1;
                     
                $display("End of Instruction memory testbench");   
                $display("");

        $finish;
    end

endmodule
