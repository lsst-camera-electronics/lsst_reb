#!/usr/bin/env python3
"""
hw_capture.py — Phase 3/5/6c hardware ILA capture for REB_v5 sequencer characterisation.

For the capturable tests (T01–T21, T25a, T26–T29, excluding T14/T15 hang,
T22/T23/T24/T30/T31 sim-only, and T25b),
this script generates a Vivado batch Tcl
file that triggers and captures the ILA.  T14, T15 are captured as hang tests
(busy=1, end_seq never fires).  T22 is EXCLUDED: its three phases cannot be
isolated by a single ILA arm (Phase A/B have no end_sequence; Phase C requires
a third trigger).
  1. Opens the hardware manager and connects to the hw_server.
  2. Configures the ILA (u_ila_0) to trigger on sync_cmd_start_seq rising edge.
  3. Arms the ILA.
  4. Resets the sequencer FSM (rms_reset <partition> -a) before loading memory.
  5. Loads memory via rms_write (called from Tcl via exec).
  6. Fires the sequencer trigger (scs_editor <partition>, stdin = "trigger 0").
  7. Waits for ILA capture to complete.
  8. Exports the captured data as a CSV.
  9. Resets the sequencer FSM again (post-capture cleanup).
 10. Closes the hardware target and disconnects.

T25b is NOT capturable: it uses reg_cmd_start (register write to 0x340000), which
does not assert sync_cmd_start_seq, so the ILA trigger never fires.  T25b is marked
sim-only for hardware comparison.

Usage:
    python3 hw_capture.py --partition <name> [--outdir DIR] [--tests T01,T02,...] [--dry-run]

Options:
    --outdir DIR        Directory for CSV output (default: ./hw_data)
    --tests T01,...     Comma-separated list of tests to run (default: all)
    --dry-run           Generate Tcl files and print them, but do not invoke Vivado.

Requirements (on hardware host):
    - vivado in PATH
    - rms_write, rms_read, rms_reset, scs_editor in PATH or at
      the location specified by TOOL_PREFIX below
    - Vivado hw_server running on rddev101:3121
    - debug_nets.ltx at the path defined in LTX_FILE below

Probe names (from debug_nets.ltx):
    U_REB_v5/sync_cmd_start_seq   — 1-bit trigger
    U_REB_v5/sequencer_busy       — 1-bit (sequencer 0)
    U_REB_v5/end_sequence         — 1-bit (sequencer 0)
    U_REB_v5/sequencer_out_slv    — 32-bit bus

ILA instance: u_ila_0
ILA depth:    32768 samples at 100 MHz = 327.68 us
Trigger position: 3276 samples (10%) — leaves ~29k cycles post-trigger.

Each test resets the sequencer FSM before loading memory (so a hung FSM from
a previous test cannot interfere) and again after capture (so the board is
left in a clean state).  This makes every test idempotent with respect to
sequencer state.
"""

import argparse
import os
import subprocess
import sys
import tempfile

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

HW_SERVER   = "rddev101:3121"
PROBE_PREFIX = "U_REB_v5"
DAQ_PARTITION = None      # set by --partition CLI argument (required)
LTX_FILE    = "/home/jgt/reb_firmware/REB_v5/build/REB_v5/REB_v5_project.runs/impl_1/debug_nets.ltx"
ILA_DEPTH   = 32768
TRIG_POS    = 3276        # 10% of depth
ILA_TIMEOUT = 30          # seconds; Vivado wait_on_hw_ila timeout

# Tool path prefix.  If tools are in PATH, set to "".  Otherwise set to the
# directory containing rms_write etc. (with trailing slash).
TOOL_PREFIX = ""          # e.g. "/opt/lsst/daq-sdk/R5-gregg/x86/bin/"
RMS_WRITE   = TOOL_PREFIX + "rms_write"
RMS_RESET   = TOOL_PREFIX + "rms_reset"
SCS_EDITOR  = TOOL_PREFIX + "scs_editor"

# ---------------------------------------------------------------------------
# Memory write helpers — produce Tcl 'exec rms_write gregg <addr> <val>' lines
# ---------------------------------------------------------------------------

