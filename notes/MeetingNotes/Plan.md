# Meeting Notes

## Notes 4/11/2026
1. Systolic Array 
2. Vector Processing Unit (VPU)
3. Surround Architecture and Memory Control 
4. Interfacing to the FPGA
5. The Requantizaton Unit, Reduction Tree...

Systolic Array Plan:
Bernardo: FSM Control (SA PE), Reading VPU 
Leonard: PE Matrix [Parameterized], Inputs to Matrix (Figure memory)

Cntrl: Loading Weights, Weights loaded, 

Meet Thurs 3PM and Sunday (Play by ear)

## Notes 4/16/2026
Need to figure out: 
1. Loading Things to Chip memory, (Ping Pong Buffer, FIFO, Reg file?). What the the process for loading all this memory etc
2. DMA Engine - What is it why does it matter.
3. General NPU Architecture - is it like CPU 5 stage, how do we strucutre it and sure that the massive amounts of data procduced from differnet units organized and operated on in a efficient mannar
4. ISA? How to choose which component to use, can we use multiple at the same time?
5. MNIST - does the components we have planned for match that? 
6. PJRT - What is it Review, understand.

## Notes 4/19/2026
Need to complete by 4/23:
Bernardo: Reading VPU(Relu, Gelu, LN), Defining the microarchitecture and also deciding the input/output bits, design for controllers and datapath..etc.
Leonard: Drawing the microarchitecture for the General NPU architecture and making sure the overall flow that we have right now is sufficient to run Yolov8