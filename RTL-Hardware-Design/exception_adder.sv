import round_pkg::*;

module exception_adder (
    input  logic [31:0] a,             // 32-bit operand a
    input  logic [31:0] b,             // 32-bit operand b
    input  logic [2:0]  round,         // 3-bit rounding mode
    input  logic        overflow,      // Overflow flag from calculations
    input  logic        underflow,     // Underflow flag from calculations
    input  logic        inexact_bit,   // Inexact flag from rounding module
    input  logic [31:0] z_calc,        // 32-bit calculated intermediate result
    output logic [31:0] result,        // Final 32-bit result
    output logic        zero_f,        // Zero status flag
    output logic        inf_f,         // Infinity status flag
    output logic        nan_f,         // NaN status flag
    output logic        tiny_f,        // Tiny (underflow) status flag
    output logic        huge_f,        // Huge (overflow) status flag
    output logic        inexact_f      // Final inexact status flag
);

    // Enumeration for floating point number groups
    typedef enum logic [2:0] {
        ZERO     = 3'b000,
        INF      = 3'b001,
        NORM     = 3'b010,
        MIN_NORM = 3'b011,
        MAX_NORM = 3'b100
    } interp_t;

    // Function to interpret the floating point number type
    function interp_t num_interp(input logic [31:0] num);
        logic [7:0] exp;
        exp = num[30:23];
        
        if (exp == 8'd0) begin
            // Exponent is 0: Both Zeroes and Denormals are considered ZERO
            return ZERO;
        end else if (exp == 8'd255) begin
            // Exponent is 255: Both Infinities and NaNs are considered INF
            return INF;
        end else begin
            // Otherwise, it is a normal number
            return NORM;
        end
    endfunction

    // Function to return the 31-bit unsigned value for specific types
    function logic [30:0] z_num(input interp_t num_type);
        case (num_type)
            ZERO:     return 31'd0;                             // Exponent=0, Mantissa=0
            INF:      return {8'd255, 23'd0};                   // Exponent=255, Mantissa=0
            MIN_NORM: return {8'd1, 23'd0};                     // Exponent=1, Mantissa=0
            MAX_NORM: return {8'd254, 23'h7FFFFF};              // Exponent=254, Mantissa=All 1s
            default:  return 31'd0; 
        endcase
    endfunction

    interp_t type_a;
    interp_t type_b;
    logic sa;
    logic sb;
    logic z_sign;

    always_comb begin
        // Initialize all status flags to 0 by default
        zero_f    = 1'b0;
        inf_f     = 1'b0;
        nan_f     = 1'b0;
        tiny_f    = 1'b0;
        huge_f    = 1'b0;
        inexact_f = 1'b0;
        
        // Default result is the calculated one
        result    = z_calc; 

        type_a = num_interp(a);
        type_b = num_interp(b);
        sa     = a[31];
        sb     = b[31];
        z_sign = z_calc[31];

        // Handle Special/Corner Cases
        if (type_a == INF && type_b == INF) begin
            if (sa != sb) begin
                // +Inf combined with -Inf results in NaN
                result = {1'b0, 8'd255, 23'h400000}; // Standard representation of qNaN
                nan_f = 1'b1;
            end else begin
                // Inf with same signs results in Inf
                result = {sa, z_num(INF)};
                inf_f = 1'b1;
            end
        end else if (type_a == INF || type_b == INF) begin
            // Inf combined with anything else (Norm, Zero) is Inf
            result = (type_a == INF) ? {sa, z_num(INF)} : {sb, z_num(INF)};
            inf_f = 1'b1;
        end else if (type_a == ZERO && type_b == ZERO) begin
            // Zero combined with Zero is Zero
            if (sa == sb) begin
                result = {sa, z_num(ZERO)};
            end else if (round == IEEE_ninf) begin
                result = {1'b1, z_num(ZERO)}; // Special rule for round to -Inf
            end else begin
                result = {1'b0, z_num(ZERO)};
            end
            zero_f = 1'b1;
        end else if (type_a == ZERO) begin
            // Zero + Norm -> return Norm
            result = b;
        end else if (type_b == ZERO) begin
            // Norm + Zero -> return Norm
            result = a;
        end else begin
            // Case: Norm x Norm
            if (overflow) begin
                // Overflow occurred
                huge_f = 1'b1;
                inexact_f = 1'b1;
                
                // Determine whether to round to Infinity or Max Normal
                case (round)
                    IEEE_near:   result = {z_sign, z_num(INF)};
                    IEEE_zero:   result = {z_sign, z_num(MAX_NORM)};
                    IEEE_ninf:   result = z_sign ? {1'b1, z_num(INF)} : {1'b0, z_num(MAX_NORM)};
                    IEEE_pinf:   result = z_sign ? {1'b1, z_num(MAX_NORM)} : {1'b0, z_num(INF)};
                    near_maxMag: result = {z_sign, z_num(INF)};
                    default:     result = {z_sign, z_num(INF)};
                endcase
                
                // Activate inf_f if we rounded to Infinity
                if (result[30:23] == 8'd255) inf_f = 1'b1;
                
            end else if (underflow) begin
                // Underflow occurred
                tiny_f = 1'b1;
                inexact_f = 1'b1;
                
                // Determine whether to round to Zero or Min Normal
                case (round)
                    IEEE_near:   result = {z_sign, z_num(ZERO)};
                    IEEE_zero:   result = {z_sign, z_num(ZERO)};
                    IEEE_ninf:   result = z_sign ? {1'b1, z_num(MIN_NORM)} : {1'b0, z_num(ZERO)};
                    IEEE_pinf:   result = z_sign ? {1'b1, z_num(ZERO)} : {1'b0, z_num(MIN_NORM)};
                    near_maxMag: result = {z_sign, z_num(MIN_NORM)};
                    default:     result = {z_sign, z_num(ZERO)};
                endcase
                
                // Activate zero_f if we rounded to Zero
                if (result[30:23] == 8'd0) zero_f = 1'b1;
                
            end else begin
                // No overflow or underflow, use the calculated normal result
                result = z_calc;
                inexact_f = inexact_bit;
            end
        end
    end

endmodule