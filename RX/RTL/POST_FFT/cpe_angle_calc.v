`timescale 1ns/1ps

module cpe_angle_calc #(
    parameter DATA_WIDTH  = 16,
    parameter ACC_WIDTH   = 18,
    parameter PHASE_WIDTH = 16,
    parameter N_FFT       = 128
)(
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire is_pilot,
    input wire signed [DATA_WIDTH-1:0] eq_in_i,
    input wire signed [DATA_WIDTH-1:0] eq_in_q,
    
    output wire phase_valid_out,
    output wire signed [PHASE_WIDTH-1:0] final_phase
);

    // Internal Wires (The Jumper Cables)
    wire trigger_cordic;
    wire signed [ACC_WIDTH-1:0] final_acc_real;
    wire signed [ACC_WIDTH-1:0] final_acc_imag;

    // Block 1: The Accumulator
    cpe_est_stream #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .N_FFT(N_FFT)
    ) estimator (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .is_pilot(is_pilot),
        .eq_in_i(eq_in_i),
        .eq_in_q(eq_in_q),
        
        // Connect outputs to the internal wires
        .trigger_cordic(trigger_cordic),
        .final_acc_real(final_acc_real),
        .final_acc_imag(final_acc_imag)
    );

    // Block 2: The Angle Calculator
    cordic_atan2 #(
        .IN_WIDTH(ACC_WIDTH),
        .PHASE_WIDTH(PHASE_WIDTH),
        .ITERATIONS(16)
    ) phase_cordic (
        .clk(clk),
        .rst(rst),
        
        // Connect inputs to the internal wires
        .valid_in(trigger_cordic),
        .in_real(final_acc_real),
        .in_imag(final_acc_imag),
        
        // Connect outputs directly to the top-level pins
        .valid_out(phase_valid_out),
        .phase_out(final_phase)
    );

endmodule