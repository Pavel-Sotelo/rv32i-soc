`timescale 1ns / 1ps

module tb_rv32i_uart_stall();

    localparam CLK_PERIOD = 10;    

    //DUT Inputs
        logic clk;  
        logic reset;

    //DUT instantiation
    rv32i_top #(
    
        .PROGRAM("program_uart_stall.hex")
    
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
        program_uart_stall.hex:
        
        Exercises the UART path and the stall on a peripheral read
        
        addi x1, x0, 42     # x1 = 42
        sw   x1, 0(x0)      # store-data forwarding, writes data memory
        lw   x5, 0(x0)      # x5 = 42

        lui  x10, 0x1       # x10 = 0x1000, UART base
        addi x6, x0, 65     # 'A'
        sw   x6, 0(x10)     # transmit, fire and forget
        lw   x13, 8(x10)    # read STATUS, stalls until read_done
        
        Expect x1=42, x5=42, x6=65, x10=0x1000, x13=1.
        
        is_uart drives the 0x1000 to the AXI master, not to memory. The
        STATUS read takes four cycles the pipeline lacks, so stall freezes the
        PC, if_stage and ID->EX until read_done, forcing reg_write low so the
        load writes once. x13 = 1 is tx_busy, the byte still going out.
        No ISS check - it has no UART or cycles.

    */
    
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of CPU Testbench - - AXI4Lite-UART lw stall test:");
        $display("");
        
        //raise reset to avoid X's in waveform, and see initial values as zero
        reset = 1;
        
        @(posedge clk); #1;
        
        reset = 0;

        //let the program run
        repeat (40) @(posedge clk);
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(1,  32'd42);     //x1 = 42, written first, no dependency
            check_reg(5,  32'd42);     //stored to mem[0], loaded back from address 0
            check_reg(10, 32'h1000);   //UART base, from lui
            check_reg(6,  32'd65);     //'A', the byte transmitted
            check_reg(13, 32'd1);      //STATUS bit 0 = tx_busy, read stalled until read_done
            check_reg(0,  32'd0);      //x0 stays zero always
       
        $display("");
        //Check for errors written in check_reg tasks     
            
            if (errors == 0) 
                $display("PASS: all registers correct");
            else             
                $display("FAIL: %0d mismatches", errors);


        $display("");
        $display("End of CPU Testbench - AXI4Lite-UART lw stall test.");
        $display("");
                        
        $finish;
    end


endmodule
