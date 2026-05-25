// =============================================================================
// File        : NPU_HW_params_pkg.sv
// Project     : EE470 Neural Engine — KR260
// Description : Hardware sizing constants for the NPU. Import this package in
//               any RTL module that needs array dimensions or data widths.
//               Does NOT contain ISA definitions — see NPU_ISA_pkg.sv.
// =============================================================================

package NPU_HW_params_pkg;

    // -------------------------------------------------------------------------
    // Systolic Array
    // -------------------------------------------------------------------------
    localparam int SA_ROWS     = 16;   // PE array height
    localparam int SA_COLS     = 16;   // PE array width

    // -------------------------------------------------------------------------
    // Data widths
    // -------------------------------------------------------------------------
    localparam int ACT_WIDTH       = 8;   // INT8 activation / weight
    localparam int ACCUM_WIDTH     = 32;  // INT32 partial sum
    localparam int COEFF_M_WIDTH   = 32;  // requant scale M (INT32, Q31 format)
    localparam int COEFF_S_WIDTH   = 4;   // requant shift S (UINT4)

    // -------------------------------------------------------------------------
    // Memory depths
    // -------------------------------------------------------------------------
    localparam int PSB_DEPTH       = 16;   // PSB rows  (= SA_ROWS)
    localparam int LUT_DEPTH       = 256;  // act LUT and HREDUCE exp LUT entries
    localparam int MAX_CHANNELS    = 512;  // requant coefficient buffer depth

    // -------------------------------------------------------------------------
    // VPU
    // -------------------------------------------------------------------------
    localparam int VPU_LANES = 64;   // vector processing lanes

    // -------------------------------------------------------------------------
    // SRAM Hub bank depths
    // -------------------------------------------------------------------------
    localparam int ACT_BUF_DEPTH  = 256;   // activation ping-pong (per bank)
    localparam int WT_BUF_DEPTH   = 256;   // weight ping-pong (per bank)
    localparam int RES_BANK_DEPTH = 1024;  // residual (skip-tensor) bank
    localparam int OUT_BANK_DEPTH = 512;   // output bank (VPU -> DMA_STORE)

endpackage : NPU_HW_params_pkg
