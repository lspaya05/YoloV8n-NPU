module universal_dump;
    initial begin
        $dumpfile("waveform.vcd");
        
        // '0' means "dump everything from the top down"
        // No hardcoded module names required!
        $dumpvars(0);
    end
endmodule