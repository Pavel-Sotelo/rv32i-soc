`timescale 1ns / 1ps 

//First CPU Testbench: Straight-line instructions (no branches or jumps, PC increments only)
module tb_rv32i_first_loop();

    localparam CLK_PERIOD = 10;    

    //DUT Inputs
        logic clk;  
        logic reset;

    //DUT instantiation
    rv32i_top #(
    
        .PROGRAM("program_first_loop.hex")
    
    ) DUT (
    
        .clk(clk),
        .reset(reset)    
    
    );


    //clock generation
    initial clk = 0; 
    always #(CLK_PERIOD/2.0) clk = ~clk;

    
    int errors = 0;

    //check_reg task: Checks if expected values in specified register are the same as real register.
    task check_reg(input int idx_reg, input logic [31:0] expected);
    
        //!== can also check X's
        if(DUT.id_inst.reg_file.register[idx_reg] !== expected) begin
            $error("(time: %0t) register x%0d = %0h, expected = %0h", $time, idx_reg, DUT.id_inst.reg_file.register[idx_reg], expected);    
            errors++;
        end
            
    endtask



    //when wb_write_enable is HIGH, we check what is being written(wb_write_value) and where(register destination, wb_rd)
    always_ff @(posedge clk) begin
    
        if(DUT.wb_write_enable && ~reset) 
            $display("(time: %0t) x%0d =  %0h", $time, DUT.wb_rd, DUT.wb_write_value);
    
    end
    
    
    /*    
    
        program_loop.hex
        First program with a counted loop using bne.
        No forwarding yet, so a register is not readable until 3 instructions after it
        is written. The fillers inside the loop are there to keep that distance.
    
        addi x1, x0, 0      # sum = 0
        addi x2, x0, 0      # counter = 0
        addi x3, x0, 4      # limit
        addi x0, x0, 0      # spacer
        addi x0, x0, 0      # spacer
    
        add  x1, x1, x3     # address 20, loop starts here: sum += 4
        addi x2, x2, 1      # counter++
        addi x0, x0, 0      # filler, keeps x2 three instructions from the bne
        addi x0, x0, 0      # filler
        bne  x2, x3, -16    # address 36, back to 20 while counter != limit
    
        Loop runs 4 times, so expect x1 = 16, x2 = 4, x3 = 4
        Also exercises the 2-cycle flush: when the bne is taken, the two instructions
        behind it in ID and IF were fetched from the not-taken path and are squashed.
    
    */
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of CPU Testbench - with a counted loop using bne:");
        $display("");
        
        //raise reset to avoid X's in waveform, and see initial values as zero
        reset = 1;
        
        @(posedge clk); #1;

        reset = 0;
        
        //let the psrogram run
        repeat (50) @(posedge clk);
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(1,  32'd16);     //sum: 4 added once per iteration, 4 iterations (4x4 = 16)
            check_reg(2,  32'd4);      //counter: incremented until it equals the limit
            check_reg(3,  32'd4);      //limit, never modified
            check_reg(0,  32'd0);      //x0 stays zero always (the fillers write to it)
       
       $display("");
       //Check for errors written in check_reg tasks     
            
            if (errors == 0) 
                $display("PASS: all registers correct");
            else             
                $display("FAIL: %0d mismatches", errors);


        $display("");
        $display("End of CPU Testbench - with a counted loop using bne.");
        $display("");
                        
        $finish;
    end
    
endmodule
