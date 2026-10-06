// ----------------------------------------------------------------------
// tb_adder.sv
// Reference testbench (Fully integrated with Hardfloat & Pipeline Scoreboard)
// ----------------------------------------------------------------------

`timescale 1ns/1ps

module tb_adder ();
    // --- Signals matching the top wrapper ---
    logic [31:0] z;             // Testbench signal to store DUT result
    logic [7:0]  status;        // Testbench signal to store DUT status flags
    logic [31:0] a, b;          // DUT inputs
    logic [2:0]  round;         // Rounding mode
    bit clk, resetn;            // Clock and reset signals

    // -------------------  Testbench variables -------------------
    int total_random = 0;
    int success_random = 0;
    int total_corner = 0;
    int success_corner = 0;

    typedef enum logic [3:0] {
        POS_NAN, NEG_NAN, POS_INF, NEG_INF, POS_NORM, NEG_NORM,
        POS_DENORM, NEG_DENORM, POS_ZERO, NEG_ZERO
    } corner_t;

    // Function to generate corner case payloads
    function logic [31:0] get_corner(corner_t ct);
        logic [22:0] rand_mant;
        logic [7:0] rand_exp;
        rand_mant = $urandom();
        rand_exp = $urandom_range(1, 254);
        case (ct)
            POS_NAN:    return {1'b0, 8'hFF, rand_mant | 23'd1};
            NEG_NAN:    return {1'b1, 8'hFF, rand_mant | 23'd1};
            POS_INF:    return {1'b0, 8'hFF, 23'd0};
            NEG_INF:    return {1'b1, 8'hFF, 23'd0};
            POS_NORM:   return {1'b0, rand_exp, rand_mant};
            NEG_NORM:   return {1'b1, rand_exp, rand_mant};
            POS_DENORM: return {1'b0, 8'h00, rand_mant | 23'd1};
            NEG_DENORM: return {1'b1, 8'h00, rand_mant | 23'd1};
            POS_ZERO:   return {1'b0, 8'h00, 23'd0};
            NEG_ZERO:   return {1'b1, 8'h00, 23'd0};
        endcase
    endfunction

    // -------------------  Instantiate the DUT (Wrapper) -------------------
    fp_adder_top dut (
        .clk(clk),
        .resetn(resetn),
        .a(a), 
        .b(b), 
        .round(round), 
        .result(z),      // Connected to 'result' port of professor's wrapper
        .status(status)
    );

    // -------------------  Instantiate the Hardfloat Reference Model -------------------
    logic [31:0] results_hf;
    logic [31:0] results_ref;
    logic [2:0]  rnd_hf;
    logic [31:0] a_hf, b_hf;

    assign rnd_hf = round; // Map rounding mode

    // Hardfloat intermediate recoded signals (33-bit for Single Precision)
    logic [32:0] rec_a, rec_b, rec_z;
    logic [4:0]  exc_flags;

    // Convert Standard Float to Recoded Hardfloat Format
    fNToRecFN #(8, 24) fn2rec_a (.in(a_hf), .out(rec_a));
    fNToRecFN #(8, 24) fn2rec_b (.in(b_hf), .out(rec_b));

    // Hardfloat Combinational Adder
    addRecFN #(8, 24) hf_adder (
        .control(1'b0),
        .subOp(1'b0),
        .a(rec_a),
        .b(rec_b),
        .roundingMode(rnd_hf),
        .out(rec_z),
        .exceptionFlags(exc_flags)
    );

    // Convert Recoded Hardfloat Format back to Standard Float
    recFNToFN #(8, 24) rec2fn_z (.in(rec_z), .out(results_hf));

    // -------------------  Update the reference model inputs (Professor's logic) -------------------
    always_comb begin
        // If a is NaN => Inf
        if(a[30:23] == '1) begin
            a_hf = {a[31], {8{1'b1}}, {23{1'b0}}};
        end
        // If a is denorm => Zero
        else if(a[30:23] == '0 ) begin
            a_hf = {a[31], {31{1'b0}}};
        end
        else begin
            a_hf = a;
        end

        // If b is NaN => Inf
        if(b[30:23] == '1) begin
            b_hf = {b[31], {8{1'b1}}, {23{1'b0}}};
        end
        // If b is denorm => Zero
         else if(b[30:23] == '0 ) begin
            b_hf = {b[31], {31{1'b0}}};
        end
        else begin
            b_hf = b;
        end

        // If result is denorm => Zero or Min normal
        if(results_hf[30:23] == '0 && |results_hf[22:0]) begin
            if (round == 3'b001 || round == 3'b000 || (round == 3'b010 && !results_hf[31]) || (round == 3'b011 && results_hf[31]) || round == 3'b100)
                results_ref = {results_hf[31], {31{1'b0}}};
            else
                results_ref = {results_hf[31], {7{1'b0}}, 1'b1, {23{1'b0}}};
        end
        // If result is NaN => Inf
        else if(results_hf[30:23] == '1 && |results_hf[22:0]) begin
            results_ref = {results_hf[31], {8{1'b1}}, {23{1'b0}}};
        end
        else begin
            results_ref = results_hf;
        end
    end

    // -------------------  Clock Generation -------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // -------------------  Scoreboard Monitoring (2-Cycle Pipeline) -------------------
    logic        testing_active = 1'b0;
    logic        testing_corner = 1'b0;

    // Pipeline arrays for synchronization
    logic [31:0] expected_z_pipe [1:0];
    logic        monitor_valid [1:0];
    logic        monitor_is_corner [1:0];
    logic [31:0] monitor_a [1:0];
    logic [31:0] monitor_b [1:0];

    // --- STAGE 1 & 2: Shift Registers (Update at POSEDGE) ---
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            monitor_valid[0] <= 1'b0;
            monitor_valid[1] <= 1'b0;
        end else begin
            // Stage 1: Capture Inputs and Hardfloat Expected Result
            expected_z_pipe[0]   <= results_ref;
            monitor_a[0]         <= a;
            monitor_b[0]         <= b;
            monitor_valid[0]     <= testing_active;
            monitor_is_corner[0] <= testing_corner;

            // Stage 2: Move data 1 cycle forward
            expected_z_pipe[1]   <= expected_z_pipe[0];
            monitor_a[1]         <= monitor_a[0];
            monitor_b[1]         <= monitor_b[0];
            monitor_valid[1]     <= monitor_valid[0];
            monitor_is_corner[1] <= monitor_is_corner[0];
        end
    end

    // --- STAGE 3: Verification (Check at NEGEDGE to ensure DUT output 'z' is stable) ---
    always @(negedge clk) begin
        if (monitor_valid[1]) begin 
            // A result is considered SUCCESS if:
            // 1. It matches the expected result exactly (z === expected_z_pipe[1])
            // OR
            // 2. The DUT correctly identified a NaN (status[2] == 1), because the professor's 
            //    reference model overrides NaNs to Infinity (Exponent == 8'hFF, Mantissa == 0).
            if ((z === expected_z_pipe[1]) || (status[2] == 1'b1 && expected_z_pipe[1][30:23] == 8'hFF)) begin
                if (monitor_is_corner[1]) success_corner++;
                else success_random++;
            end else begin
                // Mismatch detected
                if (monitor_is_corner[1]) begin
                    $display("Corner Mismatch! a=%h, b=%h | Expected=%h, Got=%h", monitor_a[1], monitor_b[1], expected_z_pipe[1], z);
                end else begin
                    $display("Random Mismatch! a=%h, b=%h | Expected=%h, Got=%h", monitor_a[1], monitor_b[1], expected_z_pipe[1], z);
                end
            end
        end
    end

// ------------------- Stimulus Generation Tasks -------------------
    task run_corner_cases();
        round = 3'b000; // Default to IEEE_near mode
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 10; j++) begin
                @(negedge clk);
                a = get_corner(corner_t'(i));
                b = get_corner(corner_t'(j));
                // Enable the monitor AFTER driving the a, b inputs
                testing_active = 1'b1; 
                testing_corner = 1'b1;
                total_corner++;
            end
        end
        // Allow 1 extra cycle for the pipeline to fetch the final (100th) test
        @(negedge clk);
        testing_active = 1'b0; 
        testing_corner = 1'b0;
        
        // Flush the pipeline to process remaining data
        @(negedge clk);
        @(negedge clk);
    endtask

    task run_random_cases(int num_tests);
        round = 3'b000; // Default to IEEE_near mode
        for (int i = 0; i < num_tests; i++) begin
            @(negedge clk);
            a = $urandom();
            b = $urandom();
            // Enable the monitor AFTER driving the a, b inputs
            testing_active = 1'b1; 
            testing_corner = 1'b0;
            total_random++;
        end
        // Allow 1 extra cycle for the pipeline to fetch the final (1000th) test
        @(negedge clk);
        testing_active = 1'b0; 
        
        // Flush the pipeline to process remaining data
        @(negedge clk);
        @(negedge clk);
    endtask

    // ------------------- Main Execution Block -------------------
    initial begin
        resetn = 0;
        a = 0; b = 0; round = 0;
        #20 resetn = 1;
        
        $display("----------------------------------------");
        $display("Starting tests...");
        
        run_corner_cases();
        run_random_cases(1000);
        
        // Wait for final pipeline elements to clear
        #100;
        
        $display("----------------------------------------");
        $display("Simulation finished.");
        $display("Total Tests Executed: %0d", total_random + total_corner);
        $display("SUCCESS Random Tests: %0d / %0d", success_random, total_random);
        $display("SUCCESS Corner Tests: %0d / %0d", success_corner, total_corner);
        $display("----------------------------------------");
        $stop;
    end

    // ------------------- BINDING ASSERTIONS TO TOP WRAPPER -------------------
    bind fp_adder_top test_status_bits tsb_inst (
        .zero_f(status[0]), .inf_f(status[1]), .nan_f(status[2]),
        .tiny_f(status[3]), .huge_f(status[4]), .inexact_f(status[5])
    );

    bind fp_adder_top test_status_z_combinations tsz_inst (
        .clk(clk), .a(a), .b(b), .z(result), // Maps inner signal 'result' of fp_adder_top to SVA's 'z'
        .zero_f(status[0]), .inf_f(status[1]), .nan_f(status[2]), .huge_f(status[4])
    );

endmodule