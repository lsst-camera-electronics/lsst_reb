#!/usr/bin/env python3
"""
hw_compare.py — Phase 3/5 hardware comparison for REB_v5 sequencer characterisation.

Reads the ILA CSV files produced by hw_capture.py and compares the captured
sequencer_out_slv trace cycle-by-cycle against the expected sequences from
tb_sequencer.vhd.

Usage:
    python3 hw_compare.py [--indir DIR] [--tests T01,T02,...] [--verbose]

Options:
    --indir DIR         Directory containing CSV files (default: ./hw_data)
    --tests T01,...     Comma-separated list of tests to compare (default: all)
    --verbose           Print the full captured cycle table even on PASS

Exit code: 0 if all tests pass, 1 if any fail or CSV missing.

CSV format notes:
  Vivado write_hw_ila_data -csv_file produces a file with:
    - A header section starting with lines beginning with '#' or blank
    - A column-header line
    - Data rows (one per sample, most-recent-first or sequential)

  Probe columns appear as:
    - Bus:  "U_REB_v5/sequencer_out_slv[31:0]"  or  "U_REB_v5/sequencer_out_slv"
            Value is a hex string, e.g. "000000CC"
    - Bit:  "U_REB_v5/sequencer_busy[0]"  or  "U_REB_v5/sequencer_busy"
            Value is "0" or "1"

  If Vivado exports individual bits instead of a bus column, the script
  reconstructs the 32-bit word from bits [31:0].

  The sample index column is typically named "Sample in Buffer" or similar.
  The script locates the trigger sample by finding the first row where
  sync_cmd_start_seq transitions from 0 to 1.
"""

import argparse
import csv
import os
import sys

# ---------------------------------------------------------------------------
# Expected sequences
#
# Copied directly from tb_sequencer.vhd expected arrays.
# Format: list of (hex_string, cycle_count) tuples.
# Coverage: from first-output-change (inclusive) through end_sequence cycle
# (inclusive).
#
# Standard F0 tail used by most tests: ("00000001", 4), ("00000002", 1)
#
# NOTE: The comparison window ends at the cycle where end_sequence fires
# (inclusive).  end_sequence fires when the last-slice counter reaches
# 4 remaining cycles.  Visible cycles for the last slice = (t1+2) - 4.
# For the standard F0 (t1=3): (3+2)-4 = 1 visible cycle -> "00000002" x 1.
# For T12's F0 (t1=6): (6+2)-4 = 4 visible cycles -> "00000200" x 4.
#
# _F0_TAIL window note: tb_sequencer.vhd run_test() captures 8 cycles after
# end_sequence fires, so the simulation sees F0_V1 for 5 cycles after end_seq.
# hw_compare stops at end_seq_idx (inclusive), so F0_V1 is visible for only
# (t1+2)-4 = (3+2)-4 = 1 cycle before end_seq fires.  Both values are correct
# for their respective capture windows; ("00000002", 1) is correct here.
# ---------------------------------------------------------------------------

_F0_TAIL = [("00000001", 4), ("00000002", 1)]

