`timescale 1ns / 1ps

module Butterfly (
    input  wire                      i_clk, i_en,
    input  wire signed [15:0]        i_x0_re, i_x0_im,
    input  wire signed [15:0]        i_x1_re, i_x1_im,
    input  wire signed [15:0]        i_w_re,  i_w_im,
    output reg  signed [15:0]        o_y0_re, o_y0_im,
    output reg  signed [15:0]        o_y1_re, o_y1_im
);
    wire signed [16:0] sum_re  = i_x0_re + i_x1_re;
    wire signed [16:0] sum_im  = i_x0_im + i_x1_im;
    wire signed [16:0] diff_re = i_x0_re - i_x1_re;
    wire signed [16:0] diff_im = i_x0_im - i_x1_im;

    wire signed [33:0] mult_re = (diff_re * i_w_re) - (diff_im * i_w_im);
    wire signed [33:0] mult_im = (diff_re * i_w_im) + (diff_im * i_w_re);

    always @(posedge i_clk) begin
        if(i_en)begin
            o_y0_re <= sum_re[16:1];
            o_y0_im <= sum_im[16:1];

            o_y1_re <= mult_re[31:16];
            o_y1_im <= mult_im[31:16];
        end
    end
endmodule