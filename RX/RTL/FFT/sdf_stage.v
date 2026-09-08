`timescale 1ns / 1ps

module sdf_stage #(
    parameter STAGE_ID       = 0,
    parameter FFT_SIZE       = 128,
    parameter NUM_STAGES     = 7,                                  
    parameter MAX_FFT_SIZE   = 1024,
    parameter TWIDDLE_ADDR_W = (NUM_STAGES > 1) ? (NUM_STAGES - 1) : 1
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      i_sel,
    input  wire                      i_en,
    input  wire [TWIDDLE_ADDR_W-1:0] i_twiddle_addr,
    input  wire signed [15:0]        i_data_re, i_data_im,
    output wire signed [15:0]        o_data_re, o_data_im
);
    localparam STG_DELAY = FFT_SIZE >> (STAGE_ID + 1);

    wire signed [15:0] w_twiddle_re, w_twiddle_im;
    twiddle_rom #(
        .FFT_SIZE(FFT_SIZE), .ADDR_WIDTH(TWIDDLE_ADDR_W), .MAX_FFT_SIZE(MAX_FFT_SIZE)
    ) u_twiddle_rom (
        .i_addr(i_twiddle_addr), .o_w_re(w_twiddle_re), .o_w_im(w_twiddle_im)
    );

    wire signed [15:0] w_sr_out_re, w_sr_out_im;
    wire signed [15:0] w_sr_in_re,  w_sr_in_im;

    reg signed [15:0] r_data_d1_re, r_data_d1_im;
    reg signed [15:0] r_sr_out_d1_re, r_sr_out_d1_im;
    reg r_sel_d1;

    always @(posedge clk) begin
        if (!rst_n) begin
            r_data_d1_re <= 0; r_data_d1_im <= 0;
            r_sr_out_d1_re <= 0; r_sr_out_d1_im <= 0;
            r_sel_d1 <= 0;
        end else if (i_en) begin
            r_data_d1_re <= i_data_re;
            r_data_d1_im <= i_data_im;
            r_sr_out_d1_re <= w_sr_out_re;
            r_sr_out_d1_im <= w_sr_out_im;
            r_sel_d1 <= i_sel;
        end
    end

    delay_line #(.DEPTH(STG_DELAY - 1)) u_delay_line (
        .i_clk(clk), .i_rst_n(rst_n),.i_en(i_en) ,
        .i_data_re(w_sr_in_re),  .i_data_im(w_sr_in_im),
        .o_data_re(w_sr_out_re), .o_data_im(w_sr_out_im)
    );

    wire signed [15:0] w_bf_y0_re, w_bf_y0_im;
    wire signed [15:0] w_bf_y1_re, w_bf_y1_im;
    Butterfly u_butterfly (
        .i_clk(clk), .i_en(i_en) ,
        .i_x0_re(w_sr_out_re), .i_x0_im(w_sr_out_im),   
        .i_x1_re(i_data_re),   .i_x1_im(i_data_im),     
        .i_w_re(w_twiddle_re), .i_w_im(w_twiddle_im),   
        .o_y0_re(w_bf_y0_re),  .o_y0_im(w_bf_y0_im),
        .o_y1_re(w_bf_y1_re),  .o_y1_im(w_bf_y1_im)
    );

    assign w_sr_in_re = r_sel_d1 ? w_bf_y1_re : r_data_d1_re;
    assign w_sr_in_im = r_sel_d1 ? w_bf_y1_im : r_data_d1_im;

    assign o_data_re  = r_sel_d1 ? w_bf_y0_re : r_sr_out_d1_re;
    assign o_data_im  = r_sel_d1 ? w_bf_y0_im : r_sr_out_d1_im;
endmodule