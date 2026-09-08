module cfo_estimator #(
    parameter WIDTH = 16,
    parameter N_FFT = 128
) (
    output wire valid_out,
    output wire signed [WIDTH-1:0] data_out,
    input wire signed [WIDTH-1:0] real_data, imag_data,
    input clk, valid_in, reset
);

    wire fifo_full;
    wire rd_en;
    assign rd_en = fifo_full;
    
    wire signed [WIDTH-1:0] oureal, ouimag;
    reg signed [31:0] mul_real_imag, mul_imag_imag, mul_real_real, mul_imag_real;
    reg signed [32:0] add_real, add_imag;
    reg [5:0] counter;   // should be parameterized 
    reg signed [37:0] mul_real, mul_imag;
    
    wire angle_valid_in;
    wire wr_en = valid_in & !fifo_full;

    fifo #(
        .depth(128),
        .WIDTH(16)
    ) fif (
        clk, reset, rd_en, wr_en, real_data, imag_data, oureal, ouimag, fifo_full
    );

    cfo_angle_extractor angle(
        clk, mul_real, mul_imag, angle_valid_in, data_out, valid_out
    );

    wire condition;
    assign condition = counter[5] ^ (|counter[4:0]);
    assign angle_valid_in = counter[5] & counter[0];
    reg signed [WIDTH-1:0] real_data_d1, imag_data_d1;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            real_data_d1 <= 0;
            imag_data_d1 <= 0;
        end else begin
            real_data_d1 <= real_data;
            imag_data_d1 <= imag_data;
        end
    end

    always @(posedge clk or negedge reset) begin 
        if (!reset)
            counter <= 0;
        else if (fifo_full & (~(counter[5] & (|counter[4:0]))))
            counter <= counter + 1;
    end 

    always @(posedge clk or negedge reset ) begin 
        if (!reset) begin 
            mul_real <= 0;
            mul_imag <= 0;
        end
        else if (condition) begin 
            mul_real <= mul_real + add_real;
            mul_imag <= mul_imag + add_imag;
        end
    end

    always @(*) begin 
        mul_real_real = real_data_d1 * oureal;
        mul_imag_imag = imag_data_d1 * ouimag;
        mul_real_imag = real_data_d1 * ouimag;
        mul_imag_real = imag_data_d1 * oureal;
        
        add_real = mul_real_real + mul_imag_imag;
        add_imag = mul_imag_real - mul_real_imag;
    end

endmodule