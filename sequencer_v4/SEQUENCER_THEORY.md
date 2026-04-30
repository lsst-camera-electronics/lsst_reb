# Sequencer Theory of Operation

Reference document for the `sequencer_v4` pattern generator used in REB_v5, GREB_v2, and WREB_v4.
Captures the timing contract, architectural details, and verification principles established during
simulation and hardware work.

---

## Source key

Claims in this document are tagged with one or more of the following sources:

| Tag   | Meaning |
|-------|---------|
| `[doc]` | User manual: *The LSST REB 5 firmware – User manual*, LCA-XXXXX, Draft 1, 2016 |
| `[rtl]` | Code inspection of `lsst_reb` (primarily at `cc9fb85`; fix at `f875887`) |
| `[sim]` | Simulation (xsim, workspace `~/reb_firmware/sequencer_tb/`) |
| `[hw]`  | Hardware measurement on physical REB_v5 |

Where sources disagree, the discrepancy is recorded in the **Discrepancies** section.

---

## Clock note

All timing values in this document are expressed in **clock cycles**. The sequencer is
synchronous and all behaviour is cycle-exact. The mapping to wall-clock time depends on the
system clock frequency in use:

- 100 MHz → 1 cycle = 10 ns
- 156.25 MHz → 1 cycle ≈ 6.4 ns

The original user manual was written assuming 100 MHz only and expresses all timings in
nanoseconds. This document converts those values to cycles throughout.

---

## 1. Introduction

### What the sequencer is

The sequencer is a **pattern generator**. It drives up to 32 output signals (CCD parallel clocks,
serial clocks, ASPIC control signals, ADC trigger, and auxiliary signals) according to a stored
program. It has no knowledge of CCD physics or readout duration. Its sole job is to produce the
correct output value on the correct cycle. `[doc][rtl]`

### Major functional blocks

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                  sequencer_parameter_extractor_top_v4               │
  │                                                                     │
  │  prog_mem ──┐                                                       │
  │             ├──► parameter_extractor_fsm_v3 ──► seq_param_fifo ──►  │──► fifo_param_out
  │  ind_*_mem ─┘          (resolve indirect           (32-entry        │
  │                          operands)                  block-RAM FIFO) │
  └─────────────────────────────────────────────────────────────────────┘
                                                              │
                                                    fifo_param_out (32 bits)
                                                    [31:28] prog_end_opcode
                                                    [27:24] func_id
                                                    [23]    inf_loop
                                                    [22:0]  rep_count
                                                              │
  ┌───────────────────────────────────────────────────────────▼─────────┐
  │                        function_v3_top                              │
  │                                                                     │
  │  ┌─────────────────────┐    func_start   ┌──────────────────────┐   │
  │  │ function_executor_v3│ ──────────────► │     function_v3      │   │
  │  │                     │ ◄────────────── │  (function_fsm_v3 +  │   │
  │  │  - rep counter      │   function_end  │   out_mem + time_mem)│   │
  │  │  - sequencer_busy   │                 └──────────┬───────────┘   │
  │  │  - end_sequence     │                            │ signal_out    │
  │  └─────────────────────┘                 ┌──────────▼───────────┐   │
  │                                          │     output_reg       │   │
  │                                          │  (1 FF, ce-gated)    │   │
  │                                          └──────────┬───────────┘   │
  └─────────────────────────────────────────────────────┼───────────────┘
                                                        │
                                           ┌────────────▼─────────────┐
                                           │ sequencer_aligner_shifter│
                                           │   (3 registered stages)  │
                                           └────────────┬─────────────┘
                                                        │
                                                  sequencer_out
```

**Data flow summary:**

1. The **parameter extractor** reads instructions from `prog_mem` one at a time. For indirect
   opcodes it reads the appropriate indirect memory to resolve the operand. The resolved
   function call parameters are pushed into `seq_param_fifo` as 32-bit words. `[rtl]`

2. The **FIFO** (`seq_param_fifo`) decouples the extractor from the executor. The extractor
   runs ahead, filling the FIFO while the executor works through the current function. The FIFO
   is a 32-entry block-RAM FIFO (surf `FifoSync`). `[rtl]`

3. The **function executor** (`function_executor_v3`) dequeues entries from the FIFO one at a
   time. It manages the repetition counter, drives `func_start` to the function FSM, asserts
   `sequencer_busy` throughout execution, and fires `end_sequence` when the program ends.
   `[rtl]`

4. The **function FSM** (`function_fsm_v3`) steps through timeslices. It drives `func_out_add`
   (the timeslice index) which selects the current row from `out_mem` and `time_mem`. It counts
   cycles against `time_mem[i]` and asserts `function_end` when the last slice completes. `[rtl]`

5. The **output path** is: `out_mem` (combinatorial distributed-LUT-RAM read) →
   `output_reg` (1 flip-flop, clock-enable gated) → 3-stage registered aligner pipeline →
   `sequencer_out`. Total pipeline depth: **4 cycles**. `[rtl]`

---

## 2. Memory model

### 2.1 Function memories (`out_mem`, `time_mem`)

The sequencer supports up to 16 functions (F0–F15). Each function occupies a fixed 16-entry
slot in `out_mem` and `time_mem`: `[doc][rtl]`

- `out_mem[func_id × 16 + i]` — 32-bit output value for timeslice `i`
- `time_mem[func_id × 16 + i]` — duration of timeslice `i`, in clock cycles
- `time_mem[func_id × 16 + N] = 0` — terminates the function at slice `N`

The full 8-bit read address presented to `out_mem` at any given moment is:
```
{fifo_param_out[27:24], func_out_add[3:0]}
```
i.e. the upper nibble is the function ID from the FIFO, and the lower nibble is the current
timeslice index from the FSM. `[rtl]`

Both memories are **distributed LUT-RAM** with combinatorial (zero-latency) port-B reads.
`[rtl]`

**Termination rule:** The FSM checks `time_mem[func_id × 16 + i + 1]` (the *next* slice's
duration) before advancing. If it is zero, the current slice is treated as the last. This means
a function with a single non-zero entry at slot 0 and zero at slot 1 executes only slice 0.
The function executor guards against this at startup: if `time_mem[func_id × 16 + 1] = 0`
when `func_start` is asserted, the FSM refuses to enter `ts0` and the executor stalls. `[rtl]`
See also: F0 and the idle output (Section 5).

### 2.2 Program memory (`prog_mem`)

A flat array of 1024 × 32-bit words. Each word encodes one instruction. The upper 4 bits
`[31:28]` are the opcode. `[doc][rtl]`

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| `0x1` | `func_call` | Call function directly; repeat N times |
| `0x2` | `ind_func_call` | Function ID from `ind_func_mem`; rep count direct |
| `0x3` | `ind_rep_call` | Function ID direct; rep count from `ind_rep_mem` |
| `0x4` | `ind_all_call` | Both function ID and rep count indirect |
| `0x5` | `jump_to_add` | Jump to subroutine at fixed address; repeat N times |
| `0x6` | `ind_add_jump` | Jump to subroutine at indirect address; rep count direct |
| `0x7` | `ind_rep_jump` | Jump to subroutine at fixed address; rep count indirect |
| `0x8` | `ind_all_jump` | Both subroutine address and rep count indirect |
| `0xE` | `sub_trailer` | End of subroutine body. **Bits[27:0] are not read by hardware and must not be relied upon.** Only the opcode field bits[31:28] = `0xE` is used. See DISC-006. |
| `0xF` | `end_sequence` | End of program |

A rep count of 0 skips the instruction entirely. `[doc][rtl]`

### 2.3 Indirect memories

Four small memories (16 entries each) allow operands to be changed without rewriting the
program: `[doc][rtl]`

| Memory | Width | Used for |
|--------|-------|----------|
| `ind_func_mem` | 4 bits | Function ID substitution (opcodes 0x2, 0x4) |
| `ind_rep_mem` | 24 bits | Repetition count substitution (opcodes 0x3, 0x4) |
| `ind_sub_add_mem` | 10 bits | Subroutine address substitution (opcodes 0x6, 0x8) |
| `ind_sub_rep_mem` | 16 bits | Subroutine repetition count substitution (opcodes 0x7, 0x8) |

All four are distributed LUT-RAM with combinatorial reads, so the resolved operand is
available to the extractor FSM in the same cycle the instruction word is presented. `[rtl]`

### 2.4 Subroutine stack

A 16-entry single-port RAM (`generic_single_port_ram`) used by the extractor to save return
addresses and repetition counts when jumping into subroutines. Subroutine nesting is supported
up to 16 levels deep. `[doc][rtl]`

**Minimum body depth constraint:** A subroutine body must contain at least **2 `func_call`
instructions** before its `sub_trailer`. A body containing only 1 `func_call` causes the
`sub_trailer` to be consumed prematurely by the extractor pipeline; the return to the calling
context never occurs and the inner body address is re-executed indefinitely. `[sim]` See
**DISC-004** in the Discrepancies section.

**Stack word format `[rtl][sim]`:**

Each stack entry is a 32-bit word:

```
bit 31      : '0' (unused)
bit 30      : ind_sub_rep_flag  (1 if this call used an indirect-rep opcode, 0 otherwise)
bits 29:20  : program_mem_rd_add  (10-bit return address = address of the jump instruction)
bits 19:16  : x"0" (padding)
bits 15:0   : sub_rep_cnt  (rep count captured at sub_jump state)
```

Values are captured at the `sub_jump` state (one cycle after `op_code_eval` sets
`next_ind_sub_rep_flag` and `next_sub_rep_cnt`).

**Return address convention `[rtl][sim]`:** The return address saved onto the stack is the
**address of the jump instruction itself** (not the next instruction). This is because
`program_mem_add_int` is not incremented in `op_code_eval` before the stack push. The
consequence is that `program_mem_rd_add` is restored to the jump instruction's address on
return, so the indirect memories use the jump instruction's bits[3:0] as their slot index.

**Indirect rep slot index source `[rtl][sim]`:** For indirect-rep opcodes (`ind_rep_jump` 0x7,
`ind_all_jump` 0x8), the rep slot index is taken from bits[3:0] of the jump instruction word
re-read via the restored return address — not from the `sub_trailer` word. This means the
slot index is correct on every pass through the loop without any additional mechanism.

---

## 3. Pipeline architecture

### 3.1 Parameter extractor

The extractor FSM (`parameter_extractor_fsm_v3`) runs independently of the executor. It
advances through `prog_mem`, decodes each instruction, and pushes a resolved 32-bit entry into
`seq_param_fifo`. `[rtl]`

State sequence for the common case (`func_call`, opcode 0x1): `[rtl]`

```
wait_start  (1 cycle: on start_sequence pulse, latch program_mem_init_add)
op_code_eval (1 cycle: read opcode, check rep count)
simple_func_op (1 cycle: prepare FIFO data)
write_fifo  (1 cycle: assert fifo_param_write; increment program_mem_add)
wait_fifo   (1 cycle: pipeline bubble)
→ back to op_code_eval for next instruction
```

Total extractor cycles to push one `func_call` entry into the FIFO: **5 cycles** from
`start_sequence` pulse. `[rtl]`

For indirect opcodes one additional cycle is consumed in the corresponding indirect state
(`ind_func_call`, `ind_rep_call`, or `all_ind_call`) before `write_fifo`. `[rtl]`

For subroutine jumps (`jump_to_add`, `sub_jump` state), one additional cycle is consumed to
update the program counter and push the return address onto the stack. `[rtl]`

### 3.2 FIFO

`seq_param_fifo` is a surf `FifoSync` instantiated with `MEMORY_TYPE_G="block"` (default) and
`FWFT_EN_G=false` (default). The internal storage is a block-RAM, and the `empty` flag
de-asserts with block-RAM read latency after the first write. `[rtl]`

This FIFO latency contributes to startup latency (see Section 4.2).

### 3.3 Function executor

The executor FSM (`function_executor_v3`) dequeues one FIFO entry per function call and drives
the function FSM. Key states: `[rtl]`

```
wait_start       idle; sequencer_busy=0; watching fifo_empty
start_func       (1 cycle) assert fifo_read_en; next cycle asserts func_start
func_exe         running; sequencer_busy=1; waiting for function_end
func_rep         (1 cycle) restart same function for next repetition
```

When `function_end='1'` in `func_exe` and `prog_end_opcode='1111'` (i.e. the FIFO entry came
from an `end_sequence` instruction), the executor transitions to `wait_start` and asserts
`end_sequence` for one cycle. `sequencer_busy` drops on the following cycle. `[rtl]`

### 3.4 Function FSM

`function_fsm_v3` steps through timeslices ts0–ts15. It uses a 16-bit counter (`ts_cnt`)
starting at 1 and counting up to `time_mem[i]`. The FSM stays in state `tsN` while
`ts_cnt < time_mem[i]`, then exits when `ts_cnt = time_mem[i]`. `[rtl]`

`func_out_add` (registered) holds the current timeslice index. `time_add_timeslice` and
`time_add_timeslice_plus1` (also registered) provide the current and next slice's address to
`time_mem`, allowing the FSM to look ahead and detect the last slice. `[rtl]`

### 3.5 Output path

```
func_out_add (registered, 4-bit timeslice index)
    + fifo_param_out[27:24] (4-bit function ID, from FIFO output register)
         │
         ▼
    out_mem (distributed LUT-RAM, combinatorial port-B read)
         │  signal_out_func
         ▼
    output_reg (generic_reg_ce_init, 1 flip-flop)
         │  clock-enable: out_ce = not(out_ce_1 or out_ce_2)
         │  where out_ce_1 = function_end or veto_out
         │        out_ce_2 = out_ce_1 delayed 1 cycle
         │  → out_ce is deasserted for 2 cycles after function_end
         ▼
    sequencer_aligner_shifter_top (3 registered pipeline stages)
         │
         ▼
    sequencer_out