EXPECTED = {
    "T01": [
        ("000000CC", 4),   # F1 ts0 (first): 3+1
        ("000000DD", 7),   # F1 ts1 (last):  5+2
    ] + _F0_TAIL,

    "T02": [
        ("000000AA", 4),   # F1 ts0 (first): 3+1
        ("000000BB", 6),   # F1 ts1 (middle): 6
        ("000000CC", 7),   # F1 ts2 (last):  5+2
    ] + _F0_TAIL,

    "T03": [
        ("000000AA", 4),   # F1 ts0 (first): 3+1
        ("000000BB", 4),   # F1 ts1 (middle): 4
        ("000000CC", 5),   # F1 ts2 (middle): 5
        ("000000DD", 8),   # F1 ts3 (last):  6+2
    ] + _F0_TAIL,

    "T04": [
        ("000000CC", 4),   # rep 1 ts0
        ("000000DD", 7),   # rep 1 ts1
        ("000000CC", 4),   # rep 2 ts0
        ("000000DD", 7),   # rep 2 ts1
        ("000000CC", 4),   # rep 3 ts0
        ("000000DD", 7),   # rep 3 ts1
    ] + _F0_TAIL,

    "T05": [
        ("000000CC", 4),   # F1 ts0 (F2 skipped, rep=0)
        ("000000DD", 7),   # F1 ts1
    ] + _F0_TAIL,

    "T06": [
        ("000000CC", 4),   # ind_func_call -> F1 ts0
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T07": [
        ("000000CC", 4),   # ind_rep_call F1 x2, rep 1
        ("000000DD", 7),
        ("000000CC", 4),   # rep 2
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T08": [
        ("000000CC", 4),   # ind_all_call -> F1 x1
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T09": [
        ("000000CC", 4),   # jump_to_add 1-level, F1 ts0
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T10": [
        ("000000CC", 4),   # sub rep 1, F1 ts0
        ("000000DD", 7),
        ("000000CC", 4),   # sub rep 2, F1 ts0
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T10b": [
        ("000000CC", 4),   # jump_to_add addr=4, F1 ts0
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T11": [
        ("000000CC", 4),   # 2-level nesting, F1 ts0
        ("000000DD", 7),
        ("000000EE", 4),   # F2 ts0
        ("000000FF", 7),
    ] + _F0_TAIL,

    "T12": [
        ("000000CC", 4),   # F1 ts0
        ("000000DD", 7),   # F1 ts1
        ("00000100", 5),   # F0 ts0 (first): t0=4 -> 4+1=5
        ("00000200", 4),   # F0 ts1 (last): t1=6 -> 6+2=8 raw; end_seq fires at raw-4=4 visible
    ],
    # Note: T12 uses non-standard F0 (t1=6), so no _F0_TAIL.
    # General rule: last slice visible cycles = (t1+2) - 4.
    # Standard F0 has t1=3 -> 5-4=1 visible cycle (matches _F0_TAIL).
    # T12 has t1=6 -> 8-4=4 visible cycles.

    "T13": [
        ("000000CC", 4),   # F1 ts0 (first): 3+1
        ("000000DD", 3),   # F1 ts1 (last):  1+2  boundary case
    ] + _F0_TAIL,

    "T16": [
        # Clean sequence after DISC-005 fix (lsst_reb f875887): no glitch cycles.
        # Pre-fix baseline (cc9fb85) had: 80010234x1, 000000CCx4, 000000DDx6,
        #   000010DDx1, 80011234x4, 80015678x1
        ("000000CC", 4),   # F1 ts0 (first): 3+1
        ("000000DD", 7),   # F1 ts1 (last):  5+2  (full 7 cycles, no glitch)
        ("80011234", 4),   # F0 ts0 (first): 3+1
        ("80015678", 1),   # F0 ts1: end_seq fires on cycle 1
    ],

    "T17": [
        # ind_add_jump: indirect sub address, direct rep=1; same output as T09
        ("000000CC", 4),
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T18": [
        # ind_rep_jump: direct sub address, indirect rep=2; F1 plays twice
        ("000000CC", 4),
        ("000000DD", 7),
        ("000000CC", 4),
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T19": [
        # ind_all_jump: both indirect, rep=2; same output as T18
        ("000000CC", 4),
        ("000000DD", 7),
        ("000000CC", 4),
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T20": [
        # jump_to_add 3-level nesting; same output as T11
        ("000000CC", 4),
        ("000000DD", 7),
        ("000000EE", 4),
        ("000000FF", 7),
    ] + _F0_TAIL,
    "T21": [
        # sub_trailer bits[15:0]=0xFFFF don't-care; identical output to T09
        ("000000CC", 4),
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T25a": [
        # sync_cmd_main_addr=1 -> prog_mem starts at word 4; guard at words 0-3 skipped.
        # Output identical to T01 (F1 ts0/ts1, then F0).
        ("000000CC", 4),
        ("000000DD", 7),
    ] + _F0_TAIL,

    "T28": [
        # 16-slice F1 (full function depth): ts0=first, ts1..ts14=middle, ts15=last.
        ("00000100", 4),    # ts0  (first): time=3 -> 3+1=4
        ("00000200", 3),    # ts1  (middle)
        ("00000300", 3),    # ts2
        ("00000400", 3),    # ts3
        ("00000500", 3),    # ts4
        ("00000600", 3),    # ts5
        ("00000700", 3),    # ts6
        ("00000800", 3),    # ts7
        ("00000900", 3),    # ts8
        ("00000A00", 3),    # ts9
        ("00000B00", 3),    # ts10
        ("00000C00", 3),    # ts11
        ("00000D00", 3),    # ts12
        ("00000E00", 3),    # ts13
        ("00000F00", 3),    # ts14
        ("00001000", 5),    # ts15 (last):  time=3 -> 3+2=5
    ] + _F0_TAIL,

    "T29": [
        # 4-level nesting, K=3 func_calls in innermost body: F1, F2, F1.
        ("000000CC", 4), ("000000DD", 7),   # F1 (first call)
        ("000000EE", 4), ("000000FF", 7),   # F2
        ("000000CC", 4), ("000000DD", 7),   # F1 (third call)
    ] + _F0_TAIL,
}

