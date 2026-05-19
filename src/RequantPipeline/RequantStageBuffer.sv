// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-18
// Widens the 16-lane INT32 PSB flush stream to a 64-lane INT32 vector by
// collecting GROUP = LANES_OUT / LANES_IN consecutive rows before firing.
// Parameters:
//     - LANES_IN:  INT32 lanes per PSB row  (= SA_COLS = 16)
//     - LANES_OUT: INT32 lanes in output beat (= VPU_LANES = 64)
// Inputs:
//     - clk, rst:  Clock and active-high synchronous reset
//     - row_i:     Packed LANES_IN x 32-bit INT32 row from PSB
//     - valid_i:   High when row_i holds a valid row
// Outputs:
//     - data_o:    Packed LANES_OUT x 32-bit INT32 vector (stable until next valid_o)
//     - valid_o:   One-cycle pulse one cycle after the GROUP-th row is received

module RequantStageBuffer #(
    parameter int LANES_IN  = 16,
    parameter int LANES_OUT = 64
) (
    input  logic                     clk,
    input  logic                     rst,
    input  logic [LANES_IN*32-1:0]   row_i,
    input  logic                     valid_i,
    output logic [LANES_OUT*32-1:0]  data_o,
    output logic                     valid_o
);

    localparam int GROUP     = LANES_OUT / LANES_IN;
    localparam int CNT_WIDTH = $clog2(GROUP);

    logic [LANES_OUT*32-1:0] buf_r;
    logic [CNT_WIDTH-1:0]    cnt_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            buf_r   <= '0;
            cnt_r   <= '0;
            valid_o <= 1'b0;
        end else begin
            valid_o <= 1'b0;
            if (valid_i) begin
                buf_r[cnt_r * (LANES_IN * 32) +: LANES_IN * 32] <= row_i;
                if (cnt_r == CNT_WIDTH'(GROUP - 1)) begin
                    cnt_r   <= '0;
                    valid_o <= 1'b1;
                end else begin
                    cnt_r <= cnt_r + 1'b1;
                end
            end
        end
    end

    assign data_o = buf_r;

endmodule