def rw(addr, val):
    """Single rms_write call.  addr and val are integers."""
    return f"exec {RMS_WRITE} {DAQ_PARTITION} {addr:#010x} {val:#010x}"

def rw_burst(base_addr, values):
    """
    Sequence of rms_write calls for a list of (offset, value) pairs.
    offset is added to base_addr.
    """
    lines = []
    for offset, val in values:
        lines.append(rw(base_addr + offset, val))
    return lines

# Memory base addresses (hardware = tb_sequencer.vhd addresses)
OUT_MEM_BASE         = 0x100000
TIME_MEM_BASE        = 0x200000
PROG_MEM_BASE        = 0x300000
IND_FUNC_MEM_BASE    = 0x350000
IND_REP_MEM_BASE     = 0x360000
IND_SUB_ADD_MEM_BASE = 0x370000
IND_SUB_REP_MEM_BASE = 0x380000


def write_out_mem(row, val):
    return rw(OUT_MEM_BASE + row, val)

def write_time_mem(row, val):
    # time_mem is 16-bit; hardware register is 32-bit, upper half zero
    return rw(TIME_MEM_BASE + row, val & 0xFFFF)

def write_prog_mem(row, val):
    return rw(PROG_MEM_BASE + row, val)

def write_ind_func_mem(row, val):
    return rw(IND_FUNC_MEM_BASE + row, val & 0xF)

def write_ind_rep_mem(row, val):
    return rw(IND_REP_MEM_BASE + row, val & 0xFFFFFF)

def write_ind_sub_add_mem(row, val):
    return rw(IND_SUB_ADD_MEM_BASE + row, val & 0x3FF)

def write_ind_sub_rep_mem(row, val):
    return rw(IND_SUB_REP_MEM_BASE + row, val & 0xFFFF)


# ---------------------------------------------------------------------------
# F0 loader
# ---------------------------------------------------------------------------

def load_f0(t0, t1, v0, v1):
    """Standard F0: 2 slices, sentinel at row 2."""
    return [
        write_out_mem (0x00, v0),
        write_out_mem (0x01, v1),
        write_time_mem(0x00, t0),
        write_time_mem(0x01, t1),
        write_time_mem(0x02, 0x0000),
    ]

# Standard F0 parameters used by most tests
F0_T0 = 0x0003
F0_T1 = 0x0003
F0_V0 = 0x00000001
F0_V1 = 0x00000002

def std_f0():
    return load_f0(F0_T0, F0_T1, F0_V0, F0_V1)


# ---------------------------------------------------------------------------
# Function loaders (mirror tb_sequencer.vhd procedures)
# ---------------------------------------------------------------------------

def load_fn2(n, t0, t1, v0, v1):
    base = n * 16
    return [
        write_out_mem (base + 0, v0),
        write_out_mem (base + 1, v1),
        write_time_mem(base + 0, t0),
        write_time_mem(base + 1, t1),
        write_time_mem(base + 2, 0x0000),
    ]

def load_fn3(n, t0, t1, t2, v0, v1, v2):
    base = n * 16
    return [
        write_out_mem (base + 0, v0),
        write_out_mem (base + 1, v1),
        write_out_mem (base + 2, v2),
        write_time_mem(base + 0, t0),
        write_time_mem(base + 1, t1),
        write_time_mem(base + 2, t2),
        write_time_mem(base + 3, 0x0000),
    ]

def load_fn4(n, t0, t1, t2, t3, v0, v1, v2, v3):
    base = n * 16
    return [
        write_out_mem (base + 0, v0),
        write_out_mem (base + 1, v1),
        write_out_mem (base + 2, v2),
        write_out_mem (base + 3, v3),
        write_time_mem(base + 0, t0),
        write_time_mem(base + 1, t1),
        write_time_mem(base + 2, t2),
        write_time_mem(base + 3, t3),
        write_time_mem(base + 4, 0x0000),
    ]

def load_fn1(n, t0, v0):
    """Single-slice function (hang-producing; used by T14, not run here)."""
    base = n * 16
    return [
        write_out_mem (base + 0, v0),
        write_time_mem(base + 0, t0),
        write_time_mem(base + 1, 0x0000),
    ]


