`timescale 1ns / 1ps 

module tb_rv32i_command_interpreter();

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
    
        .PROGRAM("program_command_interpreter.hex")
    
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
    logic [7:0] last_tx_byte = 8'h00;

        //check_reg task: Checks if expected values in specified register are the same as real register.
        task check_reg(input int idx_reg, input logic [31:0] expected);
        
            //!== can also check X's
            if(DUT.id_inst.reg_file.register[idx_reg] !== expected) begin
                $error("(time: %0t) register x%0d = %0h, expected = %0h", $time, idx_reg, DUT.id_inst.reg_file.register[idx_reg], expected);    
                errors++;
            end
                
        endtask   
        
    
        //count and record every byte handed to the transmitter
        always_ff @(posedge DUT.clk_75) begin
        
            if(DUT.slave_inst.tx_start) begin
                tx_pulses++;
                last_tx_byte <= DUT.slave_inst.tx_byte;
            end
            
        end
        
        
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



        //send_command task: sends one character, waits long enough for the reply to reach the transmitter

        task send_command(input string label, input logic [7:0] cmd, input logic [7:0] expected);
        
            int pulses_before;
            
            begin
                pulses_before = tx_pulses;
                
                send_serial(cmd);
                
                //one 8N1 frame out is about 6510 cycles, leave room for the poll too
                repeat (12000) @(posedge DUT.clk_75);


                if (tx_pulses !== pulses_before + 1) begin
                    $error("(time: %0t) %s sent %0d bytes, expected 1", $time, label, tx_pulses - pulses_before);
                    errors++;
                end
                else if (last_tx_byte !== expected) begin
                    $error("(time: %0t) %s replied %0h, expected %0h", $time, label, last_tx_byte, expected);
                    errors++;
                end
                else
                    $display("(time: %0t) PASS %s", $time, label);
            end
            
        endtask
        
        
    /*

        program_command_interpreter.hex
        Reads a byte from the UART and replies according to which command it is:

            f : compute Fibonacci and send F(12) = 233 (0xe9)
            c : send the counter, then advance it - 0 first, then 1, 2...
            p : send the last ordinary byte received, '-' if none yet
            z : 'Y' if the counter has never been used, 'N' once it has anything else : send it back uppercased, and remember it for 'p'

        The command bytes are ASCII codes, not arbitrary values: 'f' is 0x66, 'c' is
        0x63, 'p' is 0x70, 'z' is 0x7a. A byte matching none of them takes the default
        path, so 0x61 ('a') exercises the uppercase and the 'p' memory in one go.

        TC2 must run before any 'c' for 'Y' to be correct, and TC5 must run after one
        for 'N'. TC6 checks that the 'a' from TC1 was remembered across five intervening
        commands, which only holds if x8 survives every dispatch path.


        No co-simulation for this program: the C ISS has no AXI4-Lite UART, so it has
        nothing to receive a byte with and no STATUS register to poll.

    */
    
    
    //main stimulus
    initial begin
    
        $display("");
        $display("Start of CPU Testbench - AXI4Lite-UART command interpreter:");
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


        //TC1: default path - 'a' comes back uppercased, and is remembered for 'p'
        send_command("TC1: 'a' uppercased to 'A'", 8'h61, 8'h41);

        //TC2: counter untouched so far
        send_command("TC2: 'z' answers 'Y'", 8'h7a, 8'h59);

        //TC3: first counter value
        send_command("TC3: 'c' answers '0'", 8'h63, 8'h30);

        //TC4: counter advances
        send_command("TC4: 'c' answers '1'", 8'h63, 8'h31);

        //TC5: counter has now been used
        send_command("TC5: 'z' answers 'N'", 8'h7a, 8'h4e);

        //TC6: 'p' returns the 'a' from TC1, five commands ago
        send_command("TC6: 'p' answers 'a'", 8'h70, 8'h61);

        //TC7: fibonacci, F(12) = 233. Sent last because it is the only command with a
        //loop in it, so the branch flush gets exercised hardest here.
        send_command("TC7: 'f' answers e9", 8'h66, 8'he9);
        
        
        //Program runned. Now:
        
        $display("");
        //Check if each register is correct
        
            check_reg(4, 32'h32);     //counter advanced twice, '0' -> '2'
            check_reg(8, 32'h61);     //previous byte still the 'a' from TC1
            check_reg(10, 32'h1000);   //UART base, from lui, never rewritten
            check_reg(0, 32'd0);      //x0 stays zero always
       
       
        $display("");
        //Check for errors written in the check tasks     
            
            if (errors == 0) 
                $display("PASS: all commands answered correctly");
            else             
                $display("FAIL: %0d mismatches", errors);


        $display("");
        $display("End of CPU Testbench - AXI4Lite-UART command interpreter.");
        $display("");
                        
        $finish;
    end

endmodule