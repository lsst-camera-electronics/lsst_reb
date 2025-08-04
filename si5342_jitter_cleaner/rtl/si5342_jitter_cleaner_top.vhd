----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    16:52:42 11/18/2016
-- Design Name:
-- Module Name:    si5342_jitter_cleaner_top - Behavioral
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

entity si5342_jitter_cleaner_top is

  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    start_config : in  std_logic;
    jc_config    : in  std_logic_vector(1 downto 0);
    config_busy  : out std_logic;
    jc_clk_ready : out std_logic;
    jc_clk_in_en : out std_logic;
    miso         : in  std_logic;
    mosi         : out std_logic;
    chip_select  : out std_logic;
    sclk         : out std_logic
    );

end si5342_jitter_cleaner_top;

architecture Behavioral of si5342_jitter_cleaner_top is

  signal link_busy        : std_logic;
  signal start_write      : std_logic;
  signal start_spi        : std_logic;
  signal spi_busy         : std_logic;
  signal jc_clk_ready_int : std_logic;
  signal jc_clk_ready_en  : std_logic;
  signal jc_in_clk_en     : std_logic;
  signal page             : std_logic_vector(7 downto 0);
  signal address          : std_logic_vector(7 downto 0);
  signal data             : std_logic_vector(7 downto 0);
  signal data_to_spi      : std_logic_vector(15 downto 0);

begin

  si5342_jitter_cleaner_fsm_rom_1 : entity lsst_reb.si5342_jitter_cleaner_fsm_rom
    port map (
      clk             => clk,
      reset           => reset,
      start_config    => start_config,
      link_busy       => link_busy,
      jc_config       => jc_config,
      start_write     => start_write,
      config_busy     => config_busy,
      jc_clk_ready    => jc_clk_ready_int,
      jc_clk_ready_en => jc_clk_ready_en,
      jc_in_clk_en    => jc_in_clk_en,
      page            => page,
      address         => address,
      data_out        => data);

  si5342_reg_write_fsm_1 : entity lsst_reb.si5342_reg_write_fsm
    port map (
      clk         => clk,
      reset       => reset,
      start_write => start_write,
      spi_busy    => spi_busy,
      page        => page,
      address     => address,
      data_in     => data,
      start_spi   => start_spi,
      link_busy   => link_busy,
      data_to_spi => data_to_spi);

  SPI_write_BusyatStart_1 : entity lsst_reb.SPI_write_BusyatStart
    generic map (
      clk_divide  => 5,
      num_bit_max => 16)
    port map (
      clk         => clk,
      reset       => reset,
      start_write => start_spi,
      d_to_slave  => data_to_spi,
      busy        => spi_busy,
      mosi        => mosi,
      ss          => chip_select,
      sclk        => sclk);

  clk_ready_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => jc_clk_ready_int,
      ce       => jc_clk_ready_en,
      data_out => jc_clk_ready);

  clk_in_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => jc_clk_ready_int,
      ce       => jc_in_clk_en,
      data_out => jc_clk_in_en);

end Behavioral;