# ---------------------------------------------------------------------------
# Test definitions
#
# Each test is a dict:
#   name  : str
#   desc  : str
#   mem   : list of Tcl rms_write lines (memory setup)
#
# All tests issue rms_reset after mem, then "trigger 0" via scs_editor.
# ---------------------------------------------------------------------------

TESTS = []

# T01 -------------------------------------------------------------------
def _t01():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(1, 0xF0000000),   # end_sequence
    ]
    return mem

TESTS.append({
    "name": "T01",
    "desc": "func_call(F1,rep=1) 2-slice [Phase 1a regression]",
    "mem": _t01(),
})

# T02 -------------------------------------------------------------------
def _t02():
    mem = []
    mem += std_f0()
    mem += load_fn3(1, 0x0003, 0x0006, 0x0005, 0x000000AA, 0x000000BB, 0x000000CC)
    mem += [
        write_prog_mem(0, 0x11000001),
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T02",
    "desc": "func_call(F1,rep=1) 3-slice [middle=time_mem[i]]",
    "mem": _t02(),
})

# T03 -------------------------------------------------------------------
def _t03():
    mem = []
    mem += std_f0()
    mem += load_fn4(1, 0x0003, 0x0004, 0x0005, 0x0006,
                       0x000000AA, 0x000000BB, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x11000001),
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T03",
    "desc": "func_call(F1,rep=1) 4-slice [two middle slices]",
    "mem": _t03(),
})

# T04 -------------------------------------------------------------------
def _t04():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x11000003),   # func_call(F1,rep=3)
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T04",
    "desc": "func_call(F1,rep=3) 2-slice [repetition counter]",
    "mem": _t04(),
})

# T05 -------------------------------------------------------------------
def _t05():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += load_fn2(2, 0x0004, 0x0004, 0x000000EE, 0x000000FF)
    mem += [
        write_prog_mem(0, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(1, 0x12000000),   # func_call(F2,rep=0) — skipped
        write_prog_mem(2, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T05",
    "desc": "func_call(F1)+func_call(F2,rep=0)+end_seq [rep=0 skip]",
    "mem": _t05(),
})

# T06 -------------------------------------------------------------------
def _t06():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_ind_func_mem(2, 0x1),      # ind_func_mem[2] = func_id=1
        write_prog_mem(0, 0x22000001),   # ind_func_call slot=2, rep=1
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T06",
    "desc": "ind_func_call slot=2->F1 [indirect func_id]",
    "mem": _t06(),
})

# T07 -------------------------------------------------------------------
def _t07():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_ind_rep_mem(4, 0x000002),  # ind_rep_mem[4] = rep=2
        write_prog_mem(0, 0x31000004),   # ind_rep_call func_id=1, slot=4
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T07",
    "desc": "ind_rep_call F1 slot=4->rep=2 [indirect rep]",
    "mem": _t07(),
})

# T08 -------------------------------------------------------------------
def _t08():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_ind_func_mem(3, 0x1),      # ind_func_mem[3] = func_id=1
        write_ind_rep_mem (5, 0x000001), # ind_rep_mem[5]  = rep=1
        write_prog_mem(0, 0x43000005),   # ind_all_call func_slot=3, rep_slot=5
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T08",
    "desc": "ind_all_call slot=3->F1 slot=5->rep=1 [both indirect]",
    "mem": _t08(),
})

# T09 -------------------------------------------------------------------
def _t09():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x50020001),   # jump_to_add(addr=2, rep=1)
        write_prog_mem(1, 0xF0000000),
        write_prog_mem(2, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(3, 0xE0000001),   # sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T09",
    "desc": "jump_to_add 1-level rep=1 [basic subroutine]",
    "mem": _t09(),
})

# T10 -------------------------------------------------------------------
def _t10():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x50020002),   # jump_to_add(addr=2, rep=2)
        write_prog_mem(1, 0xF0000000),
        write_prog_mem(2, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(3, 0xE0000002),   # sub_trailer(rep=2)
    ]
    return mem

TESTS.append({
    "name": "T10",
    "desc": "jump_to_add 1-level rep=2 [subroutine repeats]",
    "mem": _t10(),
})

