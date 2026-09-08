`timescale 1ns / 1ps

module cfo_top #(
    parameter WIDTH = 16,
    parameter N_FFT = 128,
    parameter CP_LEN = 32
) (
    input clk,
    input reset,

    // Unified Single-Pass Input Stream
    input valid_in,
    input signed [WIDTH-1:0] real_in,
    input signed [WIDTH-1:0] imag_in,
    
    // Hardware Outputs
    output valid_out,
    output last,
    output signed [WIDTH-1:0] real_out,
    output signed [WIDTH-1:0] imag_out
);

    wire corr_valid_out, corr_matched, cprem_valid_out, corrected_valid_out;
    wire signed [WIDTH-1:0] corr_delayed_real, corr_delayed_img;
    wire signed [WIDTH-1:0] corrected_real_out, corrected_imag_out;
    wire signed [WIDTH-1:0] cprem_real_out, cprem_imag_out;
    
    wire est_valid_out;
    wire signed [WIDTH-1:0] est_angle_out;
    wire signed [15:0] latched_angle;
    wire est_enable, fft_en;




    wire fifo_empty, fifo_full;
    wire signed [WIDTH-1:0] fifo_real_out, fifo_imag_out;
    
    // The FSM asserts fft_en when estimation is done. That triggers the read out.
    wire fifo_rd_en ;

    // FSM Controller drives all internal enables and latches

    sync_fifo #(
        .WIDTH(2 * WIDTH), 
        .DEPTH(256) 
    ) payload_buffer (
        .clk(clk),
        .rst_n(reset),
        .wr_en(corr_valid_out),
        .rd_en(est_valid_out),
        .din({corr_delayed_real, corr_delayed_img}),
        .dout({fifo_real_out, fifo_imag_out}),
        .empty(fifo_empty),
        .full(fifo_full)
    );


    controller u_controller (
        .clk(clk),
        .rst_n(reset),
        .corr_matched(corr_matched),
        .est_valid_out(est_valid_out),
        .est_angle_in(est_angle_out),
        .est_enable(est_enable),
        .latched_angle(latched_angle),
        .fft_en(fft_en) ,
        .fifo_rd_en(fifo_rd_en)
    );

    correlation #(
        .WIDTH(WIDTH), .CP_LEN(CP_LEN), .N_FFT(N_FFT)
    ) correlator_inst (
        .clk(clk), .rst_n(reset),
        .in_real(real_in), .in_img(imag_in),
        .valid_in(valid_in),
        .valid_out(corr_valid_out), .matched(corr_matched),
        .delayed_out_real(corr_delayed_real), .delayed_out_img(corr_delayed_img)
    );

    cfo_estimator #(
        .WIDTH(WIDTH), .N_FFT(N_FFT)
    ) estimator_inst (
        .clk(clk), .reset(reset),
        .valid_in(est_enable & corr_valid_out),
        .real_data(corr_delayed_real), .imag_data(corr_delayed_img),
        .valid_out(est_valid_out), .data_out(est_angle_out)
    );

    // CFO_apply now receives the exact same delayed stream as the estimator
    CFO_apply #(
        .DATA_REAL(WIDTH), .DATA_IMG(WIDTH)
    ) apply_inst (
        .clk(clk), .rst_n(reset),
        .in_real(fifo_real_out), .in_img(fifo_imag_out),
        .valid_in(fifo_rd_en), // Only valid when FIFO is actively being read
        .angle(latched_angle), // Driven strictly by FSM
        .out_real(corrected_real_out), .out_img(corrected_imag_out),
        .valid_out(corrected_valid_out)
    );

    cp_rem #(
        .N_FFT(N_FFT), .CP_LEN(CP_LEN), .WIDTH(WIDTH)
    ) cp_rem_inst (
        .clk(clk), .rst_n(reset),
        .valid_in(corrected_valid_out),
        .in_real(corrected_real_out), .in_img(corrected_imag_out),
        .out_real(cprem_real_out), .out_img(cprem_imag_out),
        .valid_out(cprem_valid_out)
    );

    isac_ofdm_fft_top #(
        .FFT_SIZE(N_FFT), .NUM_STAGES($clog2(N_FFT)), .MAX_FFT_SIZE(1024)
    ) fft_inst (
        .i_clk(clk), .i_rst_n(reset),
        .valid_in(cprem_valid_out), 
        .i_en(fft_en), 
        .i_data_re(cprem_real_out), .i_data_im(cprem_imag_out),
        .o_data_re(real_out), .o_data_im(imag_out),
        .valid_out(valid_out), .o_last(last) 
    );

endmodule