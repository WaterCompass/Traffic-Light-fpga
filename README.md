# Traffic Light Controller (Verilog / FPGA + Arduino)

![Tests](https://github.com/WaterCompass/Traffic-Light-fpga/actions/workflows/tests.yml/badge.svg)

A traffic light controller for a 4-way junction with a pedestrian crossing, designed in
Verilog as a finite state machine (FSM) and verified with a self-checking testbench.
Tests run automatically on every push using GitHub Actions. The same design is also
built in C on an Arduino with real LEDs, to compare hardware and software approaches.

## What it does
- Controls a 4-way junction where the north–south road and the east–west road take
  turns. Opposite directions share the same signal, so two sets of outputs control all
  four approaches.
- 6 states: ALL_RED (safe reset), NORTH_GREEN, NORTH_AMBER, EAST_GREEN, EAST_AMBER, WALK
- **Pedestrian button:** a press is remembered and served at the next safe point
  (straight after an amber), so a green is never cut short
- During WALK both roads are red; afterwards the junction carries on where it left off
- Presses during WALK are ignored; reset returns to all-red and clears any request
- Timing is set with parameters, so it runs fast in simulation or at real speed on a board

## How it's tested
**4 safety rules, checked on every clock tick:**
1. North and East are never green at the same time
2. Each road always shows exactly one light
3. The WALK light is only on when both roads are red
4. WALK only ever starts straight after an amber

**6 test scenarios:**
| Test | Scenario | Expected |
|---|---|---|
| 1 | No button | WALK never happens |
| 2 | Button during north green | Green not cut short → WALK → east green |
| 3 | Button during east green | WALK → north green |
| 4 | Button pressed 3 times | Only one WALK |
| 5 | Button pressed during WALK | Ignored |
| 6 | Reset mid-green after a press | ALL_RED, request forgotten |

**Proving the checks work:** I injected bugs on purpose and confirmed the testbench
caught them. When I made east stay green during WALK, rules 1 and 2 did *not* catch it,
but the new rule 3 did (20 errors). This is why each new feature got its own safety rule.

**Two simulators, same result:** the tests run in Vivado (xsim) locally and in Icarus
Verilog on GitHub Actions. Both finish at exactly 4015 ns with all tests passing, which
shows the design doesn't rely on simulator-specific behaviour.

## Running the tests
    python run_tests.py
The script automatically uses Icarus Verilog if installed, otherwise Vivado's
command-line simulator. GitHub Actions runs the same script on every push.

## Waveform
The full test run. Each `ped_button` blip is latched in `walk_requested`, and `walk`
turns on after the next amber. You can see the triple press (only one WALK), the press
during a WALK (ignored), and the reset at the end clearing a pending request (no WALK).

![Simulation waveform](Waveform.png)

## Arduino version (software vs hardware)
The same design written in C for an Arduino Uno, with real LEDs and a push button
(`arduino/traffic_light/traffic_light.ino`). Same 6 states, same button rules, same
safety checks. Blue LEDs are used in place of amber in my build.

| | FPGA (Verilog) | Arduino (C) |
|---|---|---|
| How it runs | Everything updates in parallel on each clock tick | `loop()` runs one line at a time, over and over |
| Timing | A counter counts clock ticks | `millis()` measures elapsed time |
| Button | Its own circuit, always watching | Checked once each time round the loop |
| Safety checks | In the testbench, every tick | Inside `setLights()`, before the LEDs change |
| Testing | Automated testbench + CI | Manual tests + Serial Monitor |

**What I learned:** using `delay()` on the Arduino would freeze the loop and miss
button presses, so I used `millis()` instead. The FPGA never has this problem,
because the hardware is always running in parallel.

![Arduino build](arduino.jpg)

## Design decisions
- **Button presses are latched** in `walk_requested`, so a quick press isn't missed.
- **A press on the exact tick an amber ends** is served one cycle later rather than
  immediately: slightly slower, but never unsafe.
- **The testbench drives inputs on the falling clock edge**, so they're stable when
  the design samples them on the rising edge.

## Bugs I fixed
- **Times printed 1000× too big:** `%t` prints in picoseconds by default. Fixed with
  `$timeformat(-9, 0, " ns", 8)`.
- **Test result never printed:** Vivado's default run time stopped before the final
  check. Fixed by using Run All so the test runs to `$finish`.
- **Syntax error from the file name:** Vivado generated `module Traffic-Light`, but
  Verilog names can't contain hyphens. Renamed the module to `traffic_light`.

## Project structure
- `rtl/Traffic-Light.v`: the design (FSM)
- `tb/tb_traffic_light.v`: self-checking testbench (4 rules, 6 tests)
- `run_tests.py`: runs the tests (Icarus or Vivado) and prints PASS/FAIL
- `.github/workflows/tests.yml`: runs the tests automatically on every push
- `arduino/traffic_light/traffic_light.ino`: the same design in C for an Arduino Uno

## Tools
Verilog, Vivado 2023.2, Icarus Verilog, Python, GitHub Actions, Arduino (C)

## License
© 2026 Ayub (WaterCompass). All rights reserved.
If you'd like to use any of this code, please contact me first. I'm happy to say yes,
as long as you credit me.