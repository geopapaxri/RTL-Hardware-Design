package round_pkg;

    // Enumeration type definition for the supported rounding modes
    typedef enum logic [2:0] {
        IEEE_near   = 3'b000,  // Round to nearest, ties to even
        IEEE_zero   = 3'b001,  // Round towards zero
        IEEE_ninf   = 3'b010,  // Round towards negative infinity
        IEEE_pinf   = 3'b011,  // Round towards positive infinity
        near_maxMag = 3'b100   // Round to nearest, ties to max magnitude
    } round_t;

endpackage