`timescale 1ns / 1ps

module tb_if_stage();

    localparam CLK_PERIOD = 10; 

    logic clk;    
    logic reset;
    logic use_target;
    logic [31:0] pc_target;
    
    logic [31:0] instruction;
    logic [31:0] out_current_pc;
    
    if_stage #(
        .PROGRAM("program_add_5_3.hex")
    ) DUT (
    
        .clk(clk),
        .reset(reset),
        .use_target(use_target),
        .pc_target(pc_target),
        
        .instruction(instruction),
        .out_current_pc(out_current_pc)
    
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
            $error("FAIL %s - got %0h, expected %0h (time: %0t)", label, got, expected, $time);

    endtask

    initial begin
    
         $display("");
         $display("Beginning of Instruction Fetch (if_stage) testbench");
    
        /*
            Corner cases to cover:
            
                1. After each cycle (3 in total) we check if the pc address gets incremented by 4 in 4, 
                   we check that if the instructions of the program got sent (3 in total: address 0,4,8 should request imem[0], imem[1], imem2[2])
                   
                2. We reset the PC back to pc = 0, so, it must output imem[0] in the next cycle, but we will raise
                   use_target HIGH, as well as a new address (pc = 8) , to see if in the next cycle, it ouputs imem[2] and not imem[0]
                   
                3. We quickly test out_current_pc: it musts output the current pc value (not address) one cycle later      
           
        */  
         
        //initialize DUT inputs and raise RESET to avoid X's  
        reset = 1;  use_target = 0;  pc_target  = 32'd0;

        @(posedge clk); 
        #1;
       
        $display("");
        //TC1
                    
            //Extra reset cycle holds PC at 0 so memory's one cycle late read outputs imem[0] before PC advances     
            //In this moment, we send address 0, from this moment, the address will automatically advance to 0,4,8 each cycle.
            //In this cycle, address is 0, after this cycle, the instruction should be imem[0]
                 
            @(posedge clk); 
            #1;     
    
            reset = 0;
            
            check("TC1a - address 0 got imem[0] one cycle after - Success", instruction, 32'h00500093);
            
            //now in this cycle, address is 4, after this cycle, the instruction should be imem[1]
            
            @(posedge clk); 
            #1;      
    
            check("TC1b - address 4 got imem[1] one cycle after - Success", instruction, 32'h00300113);
            
            //now in this cycle, address is 8, after this cycle, the instruction should be imem[2]
    
            @(posedge clk); 
            #1;
          
            check("TC1c - address 8 got imem[2] one cycle after - Success", instruction, 32'h002081b3);
        
            @(posedge clk); 
            #1;
            
        $display("");    
        //TC2
        
            //we reset again the program so we can go back to pc = 0      
            reset = 1; 
            
            @(posedge clk)
            #1;
            
            reset = 0;
            
            /*
            right now, pc = 0 (we should get in the next cycle imem[0] in instruction) but we will raise use_target HIGH and 
            load a pc_target address (pc = 8) to see if it outputs imem[2] and not imem[0]
            */
            
            use_target = 1;
            pc_target = 32'h8;
            
            @(posedge clk)
            #1;
            
            use_target = 0;
            
            check("TC2 - target address (0x8) got imem[2] one cycle after use_target raised HIGH - Success", instruction, 32'h002081b3);                 
            
            @(posedge clk);
            #1;
        
        $display("");    
        //TC3
            
            //we also check if out_current_pc got 0x8 as well (out_current_pc captures the current_pc address one cycle later)
            
            check("TC3 - out_current_pc outputs target address (0x8) one cycle later - Success", out_current_pc, 32'h8);
            
            #9;            
            
            $display("");
            $display("End of Instruction Fetch (if_stage) testbench");
            $display("");
                    
            $finish;
    end

endmodule
