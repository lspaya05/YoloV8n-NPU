// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-13
// Controller for Weight-stationary Systolic Array; orchestrates the loading of weights and activations into the PEs, and manages the flow of data through the array.
// Parameters:
//     - ARRAY_HEIGHT: Number of PE rows in the systolic array
//     - K_DIM: The dimension of the dot product (number of MAC operations per output element)
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - start: Signal to start the matrix multiplication operation
// Outputs:
//     - loadingWeight_c: Control signal to broadcast weight-loading enable to the PEs
//     - validActivations: Signal to indicate that activation inputs are now valid
//     - load_done: Pulses high for one cycle when weight loading is complete
//     - done: Pulses high for one cycle when the entire operation is complete
//     - busy: Tells us that the controller is active and processing

module SA_Controller #(
    parameter int ARRAY_HEIGHT = 16,
    parameter int ARRAY_LENGTH = 16,
    parameter int K_DIM = 16
) (
    input  logic clk,
    input  logic rst,
    input  logic start,

    output logic loadingWeight_c,
    output logic validActivations,
    output logic load_done,
    output logic done,
    output logic busy
);

    // Defining the states for the Systolic Array Controller FSM
    // IDLE  : waiting for a start signal
    // LOAD  : broadcast weight-loading enable so weights can fill the array
    // RUN   : allow valid activations to enter the systolic array
    // DRAIN : stop new inputs and let in-flight data finish propagating
    // DONE  : pulse completion for one cycle, then return to IDLE
    enum { IDLE, LOAD, RUN, DRAIN, DONE} ps, ns;

    // Counter for timing each phase.
    // This counter is reset whenever the FSM moves to a new state.
    // While the FSM stays in LOAD, RUN, or DRAIN, it increments once per cycle.
    logic [7:0] counter;

    // Internal done signals
    logic run_done;
    logic drain_done;

    // State register:
    // On reset, force the FSM back to IDLE.
    // Otherwise, update the present state with next state.
    always_ff @(posedge clk) begin
        if (rst) begin
            ps <= IDLE;
        end else begin
            ps <= ns;
        end
    end

    // Phase counter:
    // Reset the counter on reset.
    // Also reset it whenever the FSM changes state so each phase starts at 0.
    // If we remain in LOAD, RUN, or DRAIN, increment once per clock cycle.
    // In IDLE and DONE, hold the counter at 0.
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= 0;
        end else if (ps != ns) begin
            counter <= 0;
        end else begin
            case (ps)
                LOAD:  
                    counter <= counter + 1;
                RUN:   
                    counter <= counter + 1;
                DRAIN: 
                    counter <= counter + 1;
                default: 
                    counter <= 0;
            endcase
        end
    end

    // Done conditions for each phase:
    // The counter values go 0, 1, 2, ..., N-1 for a phase that lasts N cycles.
    // Because of that, the "done" condition for a phase is asserted when the
    // counter reaches the final count value for that phase.
    // LOAD lasts ARRAY_HEIGHT cycles.
    // RUN lasts K_DIM cycles.
    // DRAIN lasts ARRAY_HEIGHT + ARRAY_LENGTH - 2 cycles.
    always_comb begin
        load_done  = 0;
        run_done   = 0;
        drain_done = 0;

        // Assert only on the final LOAD cycle.
        if ((ps == LOAD) && (counter == ARRAY_HEIGHT - 1))
            load_done = 1;

        // Assert only on the final RUN cycle.
        if ((ps == RUN) && (counter == K_DIM - 1))
            run_done = 1;

        // Assert only on the final DRAIN cycle.
        // Since DRAIN lasts (ARRAY_HEIGHT + ARRAY_LENGTH - 2) cycles,
        // the last counter value is one less than that.
        if ((ps == DRAIN) && (counter == ARRAY_HEIGHT + ARRAY_LENGTH - 3))
            drain_done = 1;
    end

    // Next-state logic:
    // Decide which state the FSM should move to on the next clock cycle based on the current state and inputs.
    always_comb begin
        ns = ps;

        case (ps)
            IDLE: begin
                // Stay in IDLE until start is asserted, then move to LOAD.
                if (start) begin
                    ns = LOAD;
                end
            end

            LOAD: begin
                // Once all weight-load cycles are complete, begin RUN.
                if (load_done) begin
                    ns = RUN;
                end
            end

            RUN: begin
                // After all activation cycles have been issued, begin DRAIN.
                if (run_done) begin
                    ns = DRAIN;
                end
            end

            DRAIN: begin
                // When the array has fully flushed, go to DONE.
                if (drain_done) begin
                    ns = DONE;
                end
            end

            DONE: begin
                // Hold done for one cycle, then return to IDLE.
                ns = IDLE;
            end

            default: begin
                // A default state is required to prevent latches
                ns = IDLE;
            end
        endcase
    end

    // Output logic:
    // Set default values first, then override them for each state.
    // busy just tells the outside world that the controller is working.
    always_comb begin
        loadingWeight_c  = 0;
        validActivations = 0;
        done             = 0;
        busy             = 1;

        case (ps)
            IDLE: begin
                // The controller is waiting for work.
                busy = 0;
            end

            LOAD: begin
                // Tell the systolic array to latch and forward weights.
                loadingWeight_c = 1;
            end

            RUN: begin
                // Tell upstream logic that activation inputs are now valid.
                validActivations = 1;
            end

            DRAIN: begin
                // No new inputs, just let the pipeline flush.
            end

            DONE: begin
                // Assert done for one cycle and mark the controller idle again.
                done = 1;
                busy = 0;
            end
        endcase
    end

endmodule
