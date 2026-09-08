`timescale 1ns/1ps

module cpe_apply_stream #(
    parameter DATA_WIDTH  = 16,
    parameter PHASE_WIDTH = 16
)(
    input wire clk, rst, valid_in, is_data_in,
    input wire signed [DATA_WIDTH-1:0] eq_in_i, eq_in_q,
    input wire phase_valid_in, 
    input wire signed [PHASE_WIDTH-1:0] cpe_angle,
    
    output wire valid_out, is_data_out,
    output wire signed [DATA_WIDTH-1:0] y_i, y_q
);
    reg signed [PHASE_WIDTH-1:0] current_cpe;
    reg signed [PHASE_WIDTH-1:0] neg_cpe;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            current_cpe <= {PHASE_WIDTH{1'b0}};
            neg_cpe     <= {PHASE_WIDTH{1'b0}};
        end else if (phase_valid_in) begin
            current_cpe <= cpe_angle;
            neg_cpe     <= -cpe_angle; 
        end
    end

    wire cordic_rot_valid;
    wire signed [DATA_WIDTH-1:0] cos_out, sin_out;

    cordic_rotator #(
        .WIDTH(DATA_WIDTH), .ITERATIONS(16)
    ) rot_cordic (
        .clk(clk), .rst(rst), .valid_in(valid_in),
        .angle_in(neg_cpe), .valid_out(cordic_rot_valid),
        .cos_out(cos_out), .sin_out(sin_out)
    );
   
    localparam CORDIC_LATENCY = 1;
    
    reg signed [DATA_WIDTH-1:0] delay_i [0:CORDIC_LATENCY-1];
    reg signed [DATA_WIDTH-1:0] delay_q [0:CORDIC_LATENCY-1];
    
    // SYNCHRONIZATION FIX: 3-cycle pipe to match multiplier latency
    reg [2:0] is_data_pipe;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            is_data_pipe <= 3'd0;
        end else begin
            is_data_pipe <= {is_data_pipe[1:0], is_data_in};
            delay_i[0] <= eq_in_i;
            delay_q[0] <= eq_in_q;
        end
    end

    wire signed [DATA_WIDTH-1:0] eq_i_aligned = delay_i[0];
    wire signed [DATA_WIDTH-1:0] eq_q_aligned = delay_q[0];
    
    assign is_data_out = is_data_pipe[2];
   
    reg signed [2*DATA_WIDTH-1:0] mult_i_cos, mult_q_sin, mult_i_sin, mult_q_cos;
    reg mult_valid_stage1;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            mult_i_cos <= 0; mult_q_sin <= 0; mult_i_sin <= 0; mult_q_cos <= 0;
            mult_valid_stage1 <= 1'b0;
        end else begin
            mult_i_cos <= eq_i_aligned * cos_out;
            mult_q_sin <= eq_q_aligned * sin_out;
            mult_i_sin <= eq_i_aligned * sin_out;
            mult_q_cos <= eq_q_aligned * cos_out;
            mult_valid_stage1 <= cordic_rot_valid;
        end
    end

    reg signed [2*DATA_WIDTH-1:0] y_i_full, y_q_full;
    reg mult_valid_stage2;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            y_i_full <= 0; y_q_full <= 0;
            mult_valid_stage2 <= 1'b0;
        end else begin
            y_i_full <= mult_i_cos - mult_q_sin;
            y_q_full <= mult_i_sin + mult_q_cos;
            mult_valid_stage2 <= mult_valid_stage1;
        end
    end


  
    localparam FRACTIONAL_BITS = 13; 


    wire signed [2*DATA_WIDTH-1:0] y_i_shifted = y_i_full >>> FRACTIONAL_BITS;
    wire signed [2*DATA_WIDTH-1:0] y_q_shifted = y_q_full >>> FRACTIONAL_BITS;


    assign y_i = (y_i_shifted > 32767)  ? 16'h7FFF :
                 (y_i_shifted < -32768) ? 16'h8000 : y_i_shifted[15:0];

    assign y_q = (y_q_shifted > 32767)  ? 16'h7FFF :
                 (y_q_shifted < -32768) ? 16'h8000 : y_q_shifted[15:0];

    assign valid_out = mult_valid_stage2;

endmodule