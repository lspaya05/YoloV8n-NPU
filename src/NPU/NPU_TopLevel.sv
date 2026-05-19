import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module NPU_TopLevel #(

) (

);

// DMA Engine -

// Sequencer - Instruction read, decode, and routing to FIFOS
Sequencer Seq ()

// Functional Unit Blocks - Implemented hardware ea. will have a case that contains the 
//  control hardware that manages each unit. This includes instruction FIFOS, Flag registers to facilitate hand offs, etc

// Can i abstract the memory into each functional unit block? - DMA will have to access it to write, but i think it should be okay
// Would be more complex to have it all in one file then send each to different blocks.

// Instruction fetch wont use the DMA engine, this will be seperate does the data coming in need to be stored in some buffer --> 
//      think yes because we need to store at least 4 transmissions before we can understand a full message. It also uses a different clock, 
// should we keep the seq at this slower clock that matches transmission. We wont see any benefit from clocking higher.
//          So in summary DDR(100HZ) --> Seq (100HZ) --> Instr Fifos (300Hz) --> ...

// List of where DMA writes to and where functional units write too:
// EX. FU (Type of Memory): Write - DMA, SA  Read - Requant
// Act Bank A/B (Ping-Pong BRAM):        Write - DMA (DMA_LOAD)                     Read - SA (MATMUL), VPU (MAXPOOL/POOL mode direct)
// Weight Bank A/B (Ping-Pong BRAM):     Write - DMA (WT_LOAD)                      Read - SA (MATMUL weight-load phase)
// Residual Bank (BRAM/URAM):            Write - DMA (DMA_LOAD, skip tensors)        Read - VPU (ELEW_ADD direct port, bypasses SA/PSB/Requant)
// Output Bank (BRAM):                   Write - VPU (SIMD_ACT, ELEW_ADD, MAXPOOL)  Read - DMA (DMA_STORE), VPU (HREDUCE reads prior output)
// PSB (16x16 INT32 Register File):      Write - SA (PSB_ACC), zero-clear on FLUSH   Read - Requant (PSB_FLUSH forwards INT32)
// Requant Coeff BRAM (512 x M/S):       Write - DMA (COEFF_LOAD)                   Read - Requant pipeline (sequential per-channel)
// Act LUT BRAM (256 x INT8):            Write - DMA (LUT_LOAD, dispatched via VPU)  Read - VPU (SIMD_ACT, HREDUCE exp-LUT path)

// We send a bunch of instructions to a a bunch of different places but we have a token handshake being used to ensure timing is met

// DMA handles timing? 