#!/usr/bin/env python3
"""
sim_compare.py — Source-agnostic pairwise CSV comparator for REB_v5 sequencer.

Compares two sets of per-test CSVs cycle-by-cycle.  Either set may be sim
output (from tb_sequencer) or hardware ILA captures (from hw_capture.py /
hw_compare.py).  Both inputs are normalised so that sample_idx = 0 corresponds
to the first post-trigger sample before comparison.

Usage:
    python3 sim_compare.py --a DIR --b DIR [--tests T01,...] [--verbose]

Options:
    --a DIR         First CSV directory (e.g. REB_v5/sim_data)
    --b DIR         Second CSV directory (e.g. REB_v5/hw_data)
    --tests T01,..  Comma-separated list of tests (default: all available)
    --verbose       Print full cycle tables even on PASS

Exit code: 0 if all compared tests match, 1 if any differ or a CSV is missing
from both directories.

CSV formats supported
---------------------
Sim format (produced by tb_sequencer textio):
    sample_idx,busy,end_seq,seq_out
    0,0,0,00000000
    ...
    (sample_idx already trigger-relative, 0-based)

Hardware ILA format (produced by hw_capture.py / Vivado):
    May have comment lines (#...) before the header.
    Column names contain probe hierarchy prefixes.
    A sync_cmd_start_seq column identifies the trigger sample; rows before
    the trigger are discarded and the trigger sample becomes index 0.

The normalisation step ensures both sets use the same 0-based trigger-relative
indexing before comparison.
"""

import argparse
import csv
import os
import sys

# ---------------------------------------------------------------------------
# Canonical test list
# ---------------------------------------------------------------------------

ALL_TEST_NAMES = [
    "T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08",
    "T09", "T10", "T10b", "T11", "T12", "T13", "T14", "T15", "T16",
]

HANG_TESTS = {"T14", "T15"}

# ---------------------------------------------------------------------------
# Sim-format CSV parser (4-column, trigger-relative already)
# ---------------------------------------------------------------------------

def _parse_sim_csv(path):
    """
    Parse a sim CSV (sample_idx,busy,end_seq,seq_out).
    Returns list of dicts with keys: sample_idx, busy, end_seq, seq_out.
    Already trigger-relative; no trigger search needed.
    """
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "sample_idx": int(row["sample_idx"]),
                "busy":       int(row["busy"]),
                "end_seq":    int(row["end_seq"]),
                "seq_out":    int(row["seq_out"], 16),
            })
    rows.sort(key=lambda r: r["sample_idx"])
    return rows


# ---------------------------------------------------------------------------
# Hardware ILA CSV parser (re-used from hw_compare.py logic)
# ---------------------------------------------------------------------------

def _parse_bus_value(s):
    s = s.strip()
    if s.startswith("0x") or s.startswith("0X"):
        return int(s, 16)
    if s.startswith("0b") or s.startswith("0B"):
        return int(s, 2)
    try:
        return int(s, 16)
    except ValueError:
        pass
    return int(s)


def _parse_hw_csv(path):
    """
    Parse a Vivado ILA CSV.
    Returns list of dicts with keys: sample_idx, busy, end_seq, seq_out, trig_in.
    Rows are sorted by sample_idx.
    """
    rows = []

    with open(path, newline="") as f:
        raw = f.read()

    lines = raw.splitlines()

    # Find first non-comment, non-blank line (header)
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
        if row[0].strip().startswith("Radix"):
            continue
        while len(row) < len(headers):
            row.append("0")

        def get(candidates):
            for cand in candidates:
                cl = cand.lower()
                for i, h in enumerate(headers):
                    if cl in h.lower():
                        return row[i].strip()
            return None

        s = get(["Sample in Buffer", "sample"])
        sample_idx = int(s) if (s is not None and s.lstrip("-").isdigit()) else len(rows)

        out_val = None
        for i, h in enumerate(headers):
            hl = h.lower()
            if "out_slv" in hl:
                v = row[i].strip()
                if "[31:0]" in hl or (v and not (len(v) == 1 and v in "01")):
                    try:
                        out_val = _parse_bus_value(v)
                    except (ValueError, TypeError):
                        out_val = None
                    break

        if out_val is None:
            acc = 0
            found = False
            for bit in range(32):
                for i, h in enumerate(headers):
                    if "out_slv[{}]".format(bit) in h.lower():
                        v = row[i].strip()
                        if v in ("1", "1'b1", "H"):
                            acc |= (1 << bit)
                        found = True
                        break
            out_val = acc if found else 0

        busy_v  = get(["sequencer_busy[0]", "sequencer_busy"])
        busy    = 1 if busy_v and busy_v in ("1", "1'b1", "H") else 0

        end_v   = get(["end_sequence[0]", "end_sequence"])
        end_val = 1 if end_v and end_v in ("1", "1'b1", "H") else 0

        trig_v  = get(["sync_cmd_start_seq"])
        trig_val = 1 if trig_v and trig_v in ("1", "1'b1", "H") else 0

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
# Probe whether a CSV is sim or hw format
# ---------------------------------------------------------------------------

