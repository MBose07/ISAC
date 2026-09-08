`timescale 1ns/1ps

module bpsk_demod_stream #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst,
    
    input wire valid_in,
    input wire is_data,
    input wire signed [DATA_WIDTH-1:0] y_i,
    input wire signed [DATA_WIDTH-1:0] y_q,
    
    output reg valid_out,
    output reg bit_out
);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_out <= 1'b0;
            bit_out   <= 1'b0;
        end else begin
            // Step 2: Default to invalid
            valid_out <= 1'b0;
            
            // Step 3: Filter for active data subcarriers
            if (valid_in && is_data) begin
                valid_out <= 1'b1;
                
                // Step 4: BPSK zero-crossing threshold
                bit_out <= (y_i > 0) ? 1'b1 : 1'b0;
            end
        end
    end

endmodule