```

The `out_ce` gating serves two purposes: `[rtl]`
1. Prevents the combinatorial `out_mem` output from writing a transient value into
   `output_reg` during the cycle when `func_out_add` transitions back to 0 at function end.
2. Extends the last timeslice value in `output_reg` for 2 extra cycles, which is the source
   of the `+2` last-slice timing rule (see Section 4.1).

Total pipeline depth from FSM address update to `sequencer_out`: **4 cycles**
(1 for `output_reg` + 3 for aligner). `[rtl]`

**Note (cc9fb85 baseline):** At `cc9fb85`, bit 12 (`adc_trigger`) takes a 2-stage path
through the aligner instead of 3 stages, producing a 1-cycle glitch at transitions that
change bit 12. See DISC-005 for details. This was corrected in `lsst_reb` at `f875887`:
all 32 bits now travel through 3 registered aligner stages. `[rtl]`

---

## 4. Timing

### 4.1 Slice duration model

Once a sequence is running, each timeslice appears at `sequencer_out` for a duration determined
by its position in the function: `[doc][rtl][sim]`

| Slice position | Duration at `sequencer_out` |
|---|---|
| Slice 0, not the only slice | `time_mem[i] + 1` cycles |
| Slice 0, only slice (single-slice function) | `time_mem[i] + 3` cycles ⚠ **unreachable — see DISC-003** |
| Middle slice (index > 0, not last) | `time_mem[i]` cycles |
| Last slice (index > 0) | `time_mem[i] + 2` cycles |

The `+1` on slice 0 arises because the executor spends one cycle in the `start_func` state
(asserting `func_start`) before the FSM enters `ts0`. During this cycle `func_out_add` is 0
(the default), so `out_mem[func_id × 16 + 0]` — the slice 0 value — is already being
presented to `output_reg`. The FSM then spends `time_mem[0]` cycles in `ts0`, giving
`time_mem[0] + 1` total cycles at `output_reg`. `[rtl]`

The `+2` on the last slice arises from `out_ce` being gated low for 2 cycles after
`function_end`, holding the last slice value in `output_reg` for 2 extra cycles. `[rtl]`

These latencies are **documented as intended behaviour** in the user manual: `[doc]`
> *"There is a fixed deterministic latency on the execution of first and last time slice of
> each function. This latency is 1 cycle for the first time slice and 2 cycles for the last.
> There is no latency for the other time slices."*
> (Original text expressed in nanoseconds at 100 MHz; converted to cycles here.)

The slice duration model was confirmed by simulation. For a 2-slice function with
`time_mem[0]=3`, `time_mem[1]=5`: slice 0 appeared for 4 cycles and slice 1 for 7 cycles,
matching `3+1` and `5+2`. `[sim]`

### 4.2 Startup latency

The startup latency is the number of cycles from the `sync_cmd_start` pulse to the first
change in `sequencer_out`. It depends on the first instruction in the program. `[doc][sim]`

#### 4.2.1 Measured values (cc9fb85)

A dedicated latency sweep (`tb_latency.vhd`, 8 probes) was run to characterise startup
latency across all direct and indirect opcode types. `[sim]`

| Opcode / scenario | trigger→busy | trigger→first-change | busy→first-change |
|---|---|---|---|
| `func_call` (0x1), F1 | 7 | **12** | 5 |
| `func_call` (0x1), F2 | 7 | **12** | 5 |
| `func_call` (0x1), F3 | 7 | **12** | 5 |
| `ind_func_call` (0x2) → F1 | 7 | **12** | 5 |
| `ind_rep_call` (0x3), F1 | 7 | **12** | 5 |
| `ind_all_call` (0x4) → F1 | 7 | **12** | 5 |
| `jump_to_add` (0x5), 1-level sub, F1 inside | 9 | **14** | 5 |
| `ind_add_jump` (0x6), 1-level sub, F1 inside | 9 | **14** | 5 |
| `ind_rep_jump` (0x7), 1-level sub, F1 inside | 9 | **14** | 5 |
| `ind_all_jump` (0x8), 1-level sub, F1 inside | 9 | **14** | 5 |
| `jump_to_add` (0x5), 2-level sub, F1 inside | 11 | **16** | 5 |
| `jump_to_add` (0x5), 3-level sub, F1 inside | 13 | **18** | 5 |

Key findings: `[sim]`

1. **`func_id` does not affect latency.** F1, F2, F3 all give 12 cycles. The extractor
   passes the function ID as data and does not branch on it.

2. **Indirect operand lookups (opcodes 0x2, 0x3, 0x4) do not add latency.** All three
   give the same 12 cycles as a direct `func_call`. The indirect memories are distributed
   LUT-RAM with combinatorial reads; the resolved operand is available within the same FSM
   cycle, so no additional wait state is inserted.

3. **Each subroutine nesting level adds exactly 2 cycles** to both `trigger→busy` and
   `trigger→first-change`. The `busy→first-change` gap remains 5 cycles regardless.

4. **`busy→first-change` is a fixed 5-cycle pipeline constant** for all opcode types:
   ```
   1 cycle : executor start_func state (FIFO read + assert func_start)
   1 cycle : output_reg (generic_reg_ce_init FF in function_v3_top)
   3 cycles: sequencer_aligner_shifter_top pipeline
   ─────────────────────────────────────────────────────
   5 cycles total
   ```
   This is independent of opcode, func_id, or subroutine depth.

#### 4.2.2 Latency breakdown for direct func_call

```
trigger
  │
  ├─ 1 cycle : sequencer_v4_top latches start_sequence; extractor enters wait_start
  ├─ 1 cycle : op_code_eval — reads opcode from prog_mem
  ├─ 1 cycle : simple_func_op — prepares FIFO data word
  ├─ 1 cycle : write_fifo — asserts fifo_param_write; increments program_mem_add
  ├─ 1 cycle : wait_fifo — pipeline bubble
  ├─ 2 cycles: block-RAM FIFO internal read latency (non-FWFT FifoSync)
  │            (empty deasserts, fifo_param_out becomes valid)
  │
  ├─ [busy asserts here — 7 cycles after trigger]
  │
  ├─ 1 cycle : executor start_func state (reads FIFO, asserts func_start; sequencer_busy=1)
  ├─ 1 cycle : output_reg captures out_mem[func_id×16+0]
  ├─ 3 cycles: aligner pipeline stages 1, 2, 3
  │
  └─ [first-output-change at sequencer_out — 12 cycles after trigger]