# T10b ------------------------------------------------------------------
def _t10b():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x50040001),   # jump_to_add(addr=4, rep=1)
        write_prog_mem(1, 0xF0000000),
        write_prog_mem(2, 0x00000000),   # unused
        write_prog_mem(3, 0x00000000),   # unused
        write_prog_mem(4, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(5, 0xE0000001),   # sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T10b",
    "desc": "jump_to_add 1-level addr=4 [non-adjacent body]",
    "mem": _t10b(),
})

# T11 -------------------------------------------------------------------
def _t11():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += load_fn2(2, 0x0003, 0x0005, 0x000000EE, 0x000000FF)
    mem += [
        write_prog_mem(0, 0x50040001),   # outer jump to addr=4, rep=1
        write_prog_mem(1, 0xF0000000),
        write_prog_mem(4, 0x50060001),   # inner jump to addr=6, rep=1
        write_prog_mem(5, 0xE0000001),   # outer sub_trailer(rep=1)
        write_prog_mem(6, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(7, 0x12000001),   # func_call(F2,rep=1)
        write_prog_mem(8, 0xE0000001),   # inner sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T11",
    "desc": "jump_to_add 2-level nesting, 2 func_calls in inner body [DISC-004]",
    "mem": _t11(),
})

# T12 -------------------------------------------------------------------
def _t12():
    mem = []
    mem += load_f0(0x0004, 0x0006, 0x00000100, 0x00000200)
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x11000001),
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T12",
    "desc": "non-trivial F0 times t0=4 t1=6 [5+8 cycle durations]",
    "mem": _t12(),
})

# T13 -------------------------------------------------------------------
def _t13():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0001, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x11000001),
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T13",
    "desc": "minimum-t1 2-slice F1 [last-slice boundary t1=1]",
    "mem": _t13(),
})

# T14 -------------------------------------------------------------------
def _t14():
    mem = []
    mem += std_f0()
    mem += load_fn1(1, 0x0005, 0x000000CC)   # single-slice: time_mem[0x11]=0 (hang)
    mem += [
        write_prog_mem(0, 0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(1, 0xF0000000),   # end_sequence (never reached)
    ]
    return mem

TESTS.append({
    "name": "T14",
    "desc": "single-slice function hang [DISC-003]",
    "mem": _t14(),
})

# T15 -------------------------------------------------------------------
def _t15():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x50040001),   # outer jump_to_add(addr=4, rep=1)
        write_prog_mem(1, 0xF0000000),   # end_sequence (never reached)
        write_prog_mem(2, 0x00000000),   # explicit zero (idempotency)
        write_prog_mem(3, 0x00000000),   # explicit zero (idempotency)
        write_prog_mem(4, 0x50060001),   # inner jump_to_add(addr=6, rep=1)
        write_prog_mem(5, 0xE0000001),   # outer sub_trailer(rep=1)
        write_prog_mem(6, 0x11000001),   # func_call(F1,rep=1) — only 1, causes hang
        write_prog_mem(7, 0xE0000001),   # inner sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T15",
    "desc": "2-level nesting 1-func_call inner body hang [DISC-004]",
    "mem": _t15(),
})

# T16 -------------------------------------------------------------------
def _t16():
    mem = []
    # F0: to_slv32(ABCD1234) = 0x80011234, to_slv32(DEAD5678) = 0x80015678
    mem += load_f0(F0_T0, F0_T1, 0xABCD1234, 0xDEAD5678)
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0, 0x11000001),
        write_prog_mem(1, 0xF0000000),
    ]
    return mem

TESTS.append({
    "name": "T16",
    "desc": "multi-bit transition glitch [DISC-005]",
    "mem": _t16(),
})

# T17 -------------------------------------------------------------------
def _t17():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_ind_sub_add_mem(2, 4),        # ind_sub_add_mem[2] = addr 4
        write_prog_mem(0, 0x60020001),      # ind_add_jump slot=2, rep=1
        write_prog_mem(1, 0xF0000000),      # end_sequence
        write_prog_mem(4, 0x11000001),      # func_call(F1,rep=1)
        write_prog_mem(5, 0xE0000001),      # sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T17",
    "desc": "ind_add_jump slot=2->addr=4 rep=1 [indirect sub address]",
    "mem": _t17(),
})

