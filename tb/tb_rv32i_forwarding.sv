`timescale 1ns / 1ps 

module tb_rv32i_forwarding();

    localparam CLK_PERIOD = 10;    

    //DUT Inputs
        logic clk;  
        logic reset;

    //DUT instantiation
    rv32i_top #(
    
        .PROGRAM("program_forwarding.hex")
    
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

        Every read here would be stale without the two fixes: the 1-back case is
        caught by the forwarding unit, the 2-back case by the register file's
        write-first bypass. The forwarded value is wb_write_value, already muxed
        by write_back_src, so the same path covers ALU results, loads and JAL
        return addresses.

        The same program against the ISS, which has no pipeline, is the check -
        any divergence is a hazard the hardware failed to handle.
    */
    
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of CPU Testbench - Forwarding on 1-back and 2-back data hazard:");
        $display("");
        
        //raise reset to avoid X's in waveform, and see initial values as zero
        reset = 1;
        
        @(posedge clk); #1;
        
        reset = 0;

        //let the program run
        repeat (25) @(posedge clk);
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(1,  32'd5);      //x1 = 5, written first, no dependency
            check_reg(2,  32'd8);      //x1 + 3, x1 forwarded from one back
            check_reg(3,  32'd13);     //x2 + x1, x2 forwarded, x1 bypassed
            check_reg(7,  32'd5);      //x3 - x2, x3 forwarded, x2 bypassed
            check_reg(4,  32'd42);     //x4 = 42, stored to memory next
            check_reg(5,  32'd42);     //loaded back from address 0
            check_reg(6,  32'd45);     //x5 + 3, a LOADED value forwarded one back
            check_reg(0,  32'd0);      //x0 stays zero always
       
        $display("");
        //Check for errors written in check_reg tasks     
            
            if (errors == 0) 
                $display("PASS: all registers correct");
            else             
                $display("FAIL: %0d mismatches", errors);


        //Create txt file with final 32 registers state for co-simulation
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
