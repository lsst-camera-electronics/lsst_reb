# Sequencer Testbench

Cycle-exact regression suite for the sequencer_v4 RTL.  Validates that the
sequencer output waveform (signal values and durations) matches expected
behaviour across 38 test cases covering normal operation, subroutines,
infinite loops, repetition counters, error handling, and edge cases.

## Prerequisites

- **Xilinx Vivado 2024.1** (xvhdl, xelab, xsim).  The path is set at the top
  of `build.sh`; edit `VIVADO_BIN` and `VIVADO_DATA` if your installation
  differs.
- **surf** library checked out as a sibling submodule at `../../../surf`
  relative to this directory (i.e. alongside `lsst_reb` in the parent
  project's submodules directory).

## Running the simulation

```bash
cd lsst_reb/sequencer_v4/TB
bash build.sh
```

The script compiles surf, lsst_reb, and the testbench, then elaborates and
runs the simulation.  Output appears on stdout and is also captured in
`xsim.log`.

A successful run ends with 38 PASS lines and no FAIL lines:

```
PASS T01 : basic single-function program
PASS T02 : two-function sequence
...
```

Any test failure is reported as a FAIL line with the test name and a
description of the mismatch.

## Output

CSV files are written to `sim_data/` (one per test case).  Each CSV contains
the cycle-by-cycle sequencer output: columns are clock cycle, output value,
and duration.  This directory is gitignored.

## Comparing results

`sim_compare.py` performs pairwise cycle-by-cycle comparison of two CSV
directories (e.g. before/after a code change, or simulation vs hardware):

```bash
python3 sim_compare.py sim_data/ ../../../other_run/sim_data/
```

It reports per-test MATCH/MISMATCH with details on the first divergence.

## Hardware validation

Two additional scripts support validation against real hardware via Vivado ILA.

### Required ILA probes

The bitstream must include an ILA core (`u_ila_0`) capturing these signals:

| Signal | Width | Purpose |
|--------|-------|---------|
| `U_REB_v5/sync_cmd_start_seq` | 1-bit | Trigger (rising edge) |
| `U_REB_v5/sequencer_busy` | 1-bit | Marks active window |
| `U_REB_v5/end_sequence` | 1-bit | Marks sequence completion |
| `U_REB_v5/sequencer_out_slv` | 32-bit | Sequencer output bus |

ILA configuration: depth 32768 samples at 100 MHz (327.68 us capture window),
trigger position at 10% (3276 samples pre-trigger).

### Running a capture

Prerequisites:
- Vivado `hw_server` running and accessible (default: `rddev101:3121`; edit
  `HW_SERVER` in `hw_capture.py` if different).
- `rms_write`, `rms_reset`, and `scs_editor` in PATH.
- The `.ltx` probes file from the build (path set in `LTX_FILE`).

```bash
python3 hw_capture.py --partition <name> [--outdir hw_data] [--tests T01,T02,...] [--dry-run]
```

The script generates a Vivado batch Tcl file per test that:
1. Connects to `hw_server` and configures the ILA trigger.
2. Arms the ILA.
3. Resets the sequencer FSM and loads test memory via `rms_write`.
4. Fires the sequencer via `scs_editor`.
5. Waits for capture, exports the waveform as CSV, and resets.

Use `--dry-run` to inspect the generated Tcl without invoking Vivado.

### Comparing hardware vs simulation

```bash
python3 hw_compare.py hw_data/ sim_data/
```

Reports per-test MATCH/MISMATCH between hardware captures and simulation
reference CSVs.

These require a connected REB with the ILA debug core present in the
bitstream.

## File listing

| File | Description |
|------|-------------|
| `tb_sequencer.vhd` | VHDL testbench (38 test cases) |
| `build.sh` | Compile and run script |
| `sim_compare.py` | CSV directory comparator |
| `hw_capture.py` | ILA capture Tcl generator |
| `hw_compare.py` | ILA vs simulation comparator |
| `.gitignore` | Excludes build artifacts and sim_data/ |
