// File: round_adder.sv
// Rounding unit for IEEE 754 Floating Point Adder

import round_pkg::*;

module round_adder (
    input  logic [2:0]  round,
    input  logic [26:0] norm_mant,
    input  logic        z_sign,
    output logic [24:0] round_mant, // Matched to 25 bits [24:0]
    output logic        inexact_bit
);

    logic [23:0] mant_base;
    logic g_bit, r_bit, s_bit;
    logic round_up;
    logic [24:0] temp_sum;

    // Extracting the 24-bit mantissa and the 3 rounding bits (Guard, Round, Sticky)
    assign mant_base = norm_mant[26:3];
    assign g_bit     = norm_mant[2];
    assign r_bit     = norm_mant[1];
    assign s_bit     = norm_mant[0];

    // Rounding logic based on IEEE 754 modes defined in round_pkg
    always_comb begin
        round_up = 1'h0;
        case (round)
            3'b000: begin // IEEE_near (round to nearest, ties to even)
                round_up = g_bit && (r_bit || s_bit || mant_base[0]);
            end
            3'b001: begin // IEEE_zero (truncate / round towards zero)
                round_up = 1'b0;
            end
            3'b010: begin // IEEE_ninf (round towards minus infinity)
                round_up = z_sign && (g_bit || r_bit || s_bit);
            end
            3'b011: begin // IEEE_pinf (round towards plus infinity)
                round_up = !z_sign && (g_bit || r_bit || s_bit);
            end
            3'b100: begin // near_maxMag (round to nearest, ties to max magnitude)
                round_up = g_bit;
            end
            default: begin
                round_up = 1'b0;
            end
        endcase
    end

    // Perform the rounding addition and preserve the 25th bit for overflow
    assign temp_sum = mant_base + round_up;
    
    // Assign outputs
    assign round_mant  = temp_sum; // Full 25-bit assignment
    assign inexact_bit = g_bit || r_bit || s_bit;

endmodule