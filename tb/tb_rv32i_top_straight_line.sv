`timescale 1ns / 1ps 

//First CPU Testbench: Straight-line instructions (no branches or jumps, PC increments only)
module tb_rv32i_top_cpu();

    localparam CLK_PERIOD = 10;    

    //DUT Inputs
        logic clk;  
        logic reset;

    //DUT instantiation
    rv32i_top #(
    
        .PROGRAM("program_straight_line.hex")
    
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
    
        program_straight_line.hex
        Straight line only: no branches or jumps.
        No forwarding yet, so a register is not readable until 3 instructions after it is written. 

        addi x1,  x0, 5
        addi x2,  x0, 7
        addi x3,  x0, 100
        lui  x6,  0x12345
        add  x4,  x1, x2     
        addi x7,  x0, 1
        addi x9,  x0, 2
        sub  x5,  x2, x1
        sw   x4,  0(x0)
        addi x10, x0, 3
        addi x11, x0, 4
        lw   x8,  0(x0)      expect 12 here
        
    */
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of First CPU Testbench: Straight-line instructions (no branches or jumps, PC increments only):");
        $display("");
        
        //raise reset to avoid X's in waveform, and see initial values as zero
        reset = 1;
        
        @(posedge clk); #1;

        reset = 0;
        
        //let the psrogram run
        repeat (25) @(posedge clk);
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(1,  32'd5);
            check_reg(2,  32'd7);
            check_reg(3,  32'd100);
            check_reg(4,  32'd12);
            check_reg(5,  32'd2);
            check_reg(6,  32'h12345000);
            check_reg(7,  32'd1);
            check_reg(8,  32'd12);
            check_reg(9,  32'd2);
            check_reg(10, 32'd3);
            check_reg(11, 32'd4);
            check_reg(0,  32'd0);      // x0 stays zero always (when read)
       
       $display("");
       //Check for errors written in check_reg tasks     
            
            if (errors == 0) 
                $display("PASS: all registers correct");
            else             
                $display("FAIL: %0d mismatches", errors);


        $display("");
        $display("End of First CPU Testbench.");
        $display("");
                        
        $finish;
    end
    
endmodule