# ---------------------------------------------------------------------------
# Negative-test expected specifications
#
# T26 and T27 exercise the rep=0 skip mechanism: all func_call and sub-jump
# instructions are skipped, leaving only F0 to execute.  Because both F0
# output values (F0_V0=0x00000001 and F0_V1=0x00000002) are used as the idle
# output, the phase of F0 at trigger time is non-deterministic in hardware
# (the sequencer cycles through F0 continuously; trigger timing is not
# aligned to the F0 period).  Cycle-exact comparison is therefore unreliable:
# the observed sequence may be either [F0_V1 x 1] (if idle_out=F0_V0) or
# [F0_V0 x 4, F0_V1 x 1] (if idle_out=F0_V1).
#
# Instead, these tests use a negative comparison: verify that no F1/F2 output
# values appear, that the output stays within {F0_V0, F0_V1}, and that
# end_sequence fires within a reasonable window.
# ---------------------------------------------------------------------------

NEGATIVE_TESTS = {
    "T26": {
        "desc":     "rep=0 skip for sub-jump opcodes 0x5–0x8 (F1/F2 must not appear)",
        "forbidden": {0x000000CC, 0x000000DD, 0x000000EE, 0x000000FF},
        "max_cycles": 30,    # F0 runs twice at most before end_seq; generous bound
    },
    "T27": {
        "desc":     "rep=0 skip for indirect func_call opcodes 0x2–0x4 (F1/F2 must not appear)",
        "forbidden": {0x000000CC, 0x000000DD, 0x000000EE, 0x000000FF},
        "max_cycles": 30,
    },
}

ALL_TEST_NAMES = ["T01","T02","T03","T04","T05","T06","T07","T08",
                  "T09","T10","T10b","T11","T12","T13","T14","T15","T16",
                  "T17","T18","T19","T20","T21","T22",
                  "T25a","T26","T27","T28","T29"]

# Tests whose expected behaviour is a hang (busy stays high, end_seq never fires).
# These are dispatched to compare_hang_test() instead of compare_test().
# T22 is NOT in HANG_TESTS: its simulation CSV (T22.csv) is produced by a normal
# run_test() call (Phase C only, a terminating run), not a hang-test capture.
# T22 has no entry in EXPECTED, so compare_test() will SKIP it automatically —
# which is the correct behaviour (no hw CSV is captured for T22).
HANG_TESTS = {"T14", "T15"}

# ---------------------------------------------------------------------------
# CSV parsing
# ---------------------------------------------------------------------------

def find_column(headers, candidates):
    """
    Return the index of the first header that matches any candidate substring
    (case-insensitive).  Returns None if not found.
    """
    cl = [h.lower() for h in headers]
    for c in candidates:
        c_low = c.lower()
        for i, h in enumerate(cl):
            if c_low in h:
                return i
    return None


def parse_bus_value(s):
    """
    Parse a bus value string from Vivado ILA CSV.
    Vivado may output hex (e.g. "000000CC"), binary (e.g. "0b000..."),
    or decimal.  Returns an integer.
    """
    s = s.strip()
    if s.startswith("0x") or s.startswith("0X"):
        return int(s, 16)
    if s.startswith("0b") or s.startswith("0B"):
        return int(s, 2)
    # Try hex first (Vivado usually outputs plain hex without prefix)
    try:
        return int(s, 16)
    except ValueError:
        pass
    return int(s)


