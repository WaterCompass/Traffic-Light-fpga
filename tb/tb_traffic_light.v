// tb_traffic_light.v
// Testbench: makes a clock, resets the design, prints the lights,
// and checks the safety rules on every clock tick.

`timescale 1ns / 1ps   // time units: 1 nanosecond

module tb_traffic_light;

    // ---- Signals to connect to the design ----
    reg  clk   = 0;
    reg  reset = 1;     // start with reset ON
    wire nr, na, ng;    // north red, amber, green
    wire er, ea, eg;    // east red, amber, green

    integer errors = 0; // counts how many rule-breaks we find

    // ---- Plug in the design (called "dut" = Device Under Test) ----
    traffic_light #(
        .GREEN_TICKS(10),
        .AMBER_TICKS(3)
    ) dut (
        .clk(clk),
        .reset(reset),
        .north_red(nr), .north_amber(na), .north_green(ng),
        .east_red(er),  .east_amber(ea),  .east_green(eg)
    );

    // ---- Make the clock: flip every 5ns, so one full tick = 10ns ----
    always #5 clk = ~clk;

    // ---- Safety checks, on every clock tick ----
    always @(posedge clk) begin
        if (!reset) begin
            // Rule 1: North and East must NEVER both be green
            if (ng && eg) begin
                $display("ERROR at %t: BOTH directions are GREEN!", $time);
                errors = errors + 1;
            end

            // Rule 2: each road must show exactly ONE light at a time
            if (nr + na + ng != 1) begin
                $display("ERROR at %t: North shows %0d lights", $time, nr + na + ng);
                errors = errors + 1;
            end
            if (er + ea + eg != 1) begin
                $display("ERROR at %t: East shows %0d lights", $time, er + ea + eg);
                errors = errors + 1;
            end
        end
    end

    // ---- The test itself ----
    initial begin
        // Print times in nanoseconds (-9 = 10^-9 seconds), 0 decimal places
        $timeformat(-9, 0, " ns", 8);

        // Save the waveform to a file (useful later for running at home)
        $dumpfile("traffic_light.vcd");
        $dumpvars(0, tb_traffic_light);

        // Print the lights every time any of them changes
        $monitor("%t | North: R=%b A=%b G=%b | East: R=%b A=%b G=%b",
                 $time, nr, na, ng, er, ea, eg);

        #20 reset = 0;     // hold reset for 20ns, then let it run
        #1000;             // let it run for 1000ns (about 4 full cycles)

        // Final result
        if (errors == 0)
            $display("=== TEST PASSED: no safety errors ===");
        else
            $display("=== TEST FAILED: %0d errors ===", errors);

        $finish;           // stop the simulation
    end

endmodule