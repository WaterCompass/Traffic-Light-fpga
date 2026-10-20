# run_tests.py
# Runs the Verilog testbench and prints PASS or FAIL.
# - On your Windows laptop it uses Vivado's simulator (xvlog / xelab / xsim).
# - On GitHub (Linux) it uses Icarus Verilog.
# Exit code 0 = pass, 1 = fail (GitHub's auto-testing uses this).

import os
import shutil
import subprocess
import sys

DESIGN    = "rtl/Traffic-Light.v"
TESTBENCH = "tb/tb_traffic_light.v"
TOP       = "tb_traffic_light"          # the testbench module name

# Where Vivado's tools are on Windows (change this if yours is different)
VIVADO_BIN = r"C:\Xilinx\Vivado\2023.2\bin"


def run(cmd):
    """Run a command and return its result (output + success/fail code)."""
    return subprocess.run(cmd, capture_output=True, text=True)


def simulate_with_icarus():
    print("Simulator: Icarus Verilog")
    result = run(["iverilog", "-o", "sim.vvp", DESIGN, TESTBENCH])
    if result.returncode != 0:
        print("COMPILE FAILED:\n" + result.stdout + result.stderr)
        sys.exit(1)
    return run(["vvp", "sim.vvp"]).stdout


def simulate_with_vivado():
    print("Simulator: Vivado (xsim)")
    xvlog = os.path.join(VIVADO_BIN, "xvlog.bat")
    xelab = os.path.join(VIVADO_BIN, "xelab.bat")
    xsim  = os.path.join(VIVADO_BIN, "xsim.bat")

    # 1. Compile the Verilog files
    result = run([xvlog, DESIGN, TESTBENCH])
    if result.returncode != 0:
        print("COMPILE FAILED:\n" + result.stdout + result.stderr)
        sys.exit(1)

    # 2. Connect them into one simulation called "tb_sim"
    result = run([xelab, TOP, "-s", "tb_sim"])
    if result.returncode != 0:
        print("ELABORATE FAILED:\n" + result.stdout + result.stderr)
        sys.exit(1)

    # 3. Run it all the way to $finish (-R = run all, then quit)
    return run([xsim, "tb_sim", "-R"]).stdout


def main():
    # Pick whichever simulator is available
    if shutil.which("iverilog"):
        output = simulate_with_icarus()
    elif os.path.exists(os.path.join(VIVADO_BIN, "xvlog.bat")):
        output = simulate_with_vivado()
    else:
        print("No simulator found. Install Icarus Verilog, or check VIVADO_BIN.")
        sys.exit(1)

    print(output)

    # Count how many tests passed / failed
    lines = [line.strip() for line in output.splitlines()]
    passed = sum(1 for l in lines if l.startswith("TEST") and l.endswith("PASSED"))
    failed = sum(1 for l in lines if l.startswith("TEST") and l.endswith("FAILED"))
    print(f"{passed} tests passed, {failed} tests failed")

    # Final verdict
    if "ALL TESTS PASSED" in output and failed == 0:
        print("RESULT: PASS")
        sys.exit(0)
    else:
        print("RESULT: FAIL")
        sys.exit(1)


if __name__ == "__main__":
    main()