def load_csv(csv_path):
    rows = []

    with open(csv_path, newline="") as f:
        raw = f.read()

    lines = raw.splitlines()

    # Find first non-comment, non-blank line (the CSV header)
    data_start = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            data_start = i
            break

    reader = csv.reader(lines[data_start:])
    headers = None

    for row in reader:
        if headers is None:
            headers = [h.strip() for h in row]
            continue
        if not row or all(c.strip() == "" for c in row):
            continue
        # Skip Vivado radix descriptor row (second row in CSV, e.g. "Radix - UNSIGNED,...")
        if row[0].strip().startswith("Radix"):
            continue
        while len(row) < len(headers):
            row.append("0")

        assert headers is not None
        _hdrs: list[str] = headers

        def get(candidates):
            for cand in candidates:
                cl = cand.lower()
                for i, h in enumerate(_hdrs):
                    if cl in h.lower():
                        return row[i].strip()
            return None

        def getidx(candidates):
            for cand in candidates:
                cl = cand.lower()
                for i, h in enumerate(_hdrs):
                    if cl in h.lower():
                        return i
            return None

        # Sample index
        s = get(["Sample in Buffer", "sample"])
        sample_idx = int(s) if (s is not None and s.lstrip("-").isdigit()) else len(rows)

        # sequencer_out_slv: prefer bus column
        out_val = None

        # Look for a column that has the bus notation [31:0] or is the plain bus
        for i, h in enumerate(_hdrs):
            hl = h.lower()
            if "out_slv" in hl:
                v = row[i].strip()
                if "[31:0]" in hl or (v and not (len(v) == 1 and v in "01")):
                    # Likely a bus value
                    try:
                        out_val = parse_bus_value(v)
                    except (ValueError, TypeError):
                        out_val = None
                    break

        if out_val is None:
            # Reconstruct from individual bits
            acc = 0
            found = False
            for bit in range(32):
                for i, h in enumerate(_hdrs):
                    if "out_slv[{}]".format(bit) in h.lower():
                        v = row[i].strip()
                        if v in ("1", "1'b1", "H"):
                            acc |= (1 << bit)
                        found = True
                        break
            out_val = acc if found else 0

        # busy
        busy_v = get(["sequencer_busy[0]", "sequencer_busy"])
        busy = 1 if busy_v and busy_v in ("1","1'b1","H") else 0

        # end_sequence
        end_v = get(["end_sequence[0]", "end_sequence"])
        end_val = 1 if end_v and end_v in ("1","1'b1","H") else 0

        # trigger input
        trig_v = get(["sync_cmd_start_seq"])
        trig_val = 1 if trig_v and trig_v in ("1","1'b1","H") else 0

        rows.append({
            "sample_idx": sample_idx,
            "seq_out":    out_val,
            "busy":       busy,
            "end_seq":    end_val,
            "trig_in":    trig_val,
        })

    rows.sort(key=lambda r: r["sample_idx"])
    return rows


# ---------------------------------------------------------------------------
# Hang-test comparison logic
# ---------------------------------------------------------------------------

def compare_hang_test(test_name, rows, verbose=False):
    """
    Compare one hang test's captured rows.

    Pass criteria (mirroring tb_sequencer.vhd):
      1. sequencer_busy asserts within 20 samples of the trigger.
      2. end_sequence never fires in any sample from busy-assertion onward.
      3. sequencer_busy stays asserted through the end of the capture.

    Returns True on pass, False on fail.
    """
    if not rows:
        print("FAIL: {} — CSV is empty".format(test_name))
        return False

    # --- Locate trigger sample ---
    trig_idx = None
    prev_trig = 0
    for i, r in enumerate(rows):
        if r["trig_in"] == 1 and prev_trig == 0:
            trig_idx = i
            break
        prev_trig = r["trig_in"]

    if trig_idx is None:
        for i, r in enumerate(rows):
            if r["trig_in"] == 1:
                trig_idx = i
                break

    if trig_idx is None:
        print("FAIL: {} — sync_cmd_start_seq never asserted in capture".format(test_name))
        return False

    # --- Find first busy=1 within 20 samples of trigger ---
    busy_idx = None
    for i in range(trig_idx, min(trig_idx + 20, len(rows))):
        if rows[i]["busy"] == 1:
            busy_idx = i
            break

    if busy_idx is None:
        print("FAIL: {} — sequencer_busy never asserted within 20 samples of trigger"
              .format(test_name))
        return False

    trig_to_busy = busy_idx - trig_idx
    print("--- {} [hang test] ---".format(test_name))
    print("  trigger -> busy            : {} samples".format(trig_to_busy))

    # --- Scan from busy_idx to end of capture ---
    pass_flag = True
    end_seq_sample = None
    busy_lost_sample = None
    samples_monitored = len(rows) - busy_idx

    for i in range(busy_idx, len(rows)):
        r = rows[i]
        if r["end_seq"] == 1 and end_seq_sample is None:
            end_seq_sample = r["sample_idx"]
            pass_flag = False
        if r["busy"] == 0 and busy_lost_sample is None:
            busy_lost_sample = r["sample_idx"]
            pass_flag = False

    print("  samples monitored from busy: {}".format(samples_monitored))

    if verbose:
        stop = min(trig_idx + 30, len(rows) - 1)
        print("  Cycle table (first 30 samples from trigger | busy | end | seq_out):")
        for i in range(trig_idx, stop + 1):
            r = rows[i]
            marker = "<- trig" if i == trig_idx else (
                     "<- busy" if i == busy_idx else "")
            print("  {:6d} | {} | {} | {:08X}  {}".format(
                r["sample_idx"], r["busy"], r["end_seq"], r["seq_out"], marker))

    if end_seq_sample is not None:
        print("  FAIL: end_sequence fired at sample {}".format(end_seq_sample))
    if busy_lost_sample is not None:
        print("  FAIL: sequencer_busy deasserted at sample {}".format(busy_lost_sample))

    if pass_flag:
        print("PASS: {} — hang confirmed (busy=1, end_seq never fired, {} samples monitored)"
              .format(test_name, samples_monitored))
    else:
        print("FAIL: {}".format(test_name))

    return pass_flag