# T18 -------------------------------------------------------------------
def _t18():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_ind_sub_rep_mem(3, 2),        # ind_sub_rep_mem[3] = 2 (run twice)
        write_prog_mem(0, 0x70040003),      # ind_rep_jump addr=4, slot=3
        write_prog_mem(1, 0xF0000000),      # end_sequence
        write_prog_mem(4, 0x11000001),      # func_call(F1,rep=1)
        write_prog_mem(5, 0xE0000001),      # sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T18",
    "desc": "ind_rep_jump addr=4 slot=3->rep=2 [indirect sub rep, twice]",
    "mem": _t18(),
})

# T19 -------------------------------------------------------------------
def _t19():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_ind_sub_add_mem(2, 4),        # ind_sub_add_mem[2] = addr 4
        write_ind_sub_rep_mem(5, 2),        # ind_sub_rep_mem[5] = 2 (run twice)
        write_prog_mem(0, 0x80020005),      # ind_all_jump addr_slot=2, rep_slot=5
        write_prog_mem(1, 0xF0000000),      # end_sequence
        write_prog_mem(4, 0x11000001),      # func_call(F1,rep=1)
        write_prog_mem(5, 0xE0000001),      # sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T19",
    "desc": "ind_all_jump addr_slot=2->4 rep_slot=5->2 [both indirect]",
    "mem": _t19(),
})

# T20 -------------------------------------------------------------------
def _t20():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += load_fn2(2, 0x0003, 0x0005, 0x000000EE, 0x000000FF)
    mem += [
        write_prog_mem(0,    0x50080001),   # level-1 jump to addr=8, rep=1
        write_prog_mem(1,    0xF0000000),   # end_sequence
        write_prog_mem(8,    0x500A0001),   # level-2 jump to addr=10, rep=1
        write_prog_mem(9,    0xE0000001),   # level-1 sub_trailer(rep=1)
        write_prog_mem(0xA,  0x500C0001),   # level-3 jump to addr=12, rep=1
        write_prog_mem(0xB,  0xE0000001),   # level-2 sub_trailer(rep=1)
        write_prog_mem(0xC,  0x11000001),   # func_call(F1,rep=1) innermost
        write_prog_mem(0xD,  0x12000001),   # func_call(F2,rep=1) innermost
        write_prog_mem(0xE,  0xE0000001),   # level-3 sub_trailer(rep=1)
    ]
    return mem

TESTS.append({
    "name": "T20",
    "desc": "jump_to_add 3-level nesting [3 nested subroutines]",
    "mem": _t20(),
})

# T21 -------------------------------------------------------------------
def _t21():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)
    mem += [
        write_prog_mem(0,  0x50020001),   # jump_to_add(addr=2, rep=1)
        write_prog_mem(1,  0xF0000000),   # end_sequence
        write_prog_mem(2,  0x11000001),   # func_call(F1,rep=1)
        write_prog_mem(3,  0xE000FFFF),   # sub_trailer(bits[15:0]=0xFFFF, don't-care)
    ]
    return mem

TESTS.append({
    "name": "T21",
    "desc": "sub_trailer bits[15:0]=0xFFFF don't-care [DISC-006]",
    "mem": _t21(),
})

# T25a ------------------------------------------------------------------
# T25b is NOT capturable: it uses reg_cmd_start (rms_write 0x340000) which
# does not assert sync_cmd_start_seq, so the ILA never triggers.
def _t25a():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)   # F1 (intended start)
    mem += load_fn2(2, 0x0003, 0x0005, 0x000000EE, 0x000000FF)   # F2 guard
    mem += [
        write_prog_mem(0, 0x12000001),   # [0] func_call(F2,rep=1) guard — skipped
        write_prog_mem(1, 0x12000001),   # [1] guard
        write_prog_mem(2, 0x12000001),   # [2] guard
        write_prog_mem(3, 0x12000001),   # [3] guard
        write_prog_mem(4, 0x11000001),   # [4] func_call(F1,rep=1) <- start at word 4
        write_prog_mem(5, 0xF0000000),   # [5] end_sequence
    ]
    return mem