```

#### 4.2.3 Subroutine latency increment

Each additional `jump_to_add` nesting level requires the extractor FSM to traverse:
- `sub_jump` state (1 cycle) — computes jump target, pushes return address onto stack
- `op_code_eval` (1 cycle) — reads the instruction at the jump target

This adds 2 cycles to `trigger→busy` per nesting level, with no effect on the fixed
`busy→first-change` pipeline. `[sim]`

#### 4.2.4 Discrepancy with user manual

The user manual states: `[doc]`
> *"A program that has an OP code 0x1 on the address 0 will start 40 ns after the trigger."*
> = **4 cycles** at 100 MHz.

The measured value at cc9fb85 is **12 cycles**. See **DISC-002** in the Discrepancies section.

The startup latency is **reported but not tested** by the characterisation testbench — it is
a latency, not a correctness criterion.

### 4.3 FIFO starvation

The extractor runs ahead of the executor and normally has the next function's parameters in the
FIFO before the executor needs them. If a function's total duration is shorter than the time
the extractor needs to enqueue the next entry, the executor will stall in `func_exe` waiting
for `fifo_empty` to deassert. `[rtl]`

Starvation manifests as a gap (repeated output value) between functions, not as a duration
error within a function. Production readout programs typically use timeslice values of 7
cycles or more, well above the starvation threshold. FIFO starvation is only a concern in
pathologically short test programs or deeply nested subroutines (see DISC-008). `[rtl]`

---

## 5. F0 and the idle output

### 5.1 Mechanism

`sequencer_out` at any moment reflects `out_mem[{fifo_param_out[27:24], func_out_add}]`,
pipelined through `output_reg` and the 3-stage aligner. `[rtl]`

When the sequencer is idle (executor in `wait_start`): `[rtl]`
- `func_out_add` resets to and defaults to `0x0`
- `fifo_param_out[27:24]` is `0x0` (the `end_sequence` instruction encodes func_id=0, and
  this is also the reset state of the FIFO output)
- Therefore `out_mem[0x00]` — function 0, slice 0 — is continuously presented to
  `output_reg` and propagates to `sequencer_out`

The idle output is **live**: a write to `out_mem[0x00]` while the sequencer is idle will
update `sequencer_out` after the 4-cycle pipeline delay. `[rtl]`

### 5.2 Documented convention

The user manual states: `[doc]`
> *"The first function is special since it is composed only by one time slice and is used to
> set outputs default values. When the system is in a non-operation mode the output values
> are set as described in this function."*

The intent is clear: F0 slice 0 is the idle/default output pattern. `[doc]`

The single-slice restriction ("composed only by one time slice") is a **programming
convention, not a hardware enforcement**. The RTL places no restriction on the number of
slices in F0. `[rtl]` See **DISC-001** in the Discrepancies section.

### 5.3 F0 and `end_sequence`

The `end_sequence` instruction (opcode `0xF`) is pushed into the FIFO like any other
instruction, with `fifo_param_out[31:28] = 0xF` and `fifo_param_out[27:24] = 0x0`
(func_id=0). The executor runs F0 as normal, and fires `end_sequence` when F0's last slice
completes. `[rtl]`

This means the `end_sequence` pulse and the return to idle both happen via F0. The output
during `end_sequence` execution is F0's programmed output values. After `end_sequence`
completes, the idle mechanism (Section 5.1) resumes, and `sequencer_out` returns to
`out_mem[0x00]`. `[rtl]`

**When does `end_sequence` appear at `sequencer_out`?**

`end_sequence` is asserted at the executor level when F0's function FSM reaches
`time_mem[1]` on the last-slice counter. Due to the aligner pipeline, `sequencer_out`
and `end_sequence` are both visible at the ILA 4 cycles before the last raw cycle of
F0 ts1 has elapsed. The number of cycles that F0 ts1 is visible at `sequencer_out`
before `end_sequence` fires is:

```
visible_cycles(F0 ts1) = (t1 + 2) - 4   where t1 = time_mem[0x01]
```

For the standard F0 (`t1 = 3`): visible = `(3+2) - 4 = 1` cycle.
For T12's F0 (`t1 = 6`): visible = `(6+2) - 4 = 4` cycles.

Hardware confirmed (T12): `end_sequence` fires on cycle 4 of F0 ts1, with
`00000200` visible for 4 cycles at `sequencer_out`. `[sim][hw]`

**Consequence for programming:** F0 must satisfy the function executor's minimum-function
guard: `time_mem[0x01]` (F0 slice 1 duration) must be non-zero, or the executor will stall
when processing `end_sequence`. The minimum working F0 is therefore **two slices**. `[rtl]`

---

## 6. Verification implications

1. **Golden models must use exact durations.** A testbench that applies per-slice correction
   factors (`+1` first slice, `+2` last slice) as ad-hoc adjustments is not verifying the
   timing contract — it is encoding known RTL behaviour into the golden model. The test only
   catches *changes* to that behaviour, not whether the behaviour is correct. The slice duration
   model in Section 4.1 should be derived from the documented contract and confirmed against
   hardware, not calibrated to match simulation. `[rtl][doc]`

2. **Startup latency is measured and reported separately.** The fixed latency from trigger to
   first output change is a single constant per instruction type. It should be reported per
   test case but not asserted — it is a property to be compared against hardware, not a
   correctness criterion. `[sim]`

3. **FIFO starvation is a distinct failure mode.** It manifests as a gap between slices, not
   as a duration offset. Test programs must use timeslice values long enough to avoid
   starvation. `[rtl]`

4. **RTL fetch-state overhead must not bleed into output duration.** Any states inserted to
   absorb memory read latency must not cause `func_out_add` to be held at a given address for
   longer than `time_mem[i]` cycles. If they do, those states represent timing bugs, not
   pipeline features. `[rtl]`

---

## 7. Discrepancies

Discrepancies between sources are recorded here. Each entry notes the conflicting claims,
their sources, a hypothesis for the cause, and the resolution status.

---

### DISC-001 — F0 single-slice restriction

**Claim A `[doc]`:** F0 must have only one timeslice.
> *"The first function is special since it is composed only by one time slice..."*

**Claim B `[rtl]`:** The RTL imposes no such restriction. F0 can have up to 16 timeslices,
subject to the same termination rules as any other function.

**Claim C `[hw]`:** In practice, F0 is routinely programmed with two identical 50-cycle
timeslices. This works correctly on hardware.

**Hypothesis:** The single-slice description in the documentation reflects an early design
intent or a simplifying assumption made at the time of writing. The RTL was either always
more flexible or was later relaxed.

**Consequence:** F0 *must* have at least two slices to satisfy the executor's minimum-function
guard (Section 5.3). The documented "one slice" convention is therefore not merely optional
but would cause the sequencer to stall if followed literally with `time_mem[0x01] = 0`.

**Resolution:** Accepted/Documented. `[rtl]` and `[hw]` are authoritative; `[doc]` is
inaccurate on this point. Hardware confirms F0 must have ≥ 2 slices (see Section 5.3 and
DISC-003). `[sim][hw]`

---

### DISC-002 — Startup latency for direct `func_call` at address 0

**Claim A `[doc]`:** 4 cycles (stated as "40 ns" at 100 MHz).
> *"A program that has an OP code 0x1 on the address 0 will start 40 ns after the trigger."*

**Claim B `[sim]`:** 12 cycles, measured directly in xsim simulation at `cc9fb85`.

**Breakdown of the 12 cycles `[sim]`:**
- 7 cycles from trigger to `sequencer_busy` assertion (extractor FSM pipeline + block-RAM
  FIFO read latency)
- 5 cycles from `sequencer_busy` to first output change (executor `start_func` state +
  `output_reg` FF + 3-stage aligner)

**Breakdown of the 4-cycle (manual) figure — hypothesis `[rtl]`:**
The manual was written against an earlier v3 extractor. The v4 extractor adds:
- A block-RAM (not distributed-RAM) FIFO with ~2 cycles of read latency
- An additional `wait_fifo` pipeline bubble state
These account for approximately 8 of the extra cycles. The remaining difference may reflect
a shorter or absent aligner pipeline in the v3 design described in the manual.

**Additional finding:** A sweep across all opcode types confirms that `func_id` and
indirect operand resolution (opcodes 0x2, 0x3, 0x4) do not add to latency. Subroutine
nesting adds 2 cycles per level to `trigger→busy`, leaving `busy→first-change` fixed at
5 cycles. See Section 4.2 for the full table. `[sim]`

**Resolution:** Accepted/Documented. The 12-cycle figure is confirmed cycle-exact by both
simulation and hardware. `[doc]` is attributed to the older v3 architecture and is not
authoritative for `cc9fb85`. `[sim][hw]`

---

### DISC-003 — Single-slice function guard causes silent skip and executor hang

**Claim A `[doc]`:** Section 4.1 of this document lists "Slice 0, only slice (single-slice
function)" with a duration of `time_mem[i] + 3` cycles, implying single-slice functions are
a supported and executable case.

**Claim B `[rtl]`:** `function_fsm_v3.wait_start` checks `func_time_in_plus1` (i.e.
`time_mem[func_base + 1]`) when `start_function = '1'`. If `func_time_in_plus1 = 0x0000`,
the FSM stays in `wait_start` — it never transitions to `ts0`. `function_end` is never
asserted. The executor stalls in `func_exe` indefinitely, and the sequencer hangs.

This is the same guard mechanism noted for F0 in DISC-001 and Section 5.3. It applies
identically to **every** function: if `time_mem[func_base + 1] = 0`, the function is
silently skipped by the FSM and the executor hangs. `[rtl]`

**Consequence:** The "Slice 0, only slice" row in Section 4.1 is unreachable. The duration
formula `time_mem[i] + 3` correctly describes the combinational path through the FSM if
`ts0` were entered with `func_time_in_plus1 = 0`, but that path is never taken. Any program
that calls a function with `time_mem[func_base + 1] = 0` will hang.

**Testbench:** T14 in `tb_sequencer.vhd` confirms the hang: it loads a single-slice F1
(`time_mem[0x11] = 0`), triggers the sequencer, and verifies that `end_sequence` never fires
and `sequencer_busy` stays high for 100 cycles. T13 tests the minimum working case (2-slice
F1 with `t1 = 1`) as the boundary adjacent to the hang condition. T15 further confirms that
the hang occurs identically when a single-slice function is called from inside a 2-level
nested subroutine.

**Resolution:** Accepted/Documented. `[rtl]` is authoritative. Programming rule: every
called function must have at least two non-zero timeslice entries (`time_mem[base + 1] != 0`).
Hardware confirms the hang (T14): `sequencer_busy` high, `end_sequence` never fired,
over ~29 k samples. `[sim][hw]`

---

### DISC-004 — Subroutine body minimum depth: 1 func_call causes hang

**Claim A `[doc]`:** No minimum body depth is documented. The `jump_to_add` / `sub_trailer`
mechanism is described as wrapping any sequence of instructions.

**Claim B `[sim]`:** A subroutine body containing exactly 1 `func_call` before its
`sub_trailer` causes a hang: the body function executes once, then the inner body address is
re-executed indefinitely. `end_sequence` never fires; `sequencer_busy` stays high. A
subroutine body containing 2 or more `func_call` instructions before its `sub_trailer`
executes correctly. `[sim]`

**Evidence (tb_t11_explore.vhd):**
- Probe A: `[0] jump(4) → [4] jump(6) → [6] func_call(F1) → [7] sub_trailer`: F1 loops forever.
- Probe B: same structure with F2 at [6]: F2 loops forever.
- Probe C: `[6] func_call(F1) → [7] func_call(F2) → [8] sub_trailer`: F1, F2 execute once
  each, outer context returns, `end_sequence` fires. Full correct execution.
- Probe D: same 1-func_call structure with lower inner address (addr=2): same hang.
  The symptom does not depend on address ordering.

**Hypothesis:** The extractor pipeline runs ahead of the executor. With only 1 `func_call`
in the body, the extractor processes the `sub_trailer` into the FIFO before the executor
has finished consuming the `func_call` entry. The return-address pop and program counter
restore therefore happen at the wrong time, leaving the inner body address live and causing
it to be re-entered. With 2 `func_call` entries the pipeline separation is sufficient for
the trailer to be processed correctly. The root cause is in the extractor FSM
(`parameter_extractor_fsm_v3`) or the FIFO interaction, not the executor. `[sim][hyp]`

**Analogy:** This is the subroutine-body analogue of DISC-003 (function minimum 2 slices):
both are minimum-depth pipeline guards imposed by the implementation but not documented.

**Testbench:** T11 in `tb_sequencer.vhd` tests the minimum working case (2 `func_calls`
in the inner body). The 1-func_call hang at 1-level nesting is confirmed by simulation
exploration (`tb_t11_explore.vhd`, Probes A–D). T15 in `tb_sequencer.vhd` is the
dedicated regression test for the hang: it uses 2-level nesting with exactly 1 `func_call`
in the inner body and verifies that `end_sequence` never fires and `sequencer_busy` stays
high for 100 cycles after trigger. The same hang symptom applies regardless of nesting
depth.

**Resolution:** Accepted/Documented. `[sim]` is authoritative. Programming rule: every
subroutine body must contain at least 2 `func_call` instructions before its `sub_trailer`.
Hardware confirms the hang (T15): `sequencer_busy` high, `end_sequence` never fired,
over ~29 k samples. `[sim][hw]`

---

### DISC-005 — Aligner pipeline produces 1-cycle transition output at slice boundaries

**Claim A (implicit) `[doc]`:** The sequencer output at any cycle equals the output value
stored in `out_mem` for the current timeslice, after passing through the aligner. No
intermediate values are mentioned.

**Claim B `[sim]`:** When two consecutive timeslices have output values that differ in
multiple bits simultaneously — in particular when bit 12 (`adc_trigger`) changes — the
aligner's 3-stage pipeline produces exactly **one cycle** of intermediate output between
the two clean values. This intermediate ("glitch") value differs from both the outgoing
and incoming slice values. `[sim]`

**Evidence (T12 original failure, `tb_sequencer.vhd`):**

The original T12 used F0 raw values `0xABCD1234` (projected: `0x80011234`) and `0xDEAD5678`
(projected: `0x80015678`), and F1 values `0x000000CC` / `0x000000DD`. The failure cycle
table showed:

| Transition | Outgoing value | Glitch (1 cycle) | Incoming value |
|------------|---------------|------------------|----------------|
| F0-idle → F1-ts0 | `0x80011234` | `0x80010234` | `0x000000CC` |
| F1-ts1 → F0-ts0  | `0x000000DD` | `0x000010DD` | `0x80011234` |

In both cases the glitch value differs from the outgoing value by exactly **bit 12**
(`adc_trigger`, `0x00001000`): the glitch = outgoing with bit 12 flipped toward the
incoming value. This is consistent with bit 12 being driven from a separate path
(the shift-register tap in `sequencer_aligner_shifter_top`) that resolves one pipeline
stage earlier or later than the remaining 31 bits. `[sim][hyp]`

**Effect on slice durations:** The 1-cycle glitch consumes one cycle from the nominal
duration of the outgoing slice as seen at `sequencer_out`. For example, F1-ts1 with
`time_mem = 5` (nominal last-slice duration 7 cycles) shows only 6 cycles of clean
`0x000000DD` output, followed by 1 glitch cycle, before the incoming F0-ts0 value
appears. The total counted duration (6 clean + 1 glitch) still equals 7 cycles, so
the timing model is not violated — the glitch is part of the slice boundary, not extra.

**Sparse-pattern exception:** With output values that differ in only 1 bit (or in bits
that do not cross the bit-12 boundary), the glitch either does not appear or is
indistinguishable from the adjacent slice values. All T01–T11, T13 use sparse patterns
(`0xCC`, `0xDD`, `0x01`, `0x02`, etc.) and show no visible glitch. This is why the
behaviour was not observed until T12.

**Testbench:** T12 (fixed) uses sparse F0 values (`0x100`, `0x200`) to keep transitions
clean and test the F0 duration formula without glitch interference. T16 deliberately
uses the original multi-bit F0 values (`0xABCD1234` / `0xDEAD5678`) and includes the
glitch cycles in the expected sequence, pinning this behaviour for hardware comparison.
The earlier erroneous observation that end_seq fired on cycle 4 of F0-ts1 (rather than
cycle 1) was initially attributed to a test artifact caused by incorrect idle_out capture.
However, hardware comparison (T12) has confirmed it was actually correct: when
F0's `t1=6` (ts1 raw duration = 8 cycles), end_seq fires at cycle 4 (= `(t1+2)-4`).
The "cycle 1" rule only holds for the standard F0 (`t1=3`, ts1 raw = 5 cycles,
visible = `5-4 = 1`). See Section 5.3 for the general formula.

**Root cause confirmed `[rtl]`:** RTL inspection of `sequencer_aligner_shifter_top.vhd`
(at `cc9fb85`) confirmed that bit 12 (`adc_trigger`, parameterised as `start_adc_bit=12`)
takes a **2-stage** registered path while all other bits take a **3-stage** path:

- **Bits 31:13, 11:0:** `sequencer_in` → `sequencer_delay_1` → `sequencer_delay_2` →
  `sequencer_delay_3` → `sequencer_out` = 3 registered stages.
- **Bit 12 (baseline, `enable_conv_shift` disabled):** `sequencer_in(12)` → SRLC32E tap 0
  (1 stage) → `shift_reg_out_ff` (1 stage) → `sequencer_out` = 2 registered stages,
  arriving 1 cycle early.

The SRLC32E chain is an optional ADC-trigger delay feature, register-map-controlled via
`enable_conv_shift` / `init_conv_shift`, which defaults to disabled (zero) after reset. It
is not activated during normal sequencer operation unless explicitly written by software.
The 2-stage path for bit 12 is therefore the default hardware condition.

**Fix (lsst_reb `f875887`):** A registered flip-flop stage (`srl_input_ff`, instance `ff_ce`)
was inserted between `sequencer_in(start_adc_bit)` and the SRLC32E input (`srl_q_ch(0)`).
This gives bit 12 a 3-stage path matching all other bits:
`sequencer_in(12)` → `srl_input_ff` (1 stage) → SRLC32E tap 0 (1 stage) →
`shift_reg_out_ff` (1 stage) → `sequencer_out`.

**Side effect on the optional shift feature:** With the fix, `shift_counter=N` produces
`N+3` total cycles of delay for bit 12 (was `N+2`). This is a calibration offset, not a
structural break; it applies only when `enable_conv_shift` is activated by software.

**Hardware status:** All 17 tests were initially captured on hardware at the **pre-fix
bitstream** (`cc9fb85`); T16 comparison against the pre-fix golden sequence passed
cycle-exact. The FPGA was subsequently rebuilt with `f875887`. T16 was
re-captured on the fixed bitstream: clean output confirmed, no intermediate cycles.
`hw_compare.py` expected sequence and `REB_v5/hw_data/T16.csv` updated accordingly.
All 17/17 tests (later expanded to 21/21) pass on the fixed bitstream. `[hw]`

**T16 output on fixed bitstream (no glitch cycles):**
- `0x000000CC` × 4 — F1 ts0 (first): 3+1
- `0x000000DD` × 7 — F1 ts1 (last):  5+2
- `0x80011234` × 4 — F0 ts0 (first): 3+1
- `0x80015678` × 1 — F0 ts1: `end_sequence` fires on cycle 1

**Resolution:** Fixed at `f875887` `[rtl]`. Root cause confirmed by RTL inspection.
Glitch value and 1-cycle duration confirmed cycle-exact by simulation and hardware
(against pre-fix bitstream). Fix confirmed on rebuilt FPGA (`f875887` bitstream):
T16 clean output matches expected no-glitch sequence cycle-exact.
`[sim][hw][rtl]`

---

### DISC-006 — `sub_trailer` bits[15:0] are not read by the hardware

**Claim A (implicit) `[doc]`:** The `sub_trailer` instruction word carries a rep-count field
in bits[15:0] that must match the rep count of the corresponding `jump_to_add` (or other
subroutine-call) instruction. The testbench header comment at the time of writing stated:
> `0xE sub_trailer : bits[31:28]=0xE, bits[15:0]=rep (must match jump rep)`

This implies the hardware reads `sub_trailer[15:0]` and uses it in the loop-exit decision.

**Claim B `[rtl]`:** `sub_trailer[15:0]` is never read. The loop-exit decision in state
`rep_sub` of `parameter_extractor_fsm_v3` compares:

- `program_mem_data[15:0]` — the program memory output at the **call-site address** (the
  `jump_to_add` / `ind_add_jump` instruction word), which was reloaded into
  `program_mem_add` during `trailer_op`.
- `data_from_stack[15:0]` — the rep count saved onto the stack at call time, which is the
  `sub_rep_cnt` value just before it was zeroed in `sub_jump` — i.e., the same
  `jump_to_add[15:0]` field captured one cycle earlier.

Both operands are derived from the **jump instruction word**, not from the `sub_trailer`
word. For a static program (the only supported use case) they are always equal, so the
subroutine always exits after exactly one traversal. The `sub_trailer` instruction word
serves solely as an opcode marker (`[31:28] = 0xE`) and an address marker (its position in
program memory determines the return address that is saved onto the stack at call time).
Its payload bits ([27:0]) are not used.

For indirect-rep opcodes (`ind_rep_jump` 0x7, `ind_all_jump` 0x8), the comparison is
`ind_sub_rep_mem_data_out` (live read of the indirect rep memory at the rep slot) against
`data_from_stack[15:0]` (the indirect rep value captured at call time). Again, no field
of the `sub_trailer` word is involved.

**Consequence:** There is no such thing as a `sub_trailer` / jump rep-count mismatch. Any
value may be placed in `sub_trailer[15:0]`; it has no effect on sequencer behaviour.
All existing tests happen to encode `sub_trailer[15:0]` equal to the jump rep count, but
this is programmer convention, not a hardware requirement.

**Testbench:** T21 in `tb_sequencer.vhd` verifies the don't-care property: it uses the
same program as T09 (`jump_to_add`, 1-level, rep=1) but encodes `sub_trailer` as
`0xE000FFFF` (bits[15:0] = `0xFFFF`, maximally different from the jump rep field of `1`).
Expected output is identical to T09. Hardware confirmed cycle-exact on the `f875887`
bitstream. `[sim][hw]`

**Resolution:** Accepted/Documented. `[rtl]` is authoritative; the "must match" convention
in the documentation and prior testbench comments is incorrect. The testbench header
comment has been corrected. Hardware confirms T21 cycle-exact on the `f875887` bitstream:
latency and output sequence identical to T09. `[sim][hw]`

**Programming rule:** Do not encode any meaningful value in `sub_trailer` bits[27:0]. The
field is completely ignored by the hardware; only the opcode bits[31:28] = `0xE` are used.
Writing a rep count or any other value into bits[27:0] has no effect and should be avoided
to prevent confusion. `[rtl][sim][hw]`

---

### DISC-007 — Invalid opcode causes a permanent `sequencer_busy` hang

**Claim A (implicit) `[doc]`:** When an invalid opcode is encountered the sequencer signals
an error via `op_code_error`, and the executor returns to its idle state after draining the
FIFO. The sequencer can be recovered by pulsing `op_code_error_reset`.

**Claim B `[sim]`:** After an invalid opcode is encountered the sequencer **never** returns to
idle on its own. `sequencer_busy` stays asserted indefinitely; no recovery is possible with
`op_code_error_reset` alone — a full reset is also required.

**Observed behaviour (T22, confirmed in simulation):**

1. The parameter extractor (`parameter_extractor_fsm_v3`) hits the invalid opcode, enters
   `op_code_error_state`, asserts `op_code_error='1'`, and stops writing to the FIFO.
   `op_code_error_add` is set to the address of the offending instruction (combinatorial tap
   on `program_mem_rd_add` in `sequencer_parameter_extractor_top_v4`).

2. The function executor drains whatever was already in the FIFO (F1 output appears normally:
   CC×4, DD×7 for the T22 program).

3. After the FIFO is empty, the executor (`function_executor_v3`, state `func_exe`) finds
   `fifo_empty='1'` with no `end_seq` token and no `inf_loop` — it loops back into `func_exe`
   indefinitely, re-running whatever function it last read. `sequencer_busy` stays `'1'`
   forever; `end_sequence` never fires.

4. `sequencer_v4_top` line: `sequencer_start_int <= start_sequence AND NOT sequencer_busy_int`.
   Because `sequencer_busy` is stuck high, any subsequent trigger pulse is blocked at this
   gate — it never reaches the extractor.

5. Pulsing `op_code_error_reset` clears `op_code_error` and returns the extractor to
   `wait_start`, but does **not** affect the executor, which is still looping in `func_exe`.
   A full reset (`do_reset`) is required to escape the hang.

**Key internal signal trace at T22 trigger (from T22_A.csv):**

| sample_idx | busy | end_seq | seq_out  | op_err | notes                        |
|-----------|------|---------|----------|--------|------------------------------|
| 6         | 0    | 0       | 00000001 | 0      | pre-busy                     |
| 7         | 1    | 0       | 00000001 | 0      | busy asserts (+7 cycles)     |
| 8         | 1    | 0       | 00000001 | 1      | op_code_error asserts (+8)   |
| 12–15     | 1    | 0       | 000000CC | 1      | F1 ts0 output (CC×4)         |
| 16–22     | 1    | 0       | 000000DD | 1      | F1 ts1 output (DD×7)         |
| 23+       | 1    | 0       | 000000CC | 1      | executor looping F1 forever  |

**Trigger-to-error timing:** `op_code_error` asserts at sample_idx=8 (i.e., 2 cycles after
`sequencer_busy`). This is earlier than the F1 output appears (sample_idx=12), because the
extractor prefetches program words — it already hit opcode 0xC (the invalid word at
prog_mem[1]) before the executor even began executing F1.

**`op_code_error_add`:** Combinatorial output — equals 1 (address of `0xC0000000`) throughout
the hung period. Captured as address 1 in simulation.

**Recovery procedure:**
1. Pulse `op_code_error_reset` (register `0x390001`) for one clock. Clears `op_code_error`;
   extractor returns to `wait_start`. Busy **remains** high.
2. Assert full reset to escape executor `func_exe` loop. After reset: busy='0',
   `op_code_error='0'`, sequencer idle.
3. Load new program and trigger normally.

**Testbench:** T22 in `tb_sequencer.vhd` exercises all three aspects:
- **Phase A:** F1 output verified cycle-exact (CC×4, DD×7); stuck-busy confirmed for 20
  observation cycles; `op_code_error='1'`, `op_code_error_add=1` verified.
- **Phase B:** Second trigger verified to be blocked by the `AND NOT busy` gate; stuck state
  maintained for 20 cycles.
- **Phase C:** `op_code_error_reset` pulse clears error; `do_reset` escapes executor loop;
  F2 runs to completion (EE×4, FF×7, F0_V0×4, F0_V1×5).

T22 is excluded from `hw_capture.py`/`hw_compare.py` hardware comparison: Phases A/B have
no `end_sequence` so the ILA never advances past its capture window; Phase C requires a
third trigger that cannot be isolated by a single ILA arm. `[sim]`

**Resolution:** Accepted/Documented. op_code_error recovery requires `op_code_error_reset`
**plus** a full reset. Any trigger while `sequencer_busy='1'` is silently blocked at the
top-level gate. `[sim][rtl]`

---

### DISC-008 — Deep subroutine nesting: executor FIFO starvation with few innermost func_calls

**Claim A `[doc]`:** No maximum nesting depth is documented. The `jump_to_add` / `sub_trailer`
mechanism is described as freely nestable.

**Claim B `[sim]`:** With 4 or more levels of subroutine nesting, a hang occurs if the
innermost body contains too few `func_call` instructions. The sequencer locks up identically
to DISC-004: `sequencer_busy` stays high and `end_sequence` never fires. The minimum number
of innermost func_calls required to avoid the hang depends on nesting depth. `[sim]`

**Root cause:** The parameter extractor (`parameter_extractor_fsm_v3`) unwinds the subroutine
stack after the last func_call is queued. Each stack level requires one `sub_trailer` /
`rep_sub` / `write_fifo` / `wait_fifo` cycle sequence (≈ 5 extractor clock cycles per level).
For N levels the total unwind latency is approximately **5 × N cycles**.

Meanwhile the function executor (`function_executor_v3`) starts consuming FIFO entries as
soon as they arrive. With K func_calls in the innermost body each taking T_exec cycles to
run, the executor finishes in approximately **K × T_exec cycles** after the last func_call
entry is queued. If unwind latency exceeds execution time the FIFO is exhausted before
`end_sequence` is written; the executor enters its permanent `func_exe` re-execution loop.

**Observed data points (2-slice functions, times=(3,5), T_exec ≈ 8 cycles):**

| N (nesting levels) | K (innermost func_calls) | Result     |
|--------------------|--------------------------|------------|
| 1                  | 1                        | PASS (T09) |
| 2                  | 2                        | PASS (T11) |
| 2                  | 1                        | HANG (T15, DISC-004) |
| 3                  | 2                        | PASS (T20) |
| 4                  | 2                        | HANG (T29a) |
| 4                  | 3                        | PASS (T29b) |
| 4                  | 4                        | PASS (T29c) |

**Derived inequality:** The hang-free condition (empirically calibrated for 2-slice functions
with times=(3,5)) is:

```
K × T_exec  >  N × 5
K × 8       >  N × 5
K           >  N × 0.625
```

For the standard 2-slice function shape: K ≥ ⌈N × 0.625⌉ = ⌈N × 5/8⌉.

| N  | Required K |
|----|-----------|
| 1  | 1         |
| 2  | 2         |
| 3  | 2         |
| 4  | 3         |
| 5  | 4         |
| 8  | 5         |

The formula is T_exec-dependent: slower functions (larger times) relax the constraint
(larger T_exec → larger K × T_exec for the same K); faster functions tighten it.
The factor of 5 cycles per nesting level on the extractor side is an FSM characteristic of
`parameter_extractor_fsm_v3` and does not depend on function content.

**Latency note (N=4, T29b):**
- trigger → busy: 15 cycles
- trigger → first-change: 20 cycles  (+2 per additional nesting level over the N=2 baseline
  of 16, consistent with T20 and T11)

**Testbench:** T29b in `tb_sequencer.vhd` is the regression test for this boundary: N=4,
K=3, the minimum passing configuration. T29a (N=4, K=2) is documented as the failing
boundary case. `[sim]`

**Resolution:** Accepted/Documented. Deep nesting with few innermost func_calls is a latent
hang risk. Users must ensure K ≥ ⌈N × 5 / T_exec⌉ for the innermost body, where T_exec is
the per-function execution time in sequencer clock cycles. For typical 2-slice functions at
times=(3,5): K ≥ ⌈N × 5/8⌉. `[sim][rtl]`

---

### DISC-009 — `sync_cmd_main_addr` and `reg_cmd_start` are multipliers, not direct program-word indices

**Claim A (implicit) `[doc]`:** The `main_addr` field of the `sync_cmd_start` command and the
`regDataWr[4:0]` field of the `reg_cmd_start` register write select the starting 32-bit word
address in `prog_mem` directly.

**Claim B `[rtl]`:** The address presented to the extractor is not `main_addr` directly.
In `Sequencer.vhd`:

```vhdl
sequencer_start_addr <= "000" & main_addr & "00";
```

`main_addr` (5 bits) is concatenated with **two trailing zero bits**, producing a 10-bit
program-word address equal to `main_addr × 4`. The same applies to `reg_cmd_start`:
`regDataWr[4:0]` is the same 5-bit field, also shifted left by 2. The resulting address is
a 32-bit word index into `prog_mem` (not a byte address — `prog_mem` is 32 bits wide).

**Consequence:** To start execution at 32-bit program word `W`, write `W/4` into `main_addr`
or `regDataWr[4:0]`. Equivalently, to use start index `idx`, place the first instruction at
`prog_mem` word `idx × 4`. Only word addresses that are multiples of 4 can be specified as
entry points; words at non-aligned positions are unreachable as start addresses. `[rtl][sim]`

**Secondary finding:** `sequencer_start_addr` has **no reset branch** in `Sequencer.vhd` — it
persists across `do_reset`. This is harmless in normal operation because the extractor only
samples it on `start_sequence='1'`, but it means test infrastructure must always write a
correct start address before triggering, even for tests that use addr=0. `[rtl][sim]`

**Testbench:** T25a (`sync_cmd_start`, `main_addr=1`, program at word 4) and T25b
(`reg_cmd_start`, `regDataWr[4:0]=2`, program at word 8) verify both trigger paths.
Both pass cycle-exact in simulation. `[sim]`

**Resolution:** Accepted/Documented. The `main_addr` / `regDataWr[4:0]` field is a
multiplier-of-4 index, not a direct word address. `[rtl][sim]`

---

### DISC-010 — ADC alignment shift counter: bit-12 timing asymmetry across repetitions

**Background:** The `sequencer_aligner_shifter_top` module contains an SRLC32E shift
register on bit 12 (`adc_trigger`). Non-bit-12 bits pass through a fixed 3-stage pipeline.
Bit 12 passes through `srl_input_ff` (1 stage) + SRLC32E (tap = `shift_counter + 1`
stages) + `shift_reg_out_ff` (1 stage) = `shift_counter + 3` total stages.

`shift_counter` auto-increments on each **falling edge of the SRLC32E output** when
`en_shift_counter='1'`. It is reset to 0 by `init_conv_shift`. `[rtl][sim]`

**Observation:** With `enable_conv_shift` latched and `shift_counter` starting at 0,
running `func_call(F1, rep=2)` where F1 has bit12=1 in ts0 and bit12=0 in ts1 (all other
bits constant at `0x00000100`), the observed output at `sequencer_out` is:

| Window | Expected (no shift) | Observed | Notes |
|--------|---------------------|----------|-------|
| iter1 ts0 (counter=0) | 4 cycles | 4 cycles | No delay; counter=0 |
| iter1 ts1 (counter→1) | 5 cycles | **6** cycles | Bit-12 fall delayed +1; counter increments to 1 during this window |
| iter2 ts0 (counter=1) | 4 cycles | 4 cycles | Both rise and fall of bit-12 delayed by 1; net duration unchanged |
| iter2 ts1 (counter→2) | 5 cycles | **4** cycles | Bit-12 rise delayed +1 but bit-12 fall also delayed +1 from iter2 ts0; ts1 shortened by 1 net |
| F0 ts0 (no bit-12) | 4 cycles | 4 cycles | Unaffected |
| F0 ts1 (end_seq) | 1 cycle | 1 cycle | end_seq fires on first appearance of F0_V1 |

The asymmetry arises because `shift_counter` increments after each bit-12 falling edge.
The first ts0→ts1 transition (counter=0→1) lengthens ts1 by 1. The second ts0→ts1
transition (counter=1→2) occurs with counter=1, so ts0's end is delayed 1 cycle, but ts1's
end is also delayed by the time the counter increments to 2 — net effect on ts1 duration
is −1 cycle relative to nominal. `[rtl][sim]`

**Practical implication:** When the shift counter is active, the duration of the low-bit-12
timeslice (ts1 in this test) varies depending on the counter value at the moment bit-12
falls. Specifically: the first low-bit-12 timeslice after enabling shift is always +1 cycle
longer than nominal; subsequent low-bit-12 timeslices may be shorter or nominally equal
depending on counter progression. `[sim]`

**Testbench:** T31 (sim-only) pins the cycle-exact output sequence for the 2-repetition
scenario above. end_seq at cycle 34, busy_drop at cycle 35 from trigger. `[sim]`

**Resolution:** Accepted/Documented. The shift counter is an intentional ADC conversion
timing feature; the timing asymmetry is a natural consequence of the auto-increment design.
No RTL change warranted. `[sim]`

---

### DISC-011 — `init_conv_shift` precondition — no discrepancy

An early investigation hypothesised that `do_reset` does not reset `shift_counter`, which
would require an explicit `init_conv_shift` pulse before enabling scan mode. This was
refuted by tracing the full reset chain through `REB_v5_base.vhd`: `do_reset` propagates
through `sys_rst` to `sequencer_aligner_shifter_top`, resetting `shift_counter` to 0 via
`shift_mode_en_ff`. Confirmed by T32 simulation (`tb_sequencer.vhd`). `[rtl][sim]`

**Resolution:** No discrepancy. `do_reset` is sufficient to reset the shift counter.
`init_conv_shift` is redundant for this purpose but still functions as an explicit counter
reset if needed during operation. No programming constraint applies.

---

### DISC-012 — Infinite-loop restart omits `veto_out`, shortening ts0 by 1 cycle

**Claim A (implicit) `[doc]`:** In infinite-loop mode, every iteration of the function
produces the same output waveform at `sequencer_out`.

**Claim B `[rtl][sim]`:** The first iteration's ts0 appears for `time_mem[0] + 1` cycles,
but all subsequent iterations' ts0 appears for only `time_mem[0]` cycles. The loop output
is not strictly periodic. See Section 8.4 for detailed timing.

**Root cause `[rtl]`:** In `function_executor_v3`, the `infinite_loop_restart` state issues
`func_start='1'` without asserting `veto_out`. Normal function-to-function transitions
assert `veto_out` for 2 cycles, freezing `output_reg` via the `out_ce` gate. Without this
freeze, the restarted function's ts0 value propagates to `output_reg` one cycle earlier
than on the first iteration.

**Fix:** Assert `veto_out` in `infinite_loop_restart` (single-line change in
`function_executor_v3.vhd`). This would make all iterations produce identical ts0 duration
(`time_mem[0] + 1` cycles), matching the first iteration.

**Consequences of fix:**
- The output waveform during infinite-loop mode would change: subsequent iterations' ts0
  would gain 1 cycle, making the loop period 1 cycle longer.
- Regression tests T23 and T24 would need re-baselining to match the new timing.
- Normal (non-looping) execution is unaffected.

**Disposition:** Fix not implemented. The current behaviour is documented and tested
(T23, T24 pass cycle-exact against the existing waveform). Changing the waveform would
require re-validation and could affect any downstream system that depends on the current
infinite-loop timing. The asymmetry is acceptable for production use.

---

## 8. Infinite-loop mechanism

### 8.1 Overview

The sequencer supports an infinite-loop execution mode activated by the `inf_loop` bit in
the FIFO word. When active, the executor repeats the same function indefinitely instead of
advancing to the next FIFO entry. The loop can be stopped or stepped via two control inputs
(`func_stop`, `func_step`), which are driven by either the sync commands
(`sync_cmd_stop`, `sync_cmd_step`) or the register commands (`reg_cmd_stop`,
`reg_cmd_step`) at the top level. `[rtl]`

Infinite-loop mode is **simulation-only** in the current testbench: the stop/step inputs
cannot be driven from an external ILA trigger, so hardware capture (hw_compare.py) is not
applicable. `[sim]`

### 8.2 FIFO word encoding

The `inf_loop` flag occupies **bit [23]** of the resolved 32-bit FIFO word:

```
[31:28] prog_end_opcode   (0xF for end_sequence, 0x0 for all func_call variants)
[27:24] func_id           (F0–F15)
[23]    inf_loop          (1 = infinite loop; 0 = normal single/rep execution)
[22:0]  rep_count         (ignored when inf_loop=1)
```

A `func_call` with `inf_loop=1` is encoded as `0x11800000` for F1 (func_id=1, inf_loop=1,
rep_count=0). The parameter extractor sets this bit from bit [23] of the program word for
opcode 0x1; the bit is preserved through the FIFO unchanged. `[rtl]`

### 8.3 Executor FSM states

The function executor (`function_executor_v3`) has the following additional states beyond
those listed in Section 3.3: `[rtl]`

```
infinite_loop_run       running in infinite-loop mode; watching func_end, func_stop, func_step
infinite_loop_restart   (1 cycle) re-issues func_start to restart the same function
empting_fifo            draining FIFO after stop command; pops end_seq token
```

**State transitions:**

- In `start_func`: if `fifo_param_out[23] = '1'` (inf_loop), executor enters `infinite_loop_run`
  instead of `func_exe`.
- In `infinite_loop_run` + `func_end='1'` + `func_stop='0'` + `func_step='0'`:
  → `infinite_loop_restart` (loop continues).
- In `infinite_loop_run` + `func_end='1'` + `func_stop='1'`:
  → `empting_fifo` (stop path).
- In `infinite_loop_run` + `func_end='1'` + `func_stop='0'` + `func_step='1'`:
  → `start_func` (step path — pops next FIFO entry, which is end_seq).
- In `empting_fifo`: pops FIFO entries until `prog_end_opcode = '1111'` (end_seq token) is
  found; then transitions to `wait_start` via the normal end_sequence path.

**`sequencer_busy`:** Asserted throughout `infinite_loop_run`, `infinite_loop_restart`, and
`empting_fifo`. Drops on the cycle after `end_sequence` fires, as for normal execution. `[rtl]`

### 8.4 `infinite_loop_restart` timing anomaly

When transitioning from `infinite_loop_restart` back to the start of the function, the
executor issues `func_start='1'` **without** asserting `veto_out`. `[rtl]`

In normal function-to-function transitions the `veto_out` signal causes the 2-cycle
`out_ce` freeze (Section 3.5), holding the previous function's last-slice value in
`output_reg` during the boundary. Without this freeze, `output_reg` begins capturing the
restarted function's ts0 value one cycle earlier.

**Consequence:** ts0 of every loop iteration except the very first appears at `sequencer_out`
for **one fewer cycle** than the first-iteration ts0:

| ts0 occurrence | Duration at `sequencer_out` |
|---|---|
| First iteration (normal `start_func`) | `time_mem[0] + 1` cycles |
| Subsequent iterations (`infinite_loop_restart`) | `time_mem[0]` cycles |

For F1 with `time_mem[0x10]=3`: ts0 appears for 4 cycles on iteration 1, then 3 cycles on
all subsequent iterations. See **DISC-012** for root cause analysis and fix disposition.
`[sim]`

### 8.5 Stop path timing (T23)

TB program: `[0] 0x11800000` (func_call F1, inf_loop=1), `[1] 0xF0000000` (end_seq).
F1: ts0=0xCC (time=3), ts1=0xDD (time=5). `sync_cmd_stop` asserted at loop iteration i=30.

The DUT sees `func_stop='1'` at the cycle where `func_end='1'` simultaneously (last cycle of
iter2 ts1, cycle 32 relative to trigger). This causes the immediate transition:
`infinite_loop_run` → `empting_fifo`. `empting_fifo` pops the end_seq token in the same
cycle; the pipeline continues to flush iteration 3's output (CC×4, DD×5) while the executor
is already in `wait_start`. `end_sequence` fires at cycle 41; `sequencer_busy` drops at
cycle 42. `[sim]`

**Iteration naming:** "i=30" is the TB loop variable at which `sync_cmd_stop` is asserted;
the DUT sees it at cycle 32 relative to trigger because of the timing of when the TB drives
the signal relative to when the DUT samples it. The transition occurs at the last cycle of
what the testbench labels iteration 2 (i=2 in the DUT's execution count). `[sim]`

### 8.6 Step path timing (T24)

Same program and F1 as T23. `sync_cmd_step` asserted at the same cycle (cycle 32, `func_end=1`
simultaneously).

RTL path: `infinite_loop_run` + `func_stop='0'` + `func_step='1'` + `func_end='1'`
→ `start_func`. In `start_func` the executor pops the next FIFO entry, which is the
end_seq token. F0 runs normally (ts0×4, ts1×5 for the standard F0 at times=(3,3)).
`end_sequence` fires at cycle 48; `sequencer_busy` drops at cycle 49. `[sim]`

**Distinction from stop path:** The step path completes one additional F0 execution before
ending. The stop path skips F0 and terminates immediately after flushing the remaining
pipeline output. `[sim]`

---

## 9. ADC trigger alignment shifter

### 9.1 Purpose

The `sequencer_aligner_shifter_top` module inserts a programmable delay on bit 12
(`adc_trigger`) relative to all other output bits. The delay is set by `shift_counter`
and defaults to 0 after reset (3-stage pipeline matching all other bits). In scan mode
(Section 9.5), the delay auto-increments after each ADC trigger, sweeping through the
full range of the SRLC32E shift register. `[rtl]`

### 9.2 Path architecture

The module provides two signal paths from the raw sequencer output (`sequencer_unaligned`)
to the final output (`sequencer_out`): `[rtl]`

- **Bits 0–11, 13–31 (all bits except `adc_trigger`):** Fixed 3-stage registered pipeline
  (`sequencer_delay_1` → `sequencer_delay_2` → `sequencer_delay_3`). Delay is always
  exactly 3 cycles.

- **Bit 12 (`adc_trigger`, parameterised as `start_adc_bit=12`):**

  ```
  sequencer_in(12)
    → srl_input_ff        (1 registered stage; added by DISC-005 fix at f875887)
    → SRLC32E chain       (tap depth = shift_counter + 1 registered stages)
    → shift_reg_out_ff    (1 registered stage)
    → sequencer_out(12)
  ```

  Total registered stages for bit 12 = **`shift_counter + 3`**.

At `shift_counter = 0`, bit 12 passes through exactly 3 stages — identical to all other
bits. This is the zero-offset condition established by the DISC-005 fix (`f875887`). Before
that fix, bit 12 had only 2 stages at `shift_counter = 0`, causing a 1-cycle glitch at
transitions. `[rtl][sim]`

### 9.3 Delay formula

Net additional delay on `adc_trigger` relative to all other bits:

```
additional_delay = shift_counter cycles

