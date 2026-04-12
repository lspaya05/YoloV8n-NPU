//Expects inputs for actiavtons and mul to be the same. as hat is in param 

module MatrixMul #(
    parameter int FORMAT_BITWIDTH = 8,
    parameter int ACCUMULATOR_BITWIDTH = 32,
    parameter int ARRAY_HEIGHT = 16,
    parameter int ARRAY_LENGTH = 16
) (
    input logic clk, rst, loadingWeight_c, //@BERNARDO: honestly the FSM needs to decide when the loading is done... 
    input wordFormat_t [ARRAY_LENGTH - 1 : 0] weightInputRow, // @LEONARD NEEDS TO LOAD Bottom TO TOP
    input wordFormat_t [ARRAY_HEIGHT - 1 : 0] activationInputCol //THis can load left to right just needs the skew
     // HOW DO I EVEN FORM THE OUTPUT, lowkey weird. - will prob need a fifo 
);
    // Type definitions weights and activations:
    typedef logic signed [FORMAT_BITWIDTH - 1 : 0] wordFormat_t;



    genvar i, j;
    generate
        for (i = 0; i < ARRAY_LENGTH; i++) begin : gen_PE_Rows
            for (j = 0; j < ARRAY_LENGTH; j++) begin : gen_PE_Col

                logic [FORMAT_BITWIDTH - 1 : 0] intermediateWeightIn;

                if (i == 0) begin
                    assign intermediateWeightIn = weightInputRow[i];
                end else begin
                    assign intermediateWeightIn = 
                end
                ProcessingElement #(.FORMAT_BITWIDTH(FORMAT_BITWIDTH), .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH) 
                    ) (
                        .loadWeight(loadingWeight_c), .clk(clk), .rst(rst),
                        .weightIn, activationIn,
                        accumlatorIn,
                        weightOut, activationOut,
                        accumlatorOut
                    );
            end 
        end 
    endgenerate 

endmodule