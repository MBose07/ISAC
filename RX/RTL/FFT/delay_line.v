`timescale 1ns / 1ps

module delay_line #(
    parameter DEPTH = 1
)(
    input  wire                      i_clk, i_rst_n, i_en,
    input  wire signed [15:0]        i_data_re, i_data_im,
    output wire signed [15:0]        o_data_re, o_data_im
);
    generate
        if (DEPTH == 0) begin
            assign o_data_re = i_data_re;
            assign o_data_im = i_data_im;
        end else if (DEPTH == 1) begin
            reg [31:0] r_mem;
            always @(posedge i_clk) begin
                if (!i_rst_n)      r_mem <= 32'd0;
                else if (i_en)     r_mem <= {i_data_re, i_data_im}; // BUG FIXED HERE
            end
            assign {o_data_re, o_data_im} = r_mem;
        end else begin
            localparam ADDR_W = $clog2(DEPTH);
            reg [31:0]       r_mem [0:DEPTH-1];
            reg [ADDR_W-1:0] r_wr_ptr;

            always @(posedge i_clk) begin
                if (!i_rst_n) begin
                    r_wr_ptr <= 0;
                end else if (i_en) begin
                    r_mem[r_wr_ptr] <= {i_data_re, i_data_im};
                    if (r_wr_ptr == DEPTH - 1) r_wr_ptr <= 0;
                    else                       r_wr_ptr <= r_wr_ptr + 1;
                end
            end
            assign {o_data_re, o_data_im} = r_mem[r_wr_ptr];
        end
    endgenerate
endmodule