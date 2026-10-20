// tb_traffic_light.v
// Self-checking testbench: 4 safety rules checked every clock tick,
// plus 6 test scenarios for the pedestrian button.

`timescale 1ns / 1ps

module tb_traffic_light;

    // ---- Same state numbers as the design, so the tests can read them ----
    localparam ALL_RED = 0, NORTH_GREEN = 1, NORTH_AMBER = 2,
               EAST_GREEN = 3, EAST_AMBER = 4, WALK = 5;

    // ---- Signals ----
    reg  clk        = 0;
    reg  reset      = 1;
    reg  ped_button = 0;
    wire nr, na, ng;    // north red, amber, green
    wire er, ea, eg;    // east red, amber, green
    wire walk;          // walk light

    integer errors     = 0;  // total rule-breaks found
    integer walk_count = 0;  // how many WALKs have happened
    integer e0;              // errors at the start of the current test
    integer w0;              // walk_count at the start of the current test

    // ---- Plug in the design ----
    traffic_light #(
        .GREEN_TICKS(10),
        .AMBER_TICKS(3),
        .WALK_TICKS(5)
    ) dut (
        .clk(clk), .reset(reset), .ped_button(ped_button),
        .north_red(nr), .north_amber(na), .north_green(ng),
        .east_red(er),  .east_amber(ea),  .east_green(eg),
        .walk_light(walk)
    );

    // ---- Clock: one tick every 10ns ----
    always #5 clk = ~clk;

    // =========================================================
    // SAFETY RULES: checked on every clock tick
    // =========================================================
    reg [2:0] prev_state = ALL_RED;
    reg       prev_walk  = 0;

    always @(posedge clk) begin
        if (!reset) begin
            // Rule 1: never both green
            if (ng && eg) begin
                $display("ERROR at %t: BOTH directions are GREEN!", $time);
                errors = errors + 1;
            end
            // Rule 2: exactly one light per road
            if (nr + na + ng != 1) begin
                $display("ERROR at %t: North shows %0d lights", $time, nr + na + ng);
                errors = errors + 1;
            end
            if (er + ea + eg != 1) begin
                $display("ERROR at %t: East shows %0d lights", $time, er + ea + eg);
                errors = errors + 1;
            end
            // Rule 3: WALK light only when BOTH roads are red
            if (walk && !(nr && er)) begin
                $display("ERROR at %t: WALK is on but a road is not red!", $time);
                errors = errors + 1;
            end
            // Rule 4: WALK must start straight after an AMBER
            if (dut.state == WALK && prev_state != WALK &&
                prev_state != NORTH_AMBER && prev_state != EAST_AMBER) begin
                $display("ERROR at %t: WALK started without an amber first!", $time);
                errors = errors + 1;
            end
            // Count WALKs: each time the walk light switches on
            if (walk && !prev_walk)
                walk_count = walk_count + 1;
        end
        prev_state <= dut.state;
        prev_walk  <= walk;
    end

    // =========================================================
    // HELPER TASKS (little reusable routines)
    // =========================================================

    // Press the button for one tick. It's changed on the FALLING edge,
    // so it's steady when the design reads it on the RISING edge.
    task press_button;
        begin
            @(negedge clk) ped_button = 1;
            @(negedge clk) ped_button = 0;
        end
    endtask

    // Wait a number of clock ticks
    task wait_ticks;
        input integer n;
        begin
            repeat (n) @(posedge clk);
        end
    endtask

    // Wait for the START of a state (not halfway through one)
    task wait_for_start_of;
        input [2:0] s;
        begin
            wait (dut.state != s);
            wait (dut.state == s);
        end
    endtask

    task start_test;
        input integer n;
        begin
            e0 = errors;
            w0 = walk_count;
            $display("--- TEST %0d ---", n);
        end
    endtask

    task end_test;
        input integer n;
        begin
            if (errors == e0) $display("TEST %0d PASSED", n);
            else              $display("TEST %0d FAILED", n);
        end
    endtask

    // =========================================================
    // THE TESTS
    // =========================================================
    initial begin
        $timeformat(-9, 0, " ns", 8);
        $dumpfile("traffic_light.vcd");
        $dumpvars(0, tb_traffic_light);

        #20 reset = 0;

        // ---- TEST 1: no button -> WALK never happens ----
        start_test(1);
        $display("    No button: WALK should never happen");
        wait_ticks(60);                       // more than 2 full cycles
        if (walk_count != w0) begin
            $display("ERROR: WALK happened without the button");
            errors = errors + 1;
        end
        end_test(1);

        // ---- TEST 2: button during NORTH_GREEN ----
        start_test(2);
        $display("    Button during NORTH_GREEN: no cut-short, WALK, then EAST_GREEN");
        wait_for_start_of(NORTH_GREEN);
        press_button;
        if (dut.state != NORTH_GREEN) begin
            $display("ERROR: the button cut the green short");
            errors = errors + 1;
        end
        wait (dut.state == WALK);
        wait (dut.state != WALK);
        if (dut.state != EAST_GREEN) begin
            $display("ERROR: after WALK expected EAST_GREEN, got state %0d", dut.state);
            errors = errors + 1;
        end
        if (walk_count != w0 + 1) begin
            $display("ERROR: expected 1 WALK, got %0d", walk_count - w0);
            errors = errors + 1;
        end
        end_test(2);

        // ---- TEST 3: button during EAST_GREEN ----
        start_test(3);
        $display("    Button during EAST_GREEN: WALK, then NORTH_GREEN");
        wait_for_start_of(EAST_GREEN);
        press_button;
        wait (dut.state == WALK);
        wait (dut.state != WALK);
        if (dut.state != NORTH_GREEN) begin
            $display("ERROR: after WALK expected NORTH_GREEN, got state %0d", dut.state);
            errors = errors + 1;
        end
        if (walk_count != w0 + 1) begin
            $display("ERROR: expected 1 WALK, got %0d", walk_count - w0);
            errors = errors + 1;
        end
        end_test(3);

        // ---- TEST 4: button pressed 3 times -> only ONE walk ----
        start_test(4);
        $display("    Button pressed 3 times: only one WALK");
        wait_for_start_of(NORTH_GREEN);
        press_button;
        press_button;
        press_button;
        wait (dut.state == WALK);
        wait (dut.state != WALK);
        wait_ticks(60);                       // a full extra cycle: no second WALK
        if (walk_count != w0 + 1) begin
            $display("ERROR: expected 1 WALK, got %0d", walk_count - w0);
            errors = errors + 1;
        end
        end_test(4);

        // ---- TEST 5: button pressed DURING the walk -> ignored ----
        start_test(5);
        $display("    Button during WALK: ignored, no extra WALK");
        wait_for_start_of(NORTH_GREEN);
        press_button;
        wait (dut.state == WALK);
        press_button;                         // pressed while people are crossing
        wait (dut.state != WALK);
        wait_ticks(60);
        if (walk_count != w0 + 1) begin
            $display("ERROR: button during WALK caused an extra WALK");
            errors = errors + 1;
        end
        end_test(5);

        // ---- TEST 6: reset in the middle -> all-red, request forgotten ----
        start_test(6);
        $display("    Reset mid-green after a button press: ALL_RED, request forgotten");
        wait_for_start_of(NORTH_GREEN);
        press_button;                         // request a walk...
        wait_ticks(3);
        @(negedge clk) reset = 1;             // ...then reset halfway through green
        @(negedge clk);
        if (dut.state != ALL_RED) begin
            $display("ERROR: after reset expected ALL_RED, got state %0d", dut.state);
            errors = errors + 1;
        end
        if (dut.walk_requested != 0) begin
            $display("ERROR: reset did not clear the WALK request");
            errors = errors + 1;
        end
        reset = 0;
        wait_ticks(60);
        if (walk_count != w0) begin
            $display("ERROR: a WALK happened after reset (request should be forgotten)");
            errors = errors + 1;
        end
        end_test(6);

        // ---- Final result ----
        $display("");
        if (errors == 0) $display("=== ALL TESTS PASSED ===");
        else             $display("=== TESTS FAILED: %0d errors ===", errors);
        $finish;
    end

    // ---- Watchdog: if a test gets stuck waiting forever, stop and fail ----
    initial begin
        #20000;
        $display("=== TESTS FAILED: TIMEOUT (a test got stuck waiting) ===");
        $finish;
    end

endmodule