def _is_sim_csv(path):
    """Return True if the first non-comment, non-blank line looks like a sim header."""
    with open(path) as f:
        for line in f:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                return stripped.lower() == "sample_idx,busy,end_seq,seq_out"
    return False


# ---------------------------------------------------------------------------
# Normalise: trim to trigger-relative 0-based indexing
# ---------------------------------------------------------------------------

def _normalise(rows, path):
    """
    Given parsed rows (may or may not have trig_in key), return a new list
    with sample_idx rewritten so that the first post-trigger sample is 0.

    For sim CSVs: already 0-based, no change needed (pass through).
    For hw CSVs: find trigger edge, discard pre-trigger rows, rebase.

    Returns (normalised_rows, error_string_or_None).
    """
    if "trig_in" not in rows[0]:
        # Sim format — already normalised
        return rows, None

    # HW format — find trigger 0->1 edge
    trig_row_idx = None
    prev = 0
    for i, r in enumerate(rows):
        if r["trig_in"] == 1 and prev == 0:
            trig_row_idx = i
            break
        prev = r["trig_in"]

    if trig_row_idx is None:
        for i, r in enumerate(rows):
            if r["trig_in"] == 1:
                trig_row_idx = i
                break

    if trig_row_idx is None:
        return rows, "sync_cmd_start_seq never asserted in {}".format(path)

    # The sample at trig_row_idx is the trigger cycle itself.
    # Post-trigger rows start at trig_row_idx + 1, which becomes index 0.
    post = rows[trig_row_idx + 1:]
    if not post:
        post = rows[trig_row_idx:]

    base = post[0]["sample_idx"]
    normalised = []
    for r in post:
        nr = dict(r)
        nr["sample_idx"] = r["sample_idx"] - base
        normalised.append(nr)
    return normalised, None


# ---------------------------------------------------------------------------
# Load a CSV from a directory, auto-detecting format
# ---------------------------------------------------------------------------

def load_test_csv(directory, test_name):
    """
    Load one test's CSV from directory.
    Returns (rows_normalised, error_string_or_None).
    rows_normalised is a list of dicts with at minimum:
        sample_idx (int, 0-based trigger-relative)
        busy       (int 0/1)
        end_seq    (int 0/1)
        seq_out    (int)
    """
    path = os.path.join(directory, test_name + ".csv")
    if not os.path.exists(path):
        return None, "CSV not found: {}".format(path)

    try:
        if _is_sim_csv(path):
            rows = _parse_sim_csv(path)
        else:
            rows = _parse_hw_csv(path)
    except Exception as e:
        return None, "parse error in {}: {}".format(path, e)

    if not rows:
        return None, "CSV is empty: {}".format(path)

    rows, err = _normalise(rows, path)
    if err:
        return None, err

    return rows, None


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

