`timescale 1ns/1ps

module cpe_est_stream #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 20, 
    parameter N_FFT      = 128
)(
    input wire clk, rst, valid_in, is_pilot,
    input wire signed [DATA_WIDTH-1:0] eq_in_i, eq_in_q,
    output reg trigger_cordic,
    output reg signed [ACC_WIDTH-1:0] final_acc_real, final_acc_imag
);

    reg signed [ACC_WIDTH-1:0] acc_real, acc_imag;
    reg [7:0] sample_cnt; 

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            acc_real <= 0; acc_imag <= 0;
            sample_cnt <= 0; trigger_cordic <= 0;
        end else begin
            trigger_cordic <= 1'b0; 
            if (valid_in) begin
                
                // Pure accumulation: Removes the pilot_sign toggle bug[cite: 35]
                if (is_pilot) begin
                    acc_real <= acc_real + eq_in_i;
                    acc_imag <= acc_imag + eq_in_q;
                end

                if (sample_cnt == N_FFT - 1) begin
                    final_acc_real <= acc_real + (is_pilot ? eq_in_i : 20'sb0);
                    final_acc_imag <= acc_imag + (is_pilot ? eq_in_q : 20'sb0);
                    trigger_cordic <= 1'b1;
                    
                    acc_real <= 0; acc_imag <= 0; sample_cnt <= 0;
                end else begin
                    sample_cnt <= sample_cnt + 1'b1;
                end
            end
        end
    end
endmodule