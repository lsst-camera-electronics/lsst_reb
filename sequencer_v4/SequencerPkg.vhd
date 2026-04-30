library IEEE;
use IEEE.STD_LOGIC_1164.all;

package SequencerPkg is

  type SequencerOutputType is record
    aspic_r_up    : std_logic;
    aspic_r_down  : std_logic;
    aspic_reset   : std_logic;
    aspic_clamp   : std_logic;
    ser_clk       : std_logic_vector(2 downto 0);
    reset_gate    : std_logic;
    par_clk       : std_logic_vector(3 downto 0);
    adc_trigger   : std_logic;
    soi           : std_logic;
    eoi           : std_logic;
    pattern_reset : std_logic;
    cabac_pulse   : std_logic;
    user_bit      : std_logic;
  end record SequencerOutputType;

  type SequencerOutputArray is array (natural range <>) of SequencerOutputType;

  ---------------------------------------------------------------------------
  -- Sequencer Register Map Configuration
  --
  -- Each field specifies the upper address byte (addr[23:16]) that selects
  -- a register block inside the Sequencer entity.  Instance selection uses
  -- addr[13:12] (sequencer instance for most blocks, sensor index for
  -- override).  The lower bits addr[9:0] provide the memory offset.
  --
  -- This type is defined here so that lsst_reb remains address-agnostic;
  -- each project defines a concrete constant in its commands package and
  -- passes it to the Sequencer entity via the REG_MAP_G generic.
  ---------------------------------------------------------------------------
  type SeqRegMapType is record
    out_mem     : std_logic_vector(7 downto 0);  -- output memory
    time_mem    : std_logic_vector(7 downto 0);  -- timing memory
    prog_mem    : std_logic_vector(7 downto 0);  -- program memory
    step_cmd    : std_logic_vector(7 downto 0);  -- single-step command
    stop_cmd    : std_logic_vector(7 downto 0);  -- stop command
    conv_shift  : std_logic_vector(7 downto 0);  -- ADC conv shift enable/init
    start_addr  : std_logic_vector(7 downto 0);  -- start address
    ind_func    : std_logic_vector(7 downto 0);  -- indirect function memory
    ind_rep     : std_logic_vector(7 downto 0);  -- indirect repeat memory
    ind_sub_add : std_logic_vector(7 downto 0);  -- indirect subroutine address memory
    ind_sub_rep : std_logic_vector(7 downto 0);  -- indirect subroutine repeat memory
    error_stat  : std_logic_vector(7 downto 0);  -- opcode error status/reset
    override    : std_logic_vector(7 downto 0);  -- per-sensor output override
  end record SeqRegMapType;

  -- Convenience constant with the standard address layout.  Projects must
  -- pass this (or a project-specific variant) explicitly to REG_MAP_G;
  -- the generic has no default.
  constant SEQ_REG_MAP_DEFAULT_C : SeqRegMapType := (
    out_mem     => x"10",
    time_mem    => x"20",
    prog_mem    => x"30",
    step_cmd    => x"31",
    stop_cmd    => x"32",
    conv_shift  => x"33",
    start_addr  => x"34",
    ind_func    => x"35",
    ind_rep     => x"36",
    ind_sub_add => x"37",
    ind_sub_rep => x"38",
    error_stat  => x"39",
    override    => x"3A"
  );

end package SequencerPkg;
