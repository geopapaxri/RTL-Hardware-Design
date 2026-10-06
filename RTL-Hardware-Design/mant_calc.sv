module mant_calc (
    input  logic [8:0]  exp_diff,       // 9-bit absolute difference between exponents
    input  logic [23:0] mant_a,         // 24-bit mantissa of operand a (including hidden bit)
    input  logic [23:0] mant_b,         // 24-bit mantissa of operand b (including hidden bit)
    input  logic        sign_exp_diff,  // 1 if Ea > Eb, 0 otherwise
    input  logic        sa,             // Sign bit of operand a
    input  logic        sb,             // Sign bit of operand b
    output logic [27:0] result_mant     // 28-bit resulting mantissa
);

    logic [23:0] large_mant;
    logic [23:0] small_mant;
    logic        a_is_larger;

    // Determine which operand is larger to always subtract the smaller from the larger
    always_comb begin
        if (sign_exp_diff == 1'b1) begin
            a_is_larger = 1'b1;         // Ea > Eb
        end else if (exp_diff == 9'd0 && mant_a >= mant_b) begin
            a_is_larger = 1'b1;         // Exponents equal, but mantissa A is >= mantissa B
        end else begin
            a_is_larger = 1'b0;         // Eb > Ea, or (Ea == Eb and mant_b > mant_a)
        end
    end

    assign large_mant = a_is_larger ? mant_a : mant_b;
    assign small_mant = a_is_larger ? mant_b : mant_a;

    // 49-bit intermediate signal for shifting without losing precision
    logic [48:0] shifted_small;
    
    // Place the 24-bit small mantissa at the top 24 bits, pad with 25 zeroes, then shift
    assign shifted_small = {small_mant, 25'd0} >> exp_diff;

    // Extract Guard, Round, and Sticky bits
    logic guard_bit;
    logic round_bit;
    logic sticky_bit;

    always_comb begin
        guard_bit = shifted_small[24];  // 25th bit from the top
        round_bit = shifted_small[23];  // 26th bit from the top
        
        // If the shift is larger than 48, all small_mant bits fall into the sticky bit
        if (exp_diff > 9'd48) begin
            sticky_bit = |small_mant;   // Bitwise OR of all bits of small_mant
        end else begin
            sticky_bit = |shifted_small[22:0]; // Bitwise OR of the remaining LSBs
        end
    end

    // Construct the 27-bit aligned mantissas
    logic [26:0] op_large;
    logic [26:0] op_small;

    // Pad the larger mantissa with 3 zeroes for G, R, S bits
    assign op_large = {large_mant, 3'b000}; 
    assign op_small = {shifted_small[48:25], guard_bit, round_bit, sticky_bit};

    // Determine if the operation is addition or subtraction
    // Subtraction occurs if the signs of the operands are different
    logic sub_op;
    assign sub_op = sa ^ sb; 

    // Perform the addition or subtraction
    always_comb begin
        if (sub_op) begin
            // Subtraction: Always subtract smaller from larger
            result_mant = {1'b0, op_large} - {1'b0, op_small};
        end else begin
            // Addition
            result_mant = {1'b0, op_large} + {1'b0, op_small};
        end
    end

endmodule