# ---------------------------------------------------------------------------
# Negative-test comparison logic (T26, T27)
# ---------------------------------------------------------------------------

def compare_negative_test(test_name, rows, verbose=False):
    """
    Compare one negative test's captured rows.

    These tests exercise the rep=0 skip path: all func_call / sub-jump
    instructions are skipped, leaving only F0 to execute.  We cannot use
    cycle-exact comparison because the idle_out phase relative to F0 is
    non-deterministic in hardware.

    Pass criteria:
      1. sync_cmd_start_seq asserts (trigger found).
      2. sequencer_busy asserts within 20 samples of trigger.
      3. end_sequence fires within max_cycles samples of trigger.
      4. No forbidden output values appear between trigger and end_seq.

    Returns True on pass, False on fail.
    """
    spec = NEGATIVE_TESTS.get(test_name)
    if spec is None:
        print("SKIP: {} — no negative-test spec defined".format(test_name))
        return True

    if not rows:
        print("FAIL: {} — CSV is empty".format(test_name))
        return False

    forbidden  = spec["forbidden"]
    max_cycles = spec["max_cycles"]

    # --- Locate trigger sample ---
    trig_idx = None
    prev_trig = 0
    for i, r in enumerate(rows):
        if r["trig_in"] == 1 and prev_trig == 0:
            trig_idx = i
            break
        prev_trig = r["trig_in"]
    if trig_idx is None:
        for i, r in enumerate(rows):
            if r["trig_in"] == 1:
                trig_idx = i
                break
    if trig_idx is None:
        print("FAIL: {} — sync_cmd_start_seq never asserted in capture".format(test_name))
        return False

    # --- Find busy and end_seq ---
    busy_idx   = None
    end_seq_idx = None
    for i in range(trig_idx, min(trig_idx + max_cycles + 20, len(rows))):
        r = rows[i]
        if busy_idx is None and r["busy"] == 1:
            busy_idx = i
        if end_seq_idx is None and r["end_seq"] == 1:
            end_seq_idx = i
        if end_seq_idx is not None:
            break

    print("--- {} [negative test] ---".format(test_name))
    print("  {}".format(spec["desc"]))
    if busy_idx is not None:
        print("  trigger -> busy            : {} samples".format(busy_idx - trig_idx))
    else:
        print("  busy: never observed in window")
    if end_seq_idx is not None:
        print("  trigger -> end_sequence    : {} samples".format(end_seq_idx - trig_idx))
    else:
        print("  end_sequence: not observed within {} samples of trigger".format(max_cycles))

    pass_flag = True

    if busy_idx is None:
        print("  FAIL: sequencer_busy never asserted within window")
        pass_flag = False

    if end_seq_idx is None:
        print("  FAIL: end_sequence did not fire within {} samples of trigger".format(max_cycles))
        pass_flag = False

    if end_seq_idx is not None and (end_seq_idx - trig_idx) > max_cycles:
        print("  FAIL: end_sequence fired {} samples after trigger (limit {})".format(
            end_seq_idx - trig_idx, max_cycles))
        pass_flag = False

    # --- Check for forbidden values between trigger and end_seq ---
    scan_end = end_seq_idx if end_seq_idx is not None else min(trig_idx + max_cycles, len(rows) - 1)
    forbidden_hits = []
    for i in range(trig_idx, scan_end + 1):
        v = rows[i]["seq_out"]
        if v in forbidden:
            forbidden_hits.append((rows[i]["sample_idx"], v))

    if forbidden_hits:
        pass_flag = False
        for sample, val in forbidden_hits[:5]:   # print first 5 hits
            print("  FAIL: forbidden value {:08X} at sample {}".format(val, sample))
        if len(forbidden_hits) > 5:
            print("  ... ({} more forbidden hits)".format(len(forbidden_hits) - 5))

    if verbose:
        stop = min(scan_end + 5, len(rows) - 1)
        print("  Full cycle table (sample | busy | end | seq_out):")
        for i in range(trig_idx, stop + 1):
            r = rows[i]
            marker = "<- trig" if i == trig_idx else (
                     "<- end_seq" if i == end_seq_idx else "")
            print("  {:6d} | {} | {} | {:08X}  {}".format(
                r["sample_idx"], r["busy"], r["end_seq"], r["seq_out"], marker))

    if pass_flag:
        print("PASS: {} — no forbidden output, end_seq fired at sample {} ({} samples after trigger)".format(
            test_name,
            rows[end_seq_idx]["sample_idx"] if end_seq_idx is not None else "?",
            (end_seq_idx - trig_idx) if end_seq_idx is not None else "?"))
    else:
        print("FAIL: {}".format(test_name))

    return pass_flag


