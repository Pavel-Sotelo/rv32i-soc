`timescale 1ns / 1ps

module tb_pc();

    localparam CLK_PERIOD = 10;

    logic clk;
    logic reset;
    logic [31:0] next_pc;
    logic [31:0] out_pc;   

    pc DUT (
    
        .clk(clk),  
        .reset(reset),
        .next_pc(next_pc),
        .out_pc(out_pc)
    
    );    

    //clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //check task
    task check(input string label, input logic [31:0] got, input logic [31:0] expected);
    
         if(got === expected)
            $display("PASS %s (time: %0t)", label, $time);
         else
              $error("FAIL %s - got: %0d, expected: %0d (time: %0t)", label, got, expected, $time);     
    
    endtask

    initial begin
 
        $display("");
        $display("Beginning of PC testbench");
           
        /*
            Corner cases to cover:
            
                1. We send an address through next_pc, we check if out_pc outputs the same address 1 cycle later
                2. We send another address through next_pc, but we check before the next cycle, if out_pc kept its old address value
                3. We raise reset HIGH, as well we send an address, then after 1 cycle, we check if reset or next_pc winned (reset must win)
           
        */
    
        //initialize DUT inputs
        reset = 0;  next_pc = 32'd0;
        
        @(posedge clk);
        #1;
        
        reset = 0;
        
        @(posedge clk);
        #1;        
    
        //TC1
        $display("");
        
            //we send an address
            next_pc = 32'h4;
            
            @(posedge clk);
            #1;     
            
            //then we check if after 1 cycle, out_pc output the same address
            check("TC1 - out_pc correctly sent the requested next_pc address (0x4)", out_pc, 32'h4);        
        
            #1;
            
        //TC2
        $display("");
        
            //we send another address
            next_pc = 32'h8;
            
            //then in the same cycle, we check if the address is still the old one and not the new one
            check("TC2a - out_pc keeps its old address before the next clock edge (0x4)", out_pc, 32'h4);
            
            @(posedge clk);
            #1;                              

            //after the next cycle, we check if out_pc got updated to the new address 
            check("TC2b - out_pc now updated to the new address after the clock edge (0x8)", out_pc, 32'h8); 
         
            #1;
               
        //TC3
        $display("");
        
            //we both raised reset and a new address
            reset = 1;
            next_pc = 32'hC;     
            
            @(posedge clk);
            #1;
            
            reset = 0;
            
            //now we check if out_pc got reseted
            check("TC3a - out_pc correctly got reseted to address 0", out_pc, 32'h0);
            
            @(posedge clk);
            #1;        
            
            //now out_pc is going to output the last address of next_pc after the reset
            check("TC3b - out_pc updated to the last address of next_pc after reset", out_pc, 32'hC);
                       
            #1;
            
        $display("");
        $display("End of PC testbench");
        $display("");
    
        $finish;
    end 

endmodule
