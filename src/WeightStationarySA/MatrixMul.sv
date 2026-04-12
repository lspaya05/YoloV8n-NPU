// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-12
// Weight-stationary systolic array of ARRAY_HEIGHT x ARRAY_LENGTH PEs that streams skewed
//   activations left-to-right and accumulates partial sums top-to-bottom, outputting one 
//   row of dot products that are NOT guaranteed to be correct.
// Parameters:
//     - FORMAT_BITWIDTH: Bit width of weight and activation data paths
//     - ACCUMULATOR_BITWIDTH: Bit width of accumulator registers
//     - ARRAY_HEIGHT: Number of PE rows in the systolic array
//     - ARRAY_LENGTH: Number of PE columns in the systolic array
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - loadingWeight_c: Weight-load enable broadcast to all PEs
//     - weightInputRow: ARRAY_LENGTH FORMAT_BITWIDTH-bit weights loaded into the first PE row
//     - activationInputCol: ARRAY_HEIGHT FORMAT_BITWIDTH-bit activations fed into the leftmost PE column
// Outputs:
//     - MatrixMulOut: ARRAY_LENGTH ACCUMULATOR_BITWIDTH-bit accumulated dot products from the bottom PE row
//Expects inputs for activations and mul to be the same. as that is in param

module MatrixMul #(
    parameter int FORMAT_BITWIDTH = 8,
    parameter int ACCUMULATOR_BITWIDTH = 32,
    parameter int ARRAY_HEIGHT = 16,
    parameter int ARRAY_LENGTH = 16
) (
    input logic clk, rst, loadingWeight_c, //@BERNARDO: honestly the FSM needs to decide when the loading is done... 
    input logic signed [FORMAT_BITWIDTH - 1 : 0] weightInputRow [ARRAY_LENGTH - 1 : 0], // @LEONARD NEEDS TO LOAD Bottom TO TOP
    input logic signed [FORMAT_BITWIDTH - 1 : 0] activationInputCol [ARRAY_HEIGHT - 1 : 0], //THis can load left to right just needs the skew
    output logic [ACCUMULATOR_BITWIDTH - 1 : 0] MatrixMulOut [ARRAY_LENGTH - 1 : 0] // will prob need a fifo outside this output? 
);
    // Intermediate PE Signals: 
    logic [ACCUMULATOR_BITWIDTH - 1 : 0] accumulateOut [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];
    logic [FORMAT_BITWIDTH - 1 : 0] weightOut [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];
    logic [FORMAT_BITWIDTH - 1 : 0] activationOut [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];


    assign MatrixMulOut = accumulateOut[ARRAY_HEIGHT - 1];

    genvar i, j;
    generate
        for (i = 0; i < ARRAY_HEIGHT; i++) begin : gen_PE_Rows
            for (j = 0; j < ARRAY_LENGTH; j++) begin : gen_PE_Col

                logic [FORMAT_BITWIDTH - 1 : 0] intermediateWeightIn;
                logic [ACCUMULATOR_BITWIDTH - 1 : 0] intermediateAccumulatorIn;

                if (i == 0) begin : gen_ifRow0
                    assign intermediateWeightIn = weightInputRow[i];
                    assign intermediateAccumulatorIn = '0;
                end else begin : gen_ifRowNot0
                    assign intermediateWeightIn =  weightOut[i - 1][j];
                    assign intermediateAccumulatorIn = accumulateOut[i-1][j];

                end

                logic [FORMAT_BITWIDTH - 1 : 0] intermediateActivationIn;

                if (j == 0) 
                    assign intermediateActivationIn = activationInputCol[j];
                else 
                    assign intermediateActivationIn = activationOut[i][j - 1];
                end 

                ProcessingElement #(.FORMAT_BITWIDTH(FORMAT_BITWIDTH), .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH) 
                    ) PE (
                        .loadWeight(loadingWeight_c), .clk(clk), .rst(rst),
                        .weightIn(intermediateWeightIn), .activationIn(intermediateActivationIn),
                        .accumlatorIn(intermediateAccumulatorIn),
                        .weightOut(weightOut[i][j]), .activationOut(activationOut[i][j]),
                        .accumlatorOut(accumulateOut[i][j])
                    );
            end 
         
    endgenerate 

endmodule