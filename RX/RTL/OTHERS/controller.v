`timescale 1ns / 1ps

module controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // Triggers from Datapath
    input  wire        corr_matched,
    input  wire        est_valid_out,
    input  wire [15:0] est_angle_in,
    
    // Control to Datapath
    output         est_enable,
    output reg  [15:0] latched_angle,
    output reg         fft_en , 
    output reg     fifo_rd_en
);

    localparam IDLE     = 2'b00;
    localparam ESTIMATE = 2'b01;
    localparam STREAM   = 2'b10;

    reg [1:0] state, next_state;

    // 1. State Memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // 2. Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:     if (corr_matched)  next_state = ESTIMATE;
            ESTIMATE: if (est_valid_out) next_state = STREAM;
            STREAM:   next_state = STREAM; // Holds until global frame reset
            default:  next_state = IDLE;
        endcase
    end

    // 3. Registered Outputs (Glitch-free)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fft_en        <= 1'b0;
            latched_angle <= 16'd0;
        end else begin
            fft_en     <= (state == STREAM);
            fifo_rd_en <= (next_state == STREAM); // Asserted when in STREAM state
            
            // Latch the angle strictly on the transition into STREAM
            if (state == ESTIMATE && next_state == STREAM) begin
                latched_angle <= est_angle_in;
            end
        end
    end
    assign est_enable = (next_state == ESTIMATE);
endmodule