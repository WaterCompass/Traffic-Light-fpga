`timescale 1ns / 1ps
// traffic_light.v
// Traffic light controller for a two-road junction (North and East),
// with a pedestrian button and a WALK state.

module traffic_light #(
    parameter GREEN_TICKS = 10,   // clock ticks of green
    parameter AMBER_TICKS = 3,    // clock ticks of amber (and all-red at the start)
    parameter WALK_TICKS  = 5     // clock ticks of the pedestrian WALK
)(
    input  wire clk,
    input  wire reset,
    input  wire ped_button,       // 1 while the pedestrian button is pressed
    output reg  north_red,
    output reg  north_amber,
    output reg  north_green,
    output reg  east_red,
    output reg  east_amber,
    output reg  east_green,
    output reg  walk_light        // 1 = pedestrians can cross
);

    // ---- State numbers ----
    localparam ALL_RED     = 3'd0;
    localparam NORTH_GREEN = 3'd1;
    localparam NORTH_AMBER = 3'd2;
    localparam EAST_GREEN  = 3'd3;
    localparam EAST_AMBER  = 3'd4;
    localparam WALK        = 3'd5;

    reg [2:0]  state;
    reg [31:0] count;            // ticks spent in the current state
    reg        walk_requested;   // remembers that the button was pressed
    reg [2:0]  after_walk;       // which green to go to when WALK finishes

    // ---- PART 1: move between states (every clock tick) ----
    always @(posedge clk) begin
        if (reset) begin
            state          <= ALL_RED;
            count          <= 0;
            walk_requested <= 1'b0;
            after_walk     <= NORTH_GREEN;
        end else begin
            // Remember a button press (presses during WALK are ignored)
            if (ped_button && state != WALK)
                walk_requested <= 1'b1;

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
                        count <= 0;
                        if (walk_requested) begin
                            state      <= WALK;
                            after_walk <= EAST_GREEN;   // east goes next after the walk
                        end else
                            state <= EAST_GREEN;
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
                        count <= 0;
                        if (walk_requested) begin
                            state      <= WALK;
                            after_walk <= NORTH_GREEN;  // north goes next after the walk
                        end else
                            state <= NORTH_GREEN;
                    end else
                        count <= count + 1;
                end

                WALK: begin
                    if (count == WALK_TICKS - 1) begin
                        state          <= after_walk;
                        count          <= 0;
                        walk_requested <= 1'b0;        // request has been served
                    end else
                        count <= count + 1;
                end

                default: begin                         // should never happen
                    state <= ALL_RED;
                    count <= 0;
                end
            endcase
        end
    end

    // ---- PART 2: which lights are on, based on the state ----
    always @(*) begin
        // Start with everything off...
        north_red = 0; north_amber = 0; north_green = 0;
        east_red  = 0; east_amber  = 0; east_green  = 0;
        walk_light = 0;

        // ...then switch on the right ones
        case (state)
            NORTH_GREEN: begin north_green = 1; east_red   = 1; end
            NORTH_AMBER: begin north_amber = 1; east_red   = 1; end
            EAST_GREEN:  begin north_red   = 1; east_green = 1; end
            EAST_AMBER:  begin north_red   = 1; east_amber = 1; end
            WALK:        begin north_red   = 1; east_red   = 1; walk_light = 1; end
            default:     begin north_red   = 1; east_red   = 1; end   // ALL_RED
        endcase
    end

endmodule