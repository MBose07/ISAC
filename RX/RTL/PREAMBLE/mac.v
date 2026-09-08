module mac #(
    parameter WIDTH = 16, 
    parameter BIT_GROW = 8 
) (
    input clk,
    input rst_n,

    // BROADCAST INPUT (Used strictly for correlation math)
    input signed [WIDTH - 1 : 0] in_real,
    input signed [WIDTH - 1 : 0] in_img,
    
    // DAISY-CHAIN INPUT (Used strictly for delaying the signal)
    input signed [WIDTH - 1 : 0] forward_in_real,
    input signed [WIDTH - 1 : 0] forward_in_img,

    input signed [WIDTH + BIT_GROW - 1 : 0] part_real,
    input signed [WIDTH + BIT_GROW - 1 : 0] part_img,
    input valid_in,
    input flag,

    output reg signed [WIDTH + BIT_GROW - 1 : 0] acc_real,
    output reg signed [WIDTH + BIT_GROW - 1 : 0] acc_img,
    
    // DAISY-CHAIN OUTPUT
    output reg signed [WIDTH - 1 : 0] forward_out_real,
    output reg signed [WIDTH - 1 : 0] forward_out_img 
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_real <= 0;
            acc_img <= 0; 
            forward_out_real <= 0;
            forward_out_img <= 0;
        end else if(valid_in) begin
            // Math uses the instantaneous broadcast input
            acc_real <= part_real + (flag == 0 ? -in_real : in_real);
            acc_img <= part_img + (flag == 0 ? -in_img : in_img);
            
            // Shift register uses the pipelined forward input
            forward_out_real <= forward_in_real;
            forward_out_img <= forward_in_img;
        end
    end
endmodule