At 100 MHz (REB_v5 standard target):    additional_delay = shift_counter × 10 ns
At 156.25 MHz (6.4 ns variant):         additional_delay ≈ shift_counter × 6.4 ns
```

At `shift_counter = 0`: additional delay = 0; all 32 bits arrive at `sequencer_out`
simultaneously. This is the normal operating condition. `[rtl][sim]`

### 9.4 Counter structure

`shift_counter` is an **8-bit counter** (values 0–255): `[rtl]`

- **Increment trigger:** A falling-edge detector on the SRLC32E tap output increments the
  counter by 1 on each falling edge of bit 12 at the tap, when `en_shift_counter='1'`
  (i.e. when `enable_conv_shift` is asserted and `sequencer_busy` is high).

- **Reset:** Two independent mechanisms reset `shift_counter` to 0: `[rtl][sim]`
  - `init_conv_shift` (register `0x390008` bit 0) synchronously resets the counter
    directly.
  - `do_reset` (system reset via PGP link-layer reset → `sys_rst`) resets the counter
    through the `reset` port of `generic_counter_comparator_ce_init`.

  *Original note (superseded):* "`do_reset` does NOT reset the counter. See DISC-011."
  That claim was based on incomplete RTL tracing and has been refuted by simulation
  (T32, `sequencer_tb` `d4d238b`) and confirmed by tracing the full reset chain through
  `SystemClock.vhd` → `si5342_multiclock_top.vhd` → `REB_v5_base.vhd:1039`. See
  DISC-011 for the full analysis.

- **Wrap:** The counter wraps silently from 255 to 0. The overflow output (`cnt_end`) is
  left `open` in the instantiation; no interrupt or flag is raised.

- **Maximum delay at 100 MHz:** 255 × 10 ns = **2550 ns**.

### 9.5 Scan mode operation

**Scan mode** is activated by writing `enable_conv_shift='1'` (register `0x390007` bit 0).
In this mode the shift counter auto-increments on each falling edge of bit 12 at the
SRLC32E tap output, so each successive ADC conversion fires one clock cycle later than the
previous one. This is a **calibration sweep**: by running N ADC conversions in scan mode
and observing which produces the best pixel value, the operator finds the optimal
`shift_counter` value for normal operation. `[doc][rtl]`

**Software flow:**

1. Issue `do_reset` (or write `init_conv_shift='1'`) to ensure `shift_counter = 0`.
   *Original note (superseded):* "`init_conv_shift` is required — see DISC-011."
   T32 confirmed that `do_reset` alone suffices; `init_conv_shift` provides a second
   independent path to the same state and remains valid but is not strictly required
   after a system reset.
2. Write `enable_conv_shift='1'` to enable auto-increment.
3. Trigger N ADC conversions (one per sequencer run). The nth conversion fires with an
   additional delay of `(n-1) × T_clk` on `adc_trigger`, as `shift_counter` increments
   from 0 to N-1.
4. Write `enable_conv_shift='0'` to freeze the counter at the chosen value.

**Timing asymmetry within a multi-repetition run:** See **DISC-010**. When the shift
counter is active, the first low-bit-12 timeslice after enabling scan is +1 cycle longer
than nominal; the second is −1 cycle relative to nominal. This is a natural consequence
of the auto-increment design and does not affect the sweep result when using one sequencer
trigger per ADC conversion (the intended flow). `[rtl][sim]`

### 9.6 Normal mode

**Normal mode** (`enable_conv_shift='0'`) is the default operating condition after reset:

- `en_shift_counter` is deasserted; `shift_counter` is frozen.
- At `shift_counter = 0`, all 32 output bits travel through exactly 3 pipeline stages:
  the aligner is **fully transparent**.
- The CCD operator programmes the ADC trigger timing directly into the sequencer output
  memory by assigning the appropriate timeslice values to `adc_trigger`.

All tests T01–T31 in `tb_sequencer.vhd` operate in normal mode with `shift_counter = 0`.
The aligner transparency in this condition is implicitly verified by the cycle-exact output
assertions in all 31 tests and confirmed on hardware. `[sim][hw]`

T31 (`tb_sequencer.vhd`) covers scan mode: it pins the cycle-exact output sequence for a
2-repetition run with `shift_counter` starting at 0, capturing the DISC-010 timing
asymmetry. T31 is simulation-only. `[sim]`

T32 (`tb_sequencer.vhd`) is a two-phase discriminating test for DISC-011: Phase A uses
`init_conv_shift` to reset the counter before scan; Phase B uses `do_reset` only (no
`init_conv_shift`). Both phases assert identical output (`T31_EXP`). PASS on both phases
confirms that `do_reset` resets `shift_counter` to 0. T32 is simulation-only. `[sim]`

### 9.7 Known weaknesses

Two RTL hazards have been identified in `sequencer_aligner_shifter_top.vhd`. Neither
affects normal operation (Section 9.6) or any of the T01–T32 test results, but both are
latent risks during scan-mode operation. `[rtl]`

**W1 — SRLC32E has no reset**

`do_reset` clears `srl_input_ff` (the `ff_ce` instance at the SRLC32E input) but does
**not** flush the SRLC32E shift-register chain. After a reset, the SRLC32E retains its
pre-reset content for `shift_counter + 1` additional clock cycles.

However, the severity is eliminated in practice. `do_reset` resets `shift_counter` to 0
(confirmed by T32 / DISC-011). At counter=0 the SRLC32E drain period is only 1 cycle, during
which `en_shift_counter` is 0 (see W2 below), so no spurious falling edge can increment
the counter. The SRLC32E content is irrelevant because scan mode cannot be active during
the single drain cycle. No RTL fix is required. `[rtl][sim]`

**W2 — `en_shift_counter` idle hazard**

If `enable_conv_shift` were left asserted across a `do_reset`, stale SRLC32E content (W1)
could produce spurious falling edges on the tap output during the drain period, potentially
incrementing `shift_counter`.

However, `do_reset` resets `en_shift_counter` to 0 via the `shift_mode_en_ff` flop (which
has `reset => reset`), regardless of whether the `enable_conv_shift` register was left set
before the reset. The register-write path for `enable_conv_shift` cannot re-assert
`en_shift_counter` until after the reset is released and the host issues a new write. No
RTL fix is required. `[rtl][sim]`

---

## 10. Sequencer program constraints

This section consolidates all constraints that a valid sequencer program must satisfy.
Each constraint references the section where the detailed explanation and evidence can
be found.

### 10.1 Function structure

| # | Constraint | Detail |
|---|---|---|
| C1 | Every function must have **≥ 2 timeslices** (i.e., `time_mem[func_id×16 + 1] ≠ 0`). | A single-slice function triggers the executor's end-of-function guard on the *first* slice, causing a silent skip and permanent hang. See **DISC-003** (Section 7). F0 is additionally constrained by the idle/end_sequence mechanism: **DISC-001** (Section 7). |
| C2 | **Minimum timeslice duration = 2** (i.e., all `time_mem` values that define active slices must be ≥ 2). | The time_mem port A pipeline register requires 1 cycle to present valid data. Duration=1 would be consumed before the registered value settles. See **Section 11.4** (time_mem pipeline register). |
| C3 | F0 must exist and have ≥ 2 slices. | F0 is executed implicitly during `end_sequence` to produce the idle output pattern. See **Section 5.3**, **DISC-001**. |

### 10.2 Subroutine structure

| # | Constraint | Detail |
|---|---|---|
| C4 | A subroutine body must contain **≥ 1 `func_call`** (or equivalent opcode that writes to the FIFO) before the `sub_trailer`. | A body consisting of only a `sub_trailer` hangs the executor — the FIFO never receives a word for the return path. See **DISC-004** (Section 7). |
| C5 | `sub_trailer` bits[27:0] are **don't-care**. Only bits[31:28] = `0xE` are checked. | Hardware ignores the payload. Do not rely on these bits for any purpose. See **DISC-006** (Section 7). |

### 10.3 Nesting depth

| # | Constraint | Detail |
|---|---|---|
| C6 | At nesting depth K, the innermost function(s) must have enough total execution time for the extractor to pre-fill the FIFO before the executor exhausts it. | The safe bound depends on function duration and FIFO depth. At K=4 with single-rep single-func_call bodies, the minimum function duration is ~18 cycles. See **DISC-008** (Section 7). |

### 10.4 Opcodes and addressing

| # | Constraint | Detail |
|---|---|---|
| C7 | All opcode fields (bits[31:28]) must be valid (`0x0`–`0xE`). | An invalid opcode causes a permanent `sequencer_busy` hang with no recovery except external reset. See **DISC-007** (Section 7). |
| C8 | `sync_cmd_main_addr` and `reg_cmd_start` values are **multiplied by 4** to produce the program-word address. The result is a 32-bit word index into `prog_mem`, not a byte address. | Value N starts execution at 32-bit word `N × 4`. See **DISC-009** (Section 7). |

### 10.5 Summary of changes from timing-closure work

Constraint **C2** (minimum timeslice duration = 2) is the only new programming constraint
introduced by the timing-closure modifications (Section 11). All other constraints existed
in the original design.

---

## 11. Timing-closure modifications (6.4 ns target)

This section documents the RTL and verification changes made to close timing for the
`REB_v5_6p4ns_3_seq` target (156.25 MHz, 3 sequencers). All modifications preserve the
cycle-exact output waveform (values and durations from first-output-change through
end_sequence). Only startup latency (trigger to first-output-change) is affected: it
increases by +1 cycle (12 → 13 cycles). `[rtl][sim]`

**Strategy:** The approach was iterative: build the target, identify the critical path from
Vivado timing reports, insert a pipeline register to break that path, validate with
simulation, then build again to reveal the next bottleneck. Each iteration exposed a new
worst path that was hidden behind the previous one.

**Coupling between modifications:** Sections 11.1–11.4 are tightly coupled and cannot be
understood in isolation:

1. The **program memory pipeline register** (11.1) breaks the extractor FSM's critical path
   but adds 1 cycle to every program-word fetch. This widens the timing window in the FIFO
   race condition (11.3), making starvation more likely for short functions.

2. The **subroutine return shortcut** (11.2) compensates by recovering 1 cycle on every
   subroutine trailer return, restoring the pre-modification FIFO margin.

3. After these changes, the next critical path revealed by Vivado was the **time_mem port A
   pipeline register** path (11.4). Registering port A (the lookahead `func_time_in_plus1`)
   breaks this path at the cost of imposing a minimum timeslice duration of 2.

4. The **readback path fix** (11.5) is largely independent — it breaks a path from the
   time_mem LUTRAM to the host register-read output that was only visible after the port A
   pipeline register made the combinational readback output the new worst path.

**Validation methodology:** Each RTL change was validated against two testbenches before
proceeding to the next build:
- `sequencer_tb` (38 tests): confirms cycle-exact output waveform preservation.
- `reg_interface_tb` (14 tests): confirms register read/write correctness.

**Commit map (`lsst_reb` branch `reg-interface`, base = `cc9fb85`):**

| Commit | Message | Section |
|--------|---------|---------|
| `f875887` | seq_aligner_shifter: fix DISC-005 glitch by equalising pipeline depth for bit 12 | DISC-005 |
| `063f938` | Sequencer: replace direct memory ports with req/ack register interface | Prerequisite (register interface refactor) |
| `abe9d17` | Sequencer: expose op_code_error/op_code_error_add as output ports | DISC-007 (testbench observability) |
| `efc73cc` | extractor: pipeline register on program_memory output | **11.1** |
| `6ac0bee` | extractor: optimize rep_sub trailer return (skip write_fifo state) | **11.2** |
| `3f7d2f7` | extractor: add simulation-only debug processes (dbg_proc, dbg_fifo) | **11.4** (supporting) |
| `b6af0e2` | function_v3: pipeline register on time_mem port A (plus1 lookahead) | **11.4** (time_mem register) |
| `6f21aad` | function_v3: use registered time_mem output for readback path | **11.5** |

### 11.1 Program memory pipeline register

**File:** `sequencer_parameter_extractor_top_v4.vhd`

**Change:** A registered copy of the program memory output (`prog_mem_data_r`) is sampled
on every rising clock edge. The extractor FSM reads from this register instead of the raw
LUTRAM (RAMD64E) combinational output. `[rtl]`

```vhdl
process(clk)
begin
  if rising_edge(clk) then
    prog_mem_data_r <= prog_mem_data;
  end if;
