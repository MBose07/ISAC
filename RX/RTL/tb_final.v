
`timescale 1ns / 1ps

module tb_final;
    parameter WIDTH = 16;
    parameter N_FFT = 128;
    parameter NUM_SAMPLES = 3000; // Matches multi-packet setup (160 preamble + 4 * 160 payload)
    parameter CP_LEN = 32; 

    reg clk, reset, valid_in; 
    reg signed [WIDTH-1:0] real_data, imag_data;
    
    wire valid_out;
    wire demod_bits_out;

    reg [31:0] stimulus_mem [0:NUM_SAMPLES-1];
    integer i, file_out, counter;
    
    // NEW: File handle and counter for the FFT extraction
    integer fft_file_out, fft_counter; 
    integer test_out; // NEW: File handle for the test output

    // Instantiate the fully integrated OFDM receiver
    full_ofdm_rx_with_cfo #(
        .DATA_WIDTH(WIDTH),
        .MAX_SUBCARRIER(N_FFT),
        .CP_LEN(CP_LEN),
        .IDX_WIDTH(7)
    ) dut (
        .clk(clk), 
        .rst(reset),
        .valid_in(valid_in), 
        .data_in_i(real_data), 
        .data_in_q(imag_data),
        .valid_out(valid_out),
        .demod_bits_out(demod_bits_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 0; valid_in = 0; counter = 0; fft_counter = 0;
        
        $readmemh("../cfo_stimulus.mem", stimulus_mem);
        
        file_out = $fopen("../simulation_log.txt", "w");
        // NEW: Open a separate file to dump the raw FFT values
        fft_file_out = $fopen("../fft_output_log.txt", "w"); 
        // testing file 
        test_out = $fopen("../test.txt", "w");

        #20 reset = 1; #10;
        
        $display("--- PASS 1: Full Receiver Stream Activation ---");
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            valid_in <= 1;
            real_data <= stimulus_mem[i][31:16];
            imag_data <= stimulus_mem[i][15:0];
        end
        
        // Push 200 zero-samples to completely flush internal pipeline delays
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            valid_in <= 1; real_data <= 0; imag_data <= 0;
        end
        @(posedge clk) valid_in <= 0;

        // Allow ample time for the complete pipeline to clear fully
        #8000;
        $fclose(file_out);
        $fclose(fft_file_out); // NEW: Close the FFT file handle
        $fclose(test_out); // NEW: Close the test file handle
        $display("Simulation Complete.");
        $finish;
    end

    // Log the incoming demodulated stream directly
    always @(posedge clk) begin
        if (valid_out) begin
            if (file_out) $fdisplay(file_out, "ctr : %0d | Demod Bit: %0b", 
                          counter, demod_bits_out);
            counter <= counter + 1;
        end
    end

    // NEW: Hierarchical extraction of the internal FFT signals
    always @(posedge clk) begin
        // IMPORTANT: Verify these exact port names (valid_out, idx, Y_i, Y_q) 
        // match the definitions inside your 'isac_ofdm_fft_top' module.
        if(dut.u_cpe.valid_out || dut.u_cpe.is_data_out) begin
            if(test_out) begin
                $fdisplay(test_out, "I: %h | Q: %h", 
                          dut.u_cpe.eq_out_i, 
                          dut.u_cpe.eq_out_q);
            end
        end
        if (dut.u_cfo_top.valid_out) begin
            if (fft_file_out) begin
                $fdisplay(fft_file_out, "ctr : %0d  | I: %h | Q: %h", 
                          fft_counter, 
                          dut.u_cfo_top.real_out, 
                          dut.u_cfo_top.imag_out);
            end
            fft_counter <= fft_counter + 1;
        end
    end

    // GTKWave VCD Dump Configuration
    initial begin
        $dumpfile("cfo_system_waves.vcd");
        $dumpvars(0, tb_final);
    end
endmodule