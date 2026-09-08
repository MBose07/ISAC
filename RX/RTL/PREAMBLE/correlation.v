module correlation #(
    parameter WIDTH = 16,
    parameter CP_LEN = 32,
    parameter N_FFT = 128
) (
    input clk,
    input rst_n,

    input signed [WIDTH - 1 : 0] in_real,
    input signed [WIDTH - 1 : 0] in_img,
    input valid_in,

    output reg valid_out,
    output reg matched,
    
    // Aligned delayed outputs
    output reg signed [WIDTH - 1 : 0] delayed_out_real,
    output reg signed [WIDTH - 1 : 0] delayed_out_img
);

    localparam [159:0] preamble = 160'b0001100001101010000011010100000100011000011010100101110101001011101001010111010010101100001100010000010101100000101011000011000100011000011010100000110101000001;  
    parameter BIT_GROW = $clog2(CP_LEN + N_FFT); 
    
    wire signed [WIDTH + BIT_GROW - 1 : 0] temp_real [0 : CP_LEN + N_FFT];
    wire signed [WIDTH + BIT_GROW - 1 : 0] temp_img  [0 : CP_LEN + N_FFT];
    
    // The delay line bus
    wire signed [WIDTH - 1 : 0] bus_real [0 : CP_LEN + N_FFT];
    wire signed [WIDTH - 1 : 0] bus_img  [0 : CP_LEN + N_FFT];

    wire [2*(WIDTH + WIDTH + 2*BIT_GROW) - 1 : 0] curr = temp_real[CP_LEN + N_FFT] * temp_real[CP_LEN + N_FFT] + 
                                                          temp_img[CP_LEN + N_FFT]  * temp_img[CP_LEN + N_FFT]; 

    assign temp_real[0] = 0;
    assign temp_img[0]  = 0;
    
    // Feed raw input into stage 0 of delay line
    assign bus_real[0] = in_real;
    assign bus_img[0]  = in_img;

    reg [$clog2(CP_LEN + N_FFT - 1) + 3: 0] counter;
    reg found;

    genvar i;
    generate
        for (i = 0; i < CP_LEN + N_FFT; i = i + 1) begin : mac_array 
            mac #(
                .WIDTH(WIDTH),
                .BIT_GROW(BIT_GROW)
            ) mac1 (
                .clk(clk),
                .rst_n(rst_n),
                .in_real(in_real),
                .in_img(in_img),
                .forward_in_real(bus_real[i]),
                .forward_in_img(bus_img[i]),    
                .part_real(temp_real[i]),
                .part_img(temp_img[i]),
                .valid_in(valid_in),
                .flag(preamble[i] == 1'b1),
                .acc_real(temp_real[i+1]),
                .acc_img(temp_img[i+1]),
                .forward_out_real(bus_real[i+1]), 
                .forward_out_img(bus_img[i+1])    
            );
        end 
    endgenerate

    // 2-stage compensation pipeline for data alignment
    reg signed [WIDTH-1:0] data_pipe1_real, data_pipe2_real;
    reg signed [WIDTH-1:0] data_pipe1_img,  data_pipe2_img;

    // Peak detector registers
    reg [2*(WIDTH + WIDTH + 2*BIT_GROW) - 1 : 0] maxm;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter          <= 0; 
            matched          <= 0; 
            valid_out        <= 0;
            maxm        <= 0;
            data_pipe1_real  <= 0;
            data_pipe2_real  <= 0;
            data_pipe1_img   <= 0;
            data_pipe2_img   <= 0;
            delayed_out_real <= 0;
            delayed_out_img  <= 0;
            found            <= 0;
        end else if (valid_in) begin
            counter <= counter + 1;
            
            // 1. Data Alignment Pipeline
            data_pipe1_real  <= bus_real[CP_LEN + N_FFT];
            data_pipe2_real  <= data_pipe1_real;
            delayed_out_real <= data_pipe2_real;

            data_pipe1_img   <= bus_img[CP_LEN + N_FFT];
            data_pipe2_img   <= data_pipe1_img;
            delayed_out_img  <= data_pipe2_img;

            // 2. Peak Detection Tracking
            // 3. Trigger exactly at the peak transition
            if ((curr > 4_000_000_000_0) && (maxm < curr) && (counter > CP_LEN + N_FFT -2)  ) begin
                $display("Peak detected at counter = %d, curr = %d, maxm = %d", counter, curr, maxm);
                maxm <= curr;
                valid_out <= 1'b1;
                matched <= 1'b1;
                found <= 1'b1;
            end else begin
                matched <= 1'b0; 
            end
        end
    end

endmodule