-- tb_sequencer.vhd
-- Phase 2 characterisation testbench for lsst_reb.Sequencer at f875887.
-- Written from scratch after completion of Phase 1a and Phase 1b analysis.
--
-- Timing model (cc9fb85, confirmed by RTL inspection and simulation):
--
--   Slice durations at sequencer_out (output_reg + 3-stage aligner):
--     Slice 0, not the only slice : time_mem[0] + 1  cycles
--     Middle slice (i>0, not last): time_mem[i]      cycles
--     Last slice (i>0)            : time_mem[i] + 2  cycles
--     Single-slice function       : time_mem[0] + 3  cycles
--
--   Startup latency (trigger -> first-output-change):
--     Direct func_call (opcodes 0x1,0x2,0x3,0x4) : 12 cycles
--     1-level subroutine (opcode 0x5)             : 14 cycles
--     2-level subroutine                          : 16 cycles
--   busy -> first-output-change is always 5 cycles regardless of opcode type.
--   Latency is REPORTED but NOT ASSERTED.
--
--   end_sequence:
--     Fires (1 cycle) on the first cycle of F0's last slice appearance at
--     sequencer_out. sequencer_busy drops the following cycle.
--
-- Opcode encodings (sequencer_v3_package.vhd):
--   0x1 func_call     : bits[31:28]=0x1, bits[27:24]=func_id, bits[22:0]=rep
--   0x2 ind_func_call : bits[31:28]=0x2, bits[27:24]=func_slot, bits[22:0]=rep
--   0x3 ind_rep_call  : bits[31:28]=0x3, bits[27:24]=func_id, bits[3:0]=rep_slot
--   0x4 ind_all_call  : bits[31:28]=0x4, bits[27:24]=func_slot, bits[3:0]=rep_slot
--   0x5 jump_to_add   : bits[31:28]=0x5, bits[25:16]=sub_addr, bits[15:0]=rep
--   0xE sub_trailer   : bits[31:28]=0xE, bits[27:0]=unused (payload ignored by hardware, see DISC-006)
--   0xF end_sequence  : bits[31:28]=0xF
--
-- Memory base addresses (sequencer 0, full 24-bit regAddr):
--   out_mem         : 0x100000  row = regAddr[7:0]
--   time_mem        : 0x200000  row = regAddr[7:0]
--   prog_mem        : 0x300000  row = regAddr[9:0]
--   ind_func_mem    : 0x350000  row = regAddr[3:0]
--   ind_rep_mem     : 0x360000  row = regAddr[3:0]
--   ind_sub_add_mem : 0x370000  row = regAddr[3:0]
--   ind_sub_rep_mem : 0x380000  row = regAddr[3:0]
--
-- Function layout: func_id * 16 = base row in out_mem and time_mem.
--   F0: rows 0x00..0x0F  (idle output = out_mem[0x00]; end_sequence function)
--   F1: rows 0x10..0x1F
--   F2: rows 0x20..0x2F
--   F3: rows 0x30..0x3F
--
-- F0 must always have >= 2 slices (time_mem[0x01] != 0) to avoid executor stall.
--
-- Test list:
--   T01 : func_call(F1,rep=1), 2-slice        -- Phase 1a regression
--   T02 : func_call(F1,rep=1), 3-slice        -- middle-slice duration = time_mem[i]
--   T03 : func_call(F1,rep=1), 4-slice        -- two middle slices
--   T04 : func_call(F1,rep=3), 2-slice        -- repetition counter
--   T05 : func_call(F1,rep=1) then func_call(F2,rep=0) then end_seq -- rep=0 skip
--   T06 : ind_func_call (0x2) -> F1           -- indirect func_id lookup
--   T07 : ind_rep_call  (0x3), F1, rep via indirect -- indirect rep lookup
--   T08 : ind_all_call  (0x4) -> F1           -- both indirect
--   T09 : jump_to_add (0x5), 1-level, rep=1   -- basic subroutine
--   T10 : jump_to_add (0x5), 1-level, rep=2   -- subroutine repetition
--   T10b: jump_to_add (0x5), 1-level, non-adjacent body (addr=4) -- body offset independence
--   T11 : jump_to_add (0x5), 2-level nesting, 2 func_calls in inner body
--   T12 : non-trivial F0 times (t0=4, t1=6)   -- F0 duration formula boundary
--   T13 : minimum-t1 2-slice function (t1=2)  -- min-duration boundary (pipeline reg)
--   T14 : single-slice function hang           -- DISC-003 confirmation
--   T15 : 2-level nesting, 1 func_call in inner body hang -- DISC-004 confirmation
--   T16 : multi-bit transition glitch          -- DISC-005 fix verification
--   T17 : ind_add_jump (0x6), 1-level, rep=1  -- indirect sub address
--   T18 : ind_rep_jump (0x7), 1-level, rep=2 via indirect -- indirect sub rep
--   T19 : ind_all_jump (0x8), 1-level, rep=2 -- both sub addr and rep indirect
--   T20 : jump_to_add (0x5), 3-level nesting -- three levels of subroutine
--   T21 : jump_to_add (0x5), 1-level, sub_trailer[15:0]=0xFFFF -- DISC-006 don't-care
--   T22 : invalid opcode 0xC                 -- DISC-007 op_code_error hang (sim only)
--   T23 : infinite loop + sync_cmd_stop      -- stop during infinite loop (sim only)
--   T24 : infinite loop + sync_cmd_step      -- step during infinite loop (sim only)
--   T25 : sync_cmd_start + reg_cmd_start with non-zero start address
--   T26 : rep=0 skip for sub-jump opcodes 0x5/0x6/0x7/0x8 (combined)
--   T27 : rep=0 skip for indirect func_call opcodes 0x2/0x3/0x4 (combined)
--   T28 : func_call(F1,rep=1), 16-slice function (full function depth)
--   T29 : 4-level subroutine nesting, K=3 innermost func_calls -- DISC-008 boundary

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use STD.TEXTIO.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_reb;
use lsst_reb.SequencerPkg.all;

entity tb_sequencer is
end entity tb_sequencer;

architecture sim of tb_sequencer is

  constant CLK_PERIOD : time := 10 ns;

  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';
  signal done : boolean   := false;

  -- DUT inputs (register interface)
  signal reg_req     : std_logic := '0';
  signal reg_op      : std_logic := '0';
  signal reg_addr    : std_logic_vector(23 downto 0) := (others => '0');
  signal reg_wr_data : std_logic_vector(31 downto 0) := (others => '0');
  signal reg_rd_data : std_logic_vector(31 downto 0);
  signal reg_ack     : std_logic;
  signal reg_fail    : std_logic;

  -- DUT inputs (synchronous command interface)
  signal sync_cmd_start     : std_logic := '0';
  signal sync_cmd_stop      : std_logic := '0';
  signal sync_cmd_step      : std_logic := '0';
  signal sync_cmd_main_addr : std_logic_vector(4 downto 0) := (others => '0');

  -- DUT outputs
  signal sequencer_out  : SequencerOutputArray(1 downto 0);
  signal end_sequence   : std_logic_vector(0 downto 0);
  signal sequencer_busy : std_logic_vector(0 downto 0);
  signal op_code_error     : std_logic_vector(0 downto 0);
  signal op_code_error_add : Slv10Array(0 downto 0);

  -- Packed output for waveform capture and hardware comparison
  signal sequencer_out_slv : std_logic_vector(31 downto 0);

  -- Global cycle counter
  signal cycle_cnt : integer := 0;

  -- Output directory for per-test simulation CSVs (relative to working dir = repo root)
  constant SIM_DATA_DIR : string := "sim_data/";

  -- ── Helper functions ────────────────────────────────────────────────────────

  function to_slv32 (s : SequencerOutputType) return std_logic_vector is
    variable v : std_logic_vector(31 downto 0) := (others => '0');
  begin
    v(0)           := s.aspic_r_up;
    v(1)           := s.aspic_r_down;
    v(2)           := s.aspic_reset;
    v(3)           := s.aspic_clamp;
    v(6 downto 4)  := s.ser_clk;
    v(7)           := s.reset_gate;
    v(11 downto 8) := s.par_clk;
    v(12)          := s.adc_trigger;
    v(13)          := s.soi;
    v(14)          := s.eoi;
    v(15)          := s.cabac_pulse;
    v(16)          := s.pattern_reset;
    v(31)          := s.user_bit;
    return v;
  end function;

  function to_hex8 (v : std_logic_vector(31 downto 0)) return string is
    variable result    : string(1 to 8);
    variable nibble    : std_logic_vector(3 downto 0);
    constant hex_chars : string(1 to 16) := "0123456789ABCDEF";
  begin
    for i in 7 downto 0 loop
      nibble := v(i*4+3 downto i*4);
      if is_x(nibble) then
        result(8-i) := 'X';
      else
        result(8-i) := hex_chars(to_integer(unsigned(nibble)) + 1);
      end if;
    end loop;
    return result;
  end function;

  -- Convert non-negative integer to decimal string (for textio CSV writes)
  function to_dec_str (n : integer) return string is
    variable tmp    : integer := n;
    variable digits : string(1 to 12);
    variable pos    : integer := 12;
    variable ch     : integer;
  begin
    if tmp = 0 then return "0"; end if;
    while tmp > 0 loop
      ch          := tmp mod 10;
      digits(pos) := character'val(character'pos('0') + ch);
      pos         := pos - 1;
      tmp         := tmp / 10;
    end loop;
    return digits(pos+1 to 12);
  end function;

  -- Extract test ID prefix (up to first space or colon) for CSV filename.
  -- e.g. "T10b: ..." -> "T10b",  "T01: ..." -> "T01"
  function test_id (name : string) return string is
    variable len : integer := 0;
  begin
    for i in name'range loop
      exit when name(i) = ':' or name(i) = ' ';
      len := len + 1;
    end loop;
    if len = 0 then return name; end if;
    return name(name'left to name'left + len - 1);
  end function;