TESTS.append({
    "name": "T25a",
    "desc": "sync non-zero start addr main_addr=1 -> prog_mem word 4",
    "mem": _t25a(),
    "trigger": 1,   # scs_editor 'trigger 1' -> sync_cmd_main_addr=1 -> start at word 4
})

# T26 -------------------------------------------------------------------
def _t26():
    mem = []
    mem += std_f0()
    mem += [
        write_ind_sub_rep_mem(6, 0),         # ind_sub_rep_mem[6] = 0 (rep=0 for opcode 0x7)
        write_ind_sub_rep_mem(7, 0),         # ind_sub_rep_mem[7] = 0 (rep=0 for opcode 0x8)
        write_prog_mem(0, 0x50020000),       # jump_to_add(addr=2, rep=0) — skipped
        write_prog_mem(1, 0x60000000),       # ind_add_jump(addr_slot=0, rep=0) — skipped
        write_prog_mem(2, 0x70040006),       # ind_rep_jump(addr=4, rep_slot=6) — skipped (ind_sub_rep[6]=0)
        write_prog_mem(3, 0x80000007),       # ind_all_jump(addr_slot=0, rep_slot=7) — skipped (ind_sub_rep[7]=0)
        write_prog_mem(4, 0xF0000000),       # end_sequence
    ]
    return mem

TESTS.append({
    "name": "T26",
    "desc": "rep=0 skip for sub-jump opcodes 0x5/0x6/0x7/0x8",
    "mem": _t26(),
})

# T27 -------------------------------------------------------------------
def _t27():
    mem = []
    mem += std_f0()
    mem += [
        write_ind_rep_mem(6, 0),             # ind_rep_mem[6] = 0 (rep=0 for opcode 0x3)
        write_ind_rep_mem(7, 0),             # ind_rep_mem[7] = 0 (rep=0 for opcode 0x4)
        write_prog_mem(0, 0x22000000),       # ind_func_call(slot=2, rep=0) — skipped
        write_prog_mem(1, 0x31000006),       # ind_rep_call(func_id=1, rep_slot=6) — skipped (ind_rep[6]=0)
        write_prog_mem(2, 0x43000007),       # ind_all_call(func_slot=3, rep_slot=7) — skipped (ind_rep[7]=0)
        write_prog_mem(3, 0xF0000000),       # end_sequence
    ]
    return mem

TESTS.append({
    "name": "T27",
    "desc": "rep=0 skip for indirect func_call opcodes 0x2/0x3/0x4",
    "mem": _t27(),
})

# T28 -------------------------------------------------------------------
def _t28():
    mem = []
    mem += std_f0()
    # F1 (func_id=1): 16 slices, out_mem rows 0x10..0x1F, time_mem rows 0x10..0x1F + sentinel at 0x20
    for i in range(16):
        mem.append(write_out_mem (0x10 + i, (i + 1) * 0x100))   # 0x100, 0x200, ..., 0x1000
        mem.append(write_time_mem(0x10 + i, 0x0003))
    mem.append(write_time_mem(0x20, 0x0000))                     # sentinel (T22 wrote this to 0x0003)
    mem += [
        write_prog_mem(0, 0x11000001),   # func_call(F1, rep=1)
        write_prog_mem(1, 0xF0000000),   # end_sequence
    ]
    return mem

TESTS.append({
    "name": "T28",
    "desc": "func_call(F1,rep=1) 16-slice function (full function depth)",
    "mem": _t28(),
})

