// ----------------------------------------------------------------------------
// Design Name:    fp_addsub_top
// Based on IEEE-754 standard
// This is the top level module (wrapper) for the floating point add/sub unit.
// Use it to instantiate the fp_addsub.sv module inside it
// ---------------------------------------------------------------------------

module fp_adder_top (
    input logic [31:0] a, b,                            // 32-bit floating point inputs
    input logic [2:0] round,                            // rounding mode
    input logic clk, resetn,                            // clock and reset signals
    output logic [31:0] result,                         // 32-bit floating point result
    output logic [7:0] status                           // 7-bit status flags
);

    // Intermediate signals for pipeline
    logic [31:0] a1, b1;
    logic [2:0] round1;
    logic [31:0] result1;
    logic [7:0] status1;

    // DO THE INSTANTIATION HERE
    // E.G.
    fp_adder adder (
        .a(a1),
        .b(b1),
        .round(round1),
        .z(result1),
        .status(status1)
    );

    // Wrapper registers
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            {a1, b1, round1, result, status} <= '0;
        end else begin
            a1 <= a;
            b1 <= b;
            round1 <= round;
            result <= result1;
            status <= status1;
        end
    end
endmodule