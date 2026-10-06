module norm_adder (
    input  logic [7:0]  max_exp,      // 8-bit calculated maximum exponent
    input  logic [27:0] result_mant,  // 28-bit result mantissa from mant_calc
    output logic [8:0]  norm_exp,     // 9-bit normalized exponent
    output logic [26:0] norm_mant     // 27-bit normalized mantissa
);

    // Signal to store the number of leading zeroes
    logic [4:0] leading_zeroes;

    // Instantiate the Leading Zero Counter (lzc)
    lzc lzc_inst (
        .result_mant(result_mant),
        .leading_zeroes(leading_zeroes)
    );

    logic [4:0] shift_left_amount;

    always_comb begin
        // Initialize outputs to default values to avoid latches
        norm_exp  = {1'b0, max_exp};
        norm_mant = 27'd0;

        if (result_mant[27] == 1'b1) begin
            // Case 1: Result >= 2 (Format: 1x.xxx...)
            // Needs right shift by 1.
            // The lost LSB (result_mant[0]) must be ORed with the new sticky bit.
            norm_mant = {result_mant[27:2], (result_mant[1] | result_mant[0])};
            norm_exp  = max_exp + 1'b1;
        end 
        else if (result_mant[26] == 1'b1) begin
            // Case 2: Result in [1, 2) (Format: 01.xxx...)
            // Already normalized, no shift needed.
            // Just take the lower 27 bits.
            norm_mant = result_mant[26:0];
            norm_exp  = {1'b0, max_exp};
        end 
        else if (result_mant == 28'd0) begin
            // Corner Case: Mantissa is exactly zero
            norm_mant = 27'd0;
            norm_exp  = 9'd0;
        end 
        else begin
            // Case 3: Result < 1 (Format: 00.xxx...)
            // Needs left shift to normalize.
            // Example: If bit 25 is '1', leading_zeroes = 2. We need 1 left shift (2 - 1).
            shift_left_amount = leading_zeroes - 5'd1;
            
            // Perform left shift on the lower 27 bits
            norm_mant = result_mant[26:0] << shift_left_amount;
            
            // Adjust exponent (subtract the shift amount)
            norm_exp  = {1'b0, max_exp} - {4'b0000, shift_left_amount};
        end
    end

endmodule