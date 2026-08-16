`timescale 1ns / 1ps 

module tb_rv32i_echo();

    localparam CLK_PERIOD = 10;    
    localparam BIT_CYCLES = 651;   // 75 MHz/115200 baud

    //DUT Inputs
        logic clk;  
        logic reset;
        logic rx;
        
    //DUT Outputs
        logic [15:0] led;
        logic tx;

    //DUT instantiation
    rv32i_top #(
    
        .PROGRAM("program_echo.hex")
    
    ) DUT (
    
        .clk(clk),
        .reset(reset),
        .led(led),
        .rx(rx),
        .tx(tx)    
    
    );


    //clock generation
    initial clk = 0; 
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //Signal to count number of errors in simulation
    int errors = 0;
    
    //Signal to count how many bytes the UART was told to transmit (tx_start)
    int tx_pulses = 0;

        //check_reg task: Checks if expected values in specified register are the same as real register.
        task check_reg(input int idx_reg, input logic [31:0] expected);
        
            //!== can also check X's
            if(DUT.id_inst.reg_file.register[idx_reg] !== expected) begin
                $error("(time: %0t) register x%0d = %0h, expected = %0h", $time, idx_reg, DUT.id_inst.reg_file.register[idx_reg], expected);    
                errors++;
            end
                
        endtask
    
    
        //send_serial task: drives one 8N1 frame onto rx, start bit low, 8 data bits, LSB first, stop bit high,
        //each held for one bit period. The CPU cannot produce its own input, so the testbench plays the part of the terminal.
        task send_serial(input logic [7:0] b);
            integer i;
            begin
                rx = 1'b0;
                repeat (BIT_CYCLES) @(posedge DUT.clk_75);
    
                for (i = 0; i < 8; i = i + 1) begin
                    rx = b[i];
                    repeat (BIT_CYCLES) @(posedge DUT.clk_75);
                end
    
                rx = 1'b1;
                repeat (BIT_CYCLES) @(posedge DUT.clk_75);
            end
        endtask
    
    
        //count and show every byte handed to the transmitter
        always_ff @(posedge DUT.clk_75) begin
        
            if(DUT.slave_inst.tx_start) begin
                tx_pulses++;
                $display("(time: %0t) transmitted %0h", $time, DUT.slave_inst.tx_byte);
            end
            
        end


        //check task
        task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
            if (got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $error("FAIL %s - got %0h, expected %0h (time: %0t)", label, got, expected, $time);
    
        endtask
        
        
    /*

        program_echo.hex
        Reads a byte from the UART and sends it straight back, forever:
        
            lui x10, 0x1        # UART base

            # echo loop (starts at adress 4):

            # wait rx (done) loop:

            lw   x1, 8(x10)     # read STATUS
            andi x1, x1, 2      # Mask only done bit
            beq  x1, x0, -8     # return to loop (PC = 4) if done is 0

            lw x2, 4(x10)       # done=1, load RX_DATA byte into register

            # wait tx (~tx_busy) loop, prevents dropping transmitted byte:

            lw   x1, 8(x10)     # read STATUS
            andi x1, x1, 1      # Mask only tx_busy bit
            bne  x1, x0, -8     # return to loop (PC = 20) if tx_busy is 1

            sw x2, 0(x10)       # echo it back

            beq x0, x0, -32     # return to echo loop
                      
        Two bytes are sent, 47 then 48. One is not enough: the design once echoed
        the first character correctly and then went deaf, because the loop never
        returned to the wait rx poll.
        
        Expect two transmissions, and x2 = 48, x10 = 0x1000 at the end.
        
        No co-simulation for this program: the C ISS has no AXI4-Lite UART, so it
        has nothing to receive a byte with and no STATUS register to poll.

    */
    
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of CPU Testbench - AXI4Lite-UART echo:");
        $display("");
        
        //rx idles HIGH (IDLE), a low line would look like a start bit
        rx = 1'b1;
        
        //raise reset to avoid X's in waveform, and see initial values as zero
        reset = 1;
        
        @(posedge clk); #1;
        
        reset = 0;
        
        //the MMCM takes microseconds to lock and the CPU is held in reset until it
        //does, so nothing can be sent in before this
        wait (DUT.locked == 1'b1);
        repeat (100) @(posedge DUT.clk_75);

        //TC1: Send hex 47 

            //send the first byte, and let the echo finish before sending the second
            send_serial(8'h47);
            repeat (100) @(posedge DUT.clk_75);
            check("TC1: register x2 = 0x47", DUT.id_inst.reg_file.register[2], 8'h47);
            
            repeat (7000) @(posedge DUT.clk_75);
            
            
       //TC2: Send hex 48 
            
            //send the second byte
            send_serial(8'h48);
            repeat (100) @(posedge DUT.clk_75);
            check("TC2: register x2 = 0x48", DUT.id_inst.reg_file.register[2], 8'h48);
            
            repeat (7000) @(posedge DUT.clk_75);
        
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(2,  32'h48);     //last byte read out of RX_DATA
            check_reg(10, 32'h1000);   //UART base, from lui
            check_reg(0,  32'd0);      //x0 stays zero always
            
            if (tx_pulses !== 2) begin
                $error("(time: %0t) transmissions = %0d, expected 2", $time, tx_pulses);
                errors++;
            end
       
       
        $display("");
        //Check for errors written in check_reg task     
            
            if (errors == 0) 
                $display("PASS: both bytes echoed");
            else             
                $display("FAIL: %0d mismatches", errors);


        $display("");
        $display("End of CPU Testbench - AXI4Lite-UART echo.");
        $display("");
                        
        $finish;
    end

endmodule