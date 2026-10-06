module test_status_z_combinations (
    input logic clk,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [31:0] z,
    input logic zero_f,
    input logic inf_f,
    input logic nan_f,
    input logic huge_f
);

    // 1. If 'zero' asserts, all bits of exponent of 'z' must be 0
    property p_zero;
        @(posedge clk) zero_f |-> (z[30:23] == 8'h00);
    endproperty
    assert_p_zero: assert property(p_zero) else $error("Zero flag is 1 but exponent is not 0");

    // 2. If 'inf' asserts, all bits of exponent of 'z' must be 1
    property p_inf;
        @(posedge clk) inf_f |-> (z[30:23] == 8'hFF);
    endproperty
    assert_p_inf: assert property(p_inf) else $error("Inf flag is 1 but exponent is not 255");
// 3. If 'nan' asserts, 2 cycles ago exponents of 'a' and 'b' were 255 and signs were opposite
    property p_nan;
        @(posedge clk) nan_f |-> ($past(a[30:23], 2) == 8'hFF && $past(b[30:23], 2) == 8'hFF && $past(a[31], 2) != $past(b[31], 2));
    endproperty
    assert_p_nan: assert property(p_nan) else $error("NaN flag is 1 but inputs 2 cycles ago were not opposite infinities");

        // 4. If 'huge' asserts, exponent of 'z' is 255 OR (exponent is 254 and mantissa is all 1s)
    property p_huge;
        @(posedge clk) huge_f |-> (z[30:23] == 8'hFF) || (z[30:23] == 8'hFE && z[22:0] == 23'h7FFFFF);
    endproperty
    assert_p_huge: assert property(p_huge) else $error("Huge flag is 1 but 'z' is neither Infinity nor MaxNormal");

endmodule