module Sequencer #(
    parameter int INPUT_WIDTH = 32,
) (
    input logic clk, rst, 
    input logic [INPUT_WIDTH - 1 : 0] instrSeg,
    

    output logic DMA_en, SA_en, VPU_en  
    output [] 
);



endmodule