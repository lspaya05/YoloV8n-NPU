module mux2to1_tb();

    // DUT signals
    logic [31:0] d0, d1;
    logic select;
    logic [31:0] y;

    // DUT instantiation
    mux2to1 dut (
        .d0(d0),
        .d1(d1),
        .select(select),
        .y(y)
    );

    // Test stimulus
    initial begin
        // Test case 1: select = 0, should output d0
        d0 = 32'hAAAAAAAA;
        d1 = 32'h55555555;
        select = 0;
        #1; // Small delay for combinational logic
        if (y !== d0) begin
            $display("FAIL: select=0, y=%h, expected=%h", y, d0);
            $finish;
        end

        // Test case 2: select = 1, should output d1
        select = 1;
        #1;
        if (y !== d1) begin
            $display("FAIL: select=1, y=%h, expected=%h", y, d1);
            $finish;
        end

        // Test case 3: Random values
        d0 = $random;
        d1 = $random;
        select = 0;
        #1;
        if (y !== d0) begin
            $display("FAIL: random select=0, y=%h, expected=%h", y, d0);
            $finish;
        end

        select = 1;
        #1;
        if (y !== d1) begin
            $display("FAIL: random select=1, y=%h, expected=%h", y, d1);
            $finish;
        end

        $display("PASS: All tests passed");
        $finish;
    end

endmodule