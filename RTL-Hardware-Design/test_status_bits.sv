module test_status_bits (
    input logic zero_f,
    input logic inf_f,
    input logic nan_f,
    input logic tiny_f,
    input logic huge_f,
    input logic inexact_f
);

    always_comb begin
        // Immediate assertions to check that mutually exclusive flags do not assert together
        assert_zero_inf:  assert (!(zero_f && inf_f))  else $error("Zero and Inf asserted together!");
        assert_zero_nan:  assert (!(zero_f && nan_f))  else $error("Zero and NaN asserted together!");
        assert_inf_nan:   assert (!(inf_f && nan_f))   else $error("Inf and NaN asserted together!");
        assert_tiny_huge: assert (!(tiny_f && huge_f)) else $error("Tiny and Huge asserted together!");
        assert_huge_zero: assert (!(huge_f && zero_f)) else $error("Huge and Zero asserted together!");
        assert_tiny_inf:  assert (!(tiny_f && inf_f))  else $error("Tiny and Inf asserted together!");
        assert_nan_tiny:  assert (!(nan_f && tiny_f))  else $error("NaN and Tiny asserted together!");
        assert_nan_huge:  assert (!(nan_f && huge_f))  else $error("NaN and Huge asserted together!");
    end

endmodule