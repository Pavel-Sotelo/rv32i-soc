`timescale 1ns / 1ps

module tb_rv32i_fibonacci();

    localparam CLK_PERIOD = 10;    

    //DUT Inputs
        logic clk;  
        logic reset;

    //DUT instantiation
    rv32i_top #(
    
        .PROGRAM("program_fibonacci.hex")
    
    ) DUT (
    
        .clk(clk),
        .reset(reset)    
    
    );


    //clock generation
    initial clk = 0; 
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //Signal to drive txt file generation
    integer f;
    
    //Signal to count number of errors in simulation
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

        program_fibonacci.hex
        A counted loop computing Fibonacci, then one byte out (233, max value for a byte in fibonacci) to the UART:
        
            addi x2, x0, 0      # counter = 0
            addi x3, x0, 12     # limit = 12 (F(12) = 233, max number a byte can send in fibonacci)
            
            addi x4, x0, 0      # prev = 0
            addi x5, x0, 1      # curr = 1
            
            # fibonacci loop:
            add  x6, x4, x5     # prev + curr  (loop start, address 16)
            add  x4, x0, x5     # curr -> prev
            add  x5, x0, x6     # next -> curr
            addi x2, x2,  1     # counter++
            bne  x2, x3, -16    # loop returner (PC + imm = 32 - 16 = 16)
            
            # send final fibonacci byte (233 decimal) to UART:
            
            lui x10, 0x1        # x10 = 0x1000 (UART address)
            sw   x5, 0(x10)     # write 233 to UART
            
            # done:
            beq x0, x0, 0    # finish program, PC stays here forever (PC + imm = 44 + 0 = 44)            
            
            
        Expect x5 = 233 (0xE9), x4 = 144, x2 = 12, x10 = 0x1000.
        
        The loop uses add, addi, bne and beq for a halt pc, all implemented, and bne is
        what collapses 12 iterations into a body written once.

    */
    
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of CPU Testbench - - Fibonacci until 233:");
        $display("");
        
        //raise reset to avoid X's in waveform, and see initial values as zero
        reset = 1;
        
        @(posedge clk); #1;
        
        reset = 0;

        //let the program run
        repeat (4000) @(posedge clk);
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(5,  32'd233);    //curr = F(12) = 233, the byte sent to the UART
            check_reg(4,  32'd144);    //prev = F(11) = 144, one step behind curr
            check_reg(6,  32'd233);    //next = last sum computed, equals curr on exit
            check_reg(2,  32'd12);     //counter, hit the limit and fell through
            check_reg(3,  32'd12);     //limit, never written after setup
            check_reg(10, 32'h1000);   //UART base, from lui
            check_reg(0,  32'd0);      //x0 stays zero always
       
       
        $display("");
        //Check for errors written in check_reg tasks     
            
            if (errors == 0) 
                $display("PASS: all registers correct");
            else             
                $display("FAIL: %0d mismatches", errors);


        //Create txt file with final 32 registers state for co-simulation
        f = $fopen("C:/Users/Pavel/Desktop/rv32i-soc/cosim/rtl_regs_fibonacci.txt", "w");
        for (int i = 0; i < 32; i++)
            $fdisplay(f, "x%0d = %08x", i, DUT.id_inst.reg_file.register[i]);
        $fclose(f);


        $display("");
        $display("End of CPU Testbench - Fibonacci until 233.");
        $display("");
                        
        $finish;
    end

endmodule