begin

  clk <= not clk after CLK_PERIOD/2 when not done else '0';

  process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cycle_cnt <= 0;
      else
        cycle_cnt <= cycle_cnt + 1;
      end if;
    end if;
  end process;

  dut : entity lsst_reb.Sequencer
    generic map (NUM_SENSORS_G => 2, NUM_SEQUENCERS_G => 1)
    port map (
      clk                => clk,
      rst                => rst,
      reg_req            => reg_req,
      reg_op             => reg_op,
      reg_addr           => reg_addr,
      reg_wr_data        => reg_wr_data,
      reg_rd_data        => reg_rd_data,
      reg_ack            => reg_ack,
      reg_fail           => reg_fail,
      sync_cmd_start     => sync_cmd_start,
      sync_cmd_stop      => sync_cmd_stop,
      sync_cmd_step      => sync_cmd_step,
      sync_cmd_main_addr => sync_cmd_main_addr,
      sequencer_busy     => sequencer_busy,
      end_sequence       => end_sequence,
      sequencer_out      => sequencer_out,
      op_code_error      => op_code_error,
      op_code_error_add  => op_code_error_add
    );

  -- Pack sequencer_out(0) record into slv32 for waveform capture
  sequencer_out_slv <= to_slv32(sequencer_out(0));

  -- ── Stimulus process ──────────────────────────────────────────────────────
  process

    -- ── Memory write helpers ─────────────────────────────────────────────────
    -- All memory writes use the reg_req/reg_ack handshake protocol.
    -- Pulse reg_req for 1 cycle; wait for reg_ack (arrives 2 cycles later).

    procedure reg_write (addr : in std_logic_vector(23 downto 0);
                         data : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      reg_addr    <= addr;
      reg_wr_data <= data;
      reg_op      <= '1';
      reg_req     <= '1';
      wait until rising_edge(clk);
      reg_req     <= '0';
      while reg_ack /= '1' loop
        wait until rising_edge(clk);
      end loop;
      wait until rising_edge(clk);
    end procedure;

    procedure write_out_mem (addr : in integer; data : in std_logic_vector(31 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), data);
    end procedure;

    procedure write_time_mem (addr : in integer; data : in std_logic_vector(15 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), x"0000" & data);
    end procedure;

    procedure write_prog_mem (addr : in integer; data : in std_logic_vector(31 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), data);
    end procedure;

    procedure write_ind_func_mem (addr : in integer; data : in std_logic_vector(3 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), x"0000000" & data);
    end procedure;

    procedure write_ind_rep_mem (addr : in integer; data : in std_logic_vector(23 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), x"00" & data);
    end procedure;

    procedure write_ind_sub_add_mem (addr : in integer; data : in std_logic_vector(9 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), std_logic_vector(resize(unsigned(data), 32)));
    end procedure;

    procedure write_ind_sub_rep_mem (addr : in integer; data : in std_logic_vector(15 downto 0)) is
    begin
      reg_write(std_logic_vector(to_unsigned(addr, 24)), x"0000" & data);
    end procedure;

    -- Write override register for one sensor (sensor index 0 or 1).
    -- data(31)='1' activates override; data(12:0) = replacement bits [12:0].
    -- data(31)='0' deactivates override.
    procedure write_override (sensor : in integer; data : in std_logic_vector(31 downto 0)) is
    begin
      reg_write(x"41001" & std_logic_vector(to_unsigned(sensor, 4)), data);
    end procedure;

    -- ── Reset ────────────────────────────────────────────────────────────────
    procedure do_reset is
    begin
      rst <= '1';
      wait for CLK_PERIOD * 5;
      wait until rising_edge(clk);
      rst <= '0';
      wait until rising_edge(clk);
    end procedure;

    -- zero_all_memories removed: each test loads exactly the values it needs.
    -- Contamination is impossible because:
    --   - load_fnX/load_f0 always write a zero sentinel after the last slice,
    --     so stale time_mem values at higher rows are never reached.
    --   - prog_mem: execution stops at end_sequence (0xF opcode); each test
    --     writes end_sequence at the end of its program so stale instructions
    --     beyond that are never decoded.
    --   - indirect memory slots used by each test are distinct (T06 uses
    --     ind_func_mem[2], T07 ind_rep_mem[4], T08 ind_func_mem[3]/[5]).
    -- This eliminates ~160 wait-until-rising_edge calls per test (~2080 total)
    -- that were making the full suite take >30 minutes of real time.

    -- ── Load F0 ──────────────────────────────────────────────────────────────
    -- F0 is the idle function and the end_sequence function.
    -- Must have >= 2 slices. Caller specifies times and values for ts0 and ts1.
    -- A zero sentinel is written at time_mem[0x02].
    -- idle output = out_mem[0x00] = v0.
    procedure load_f0 (
      t0 : in std_logic_vector(15 downto 0);
      t1 : in std_logic_vector(15 downto 0);
      v0 : in std_logic_vector(31 downto 0);
      v1 : in std_logic_vector(31 downto 0)) is
    begin
      write_out_mem (16#100000#, v0);       -- F0 ts0 (idle output)
      write_out_mem (16#100001#, v1);       -- F0 ts1
      write_time_mem(16#200000#, t0);       -- F0 ts0 time
      write_time_mem(16#200001#, t1);       -- F0 ts1 time (must be non-zero)
      write_time_mem(16#200002#, x"0000");  -- F0 sentinel
    end procedure;

    -- ── Load a 2-slice function Fn (func_id=n) ───────────────────────────────
    procedure load_fn2 (
      n  : in integer;
      t0 : in std_logic_vector(15 downto 0);
      t1 : in std_logic_vector(15 downto 0);
      v0 : in std_logic_vector(31 downto 0);
      v1 : in std_logic_vector(31 downto 0)) is
      variable base : integer;
    begin
      base := n * 16;
      write_out_mem (16#100000# + base,     v0);
      write_out_mem (16#100000# + base + 1, v1);
      write_time_mem(16#200000# + base,     t0);
      write_time_mem(16#200000# + base + 1, t1);
      write_time_mem(16#200000# + base + 2, x"0000");
    end procedure;

    -- ── Load a 3-slice function Fn ────────────────────────────────────────────
    procedure load_fn3 (
      n  : in integer;
      t0 : in std_logic_vector(15 downto 0);
      t1 : in std_logic_vector(15 downto 0);
      t2 : in std_logic_vector(15 downto 0);
      v0 : in std_logic_vector(31 downto 0);
      v1 : in std_logic_vector(31 downto 0);
      v2 : in std_logic_vector(31 downto 0)) is
      variable base : integer;
    begin
      base := n * 16;
      write_out_mem (16#100000# + base,     v0);
      write_out_mem (16#100000# + base + 1, v1);
      write_out_mem (16#100000# + base + 2, v2);
      write_time_mem(16#200000# + base,     t0);
      write_time_mem(16#200000# + base + 1, t1);
      write_time_mem(16#200000# + base + 2, t2);
      write_time_mem(16#200000# + base + 3, x"0000");
    end procedure;

    -- ── Load a 4-slice function Fn ────────────────────────────────────────────
    procedure load_fn4 (
      n  : in integer;
      t0 : in std_logic_vector(15 downto 0);
      t1 : in std_logic_vector(15 downto 0);
      t2 : in std_logic_vector(15 downto 0);
      t3 : in std_logic_vector(15 downto 0);
      v0 : in std_logic_vector(31 downto 0);
      v1 : in std_logic_vector(31 downto 0);
      v2 : in std_logic_vector(31 downto 0);
      v3 : in std_logic_vector(31 downto 0)) is
      variable base : integer;
    begin
      base := n * 16;
      write_out_mem (16#100000# + base,     v0);
      write_out_mem (16#100000# + base + 1, v1);
      write_out_mem (16#100000# + base + 2, v2);
      write_out_mem (16#100000# + base + 3, v3);
      write_time_mem(16#200000# + base,     t0);
      write_time_mem(16#200000# + base + 1, t1);
      write_time_mem(16#200000# + base + 2, t2);
      write_time_mem(16#200000# + base + 3, t3);
      write_time_mem(16#200000# + base + 4, x"0000");
    end procedure;

    -- ── Load a 1-slice function Fn ────────────────────────────────────────────
    -- Single-slice: time_mem[base+1] = 0 (sentinel immediately after ts0).
    -- Duration at sequencer_out: time_mem[0] + 3 cycles.
    -- NOTE: this must NOT be F0 (F0 requires 2 slices).
    procedure load_fn1 (
      n  : in integer;
      t0 : in std_logic_vector(15 downto 0);
      v0 : in std_logic_vector(31 downto 0)) is
      variable base : integer;
    begin
      base := n * 16;
      write_out_mem (16#100000# + base,     v0);
      write_time_mem(16#200000# + base,     t0);
      write_time_mem(16#200000# + base + 1, x"0000");  -- sentinel = single-slice guard
    end procedure;

    -- ── Expected sequence arrays ──────────────────────────────────────────────
    -- Max 64 (value, duration) entries. Duration = number of consecutive cycles
    -- sequencer_out equals that value, counted from first-output-change.
    -- Coverage extends up to and including the cycle where end_sequence fires.
    type slv32_arr_t is array (0 to 63) of std_logic_vector(31 downto 0);
    type int_arr_t   is array (0 to 63) of integer;

    -- ── run_test_impl ─────────────────────────────────────────────────────────
    -- Core implementation. Triggers the sequencer (sync or reg path, at any
    -- start address), observes cycle-by-cycle, and checks the output sequence
    -- against the expected (value, duration) pairs.
    -- Cycle-exact from first-output-change to end_sequence (inclusive).
    -- Latency is reported but not asserted.
    --   use_reg   : false = sync_cmd_start path; true = reg_cmd_start path
    --   start_idx : main_addr 5-bit value; prog_mem start word = start_idx * 4
    procedure run_test_impl (
      use_reg   : in boolean;
      start_idx : in integer;
      test_name : in string;
      exp_vals  : in slv32_arr_t;
      exp_durs  : in int_arr_t;
      exp_n     : in integer) is

      variable idle_out           : std_logic_vector(31 downto 0);
      variable cur_out            : std_logic_vector(31 downto 0);
      variable last_out           : std_logic_vector(31 downto 0);
      variable trigger_cycle      : integer;
      variable busy_cycle         : integer;
      variable first_change_cycle : integer;
      variable end_seq_cycle      : integer;
      variable post_end_cnt       : integer;
      variable running            : boolean;
      variable pass               : boolean;
      variable exp_idx            : integer;
      variable exp_pos            : integer;
      variable in_expected        : boolean;

      -- Cycle table (max 512 entries for failure reporting)
      type ct_out_t  is array (0 to 511) of std_logic_vector(31 downto 0);
      type ct_int_t  is array (0 to 511) of integer;
      type ct_sl_t   is array (0 to 511) of std_logic;
      variable ct_out   : ct_out_t;
      variable ct_cycle : ct_int_t;
      variable ct_busy  : ct_sl_t;
      variable ct_end   : ct_sl_t;
      variable ct_n     : integer;

      -- CSV output
      file     csv_file : text;
      variable csv_line : line;

    begin
      idle_out           := to_slv32(sequencer_out(0));
      last_out           := idle_out;
      trigger_cycle      := cycle_cnt;
      busy_cycle         := -1;
      first_change_cycle := -1;
      end_seq_cycle      := -1;
      post_end_cnt       := 0;
      running            := true;
      pass               := true;
      exp_idx            := 0;
      exp_pos            := 0;
      in_expected        := false;
      ct_n               := 0;

      -- Open CSV file and write header
      -- File name is the test ID prefix up to the first space or colon (e.g. "T01", "T10b")
      file_open(csv_file, SIM_DATA_DIR & test_id(test_name) & ".csv", write_mode);
      write(csv_line, string'("sample_idx,busy,end_seq,seq_out"));
      writeline(csv_file, csv_line);

      -- Trigger: sync_cmd_start or reg_cmd_start, at the specified start address
      if not use_reg then
        sync_cmd_start     <= '1';
        sync_cmd_main_addr <= std_logic_vector(to_unsigned(start_idx, 5));
        wait until rising_edge(clk);
        sync_cmd_start     <= '0';
        sync_cmd_main_addr <= (others => '0');
      else
        -- reg_cmd_start via register interface: write to address x"34" with start_idx
        reg_write(x"340000", std_logic_vector(to_unsigned(start_idx, 32)));
      end if;

      while running loop
        wait until rising_edge(clk);
        cur_out := to_slv32(sequencer_out(0));

        if busy_cycle = -1 and sequencer_busy(0) = '1' then
          busy_cycle := cycle_cnt;
        end if;

        if first_change_cycle = -1
           and not is_x(cur_out) and not is_x(last_out)
           and cur_out /= last_out then
          first_change_cycle := cycle_cnt;
          in_expected        := true;
        end if;

        if end_seq_cycle = -1 and end_sequence(0) = '1' then
          end_seq_cycle := cycle_cnt;
        end if;

        -- Record for failure table
        if ct_n < 512 then
          ct_cycle(ct_n) := cycle_cnt;
          ct_out(ct_n)   := cur_out;
          ct_busy(ct_n)  := sequencer_busy(0);
          ct_end(ct_n)   := end_sequence(0);
          ct_n           := ct_n + 1;
        end if;

        -- Write CSV row (trigger-relative sample index)
        write(csv_line, to_dec_str(cycle_cnt - trigger_cycle));
        write(csv_line, string'(","));
        write(csv_line, std_logic'image(sequencer_busy(0))(2));  -- '0' or '1'
        write(csv_line, string'(","));
        write(csv_line, std_logic'image(end_sequence(0))(2));
        write(csv_line, string'(","));
        write(csv_line, to_hex8(cur_out));
        writeline(csv_file, csv_line);

        -- Check expected sequence from first-change to end of last expected entry
        if in_expected and exp_idx < exp_n then
          if cur_out /= exp_vals(exp_idx) then
            pass := false;
          end if;
          exp_pos := exp_pos + 1;
          if exp_pos >= exp_durs(exp_idx) then
            exp_pos := 0;
            exp_idx := exp_idx + 1;
          end if;
        end if;

        last_out := cur_out;

        -- Stop 8 cycles after end_sequence
        if end_seq_cycle /= -1 then
          post_end_cnt := post_end_cnt + 1;
          if post_end_cnt >= 8 then
            running := false;
          end if;
        end if;

        -- Safety timeout
        -- All blocking waits in run_test must have this guard. Never add an
        -- unguarded wait until statement to the testbench.
        if cycle_cnt > trigger_cycle + 600 then
          report "FAIL: " & test_name & " -- TIMEOUT (no end_sequence in 600 cycles)" severity note;
          running := false;
          pass    := false;
        end if;
      end loop;

      -- Check all expected entries were consumed
      if pass and exp_idx /= exp_n then
        pass := false;
        report "FAIL: " & test_name & " -- consumed " & integer'image(exp_idx) &
               " of " & integer'image(exp_n) & " expected segments";
      end if;

      -- Latency summary
      report "--- " & test_name & " ---";
      if busy_cycle /= -1 then
        report "  trigger -> busy            : " &
               integer'image(busy_cycle - trigger_cycle) & " cycles";
      end if;
      if first_change_cycle /= -1 then
        report "  trigger -> first-change    : " &
               integer'image(first_change_cycle - trigger_cycle) & " cycles";
        if busy_cycle /= -1 then
          report "  busy -> first-change       : " &
                 integer'image(first_change_cycle - busy_cycle) & " cycles";
        end if;
      else
        report "  first-output-change: never observed";
      end if;
      if end_seq_cycle /= -1 then
        if busy_cycle /= -1 then
          report "  busy -> end_sequence       : " &
                 integer'image(end_seq_cycle - busy_cycle) & " cycles";
        end if;
        if first_change_cycle /= -1 then
          report "  first-change -> end_seq    : " &
                 integer'image(end_seq_cycle - first_change_cycle) & " cycles";
        end if;
      else
        report "  end_sequence: never observed";
      end if;

      -- Pass / fail
      if pass then
        report "PASS: " & test_name;
      else
        report "FAIL: " & test_name & " -- cycle table:";
        report "  cycle | busy | end | sequencer_out";
        for i in 0 to ct_n - 1 loop
          report "  " & integer'image(ct_cycle(i)) & " | " &
                 std_logic'image(ct_busy(i)) & " | " &
                 std_logic'image(ct_end(i)) & " | 0x" & to_hex8(ct_out(i));
        end loop;
        report "  expected sequence:";
        for i in 0 to exp_n - 1 loop
          report "    [" & integer'image(i) & "] 0x" & to_hex8(exp_vals(i)) &
                 " x " & integer'image(exp_durs(i)) & " cycles";
        end loop;
        report "FAIL: " & test_name severity error;
      end if;

      -- Brief settling gap before next test's do_reset.
      -- Note: sequencer_busy stays high while the sequencer loops on F0 after
      -- end_sequence, so we cannot wait for busy='0' here -- it never comes.
      for i in 1 to 10 loop wait until rising_edge(clk); end loop;

      file_close(csv_file);

    end procedure run_test_impl;

    -- ── run_test (default wrapper: sync trigger, start addr 0) ───────────────
    procedure run_test (
      test_name : in string;
      exp_vals  : in slv32_arr_t;
      exp_durs  : in int_arr_t;
      exp_n     : in integer) is
    begin
      run_test_impl(false, 0, test_name, exp_vals, exp_durs, exp_n);
    end procedure run_test;

    -- ── run_test_at (sync trigger, non-zero start address) ───────────────────
    -- start_idx: main_addr 5-bit value; prog_mem start word = start_idx * 4
    procedure run_test_at (
      start_idx : in integer;
      test_name : in string;
      exp_vals  : in slv32_arr_t;
      exp_durs  : in int_arr_t;
      exp_n     : in integer) is
    begin
      run_test_impl(false, start_idx, test_name, exp_vals, exp_durs, exp_n);
    end procedure run_test_at;

    -- ── run_test_reg (reg_cmd_start trigger, non-zero start address) ─────────
    -- start_idx: regDataWr[4:0] value; prog_mem start word = start_idx * 4
    procedure run_test_reg (
      start_idx : in integer;
      test_name : in string;
      exp_vals  : in slv32_arr_t;
      exp_durs  : in int_arr_t;
      exp_n     : in integer) is
    begin
      run_test_impl(true, start_idx, test_name, exp_vals, exp_durs, exp_n);
    end procedure run_test_reg;

    -- ── Working arrays for expected sequences ────────────────────────────────
    variable ev : slv32_arr_t;
    variable ed : int_arr_t;
    variable en : integer;

    -- ── T14 working variables ─────────────────────────────────────────────────
    variable t14_busy_ok   : boolean;
    variable t14_end_seen  : boolean;
    variable t14_busy_lost : boolean;

    -- ── Hang-test CSV helpers ─────────────────────────────────────────────────
    file     hang_csv_file  : text;
    variable hang_csv_line  : line;
    variable hang_trig_cyc  : integer;

    -- ── T23/T24 expected output arrays ───────────────────────────────────────
    -- Index 0 = cycle 2 relative to trigger (first sample in observation loop).
    -- T23: 41 samples (cycles 2-42)
    type t23_exp_t is array (0 to 40) of std_logic_vector(31 downto 0);
    constant T23_EXP : t23_exp_t := (
      x"00000001", x"00000001", x"00000001", x"00000001", x"00000001",  -- cyc  2- 6
      x"00000001", x"00000001", x"00000001", x"00000001", x"00000001",  -- cyc  7-11
      x"000000CC", x"000000CC", x"000000CC", x"000000CC",               -- cyc 12-15
      x"000000DD", x"000000DD", x"000000DD", x"000000DD",               -- cyc 16-19
      x"000000DD", x"000000DD", x"000000DD",                            -- cyc 20-22
      x"000000CC", x"000000CC", x"000000CC",                            -- cyc 23-25
      x"000000DD", x"000000DD", x"000000DD", x"000000DD",               -- cyc 26-29
      x"000000DD", x"000000DD", x"000000DD",                            -- cyc 30-32
      x"000000CC", x"000000CC", x"000000CC", x"000000CC",               -- cyc 33-36
      x"000000DD", x"000000DD", x"000000DD", x"000000DD", x"000000DD",  -- cyc 37-41
      x"000000DD"                                                        -- cyc 42
    );
    variable t23_pass      : boolean;
    variable t23_end_cycle : integer;
    variable t23_busy_drop : integer;
    variable t23_busy_seen : boolean;
    -- T24: 48 samples (cycles 2-49)
    type t24_exp_t is array (0 to 47) of std_logic_vector(31 downto 0);
    constant T24_EXP : t24_exp_t := (
      x"00000001", x"00000001", x"00000001", x"00000001", x"00000001",  -- cyc  2- 6
      x"00000001", x"00000001", x"00000001", x"00000001", x"00000001",  -- cyc  7-11
      x"000000CC", x"000000CC", x"000000CC", x"000000CC",               -- cyc 12-15
      x"000000DD", x"000000DD", x"000000DD", x"000000DD",               -- cyc 16-19
      x"000000DD", x"000000DD", x"000000DD",                            -- cyc 20-22
      x"000000CC", x"000000CC", x"000000CC",                            -- cyc 23-25
      x"000000DD", x"000000DD", x"000000DD", x"000000DD",               -- cyc 26-29
      x"000000DD", x"000000DD", x"000000DD",                            -- cyc 30-32
      x"000000CC", x"000000CC", x"000000CC", x"000000CC",               -- cyc 33-36
      x"000000DD", x"000000DD", x"000000DD", x"000000DD",               -- cyc 37-40
      x"000000DD", x"000000DD", x"000000DD",                            -- cyc 41-43
      x"00000001", x"00000001", x"00000001", x"00000001",               -- cyc 44-47
      x"00000002",                                                       -- cyc 48
      x"00000002"                                                        -- cyc 49
    );
    variable t24_pass      : boolean;
    variable t24_end_cycle : integer;
    variable t24_busy_drop : integer;
    variable t24_busy_seen : boolean;

    -- ── T30 working variables ─────────────────────────────────────────────────
    variable t30_pass         : boolean;
    variable t30_out0         : std_logic_vector(31 downto 0);
    variable t30_out1         : std_logic_vector(31 downto 0);
    variable t30_end_seen     : boolean;
    variable t30_end_cycle    : integer;

    -- T30 Phase B: expected sensor 0 output (20 cycles, first-change to end_seq inclusive)
    -- F1 ts0 = 0x00000100 x4, F1 ts1 = 0x00000200 x7, F0_V0 x4, F0_V1 x5
    type t30_exp_t is array (0 to 19) of std_logic_vector(31 downto 0);
    constant T30B_EXP0 : t30_exp_t := (
      x"00000100", x"00000100", x"00000100", x"00000100",   -- F1 ts0 (4 cyc)
      x"00000200", x"00000200", x"00000200", x"00000200",   -- F1 ts1 (7 cyc)
      x"00000200", x"00000200", x"00000200",
      x"00000001", x"00000001", x"00000001", x"00000001",   -- F0 ts0 (4 cyc)
      x"00000002", x"00000002", x"00000002", x"00000002",   -- F0 ts1 (5 cyc)
      x"00000002"
    );
    -- Sensor 1 Phase B: override active (bit31=1, bits[12:0]=0x1234 → 0x00001234 throughout)
    -- bits[31:13] = 0 for all values used in this test (all values < 0x2000)
    constant T30B_EXP1 : std_logic_vector(31 downto 0) := x"00001234";

    -- ── T31 working variables ─────────────────────────────────────────────────
    variable t31_pass         : boolean;
    variable t31_out0         : std_logic_vector(31 downto 0);
    variable t31_end_seen     : boolean;
    variable t31_end_cycle    : integer;
    variable t31_busy_drop    : integer;
    variable t31_busy_seen    : boolean;

    -- ── T32 working variables ─────────────────────────────────────────────────
    -- T32 uses two phases (A and B); both compare against T31_EXP.
    variable t32_pass           : boolean;
    variable t32_out0           : std_logic_vector(31 downto 0);
    variable t32_end_seen_a     : boolean;
    variable t32_end_cycle_a    : integer;
    variable t32_busy_drop_a    : integer;
    variable t32_busy_seen_a    : boolean;
    variable t32_end_seen_b     : boolean;
    variable t32_end_cycle_b    : integer;
    variable t32_busy_drop_b    : integer;
    variable t32_busy_seen_b    : boolean;

    -- T31 expected output sequence (23 cycles, first-change to end_seq inclusive)
    -- Derived from exploration run (shift mode enabled, counter starts at 0,
    -- func_call(F1,rep=2) with F1: ts0=0x00001100 (bit12,bit8), ts1=0x00000100 (bit8), t0=3,t1=3)
    --
    -- Behaviour: counter=0 during iter1 ts0 → no delay.
    --   After iter1 ts0 falls (bit-12 drop), counter→1 (1 extra stage for bit 12).
    --   Iter1 ts1 appears 1 cycle late (bit-12 drop delayed) → ts1 = t1+2+1 = 6 cycles.
    --   Iter2 ts0 both start and end delayed by same amount → duration unchanged = t0+1 = 4 cycles.
    --   After iter2 ts0 falls, counter→2.
    --   Iter2 ts1 start delayed by 2, but end also delayed by 2 → duration net = t1+2-2 = 3 cycles?
    --   Actually simulation shows ts1 iter2 = 4 cycles.  Trust the simulation.
    --   F0 ts0 (first): 4 cycles (no bit12 in F0 values → no shift effect).
    --   F0 ts1 (last): end_seq fires on first cycle of F0_V1 appearance.
    type t31_exp_t is array (0 to 22) of std_logic_vector(31 downto 0);
    constant T31_EXP : t31_exp_t := (
      x"00001100", x"00001100", x"00001100", x"00001100",   -- iter1 ts0: 4 cyc (counter=0)
      x"00000100", x"00000100", x"00000100", x"00000100",   -- iter1 ts1: 6 cyc (counter→1)
      x"00000100", x"00000100",
      x"00001100", x"00001100", x"00001100", x"00001100",   -- iter2 ts0: 4 cyc
      x"00000100", x"00000100", x"00000100", x"00000100",   -- iter2 ts1: 4 cyc (counter→2)
      x"00000001", x"00000001", x"00000001", x"00000001",   -- F0 ts0:    4 cyc
      x"00000002"                                            -- F0 ts1:    1 cyc (end_seq)
    );
    -- ── Standard F0 parameters (used across all tests) ───────────────────────
    -- F0: ts0=0x00000001 (idle indicator), ts1=0x00000002
    -- times: t0=3, t1=3
    -- Durations at sequencer_out:
    --   F0 ts0 (first): 3+1 = 4 cycles
    --   F0 ts1 (last) : 3+2 = 5 cycles
    -- end_sequence fires on the first cycle of F0 ts1's appearance.
    constant F0_V0 : std_logic_vector(31 downto 0) := x"00000001";
    constant F0_V1 : std_logic_vector(31 downto 0) := x"00000002";
    constant F0_T0 : std_logic_vector(15 downto 0) := x"0003";
    constant F0_T1 : std_logic_vector(15 downto 0) := x"0003";
    -- F0 expected contribution to every test's expected sequence (end of program):
    --   F0_V0 x 4, F0_V1 x 5

  begin

    -- ======================================================================
    -- T01 : func_call(F1,rep=1), 2-slice  [Phase 1a regression]
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program: [0]=func_call(F1,rep=1)=0x11000001, [1]=end_seq=0xF0000000
    --
    -- Timing model:
    --   F1 ts0 (first): 3+1 = 4 cycles
    --   F1 ts1 (last) : 5+2 = 7 cycles
    --   F0 ts0 (first): 3+1 = 4 cycles
    --   F0 ts1 (last) : 3+2 = 5 cycles
    --
    -- Expected (first-change to end_seq inclusive):
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0
    ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1
    ev(2) := F0_V0;        ed(2) := 4;   -- F0 ts0
    ev(3) := F0_V1;        ed(3) := 5;   -- F0 ts1
    en := 4;
    run_test("T01: func_call(F1,rep=1) 2-slice [Phase 1a regression]", ev, ed, en);

    -- ======================================================================
    -- T02 : func_call(F1,rep=1), 3-slice  [middle-slice = time_mem[i]]
    --
    -- F1: ts0=0xAA, ts1=0xBB, ts2=0xCC, times=(3,6,5)
    -- Program: [0]=func_call(F1,rep=1)=0x11000001, [1]=end_seq
    --
    -- Timing model:
    --   F1 ts0 (first) : 3+1 = 4 cycles
    --   F1 ts1 (middle): 6   = 6 cycles  ← NOT 6+1
    --   F1 ts2 (last)  : 5+2 = 7 cycles
    --   F0 ts0 (first) : 4 cycles
    --   F0 ts1 (last)  : 5 cycles
    --
    -- Expected:
    --   0xAA x 4, 0xBB x 6, 0xCC x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn3(1, x"0003", x"0006", x"0005",
                x"000000AA", x"000000BB", x"000000CC");
    write_prog_mem(16#300000#, x"11000001");
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000AA"; ed(0) := 4;   -- F1 ts0 (first)
    ev(1) := x"000000BB"; ed(1) := 6;   -- F1 ts1 (middle)
    ev(2) := x"000000CC"; ed(2) := 7;   -- F1 ts2 (last)
    ev(3) := F0_V0;        ed(3) := 4;
    ev(4) := F0_V1;        ed(4) := 5;
    en := 5;
    run_test("T02: func_call(F1,rep=1) 3-slice [middle=time_mem[i]]", ev, ed, en);

    -- ======================================================================
    -- T03 : func_call(F1,rep=1), 4-slice  [two middle slices]
    --
    -- F1: ts0=0xAA, ts1=0xBB, ts2=0xCC, ts3=0xDD, times=(3,4,5,6)
    -- Program: [0]=func_call(F1,rep=1)=0x11000001, [1]=end_seq
    --
    -- Timing model:
    --   F1 ts0 (first)   : 3+1 = 4 cycles
    --   F1 ts1 (middle)  : 4   = 4 cycles
    --   F1 ts2 (middle)  : 5   = 5 cycles
    --   F1 ts3 (last)    : 6+2 = 8 cycles
    --   F0 ts0 (first)   : 4 cycles
    --   F0 ts1 (last)    : 5 cycles
    --
    -- Expected:
    --   0xAA x 4, 0xBB x 4, 0xCC x 5, 0xDD x 8, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn4(1, x"0003", x"0004", x"0005", x"0006",
                x"000000AA", x"000000BB", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11000001");
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000AA"; ed(0) := 4;   -- F1 ts0 (first)
    ev(1) := x"000000BB"; ed(1) := 4;   -- F1 ts1 (middle)
    ev(2) := x"000000CC"; ed(2) := 5;   -- F1 ts2 (middle)
    ev(3) := x"000000DD"; ed(3) := 8;   -- F1 ts3 (last)
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T03: func_call(F1,rep=1) 4-slice [two middle slices]", ev, ed, en);

    -- ======================================================================
    -- T04 : func_call(F1,rep=3), 2-slice  [repetition counter]
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program: [0]=func_call(F1,rep=3)=0x11000003, [1]=end_seq
    --
    -- Each repetition: ts0=4 cycles, ts1=7 cycles.
    -- No gap expected between repetitions (executor goes directly from
    -- func_rep back into func_exe for the next rep).
    --
    -- Expected:
    --   0xCC x 4, 0xDD x 7,  (rep 1)
    --   0xCC x 4, 0xDD x 7,  (rep 2)
    --   0xCC x 4, 0xDD x 7,  (rep 3)
    --   0x01 x 4, 0x02 x 5   (F0)
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11000003");  -- func_call(F1,rep=3)
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := x"000000CC"; ed(2) := 4;
    ev(3) := x"000000DD"; ed(3) := 7;
    ev(4) := x"000000CC"; ed(4) := 4;
    ev(5) := x"000000DD"; ed(5) := 7;
    ev(6) := F0_V0;        ed(6) := 4;
    ev(7) := F0_V1;        ed(7) := 5;
    en := 8;
    run_test("T04: func_call(F1,rep=3) 2-slice [repetition counter]", ev, ed, en);

    -- ======================================================================
    -- T05 : func_call(F1,rep=1), then func_call(F2,rep=0), then end_seq
    --       [rep=0 skips instruction]
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- F2: ts0=0xEE, ts1=0xFF, times=(4,4)  (should never appear in output)
    -- Program:
    --   [0] func_call(F1,rep=1) = 0x11000001
    --   [1] func_call(F2,rep=0) = 0x12000000  <- rep=0, must be skipped
    --   [2] end_sequence        = 0xF0000000
    --
    -- Expected: same as T01 (F2 never appears).
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    load_fn2(2, x"0004", x"0004", x"000000EE", x"000000FF");
    write_prog_mem(16#300000#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300001#, x"12000000");  -- func_call(F2,rep=0) -- skipped
    write_prog_mem(16#300002#, x"F0000000");  -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T05: func_call(F1)+func_call(F2,rep=0)+end_seq [rep=0 skip]", ev, ed, en);

    -- ======================================================================
    -- T06 : ind_func_call (opcode 0x2), indirect func_id -> F1
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- ind_func_mem[2] = func_id=1
    -- Instruction: bits[31:28]=0x2, bits[27:24]=slot=2, bits[22:0]=rep=1
    --   = 0x22000001
    -- Program: [0]=0x22000001, [1]=end_seq
    --
    -- Expected: same output timing as direct func_call(F1,rep=1).
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_ind_func_mem(16#350002#, x"1");     -- ind_func_mem[2] = func_id=1
    write_prog_mem(16#300000#, x"22000001");  -- ind_func_call slot=2, rep=1
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T06: ind_func_call slot=2->F1 [indirect func_id]", ev, ed, en);

    -- ======================================================================
    -- T07 : ind_rep_call (opcode 0x3), direct func_id=1, rep via indirect
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- ind_rep_mem[4] = rep=2
    -- Instruction: bits[31:28]=0x3, bits[27:24]=func_id=1, bits[3:0]=rep_slot=4
    --   = 0x31000004
    -- Program: [0]=0x31000004, [1]=end_seq
    --
    -- Expected: F1 plays twice.
    --   0xCC x 4, 0xDD x 7, 0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_ind_rep_mem(16#360004#, x"000002");  -- ind_rep_mem[4] = rep=2
    write_prog_mem(16#300000#, x"31000004");   -- ind_rep_call func_id=1, slot=4
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := x"000000CC"; ed(2) := 4;
    ev(3) := x"000000DD"; ed(3) := 7;
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T07: ind_rep_call F1 slot=4->rep=2 [indirect rep]", ev, ed, en);

    -- ======================================================================
    -- T08 : ind_all_call (opcode 0x4), both func_id and rep indirect
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- ind_func_mem[3] = func_id=1
    -- ind_rep_mem[5]  = rep=1
    -- Instruction: bits[31:28]=0x4, bits[27:24]=func_slot=3, bits[3:0]=rep_slot=5
    --   = 0x43000005
    -- Program: [0]=0x43000005, [1]=end_seq
    --
    -- Expected: same as T01 (F1 once).
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_ind_func_mem(16#350003#, x"1");      -- ind_func_mem[3] = func_id=1
    write_ind_rep_mem (16#360005#, x"000001"); -- ind_rep_mem[5]  = rep=1
    write_prog_mem(16#300000#, x"43000005");   -- ind_all_call func_slot=3, rep_slot=5
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T08: ind_all_call slot=3->F1 slot=5->rep=1 [both indirect]", ev, ed, en);

    -- ======================================================================
    -- T09 : jump_to_add (0x5), 1-level subroutine, runs once
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program:
    --   [0] jump_to_add(addr=2, rep=1) = 0x50020001
    --   [1] end_sequence               = 0xF0000000
    --   [2] func_call(F1,rep=1)        = 0x11000001
    --   [3] sub_trailer(rep=1)         = 0xE0000001
    --
    -- Output timing: identical to T01 (same F1, same F0).
    -- Latency: 14 cycles (2 more than direct func_call).
    --
    -- Expected:
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"50020001");  -- jump_to_add(addr=2, rep=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    write_prog_mem(16#300002#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300003#, x"E0000001");  -- sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T09: jump_to_add 1-level rep=1 [basic subroutine]", ev, ed, en);

    -- ======================================================================
    -- T10 : jump_to_add (0x5), 1-level, subroutine body repeats 2×
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program:
    --   [0] jump_to_add(addr=2, rep=2) = 0x50020002
    --   [1] end_sequence               = 0xF0000000
    --   [2] func_call(F1,rep=1)        = 0x11000001
    --   [3] sub_trailer(rep=2)         = 0xE0000002
    --
    -- The subroutine body ([2]..[3]) executes twice before returning to [1].
    -- F1 therefore plays twice.
    --
    -- Expected:
    --   0xCC x 4, 0xDD x 7,  (F1 rep 1 inside sub)
    --   0xCC x 4, 0xDD x 7,  (F1 rep 1 inside sub, second iteration)
    --   0x01 x 4, 0x02 x 5   (F0)
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"50020002");  -- jump_to_add(addr=2, rep=2)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    write_prog_mem(16#300002#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300003#, x"E0000002");  -- sub_trailer(rep=2)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := x"000000CC"; ed(2) := 4;
    ev(3) := x"000000DD"; ed(3) := 7;
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T10: jump_to_add 1-level rep=2 [subroutine repeats]", ev, ed, en);

    -- ======================================================================
    -- T10b : jump_to_add (0x5), 1-level, non-adjacent body (addr=4)
    --
    -- Same as T09 but the subroutine body is placed at address 4 (not 2),
    -- with gaps at [2] and [3].  This isolates whether a non-zero jump target
    -- address affects the return-address encoding in the sub-stack.
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program:
    --   [0] jump_to_add(addr=4, rep=1) = 0x50040001
    --   [1] end_sequence               = 0xF0000000
    --   [2] unused                     = 0x00000000
    --   [3] unused                     = 0x00000000
    --   [4] func_call(F1,rep=1)        = 0x11000001
    --   [5] sub_trailer(rep=1)         = 0xE0000001
    --
    -- Expected: same as T09.
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"50040001");  -- jump_to_add(addr=4, rep=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    write_prog_mem(16#300002#, x"00000000");  -- unused
    write_prog_mem(16#300003#, x"00000000");  -- unused
    write_prog_mem(16#300004#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300005#, x"E0000001");  -- sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T10b: jump_to_add 1-level addr=4 [non-adjacent body]", ev, ed, en);

    -- ======================================================================
    -- T11 : jump_to_add (0x5), 2-level nesting  [DISC-004]
    --
    -- The inner subroutine body must contain >= 2 func_calls before its
    -- sub_trailer (DISC-004).  This test uses the minimum working case:
    -- F1 then F2 in the inner body.
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- F2: ts0=0xEE, ts1=0xFF, times=(3,5)
    -- Program:
    --   [0] jump_to_add(addr=4, rep=1) = 0x50040001  outer jump
    --   [1] end_sequence               = 0xF0000000
    --   [4] jump_to_add(addr=6, rep=1) = 0x50060001  inner jump (outer body)
    --   [5] sub_trailer(rep=1)         = 0xE0000001  outer trailer
    --   [6] func_call(F1,rep=1)        = 0x11000001  } inner body
    --   [7] func_call(F2,rep=1)        = 0x12000001  } (2 calls required)
    --   [8] sub_trailer(rep=1)         = 0xE0000001  inner trailer
    --
    -- Execution: [0] -> [4] -> [6] -> F1 -> F2 -> [8] trailer -> [5]
    --            trailer -> [1] -> end_seq
    --
    -- Latency (observed): trigger->first-change = 16 cycles (2-level nesting baseline).
    -- Note: SEQUENCER_THEORY.md Section 4.2 predicted 16 cycles for 2-level
    -- nesting; this matches exactly. `[sim]`
    --
    -- Expected:
    --   0xCC x 4, 0xDD x 7,  (F1)
    --   0xEE x 4, 0xFF x 7,  (F2)
    --   0x01 x 4, 0x02 x 5   (F0)
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");
    write_prog_mem(16#300000#, x"50040001");  -- outer jump to addr=4, rep=1
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    write_prog_mem(16#300004#, x"50060001");  -- inner jump to addr=6, rep=1
    write_prog_mem(16#300005#, x"E0000001");  -- outer sub_trailer(rep=1)
    write_prog_mem(16#300006#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300007#, x"12000001");  -- func_call(F2,rep=1)
    write_prog_mem(16#300008#, x"E0000001");  -- inner sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0 (first)
    ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1 (last)
    ev(2) := x"000000EE"; ed(2) := 4;   -- F2 ts0 (first)
    ev(3) := x"000000FF"; ed(3) := 7;   -- F2 ts1 (last)
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T11: jump_to_add 2-level nesting, 2 func_calls in inner body [DISC-004]", ev, ed, en);

    -- ======================================================================
    -- T12 : Non-trivial F0 — distinct ts0/ts1 output values, non-standard times
    --
    -- Goal: confirm F0 slice duration formula with times other than the
    -- standard (3,3) used in all other tests.
    --
    -- F0: ts0=0x00000100 (par_clk[0]), ts1=0x00000200 (par_clk[1]), times=(4,6)
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program: [0]=func_call(F1,rep=1), [1]=end_seq
    --
    -- F0 durations:
    --   F0 ts0 (first): 4+1 = 5 cycles
    --   F0 ts1 (last) : 6+2 = 8 cycles
    --
    -- Single-bit F0 values are used to avoid multi-bit transition glitches in
    -- the aligner pipeline (empirically: glitches appear when raw out_mem values
    -- have many simultaneous bit transitions; single-bit values produce clean
    -- output, as confirmed by T01--T11).
    --
    -- Settling note: T12 uses an F0 idle value that differs from the previous
    -- test's F0_V0. We wait 20 cycles after memory load so idle_out captured
    -- by run_test equals the new F0 ts0 value, preventing spurious first-change
    -- detection before the sequencer actually starts.
    --
    -- Expected:
    --   0xCC x 4, 0xDD x 7,          (F1)
    --   0x00000100 x 5, 0x00000200 x 8  (F0 ts0 first, ts1 last)
    -- ======================================================================
    do_reset;

    load_f0(x"0004", x"0006", x"00000100", x"00000200");
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11000001");
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 20 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := x"00000100"; ed(2) := 5;   -- F0 ts0 (first): 4+1
    ev(3) := x"00000200"; ed(3) := 8;   -- F0 ts1 (last) : 6+2
    en := 4;
    run_test("T12: non-trivial F0 times t0=4 t1=6 [5+8 cycle durations]", ev, ed, en);

    -- ======================================================================
    -- T13 : Minimum-t1 2-slice function  [last-slice boundary, t1=2]
    --
    -- Tests the minimum timeslice duration boundary: time_mem >= 2 required
    -- after the time_mem pipeline register was added to function_v3.vhd.
    -- With t1=2, the last slice should appear for exactly 4 cycles.
    -- (t1=1 is no longer valid; see DISC-003 for t1=0 hang condition.)
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,2)
    -- Program: [0]=func_call(F1,rep=1), [1]=end_seq
    --
    -- Timing model:
    --   F1 ts0 (first): 3+1 = 4 cycles
    --   F1 ts1 (last) : 2+2 = 4 cycles  ← new minimum boundary
    --   F0 ts0 (first): 4 cycles
    --   F0 ts1 (last) : 5 cycles
    --
    -- Expected:
    --   0xCC x 4, 0xDD x 4, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0002", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11000001");
    write_prog_mem(16#300001#, x"F0000000");
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0 (first): 3+1
    ev(1) := x"000000DD"; ed(1) := 4;   -- F1 ts1 (last) : 2+2  new minimum
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T13: minimum-t1 2-slice F1 [last-slice boundary t1=2]", ev, ed, en);

    -- ======================================================================
    -- T14 : Single-slice function hang confirmation  [DISC-003]
    --
    -- Verifies that a function with time_mem[base+1]=0 causes the executor
    -- to hang: end_sequence never fires and sequencer_busy stays high.
    --
    -- F1: ts0=0xCC only (time_mem[0x10]=5, time_mem[0x11]=0 — sentinel).
    -- F0: standard 2-slice (required for F0; F1 will never complete anyway).
    -- Program: [0]=func_call(F1,rep=1), [1]=end_seq
    --
    -- Expected behaviour (DISC-003):
    --   function_fsm_v3.wait_start sees func_time_in_plus1=0 on start_function,
    --   stays in wait_start, never asserts function_end. Executor stalls in
    --   func_exe. sequencer_busy stays '1'. end_sequence never fires.
    --
    -- PASS criterion: end_sequence='0' for all 100 cycles after trigger,
    --   AND sequencer_busy='1' throughout (after the initial busy-assertion
    --   latency of 7 cycles).
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn1(1, x"0005", x"000000CC");   -- single-slice: sentinel at time_mem[0x11]=0
    write_prog_mem(16#300000#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence (should never be reached)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- Trigger
    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Wait for busy to assert (up to 20 cycles), then observe 100 cycles
    t14_busy_ok   := false;
    t14_end_seen  := false;
    t14_busy_lost := false;

    -- Open CSV
    hang_trig_cyc := cycle_cnt;
    file_open(hang_csv_file, SIM_DATA_DIR & "T14.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    -- Wait for busy
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(sequencer_out_slv));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then
        t14_busy_ok := true;
        exit;
      end if;
    end loop;

    if not t14_busy_ok then
      report "FAIL: T14: single-slice hang [DISC-003] -- sequencer_busy never asserted";
      report "FAIL: T14: single-slice hang [DISC-003]" severity error;
    else
      -- Observe 100 more cycles; busy must stay high, end_sequence must stay low
      for i in 1 to 100 loop
        wait until rising_edge(clk);
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(sequencer_out_slv));
        writeline(hang_csv_file, hang_csv_line);
        if end_sequence(0) = '1' then
          t14_end_seen := true;
        end if;
        if sequencer_busy(0) = '0' then
          t14_busy_lost := true;
        end if;
      end loop;

      if t14_end_seen then
        report "FAIL: T14: single-slice hang [DISC-003] -- end_sequence unexpectedly fired";
        report "FAIL: T14: single-slice hang [DISC-003]" severity error;
      elsif t14_busy_lost then
        report "FAIL: T14: single-slice hang [DISC-003] -- sequencer_busy deasserted unexpectedly";
        report "FAIL: T14: single-slice hang [DISC-003]" severity error;
      else
        report "PASS: T14: single-slice hang [DISC-003]";
      end if;
    end if;

    file_close(hang_csv_file);

    -- ======================================================================
    -- T15 : 2-level nesting, 1 func_call in inner body — hang  [DISC-004]
    --
    -- Confirms that DISC-004 applies even when the 1-func_call body is nested
    -- two levels deep.  The outer body (addr=4) contains an inner jump whose
    -- body (addr=6) holds exactly 1 func_call before its sub_trailer.
    --
    -- Program:
    --   [0] jump_to_add(addr=4, rep=1) = 0x50040001  outer jump
    --   [1] end_sequence               = 0xF0000000  (never reached)
    --   [4] jump_to_add(addr=6, rep=1) = 0x50060001  inner jump (outer body)
    --   [5] sub_trailer(rep=1)         = 0xE0000001  outer trailer
    --   [6] func_call(F1,rep=1)        = 0x11000001  only 1 func_call
    --   [7] sub_trailer(rep=1)         = 0xE0000001  inner trailer
    --
    -- PASS criterion: end_sequence='0' for all 100 cycles after trigger,
    --   AND sequencer_busy='1' throughout (after the initial busy-assertion
    --   latency of 7 cycles).
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"50040001");  -- outer jump to addr=4, rep=1
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence (never reached)
    write_prog_mem(16#300004#, x"50060001");  -- inner jump to addr=6, rep=1
    write_prog_mem(16#300005#, x"E0000001");  -- outer sub_trailer(rep=1)
    write_prog_mem(16#300006#, x"11000001");  -- func_call(F1,rep=1) — only 1
    write_prog_mem(16#300007#, x"E0000001");  -- inner sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- Trigger
    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Wait for busy to assert (up to 20 cycles), then observe 100 cycles
    t14_busy_ok   := false;
    t14_end_seen  := false;
    t14_busy_lost := false;

    -- Open CSV
    hang_trig_cyc := cycle_cnt;
    file_open(hang_csv_file, SIM_DATA_DIR & "T15.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    for i in 1 to 20 loop
      wait until rising_edge(clk);
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(sequencer_out_slv));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then
        t14_busy_ok := true;
        exit;
      end if;
    end loop;

    if not t14_busy_ok then
      report "FAIL: T15: 2-level 1-func_call hang [DISC-004] -- sequencer_busy never asserted";
      report "FAIL: T15: 2-level 1-func_call hang [DISC-004]" severity error;
     else
       for i in 1 to 100 loop
         wait until rising_edge(clk);
         write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
         write(hang_csv_line, string'(","));
         write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
         write(hang_csv_line, string'(","));
         write(hang_csv_line, std_logic'image(end_sequence(0))(2));
         write(hang_csv_line, string'(","));
         write(hang_csv_line, to_hex8(sequencer_out_slv));
         writeline(hang_csv_file, hang_csv_line);
         if end_sequence(0) = '1' then
           t14_end_seen := true;
         end if;
         if sequencer_busy(0) = '0' then
           t14_busy_lost := true;
         end if;
       end loop;

       if t14_end_seen then
         report "FAIL: T15: 2-level 1-func_call hang [DISC-004] -- end_sequence unexpectedly fired";
         report "FAIL: T15: 2-level 1-func_call hang [DISC-004]" severity error;
       elsif t14_busy_lost then
         report "FAIL: T15: 2-level 1-func_call hang [DISC-004] -- sequencer_busy deasserted unexpectedly";
         report "FAIL: T15: 2-level 1-func_call hang [DISC-004]" severity error;
       else
         report "PASS: T15: 2-level 1-func_call hang [DISC-004]";
       end if;
     end if;
     file_close(hang_csv_file);

    -- ======================================================================
     -- T16 : Multi-bit slice-boundary transitions  [DISC-005 fix verification]
     --
     -- Uses F0 output values that differ in many bits from F1's CC/DD,
     -- including bit 12 (adc_trigger).  This test was originally written to
     -- pin the 1-cycle glitch produced by the old aligner (DISC-005).  After
     -- the fix (srl_input_ff added in sequencer_aligner_shifter_top), all 32
     -- bits travel through 3 registered pipeline stages and transitions are
     -- clean regardless of which bits change.
     --
     -- Baseline (pre-fix) behaviour for reference:
     --   first_change fired on glitch cycle 0x80010234 (bit 12 of idle cleared
     --   one cycle before the other bits), then:
     --   0x80010234 x 1 / 0x000000CC x 4 / 0x000000DD x 6 /
     --   0x000010DD x 1 / 0x80011234 x 4 / 0x80015678 x 1
     --
     -- F0: ts0=0xABCD1234 (projected via to_slv32: 0x80011234)
     --     ts1=0xDEAD5678 (projected via to_slv32: 0x80015678)
     --     times=(3,3)  -- standard F0_T0/F0_T1, durations 4 and 5 cycles
     -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
     -- Program: [0]=func_call(F1,rep=1), [1]=end_seq
     --
     -- Settling: 20 cycles so idle_out = 0x80011234 before trigger.
     -- first_change fires on 0x000000CC (no glitch).
     --
     -- Fixed sequence (all transitions clean):
     --   0x000000CC x 4   F1 ts0 (first): 3+1
     --   0x000000DD x 7   F1 ts1 (last):  5+2
     --   0x80011234 x 4   F0 ts0 (first): 3+1
     --   0x80015678 x 1   F0 ts1: end_seq fires on cycle 1 (standard model)
     -- ======================================================================
     do_reset;

     load_f0(F0_T0, F0_T1, x"ABCD1234", x"DEAD5678");
     load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
     write_prog_mem(16#300000#, x"11000001");
     write_prog_mem(16#300001#, x"F0000000");
     for i in 1 to 20 loop wait until rising_edge(clk); end loop;

     ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0 (first): 3+1
     ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1 (last):  5+2
     ev(2) := x"80011234"; ed(2) := 4;   -- F0 ts0 (first): 3+1
     ev(3) := x"80015678"; ed(3) := 1;   -- F0 ts1: end_seq fires on cycle 1
     en := 4;
     run_test("T16: multi-bit transition glitch [DISC-005]", ev, ed, en);

    -- ======================================================================
    -- T17 : ind_add_jump (0x6), 1-level, rep=1
    --       [indirect sub address, direct rep]
    --
    -- The jump target address is read from ind_sub_add_mem[slot].
    -- bits[31:28]=0x6, bits[19:16]=addr_slot, bits[15:0]=rep (direct)
    --
    -- ind_sub_add_mem[2] = 4  (body at prog_mem address 4)
    -- Instruction: 0x60020001
    --   bits[31:28]=6, bits[19:16]=2 (addr slot), bits[15:0]=1 (rep)
    --
    -- FSM path: op_code_eval -> ind_sub_add_jump -> op_code_eval
    -- ind_sub_add_jump and sub_jump take the same number of states,
    -- so latency is identical to direct jump_to_add: 14 cycles. [sim confirmed]
    --
    -- Program:
    --   [0] ind_add_jump(slot=2, rep=1)  = 0x60020001
    --   [1] end_sequence                 = 0xF0000000
    --   [4] func_call(F1,rep=1)          = 0x11000001
    --   [5] sub_trailer(rep=1)           = 0xE0000001
    --
    -- Expected output: identical to T09.
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_ind_sub_add_mem(16#370002#, "0000000100");  -- ind_sub_add_mem[2] = addr 4
    write_prog_mem(16#300000#, x"60020001");          -- ind_add_jump slot=2, rep=1
    write_prog_mem(16#300001#, x"F0000000");          -- end_sequence
    write_prog_mem(16#300004#, x"11000001");          -- func_call(F1,rep=1)
    write_prog_mem(16#300005#, x"E0000001");          -- sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T17: ind_add_jump slot=2->addr=4 rep=1 [indirect sub address]", ev, ed, en);

    -- ======================================================================
    -- T18 : ind_rep_jump (0x7), 1-level, rep=2 from ind_sub_rep_mem
    --       [indirect sub rep count, direct sub address]
    --
    -- bits[31:28]=0x7, bits[25:16]=sub_addr (direct), bits[3:0]=rep_slot
    -- FSM sets ind_sub_rep_flag=1 before writing stack, so rep_sub uses
    -- the indirect comparison path.
    --
    -- Counting mechanism (confirmed by RTL and simulation):
    --   - Stack word: '0' & ind_sub_rep_flag & return_addr & x"0" & sub_rep_cnt
    --   - return_addr stored is the ind_rep_jump instruction address (0),
    --     NOT the following instruction address.
    --   - sub_rep_cnt is incremented to N before the stack push; on each loop
    --     iteration it increments by 1.
    --   - rep_sub (indirect path) exits when ind_sub_rep_mem_data_out =
    --     data_from_stack(15:0) = sub_rep_cnt at push time = N.
    --   - The slot index used during rep_sub is prog_mem_data_out(3:0), which
    --     re-reads the jump instruction (via the stored return address 0),
    --     so bits[3:0] of the ind_rep_jump instruction = rep_slot throughout.
    --   - Setting ind_sub_rep_mem[slot] = N => subroutine runs exactly N times.
    --
    -- T18: ind_sub_rep_mem[3] = 2 (two passes).
    -- Instruction: bits[31:28]=7, bits[25:16]=addr=4, bits[3:0]=slot=3
    --   = 0x70040003
    -- sub_trailer bits[15:0] are irrelevant on the indirect path (rep_sub
    -- reads from ind_sub_rep_mem via the jump instruction's slot field).
    --
    -- Program:
    --   [0] ind_rep_jump(addr=4, slot=3)  = 0x70040003
    --   [1] end_sequence                  = 0xF0000000
    --   [4] func_call(F1,rep=1)           = 0x11000001
    --   [5] sub_trailer(rep=1)            = 0xE0000001
    --
    -- Expected output: F1 plays twice (same as T10 direct rep=2).
    --   0xCC x 4, 0xDD x 7, 0xCC x 4, 0xDD x 7, F0_V0 x 4, F0_V1 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_ind_sub_rep_mem(16#380003#, x"0002");       -- ind_sub_rep_mem[3] = 2
    write_prog_mem(16#300000#, x"70040003");          -- ind_rep_jump addr=4, slot=3
    write_prog_mem(16#300001#, x"F0000000");          -- end_sequence
    write_prog_mem(16#300004#, x"11000001");          -- func_call(F1,rep=1)
    write_prog_mem(16#300005#, x"E0000001");          -- sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := x"000000CC"; ed(2) := 4;
    ev(3) := x"000000DD"; ed(3) := 7;
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T18: ind_rep_jump addr=4 slot=3->rep=2 [indirect sub rep, twice]", ev, ed, en);

    -- ======================================================================
    -- T19 : ind_all_jump (0x8), 1-level, rep=2
    --       [both sub address and rep count indirect]
    --
    -- bits[31:28]=0x8, bits[19:16]=addr_slot, bits[3:0]=rep_slot
    -- FSM path: op_code_eval -> ind_sub_all_jump -> op_code_eval
    -- Same counting mechanism as ind_rep_jump (T18): ind_sub_rep_flag=1,
    -- return address = jump instruction address, rep_sub reads
    -- ind_sub_rep_mem[prog_mem_data_out(3:0)] = ind_sub_rep_mem[rep_slot].
    --
    -- ind_sub_add_mem[2] = 4  (sub body at prog_mem address 4)
    -- ind_sub_rep_mem[5] = 2  (run twice)
    -- Instruction: bits[31:28]=8, bits[19:16]=2, bits[3:0]=5 = 0x80020005
    --
    -- Program:
    --   [0] ind_all_jump(addr_slot=2, rep_slot=5)  = 0x80020005
    --   [1] end_sequence                           = 0xF0000000
    --   [4] func_call(F1,rep=1)                    = 0x11000001
    --   [5] sub_trailer(rep=1)                     = 0xE0000001
    --
    -- Expected output: F1 plays twice (same as T18).
    --   0xCC x 4, 0xDD x 7, 0xCC x 4, 0xDD x 7, F0_V0 x 4, F0_V1 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_ind_sub_add_mem(16#370002#, "0000000100");  -- ind_sub_add_mem[2] = addr 4
    write_ind_sub_rep_mem(16#380005#, x"0002");       -- ind_sub_rep_mem[5] = 2
    write_prog_mem(16#300000#, x"80020005");          -- ind_all_jump addr_slot=2, rep_slot=5
    write_prog_mem(16#300001#, x"F0000000");          -- end_sequence
    write_prog_mem(16#300004#, x"11000001");          -- func_call(F1,rep=1)
    write_prog_mem(16#300005#, x"E0000001");          -- sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := x"000000CC"; ed(2) := 4;
    ev(3) := x"000000DD"; ed(3) := 7;
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T19: ind_all_jump addr_slot=2->4 rep_slot=5->2 [both indirect]", ev, ed, en);

    -- ======================================================================
    -- T20 : jump_to_add (0x5), 3-level subroutine nesting
    --
    -- Extends T11 (2-level) by adding a third nesting level.
    -- The innermost body must have >= 2 func_calls (DISC-004).
    -- The middle body contains only the innermost jump + trailer.
    -- The outermost body contains only the middle jump + trailer.
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- F2: ts0=0xEE, ts1=0xFF, times=(3,5)
    --
    -- Program:
    --   [0]  jump_to_add(addr=8,  rep=1) = 0x50080001  level-1 jump
    --   [1]  end_sequence                = 0xF0000000
    --   [8]  jump_to_add(addr=10, rep=1) = 0x500A0001  level-2 jump (L1 body)
    --   [9]  sub_trailer(rep=1)          = 0xE0000001  level-1 trailer
    --   [10] jump_to_add(addr=12, rep=1) = 0x500C0001  level-3 jump (L2 body)
    --   [11] sub_trailer(rep=1)          = 0xE0000001  level-2 trailer
    --   [12] func_call(F1,rep=1)         = 0x11000001  } L3 body (innermost)
    --   [13] func_call(F2,rep=1)         = 0x12000001  } (2 calls per DISC-004)
    --   [14] sub_trailer(rep=1)          = 0xE0000001  level-3 trailer
    --
    -- Execution path:
    --   [0] -> [8] -> [10] -> [12] -> F1 -> [13] -> F2 -> [14]
    --       -> [11] -> [9] -> [1] -> end_seq
    --
    -- Expected output: identical to T11.
    --   0xCC x 4, 0xDD x 7, 0xEE x 4, 0xFF x 7, F0_V0 x 4, F0_V1 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");
    write_prog_mem(16#300000#, x"50080001");  -- level-1 jump to addr=8, rep=1
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    write_prog_mem(16#300008#, x"500A0001");  -- level-2 jump to addr=10, rep=1
    write_prog_mem(16#300009#, x"E0000001");  -- level-1 sub_trailer(rep=1)
    write_prog_mem(16#30000A#, x"500C0001");  -- level-3 jump to addr=12, rep=1
    write_prog_mem(16#30000B#, x"E0000001");  -- level-2 sub_trailer(rep=1)
    write_prog_mem(16#30000C#, x"11000001");  -- func_call(F1,rep=1) innermost body
    write_prog_mem(16#30000D#, x"12000001");  -- func_call(F2,rep=1) innermost body
    write_prog_mem(16#30000E#, x"E0000001");  -- level-3 sub_trailer(rep=1)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0 (first)
    ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1 (last)
    ev(2) := x"000000EE"; ed(2) := 4;   -- F2 ts0 (first)
    ev(3) := x"000000FF"; ed(3) := 7;   -- F2 ts1 (last)
    ev(4) := F0_V0;        ed(4) := 4;
    ev(5) := F0_V1;        ed(5) := 5;
    en := 6;
    run_test("T20: jump_to_add 3-level nesting [3 nested subroutines]", ev, ed, en);

    -- ======================================================================
    -- T21 : sub_trailer bits[15:0] are don't-care (DISC-006)
    --
    -- Identical program to T09 (jump_to_add, 1-level, rep=1) except that
    -- sub_trailer[15:0] is set to 0xFFFF instead of 0x0001.  This is
    -- maximally different from the jump instruction's rep field (rep=1).
    --
    -- The user-facing documentation implies sub_trailer[15:0] must match
    -- the jump rep count.  RTL analysis shows the field is never read:
    -- both sides of the loop-exit comparison in rep_sub come from the jump
    -- instruction word (re-read from program memory at the call-site address),
    -- not from the sub_trailer word.  The sub_trailer word serves only as an
    -- opcode marker and address marker; its payload bits are unused.
    --
    -- F1: ts0=0xCC, ts1=0xDD, times=(3,5)
    -- Program:
    --   [0] jump_to_add(addr=2, rep=1) = 0x50020001
    --   [1] end_sequence               = 0xF0000000
    --   [2] func_call(F1,rep=1)        = 0x11000001
    --   [3] sub_trailer(0xFFFF)        = 0xE000FFFF  <-- bits[15:0] != rep
    --
    -- Expected: identical to T09.
    --   0xCC x 4, 0xDD x 7, 0x01 x 4, 0x02 x 5
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"50020001");  -- jump_to_add(addr=2, rep=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    write_prog_mem(16#300002#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300003#, x"E000FFFF");  -- sub_trailer(bits[15:0]=0xFFFF, don't-care)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;
    ev(1) := x"000000DD"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T21: sub_trailer bits[15:0]=0xFFFF don't-care [DISC-006]", ev, ed, en);

    -- ======================================================================
    -- T22 : op_code_error — idle, spurious-trigger rejection, and recovery
    --       [DISC-007]
    --
    -- Verifies three distinct aspects of the op_code_error path:
    --
    --   Phase A: An invalid opcode causes op_code_error to assert.  The
    --     parameter extractor FSM enters op_code_error_state and stops
    --     writing to the FIFO.  The function executor drains the FIFO
    --     (F1 output is produced normally), then loops forever in func_exe
    --     because fifo_empty='1' with no end_seq token; sequencer_busy
    --     stays '1' indefinitely.  end_sequence never fires.
    --     [DISC-007]
    --
    --   Phase B: A second trigger while busy='1' and op_code_error='1' is
    --     blocked at the "AND NOT busy" gate in sequencer_v4_top.  The
    --     stuck state is maintained: busy='1', end_seq='0', op_err='1'.
    --
    --   Phase C: Pulsing op_code_error_reset clears the extractor state.
    --     A do_reset is then required to escape the executor's func_exe
    --     loop before a new trigger can run F2 to completion.
    --
    -- Memories loaded once at the top of the test:
    --   F0  : standard (V0=0x01, V1=0x02, T0=3, T1=3)
    --   F1  : ts0=0xCC, ts1=0xDD, times=(3,5)
    --   F2  : ts0=0xEE, ts1=0xFF, times=(3,5)
    --
    -- Phase A program (written once; not changed for phase B):
    --   [0] func_call(F1,rep=1)  = 0x11000001
    --   [1] 0xC0000000           = invalid opcode 0xC
    --   [2] end_sequence         = 0xF0000000  (never reached)
    --
    -- Phase C: op_code_error_reset pulse; then do_reset; then F2 program:
    --   [0] func_call(F2,rep=1)  = 0x12000001
    --   [1] end_sequence         = 0xF0000000
    --
    -- Phase A CSV: T22_A.csv  (columns: sample_idx,busy,end_seq,seq_out,op_err,op_err_add)
    -- Phase B CSV: T22_B.csv  (same columns)
    -- Phase C CSV: T22.csv    (written by run_test; standard 4-column format)
    --
    -- PASS criterion:
    --   Phase A: F1 output cycle-exact (CC x4, DD x7); sequencer_busy
    --     stays '1' for 20+ cycles; op_code_error='1' throughout;
    --     op_code_error_add = addr 1; end_sequence never fires.
    --   Phase B: sequencer_busy='1', end_sequence='0', op_code_error='1'
    --     for all 20 observation cycles.
    --   Phase C: op_code_error clears after reset pulse; after do_reset
    --     F2 runs to completion (EE x4, FF x7, F0_V0 x4, F0_V1 x5).
    --
    -- Hardware note: T22 is excluded from hw_capture.py ILA capture.
    -- Phase A/B have no end_sequence; Phase C requires a third trigger
    -- that cannot be isolated by a single ILA arm.
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");
    write_prog_mem(16#300000#, x"11000001");  -- func_call(F1,rep=1)
    write_prog_mem(16#300001#, x"C0000000");  -- invalid opcode 0xC
    write_prog_mem(16#300002#, x"F0000000");  -- end_sequence (never reached in A/B)
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- ── Phase A ──────────────────────────────────────────────────────────
    -- Trigger and observe F1 output inline, then verify idle+error state.

    hang_trig_cyc := cycle_cnt;
    file_open(hang_csv_file, SIM_DATA_DIR & "T22_A.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out,op_err,op_err_add"));
    writeline(hang_csv_file, hang_csv_line);

    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Wait for sequencer_busy to assert (up to 20 cycles)
    t14_busy_ok := false;
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(sequencer_out_slv));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(op_code_error(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_dec_str(to_integer(unsigned(op_code_error_add(0)))));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then
        t14_busy_ok := true;
        exit;
      end if;
    end loop;

    if not t14_busy_ok then
      report "FAIL: T22 Phase A -- sequencer_busy never asserted after trigger";
      report "FAIL: T22 Phase A" severity error;
      file_close(hang_csv_file);
    else

      -- Inline F1 output check: CC x4 then DD x7
      -- t14_busy_ok repurposed as F1-pass flag (true = passing so far)
      -- Busy asserts 5 cycles before first output change; we already consumed
      -- the busy-assert cycle exiting the wait loop, so skip 4 more cycles
      -- before the first output sample.
      t14_busy_ok := true;

      for i in 1 to 4 loop
        wait until rising_edge(clk);
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(sequencer_out_slv));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(op_code_error(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_dec_str(to_integer(unsigned(op_code_error_add(0)))));
        writeline(hang_csv_file, hang_csv_line);
      end loop;

      for i in 1 to 4 loop
        wait until rising_edge(clk);
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(sequencer_out_slv));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(op_code_error(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_dec_str(to_integer(unsigned(op_code_error_add(0)))));
        writeline(hang_csv_file, hang_csv_line);
        if sequencer_out_slv /= x"000000CC" then
          t14_busy_ok := false;
          report "FAIL: T22 Phase A -- F1 CC output mismatch cycle " &
                 integer'image(i) & ": got " & to_hex8(sequencer_out_slv);
        end if;
      end loop;

      for i in 1 to 7 loop
        wait until rising_edge(clk);
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(sequencer_out_slv));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(op_code_error(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_dec_str(to_integer(unsigned(op_code_error_add(0)))));
        writeline(hang_csv_file, hang_csv_line);
        if sequencer_out_slv /= x"000000DD" then
          t14_busy_ok := false;
          report "FAIL: T22 Phase A -- F1 DD output mismatch cycle " &
                 integer'image(i) & ": got " & to_hex8(sequencer_out_slv);
        end if;
      end loop;

      if not t14_busy_ok then
        report "FAIL: T22 Phase A -- F1 output check failed" severity error;
        file_close(hang_csv_file);
      else

        -- DISC-007: after F1 output ends the executor loops back into func_exe
        -- and re-runs F1 indefinitely; sequencer_busy never de-asserts.
        -- Verify: observe 20 cycles and confirm busy='1', end_seq='0',
        -- op_code_error='1' throughout.
        t14_end_seen  := false;   -- any violation seen
        t14_busy_lost := false;   -- busy unexpectedly de-asserted
        for i in 1 to 20 loop
          wait until rising_edge(clk);
          write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
          write(hang_csv_line, string'(","));
          write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
          write(hang_csv_line, string'(","));
          write(hang_csv_line, std_logic'image(end_sequence(0))(2));
          write(hang_csv_line, string'(","));
          write(hang_csv_line, to_hex8(sequencer_out_slv));
          write(hang_csv_line, string'(","));
          write(hang_csv_line, std_logic'image(op_code_error(0))(2));
          write(hang_csv_line, string'(","));
          write(hang_csv_line, to_dec_str(to_integer(unsigned(op_code_error_add(0)))));
          writeline(hang_csv_file, hang_csv_line);
          if sequencer_busy(0) = '0' then
            t14_busy_lost := true;
          end if;
          if end_sequence(0) = '1' then
            t14_end_seen := true;
          end if;
        end loop;

        -- Check error address (combinatorial; read at end of observation window)
        if t14_busy_lost then
          report "FAIL: T22 Phase A -- sequencer_busy unexpectedly de-asserted";
          report "FAIL: T22 Phase A" severity error;
          file_close(hang_csv_file);
        elsif t14_end_seen then
          report "FAIL: T22 Phase A -- end_sequence fired unexpectedly";
          report "FAIL: T22 Phase A" severity error;
          file_close(hang_csv_file);
        elsif op_code_error(0) /= '1' then
          report "FAIL: T22 Phase A -- op_code_error not asserted";
          report "FAIL: T22 Phase A" severity error;
          file_close(hang_csv_file);
        elsif op_code_error_add(0) /= "0000000001" then
          report "FAIL: T22 Phase A -- op_code_error_add mismatch: got " &
                 integer'image(to_integer(unsigned(op_code_error_add(0)))) &
                 " expected 1";
          report "FAIL: T22 Phase A" severity error;
          file_close(hang_csv_file);
        else
          report "PASS: T22 Phase A -- F1 output correct, busy stuck, op_code_error=1 at addr 1";
          file_close(hang_csv_file);

          -- ── Phase B ────────────────────────────────────────────────────
          -- Issue a second trigger; it must be silently dropped.

          file_open(hang_csv_file, SIM_DATA_DIR & "T22_B.csv", write_mode);
          write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out,op_err,op_err_add"));
          writeline(hang_csv_file, hang_csv_line);

          sync_cmd_start     <= '1';
          sync_cmd_main_addr <= "00000";
          wait until rising_edge(clk);
          sync_cmd_start     <= '0';
          sync_cmd_main_addr <= (others => '0');

          -- Phase B: busy is already '1' so the trigger is blocked at the
          -- "AND NOT busy" gate in sequencer_v4_top.  Verify the stuck state
          -- is unchanged for 20 cycles: busy='1', end_seq='0', op_err='1'.
          t14_end_seen  := false;   -- end_sequence fired (bad)
          t14_busy_lost := false;   -- busy unexpectedly de-asserted (bad)
          t14_busy_ok   := true;    -- op_code_error stays asserted (fail if drops)
          for i in 1 to 20 loop
            wait until rising_edge(clk);
            write(hang_csv_line, to_dec_str(i));
            write(hang_csv_line, string'(","));
            write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
            write(hang_csv_line, string'(","));
            write(hang_csv_line, std_logic'image(end_sequence(0))(2));
            write(hang_csv_line, string'(","));
            write(hang_csv_line, to_hex8(sequencer_out_slv));
            write(hang_csv_line, string'(","));
            write(hang_csv_line, std_logic'image(op_code_error(0))(2));
            write(hang_csv_line, string'(","));
            write(hang_csv_line, to_dec_str(to_integer(unsigned(op_code_error_add(0)))));
            writeline(hang_csv_file, hang_csv_line);
            if end_sequence(0) = '1' then
              t14_end_seen := true;
            end if;
            if sequencer_busy(0) = '0' then
              t14_busy_lost := true;
            end if;
            if op_code_error(0) = '0' then
              t14_busy_ok := false;
            end if;
          end loop;

          if t14_end_seen then
            report "FAIL: T22 Phase B -- end_sequence fired unexpectedly";
            report "FAIL: T22 Phase B" severity error;
          elsif t14_busy_lost then
            report "FAIL: T22 Phase B -- sequencer_busy de-asserted unexpectedly";
            report "FAIL: T22 Phase B" severity error;
          elsif not t14_busy_ok then
            report "FAIL: T22 Phase B -- op_code_error deasserted unexpectedly";
            report "FAIL: T22 Phase B" severity error;
          else
            report "PASS: T22 Phase B -- spurious trigger blocked, stuck state maintained";
          end if;
          file_close(hang_csv_file);

          -- ── Phase C ────────────────────────────────────────────────────
          -- Clear the error and verify the sequencer recovers.
          --
          -- Step 1: Pulse op_code_error_reset to return the extractor to
          --         wait_start and clear op_code_error.
          -- Step 2: do_reset to escape the executor's func_exe loop.
          -- Step 3: Load a clean program and trigger a normal run.

          -- Pulse op_code_error_reset via register interface (addr x"39", bit0=1)
          reg_write(x"390001", x"00000000");
          wait until rising_edge(clk);

          -- op_code_error is registered; should be '0' now
          if op_code_error(0) /= '0' then
            report "FAIL: T22 Phase C -- op_code_error did not clear after reset pulse";
            report "FAIL: T22 Phase C" severity error;
          else
            -- Full reset to escape executor func_exe loop, then load F2 program
            do_reset;
            load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
            load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");
            write_prog_mem(16#300000#, x"12000001");  -- func_call(F2,rep=1)
            write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
            for i in 1 to 5 loop wait until rising_edge(clk); end loop;

            ev(0) := x"000000EE"; ed(0) := 4;   -- F2 ts0
            ev(1) := x"000000FF"; ed(1) := 7;   -- F2 ts1
            ev(2) := F0_V0;        ed(2) := 4;
            ev(3) := F0_V1;        ed(3) := 5;
            en := 4;
            run_test("T22: op_code_error recovery [DISC-007]", ev, ed, en);
          end if;

        end if;
      end if;
    end if;

    -- ======================================================================
    -- T23 : Infinite loop + sync_cmd_stop
    --
    -- Verifies that asserting sync_cmd_stop during an infinite-loop execution
    -- terminates the sequencer after the current F1 iteration completes and
    -- the FIFO is drained to the end_sequence token.
    --
    -- RTL path (function_executor_v3.vhd):
    --   The TB asserts sync_cmd_stop='1' for 1 cycle at iteration i=30 of
    --   the observation loop.  Due to VHDL delta ordering the DUT sees
    --   func_stop=1 at the rising edge of cycle 32 (relative to trigger).
    --   At cycle 32 func_end=1 simultaneously (last cycle of iter2 ts1) so
    --   the last-else branch fires:
    --     infinite_loop_run + func_stop=1 + func_end=1 → empting_fifo
    --   empting_fifo pops the end_seq token on the same cycle; by cycle 33
    --   prog_end_opcode_int=1 → wait_start + end_sequence='1'.
    --   The 3-stage pipeline continues to flush iter3-equivalent output
    --   through cycles 33-40, and end_sequence fires at cycle 41.
    --
    -- Program:
    --   [0] 0x11800000  func_call(F1, inf_loop=1, rep=0)
    --   [1] 0xF0000000  end_sequence
    -- F1: ts0=0xCC (t=3), ts1=0xDD (t=5)
    --
    -- Expected output sequence (cycle 12 = first change):
    --   CC x4, DD x7, CC x3, DD x7, CC x4, DD x5 (end_seq at cycle 41)
    --   00000001 → CC at cycle 12 (trigger→first-change = 12 cycles)
    --   end_sequence fires at cycle 41; sequencer_busy drops at cycle 42.
    --
    -- CSV: T23.csv  (sample_idx,busy,end_seq,seq_out)
    -- Hardware note: T23 is excluded from hw_capture.py ILA capture
    --   (no clean single-arm trigger possible due to internal stop).
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11800000");  -- func_call(F1, inf_loop=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    hang_trig_cyc := cycle_cnt;
    file_open(hang_csv_file, SIM_DATA_DIR & "T23.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Expected non-idle pattern (T23_EXP indices 10..40 = 31 samples):
    -- CC×4, DD×7, CC×3, DD×7, CC×4, DD×5, DD×1(end)
    --
    -- Auto-detect first-change: wait for output /= idle, then check pattern.
    -- Stop assertion: must hit DUT at last cycle of iter2 ts1 = 20 cycles
    -- after first-change.  TB asserts 1 cycle before DUT sees it → index 19.
    -- Expected non-idle pattern (31 samples from first-change):
    --   CC×4, DD×7, CC×3, DD×7, CC×4, DD×5, DD×1(end)
    t23_pass      := true;
    t23_end_cycle := -1;
    t23_busy_drop := -1;
    t23_busy_seen := false;

    -- Phase 1: wait for first-change
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(sequencer_out_slv));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then t23_busy_seen := true; end if;
      if sequencer_out_slv /= F0_V0 then
        report "NOTE: T23 startup latency = " &
               integer'image(cycle_cnt - hang_trig_cyc) & " cycles (first-change)";
        exit;
      end if;
      if i = 20 then
        t23_pass := false;
        report "FAIL: T23 -- first-change not detected within 20 cycles" severity error;
      end if;
    end loop;

    -- Phase 2: check pattern from first-change (index 0 already sampled above).
    -- Assert stop at index 19 from first-change (DUT sees at index 20 = last DD of iter2).
    -- Check index 0 inline, then loop indices 1..30 (31 total active samples).
    if t23_pass then
      -- Index 0 check (already at first-change sample)
      if sequencer_out_slv /= T23_EXP(10) then
        t23_pass := false;
        report "FAIL: T23 -- output mismatch at first-change" &
               ": expected " & to_hex8(T23_EXP(10)) &
               " got " & to_hex8(sequencer_out_slv) severity error;
      end if;
      for i in 1 to 40 loop
        wait until rising_edge(clk);
        -- Write CSV
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(sequencer_out_slv));
        writeline(hang_csv_file, hang_csv_line);
        -- Assert stop at index 19 from first-change
        if i = 19 then sync_cmd_stop <= '1'; end if;
        if i = 20 then sync_cmd_stop <= '0'; end if;
        -- Track end_sequence and busy
        if sequencer_busy(0) = '1' then t23_busy_seen := true; end if;
        if end_sequence(0) = '1' and t23_end_cycle = -1 then
          t23_end_cycle := cycle_cnt - hang_trig_cyc;
        end if;
        if sequencer_busy(0) = '0' and t23_busy_seen and t23_busy_drop = -1 then
          t23_busy_drop := cycle_cnt - hang_trig_cyc;
        end if;
        -- Compare against expected (offset by 10 for idle-stripped array)
        if (i + 10) <= 40 then
          if sequencer_out_slv /= T23_EXP(i + 10) then
            t23_pass := false;
            report "FAIL: T23 -- output mismatch at cycle " &
                   integer'image(cycle_cnt - hang_trig_cyc) &
                   ": expected " & to_hex8(T23_EXP(i + 10)) &
                   " got " & to_hex8(sequencer_out_slv) severity error;
          end if;
        end if;
        -- Exit after busy drops
        if t23_busy_drop /= -1 then exit; end if;
      end loop;
    end if;
    file_close(hang_csv_file);
    -- Verify end_sequence fired (don't check absolute cycle)
    if t23_pass and t23_end_cycle = -1 then
      t23_pass := false;
      report "FAIL: T23 -- end_sequence never observed" severity error;
    end if;
    -- Verify busy dropped
    if t23_pass and t23_busy_drop = -1 then
      t23_pass := false;
      report "FAIL: T23 -- sequencer_busy never dropped" severity error;
    end if;
    -- Verify busy drops 1 cycle after end_sequence
    if t23_pass and (t23_busy_drop /= t23_end_cycle + 1) then
      t23_pass := false;
      report "FAIL: T23 -- busy_drop at " & integer'image(t23_busy_drop) &
             " not 1 cycle after end_sequence at " & integer'image(t23_end_cycle) severity error;
    end if;
    if t23_pass then
      report "PASS: T23: infinite loop + sync_cmd_stop";
    end if;

    -- ======================================================================
    -- T24 : Infinite loop + sync_cmd_step
    --
    -- Verifies that asserting sync_cmd_step during an infinite-loop execution
    -- causes the sequencer to complete the current F1 iteration, advance to
    -- the next FIFO entry (the end_sequence token, executed as F0), and
    -- terminate normally.
    --
    -- RTL path (function_executor_v3.vhd):
    --   The TB asserts sync_cmd_step='1' for 1 cycle at iteration i=30 of
    --   the observation loop.  Due to VHDL delta ordering the DUT sees
    --   func_step=1 at the rising edge of cycle 32 (relative to trigger).
    --   At cycle 32 func_end=1 simultaneously (last cycle of iter2 ts1):
    --     infinite_loop_run + func_stop=0 + func_step=1 + func_end=1
    --     → start_func  (reads end_seq token from FIFO)
    --   The end_seq token is executed as F0.  The 3-stage pipeline continues
    --   to flush iter3-equivalent output through cycles 33-43, then F0
    --   output appears at cycles 44-48, and end_sequence fires at cycle 48.
    --
    -- Program:
    --   [0] 0x11800000  func_call(F1, inf_loop=1, rep=0)
    --   [1] 0xF0000000  end_sequence
    -- F1: ts0=0xCC (t=3), ts1=0xDD (t=5)
    --
    -- Expected output sequence (cycle 12 = first change):
    --   CC x4, DD x7, CC x3, DD x7, CC x4, DD x7 (pipeline drain)
    --   then F0 ts0: 00000001 x4, F0 ts1: 00000002 x1 (end_seq at cycle 48)
    --   trigger→first-change = 12 cycles; end_seq at cycle 48; busy drops at 49
    --
    -- CSV: T24.csv  (sample_idx,busy,end_seq,seq_out)
    -- Hardware note: T24 is excluded from hw_capture.py ILA capture.
    -- ======================================================================
    do_reset;

    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    write_prog_mem(16#300000#, x"11800000");  -- func_call(F1, inf_loop=1)
    write_prog_mem(16#300001#, x"F0000000");  -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    hang_trig_cyc := cycle_cnt;
    file_open(hang_csv_file, SIM_DATA_DIR & "T24.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Auto-detect first-change, then check pattern and assert step relative
    -- to first-change (same timing as T23: step at index 19 from first-change,
    -- DUT sees at index 20 = last cycle of iter2 ts1).
    -- After step: DUT reads end_seq token → executes F0 → end_sequence.
    -- Expected non-idle pattern from T24_EXP starts at index 10.
    t24_pass      := true;
    t24_end_cycle := -1;
    t24_busy_drop := -1;
    t24_busy_seen := false;

    -- Phase 1: wait for first-change
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(sequencer_out_slv));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then t24_busy_seen := true; end if;
      if sequencer_out_slv /= F0_V0 then
        report "NOTE: T24 startup latency = " &
               integer'image(cycle_cnt - hang_trig_cyc) & " cycles (first-change)";
        exit;
      end if;
      if i = 20 then
        t24_pass := false;
        report "FAIL: T24 -- first-change not detected within 20 cycles" severity error;
      end if;
    end loop;

    -- Phase 2: check pattern from first-change.
    -- T24_EXP non-idle starts at index 10. Check from first-change using offset 10.
    if t24_pass then
      -- Index 0 check (first-change sample already on bus)
      if sequencer_out_slv /= T24_EXP(10) then
        t24_pass := false;
        report "FAIL: T24 -- output mismatch at first-change" &
               ": expected " & to_hex8(T24_EXP(10)) &
               " got " & to_hex8(sequencer_out_slv) severity error;
      end if;
      for i in 1 to 50 loop
        wait until rising_edge(clk);
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(sequencer_out_slv));
        writeline(hang_csv_file, hang_csv_line);
        -- Assert step at index 19 from first-change
        if i = 19 then sync_cmd_step <= '1'; end if;
        if i = 20 then sync_cmd_step <= '0'; end if;
        -- Track end_sequence and busy
        if sequencer_busy(0) = '1' then t24_busy_seen := true; end if;
        if end_sequence(0) = '1' and t24_end_cycle = -1 then
          t24_end_cycle := cycle_cnt - hang_trig_cyc;
        end if;
        if sequencer_busy(0) = '0' and t24_busy_seen and t24_busy_drop = -1 then
          t24_busy_drop := cycle_cnt - hang_trig_cyc;
        end if;
        -- Compare against expected (offset by 10 for idle-stripped position)
        if (i + 10) <= 47 then
          if sequencer_out_slv /= T24_EXP(i + 10) then
            t24_pass := false;
            report "FAIL: T24 -- output mismatch at cycle " &
                   integer'image(cycle_cnt - hang_trig_cyc) &
                   ": expected " & to_hex8(T24_EXP(i + 10)) &
                   " got " & to_hex8(sequencer_out_slv) severity error;
          end if;
        end if;
        -- Exit after busy drops
        if t24_busy_drop /= -1 then exit; end if;
      end loop;
    end if;
    file_close(hang_csv_file);
    -- Verify end_sequence fired
    if t24_pass and t24_end_cycle = -1 then
      t24_pass := false;
      report "FAIL: T24 -- end_sequence never observed" severity error;
    end if;
    -- Verify busy dropped
    if t24_pass and t24_busy_drop = -1 then
      t24_pass := false;
      report "FAIL: T24 -- sequencer_busy never dropped" severity error;
    end if;
    -- Verify busy drops 1 cycle after end_sequence
    if t24_pass and (t24_busy_drop /= t24_end_cycle + 1) then
      t24_pass := false;
      report "FAIL: T24 -- busy_drop at " & integer'image(t24_busy_drop) &
             " not 1 cycle after end_sequence at " & integer'image(t24_end_cycle) severity error;
    end if;
    if t24_pass then
      report "PASS: T24: infinite loop + sync_cmd_step";
    end if;

    -- ======================================================================
    -- T25 : Non-zero start address via sync_cmd_start and reg_cmd_start
    --
    -- Confirms that sync_cmd_main_addr and regDataWr[4:0] correctly select
    -- the program memory start address.
    --
    -- RTL: sequencer_start_addr = "000" & main_addr & "00"  (= main_addr * 4)
    --      This is a 10-bit WORD address into prog_mem.
    -- So main_addr=1 -> prog_mem word 4; start_idx=2 -> prog_mem word 8.
    --
    -- F1: ts0=0xCC (t=3), ts1=0xDD (t=5)  -> 4 cycles, 7 cycles
    -- F2: ts0=0xEE (t=3), ts1=0xFF (t=5)  -> 4 cycles, 7 cycles (guard)
    --
    -- T25a: sync_cmd_start, main_addr=1 -> starts at prog_mem word 4
    --   prog[0..3]=func_call(F2,rep=1) [guards: would give EE/FF if executed]
    --   prog[4]=func_call(F1,rep=1) [intended first instruction]
    --   prog[5]=end_sequence
    --
    -- T25b: reg_cmd_start, regDataWr[4:0]=2 -> starts at prog_mem word 8
    --   prog[0..7]=func_call(F2,rep=1) [guards]
    --   prog[8]=func_call(F1,rep=1) [intended first instruction]
    --   prog[9]=end_sequence
    --
    -- Expected (both sub-tests):
    --   0xCC x 4, 0xDD x 7, F0_V0 x 4, F0_V1 x 5
    -- ======================================================================
    -- T25a: sync_cmd_start, main_addr=1 (starts at prog_mem word 4)
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");   -- F1
    load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");   -- F2 guard
    write_prog_mem(16#300000#, x"12000001");  -- [0] func_call(F2,rep=1) guard
    write_prog_mem(16#300001#, x"12000001");  -- [1] func_call(F2,rep=1) guard
    write_prog_mem(16#300002#, x"12000001");  -- [2] func_call(F2,rep=1) guard
    write_prog_mem(16#300003#, x"12000001");  -- [3] func_call(F2,rep=1) guard
    write_prog_mem(16#300004#, x"11000001");  -- [4] func_call(F1,rep=1)  <-- start
    write_prog_mem(16#300005#, x"F0000000");  -- [5] end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0
    ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test_at(1, "T25a: sync non-zero start addr (main_addr=1 -> word 4)", ev, ed, en);

    -- T25b: reg_cmd_start, start_idx=2 (starts at prog_mem word 8)
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");   -- F1
    load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");   -- F2 guard
    write_prog_mem(16#300000#, x"12000001");  -- [0] func_call(F2,rep=1) guard
    write_prog_mem(16#300001#, x"12000001");  -- [1] func_call(F2,rep=1) guard
    write_prog_mem(16#300002#, x"12000001");  -- [2] func_call(F2,rep=1) guard
    write_prog_mem(16#300003#, x"12000001");  -- [3] func_call(F2,rep=1) guard
    write_prog_mem(16#300004#, x"12000001");  -- [4] func_call(F2,rep=1) guard
    write_prog_mem(16#300005#, x"12000001");  -- [5] func_call(F2,rep=1) guard
    write_prog_mem(16#300006#, x"12000001");  -- [6] func_call(F2,rep=1) guard
    write_prog_mem(16#300007#, x"12000001");  -- [7] func_call(F2,rep=1) guard
    write_prog_mem(16#300008#, x"11000001");  -- [8] func_call(F1,rep=1)  <-- start
    write_prog_mem(16#300009#, x"F0000000");  -- [9] end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0
    ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test_reg(2, "T25b: reg_cmd_start non-zero start addr (idx=2 -> word 8)", ev, ed, en);

    -- ======================================================================
    -- T26 : rep=0 skip for sub-jump opcodes 0x5/0x6/0x7/0x8
    -- ======================================================================
    -- Program:
    --   [0] 0x50020000  jump_to_add(addr=2, rep=0)           opcode 0x5, bits[15:0]=0 -> skip
    --   [1] 0x60000000  ind_add_jump(addr_slot=0, rep=0)     opcode 0x6, bits[15:0]=0 -> skip
    --   [2] 0x70040006  ind_rep_jump(addr=4, rep_slot=6)     opcode 0x7, ind_sub_rep[6]=0 -> skip
    --   [3] 0x80000007  ind_all_jump(addr_slot=0, rep_slot=7) opcode 0x8, ind_sub_rep[7]=0 -> skip
    --   [4] 0xF0000000  end_sequence
    -- ind_sub_rep_mem[6]=0 and [7]=0 written explicitly.
    -- All four sub-jump instructions are skipped; only F0 runs.
    -- Expected: F0_V1 x 5   (F0_V0 = idle output = first_change never fires on it)
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    write_ind_sub_rep_mem(16#380006#, x"0000");   -- ind_sub_rep_mem[6] = 0
    write_ind_sub_rep_mem(16#380007#, x"0000");   -- ind_sub_rep_mem[7] = 0
    write_prog_mem(16#300000#, x"50020000");      -- jump_to_add(addr=2, rep=0)
    write_prog_mem(16#300001#, x"60000000");      -- ind_add_jump(addr_slot=0, rep=0)
    write_prog_mem(16#300002#, x"70040006");      -- ind_rep_jump(addr=4, rep_slot=6)
    write_prog_mem(16#300003#, x"80000007");      -- ind_all_jump(addr_slot=0, rep_slot=7)
    write_prog_mem(16#300004#, x"F0000000");      -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := F0_V1; ed(0) := 5;   -- F0 ts1 only (ts0 = idle, never a "change")
    en := 1;
    run_test("T26: rep=0 skip for sub-jump opcodes 0x5/0x6/0x7/0x8", ev, ed, en);

    -- ======================================================================
    -- T27 : rep=0 skip for indirect func_call opcodes 0x2/0x3/0x4
    -- ======================================================================
    -- Program:
    --   [0] 0x22000000  ind_func_call(slot=2, rep=0)          opcode 0x2, bits[23:0]=0 -> skip
    --   [1] 0x31000006  ind_rep_call(func_id=1, rep_slot=6)   opcode 0x3, ind_rep[6]=0 -> skip
    --   [2] 0x43000007  ind_all_call(func_slot=3, rep_slot=7) opcode 0x4, ind_rep[7]=0 -> skip
    --   [3] 0xF0000000  end_sequence
    -- ind_rep_mem[6]=0 and [7]=0 written explicitly.
    -- All three indirect-call instructions are skipped; only F0 runs.
    -- Expected: F0_V1 x 5
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    write_ind_rep_mem(16#360006#, x"000000");     -- ind_rep_mem[6] = 0
    write_ind_rep_mem(16#360007#, x"000000");     -- ind_rep_mem[7] = 0
    write_prog_mem(16#300000#, x"22000000");      -- ind_func_call(slot=2, rep=0)
    write_prog_mem(16#300001#, x"31000006");      -- ind_rep_call(func_id=1, rep_slot=6)
    write_prog_mem(16#300002#, x"43000007");      -- ind_all_call(func_slot=3, rep_slot=7)
    write_prog_mem(16#300003#, x"F0000000");      -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := F0_V1; ed(0) := 5;
    en := 1;
    run_test("T27: rep=0 skip for indirect func_call opcodes 0x2/0x3/0x4", ev, ed, en);

    -- ======================================================================
    -- T28 : func_call(F1,rep=1), 16-slice function (full function depth)
    -- ======================================================================
    -- F1 occupies rows 0x10..0x1F in out_mem and time_mem.
    -- 16 slices, all with time=3.  Distinct output values per slice:
    --   ts0=0x00000100, ts1=0x00000200, ..., ts14=0x00000F00, ts15=0x00001000
    -- time_mem[0x20]=0 written explicitly (T22 wrote it to 0x0003).
    -- Duration model (same as all prior tests):
    --   first slice  : time_mem[0] + 1 = 4 cycles
    --   middle slices: time_mem[i]     = 3 cycles each  (slices 1..14)
    --   last slice   : time_mem[15] + 2 = 5 cycles
    -- Then F0: F0_V0 x 4, F0_V1 x 5.
    -- Expected: 18 entries total (well within 64-entry array).
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    -- Write F1: 16 slices, time=3 each, output values 0x100 .. 0x1000
    write_out_mem (16#100010#, x"00000100");
    write_out_mem (16#100011#, x"00000200");
    write_out_mem (16#100012#, x"00000300");
    write_out_mem (16#100013#, x"00000400");
    write_out_mem (16#100014#, x"00000500");
    write_out_mem (16#100015#, x"00000600");
    write_out_mem (16#100016#, x"00000700");
    write_out_mem (16#100017#, x"00000800");
    write_out_mem (16#100018#, x"00000900");
    write_out_mem (16#100019#, x"00000A00");
    write_out_mem (16#10001A#, x"00000B00");
    write_out_mem (16#10001B#, x"00000C00");
    write_out_mem (16#10001C#, x"00000D00");
    write_out_mem (16#10001D#, x"00000E00");
    write_out_mem (16#10001E#, x"00000F00");
    write_out_mem (16#10001F#, x"00001000");
    write_time_mem(16#200010#, x"0003");
    write_time_mem(16#200011#, x"0003");
    write_time_mem(16#200012#, x"0003");
    write_time_mem(16#200013#, x"0003");
    write_time_mem(16#200014#, x"0003");
    write_time_mem(16#200015#, x"0003");
    write_time_mem(16#200016#, x"0003");
    write_time_mem(16#200017#, x"0003");
    write_time_mem(16#200018#, x"0003");
    write_time_mem(16#200019#, x"0003");
    write_time_mem(16#20001A#, x"0003");
    write_time_mem(16#20001B#, x"0003");
    write_time_mem(16#20001C#, x"0003");
    write_time_mem(16#20001D#, x"0003");
    write_time_mem(16#20001E#, x"0003");
    write_time_mem(16#20001F#, x"0003");
    write_time_mem(16#200020#, x"0000");          -- sentinel (T22 wrote this to 0x0003)
    write_prog_mem(16#300000#, x"11000001");      -- func_call(F1, rep=1)
    write_prog_mem(16#300001#, x"F0000000");      -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev( 0) := x"00000100"; ed( 0) := 4;   -- F1 ts0
    ev( 1) := x"00000200"; ed( 1) := 3;   -- F1 ts1
    ev( 2) := x"00000300"; ed( 2) := 3;
    ev( 3) := x"00000400"; ed( 3) := 3;
    ev( 4) := x"00000500"; ed( 4) := 3;
    ev( 5) := x"00000600"; ed( 5) := 3;
    ev( 6) := x"00000700"; ed( 6) := 3;
    ev( 7) := x"00000800"; ed( 7) := 3;
    ev( 8) := x"00000900"; ed( 8) := 3;
    ev( 9) := x"00000A00"; ed( 9) := 3;
    ev(10) := x"00000B00"; ed(10) := 3;
    ev(11) := x"00000C00"; ed(11) := 3;
    ev(12) := x"00000D00"; ed(12) := 3;
    ev(13) := x"00000E00"; ed(13) := 3;
    ev(14) := x"00000F00"; ed(14) := 3;
    ev(15) := x"00001000"; ed(15) := 5;   -- F1 ts15 (last)
    ev(16) := F0_V0;        ed(16) := 4;
    ev(17) := F0_V1;        ed(17) := 5;
    en := 18;
    run_test("T28: 16-slice function (full function depth)", ev, ed, en);

    -- ======================================================================
    -- T29 : 4-level subroutine nesting, minimum passing body depth (DISC-008)
    -- ======================================================================
    -- DISC-008: the extractor unwinds N stack levels (≈ 5 cycles each) after
    -- queuing the last func_call.  If the executor finishes K func_calls before
    -- the extractor writes end_sequence into the FIFO, the sequencer hangs.
    -- Hang-free condition: K × T_exec > N × 5.
    -- For 2-slice functions (T_exec ≈ 8 cycles): K ≥ ⌈N × 5/8⌉.
    -- At N=4: K ≥ 3.  This test uses K=3 (minimum passing configuration).
    --
    -- Program (N=4, K=3):
    --   [0]  jump_to_add(addr=8,  rep=1) = 0x50080001  L1
    --   [1]  end_sequence                = 0xF0000000
    --   [8]  jump_to_add(addr=10, rep=1) = 0x500A0001  L1 body: L2 jump
    --   [9]  L1 sub_trailer              = 0xE0000001
    --   [10] jump_to_add(addr=12, rep=1) = 0x500C0001  L2 body: L3 jump
    --   [11] L2 sub_trailer              = 0xE0000001
    --   [12] jump_to_add(addr=14, rep=1) = 0x500E0001  L3 body: L4 jump
    --   [13] L3 sub_trailer              = 0xE0000001
    --   [14] func_call(F1,rep=1)         = 0x11000001  } L4 innermost body
    --   [15] func_call(F2,rep=1)         = 0x12000001  } K=3 calls
    --   [16] func_call(F1,rep=1)         = 0x11000001  }
    --   [17] L4 sub_trailer              = 0xE0000001
    -- F1: 0xCC x4, 0xDD x7  (times 3,5)
    -- F2: 0xEE x4, 0xFF x7  (times 3,5)
    -- Expected: CC x4, DD x7, EE x4, FF x7, CC x4, DD x7, F0_V0 x4, F0_V1 x5
    -- Latency: trigger -> first-change = 20 cycles (N=4 baseline)
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"000000CC", x"000000DD");
    load_fn2(2, x"0003", x"0005", x"000000EE", x"000000FF");
    write_prog_mem(16#300000#, x"50080001");   -- L1: jump_to_add(addr=8,  rep=1)
    write_prog_mem(16#300001#, x"F0000000");   -- end_sequence
    write_prog_mem(16#300008#, x"500A0001");   -- L2: jump_to_add(addr=10, rep=1)
    write_prog_mem(16#300009#, x"E0000001");   -- L1 sub_trailer
    write_prog_mem(16#30000A#, x"500C0001");   -- L3: jump_to_add(addr=12, rep=1)
    write_prog_mem(16#30000B#, x"E0000001");   -- L2 sub_trailer
    write_prog_mem(16#30000C#, x"500E0001");   -- L4: jump_to_add(addr=14, rep=1)
    write_prog_mem(16#30000D#, x"E0000001");   -- L3 sub_trailer
    write_prog_mem(16#30000E#, x"11000001");   -- func_call(F1, rep=1)  K=3 body
    write_prog_mem(16#30000F#, x"12000001");   -- func_call(F2, rep=1)
    write_prog_mem(16#300010#, x"11000001");   -- func_call(F1, rep=1)
    write_prog_mem(16#300011#, x"E0000001");   -- L4 sub_trailer
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"000000CC"; ed(0) := 4;   -- F1 ts0
    ev(1) := x"000000DD"; ed(1) := 7;   -- F1 ts1
    ev(2) := x"000000EE"; ed(2) := 4;   -- F2 ts0
    ev(3) := x"000000FF"; ed(3) := 7;   -- F2 ts1
    ev(4) := x"000000CC"; ed(4) := 4;   -- F1 ts0 (second call)
    ev(5) := x"000000DD"; ed(5) := 7;   -- F1 ts1
    ev(6) := F0_V0;        ed(6) := 4;
    ev(7) := F0_V1;        ed(7) := 5;
    en := 8;
    run_test("T29: 4-level nesting K=3 [DISC-008 minimum passing config]", ev, ed, en);

    -- ======================================================================
    -- T30 : Override register + sensor 1 output
    --
    -- Verifies that writing the override register for sensor 1 (s=1) replaces
    -- bits[12:0] of the sequencer output on that sensor while leaving sensor 0
    -- unaffected.  Override is activated by setting bit[31]=1 in the override
    -- register; deactivated by writing bit[31]=0 (or by do_reset).
    --
    -- RTL: Sequencer.vhd sensors_generate block.
    --   sequencer_masked(s)(31:13) always = sequencer_aligned(0)(31:13)
    --   sequencer_masked(s)(12:0)  = override(s)(12:0) when override(s)(31)='1'
    --                                else sequencer_aligned(0)(12:0)
    --   Override register resets to 0 on do_reset.
    --
    -- Function / program:
    --   F1: ts0=0x00000100, ts1=0x00000200 (no bits above 12; bits[31:13]=0)
    --   t0=3, t1=5
    --   Program: [0]=func_call(F1,rep=1), [1]=end_sequence
    --   F0: standard (0x00000001, 0x00000002, t0=3, t1=3)
    --
    -- Phase A (no override — both sensors identical):
    --   Sensor 0 = Sensor 1: 0x00000100×4, 0x00000200×7, 0x01×4, 0x02×5
    --   Tested via run_test (sensor 0) and inline (sensor 1).
    --
    -- Phase B (override sensor 1 with 0x80001234):
    --   Sensor 0: unchanged — 0x00000100×4, 0x00000200×7, 0x01×4, 0x02×5
    --   Sensor 1: bits[31:13]=0 (same as aligned), bits[12:0]=0x1234 → 0x00001234×20
    --   Checked inline for both sensors.
    --
    -- Phase C (override cleared by do_reset — both sensors back to normal):
    --   Sensor 0: same as Phase A.  Tested via run_test.
    --
    -- Hardware note: T30 is sim-only (no ILA capture; override_we is testbench-
    --   internal and cannot be driven from the hardware register bus).
    -- ======================================================================

    -- ── Phase A : no override ─────────────────────────────────────────────
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0005", x"00000100", x"00000200");
    write_prog_mem(16#300000#, x"11000001");   -- func_call(F1,rep=1)
    write_prog_mem(16#300001#, x"F0000000");   -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"00000100"; ed(0) := 4;   -- F1 ts0
    ev(1) := x"00000200"; ed(1) := 7;   -- F1 ts1
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T30A: override register Phase A (no override, sensor 0)", ev, ed, en);

    -- ── Phase B : override sensor 1 ───────────────────────────────────────
    -- do_reset clears override_we; memories are still loaded from Phase A.
    do_reset;
    write_override(1, x"80001234");   -- bit[31]=1, bits[12:0]=0x1234

    -- Fire trigger manually (sync_cmd_start path, addr=0)
    hang_trig_cyc := cycle_cnt;
    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Auto-detect first-change: wait until sensor 0 output differs from idle (F0_V0)
    -- then report startup latency and begin pattern checking.
    t30_pass     := true;
    t30_end_seen := false;
    t30_end_cycle := -1;
    -- Wait up to 20 cycles for first-change
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      t30_out0 := to_slv32(sequencer_out(0));
      if t30_out0 /= F0_V0 then
        report "NOTE: T30B startup latency = " &
               integer'image(cycle_cnt - hang_trig_cyc) & " cycles (first-change)";
        exit;
      end if;
      if i = 20 then
        t30_pass := false;
        report "FAIL: T30B -- first-change not detected within 20 cycles" severity error;
      end if;
    end loop;

    -- Now check 20 cycles starting from first-change (index 0 = first non-idle sample)
    -- First sample already captured in t30_out0 above; check it inline then loop for rest.
    if t30_pass then
      t30_out1 := to_slv32(sequencer_out(1));
      if end_sequence(0) = '1' and not t30_end_seen then
        t30_end_seen  := true;
        t30_end_cycle := cycle_cnt - hang_trig_cyc;
      end if;
      if t30_out0 /= T30B_EXP0(0) then
        t30_pass := false;
        report "FAIL: T30B sensor 0 mismatch at index 0" &
               ": expected " & to_hex8(T30B_EXP0(0)) &
               " got " & to_hex8(t30_out0) severity error;
      end if;
      if t30_out1 /= T30B_EXP1 then
        t30_pass := false;
        report "FAIL: T30B sensor 1 mismatch at index 0" &
               ": expected " & to_hex8(T30B_EXP1) &
               " got " & to_hex8(t30_out1) severity error;
      end if;
      for i in 1 to 19 loop
        wait until rising_edge(clk);
        t30_out0 := to_slv32(sequencer_out(0));
        t30_out1 := to_slv32(sequencer_out(1));
        if end_sequence(0) = '1' and not t30_end_seen then
          t30_end_seen  := true;
          t30_end_cycle := cycle_cnt - hang_trig_cyc;
        end if;
        if t30_out0 /= T30B_EXP0(i) then
          t30_pass := false;
          report "FAIL: T30B sensor 0 mismatch at index " & integer'image(i) &
                 ": expected " & to_hex8(T30B_EXP0(i)) &
                 " got " & to_hex8(t30_out0) severity error;
        end if;
        if t30_out1 /= T30B_EXP1 then
          t30_pass := false;
          report "FAIL: T30B sensor 1 mismatch at index " & integer'image(i) &
                 ": expected " & to_hex8(T30B_EXP1) &
                 " got " & to_hex8(t30_out1) severity error;
        end if;
      end loop;
    end if;
    -- end_sequence should fire somewhere during F0_V1
    if t30_pass and not t30_end_seen then
      t30_pass := false;
      report "FAIL: T30B -- end_sequence never observed in observation window" severity error;
    end if;
    if t30_pass then
      report "PASS: T30B: override register Phase B (sensor 1 overridden to 0x00001234)";
    end if;
    -- Brief settling gap
    for i in 1 to 10 loop wait until rising_edge(clk); end loop;

    -- ── Phase C : override cleared by do_reset ────────────────────────────
    do_reset;
    -- memories still loaded; override resets to 0 on do_reset
    -- Wait for pipeline to settle to correct idle output (F0 ts0 = 0x00000001)
    -- before run_test captures idle_out.
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    ev(0) := x"00000100"; ed(0) := 4;
    ev(1) := x"00000200"; ed(1) := 7;
    ev(2) := F0_V0;        ed(2) := 4;
    ev(3) := F0_V1;        ed(3) := 5;
    en := 4;
    run_test("T30C: override register Phase C (override cleared, sensor 0 back to normal)", ev, ed, en);

    -- ======================================================================
    -- T31 : ADC alignment shift (enable_conv_shift / shift counter)
    --
    -- Verifies that enabling the shift counter in sequencer_aligner_shifter_top
    -- delays the adc_trigger (bit 12) output by N extra pipeline stages, where N
    -- auto-increments each time bit 12 goes low in the delayed output.
    --
    -- RTL: sequencer_aligner_shifter_top.vhd
    --   Non-bit-12 bits: 3 registered stages (combinatorial output)
    --   Bit 12: srl_input_ff (1) + SRLC32E tap A (1+A) + shift_reg_out_ff (1) = 3+A stages
    --   shift_counter (A): auto-increments on falling edge of shift_reg_out_reg when
    --     en_shift_counter='1'; init_conv_shift resets counter to 0.
    --
    -- Exploration: run func_call(F1,rep=2) with bit-12 in ts0 and observe
    --   how bit 12 is delayed relative to other bits across the two repetitions.
    --   Iteration 1 uses counter=0 (no delay), then counter increments to 1.
    --   Iteration 2 uses counter=1 (1 extra cycle delay on bit 12).
    --
    -- Function:
    --   F1: ts0=0x00001100 (bit12=1, bit8=1), ts1=0x00000100 (bit12=0, bit8=1)
    --   t0=3, t1=3   → ts0 first=4 cyc, ts1 last=5 cyc per repetition
    --   Non-bit-12 bits: always 0x00000100 (bit 8 only) → no change between ts0/ts1
    --   Only bit 12 toggles: 1 in ts0, 0 in ts1
    --   Program: [0]=func_call(F1,rep=2), [1]=end_seq
    --   F0: standard
    --
    -- With counter=0 (iteration 1): no delay; ts0 = 0x00001100×4, ts1 = 0x00000100×5
    -- With counter=1 (iteration 2): bit 12 lags other bits by 1 cycle:
    --   ts0 start: bit 8 already reflects ts0 (0x00000100) for 1 extra cycle before
    --     bit 12 rises → 1 cycle of 0x00000100, then ts0 = 0x00001100×...
    --   Wait - bit 8 is constant (0x00000100) in both ts0 and ts1, so ts1→ts0
    --     transition: no change in non-bit-12 bits; bit 12 goes 0→1 delayed 1 cycle.
    --     ts1 end: 5 cycles; then 1 extra 0x00000100 cycle before bit 12 rises
    --     → effectively ts1 appears to be 5+1=6 cycles, followed by ts0.
    --   ts0 end: bit 12 goes 1→0 delayed 1 cycle → ts0 appears to be 4-1+1=? cycles
    --   (Counter increments to 2 after ts0 ends.)
    --
    -- Expected output sequence hardcoded from exploration run (T31.csv).
    -- Assertion-based: cycle-exact on sequencer_out(0) from first-change to end_seq.
    -- end_sequence must fire at cycle 34, busy must drop at cycle 35 from trigger.
    --
    -- Hardware note: T31 is sim-only (no ILA capture applicable).
    -- ======================================================================
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0003", x"00001100", x"00000100");
    write_prog_mem(16#300000#, x"11000002");   -- func_call(F1,rep=2)
    write_prog_mem(16#300001#, x"F0000000");   -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- Reset and enable shift counter for sequencer 0
    reg_write(x"330001", x"00000000");  -- init_conv_shift (addr x"33", bit0=1)
    -- Enable shift mode: write addr x"330000" with data(0)='1'
    reg_write(x"330000", x"00000001");  -- enable_conv_shift
    for i in 1 to 3 loop wait until rising_edge(clk); end loop;

    -- Fire trigger; also open CSV for diagnostics
    hang_trig_cyc    := cycle_cnt;
    t31_pass         := true;
    t31_end_seen     := false;
    t31_end_cycle    := -1;
    t31_busy_drop    := -1;
    t31_busy_seen    := false;

    file_open(hang_csv_file, SIM_DATA_DIR & "T31.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Auto-detect first-change: wait until output differs from idle (F0_V0),
    -- writing CSV for all pre-first-change cycles.
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      t31_out0 := to_slv32(sequencer_out(0));
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(t31_out0));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then t31_busy_seen := true; end if;
      if t31_out0 /= F0_V0 then
        report "NOTE: T31 startup latency = " &
               integer'image(cycle_cnt - hang_trig_cyc) & " cycles (first-change)";
        exit;
      end if;
      if i = 20 then
        t31_pass := false;
        report "FAIL: T31 -- first-change not detected within 20 cycles" severity error;
      end if;
    end loop;

    -- Check 23 cycles from first-change (index 0 already sampled as t31_out0).
    -- First sample check inline, then loop for indices 1..22.
    if t31_pass then
      if end_sequence(0) = '1' and not t31_end_seen then
        t31_end_seen  := true;
        t31_end_cycle := cycle_cnt - hang_trig_cyc;
      end if;
      if t31_out0 /= T31_EXP(0) then
        t31_pass := false;
        report "FAIL: T31 output mismatch at index 0" &
               " (cycle " & integer'image(cycle_cnt - hang_trig_cyc) & " from trigger)" &
               ": expected " & to_hex8(T31_EXP(0)) &
               " got " & to_hex8(t31_out0) severity error;
      end if;
      for i in 1 to 22 loop
        wait until rising_edge(clk);
        t31_out0 := to_slv32(sequencer_out(0));
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(t31_out0));
        writeline(hang_csv_file, hang_csv_line);
        if sequencer_busy(0) = '1' then t31_busy_seen := true; end if;
        if end_sequence(0) = '1' and not t31_end_seen then
          t31_end_seen  := true;
          t31_end_cycle := cycle_cnt - hang_trig_cyc;
        end if;
        if t31_out0 /= T31_EXP(i) then
          t31_pass := false;
          report "FAIL: T31 output mismatch at index " & integer'image(i) &
                 " (cycle " & integer'image(cycle_cnt - hang_trig_cyc) & " from trigger)" &
                 ": expected " & to_hex8(T31_EXP(i)) &
                 " got " & to_hex8(t31_out0) severity error;
        end if;
      end loop;
    end if;

    -- end_sequence must have fired during the pattern window
    if t31_pass and not t31_end_seen then
      t31_pass := false;
      report "FAIL: T31 -- end_sequence not observed in 23-cycle window" severity error;
    end if;

    -- Drain a few more cycles; busy must drop within drain window
    for i in 1 to 5 loop
      wait until rising_edge(clk);
      t31_out0 := to_slv32(sequencer_out(0));
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(t31_out0));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '0' and t31_busy_seen and t31_busy_drop = -1 then
        t31_busy_drop := cycle_cnt - hang_trig_cyc;
      end if;
    end loop;
    file_close(hang_csv_file);

    if t31_pass and t31_busy_drop = -1 then
      t31_pass := false;
      report "FAIL: T31 -- busy never dropped in drain window" severity error;
    end if;

    if t31_pass then
      report "PASS: T31: ADC alignment shift (enable_conv_shift / shift counter)";
    end if;

    -- ======================================================================
    -- T32 : do_reset resets shift_counter (init_conv_shift not needed after reset)
    --
    -- Purpose: Determine empirically whether do_reset is sufficient to reset
    -- shift_counter in sequencer_aligner_shifter_top, settling DISC-011 Claim B
    -- and the preconditions for W1/W2.
    --
    -- T31 always calls init_conv_shift before running, so it never tests whether
    -- do_reset alone resets the counter.  T32 omits init_conv_shift in Phase B.
    --
    -- Phase A: Advance shift_counter to a known non-zero value.
    --   do_reset → init_conv_shift (counter=0) → enable_conv_shift →
    --   func_call(F1,rep=2) → assert output = T31_EXP.
    --   After Phase A: shift_counter = 2 (two bit-12 falling edges processed).
    --
    -- Phase B: Test whether do_reset resets the counter.
    --   do_reset (WITHOUT init_conv_shift) → enable_conv_shift →
    --   func_call(F1,rep=2) → assert output = T31_EXP.
    --
    --   If PASS: counter was reset to 0 by do_reset → DISC-011 Claim B is wrong;
    --            no RTL fix needed; W1/W2 hazards are eliminated for this path.
    --   If FAIL: counter was NOT reset → DISC-011 Claim B is correct; RTL fix needed.
    --
    -- Memory layout: identical to T31.
    -- Hardware note: T32 is sim-only (no ILA capture applicable).
    -- ======================================================================
    do_reset;
    load_f0(F0_T0, F0_T1, F0_V0, F0_V1);
    load_fn2(1, x"0003", x"0003", x"00001100", x"00000100");
    write_prog_mem(16#300000#, x"11000002");   -- func_call(F1,rep=2)
    write_prog_mem(16#300001#, x"F0000000");   -- end_sequence
    for i in 1 to 5 loop wait until rising_edge(clk); end loop;

    -- ── Phase A: establish baseline with init_conv_shift ──────────────────
    -- counter=0 guaranteed by init_conv_shift pulse
    reg_write(x"330001", x"00000000");  -- init_conv_shift
    reg_write(x"330000", x"00000001");  -- enable_conv_shift
    for i in 1 to 3 loop wait until rising_edge(clk); end loop;

    hang_trig_cyc   := cycle_cnt;
    t32_pass        := true;
    t32_end_seen_a  := false;
    t32_end_cycle_a := -1;
    t32_busy_drop_a := -1;
    t32_busy_seen_a := false;

    file_open(hang_csv_file, SIM_DATA_DIR & "T32A.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Auto-detect first-change for Phase A
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      t32_out0 := to_slv32(sequencer_out(0));
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(t32_out0));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then t32_busy_seen_a := true; end if;
      if t32_out0 /= F0_V0 then
        report "NOTE: T32A startup latency = " &
               integer'image(cycle_cnt - hang_trig_cyc) & " cycles (first-change)";
        exit;
      end if;
      if i = 20 then
        t32_pass := false;
        report "FAIL: T32A -- first-change not detected within 20 cycles" severity error;
      end if;
    end loop;

    -- 23-cycle assertion window (index 0 already sampled)
    if t32_pass then
      if end_sequence(0) = '1' and not t32_end_seen_a then
        t32_end_seen_a  := true;
        t32_end_cycle_a := cycle_cnt - hang_trig_cyc;
      end if;
      if t32_out0 /= T31_EXP(0) then
        t32_pass := false;
        report "FAIL: T32A output mismatch at index 0" &
               " (cycle " & integer'image(cycle_cnt - hang_trig_cyc) & " from trigger)" &
               ": expected " & to_hex8(T31_EXP(0)) &
               " got " & to_hex8(t32_out0) severity error;
      end if;
      for i in 1 to 22 loop
        wait until rising_edge(clk);
        t32_out0 := to_slv32(sequencer_out(0));
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(t32_out0));
        writeline(hang_csv_file, hang_csv_line);
        if sequencer_busy(0) = '1' then t32_busy_seen_a := true; end if;
        if end_sequence(0) = '1' and not t32_end_seen_a then
          t32_end_seen_a  := true;
          t32_end_cycle_a := cycle_cnt - hang_trig_cyc;
        end if;
        if t32_out0 /= T31_EXP(i) then
          t32_pass := false;
          report "FAIL: T32A output mismatch at index " & integer'image(i) &
                 " (cycle " & integer'image(cycle_cnt - hang_trig_cyc) & " from trigger)" &
                 ": expected " & to_hex8(T31_EXP(i)) &
                 " got " & to_hex8(t32_out0) severity error;
        end if;
      end loop;
    end if;

    if t32_pass and not t32_end_seen_a then
      t32_pass := false;
      report "FAIL: T32A -- end_sequence not observed in 23-cycle window" severity error;
    end if;

    for i in 1 to 5 loop
      wait until rising_edge(clk);
      t32_out0 := to_slv32(sequencer_out(0));
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(t32_out0));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '0' and t32_busy_seen_a and t32_busy_drop_a = -1 then
        t32_busy_drop_a := cycle_cnt - hang_trig_cyc;
      end if;
    end loop;
    file_close(hang_csv_file);

    if t32_pass and t32_busy_drop_a = -1 then
      t32_pass := false;
      report "FAIL: T32A -- busy never dropped in drain window" severity error;
    end if;
    -- After Phase A: shift_counter = 2 (two bit-12 falling edges processed).

    -- ── Phase B: do_reset WITHOUT init_conv_shift ─────────────────────────
    -- If do_reset resets shift_counter, Phase B output = T31_EXP (counter=0).
    -- If not, counter=2 and bit-12 timing differs from T31_EXP.
    do_reset;
    -- NO init_conv_shift here -- that is the entire point of this phase.
    -- Re-enable shift mode (internal latch cleared by rst; must re-write).
    reg_write(x"330000", x"00000001");  -- enable_conv_shift
    for i in 1 to 3 loop wait until rising_edge(clk); end loop;

    hang_trig_cyc   := cycle_cnt;
    t32_end_seen_b  := false;
    t32_end_cycle_b := -1;
    t32_busy_drop_b := -1;
    t32_busy_seen_b := false;

    file_open(hang_csv_file, SIM_DATA_DIR & "T32B.csv", write_mode);
    write(hang_csv_line, string'("sample_idx,busy,end_seq,seq_out"));
    writeline(hang_csv_file, hang_csv_line);

    sync_cmd_start     <= '1';
    sync_cmd_main_addr <= "00000";
    wait until rising_edge(clk);
    sync_cmd_start     <= '0';
    sync_cmd_main_addr <= (others => '0');

    -- Auto-detect first-change for Phase B
    for i in 1 to 20 loop
      wait until rising_edge(clk);
      t32_out0 := to_slv32(sequencer_out(0));
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(t32_out0));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '1' then t32_busy_seen_b := true; end if;
      if t32_out0 /= F0_V0 then
        report "NOTE: T32B startup latency = " &
               integer'image(cycle_cnt - hang_trig_cyc) & " cycles (first-change)";
        exit;
      end if;
      if i = 20 then
        t32_pass := false;
        report "FAIL: T32B -- first-change not detected within 20 cycles" severity error;
      end if;
    end loop;

    -- 23-cycle assertion window (index 0 already sampled)
    if t32_pass then
      if end_sequence(0) = '1' and not t32_end_seen_b then
        t32_end_seen_b  := true;
        t32_end_cycle_b := cycle_cnt - hang_trig_cyc;
      end if;
      if t32_out0 /= T31_EXP(0) then
        t32_pass := false;
        report "FAIL: T32B output mismatch at index 0" &
               " (cycle " & integer'image(cycle_cnt - hang_trig_cyc) & " from trigger)" &
               ": expected " & to_hex8(T31_EXP(0)) &
               " got " & to_hex8(t32_out0) severity error;
      end if;
      for i in 1 to 22 loop
        wait until rising_edge(clk);
        t32_out0 := to_slv32(sequencer_out(0));
        write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, std_logic'image(end_sequence(0))(2));
        write(hang_csv_line, string'(","));
        write(hang_csv_line, to_hex8(t32_out0));
        writeline(hang_csv_file, hang_csv_line);
        if sequencer_busy(0) = '1' then t32_busy_seen_b := true; end if;
        if end_sequence(0) = '1' and not t32_end_seen_b then
          t32_end_seen_b  := true;
          t32_end_cycle_b := cycle_cnt - hang_trig_cyc;
        end if;
        if t32_out0 /= T31_EXP(i) then
          t32_pass := false;
          report "FAIL: T32B output mismatch at index " & integer'image(i) &
                 " (cycle " & integer'image(cycle_cnt - hang_trig_cyc) & " from trigger)" &
                 ": expected " & to_hex8(T31_EXP(i)) &
                 " got " & to_hex8(t32_out0) severity error;
        end if;
      end loop;
    end if;

    if t32_pass and not t32_end_seen_b then
      t32_pass := false;
      report "FAIL: T32B -- end_sequence not observed in 23-cycle window" severity error;
    end if;

    for i in 1 to 5 loop
      wait until rising_edge(clk);
      t32_out0 := to_slv32(sequencer_out(0));
      write(hang_csv_line, to_dec_str(cycle_cnt - hang_trig_cyc));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(sequencer_busy(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, std_logic'image(end_sequence(0))(2));
      write(hang_csv_line, string'(","));
      write(hang_csv_line, to_hex8(t32_out0));
      writeline(hang_csv_file, hang_csv_line);
      if sequencer_busy(0) = '0' and t32_busy_seen_b and t32_busy_drop_b = -1 then
        t32_busy_drop_b := cycle_cnt - hang_trig_cyc;
      end if;
    end loop;
    file_close(hang_csv_file);

    if t32_pass and t32_busy_drop_b = -1 then
      t32_pass := false;
      report "FAIL: T32B -- busy never dropped in drain window" severity error;
    end if;

    if t32_pass then
      report "PASS: T32: do_reset resets shift_counter (init_conv_shift not required after reset)";
    end if;

    done <= true;
    wait;

  end process;

end architecture sim;
