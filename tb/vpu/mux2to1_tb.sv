module mux2to1_tb();

    // DUT signals
    logic [7:0] d0, d1;
    logic select;
    logic [7:0] y;

    // DUT instantiation
    mux2to1 #(.BIT_WIDTH(8)) dut (
        .d0(d0),
        .d1(d1),
        .select(select),
        .y(y)
    );

    // Test stimulus
    initial begin
        // Test case 1: select = 0, should output d0
        d0 = 8'hAA;
        d1 = 8'h55;
        select = 0;
        #1;
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

        $display("PASS: mux2to1 INT8 tests passed");
        $finish;
    end

endmodule
