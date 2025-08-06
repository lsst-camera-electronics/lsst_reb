----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    17:43:16 04/10/2013
-- Design Name:
-- Module Name:    function_v3_top - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

library lsst_reb;

entity function_v3_top is

  port (
    reset : in std_logic;               -- syncronus reset
    clk   : in std_logic;               -- clock

    time_mem_w_en   : in  std_logic;
    time_mem_in     : in  std_logic_vector(15 downto 0);
    time_mem_w_add  : in  std_logic_vector(7 downto 0);
    time_mem_readbk : out std_logic_vector(15 downto 0);

    out_mem_w_en   : in  std_logic;
    out_mem_in     : in  std_logic_vector(31 downto 0);
    out_mem_w_add  : in  std_logic_vector(7 downto 0);
    out_mem_readbk : out std_logic_vector(31 downto 0);

    fifo_empty     : in  std_logic;
    fifo_read_en   : out std_logic;
    fifo_param_out : in  std_logic_vector(31 downto 0);

    stop_sequence : in std_logic;
    step_sequence : in std_logic;

    sequencer_busy : out std_logic;
    sequencer_out  : out std_logic_vector(31 downto 0);
    end_sequence   : out std_logic
    );

end function_v3_top;

architecture Behavioral of function_v3_top is

  signal end_rep_cnt        : std_logic;
  signal init_rep_cnt       : std_logic;
  signal en_rep_cnt         : std_logic;
  signal start_func         : std_logic;
  signal end_func           : std_logic;
  signal sequencer_busy_int : std_logic;

  signal out_ce            : std_logic;
  signal out_ce_1          : std_logic;
  signal out_ce_2          : std_logic;
  signal sequencer_out_mem : std_logic_vector(31 downto 0);

  signal veto_out : std_logic;

begin

  function_executor_v3_0 : entity lsst_reb.function_executor_v3
    port map (
      clk               => clk,
      reset             => reset,
      fifo_empty        => fifo_empty,
      func_end          => end_func,
      func_rep_cnt_end  => end_rep_cnt,
      func_inf_loop     => fifo_param_out(23),
      prog_end_opcode   => fifo_param_out(31 downto 28),
      func_stop         => stop_sequence,
      func_step         => step_sequence,
      func_rep_cnt_init => init_rep_cnt,
      fifo_read_en      => fifo_read_en,
      func_start        => start_func,
      func_rep_cnt_en   => en_rep_cnt,
      sequencer_busy    => sequencer_busy_int,
      veto_out          => veto_out,
      end_sequence      => end_sequence
      );

  rep_counter : entity lsst_reb.generic_counter_comparator_ce_init
    generic map (length_cnt => 22)
    port map (
      reset     => reset,               -- syncronus reset
      clk       => clk,                 -- clock
      max_value => fifo_param_out(22 downto 0),  -- maximum value the counter has to count
      enable    => en_rep_cnt,          -- enable
      init      => init_rep_cnt,
      cnt_end   => end_rep_cnt);  -- signal = 1 when the counter reach the maximum

  function_v3_0 : entity lsst_reb.function_v3
    generic map (time_bus_width => 16,
                 out_bus_width  => 32,
                 time_slice_num => 16,
                 function_num   => 15
                 )
    port map (
      reset          => reset,          -- syncronus reset
      clk            => clk,            -- clock
      start_func     => start_func,
      sequencer_busy => sequencer_busy_int,

      time_mem_w_en  => time_mem_w_en,
      time_mem_in    => time_mem_in,
      time_mem_w_add => time_mem_w_add,
      time_func_add  => fifo_param_out(27 downto 24),
      time_mem_out_2 => time_mem_readbk,

      out_mem_w_en  => out_mem_w_en,
      out_mem_in    => out_mem_in,
      out_mem_w_add => out_mem_w_add,
      out_func_add  => fifo_param_out(27 downto 24),
      out_mem_out_2 => out_mem_readbk,

      end_func        => end_func,
      signal_out_func => sequencer_out_mem
      );

  output_reg : entity lsst_reb.generic_reg_ce_init
    generic map (width => 31)
    port map (
      reset    => reset,
      clk      => clk,
      ce       => out_ce,
      init     => '0',  -- signal to reset the reg (active high)
      data_in  => sequencer_out_mem,
      data_out => sequencer_out);

  out_ce_delay_1 : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => out_ce_1,
      ce       => '1',
      data_out => out_ce_2);

  out_ce   <= not (out_ce_1 or out_ce_2);
  out_ce_1 <= end_func or veto_out;

  sequencer_busy <= sequencer_busy_int;

end Behavioral;

