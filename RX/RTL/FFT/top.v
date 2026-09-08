`timescale 1ns / 1ps

module isac_ofdm_fft_top #(
    parameter FFT_SIZE     = 128,
    parameter NUM_STAGES   = 7,
    parameter MAX_FFT_SIZE = 1024
)(
    input  wire                      i_clk,
    input  wire                      i_rst_n,
    input  wire                      valid_in, // Synchronizes the 128 useful samples
    input  wire                      i_en,
    input  wire signed [15:0]        i_data_re, i_data_im,
    output wire signed [15:0]        o_data_re, o_data_im,
    output wire                      valid_out, // Signals when valid FFT data is ready
    output wire                      o_last    
);
    wire signed [15:0] w_pipe_re [0:NUM_STAGES];
    wire signed [15:0] w_pipe_im [0:NUM_STAGES];
    wire               w_pipe_valid [0:NUM_STAGES]; 
    
    assign w_pipe_re[0] = i_data_re;
    assign w_pipe_im[0] = i_data_im;
    assign w_pipe_valid[0] = valid_in; 
    
    localparam ADDR_W = (NUM_STAGES > 1) ? (NUM_STAGES - 1) : 1;

    genvar k;
    generate
        for (k = 0; k < NUM_STAGES; k = k + 1) begin : gen_sdf_pipeline
            localparam STG_DELAY = FFT_SIZE >> (k + 1);
            
            reg [NUM_STAGES-1:0] r_cnt;
            always @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) r_cnt <= 0;
                else if (w_pipe_valid[k] && i_en) r_cnt <= r_cnt + 1;
            end

            wire [ADDR_W-1:0] w_twiddle_addr = (r_cnt << k) & ((FFT_SIZE/2) - 1);
            wire w_sel = r_cnt[NUM_STAGES - 1 - k];

            localparam STG_LATENCY = STG_DELAY + 1;
            reg [STG_LATENCY-1:0] r_valid_sr; 
            always @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) r_valid_sr <= 0;
                else if (i_en) r_valid_sr <= {r_valid_sr[STG_LATENCY-2:0], w_pipe_valid[k]};
            end
            assign w_pipe_valid[k+1] = r_valid_sr[STG_LATENCY-1];

            sdf_stage #(
                .STAGE_ID(k), .FFT_SIZE(FFT_SIZE), 
                .NUM_STAGES(NUM_STAGES), .MAX_FFT_SIZE(MAX_FFT_SIZE)
            ) u_fft_stg (
                .clk(i_clk), .rst_n(i_rst_n), .i_en(i_en) ,
                .i_sel(w_sel), .i_twiddle_addr(w_twiddle_addr),
                .i_data_re(w_pipe_re[k]),   .i_data_im(w_pipe_im[k]),
                .o_data_re(w_pipe_re[k+1]), .o_data_im(w_pipe_im[k+1])
            );
        end
    endgenerate 

    bit_reversal #(.FFT_SIZE(FFT_SIZE), .WIDTH(16)) u_bit_reversal (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_valid(w_pipe_valid[NUM_STAGES]), 
        .i_data_re(w_pipe_re[NUM_STAGES]), .i_data_im(w_pipe_im[NUM_STAGES]), 
        .o_valid(valid_out), .o_data_re(o_data_re), .o_data_im(o_data_im), .o_last(o_last)
    );
endmodule