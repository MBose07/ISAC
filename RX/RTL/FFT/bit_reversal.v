`timescale 1ns / 1ps

module bit_reversal #(
    parameter FFT_SIZE = 128,
    parameter WIDTH = 16
)(
    input  wire                      i_clk, i_rst_n, i_valid,
    input  wire signed [WIDTH-1:0]   i_data_re, i_data_im,
    output reg                       o_valid, o_last,
    output reg  signed [WIDTH-1:0]   o_data_re, o_data_im
);
    localparam ADDR_W = $clog2(FFT_SIZE);

    reg [ADDR_W-1:0] write_cnt, read_cnt;
    reg write_bank, read_bank;
    reg reading;

    wire [ADDR_W-1:0] reversed_write_addr;
    genvar i;
    generate
        for (i = 0; i < ADDR_W; i = i + 1) begin : gen_rev
            assign reversed_write_addr[i] = write_cnt[ADDR_W - 1 - i];
        end
    endgenerate

    // 2x RAM footprint required to handle OFDM CP gaps
    (* ram_style = "block" *) reg signed [WIDTH-1:0] ram_re [0:2*FFT_SIZE-1];
    (* ram_style = "block" *) reg signed [WIDTH-1:0] ram_im [0:2*FFT_SIZE-1];

    wire [ADDR_W:0] full_write_addr = {write_bank, reversed_write_addr};
    wire [ADDR_W:0] full_read_addr  = {read_bank, read_cnt};

    // Pipeline memory access
    always @(posedge i_clk) begin
        if (i_valid) begin
            ram_re[full_write_addr] <= i_data_re;
            ram_im[full_write_addr] <= i_data_im;
        end
        if (reading) begin
            o_data_re <= ram_re[full_read_addr];
            o_data_im <= ram_im[full_read_addr];
        end
    end

    // Control Logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            write_cnt <= 0; write_bank <= 0;
            read_cnt <= 0;  read_bank <= 0;
            reading <= 0;
            o_valid <= 0;   o_last <= 0;
        end else begin
            
            // --- WRITE PHASE ---
            if (i_valid) begin
                if (write_cnt == FFT_SIZE - 1) begin
                    write_cnt <= 0;
                    write_bank <= ~write_bank;
                    reading <= 1; // Trigger read phase independently 
                end else begin
                    write_cnt <= write_cnt + 1;
                end
            end

            // --- READ PHASE ---
            if (reading) begin
                o_valid <= 1; // Output is continuous, ignoring i_valid gaps
                
                if (read_cnt == FFT_SIZE - 1) begin
                    read_cnt <= 0;
                    read_bank <= ~read_bank;
                    o_last <= 1;
                    
                    // FIX: Check against the NEXT state of read_bank
                    reading <= (write_bank != ~read_bank); 
                end else begin
                    read_cnt <= read_cnt + 1;
                    o_last <= 0;
                end
            end else begin
                o_valid <= 0;
                o_last <= 0;
            end
        end
    end
endmodule