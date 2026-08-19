`timescale 1ns / 1ps 

module tb_rv32i_forwarding();

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
        .PROGRAM("program_forwarding.hex")
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
        program_forwarding.hex
        Back-to-back instructions with no spacers, covering every forwarding path.

        addi x1, x0, 5      # x1 = 5
        addi x2, x1, 3      # x1 one back -> forward ALU result
        add  x3, x2, x1     # x2 one back, x1 two back -> forward + bypass
        sub  x7, x3, x2     # x3 one back, x2 two back -> forward + bypass
        
        addi x4, x0, 42     # x4 = 42
        sw   x4, 0(x0)      # x4 one back -> forward on the store data path
        lw   x5, 0(x0)      # x5 = 42
        addi x6, x5, 3      # x5 one back -> forward a LOADED value

        Expect x1=5, x2=8, x3=13, x4=42, x5=42, x6=45, x7=5.
    */


    //main stimulus
    initial begin

        $display("");
        $display("Start of CPU Testbench - Forwarding on 1-back and 2-back data hazard:");
        $display("");

        rx = 1'b1;   //rx idles high so the receiver never sees a false start bit
        reset = 1;

        @(posedge clk); #1;
        reset = 0;

        //CPU is held in reset until the MMCM locks, so we wait for it, then run on clk_75
        wait (DUT.locked == 1'b1);
        repeat (200) @(posedge DUT.clk_75);

        $display("");
        check_reg(1,  32'd5);      //x1 = 5, written first, no dependency
        check_reg(2,  32'd8);      //x1 + 3, x1 forwarded from one back
        check_reg(3,  32'd13);     //x2 + x1, x2 forwarded, x1 bypassed
        check_reg(7,  32'd5);      //x3 - x2, x3 forwarded, x2 bypassed
        check_reg(4,  32'd42);     //x4 = 42, stored to memory next
        check_reg(5,  32'd42);     //loaded back from address 0
        check_reg(6,  32'd45);     //x5 + 3, a LOADED value forwarded one back
        check_reg(0,  32'd0);      //x0 stays zero always

        $display("");
        if (errors == 0) 
            $display("PASS: all registers correct");
        else             
            $display("FAIL: %0d mismatches", errors);

            
        f = $fopen("C:/Users/Pavel/Desktop/rv32i-soc/cosim/rtl_regs_forwarding.txt", "w");
        for (int i = 0; i < 32; i++)
            $fdisplay(f, "x%0d = %08x", i, DUT.id_inst.reg_file.register[i]);
        $fclose(f);

        $display("");
        $display("End of CPU Testbench - Forwarding on 1-back and 2-back data hazard.");
        $display("");

        $finish;
    end

endmodule