def compare_test(test_name, rows_a, rows_b, label_a, label_b, verbose=False):
    """
    Cycle-exact comparison of two normalised row sets.
    Returns True if all cycles match on busy, end_seq, seq_out.
    """
    # Build index-keyed dicts
    idx_a = {r["sample_idx"]: r for r in rows_a}
    idx_b = {r["sample_idx"]: r for r in rows_b}

    all_idx = sorted(set(idx_a) | set(idx_b))

    mismatches = []
    for idx in all_idx:
        ra = idx_a.get(idx)
        rb = idx_b.get(idx)

        if ra is None:
            mismatches.append((idx, "only in {}".format(label_b),
                               None, rb["busy"], rb["end_seq"], rb["seq_out"],
                               None, None, None))
            continue
        if rb is None:
            mismatches.append((idx, "only in {}".format(label_a),
                               ra["busy"], ra["end_seq"], ra["seq_out"],
                               None, None, None))
            continue

        diff = []
        if ra["busy"]    != rb["busy"]:    diff.append("busy")
        if ra["end_seq"] != rb["end_seq"]: diff.append("end_seq")
        if ra["seq_out"] != rb["seq_out"]: diff.append("seq_out")

        if diff:
            mismatches.append((idx, "differ: " + ",".join(diff),
                               ra["busy"], ra["end_seq"], ra["seq_out"],
                               rb["busy"], rb["end_seq"], rb["seq_out"]))

    pass_flag = len(mismatches) == 0
    n_cycles = len(all_idx)

    if verbose or not pass_flag:
        print("--- {} ({} vs {}) ---".format(test_name, label_a, label_b))
        print("  cycles compared: {}".format(n_cycles))

    if verbose and pass_flag:
        print("  All {} cycles match.".format(n_cycles))

    if not pass_flag:
        hdr = "  {:>6}  {:>8}  {:>8}  {:>8}    {:>8}  {:>8}  {:>8}  note".format(
            "idx",
            label_a[:8] + "_b", label_a[:8] + "_e", label_a[:8] + "_o",
            label_b[:8] + "_b", label_b[:8] + "_e", label_b[:8] + "_o",
        )
        print("  {:>6}  {:<8} {:<8} {:<8}    {:<8} {:<8} {:<8}  note".format(
            "idx",
            "A:busy", "A:end", "A:out",
            "B:busy", "B:end", "B:out",
        ))
        for m in mismatches[:40]:
            idx, note = m[0], m[1]
            a_b = "-" if m[2] is None else str(m[2])
            a_e = "-" if m[3] is None else str(m[3])
            a_o = "-" if m[4] is None else "{:08X}".format(m[4])
            b_b = "-" if m[5] is None else str(m[5])
            b_e = "-" if m[6] is None else str(m[6])
            b_o = "-" if m[7] is None else "{:08X}".format(m[7])
            print("  {:>6}  {:<8} {:<8} {:<8}    {:<8} {:<8} {:<8}  {}".format(
                idx, a_b, a_e, a_o, b_b, b_e, b_o, note))
        if len(mismatches) > 40:
            print("  ... ({} more mismatches)".format(len(mismatches) - 40))

    if pass_flag:
        print("PASS: {} ({} cycles match)".format(test_name, n_cycles))
    else:
        print("FAIL: {} ({}/{} cycles differ)".format(
            test_name, len(mismatches), n_cycles))

    return pass_flag


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--a", required=True, metavar="DIR",
                   help="First CSV directory")
    p.add_argument("--b", required=True, metavar="DIR",
                   help="Second CSV directory")
    p.add_argument("--tests", default=None,
                   help="Comma-separated test names (default: all found in both dirs)")
    p.add_argument("--verbose", action="store_true",
                   help="Print full cycle tables even on PASS")
    return p.parse_args()


def _available_tests(dir_a, dir_b):
    """Return sorted list of test names present in at least one directory."""
    found = set()
    for d in (dir_a, dir_b):
        for name in ALL_TEST_NAMES:
            if os.path.exists(os.path.join(d, name + ".csv")):
                found.add(name)
    return [t for t in ALL_TEST_NAMES if t in found]


def main():
    args = parse_args()

    dir_a = args.a
    dir_b = args.b
    label_a = os.path.basename(os.path.normpath(dir_a))
    label_b = os.path.basename(os.path.normpath(dir_b))

    if args.tests:
        test_names = [t.strip() for t in args.tests.split(",")]
    else:
        test_names = _available_tests(dir_a, dir_b)

    if not test_names:
        print("No CSVs found in {} or {}".format(dir_a, dir_b))
        sys.exit(1)

    all_pass = True
    results = []

    for name in test_names:
        rows_a, err_a = load_test_csv(dir_a, name)
        rows_b, err_b = load_test_csv(dir_b, name)

        if rows_a is None and rows_b is None:
            print("SKIP: {} — missing from both directories".format(name))
            results.append((name, None))
            continue

        if rows_a is None:
            print("FAIL: {} — {} missing or unreadable: {}".format(name, label_a, err_a))
            all_pass = False
            results.append((name, False))
            continue

        if rows_b is None:
            print("FAIL: {} — {} missing or unreadable: {}".format(name, label_b, err_b))
            all_pass = False
            results.append((name, False))
            continue

        ok = compare_test(name, rows_a, rows_b, label_a, label_b, verbose=args.verbose)
        results.append((name, ok))
        if not ok:
            all_pass = False

    print("")
    print("=" * 50)
    print("SUMMARY  ({} vs {})".format(label_a, label_b))
    print("=" * 50)
    for name, ok in results:
        status = "SKIP" if ok is None else ("PASS" if ok else "FAIL")
        print("  {:8s}  {}".format(name, status))

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
