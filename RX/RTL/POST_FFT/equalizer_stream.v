`timescale 1ns/1ps

module equalizer_stream #(
    parameter DATA_WIDTH = 16,
    parameter MULT_WIDTH = 2 * DATA_WIDTH,       
    parameter ADD_WIDTH  = (2 * DATA_WIDTH) + 1,
    parameter MAX_SUBCARRIER = 128,
    parameter IDX_WIDTH  = $clog2(MAX_SUBCARRIER)
)(
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire [IDX_WIDTH-1:0] idx,
    
    input wire signed [DATA_WIDTH-1:0] Y_i,  
    input wire signed [DATA_WIDTH-1:0] Y_q,  
    input wire signed [DATA_WIDTH-1:0] H_i,  
    input wire signed [DATA_WIDTH-1:0] H_q,  
    
    output wire valid_out,
    output wire signed [DATA_WIDTH-1:0] eq_out_i,
    output wire signed [DATA_WIDTH-1:0] eq_out_q,
    output wire is_pilot,
    output wire is_data
);

    // -------------------------------------------------------------
    // Stage 1 & 2 Internal Registers
    // -------------------------------------------------------------
    reg stage1_valid;
    reg signed [ADD_WIDTH-1:0] num_real, num_imag, H_magsq;
    reg signed [DATA_WIDTH-1:0] Y_i_delay, Y_q_delay;
    reg [IDX_WIDTH-1:0] idx_stage1;
    
    reg stage2_valid;
    reg signed [ADD_WIDTH-1:0] stage2_num_real, stage2_num_imag, stage2_den;
    reg [IDX_WIDTH-1:0] idx_stage2;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            stage1_valid <= 1'b0;
            num_real     <= {ADD_WIDTH{1'b0}};
            num_imag     <= {ADD_WIDTH{1'b0}};
            H_magsq      <= {ADD_WIDTH{1'b0}};
            Y_i_delay    <= {DATA_WIDTH{1'b0}};
            Y_q_delay    <= {DATA_WIDTH{1'b0}};
            idx_stage1   <= {IDX_WIDTH{1'b0}};
        end 
        else if (valid_in) begin
            stage1_valid <= 1'b1;
            idx_stage1   <= idx; 
            Y_i_delay    <= Y_i;
            Y_q_delay    <= Y_q;
            
            H_magsq  <= (H_i * H_i) + (H_q * H_q);
            num_real <= (Y_i * H_i) + (Y_q * H_q);
            num_imag <= (Y_q * H_i) - (Y_i * H_q);
        end 
        else begin
            stage1_valid <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            stage2_valid    <= 1'b0;
            stage2_num_real <= {ADD_WIDTH{1'b0}};
            stage2_num_imag <= {ADD_WIDTH{1'b0}};
            stage2_den      <= {ADD_WIDTH{1'b0}};
            idx_stage2      <= {IDX_WIDTH{1'b0}};
        end 
        else if (stage1_valid) begin
            stage2_valid <= 1'b1;
            idx_stage2   <= idx_stage1; 
            
            if (H_magsq == 0) begin
                stage2_den      <= 33'h040000000; 
                stage2_num_real <= {Y_i_delay, 15'd0}; 
                stage2_num_imag <= {Y_q_delay, 15'd0};
            end
            else begin
                stage2_den      <= H_magsq;
                stage2_num_real <= num_real;
                stage2_num_imag <= num_imag;
            end
        end
        else begin
            stage2_valid <= 1'b0;
        end
    end

    // -------------------------------------------------------------
    // Stage 3: The Division (49 Cycles)
    // -------------------------------------------------------------
    wire valid_out_real;

    pipelined_divider #(
        .IN_WIDTH(ADD_WIDTH),
        .OUT_WIDTH(DATA_WIDTH),
        .SHIFT_VAL(15)
    ) div_real (
        .clk(clk),
        .rst(rst),
        .valid_in(stage2_valid),
        .num(stage2_num_real),
        .den(stage2_den),
        .valid_out(valid_out_real),
        .quotient(eq_out_i)
    );

    pipelined_divider #(
        .IN_WIDTH(ADD_WIDTH),
        .OUT_WIDTH(DATA_WIDTH),
        .SHIFT_VAL(15)
    ) div_imag (
        .clk(clk),
        .rst(rst),
        .valid_in(stage2_valid),
        .num(stage2_num_imag),
        .den(stage2_den),
        .valid_out(), // Ignored
        .quotient(eq_out_q)
    );

    assign valid_out = valid_out_real;

    // -------------------------------------------------------------
    // Stage 4: Index Synchronization & Classification
    // -------------------------------------------------------------
    // Corrected to exactly 49 stages to match pipelined_divider.v
    reg [IDX_WIDTH-1:0] idx_pipe [0:48];
    integer i;
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < 49; i = i + 1) begin
                idx_pipe[i] <= {IDX_WIDTH{1'b0}};
            end
        end 
        else begin
            // Shift unconditionally to prevent misalignment when valid drops
            idx_pipe[0] <= idx_stage2;
            for (i = 1; i < 49; i = i + 1) begin
                idx_pipe[i] <= idx_pipe[i-1];
            end
        end
    end

    wire [IDX_WIDTH-1:0] final_idx = idx_pipe[48];

    wire is_null = (final_idx == 0) || (final_idx >= 1 && final_idx <= 5) || (final_idx >= (MAX_SUBCARRIER - 5) && final_idx <= (MAX_SUBCARRIER - 1));

    assign is_pilot = (final_idx == 12) || (final_idx == 24) || (final_idx == 36) || (final_idx == 48) || 
                      (final_idx == 60) || (final_idx == 68) || (final_idx == 80) || (final_idx == 92) ||    
                      (final_idx == 104); 

    assign is_data = valid_out & ~(is_null | is_pilot);

endmodule