`timescale 1ns/1ps

module full_ofdm_rx_with_cfo #(
    parameter DATA_WIDTH = 16,
    parameter MAX_SUBCARRIER = 128,
    parameter CP_LEN = 32,
    parameter IDX_WIDTH = 7 
)(
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire signed [DATA_WIDTH-1:0] data_in_i,
    input  wire signed [DATA_WIDTH-1:0] data_in_q,
    output wire valid_out,
    output wire demod_bits_out 
);

    // =========================================================================
    // 1. CFO Correction, Cyclic Prefix Removal, and FFT Pipeline (`cfo_top`)
    // =========================================================================
    wire cfo_valid_out, cfo_last;
    wire signed [DATA_WIDTH-1:0] fft_out_re, fft_out_im;

    cfo_top #(
        .WIDTH(DATA_WIDTH),
        .N_FFT(MAX_SUBCARRIER),
        .CP_LEN(CP_LEN)
    ) u_cfo_top (
        .clk(clk),
        .reset(rst),
        .valid_in(valid_in),
        .real_in(data_in_i),
        .imag_in(data_in_q),
        .valid_out(cfo_valid_out),
        .last(cfo_last),
        .real_out(fft_out_re),
        .imag_out(fft_out_im)
    );

    // =========================================================================
    // 2. Subcarrier Index Generation for Post-FFT Stream
    // =========================================================================
    // The FFT outputs a fixed block of MAX_SUBCARRIER (128) bins per symbol when 
    // cfo_valid_out is high. We generate a rolling index (0 to MAX_SUBCARRIER-1) 
    // synchronized to cfo_valid_out to feed downstream components (`ch_est`, `equalizer`).
    reg [IDX_WIDTH-1:0] subcarrier_idx;

    always @(posedge clk or negedge rst ) begin
        if (!rst) begin
            subcarrier_idx <= 0;
        end else if (cfo_valid_out) begin
            if (subcarrier_idx == MAX_SUBCARRIER - 1 || cfo_last == 1) 
                subcarrier_idx <= 0;
            else
                subcarrier_idx <= subcarrier_idx + 1;
        end
    end

    // =========================================================================
    // 3. Channel Estimation
    // =========================================================================
    wire ch_est_valid;
    wire signed [DATA_WIDTH-1:0] H_i, H_q;
    
    ch_est #(
        .data_width(DATA_WIDTH),
        .max_subcarrier(MAX_SUBCARRIER),
        .idx_width(IDX_WIDTH)
    ) u_ch_est (
        .clk(clk), 
        .rst(rst),
        .valid_in(cfo_valid_out), 
        .idx(subcarrier_idx),
        .sc_in_i(fft_out_re), 
        .sc_in_q(fft_out_im),
        .valid_out(ch_est_valid),
        .H_out_i(H_i), 
        .H_out_q(H_q)
    );

    // =========================================================================
    // 4. Delay Line for Equalizer Alignment
    // =========================================================================
    reg signed [DATA_WIDTH-1:0] fft_out_re_d1, fft_out_im_d1;
    reg [IDX_WIDTH-1:0] subcarrier_idx_d1;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            fft_out_re_d1     <= 0;
            fft_out_im_d1     <= 0;
            subcarrier_idx_d1 <= 0;
        end else begin
            fft_out_re_d1     <= fft_out_re;
            fft_out_im_d1     <= fft_out_im;
            subcarrier_idx_d1 <= subcarrier_idx;
        end
    end

    // =========================================================================
    // 5. Zero-Forcing Equalizer
    // =========================================================================
    wire eq_valid_out;
    wire signed [DATA_WIDTH-1:0] eq_out_i, eq_out_q;
    wire eq_is_pilot, eq_is_data;
    
    equalizer_stream #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SUBCARRIER(MAX_SUBCARRIER),
        .IDX_WIDTH(IDX_WIDTH)
    ) u_equalizer (
        .clk(clk), 
        .rst(rst),
        .valid_in(ch_est_valid),
        .idx(subcarrier_idx_d1),
        .Y_i(fft_out_re_d1), 
        .Y_q(fft_out_im_d1),
        .H_i(H_i), 
        .H_q(H_q),
        .valid_out(eq_valid_out),
        .eq_out_i(eq_out_i), 
        .eq_out_q(eq_out_q),
        .is_pilot(eq_is_pilot), 
        .is_data(eq_is_data)
    );

    // =========================================================================
    // 6. Common Phase Error (CPE) Rotator
    // =========================================================================
    wire cpe_valid_out;
    wire cpe_is_data;
    wire signed [DATA_WIDTH-1:0] cpe_out_i, cpe_out_q;
    
    cpe_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .PHASE_WIDTH(16),
        .N_FFT(MAX_SUBCARRIER)
    ) u_cpe (
        .clk(clk), 
        .rst(rst),
        .valid_in(eq_valid_out),
        .is_pilot_in(eq_is_pilot), 
        .is_data_in(eq_is_data),   
        .eq_in_i(eq_out_i), 
        .eq_in_q(eq_out_q),
        .valid_out(cpe_valid_out),
        .is_data_out(cpe_is_data), 
        .eq_out_i(cpe_out_i), 
        .eq_out_q(cpe_out_q)
    );

    // =========================================================================
    // 7. BPSK Demodulator
    // =========================================================================
    bpsk_demod_stream #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_bpsk (
        .clk(clk), 
        .rst(rst),
        .valid_in(cpe_valid_out),
        .is_data(cpe_is_data),     
        .y_i(cpe_out_i), 
        .y_q(cpe_out_q),
        .valid_out(valid_out),
        .bit_out(demod_bits_out)
    );

endmodule