# T29 -------------------------------------------------------------------
def _t29():
    mem = []
    mem += std_f0()
    mem += load_fn2(1, 0x0003, 0x0005, 0x000000CC, 0x000000DD)   # F1
    mem += load_fn2(2, 0x0003, 0x0005, 0x000000EE, 0x000000FF)   # F2
    mem += [
        write_prog_mem(0x00, 0x50080001),   # L1: jump_to_add(addr=8,  rep=1)
        write_prog_mem(0x01, 0xF0000000),   # end_sequence
        write_prog_mem(0x08, 0x500A0001),   # L2: jump_to_add(addr=10, rep=1)
        write_prog_mem(0x09, 0xE0000001),   # L1 sub_trailer
        write_prog_mem(0x0A, 0x500C0001),   # L3: jump_to_add(addr=12, rep=1)
        write_prog_mem(0x0B, 0xE0000001),   # L2 sub_trailer
        write_prog_mem(0x0C, 0x500E0001),   # L4: jump_to_add(addr=14, rep=1)
        write_prog_mem(0x0D, 0xE0000001),   # L3 sub_trailer
        write_prog_mem(0x0E, 0x11000001),   # func_call(F1, rep=1)  } K=3 innermost body
        write_prog_mem(0x0F, 0x12000001),   # func_call(F2, rep=1)  }
        write_prog_mem(0x10, 0x11000001),   # func_call(F1, rep=1)  }
        write_prog_mem(0x11, 0xE0000001),   # L4 sub_trailer
    ]
    return mem

TESTS.append({
    "name": "T29",
    "desc": "4-level nesting K=3 [DISC-008 minimum passing config]",
    "mem": _t29(),
})

# ---------------------------------------------------------------------------
# Tcl script generator
# ---------------------------------------------------------------------------

def make_tcl(test, csv_path):
    """
    Generate a complete Vivado batch Tcl script for one test.

    The script:
      1. Opens hw_manager and connects to hw_server.
      2. Opens the hw_target and programs the probes file.
      3. Configures ILA trigger on sync_cmd_start_seq rising edge.
      4. Arms ILA (run_hw_ila).
      5. Loads memories via exec rms_write (one call per row).
      6. Resets sequencer state via exec rms_reset.
      7. Fires trigger via exec scs_editor.
      8. Waits for capture.
      9. Uploads and exports CSV.
     10. Post-capture reset (always — clears any hung FSM state).
     11. Closes and disconnects.

    Note on F0 raw values: out_mem stores the raw 32-bit word that the
    sequencer writes; the to_slv32 bit-picking happens in hardware/simulation
    identically.  T16 writes 0xABCD1234 and 0xDEAD5678 to out_mem, which is
    what rms_write sends — the hardware picks bits the same way as to_slv32.
    """
    lines = []

    lines.append("# Auto-generated Vivado batch Tcl for {}".format(test["name"]))
    lines.append("# {}".format(test["desc"]))
    lines.append("")
    lines.append("open_hw_manager")
    lines.append("connect_hw_server -url {}".format(HW_SERVER))
    lines.append("open_hw_target")
    lines.append("")
    lines.append("# Associate probes file")
    lines.append("set dev [get_hw_devices]")
    lines.append("set_property PROBES.FILE {{{}}} $dev".format(LTX_FILE))
    lines.append("refresh_hw_device $dev")
    lines.append("")
    lines.append("# Get ILA handle (only one ILA in this design)")
    lines.append("set ila [get_hw_ilas -of_objects $dev]")
    lines.append("")
    lines.append("# Configure trigger: sync_cmd_start_seq rising edge (0->1)")
    lines.append("set_property CONTROL.TRIGGER_CONDITION AND $ila")
    lines.append("set_property CONTROL.TRIGGER_POSITION {} $ila".format(TRIG_POS))
    lines.append("set_property TRIGGER_COMPARE_VALUE eq1'b1 \\")
    lines.append("    [get_hw_probes {}/sync_cmd_start_seq -of_objects $ila]".format(PROBE_PREFIX))
    lines.append("# Capture all 32 bits of sequencer_out_slv, busy, end_sequence")
    lines.append("set_property CONTROL.DATA_DEPTH {} $ila".format(ILA_DEPTH))
    lines.append("")
    lines.append("# Arm ILA")
    lines.append("run_hw_ila $ila")
    lines.append("after 500")
    lines.append("")
    lines.append("# Pre-load reset: clear any hung FSM state from a previous test")
    lines.append("exec {} {} -a".format(RMS_RESET, DAQ_PARTITION))
    lines.append("after 200")
    lines.append("")
    lines.append("# --- Memory load ---")
    for mem_line in test["mem"]:
        lines.append(mem_line)
    lines.append("")
    lines.append("# Fire sequencer trigger (opcode N = prog_mem start address N*4)")
    trigger_idx = test.get("trigger", 0)
    lines.append("exec sh -c {{echo trigger {} | {} {}}}".format(trigger_idx, SCS_EDITOR, DAQ_PARTITION))
    lines.append("")
    lines.append("# Wait for ILA capture to complete")
    lines.append("wait_on_hw_ila -timeout {} $ila".format(ILA_TIMEOUT))
    lines.append("")
    lines.append("# Upload and export CSV")
    lines.append("set idata [upload_hw_ila_data $ila]")
    lines.append("write_hw_ila_data -csv_file -force {{{}}} $idata".format(csv_path))
    lines.append("")
    lines.append("# Post-capture reset: leave sequencer in clean state (required after hang tests)")
    lines.append("exec {} {} -a".format(RMS_RESET, DAQ_PARTITION))
    lines.append("after 200")
    lines.append("")
    lines.append("close_hw_target")
    lines.append("disconnect_hw_server")
    lines.append("puts \"DONE: {} captured to {}\"".format(test["name"], csv_path))

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--partition", required=True,
                   help="DAQ partition name (required)")
    p.add_argument("--outdir", default=os.path.join(os.path.dirname(__file__), "hw_data"),
                   help="Output directory for CSV files (default: ./hw_data)")
    p.add_argument("--tests", default=None,
                   help="Comma-separated list of test names to run (default: all)")
    p.add_argument("--dry-run", action="store_true",
                   help="Print generated Tcl files but do not invoke Vivado")
    p.add_argument("--tcl-dir", default=None,
                   help="Directory for Tcl files (default: temp dir, removed after use)")
    return p.parse_args()


