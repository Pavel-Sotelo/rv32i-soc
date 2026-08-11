`timescale 1ns / 1ps

module axi4lite_master #(

    parameter ADDR_WIDTH = 4   //register length

)(
        input logic clk,    
        input logic reset,
        
        //CPU side signals
        input logic uart_start,
        input logic sel_write_read,
        input logic [ADDR_WIDTH - 1:0] cpu_addr,
        input logic [31:0] cpu_write_data,
        output logic [31:0] cpu_read_data,
        //output signal that raises when READ is done (for lw stall)
        output logic read_done,
        
    
        //WRITE ADDRESS CHANNEL (AW)
        output logic [ADDR_WIDTH - 1:0] AWADDR,
        output logic AWVALID,
        input logic AWREADY,
    
        //WRITE DATA CHANNEL (W)
        output logic [31:0] WDATA,   //32-bit standard AXI bus width
        output logic WVALID,
        input logic WREADY,    
    
        //WRITE RESPONSE CHANNEL (B)
        input logic [1:0] BRESP,
        input logic BVALID,
        output logic BREADY,  
    
        //READ ADDRESS CHANNEL (AR)
        output logic [ADDR_WIDTH - 1:0] ARADDR,
        output logic ARVALID,
        input logic ARREADY,   
    
        //WRITE RESPONSE CHANNEL (B)
        input logic [31:0] RDATA,    //32-bit standard AXI bus width 
        input logic [1:0] RRESP,
        input logic RVALID,
        output logic RREADY  
        
        //UART TX & RX belong to AXI slave, not master

    );
    

    //STATES
    localparam IDLE = 0, WRITE = 1, WRITE_RESP = 2, READ = 3, READ_RESP = 4;
    
    logic [2:0] state, next_state;    
    
    
    //signals to capture during IDLE transitions (to avoid if they change on following states)
    logic [ADDR_WIDTH - 1:0] CAPTURED_AWADDR;
    logic [31:0] CAPTURED_WDATA;
    logic [ADDR_WIDTH - 1:0] CAPTURED_ARADDR; 
    
    
    
    
    //state sequential logic
    always_ff @(posedge clk) begin
    
        if (reset) begin
            state <= 3'b0;
        end else begin
            state <= next_state;
        end

    end        
    
    //WRITE logic:
    
        //capture AWADDR and WDATA during the IDLE->WRITE transition
        always_ff @(posedge clk) begin
        
            if(reset) begin
            
                CAPTURED_AWADDR <= '0;                
                CAPTURED_WDATA  <= '0;
                        
            end else if(state == IDLE && uart_start && sel_write_read) begin
            
                CAPTURED_AWADDR <= cpu_addr;
                CAPTURED_WDATA  <= cpu_write_data;
                
            end
            
        end   
    
    
     //READ logic:
    
    
        //capture ARADDR during the IDLE->READ transition
        always_ff @(posedge clk) begin
        
            if(reset)
                CAPTURED_ARADDR <= '0;                
                        
            else if(state == IDLE && uart_start && (~sel_write_read))
                CAPTURED_ARADDR <= cpu_addr;
                      
        end       
    

        //Capture RDATA in READ_RESP next_state transition
        always_ff @(posedge clk) begin
        
            if(reset) begin
                cpu_read_data <= '0;
                read_done <= 0;    
                        
            end else if(state == READ_RESP && RVALID) begin
                cpu_read_data <= RDATA;
                read_done <= 1;
                
            end else begin
                read_done <= 0;
                
            end
        end      
    


    //state transition logic
    always_comb begin
    
        case (state)
    
            IDLE: next_state = uart_start? (sel_write_read? WRITE : READ) : IDLE;    
            WRITE: next_state = (AWREADY & WREADY)? WRITE_RESP : WRITE; 
            WRITE_RESP: next_state = BVALID? IDLE : WRITE_RESP;
            READ: next_state = ARREADY? READ_RESP : READ;          
            READ_RESP: next_state = RVALID? IDLE : READ_RESP;  

            default: next_state = IDLE;
        endcase
        
    end
    
    
    //state output's logic        
    
    always_comb begin
    
        //initialize inputs to avoid latches
        AWADDR = '0; WDATA = '0; AWVALID = 0; WVALID = 0;
        BREADY = 0; ARADDR = '0; ARVALID = 0; RREADY = 0;
            
        case (state)
    
            WRITE: begin                            
                        AWADDR = CAPTURED_AWADDR;          
                        WDATA = CAPTURED_WDATA;                
                        AWVALID = 1;
                        WVALID  = 1;
                   end

            WRITE_RESP: BREADY = 1; 
            
            READ: begin
                        ARADDR = CAPTURED_ARADDR;  
                        ARVALID = 1;
                  end  
 
            READ_RESP: RREADY = 1;  

        endcase
        
    end    
    
endmodule