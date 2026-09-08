`timescale 1ns/1ps

module cpe_top #(
    parameter DATA_WIDTH  = 16,
    parameter PHASE_WIDTH = 16,
    parameter N_FFT       = 128
)(
    input  wire clk, rst, valid_in, is_pilot_in, is_data_in,
    input  wire signed [DATA_WIDTH-1:0] eq_in_i, eq_in_q,
    output wire valid_out, is_data_out,
    output wire signed [DATA_WIDTH-1:0] eq_out_i, eq_out_q
);

    wire phase_valid;
    wire signed [PHASE_WIDTH-1:0] calculated_phase;
    wire delayed_valid, delayed_is_data;
    wire signed [DATA_WIDTH-1:0] delayed_i, delayed_q;

    cpe_angle_calc #(
        .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(20), .N_FFT(N_FFT)
    ) estimator_inst (
        .clk(clk), .rst(rst),
        .valid_in(valid_in), .is_pilot(is_pilot_in),
        .eq_in_i(eq_in_i), .eq_in_q(eq_in_q),
        .phase_valid_out(phase_valid),
        .final_phase(calculated_phase)
    );

    // SYNCHRONIZATION FIX: 147 cycles -> 130 cycles (N_FFT + 2)
    cpe_data_delay #(
        .DATA_WIDTH(DATA_WIDTH),
        .DELAY_CYCLES(N_FFT + 2) 
    ) delay_inst (
        .clk(clk), .rst(rst),
        .valid_in(valid_in), .is_data_in(is_data_in),
        .eq_in_i(eq_in_i), .eq_in_q(eq_in_q),
        .valid_out(delayed_valid), .is_data_out(delayed_is_data),
        .eq_out_i(delayed_i), .eq_out_q(delayed_q)
    );

    cpe_apply_stream #(
        .DATA_WIDTH(DATA_WIDTH)
    ) applier_inst (
        .clk(clk), .rst(rst),
        .valid_in(delayed_valid), .is_data_in(delayed_is_data),
        .eq_in_i(delayed_i), .eq_in_q(delayed_q),
        .phase_valid_in(phase_valid), .cpe_angle(calculated_phase),
        .valid_out(valid_out), .is_data_out(is_data_out),
        .y_i(eq_out_i), .y_q(eq_out_q)
    );

endmodule