def main():
    global DAQ_PARTITION
    args = parse_args()
    DAQ_PARTITION = args.partition

    # Filter test list
    if args.tests:
        names = {t.strip() for t in args.tests.split(",")}
        run_tests = [t for t in TESTS if t["name"] in names]
        unknown = names - {t["name"] for t in TESTS}
        if unknown:
            print("WARNING: unknown test names: {}".format(", ".join(sorted(unknown))),
                  file=sys.stderr)
    else:
        run_tests = TESTS

    if not run_tests:
        print("No tests to run.", file=sys.stderr)
        sys.exit(1)

    # Create output directory
    os.makedirs(args.outdir, exist_ok=True)

    # Tcl file directory
    use_tmp = args.tcl_dir is None
    tcl_dir = args.tcl_dir if args.tcl_dir else tempfile.mkdtemp(prefix="hw_capture_")

    try:
        for test in run_tests:
            csv_path = os.path.abspath(os.path.join(args.outdir, test["name"] + ".csv"))
            tcl_path = os.path.join(tcl_dir, test["name"] + ".tcl")

            tcl_content = make_tcl(test, csv_path)

            with open(tcl_path, "w") as f:
                f.write(tcl_content)

            if args.dry_run:
                print("=" * 70)
                print("DRY-RUN: {} -> {}".format(tcl_path, csv_path))
                print("-" * 70)
                print(tcl_content)
                continue

            print("Running {} ({})...".format(test["name"], test["desc"]))
            sys.stdout.flush()

            result = subprocess.run(
                ["vivado", "-mode", "batch", "-nolog", "-nojournal", "-source", tcl_path],
                capture_output=True,
                text=True,
            )

            # Print Tcl stdout/stderr for visibility
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(result.stderr, file=sys.stderr)

            if result.returncode != 0:
                print("ERROR: vivado exited with code {} for {}".format(
                    result.returncode, test["name"]), file=sys.stderr)
                print("Tcl file: {}".format(tcl_path))
                sys.exit(result.returncode)

            if os.path.exists(csv_path):
                size = os.path.getsize(csv_path)
                print("  -> {} ({} bytes)".format(csv_path, size))
            else:
                print("WARNING: CSV not found after capture: {}".format(csv_path),
                      file=sys.stderr)

    finally:
        if use_tmp and not args.dry_run:
            import shutil
            shutil.rmtree(tcl_dir, ignore_errors=True)

    if not args.dry_run:
        print("\nAll captures complete.  CSVs in: {}".format(args.outdir))


if __name__ == "__main__":
    main()
