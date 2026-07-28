`timescale 1ns / 1ps

module tb_data_memory();

    localparam CLK_PERIOD = 10;

    //DUT inputs
    logic clk;
    logic [31:0] addr;
    logic write_enable;
    logic [31:0] write_data;

    //DUT outputs
    logic [31:0] read_data;

    
    //DUT instantiation
    data_memory DUT(
    
        .clk(clk),
        .addr(addr),
        .write_enable(write_enable),
        .write_data(write_data),
        .read_data(read_data)
    
    );
 
 
    //check task
    task check (input string label, input logic [31:0] got, input logic [31:0] expected);

        if (got === expected)
            $display("PASS %s (time: %0t)", label, $time);
        else
            $error("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);

    endtask

    //write task
    task do_write(input logic [31:0] task_addr, input logic [31:0] task_write_data, input logic task_write_enable);
    
        addr = task_addr;
        write_data = task_write_data;
        write_enable = task_write_enable;
        
        @(posedge clk);
        #1;
        
        write_enable = 0;
    
    endtask


    //clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;
    
      
    //main stimulus  
    initial begin
    
        $display("");
        $display("Start of data memory testbench");
    
        //initialize DUT inputs
        addr = 32'd0;  write_enable = 0;  write_data = 32'd0;    
        
        @(posedge clk); 
        #1;
        
        /*
            Corner cases to cover:
            
                1. Write and read round trip: write a value, read it back one cycle later. 
                   Also proves the byte-to-word conversion (addr[9:2]), since byte address 16 must land in word 4.

                2. Write enable test: drive an address and write data with write_enable low.
                   The stored word must keep its old value, proving the memory only writes when we raise write_enabled HIGH.
          
                3. Read latency and read-first behaviour: read_data is valid one clock edge after the address is presented, not in the same cycle.
                   When a read and a write hit the same address on the same edge, read_data returns the old contents, not the new one
                  
                4. Address independence: writing to one word must not disturb any other word. Re-read the first address 
                   after writing a different one and confirm it is unchanged. 
        */        
    
        $display("");
        //TC1:
        
            //First, we write a value to d_memory[4] (byte addressed: address 16) with do_write task
            //with this we also check that the 4 divider of addresses works
            do_write(32'd16, 32'd583, 1); 
            check ("TC1 write into d_memory[4] = 583 decimal, after one cycle", DUT.d_memory[4], 32'd583); 
            #1;
            
            //now we read d_memory[4] to check if we get 583 decimal, after one cycle
            //(address is still 16, but we put it just for clarity)
            addr = 32'd16;
            
            @(posedge clk);
            #1;
            
            check ("TC1 read d_memory[4] got 583 decimal in read_data, after one cycle", read_data, 32'd583);
            #1;
            
        //End of TC1
           
        $display("");    
        //TC2:
        
            //Now we try to write 75 decimal to d_memory[4] but with NO write_enable, that shouldn't write the new value
            do_write(32'd16, 32'd75, 0); 
            check ("TC2 write into d_memory[4] with NO write_enable returns old value (583 decimal), after one cycle", DUT.d_memory[4], 32'd583); 
            #1;
            
            //now we read d_memory[4] to check if we get as well the old value (583)
            addr = 32'd16;
            
            @(posedge clk);
            #1;
            
            check ("TC2 read d_memory[4] got 583 decimal in read_data, NOT 75 decimal, after one cycle", read_data, 32'd583);
            #1;             
              
        //End of TC2      
        
        $display("");           
        //TC3:
        
            //First we write another value to another d_memory address, to stop working with d_memory[4] and test another addresses
            //We send address 36 (d_memory[9])
            do_write(32'd36, 32'd807, 1); 
            check ("TC3 write into d_memory[9] = 807 decimal, after one cycle", DUT.d_memory[9], 32'd807); 
            #1;                
        
            //we wait to the next clock edge to let read_data read d_memory[9] (address is still 36)
            @(posedge clk);
            #1;
            
            //now we send another value to the same d_memory[9], but we read before the next clock edge , to verify if we got the old value of d_memory[9]
                        
            check ("TC3 read d_memory[9] got 807 decimal in read_data, before the next cycle", read_data, 32'd807);
            
            do_write(32'd36, 32'd2045, 1);  
            #1;                
        
            @(posedge clk);
            #1; 
            
            //now read_data updated to the next cycle
            check ("TC3 read d_memory[9] got 2045 decimal in read_data, after the next cycle when d_memory[9] were already updated", read_data, 32'd2045);                       
            #1; 
            
        //End of TC3
        
        $display("");           
        //TC4:        
        
            //We read again address 16, to test address independency
            addr = 32'd16;
            
            @(posedge clk);
            #1;
            
            check ("TC4 read d_memory[4] got 583 decimal in read_data, after one cycle. address independency proven", read_data, 32'd583);
            #1;                
        
           
        //End of TC4
          
        $display("");
        $display("End of data memory testbench");
        $display("");
        
              
        $finish;
    end    


endmodule
