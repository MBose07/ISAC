module cfo_top_controller #(
    parameter WIDTH = 16
)(
    input clk,
    input rst_n,
    
    // Incoming stream from the ADC / Peak Detector
    input signed [WIDTH-1:0] in_real,
    input signed [WIDTH-1:0] in_img,
    input valid_in,
    input frame_start, // Trigger from the correlation peak
    
    // Outgoing corrected stream to the CP Removal / FFT
    output signed [WIDTH-1:0] out_real,
    output signed [WIDTH-1:0] out_img,
    output valid_out
);

    // ==========================================
    // 1. FSM State Declarations
    // ==========================================
    localparam IDLE      = 2'b00;
    localparam BUFFERING = 2'b01;
    localparam DRAINING  = 2'b10;
    
    reg [1:0] state, next_state;
    
    // ==========================================
    // 2. Main Datapath FIFO (Feed-Forward Buffer)
    // ==========================================
    // The estimator takes ~160 cycles to calculate the angle. 
    // This FIFO must be larger than 160 to prevent data loss. 256 is safe.
    wire fifo_rd_en;
    wire fifo_wr_en = (state == BUFFERING || state == DRAINING) ? valid_in : 1'b0;
    wire signed [WIDTH-1:0] fifo_out_real, fifo_out_img;
    wire fifo_full;
    
    fifo #(.depth(256), .WIDTH(WIDTH)) datapath_fifo (
        .clk(clk),
        .reset(rst_n), // Your fifo.v uses active-high reset
        .rd_en(fifo_rd_en),
        .wr_en(fifo_wr_en),
        .inreal(in_real),
        .iimag(in_img),
        .oureal(fifo_out_real),
        .ouimag(fifo_out_img),
        .fifo_full(fifo_full)
    );

    // ==========================================
    // 3. CFO Estimator Instantiation
    // ==========================================
    wire est_valid_out;
    wire [15:0] est_angle_out;
    
    // Dynamic reset: Clear the estimator logic when a new frame is detected
    wire est_reset = rst_n && !frame_start; 
    
    // Only feed data to the estimator during the BUFFERING state
    wire est_valid_in = (next_state == BUFFERING) ? valid_in : 1'b0;

    cfo_estimator #(
        .WIDTH(WIDTH), 
        .N_FFT(128)
    ) estimator (
        .clk(clk),
        .reset(est_reset),
        .real_data(in_real),
        .imag_data(in_img),
        .valid_in(est_valid_in),
        .data_out(est_angle_out),
        .valid_out(est_valid_out)
    );

    // ==========================================
    // 4. Angle Latch Register
    // ==========================================
    reg [15:0] locked_angle;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            locked_angle <= 0;
        end else if (est_valid_out) begin
            // Lock the angle the exact moment the estimator finishes
            locked_angle <= est_angle_out; 
        end
    end

    // ==========================================
    // 5. CFO Apply (NCO Counter-Rotation)
    // ==========================================
    // Only read from the datapath FIFO during the DRAINING state
    assign fifo_rd_en = (state == DRAINING) ? valid_in : 1'b0;

    CFO_apply #(
        .DATA_REAL(WIDTH), 
        .DATA_IMG(WIDTH)
    ) apply_mod (
        .clk(clk),
        .rst_n(rst_n),
        .in_real(fifo_out_real),
        .in_img(fifo_out_img),
        .valid_in(fifo_rd_en), 
        .angle(locked_angle),
        .out_real(out_real),
        .out_img(out_img),
        .valid_out(valid_out)
    );

    // ==========================================
    // 6. FSM Sequential Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // ==========================================
    // 7. FSM Combinational Routing Logic
    // ==========================================
    always @(*) begin
        next_state = state; // Default to staying in current state
        
        case (state)
            IDLE: begin
                if (frame_start) begin
                    next_state = BUFFERING;
                end
            end
            
            BUFFERING: begin
                // Wait for the estimator to calculate the angle
                if (est_valid_out) begin
                    next_state = DRAINING;
                end
            end
            
            DRAINING: begin
                // If a new packet arrives immediately, jump back to start
                if (frame_start) begin
                    next_state = BUFFERING;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule