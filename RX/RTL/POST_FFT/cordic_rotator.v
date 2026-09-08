`timescale 1ns/1ps

module cordic_rotator #(
    parameter WIDTH = 16,
    parameter ITERATIONS = 16 // Kept so your top-level instantiation doesn't break
)(
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  wire signed [WIDTH-1:0] angle_in,
    output reg  valid_out,
    output reg signed [WIDTH-1:0] cos_out,
    output reg signed [WIDTH-1:0] sin_out
);
    
    // Convert Q3.13 radians to 8-bit LUT address format[cite: 31]
    wire signed [31:0] scaled_angle = angle_in * $signed(18'd41721);
    wire [15:0] binary_angle = scaled_angle >>> 22;
    
    // Index the top 8 bits for the 256-line LUT[cite: 31]
    wire [7:0] lut_addr = binary_angle[15:8];

    reg signed [15:0] cos_val;
    reg signed [15:0] sin_val;

    always @(*) begin
        case (lut_addr)
            8'h00: begin cos_val = 16'h7FFF; sin_val = 16'h0000; end
            8'h01: begin cos_val = 16'h7FF6; sin_val = 16'h0324; end
            8'h02: begin cos_val = 16'h7FD9; sin_val = 16'h0648; end
            8'h03: begin cos_val = 16'h7FA7; sin_val = 16'h096B; end
            8'h04: begin cos_val = 16'h7F62; sin_val = 16'h0C8C; end
            8'h05: begin cos_val = 16'h7F0A; sin_val = 16'h0FAB; end
            8'h06: begin cos_val = 16'h7E9D; sin_val = 16'h12C8; end
            8'h07: begin cos_val = 16'h7E1E; sin_val = 16'h15E2; end
            8'h08: begin cos_val = 16'h7D8A; sin_val = 16'h18F9; end
            8'h09: begin cos_val = 16'h7CE4; sin_val = 16'h1C0C; end
            8'h0A: begin cos_val = 16'h7C2A; sin_val = 16'h1F1A; end
            8'h0B: begin cos_val = 16'h7B5D; sin_val = 16'h2224; end
            8'h0C: begin cos_val = 16'h7A7D; sin_val = 16'h2528; end
            8'h0D: begin cos_val = 16'h798A; sin_val = 16'h2827; end
            8'h0E: begin cos_val = 16'h7885; sin_val = 16'h2B1F; end
            8'h0F: begin cos_val = 16'h776C; sin_val = 16'h2E11; end
            8'h10: begin cos_val = 16'h7642; sin_val = 16'h30FC; end
            8'h11: begin cos_val = 16'h7505; sin_val = 16'h33DF; end
            8'h12: begin cos_val = 16'h73B6; sin_val = 16'h36BA; end
            8'h13: begin cos_val = 16'h7255; sin_val = 16'h398D; end
            8'h14: begin cos_val = 16'h70E3; sin_val = 16'h3C57; end
            8'h15: begin cos_val = 16'h6F5F; sin_val = 16'h3F17; end
            8'h16: begin cos_val = 16'h6DCA; sin_val = 16'h41CE; end
            8'h17: begin cos_val = 16'h6C24; sin_val = 16'h447B; end
            8'h18: begin cos_val = 16'h6A6E; sin_val = 16'h471D; end
            8'h19: begin cos_val = 16'h68A7; sin_val = 16'h49B4; end
            8'h1A: begin cos_val = 16'h66D0; sin_val = 16'h4C40; end
            8'h1B: begin cos_val = 16'h64E9; sin_val = 16'h4EC0; end
            8'h1C: begin cos_val = 16'h62F2; sin_val = 16'h5134; end
            8'h1D: begin cos_val = 16'h60EC; sin_val = 16'h539B; end
            8'h1E: begin cos_val = 16'h5ED7; sin_val = 16'h55F6; end
            8'h1F: begin cos_val = 16'h5CB4; sin_val = 16'h5843; end
            8'h20: begin cos_val = 16'h5A82; sin_val = 16'h5A82; end
            8'h21: begin cos_val = 16'h5843; sin_val = 16'h5CB4; end
            8'h22: begin cos_val = 16'h55F6; sin_val = 16'h5ED7; end
            8'h23: begin cos_val = 16'h539B; sin_val = 16'h60EC; end
            8'h24: begin cos_val = 16'h5134; sin_val = 16'h62F2; end
            8'h25: begin cos_val = 16'h4EC0; sin_val = 16'h64E9; end
            8'h26: begin cos_val = 16'h4C40; sin_val = 16'h66D0; end
            8'h27: begin cos_val = 16'h49B4; sin_val = 16'h68A7; end
            8'h28: begin cos_val = 16'h471D; sin_val = 16'h6A6E; end
            8'h29: begin cos_val = 16'h447B; sin_val = 16'h6C24; end
            8'h2A: begin cos_val = 16'h41CE; sin_val = 16'h6DCA; end
            8'h2B: begin cos_val = 16'h3F17; sin_val = 16'h6F5F; end
            8'h2C: begin cos_val = 16'h3C57; sin_val = 16'h70E3; end
            8'h2D: begin cos_val = 16'h398D; sin_val = 16'h7255; end
            8'h2E: begin cos_val = 16'h36BA; sin_val = 16'h73B6; end
            8'h2F: begin cos_val = 16'h33DF; sin_val = 16'h7505; end
            8'h30: begin cos_val = 16'h30FC; sin_val = 16'h7642; end
            8'h31: begin cos_val = 16'h2E11; sin_val = 16'h776C; end
            8'h32: begin cos_val = 16'h2B1F; sin_val = 16'h7885; end
            8'h33: begin cos_val = 16'h2827; sin_val = 16'h798A; end
            8'h34: begin cos_val = 16'h2528; sin_val = 16'h7A7D; end
            8'h35: begin cos_val = 16'h2224; sin_val = 16'h7B5D; end
            8'h36: begin cos_val = 16'h1F1A; sin_val = 16'h7C2A; end
            8'h37: begin cos_val = 16'h1C0C; sin_val = 16'h7CE4; end
            8'h38: begin cos_val = 16'h18F9; sin_val = 16'h7D8A; end
            8'h39: begin cos_val = 16'h15E2; sin_val = 16'h7E1E; end
            8'h3A: begin cos_val = 16'h12C8; sin_val = 16'h7E9D; end
            8'h3B: begin cos_val = 16'h0FAB; sin_val = 16'h7F0A; end
            8'h3C: begin cos_val = 16'h0C8C; sin_val = 16'h7F62; end
            8'h3D: begin cos_val = 16'h096B; sin_val = 16'h7FA7; end
            8'h3E: begin cos_val = 16'h0648; sin_val = 16'h7FD9; end
            8'h3F: begin cos_val = 16'h0324; sin_val = 16'h7FF6; end
            8'h40: begin cos_val = 16'h0000; sin_val = 16'h7FFF; end
            8'h41: begin cos_val = 16'hFCDC; sin_val = 16'h7FF6; end
            8'h42: begin cos_val = 16'hF9B8; sin_val = 16'h7FD9; end
            8'h43: begin cos_val = 16'hF695; sin_val = 16'h7FA7; end
            8'h44: begin cos_val = 16'hF374; sin_val = 16'h7F62; end
            8'h45: begin cos_val = 16'hF055; sin_val = 16'h7F0A; end
            8'h46: begin cos_val = 16'hED38; sin_val = 16'h7E9D; end
            8'h47: begin cos_val = 16'hEA1E; sin_val = 16'h7E1E; end
            8'h48: begin cos_val = 16'hE707; sin_val = 16'h7D8A; end
            8'h49: begin cos_val = 16'hE3F4; sin_val = 16'h7CE4; end
            8'h4A: begin cos_val = 16'hE0E6; sin_val = 16'h7C2A; end
            8'h4B: begin cos_val = 16'hDDDC; sin_val = 16'h7B5D; end
            8'h4C: begin cos_val = 16'hDAD8; sin_val = 16'h7A7D; end
            8'h4D: begin cos_val = 16'hD7D9; sin_val = 16'h798A; end
            8'h4E: begin cos_val = 16'hD4E1; sin_val = 16'h7885; end
            8'h4F: begin cos_val = 16'hD1EF; sin_val = 16'h776C; end
            8'h50: begin cos_val = 16'hCF04; sin_val = 16'h7642; end
            8'h51: begin cos_val = 16'hCC21; sin_val = 16'h7505; end
            8'h52: begin cos_val = 16'hC946; sin_val = 16'h73B6; end
            8'h53: begin cos_val = 16'hC673; sin_val = 16'h7255; end
            8'h54: begin cos_val = 16'hC3A9; sin_val = 16'h70E3; end
            8'h55: begin cos_val = 16'hC0E9; sin_val = 16'h6F5F; end
            8'h56: begin cos_val = 16'hBE32; sin_val = 16'h6DCA; end
            8'h57: begin cos_val = 16'hBB85; sin_val = 16'h6C24; end
            8'h58: begin cos_val = 16'hB8E3; sin_val = 16'h6A6E; end
            8'h59: begin cos_val = 16'hB64C; sin_val = 16'h68A7; end
            8'h5A: begin cos_val = 16'hB3C0; sin_val = 16'h66D0; end
            8'h5B: begin cos_val = 16'hB140; sin_val = 16'h64E9; end
            8'h5C: begin cos_val = 16'hAECC; sin_val = 16'h62F2; end
            8'h5D: begin cos_val = 16'hAC65; sin_val = 16'h60EC; end
            8'h5E: begin cos_val = 16'hAA0A; sin_val = 16'h5ED7; end
            8'h5F: begin cos_val = 16'hA7BD; sin_val = 16'h5CB4; end
            8'h60: begin cos_val = 16'hA57E; sin_val = 16'h5A82; end
            8'h61: begin cos_val = 16'hA34C; sin_val = 16'h5843; end
            8'h62: begin cos_val = 16'hA129; sin_val = 16'h55F6; end
            8'h63: begin cos_val = 16'h9F14; sin_val = 16'h539B; end
            8'h64: begin cos_val = 16'h9D0E; sin_val = 16'h5134; end
            8'h65: begin cos_val = 16'h9B17; sin_val = 16'h4EC0; end
            8'h66: begin cos_val = 16'h9930; sin_val = 16'h4C40; end
            8'h67: begin cos_val = 16'h9759; sin_val = 16'h49B4; end
            8'h68: begin cos_val = 16'h9592; sin_val = 16'h471D; end
            8'h69: begin cos_val = 16'h93DC; sin_val = 16'h447B; end
            8'h6A: begin cos_val = 16'h9236; sin_val = 16'h41CE; end
            8'h6B: begin cos_val = 16'h90A1; sin_val = 16'h3F17; end
            8'h6C: begin cos_val = 16'h8F1D; sin_val = 16'h3C57; end
            8'h6D: begin cos_val = 16'h8DAB; sin_val = 16'h398D; end
            8'h6E: begin cos_val = 16'h8C4A; sin_val = 16'h36BA; end
            8'h6F: begin cos_val = 16'h8AFB; sin_val = 16'h33DF; end
            8'h70: begin cos_val = 16'h89BE; sin_val = 16'h30FC; end
            8'h71: begin cos_val = 16'h8894; sin_val = 16'h2E11; end
            8'h72: begin cos_val = 16'h877B; sin_val = 16'h2B1F; end
            8'h73: begin cos_val = 16'h8676; sin_val = 16'h2827; end
            8'h74: begin cos_val = 16'h8583; sin_val = 16'h2528; end
            8'h75: begin cos_val = 16'h84A3; sin_val = 16'h2224; end
            8'h76: begin cos_val = 16'h83D6; sin_val = 16'h1F1A; end
            8'h77: begin cos_val = 16'h831C; sin_val = 16'h1C0C; end
            8'h78: begin cos_val = 16'h8276; sin_val = 16'h18F9; end
            8'h79: begin cos_val = 16'h81E2; sin_val = 16'h15E2; end
            8'h7A: begin cos_val = 16'h8163; sin_val = 16'h12C8; end
            8'h7B: begin cos_val = 16'h80F6; sin_val = 16'h0FAB; end
            8'h7C: begin cos_val = 16'h809E; sin_val = 16'h0C8C; end
            8'h7D: begin cos_val = 16'h8059; sin_val = 16'h096B; end
            8'h7E: begin cos_val = 16'h8027; sin_val = 16'h0648; end
            8'h7F: begin cos_val = 16'h800A; sin_val = 16'h0324; end
            8'h80: begin cos_val = 16'h8000; sin_val = 16'h0000; end
            8'h81: begin cos_val = 16'h800A; sin_val = 16'hFCDC; end
            8'h82: begin cos_val = 16'h8027; sin_val = 16'hF9B8; end
            8'h83: begin cos_val = 16'h8059; sin_val = 16'hF695; end
            8'h84: begin cos_val = 16'h809E; sin_val = 16'hF374; end
            8'h85: begin cos_val = 16'h80F6; sin_val = 16'hF055; end
            8'h86: begin cos_val = 16'h8163; sin_val = 16'hED38; end
            8'h87: begin cos_val = 16'h81E2; sin_val = 16'hEA1E; end
            8'h88: begin cos_val = 16'h8276; sin_val = 16'hE707; end
            8'h89: begin cos_val = 16'h831C; sin_val = 16'hE3F4; end
            8'h8A: begin cos_val = 16'h83D6; sin_val = 16'hE0E6; end
            8'h8B: begin cos_val = 16'h84A3; sin_val = 16'hDDDC; end
            8'h8C: begin cos_val = 16'h8583; sin_val = 16'hDAD8; end
            8'h8D: begin cos_val = 16'h8676; sin_val = 16'hD7D9; end
            8'h8E: begin cos_val = 16'h877B; sin_val = 16'hD4E1; end
            8'h8F: begin cos_val = 16'h8894; sin_val = 16'hD1EF; end
            8'h90: begin cos_val = 16'h89BE; sin_val = 16'hCF04; end
            8'h91: begin cos_val = 16'h8AFB; sin_val = 16'hCC21; end
            8'h92: begin cos_val = 16'h8C4A; sin_val = 16'hC946; end
            8'h93: begin cos_val = 16'h8DAB; sin_val = 16'hC673; end
            8'h94: begin cos_val = 16'h8F1D; sin_val = 16'hC3A9; end
            8'h95: begin cos_val = 16'h90A1; sin_val = 16'hC0E9; end
            8'h96: begin cos_val = 16'h9236; sin_val = 16'hBE32; end
            8'h97: begin cos_val = 16'h93DC; sin_val = 16'hBB85; end
            8'h98: begin cos_val = 16'h9592; sin_val = 16'hB8E3; end
            8'h99: begin cos_val = 16'h9759; sin_val = 16'hB64C; end
            8'h9A: begin cos_val = 16'h9930; sin_val = 16'hB3C0; end
            8'h9B: begin cos_val = 16'h9B17; sin_val = 16'hB140; end
            8'h9C: begin cos_val = 16'h9D0E; sin_val = 16'hAECC; end
            8'h9D: begin cos_val = 16'h9F14; sin_val = 16'hAC65; end
            8'h9E: begin cos_val = 16'hA129; sin_val = 16'hAA0A; end
            8'h9F: begin cos_val = 16'hA34C; sin_val = 16'hA7BD; end
            8'hA0: begin cos_val = 16'hA57E; sin_val = 16'hA57E; end
            8'hA1: begin cos_val = 16'hA7BD; sin_val = 16'hA34C; end
            8'hA2: begin cos_val = 16'hAA0A; sin_val = 16'hA129; end
            8'hA3: begin cos_val = 16'hAC65; sin_val = 16'h9F14; end
            8'hA4: begin cos_val = 16'hAECC; sin_val = 16'h9D0E; end
            8'hA5: begin cos_val = 16'hB140; sin_val = 16'h9B17; end
            8'hA6: begin cos_val = 16'hB3C0; sin_val = 16'h9930; end
            8'hA7: begin cos_val = 16'hB64C; sin_val = 16'h9759; end
            8'hA8: begin cos_val = 16'hB8E3; sin_val = 16'h9592; end
            8'hA9: begin cos_val = 16'hBB85; sin_val = 16'h93DC; end
            8'hAA: begin cos_val = 16'hBE32; sin_val = 16'h9236; end
            8'hAB: begin cos_val = 16'hC0E9; sin_val = 16'h90A1; end
            8'hAC: begin cos_val = 16'hC3A9; sin_val = 16'h8F1D; end
            8'hAD: begin cos_val = 16'hC673; sin_val = 16'h8DAB; end
            8'hAE: begin cos_val = 16'hC946; sin_val = 16'h8C4A; end
            8'hAF: begin cos_val = 16'hCC21; sin_val = 16'h8AFB; end
            8'hB0: begin cos_val = 16'hCF04; sin_val = 16'h89BE; end
            8'hB1: begin cos_val = 16'hD1EF; sin_val = 16'h8894; end
            8'hB2: begin cos_val = 16'hD4E1; sin_val = 16'h877B; end
            8'hB3: begin cos_val = 16'hD7D9; sin_val = 16'h8676; end
            8'hB4: begin cos_val = 16'hDAD8; sin_val = 16'h8583; end
            8'hB5: begin cos_val = 16'hDDDC; sin_val = 16'h84A3; end
            8'hB6: begin cos_val = 16'hE0E6; sin_val = 16'h83D6; end
            8'hB7: begin cos_val = 16'hE3F4; sin_val = 16'h831C; end
            8'hB8: begin cos_val = 16'hE707; sin_val = 16'h8276; end
            8'hB9: begin cos_val = 16'hEA1E; sin_val = 16'h81E2; end
            8'hBA: begin cos_val = 16'hED38; sin_val = 16'h8163; end
            8'hBB: begin cos_val = 16'hF055; sin_val = 16'h80F6; end
            8'hBC: begin cos_val = 16'hF374; sin_val = 16'h809E; end
            8'hBD: begin cos_val = 16'hF695; sin_val = 16'h8059; end
            8'hBE: begin cos_val = 16'hF9B8; sin_val = 16'h8027; end
            8'hBF: begin cos_val = 16'hFCDC; sin_val = 16'h800A; end
        endcase
    end

    // 1-Cycle Pipeline Registration[cite: 31]
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_out <= 1'b0;
            cos_out   <= 0;
            sin_out   <= 0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                cos_out <= cos_val;
                sin_out <= sin_val;
            end
        end
    end
endmodule