# ---------------------------------------------------------------------------
# Comparison logic
# ---------------------------------------------------------------------------

def compare_test(test_name, rows, verbose=False):
    """
    Compare one test's captured rows against the expected sequence.

    Returns True on pass, False on fail.
    """
    expected = EXPECTED.get(test_name)
    if expected is None:
        print("SKIP: {} — no expected sequence defined".format(test_name))
        return True

    if not rows:
        print("FAIL: {} — CSV is empty".format(test_name))
        return False

    # --- Locate trigger sample ---
    # First sample where trig_in goes 1 (0->1 edge or sustained 1 at start)
    trig_idx = None
    prev_trig = 0
    for i, r in enumerate(rows):
        if r["trig_in"] == 1 and prev_trig == 0:
            trig_idx = i
            break
        prev_trig = r["trig_in"]

    if trig_idx is None:
        # Fallback: just find any sample with trig_in=1
        for i, r in enumerate(rows):
            if r["trig_in"] == 1:
                trig_idx = i
                break

    if trig_idx is None:
        print("FAIL: {} — sync_cmd_start_seq never asserted in capture".format(test_name))
        return False

    # --- Find first-change, end_sequence, busy ---
    trigger_out = rows[trig_idx]["seq_out"]
    idle_out = trigger_out  # output value at trigger

    first_change_idx = None
    end_seq_idx      = None
    busy_idx         = None

    for i in range(trig_idx, len(rows)):
        r = rows[i]
        if busy_idx is None and r["busy"] == 1:
            busy_idx = i
        if first_change_idx is None and r["seq_out"] != idle_out:
            first_change_idx = i
        if end_seq_idx is None and r["end_seq"] == 1:
            end_seq_idx = i
        if end_seq_idx is not None and i > end_seq_idx + 8:
            break

    # --- Latency report ---
    print("--- {} ---".format(test_name))
    if busy_idx is not None:
        print("  trigger -> busy            : {} samples".format(busy_idx - trig_idx))
    else:
        print("  busy: never observed in window")
    if first_change_idx is not None:
        print("  trigger -> first-change    : {} samples".format(first_change_idx - trig_idx))
        if busy_idx is not None:
            print("  busy -> first-change       : {} samples".format(
                first_change_idx - busy_idx))
    else:
        print("  first-output-change: never observed")
    if end_seq_idx is not None:
        if busy_idx is not None:
            print("  busy -> end_sequence       : {} samples".format(
                end_seq_idx - busy_idx))
        if first_change_idx is not None:
            print("  first-change -> end_seq    : {} samples".format(
                end_seq_idx - first_change_idx))
    else:
        print("  end_sequence: never observed in capture window")

    if first_change_idx is None:
        print("FAIL: {} — first-output-change never seen".format(test_name))
        return False

    if end_seq_idx is None:
        print("FAIL: {} — end_sequence never fired in capture window".format(test_name))
        return False

    # --- Build observed sequence from first-change to end_sequence (inclusive) ---
    observed_rows = rows[first_change_idx : end_seq_idx + 1]

    # Collapse consecutive identical seq_out values into (value, count) runs
    observed_runs = []
    for r in observed_rows:
        v = r["seq_out"]
        if observed_runs and observed_runs[-1][0] == v:
            observed_runs[-1] = (v, observed_runs[-1][1] + 1)
        else:
            observed_runs.append((v, 1))

    # --- Compare against expected ---
    pass_flag = True
    diff_lines = []

    n_exp = len(expected)
    n_obs = len(observed_runs)

    for i in range(max(n_exp, n_obs)):
        exp_val, exp_dur = expected[i] if i < n_exp else (None, None)
        obs_val, obs_dur = observed_runs[i] if i < n_obs else (None, None)

        exp_hex = exp_val.upper() if exp_val else "--------"
        obs_hex = "{:08X}".format(obs_val) if obs_val is not None else "--------"
        exp_d   = str(exp_dur) if exp_dur is not None else "-"
        obs_d   = str(obs_dur) if obs_dur is not None else "-"

        match = (exp_val is not None and obs_val is not None and
                 exp_val.upper() == obs_hex and exp_dur == obs_dur)
        status = "OK" if match else "FAIL"
        if not match:
            pass_flag = False
        diff_lines.append("  [{:2d}] exp={} x{:>4}   obs={} x{:>4}   {}".format(
            i, exp_hex, exp_d, obs_hex, obs_d, status))

    if verbose or not pass_flag:
        print("  Segment comparison (value x cycles):")
        for line in diff_lines:
            print(line)

    if verbose:
        # Print full cycle table from trigger to end_seq + a few guard cycles
        stop = min(end_seq_idx + 5, len(rows) - 1)
        print("  Full cycle table (sample | busy | end | seq_out):")
        for i in range(trig_idx, stop + 1):
            r = rows[i]
            marker = "<- trig" if i == trig_idx else (
                     "<- first-change" if i == first_change_idx else (
                     "<- end_seq" if i == end_seq_idx else ""))
            print("  {:6d} | {} | {} | {:08X}  {}".format(
                r["sample_idx"], r["busy"], r["end_seq"], r["seq_out"], marker))

    if pass_flag:
        print("PASS: {}".format(test_name))
    else:
        print("FAIL: {}".format(test_name))

    return pass_flag


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--indir", default=os.path.join(os.path.dirname(__file__), "REB_v5", "hw_data"),
                   help="Input directory containing CSV files (default: ./REB_v5/hw_data)")
    p.add_argument("--tests", default=None,
                   help="Comma-separated list of tests to compare (default: all)")
    p.add_argument("--verbose", action="store_true",
                   help="Print full cycle tables even on PASS")
    return p.parse_args()


