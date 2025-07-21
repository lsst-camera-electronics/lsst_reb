----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    17:06:09 07/08/2016
-- Design Name:
-- Module Name:    dual_ads1118_top - Behavioral
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
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library lsst_reb;
use lsst_reb.basic_elements_pkg.all;

entity dual_ads1118_top is

  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    start_read    : in  std_logic;
    device_select : in  std_logic;
    miso          : in  std_logic;
    mosi          : out std_logic;
    ss_adc_1      : out std_logic;
    ss_adc_2      : out std_logic;
    sclk          : out std_logic;
    link_busy     : out std_logic;
    data_from_adc : out array432
    );

end dual_ads1118_top;

architecture Behavioral of dual_ads1118_top is

  signal spi_busy          : std_logic;
  signal start_spi         : std_logic;
  signal device_select_int : std_logic;
  signal data_to_spi_16    : std_logic_vector(15 downto 0);
  signal data_to_spi       : std_logic_vector(31 downto 0);
  signal out_reg_en_bus    : std_logic_vector(3 downto 0);
  signal data_from_spi     : std_logic_vector(31 downto 0);
  signal ss_bus            : std_logic_vector(1 downto 0);

  signal ss_int   : std_logic;
  signal miso_int : std_logic;
  signal mosi_int : std_logic;
  signal sclk_int : std_logic;

begin

  dual_ads1118_controller_fsm_1 : entity lsst_reb.dual_ads1118_controller_fsm
    port map (
      clk            => clk,
      reset          => reset,
      start_read     => start_read,
      spi_busy       => spi_busy,
      device_busy    => miso_int,
      start_spi      => start_spi,
      link_busy      => link_busy,
      data_to_spi    => data_to_spi_16,
      out_reg_en_bus => out_reg_en_bus);

  ff_ce_1 : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => device_select,
      ce       => start_read,
      data_out => device_select_int);

  SPI_read_write_noss_1 : entity lsst_reb.SPI_read_write_noss
    generic map (
      clk_divide  => 10,
      num_bit_max => 32)
    port map (
      clk          => clk,
      reset        => reset,
      start_write  => start_spi,
      d_to_slave   => data_to_spi,
      miso         => miso_int,
      mosi         => mosi_int,
      ss           => ss_int,
      sclk         => sclk_int,
      busy         => spi_busy,
      d_from_slave => data_from_spi);



  spi_out_reg_generate :
  for i in 0 to 3 generate
    out_reg : entity lsst_reb.generic_reg_ce_init
      generic map(width => 31)
      port map (
        reset    => reset,
        clk      => clk,
        ce       => out_reg_en_bus(i),
        init     => '0',
        data_in  => data_from_spi,
        data_out => data_from_adc(i)
        );
  end generate;



  ff_ce_mosi : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => mosi_int,
      ce       => '1',
      data_out => mosi);

  ff_ce_miso : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => miso,
      ce       => '1',
      data_out => miso_int);

  ff_ce_sckl : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => sclk_int,
      ce       => '1',
      data_out => sclk);

  demux_1_2_clk_def_1_1 : entity lsst_reb.demux_1_2_clk_def_1
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => ss_int,
      selector => device_select_int,
      data_out => ss_bus);

  data_to_spi <= data_to_spi_16 & x"0000";
  ss_adc_1    <= ss_bus(0);
  ss_adc_2    <= ss_bus(1);

end Behavioral;
