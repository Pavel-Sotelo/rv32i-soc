`timescale 1ns / 1ps

module tb_axi4lite_master_slave();

    localparam ADDR_WIDTH = 4;
    localparam CLK_PERIOD = 10;

    logic clk, reset;
    
    //CPU side signals
    logic uart_start;
    logic sel_write_read;
    logic [ADDR_WIDTH - 1:0] cpu_addr;
    logic [31:0] cpu_write_data;
    logic [31:0] cpu_read_data;
        
    
    //WRITE ADDRESS CHANNEL (AW)    
    logic [ADDR_WIDTH - 1:0] AWADDR;
    logic AWVALID;
    logic AWREADY;

    //WRITE DATA CHANNEL (W)
    logic [31:0] WDATA;
    logic WVALID;
    logic WREADY;    

    //WRITE RESPONSE CHANNEL (B)
    logic [1:0] BRESP;
    logic BVALID;
    logic BREADY;  

    //READ ADDRESS CHANNEL (AR)
    logic [ADDR_WIDTH - 1:0] ARADDR;
    logic ARVALID;
    logic ARREADY;   

    //WRITE RESPONSE CHANNEL (B)
    logic [31:0] RDATA;
    logic [1:0] RRESP;
    logic RVALID;
    logic RREADY;  

    //UART I/O (tx output, rx input) 
    logic uart_wire;


    axi4lite_master DUT_MASTER (
    
        .clk(clk),
        .reset(reset),
        
        .uart_start(uart_start),
        .sel_write_read(sel_write_read),
        .cpu_addr(cpu_addr),
        .cpu_write_data(cpu_write_data),
        .cpu_read_data(cpu_read_data),

        .AWADDR(AWADDR),    
        .AWVALID(AWVALID),  
        .AWREADY(AWREADY),
        
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
    
        .ARADDR(ARADDR),    
        .ARVALID(ARVALID),  
        .ARREADY(ARREADY),        
    
        .RDATA(RDATA),        
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY) 

    );


    axi4lite_wrapper_uart DUT_SLAVE (
    
        .clk(clk),
        .reset(reset),
        
        .AWADDR(AWADDR),    
        .AWVALID(AWVALID),  
        .AWREADY(AWREADY),
        
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
    
        .ARADDR(ARADDR),    
        .ARVALID(ARVALID),  
        .ARREADY(ARREADY),        
    
        .RDATA(RDATA),        
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY),

        .rx(uart_wire),
        .tx(uart_wire)    

    );
    

    //Task's
    
        //check task
        task check (input string label, input logic [31:0] got, input logic [31:0] expected);
    
            if (got === expected)
                $display("PASS %s (time: %0t)", label, $time);
            else
                $error("FAIL %s - got %0d, expected %0d (time: %0t)", label, got, expected, $time);
    
        endtask

    
    //SVA'S to check VALID and READY signals:
    
        //SVA 1: Check AWVALID and WVALID signals after a WRITE request in the previous cycle (IDLE state), both must be HIGH
    
            property p_awvalid_wvalid;
                @(posedge clk) disable iff (reset)
                ((DUT_MASTER.state == DUT_MASTER.IDLE) & uart_start & sel_write_read) |=> (AWVALID & WVALID);
            endproperty
        
            check_p_awvalid_wvalid: assert property (p_awvalid_wvalid)
                else $error("SVA 1 failed - AWVALID & WVALID aren't HIGH after a WRITE request (time: %0t)", $time);
    
            
        //SVA 2: Check BREADY signal after AWREADY and WREADY got HIGH in the previous cycle, in WRITE state  
    
            property p_bready;
                @(posedge clk) disable iff (reset)
                ((DUT_MASTER.state == DUT_MASTER.WRITE) & AWREADY & WREADY) |=> (BREADY);
            endproperty
    
            check_p_bready: assert property (p_bready)
                else $error("SVA 2 failed - BREADY is LOW after WRITE->WRITE_RESP transition (time: %0t)", $time);
    
    
        //SVA 3: Check ARVALID signal after a READ request in the previous cycle (IDLE state), must be HIGH
    
            property p_arvalid;
                @(posedge clk) disable iff (reset)
                ((DUT_MASTER.state == DUT_MASTER.IDLE) & uart_start & (~sel_write_read)) |=> (ARVALID);
            endproperty
        
            check_p_arvalid: assert property (p_arvalid)
                else $error("SVA 3 failed - ARVALID is LOW after a READ request (time: %0t)", $time);
    
            
        //SVA 4: Check RREADY signal after ARREADY got HIGH in the previous cycle, in READ state  
    
            property p_rready;
                @(posedge clk) disable iff (reset)
                ((DUT_MASTER.state == DUT_MASTER.READ) & ARREADY) |=> (RREADY);
            endproperty
    
            check_p_rready: assert property (p_rready)
                else $error("SVA 4 failed - RREADY is LOW after READ->READ_RESP transition (time: %0t)", $time);    
    
        /*
          SVA 5: Check if AWVALID is high and AWREADY is not (so the transfer hasn't happened yet),
                 then on the next cycle AWVALID must still be high and the address must not have changed
        */
    
            property p_awvalid_stable;     
                @(posedge clk) disable iff (reset)
                (AWVALID & ~AWREADY) |=> (AWVALID && $stable(AWADDR));
            endproperty
    
            check_p_awvalid_stable: assert property (p_awvalid_stable)
                else $error("SVA 5 failed - AWVALID dropped or AWADDR changed before the handshake completed (time: %0t)", $time);      
    
    
        /*
          SVA 6: Same rule on the write data channel: WVALID must hold and WDATA must not
                 change until WREADY completes the handshake
        */
    
            property p_wvalid_stable;     
                @(posedge clk) disable iff (reset)
                (WVALID & ~WREADY) |=> (WVALID && $stable(WDATA));
            endproperty
    
            check_p_wvalid_stable: assert property (p_wvalid_stable)
                else $error("SVA 6 failed - WVALID dropped or WDATA changed before the handshake completed (time: %0t)", $time);
    
    
        /*
          SVA 7: Same rule on the read address channel: ARVALID must hold and ARADDR must
                 not change until ARREADY completes the handshake
        */
    
            property p_arvalid_stable;     
                @(posedge clk) disable iff (reset)
                (ARVALID & ~ARREADY) |=> (ARVALID && $stable(ARADDR));
            endproperty
    
            check_p_arvalid_stable: assert property (p_arvalid_stable)
                else $error("SVA 7 failed - ARVALID dropped or ARADDR changed before the handshake completed (time: %0t)", $time);
    
    
    //End of SVA's


    //clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;


    //MAIN stimulus: 
    initial begin
    
        $display("");
        $display("Start of full AXI4-Lite CPU and UART testbench");

    
        //initialize CPU input signals:
        
            uart_start = 0;
            sel_write_read = 0;
            cpu_addr = '0;
            cpu_write_data = '0;
        
        //Raise reset to initialize states in IDLE 
           
            reset = 1;
            @(posedge clk) #1;        
            reset = 0;     #1;
        
            
        /*
            Corner cases to cover:

            An integration testbench: the master drives the real slave, with tx looped
            back to rx. The slave's own testbench covers its internals; what is new
            here is that the two sides of the protocol agree.

            1. Write: The address and data are captured on the IDLE->WRITE edge, so
               changing the CPU inputs mid-transaction must not reach the slave.
               Checked by changing them, then confirming the slave pulses tx_start.

            2. Read STATUS: Same capture check on the read address. tx_busy is still
               high from TC1, so STATUS reads 001,  real state, not a constant.

            3. Full round trip: The TC1 byte comes back through the loopback and is
               read out of RX_DATA. Master write, slave, uart_tx, wire, uart_rx, slave,
               master read: every module has to be correct for this value to return.
        */
    
    
        $display("");
        //TC1:
        
            //Insert CPU signals to master (WRITE): 
            uart_start = 1; sel_write_read = 1; cpu_addr = 4'h0; cpu_write_data = 32'd234; 
            
            @(posedge clk) #1;
            uart_start = 0;    
        
            //Now in this cycle , Master is in WRITE state and Slave is receiving master outputs (still IDLE)
            //First we do a little test to prove that CAPTURED_AWADDR & CAPTURED_WDATA got captured the past cycle and not in this cycle
            //We change values to see if it captured the past ones , not this ones
            cpu_addr = 4'h4;
            cpu_write_data = 32'd231;
            
            check("TC1 AXI Master IDLE->WRITE transition, captured AWADDR = 0x0 in the next cycle", DUT_MASTER.CAPTURED_AWADDR, 4'h0);
            check("TC1 AXI Master IDLE->WRITE transition, captured WDATA = 234 decimal in the next cycle", DUT_MASTER.CAPTURED_WDATA, 32'd234);
        
            @(posedge clk) #1;
            //Now Slave is in WRITE state, we check if tx_start is HIGH the NEXT cycle:
            @(posedge clk) #1;
            
            check("TC1 AXI Slave raised tx_start HIGH in the next cycle", DUT_SLAVE.tx_start, 1);
        
            //let slave finish states to return to IDLE for TC2
            repeat (5) @(posedge clk) #1;
        
        //End of TC1.
        
        $display("");
        //TC2:
        
            //Insert CPU signals to master (READ STATUS): 
            uart_start = 1; sel_write_read = 0; cpu_addr = 4'h8;
            
            @(posedge clk) #1;
            uart_start = 0;    
        
            //Now in this cycle , Master is in READ state and Slave is receiving master outputs (still IDLE)
            //We change address to see if it captured the past one, not this one
            cpu_addr = 4'h4;
            
            check("TC2 AXI Master IDLE->READ transition, captured ARADDR = 0x8 in the next cycle", DUT_MASTER.CAPTURED_ARADDR, 4'h8);
        
            @(posedge clk) #1;
            //Now Slave is in READ state, we check if RDATA is 32'b001 (overrun and captured_done LOW, tx_busy HIGH, due to previous TC1 write)
            @(posedge clk) #1;
            
            check("TC2 AXI Slave got RDATA = 001 (tx_busy HIGH due to TC1)", RDATA, 32'b001);
         
    
        //End of TC2.
        
        $display("");
        //TC3:            
            
            //wait to TC1 byte (234 decimal) to get finished so we can read it after
            wait (DUT_SLAVE.CAPTURED_DONE == 1);    
            
            
            //Insert CPU signals to master (READ RX_DATA): 
            uart_start = 1; sel_write_read = 0; cpu_addr = 4'h4; 
            
            @(posedge clk) #1;
            uart_start = 0;               
            //Now in this cycle, Master is in READ state and Slave is receiving master outputs (still IDLE)
            @(posedge clk) #1;
            //Now in this cycle, Slave is in READ state, we check if RDATA is 32'd234 in the next cycle 
            @(posedge clk) #1;
            
            check("TC3 AXI Slave got RDATA = 234 decimal (TC1 byte finished)", RDATA, 32'd234);
                     
            #10;
 
        //End of TC3.
    
        $display("");
        $display("End of full AXI4-Lite CPU and UART testbench"); 
        $display("");
        
        $finish;
    end

endmodule
