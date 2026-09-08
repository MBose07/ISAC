`timescale 1ns/1ps

module tb_post_fft;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter MAX_SUBCARRIER = 128;
    parameter IDX_WIDTH = 7;

    // Clock & Reset
    reg clk;
    reg rst;

    // File I/O Variables
    integer infile, outfile, status;
    integer read_ctr, out_ctr;
    reg [15:0] read_i, read_q;

    // Top-Level Inputs
    reg valid_in;
    reg [IDX_WIDTH-1:0] idx;
    reg signed [DATA_WIDTH-1:0] fft_i, fft_q;

    // ---------------------------------------------------
    // 1. Channel Estimator
    // ---------------------------------------------------
    wire ch_valid;
    wire signed [DATA_WIDTH-1:0] H_i, H_q;

    ch_est #(
        .data_width(DATA_WIDTH),
        .max_subcarrier(MAX_SUBCARRIER)
    ) u_ch_est (
        .clk(clk), .rst(rst),
        .valid_in(valid_in), .idx(idx),
        .sc_in_i(fft_i), .sc_in_q(fft_q),
        .valid_out(ch_valid),
        .H_out_i(H_i), .H_out_q(H_q)
    );

    // 1-Cycle Delay Pipeline (Aligns FFT data with memory-read H)
    reg eq_valid_in;
    reg [IDX_WIDTH-1:0] eq_idx;
    reg signed [DATA_WIDTH-1:0] eq_fft_i, eq_fft_q;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            eq_valid_in <= 1'b0;
            eq_idx <= 0; eq_fft_i <= 0; eq_fft_q <= 0;
        end else begin
            eq_valid_in <= valid_in;
            eq_idx      <= idx;
            eq_fft_i    <= fft_i;
            eq_fft_q    <= fft_q;
        end
    end

    // ---------------------------------------------------
    // 2. Equalizer
    // ---------------------------------------------------
    wire eq_valid_out, is_pilot, is_data;
    wire signed [DATA_WIDTH-1:0] eq_out_i, eq_out_q;

    equalizer_stream #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_SUBCARRIER(MAX_SUBCARRIER)
    ) u_equalizer (
        .clk(clk), .rst(rst),
        .valid_in(eq_valid_in), .idx(eq_idx),
        .Y_i(eq_fft_i), .Y_q(eq_fft_q),
        .H_i(H_i), .H_q(H_q),
        .valid_out(eq_valid_out),
        .eq_out_i(eq_out_i), .eq_out_q(eq_out_q),
        .is_pilot(is_pilot), .is_data(is_data)
    );

    // ---------------------------------------------------
    // 3. Common Phase Error (CPE) Compensation
    // ---------------------------------------------------
    wire cpe_valid_out, cpe_is_data;
    wire signed [DATA_WIDTH-1:0] cpe_out_i, cpe_out_q;

    cpe_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .N_FFT(MAX_SUBCARRIER)
    ) u_cpe (
        .clk(clk), .rst(rst),
        .valid_in(eq_valid_out),
        .is_pilot_in(is_pilot),
        .is_data_in(is_data),
        .eq_in_i(eq_out_i), .eq_in_q(eq_out_q),
        .valid_out(cpe_valid_out),
        .is_data_out(cpe_is_data),
        .eq_out_i(cpe_out_i), .eq_out_q(cpe_out_q)
    );

    // ---------------------------------------------------
    // 4. BPSK Demodulator
    // ---------------------------------------------------
    wire demod_valid, bit_out;

    bpsk_demod_stream #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_demod (
        .clk(clk), .rst(rst),
        .valid_in(cpe_valid_out),
        .is_data(cpe_is_data),
        .y_i(cpe_out_i), .y_q(cpe_out_q),
        .valid_out(demod_valid),
        .bit_out(bit_out)
    );

    // ---------------------------------------------------
    // Simulation Control & File I/O
    // ---------------------------------------------------
    always #5 clk = ~clk; // 100MHz clock

    initial begin
        clk = 0;
        rst = 0;
        valid_in = 0;
        out_ctr = 0;

        // Open files
        infile = $fopen("../fft_output_log.txt", "r");
        outfile = $fopen("../simulation_log.txt", "w");
        
        #20 rst = 1; // Release reset

        // Read input file line by line
        while (!$feof(infile)) begin
            @(posedge clk);
            // Parse exactly: "ctr : 0 | I: ffff | Q: ffff"
            status = $fscanf(infile, "ctr : %d | I: %h | Q: %h\n", read_ctr, read_i, read_q);
            
            if (status == 3) begin
                valid_in <= 1'b1;
                idx      <= read_ctr % MAX_SUBCARRIER;
                fft_i    <= read_i;
                fft_q    <= read_q;
            end else begin
                valid_in <= 1'b0;
            end
        end

        valid_in <= 1'b0;

        // Wait for pipeline to flush (49 for EQ + ~144 for CPE)
        #5000;
        
        $fclose(infile);
        $fclose(outfile);
        $finish;
    end

    // Write Demodulated Bits to Output File
    always @(posedge clk) begin
        if (demod_valid) begin // demod_valid already verifies is_data is true internally
            $fwrite(outfile, "ctr : %0d | Demod Bit: %b\n", out_ctr, bit_out);
            out_ctr = out_ctr + 1;
        end
    end

endmodule