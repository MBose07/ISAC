`timescale 1ns/1ps

module cpe_data_delay #(
    parameter DATA_WIDTH = 16,
    parameter DELAY_CYCLES = 144 // 128 (Symbol) + 16 (CORDIC Latency)
)(
    input wire clk,
    input wire rst,
    
    // Incoming stream from the Equalizer
    input wire valid_in,
    input wire is_data_in,
    input wire signed [DATA_WIDTH-1:0] eq_in_i,
    input wire signed [DATA_WIDTH-1:0] eq_in_q,

    // Outgoing delayed stream to the Phase Rotator
    output wire valid_out,
    output wire is_data_out,
    output wire signed [DATA_WIDTH-1:0] eq_out_i,
    output wire signed [DATA_WIDTH-1:0] eq_out_q
);

    // 1. The Physical Memory Arrays
    reg signed [DATA_WIDTH-1:0] delay_i [0:DELAY_CYCLES-1];
    reg signed [DATA_WIDTH-1:0] delay_q [0:DELAY_CYCLES-1];
    
    reg valid_pipe [0:DELAY_CYCLES-1];
    reg is_data_pipe [0:DELAY_CYCLES-1];

    integer k;

    // 2. The Shift Register Logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (k = 0; k < DELAY_CYCLES; k = k + 1) begin
                delay_i[k]      <= {DATA_WIDTH{1'b0}};
                delay_q[k]      <= {DATA_WIDTH{1'b0}};
                valid_pipe[k]   <= 1'b0;
                is_data_pipe[k] <= 1'b0;
            end
        end 
        else begin
            // Stage 0 catches the fresh incoming data
            delay_i[0]      <= eq_in_i;
            delay_q[0]      <= eq_in_q;
            valid_pipe[0]   <= valid_in;
            is_data_pipe[0] <= is_data_in;

            // Shift everything down one bucket per clock tick
            for (k = 1; k < DELAY_CYCLES; k = k + 1) begin
                delay_i[k]      <= delay_i[k-1];
                delay_q[k]      <= delay_q[k-1];
                valid_pipe[k]   <= valid_pipe[k-1];
                is_data_pipe[k] <= is_data_pipe[k-1];
            end
        end
    end

    // 3. Output Connections
    assign eq_out_i    = delay_i[DELAY_CYCLES-1];
    assign eq_out_q    = delay_q[DELAY_CYCLES-1];
    assign valid_out   = valid_pipe[DELAY_CYCLES-1];
    assign is_data_out = is_data_pipe[DELAY_CYCLES-1];

endmodule