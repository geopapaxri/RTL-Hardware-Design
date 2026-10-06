module exponent_calc (
    input  logic [7:0] Ea,             // 8-bit exponent of operand a
    input  logic [7:0] Eb,             // 8-bit exponent of operand b
    output logic [7:0] max_exp,        // 8-bit maximum exponent
    output logic [8:0] exp_diff,       // 9-bit absolute difference between exponents
    output logic       sign_exp_diff   // Sign of the exponent difference (1 if Ea > Eb)
);

    // Calculate the sign of the difference
    // If Ea is greater than Eb, the sign is 1, otherwise 0
    assign sign_exp_diff = (Ea > Eb) ? 1'b1 : 1'b0;

    // Output the maximum exponent between Ea and Eb
    assign max_exp = (Ea > Eb) ? Ea : Eb;

    // Calculate the absolute difference between the exponents
    // We pad with a leading zero to ensure a 9-bit unsigned subtraction
    assign exp_diff = (Ea > Eb) ? ({1'b0, Ea} - {1'b0, Eb}) : ({1'b0, Eb} - {1'b0, Ea});

endmodule