def main():
    args = parse_args()

    if args.tests:
        test_names = [t.strip() for t in args.tests.split(",")]
    else:
        test_names = ALL_TEST_NAMES

    all_pass = True
    results = []

    for name in test_names:
        csv_path = os.path.join(args.indir, name + ".csv")
        if not os.path.exists(csv_path):
            print("SKIP: {} — CSV not found: {}".format(name, csv_path))
            results.append((name, None))
            continue

        try:
            rows = load_csv(csv_path)
        except Exception as e:
            print("FAIL: {} — error parsing CSV: {}".format(name, e))
            all_pass = False
            results.append((name, False))
            continue

        if name in HANG_TESTS:
            ok = compare_hang_test(name, rows, verbose=args.verbose)
        elif name in NEGATIVE_TESTS:
            ok = compare_negative_test(name, rows, verbose=args.verbose)
        else:
            ok = compare_test(name, rows, verbose=args.verbose)
        results.append((name, ok))
        if not ok:
            all_pass = False

    # Summary
    print("")
    print("=" * 50)
    print("SUMMARY")
    print("=" * 50)
    for name, ok in results:
        if ok is None:
            status = "SKIP"
        elif ok:
            status = "PASS"
        else:
            status = "FAIL"
        print("  {:8s}  {}".format(name, status))

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
