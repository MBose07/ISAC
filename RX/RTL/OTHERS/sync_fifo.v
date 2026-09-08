`timescale 1ns / 1ps

module sync_fifo #(
    parameter WIDTH = 32,
    parameter DEPTH = 256
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             wr_en,
    input  wire             rd_en,
    input  wire [WIDTH-1:0] din,
    output reg  [WIDTH-1:0] dout,
    output wire             empty,
    output wire             full
);
    localparam ADDR_W = $clog2(DEPTH);
    
    // When pushing this RTL through OpenLane or Innovus, this array 
    // should be constrained to map to an SRAM macro to save routing resources.
    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];
    
    reg [ADDR_W:0] wr_ptr;
    reg [ADDR_W:0] rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]) && 
                   (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout   <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr[ADDR_W-1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                dout <= mem[rd_ptr[ADDR_W-1:0]];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end
endmodule