end process;
```

**Motivation:** The pre-modification critical path at 6.4 ns was:

```
FIFO BRAM output → time_mem LUTRAM (RAMD64E) → function FSM state register
```

At 100 MHz (10 ns) this path had ~3.5 ns of positive slack. At 156.25 MHz (6.4 ns) it
violated timing by ~0.3 ns. The pipeline register breaks the path between the LUTRAM
output and the FSM decode logic, reducing the number of logic levels from ~8 to ~4 per
half. `[rtl]`

**New FSM state — `fetch`:** The extractor FSM (`parameter_extractor_fsm_v3`) gains a
`fetch` state inserted between address presentation and data consumption. The state
machine now performs: `[rtl]`

```
idle → fetch → decode → [write_fifo | inc_addr | call_sub | ...]
                              ↑                              |
                              └──────── fetch ←──────────────┘
```

Every program word read incurs one additional cycle (the `fetch` wait state) for the
pipeline register to capture the LUTRAM output. This latency is entirely within the
extractor pipeline and is invisible at `sequencer_out`. `[rtl][sim]`

**Impact on startup latency:** +1 cycle. Trigger-to-first-change increases from 12 to 13
cycles (for the baseline N=0 case; deeper nesting adds +2 per level as before per
DISC-008). `[sim]`

**Impact on output waveform:** None. The output sequence (values and durations) from
first-change through end_sequence is bit-identical to the pre-modification baseline for
all 36 regression tests. `[sim]`

### 11.2 Subroutine return shortcut (`rep_sub` → `fetch`)

**File:** `parameter_extractor_fsm_v3.vhd`

**Change:** When the subroutine repetition counter expires (`rep_counter_end='1'`), the
FSM transitions directly from `rep_sub` to `fetch` (with PC incremented past the trailer
word) instead of going through the intermediate `write_fifo` state. The FIFO write-enable
is asserted combinationally during `rep_sub` when `rep_counter_end='1'`, since the data
word (`fifo_param_in`) is already stable at that point. `[rtl]`

**Before:**
```
rep_sub → write_fifo → fetch    (2 cycles from counter-expire to next word read)
```

**After:**
```
rep_sub → fetch                  (1 cycle from counter-expire to next word read)
```

**Motivation:** The pipeline register (Section 11.1) adds 1 cycle to every program word
fetch. Without compensation, this widens the window between the extractor's last FIFO
write and the executor's sampling of `fifo_empty` on the `func_end` pulse. The FIFO race
condition (Section 11.3) would become more likely to trigger for short functions with
few repetitions. The `rep_sub` shortcut recovers 1 cycle per subroutine trailer return,
maintaining the pre-modification margin. `[rtl][sim]`

**Impact on output waveform:** None. The saved cycle is entirely within the extractor
pipeline, before any output is produced. `[sim]`

### 11.3 FIFO race condition (background)

The `FifoSync` module (from `surf`, read-only) uses a **registered `empty` flag** with
2-cycle latency from write assertion to `empty` deassertion at the read port. The function
executor (`function_executor_v3`) checks `fifo_empty` only on the single cycle where
`func_end='1'`. If both events coincide — the extractor writes the next entry, and the
executor samples `fifo_empty` before the write propagates — the executor sees `empty='1'`
and hangs permanently in `wait_fifo` (a state that has no timeout or recovery path). `[rtl]`

**Relationship to Section 11.1:** The pipeline register increases the total time the
extractor spends fetching each program word by 1 cycle. For programs where the extractor
barely finishes writing the next FIFO entry before the executor's `func_end` pulse (the
"just-in-time" case), this extra cycle could push the write past the sampling window.
The `rep_sub` shortcut (Section 11.2) compensates by saving 1 cycle on the return path,
keeping the net margin unchanged. `[rtl]`

**Relationship to DISC-008:** DISC-008 documents the same race for deeply nested
subroutines (N ≥ 4) where the extractor traverses many call/return cycles before writing
the next FIFO entry. The pipeline register does not worsen DISC-008 because the additional
fetch cycle applies uniformly to all word reads, including the nested `call_sub` traversals
that contribute to the nesting overhead. The `rep_sub` shortcut partially improves DISC-008
by reducing the return path, but the fundamental constraint (K ≥ ⌈N × 5 / T_exec⌉) remains
valid with slightly tighter constants. `[rtl][sim]`

### 11.4 Supporting changes

**Time memory port A pipeline register** (`function_v3.vhd`): The time memory's port A
output (indexed by FIFO data, used for the `func_time_in_plus1` lookahead) is registered
as `time_bus_2_int_r`. The function FSM reads from this registered copy for its plus-one
comparison (`ltOp`). This breaks the critical path from FIFO BRAM through the time_mem
LUTRAM to the FSM state register. Port B (the runtime `func_time_in` path, indexed by the
function FSM's own counter) is left combinational to preserve cycle-exact timeslice
durations. `[rtl][sim]`

**Constraint:** Minimum timeslice duration is now 2 (was 1). Duration=1 timeslices would
require the registered port A value to be valid on the same cycle it is written — which
the pipeline register delays by one cycle. No production sequencer programs use duration=1.
Regression test T13 was updated to test the new boundary (t1=2). `[rtl][sim]`

**StatusReg pipeline register** (`REB_v5_base.vhd`): A registered copy of the sequencer
status register output (`StatusReg_r`) breaks a secondary timing path between the
sequencer's combinational status outputs and the register-read multiplexer in the base
module. This path was not on the sequencer's critical path but contributed to timing
pressure in the 3-sequencer configuration. `[rtl]`

**Command interpreter latch fix** (`REB_v5_cmd_interpreter.vhd`): The `seq_wait` signal
was inferred as a latch (assigned in only one branch of a combinational process). Fixed
by adding an explicit default assignment. This is a correctness fix found during timing
review; it does not affect timing directly. `[rtl]`

**Debug process pragma guards** (`parameter_extractor_fsm_v3.vhd`,
`sequencer_parameter_extractor_top_v4.vhd`): Two debug processes (`dbg_proc`, `dbg_fifo`)
that read the FIFO output port — valid in simulation but illegal in synthesis — are wrapped
in `-- pragma translate_off` / `-- pragma translate_on`. This allows the same source file
to serve both simulation and synthesis without maintaining separate copies. `[rtl]`

**Testbench auto-detect latency** (`tb_sequencer.vhd`): Tests T23, T24, T30B, T31, T32A,
and T32B were rewritten to detect the first output change dynamically rather than using a
hardcoded cycle offset. This makes the testbench tolerant of startup-latency changes (such
as the +1 cycle from the pipeline register) while still asserting cycle-exact output
durations. Stop/step commands (T23, T24) are now timed relative to first-change rather
than to an absolute cycle count. `[sim]`

### 11.5 Time memory readback path fix

**File:** `function_v3.vhd`

**Change:** The host-facing readback output `time_mem_out_2` is wired to the registered
copy of the time memory port A output (`time_bus_2_int_r`) rather than the raw LUTRAM
combinational output. `[rtl]`

```vhdl
time_mem_out_2 <= time_bus_2_int_r;   -- registered copy (1-cycle old)
```

**Motivation:** After the port A pipeline register was added (Section 11.4, time_mem
pipeline register), the raw LUTRAM output still fed the readback path. Vivado cannot
statically prove that the sequencer is idle during host register reads, so it reports a
combinational path from the FIFO BRAM output (which drives the time_mem write address
via `time_add_mux`) through the LUTRAM to `reg_rd_data_reg`. This path had only +0.066 ns
slack in build #2. `[rtl]`

**Correctness argument:** The register interface protocol issues the address in the IDLE
cycle and captures the read data in the RESPOND cycle (2 cycles later). The pipeline
register `time_bus_2_int_r` captures the LUTRAM output on the cycle after the address is
presented, so by the time RESPOND samples `time_mem_out_2`, the registered value has been
stable for a full cycle. The sequencer is guaranteed idle during register reads (hardware
protocol enforced by `sequencer_busy` gating in the cmd interpreter). `[rtl]`

**Impact on output waveform:** None. This signal is only read by the host register
interface; the runtime datapath uses `time_bus_2_int` (port B, unregistered) and
`time_bus_2_int_r` (port A, registered) directly within the function FSM. `[rtl][sim]`

### 11.6 Representative build results

Results below are representative of each RTL iteration and illustrate how each change
shifted the critical path. Absolute WNS values vary between builds due to Vivado's
non-deterministic placement and routing.

| Target | Clock | Sequencers | WNS | Critical path | Strategy |
|--------|-------|------------|-----|---------------|----------|
| `REB_v5_6p4ns` (1-seq) | 6.4 ns | 1 | +0.137 ns | (not recorded) | `Performance_Explore` |
| `REB_v5_6p4ns_3_seq` build #1 | 6.4 ns | 3 | +0.089 ns | FIFO BRAM → time_mem LUTRAM → `func_time_add_plus1_reg` | `Performance_Explore` |
| `REB_v5_6p4ns_3_seq` build #2 | 6.4 ns | 3 | +0.066 ns | FIFO BRAM → time_mem LUTRAM port A → `reg_rd_data_reg` | `Performance_Explore` |
| `REB_v5_6p4ns_3_seq` build #3 | 6.4 ns | 3 | +0.126 ns | `pgpRemData` → `RstOut` (fo=8579) → `reg_rd_data_reg` | `Performance_Explore` |

The 1-sequencer build was validated on hardware with functional testing (correct data
volume, no hangs). Dedicated sensor-level testing is required to fully validate the
modified sequencer code. `[hw]`

Build #3 represents the final sequencer RTL. The remaining critical path is in the PGP
infrastructure (`lsst_sci`, read-only) — a reset signal with fanout 8579 feeding into the
register readback mux. The sequencer's own worst path is the function FSM (FIFO BRAM →
time_mem port B → CARRY4 chain → state register) at +0.182 ns. Registering the runtime
time_mem output (port B) would change the output waveform by adding 1 cycle to every
timeslice duration and is therefore rejected. This represents the fundamental architectural
timing floor for the current sequencer design. `[rtl]`
