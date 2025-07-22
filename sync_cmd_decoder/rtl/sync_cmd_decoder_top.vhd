----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    14:45:25 03/09/2017
-- Design Name:
-- Module Name:    sync_cmd_decoder_top - Behavioral
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

library UNISIM;
use UNISIM.VComponents.all;

library lsst_reb;

entity sync_cmd_decoder_top is

  port (
    pgp_clk            : in  std_logic;
    pgp_reset          : in  std_logic;
    clk                : in  std_logic;
    reset              : in  std_logic;
    sync_cmd_en        : in  std_logic;
    delay_en           : in  std_logic;
    delay_in           : in  std_logic_vector(7 downto 0);
    delay_read         : out std_logic_vector(7 downto 0);
    sync_cmd           : in  std_logic_vector(7 downto 0);
    sync_cmd_start_seq : out std_logic;  -- this signal is delayed buy at least
                                         -- 1 clk with respect to sync_cmd_main_add
    sync_cmd_step_seq  : out std_logic;  -- this signal is delayed buy at least
                                         -- 1 clk with respect to sync_cmd_main_add
    sync_cmd_stop_seq  : out std_logic;  -- this signal is delayed buy at least
                                         -- 1 clk with respect to sync_cmd_main_add
    sync_cmd_main_add  : out std_logic_vector(4 downto 0)
    );

end sync_cmd_decoder_top;

architecture Behavioral of sync_cmd_decoder_top is

  signal sync_cmd_en_stretch : std_logic;
  signal sync_cmd_en_sync1   : std_logic;
  signal sync_cmd_en_sync2   : std_logic;
  signal sync_cmd_en_sync    : std_logic;
  signal sync_cmd_latch      : std_logic_vector(7 downto 0);
  signal sync_cmd_start_int  : std_logic;
  signal sync_cmd_step_int   : std_logic;
  signal sync_cmd_stop_int   : std_logic;
  signal sync_cmd_addr_int   : std_logic_vector(4 downto 0);
  signal delay_in_reg        : std_logic_vector(7 downto 0);

begin

  sync_cmd_reg : entity lsst_reb.generic_reg_ce_init
    generic map
    (width => 7)
    port map (
      reset    => pgp_reset,
      clk      => pgp_clk,
      ce       => sync_cmd_en,
      init     => '0',
      data_in  => sync_cmd,
      data_out => sync_cmd_latch);

  -- pulse stretcher
  pulse_stretcher_A : entity lsst_reb.pulse_stretcher
    generic map (
      STRETCH_SIZE => 2)
    port map (
      clk         => pgp_clk,
      reset       => pgp_reset,
      sig_in      => sync_cmd_en,
      stretch_out => sync_cmd_en_stretch);

  ff1_en : FD port map (D => sync_cmd_en_stretch, C => clk, Q => sync_cmd_en_sync1);
  ff2_en : FD port map (D => sync_cmd_en_sync1, C => clk, Q => sync_cmd_en_sync);

  sync_cmd_decoder_1 : entity lsst_reb.sync_cmd_decoder
    port map (
      clk          => clk,
      reset        => reset,
      sync_cmd_en  => sync_cmd_en_sync,
      sync_cmd     => sync_cmd_latch,
      sync_cmd_start => sync_cmd_start_int,
      sync_cmd_step  => sync_cmd_step_int,
      sync_cmd_stop  => sync_cmd_stop_int,
      sync_cmd_addr  => sync_cmd_addr_int
      );

  delay_register : entity lsst_reb.generic_reg_ce_init
    generic map
    (width => 7)
    port map (
      reset    => reset,
      clk      => clk,
      ce       => delay_en,
      init     => '0',
      data_in  => delay_in,
      data_out => delay_in_reg);

  programmable_delay_start : entity lsst_reb.programmable_delay
    port map (
      clk        => clk,
      reset      => reset,
      signal_in  => sync_cmd_start_int,
      delay_in   => delay_in_reg,
      signal_out => sync_cmd_start_seq
      );

  programmable_delay_step : entity lsst_reb.programmable_delay
    port map (
      clk        => clk,
      reset      => reset,
      signal_in  => sync_cmd_step_int,
      delay_in   => delay_in_reg,
      signal_out => sync_cmd_step_seq
      );

  programmable_delay_stop : entity lsst_reb.programmable_delay
    port map (
      clk        => clk,
      reset      => reset,
      signal_in  => sync_cmd_stop_int,
      delay_in   => delay_in_reg,
      signal_out => sync_cmd_stop_seq
      );

  delay_read        <= delay_in_reg;
  sync_cmd_main_add <= sync_cmd_addr_int;

end Behavioral;

