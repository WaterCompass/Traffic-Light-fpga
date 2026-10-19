   `timescale 1ns / 1ps

// traffic_light.v
// A traffic light controller for a two-road junction (North and East).
// It's a state machine: it moves through a fixed list of states,
// spending a set number of clock ticks in each one.

module traffic_light #(
    parameter GREEN_TICKS = 10,   // how many clock ticks green lasts
    parameter AMBER_TICKS = 3     // how many clock ticks amber (and all-red) lasts
)(
    input  wire clk,              // the clock (heartbeat)
    input  wire reset,            // 1 = go back to the safe state
    output reg  north_red,
    output reg  north_amber,
    output reg  north_green,
    output reg  east_red,
    output reg  east_amber,
    output reg  east_green
);

    // ---- Give each state a number ----
    localparam ALL_RED     = 3'd0;
    localparam NORTH_GREEN = 3'd1;
    localparam NORTH_AMBER = 3'd2;
    localparam EAST_GREEN  = 3'd3;
    localparam EAST_AMBER  = 3'd4;

    reg [2:0]  state;   // which state we're in (3 bits = numbers 0 to 7)
    reg [31:0] count;   // how many ticks we've spent in this state

    // ---- PART 1: Move between states (happens on every clock tick) ----
    always @(posedge clk) begin
        if (reset) begin
            state <= ALL_RED;        // safe state
            count <= 0;
        end else begin
            case (state)
                ALL_RED: begin
                    if (count == AMBER_TICKS - 1) begin
                        state <= NORTH_GREEN;
                        count <= 0;
                    end else
                        count <= count + 1;
                end

                NORTH_GREEN: begin
                    if (count == GREEN_TICKS - 1) begin
                        state <= NORTH_AMBER;
                        count <= 0;
                    end else
                        count <= count + 1;
                end

                NORTH_AMBER: begin
                    if (count == AMBER_TICKS - 1) begin
                        state <= EAST_GREEN;
                        count <= 0;
                    end else
                        count <= count + 1;
                end

                EAST_GREEN: begin
                    if (count == GREEN_TICKS - 1) begin
                        state <= EAST_AMBER;
                        count <= 0;
                    end else
                        count <= count + 1;
                end

                EAST_AMBER: begin
                    if (count == AMBER_TICKS - 1) begin
                        state <= NORTH_GREEN;
                        count <= 0;
                    end else
                        count <= count + 1;
                end

                default: begin               // should never happen, but just in case
                    state <= ALL_RED;
                    count <= 0;
                end
            endcase
        end
    end

    // ---- PART 2: Decide which lights are on, based on the state ----
    always @(*) begin
        // Start with every light off...
        north_red = 0; north_amber = 0; north_green = 0;
        east_red  = 0; east_amber  = 0; east_green  = 0;

        // ...then switch on the right ones
        case (state)
            NORTH_GREEN: begin north_green = 1; east_red   = 1; end
            NORTH_AMBER: begin north_amber = 1; east_red   = 1; end
            EAST_GREEN:  begin north_red   = 1; east_green = 1; end
            EAST_AMBER:  begin north_red   = 1; east_amber = 1; end
            default:     begin north_red   = 1; east_red   = 1; end  // ALL_RED, or anything weird
        endcase
    end

endmodule