import round_pkg::*;

module fp_adder (
    input  logic [31:0] a,        // 32-bit operand a
    input  logic [31:0] b,        // 32-bit operand b
    input  logic [2:0]  round,    // 3-bit rounding mode
    output logic [31:0] z,        // 32-bit final result
    output logic [7:0]  status    // 8-bit status flags
);

    // --- 1) Input Extraction & Sign Calculation ---
    logic sa, sb;
    logic [7:0] Ea, Eb;
    logic [23:0] mant_a, mant_b;
    logic z_sign;

    assign sa = a[31];
    assign sb = b[31];
    assign Ea = a[30:23];
    assign Eb = b[30:23];
    
    // Add the implicit hidden bit '1' for normal numbers
    assign mant_a = {1'b1, a[22:0]};
    assign mant_b = {1'b1, b[22:0]};

    always_comb begin
        if (sa == sb) begin
            z_sign = sa;
        end else begin
            // If signs differ, the sign of the result is the sign of the larger magnitude
            if (a[30:0] > b[30:0]) begin
                z_sign = sa;
            end else begin
                z_sign = sb;
            end
        end
    end

    // --- 2) Exponent Calculation ---
    logic [7:0] max_exp;
    logic [8:0] exp_diff;
    logic       sign_exp_diff;

    exponent_calc exp_inst (
        .Ea(Ea),
        .Eb(Eb),
        .max_exp(max_exp),
        .exp_diff(exp_diff),
        .sign_exp_diff(sign_exp_diff)
    );

    // --- 3) Mantissa Calculation ---
    logic [27:0] result_mant;

    mant_calc mant_inst (
        .exp_diff(exp_diff),
        .mant_a(mant_a),
        .mant_b(mant_b),
        .sign_exp_diff(sign_exp_diff),
        .sa(sa),
        .sb(sb),
        .result_mant(result_mant)
    );

    // --- 4) Normalization ---
    logic [8:0]  norm_exp;
    logic [26:0] norm_mant;

    norm_adder norm_inst (
        .max_exp(max_exp),
        .result_mant(result_mant),
        .norm_exp(norm_exp),
        .norm_mant(norm_mant)
    );

    // --- 5) Rounding ---
    logic [24:0] round_mant;
    logic        inexact_bit;

    round_adder round_inst (
        .round(round),
        .norm_mant(norm_mant),
        .z_sign(z_sign),
        .round_mant(round_mant),
        .inexact_bit(inexact_bit)
    );

    // --- 6) Post-Round Normalization ---
    logic [22:0] final_mant;
    logic signed [9:0] final_exp; // Using 10 bits signed to easily detect underflow/overflow
    logic overflow, underflow;
    logic [31:0] z_calc;

    always_comb begin
        // Check if rounding caused an overflow in the mantissa
        if (round_mant[24] == 1'b1) begin
            // Shift right by 1, increment exponent
            final_mant = round_mant[23:1];
            final_exp  = {1'b0, norm_exp} + 10'd1;
        end else begin
            // No shift needed
            final_mant = round_mant[22:0];
            final_exp  = {1'b0, norm_exp};
        end

        // Detect Overflow (Exponent >= 255) and Underflow (Exponent <= 0)
        overflow  = (final_exp >= 10'd255) ? 1'b1 : 1'b0;
        underflow = (final_exp <= 10'd0)   ? 1'b1 : 1'b0;

        // Assemble the intermediate calculated result
        z_calc = {z_sign, final_exp[7:0], final_mant};
    end

    // --- 7) Exception Handling ---
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;

    exception_adder exc_inst (
        .a(a),
        .b(b),
        .round(round),
        .overflow(overflow),
        .underflow(underflow),
        .inexact_bit(inexact_bit),
        .z_calc(z_calc),
        .result(z),
        .zero_f(zero_f),
        .inf_f(inf_f),
        .nan_f(nan_f),
        .tiny_f(tiny_f),
        .huge_f(huge_f),
        .inexact_f(inexact_f)
    );

    // --- 8) Assemble Status Register ---
    // Mapping according to Table 3:
    // bit 0: Zero, bit 1: Infinity, bit 2: Invalid (NaN), bit 3: Tiny (Underflow)
    // bit 4: Huge (Overflow), bit 5: Inexact, bit 6: Unused (0), bit 7: Div by 0 (0)
    assign status = {2'b00, inexact_f, huge_f, tiny_f, nan_f, inf_f, zero_f};

endmodule