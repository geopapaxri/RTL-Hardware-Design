module lzc (
    input  logic [27:0] result_mant,    // 28-bit input mantissa
    output logic [4:0]  leading_zeroes  // 5-bit number of leading zeroes
);

    always_comb begin
        // Default value if the input is entirely zero
        leading_zeroes = 5'd28; 

        // Iterate from LSB (0) to MSB (27).
        // The highest bit index containing a '1' will be the final assigned value.
        // This implicitly creates a priority encoder.
        for (int i = 0; i < 28; i++) begin
            if (result_mant[i] == 1'b1) begin
                leading_zeroes = 5'(27 - i);
            end
        end
    end

endmodule