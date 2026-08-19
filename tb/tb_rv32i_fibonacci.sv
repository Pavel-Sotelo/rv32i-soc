`timescale 1ns / 1ps

module tb_rv32i_fibonacci();

    localparam CLK_PERIOD = 10;   //100 MHz board clock into the MMCM

    //DUT Inputs
        logic clk;  
        logic reset;
        logic rx;

    //DUT Outputs
        logic [15:0] led;
        logic tx;

    //DUT instantiation
    rv32i_top #(
        .PROGRAM("program_fibonacci.hex")
    ) DUT (
        .clk(clk),
        .reset(reset),
        .led(led),
        .rx(rx),
        .tx(tx)
    );

    //clock generation (board clock, MMCM divides it to clk_75 internally)
    initial clk = 0; 
    always #(CLK_PERIOD/2.0) clk = ~clk;

    integer f;
    int errors = 0;

    task check_reg(input int idx_reg, input logic [31:0] expected);
        //!== can also check X's
        if(DUT.id_inst.reg_file.register[idx_reg] !== expected) begin
            $error("(time: %0t) register x%0d = %0h, expected = %0h", $time, idx_reg, DUT.id_inst.reg_file.register[idx_reg], expected);    
            errors++;
        end
    endtask

    //log each register write, now on the real CPU clock
    always_ff @(posedge DUT.clk_75) begin
        if(DUT.wb_write_enable && ~DUT.sys_reset) 
            $display("(time: %0t) x%0d =  %0h", $time, DUT.wb_rd, DUT.wb_write_value);
    end


    //CPI measurement

    longint cycles  = 0;
    longint retired = 0;
    logic cpi_printed = 0;

    wire retire = (DUT.id_ex_reg_write | DUT.id_ex_write_mem | DUT.id_ex_branch) & ~DUT.stall;

    always_ff @(posedge DUT.clk_75) begin
    
        if (!DUT.sys_reset && ~cpi_printed) begin

            //halt reached is when beq x0,x0,0 (0x00000063) has entered decode
            if (DUT.if_instruction == 32'h00000063) begin
            
                $display("");
                $display("cycles = %0d   retired = %0d", cycles, retired);
                $display("CPI  = %0.3f", real'(cycles) / real'(retired));
                $display("MIPS = %0.1f (at 75 MHz)", 75.0 / (real'(cycles) / real'(retired)));
                $display("");
                
                cpi_printed <= 1;
                
            end else begin        
                cycles++;
             
                if (retire) 
                    retired++;                  
            end
        end
    end


    /*
        program_fibonacci.hex
        A counted loop computing Fibonacci, then one byte out (233) to the UART.

            addi x2, x0, 0 ; addi x3, x0, 12
            addi x4, x0, 0 ; addi x5, x0, 1
            add  x6, x4, x5 ; add x4, x0, x5 ; add x5, x0, x6 ; addi x2, x2, 1
            bne  x2, x3, -16
            lui  x10, 0x1 ; sw x5, 0(x10)
            beq  x0, x0, 0     # halt, PC stays at 44 forever

        Expect x5 = 233 (0xE9), x4 = 144, x2 = 12, x10 = 0x1000.
    */


    //main stimulus
    initial begin

        $display("");
        $display("Start of CPU Testbench - Fibonacci until 233:");
        $display("");

        rx = 1'b1;   //rx idles high so the receiver never sees a false start bit
        reset = 1;

        @(posedge clk); #1;
        reset = 0;

        //CPU is held in reset until the MMCM locks, so we wait for it, then run on clk_75
        wait (DUT.locked == 1'b1);
        repeat (2000) @(posedge DUT.clk_75);

        $display("");
        check_reg(5,  32'd233);    //curr = F(12) = 233, the byte sent to the UART
        check_reg(4,  32'd144);    //prev = F(11) = 144, one step behind curr
        check_reg(6,  32'd233);    //next = last sum computed, equals curr on exit
        check_reg(2,  32'd12);     //counter, hit the limit and fell through
        check_reg(3,  32'd12);     //limit, never written after setup
        check_reg(10, 32'h1000);   //UART base, from lui
        check_reg(0,  32'd0);      //x0 stays zero always

        $display("");
        if (errors == 0) 
            $display("PASS: all registers correct");
        else             
            $display("FAIL: %0d mismatches", errors);

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