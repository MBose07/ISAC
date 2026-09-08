`timescale 1ns/1ps

module pipelined_divider #(
    parameter IN_WIDTH  = 33,
    parameter OUT_WIDTH = 16,
    parameter SHIFT_VAL = 15, 
    parameter PIPELINE_DEPTH = IN_WIDTH + SHIFT_VAL 
)(
    input wire clk,
    input wire rst,
    input wire valid_in,
    
    input wire signed [IN_WIDTH-1:0] num,
    input wire signed [IN_WIDTH-1:0] den,
    
    output wire valid_out,
    output wire signed [OUT_WIDTH-1:0] quotient
);

    wire num_sign = num[IN_WIDTH-1];
    wire den_sign = den[IN_WIDTH-1];
    wire final_sign_init = num_sign ^ den_sign;

    wire [IN_WIDTH-1:0] abs_num = num_sign ? (~num + 1'b1) : num;
    wire [IN_WIDTH-1:0] abs_den = den_sign ? (~den + 1'b1) : den;

    wire [PIPELINE_DEPTH-1:0] shifted_num = {abs_num, {SHIFT_VAL{1'b0}}};

    reg [IN_WIDTH-1:0]       R_pipe     [0:PIPELINE_DEPTH]; 
    reg [PIPELINE_DEPTH-1:0] Q_pipe     [0:PIPELINE_DEPTH]; 
    reg [IN_WIDTH-1:0]       Den_pipe   [0:PIPELINE_DEPTH]; 
    reg                      valid_pipe [0:PIPELINE_DEPTH];
    reg                      sign_pipe  [0:PIPELINE_DEPTH];

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_pipe[0] <= 1'b0;
            R_pipe[0]     <= {IN_WIDTH{1'b0}};
            Q_pipe[0]     <= {PIPELINE_DEPTH{1'b0}};
            Den_pipe[0]   <= {IN_WIDTH{1'b0}};
            sign_pipe[0]  <= 1'b0;
        end else begin
            valid_pipe[0] <= valid_in;
            R_pipe[0]     <= {IN_WIDTH{1'b0}}; 
            Q_pipe[0]     <= shifted_num;      
            Den_pipe[0]   <= abs_den;          
            sign_pipe[0]  <= final_sign_init;
        end
    end

    genvar i;
    generate
        for (i = 0; i < PIPELINE_DEPTH; i = i + 1) begin : div_stage
            wire [IN_WIDTH-1:0] R_shifted = {R_pipe[i][IN_WIDTH-2:0], Q_pipe[i][PIPELINE_DEPTH-1]};
            wire can_subtract = (R_shifted >= Den_pipe[i]);

            always @(posedge clk or negedge rst) begin
                if (!rst) begin
                    valid_pipe[i+1] <= 1'b0;
                    sign_pipe[i+1]  <= 1'b0;
                    Den_pipe[i+1]   <= {IN_WIDTH{1'b0}};
                    R_pipe[i+1]     <= {IN_WIDTH{1'b0}};
                    Q_pipe[i+1]     <= {PIPELINE_DEPTH{1'b0}};
                end 
                else begin
                    valid_pipe[i+1] <= valid_pipe[i];
                    if (valid_pipe[i]) begin
                        sign_pipe[i+1]  <= sign_pipe[i];
                        Den_pipe[i+1]   <= Den_pipe[i];
                        if (can_subtract) begin
                            R_pipe[i+1] <= R_shifted - Den_pipe[i];
                            Q_pipe[i+1] <= {Q_pipe[i][PIPELINE_DEPTH-2:0], 1'b1}; 
                        end else begin
                            R_pipe[i+1] <= R_shifted;
                            Q_pipe[i+1] <= {Q_pipe[i][PIPELINE_DEPTH-2:0], 1'b0}; 
                        end
                    end
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------
    // Anti-Wrap Saturation Logic
    // -------------------------------------------------------------
    wire [OUT_WIDTH-1:0] raw_quotient = Q_pipe[PIPELINE_DEPTH][OUT_WIDTH-1:0];
    
    // If the math results in 32768 (+1.0), clamp it to 32767 so it doesn't wrap to negative
    wire overflow = (raw_quotient >= 16'h8000);
    wire [OUT_WIDTH-1:0] clamped_quotient = overflow ? 16'h7FFF : raw_quotient;
    
    assign quotient  = sign_pipe[PIPELINE_DEPTH] ? (~clamped_quotient + 1'b1) : clamped_quotient;
    assign valid_out = valid_pipe[PIPELINE_DEPTH];

endmodule