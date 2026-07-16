`timescale 1ns / 1ps

module tb_register_file();

    localparam CLK_PERIOD = 10;

    logic clk;
    logic reset;
    
    logic [4:0] rs1;    
    logic [4:0] rs2;
    logic write_enable;
    logic [31:0] write_value; 
    logic [4:0] rd;
        
    logic [31:0] out_rs1;
    logic [31:0] out_rs2;
    
    register_file DUT (
    
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .write_enable(write_enable),
        .write_value(write_value),
        .rd(rd),
        .out_rs1(out_rs1),
        .out_rs2(out_rs2)

    );
  
    //clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;
    
    //TASKS
    
    //check task
    task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
        if(got === expected) //=== can detect PASS or FAIL on X (unknown) circumnstances
            $display("PASS %s (time: %0t)", label, $time);
        else
            $error("FAIL %s - got: %0d, expected: %0d (time: %0t)", label, got, expected, $time); 

    endtask
    
    //write task
    task do_write(input logic [4:0] address, input logic [31:0] value, input logic task_write_enable);
    
        rd = address;
        write_value = value;
        write_enable = task_write_enable;
        
        @(posedge clk);
        #1;
        
        write_enable = 0;
    
    endtask
    
    //SVA's
    
        //SVA 1: when rs1 is 0 (x0) , out_rs1 is 0 always
        
        property p_x0_rs1;
            @(posedge clk) disable iff (reset)
                (rs1 == 5'b0) |-> (out_rs1 == 32'b0);    
        endproperty
        
        p_check_x0_rs1: assert property (p_x0_rs1)
            else $error("SVA 1 FAILED: out_rs1 is not 0 when rs1 is 0 (x0 must always be 0 when read)");
        
        
        //SVA 2: when rs2 is 0 (x0) , out_rs2 is 0 always
            
        property p_x0_rs2;
            @(posedge clk) disable iff (reset)
                (rs2 == 5'b0) |-> (out_rs2 == 32'b0);
        endproperty       
   
        p_check_x0_rs2: assert property (p_x0_rs2)
            else $error("SVA 2 FAILED: out_rs2 is not 0 when rs2 is 0 (x0 must always be 0 when read)");
            
     //End of SVA's       
            
    
    initial begin
    
        //initialize DUT inputs, press reset HIGH to initialize all 32 registers to 0 (to avoid X's) 
        reset = 1; rs1 = 5'b0; rs2 = 5'b0; write_enable = 0; write_value = 32'b0; rd = 5'b0;
        
        //synchronous reset
        @(posedge clk);
        #1;
        
        reset = 0;
        
        #10;       
        
        
        /*
            Corner cases to cover:
            
                1. Normal write
                2. Normal read (from previous TC1 write)
                3. Write in x0 a random value, but reading x0 will be 0
                4. Trying to write a register with write_enable = 0 , register should keep its old value (not update)
                5. Overwrite: writing a value to a register , then another one , to confirm t updates correctly
                6. Read before write posedge clk: in the same moment a write is requested, read the register (before the posedge clk) read must show the old value
                7. Reset registers: raising reset HIGH should clear all 32 registers back to 0
                  
        */
        
        $display("");
        
        //TC1: Normal write
        
        do_write(5'd10, 32'd999, 1);
        check ("TC1 normal write into register x10 - x10 = 999 decimal", DUT.register[5'd10], 32'd999);
        $display("");
        
        //TC2: Normal read (from previous TC1 write) 
            
        rs1 = 5'd10;
        #10;
        
        check ("TC2 normal rs1 read into register x10 - got 999 in out_rs1", out_rs1, 32'd999);
        rs1 = 5'd0;// reset rs1 back to 0 just for waveform purpose
        #1;
        $display("");
        
        //TC3: Write in x0 a random value, but reading x0 will be 0
        
        do_write(5'd0, 32'd78, 1);
        rs2 = 5'd0;
        check ("TC3 read into x0 got 0, not 78 decimal", out_rs2, 32'd0);
        #1;
        $display("");
        
        //TC4: Trying to write a register with write_enable = 0 , register should keep its old value (not update)
        
        //first we write a value to a register
        do_write(5'd20, 32'd13, 1);
        check ("TC4a x20 write of value 13 decimal completed", DUT.register[5'd20], 32'd13);
        #1;
        
        //then, we try to write another value to x20 but with write_enable = 0
        do_write(5'd20, 32'd199, 0);
        check ("TC4b x20 write of value 199 decimal does NOT write. old value 13 decimal kept it (write_enable = 0)", DUT.register[5'd20], 32'd13);
        #1;
        $display("");
        
        //TC5: Overwrite - writing a value to a register , then another one , to confirm t updates correctly
        
        do_write(5'd31, 32'd200, 1);
        check ("TC5a first write into register x31 - x31 = 200 decimal", DUT.register[5'd31], 32'd200);
        #1;
        
        do_write(5'd31, 32'd45, 1);
        check ("TC5b second write into register x31 - x31 = 45 decimal. Updated", DUT.register[5'd31], 32'd45);
        #1;
        $display("");
        
        //TC6: Read before write posedge clk: in the same moment a write is requested, read the register (before the posedge clk) read must show the old value        
        
        //We will use the same old value of x31 of TC5 (45 decimal)
        rd = 5'd31;
        write_value = 32'd456;
        write_enable = 1;
        
        check ("TC6a stayed the old value of x31 before the clock edge (45 decimal)", DUT.register[5'd31], 32'd45);
        
        @(posedge clk);
        #1;
        
        write_enable = 0;
        check ("TC6b after the clock edge, x31 got updated to 456 decimal", DUT.register[5'd31], 32'd456);
        #1;
        $display("");
        
        //TC7: Reset registers - raising reset HIGH should clear all 32 registers back to 0
        
        reset = 1;
        
        //synchronous reset
        @(posedge clk);
        #1;
        
        for(int i = 0; i < 32; i = i + 1) begin
        
        rs1 = i;
        #1;
        
        // we use $sformatf (building a valid string from variables) to show the i variables in tcl console
        check($sformatf("TC7 - register x%0d reseted to 0", i), out_rs1, 32'd0);
        
        end
        
        reset = 0;
        
        #10;
        $display("");
        $display("END OF REGISTER FILE TESTBENCH");
        $display("");       
    
        $finish;
    end   

endmodule
