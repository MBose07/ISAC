`timescale 1ns/1ps

module ch_est #(
    parameter data_width = 16,
    parameter max_subcarrier = 128,
    parameter idx_width = $clog2(max_subcarrier) 
)(
    // Input
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire [idx_width-1:0] idx, 
    input wire signed [data_width-1:0] sc_in_i,
    input wire signed [data_width-1:0] sc_in_q,
    
    // Output
    output reg valid_out,
    output reg signed [data_width-1:0] H_out_i,
    output reg signed [data_width-1:0] H_out_q
);

    // -------------------------------------------------------------
    // Subcarrier Classification
    // -------------------------------------------------------------
    wire is_null = (idx == 0) || (idx >= 1 && idx <= 5) || (idx >= (max_subcarrier - 5) && idx <= max_subcarrier-1);
    
    wire is_pilot = (idx == 12) || (idx == 24) || (idx == 36) || (idx == 48) || 
                    (idx == 60) || (idx == 68) || (idx == 80) || (idx == 92) ||    
                    (idx == 104);
                    
    wire is_data = ~(is_null | is_pilot);

    // -------------------------------------------------------------
    // Memory and State Machine
    // -------------------------------------------------------------
    // Inferred Block RAM: 128 depth x 32-bit width (16-bit I + 16-bit Q)
    reg [31:0] channel_memory [0:127];
    
    // 0 = Training Symbol Mode (Calculate H and write to memory)
    // 1 = Payload Symbol Mode (Read H from memory, skip calculations)
    reg payload_mode; 
    
    reg data_cnt_is_odd;

    // -------------------------------------------------------------
    // Main Processing Block
    // -------------------------------------------------------------
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_out <= 1'b0;
            H_out_i   <= {data_width{1'b0}}; 
            H_out_q   <= {data_width{1'b0}};
            payload_mode <= 1'b0;
            data_cnt_is_odd <= 1'b1;
        end
        else if (valid_in) begin
            valid_out <= 1'b1;

            if (payload_mode == 1'b0) begin
                // =========================================================
                // STATE 0: TRAINING MODE
                // Calculate channel estimates and save them into RAM
                // =========================================================
                
                // Track alternating data subcarriers
                if (idx == max_subcarrier - 1) begin
                    data_cnt_is_odd <= 1'b1;
                    payload_mode <= 1'b1; // Switch to payload mode for the next symbol
                end
                else if (is_data) begin
                    data_cnt_is_odd <= ~data_cnt_is_odd;
                end
                
                // Calculate and store H
                if (is_null) begin
                    H_out_i <= 16'h7FFF;
                    H_out_q <= 16'h0000;
                    channel_memory[idx] <= {16'h7FFF, 16'h0000};
                end
                else if (is_pilot) begin
                    H_out_i <= sc_in_i;
                    H_out_q <= sc_in_q;
                    channel_memory[idx] <= {sc_in_i, sc_in_q};
                end
                else if (is_data) begin
                    if (data_cnt_is_odd == 1'b0) begin
                        H_out_i <= sc_in_i;
                        H_out_q <= sc_in_q;
                        channel_memory[idx] <= {sc_in_i, sc_in_q};
                    end 
                    else begin
                        // Reverse the -1 training sequence (match MATLAB reference)
                        H_out_i <= ~sc_in_i + 1'b1;
                        H_out_q <= ~sc_in_q + 1'b1;
                        channel_memory[idx] <= {(~sc_in_i + 1'b1), (~sc_in_q + 1'b1)};
                    end
                end
            end 
            else begin
                // =========================================================
                // STATE 1: PAYLOAD MODE
                // Stop calculating, just output the saved H from RAM
                // =========================================================
                H_out_i <= channel_memory[idx][31:16];
                H_out_q <= channel_memory[idx][15:0];
            end
        end
        else begin
            valid_out <= 1'b0;
        end
    end

endmodule