`timescale 1ns / 1ps

module uart_rx(

    input clk,
    input reset,
    input rx,
    output [7:0] rx_byte,
    output done

);
    parameter IDLE = 0, DATA = 1, DONE = 2, ERROR = 3;

    //FULL_CYCLE is the last count of a 868-cycle bit period (0 to 867)
    //HALF_CYCLE is the midpoint of the bit period, where rx gets sampled
    //LAST_BIT is the index past the final data bit, marks end of DATA state

    localparam FULL_CYCLE = 10'd867;
    localparam HALF_CYCLE = 10'd433;
    localparam LAST_BIT   = 4'd8;

    reg [3:0] d_counter;
    reg [1:0] state, next_state;
    reg [7:0] store_rx;
    reg [9:0] cycle_counter;
    reg sample_rx;

    //counter of cycles: counts 0 to FULL_CYCLE within whatever state we're in,
    //resets to 0 every time we change state
    always @(posedge clk) begin
        if (reset)
            cycle_counter <= 10'd0;
        else if (cycle_counter == FULL_CYCLE)
            cycle_counter <= 10'd0;
        else
            cycle_counter <= cycle_counter + 10'd1;
    end

    //sample rx once, at the midpoint of every bit, the same way for every state
    always @(posedge clk) begin
        if (cycle_counter == HALF_CYCLE)
            sample_rx <= rx;
    end

    //state register, advances on cycle_counter==FULL_CYCLE instead
    //of advancing every single clock edge
    always @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else if (cycle_counter == FULL_CYCLE)
            state <= next_state;
    end

    //data bit counter, only counts in DATA, stores each bit at the midpoint
    always @(posedge clk) begin
        if (state != DATA)
            d_counter <= 4'd0;
        else if (cycle_counter == HALF_CYCLE)
            store_rx[d_counter] <= rx;
        else if (cycle_counter == FULL_CYCLE)
            d_counter <= d_counter + 4'd1;
    end

    //state transition logic
    always @(*) begin
        case(state)
            IDLE:    next_state = sample_rx ? IDLE : DATA;
            DATA:    next_state = (d_counter == LAST_BIT) ? (sample_rx ? DONE : ERROR) : DATA;
            DONE:    next_state = sample_rx ? IDLE : DATA;
            ERROR:   next_state = sample_rx ? IDLE : ERROR;
            default: next_state = IDLE;
        endcase
    end

    assign done = (state == DONE);
    assign rx_byte = (state == DONE) ? store_rx : 8'd0;

endmodule
