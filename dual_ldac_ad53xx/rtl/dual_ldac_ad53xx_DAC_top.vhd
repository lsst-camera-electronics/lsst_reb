----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    12:51:43 07/01/2016
-- Design Name:
-- Module Name:    dual_ldac_ad53xx_DAC_top - Behavioral
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

entity dual_ldac_ad53xx_DAC_top is

  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    start_write  : in  std_logic;
    start_ldac_1 : in  std_logic;
    start_ldac_2 : in  std_logic;
    d_to_slave   : in  std_logic_vector(15 downto 0);
    mosi         : out std_logic;
    ss_dac       : out std_logic;
    sclk         : out std_logic;
    ldac_1       : out std_logic;
    ldac_2       : out std_logic
    );

end dual_ldac_ad53xx_DAC_top;

architecture Behavioral of dual_ldac_ad53xx_DAC_top is

  signal ldac_1_delay_1 : std_logic;
  signal ldac_1_delay_2 : std_logic;

  signal ldac_2_delay_1 : std_logic;
  signal ldac_2_delay_2 : std_logic;

begin

  SPI_write_0 : entity lsst_reb.SPI_write
    generic map (clk_divide  => 2,
                 num_bit_max => 16)
    port map (
      clk         => clk,
      reset       => reset,
      start_write => start_write,
      d_to_slave  => d_to_slave,
      mosi        => mosi,
      ss          => ss_dac,
      sclk        => sclk
      );


  ldac_1_delay_ff_1 : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => start_ldac_1,
      ce       => '1',
      data_out => ldac_1_delay_1);

  ldac_1_delay_ff_2 : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => ldac_1_delay_1,
      ce       => '1',
      data_out => ldac_1_delay_2);

  ldac_1 <= not(ldac_1_delay_1 or ldac_1_delay_2);


  ldac_2_delay_ff_1 : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => start_ldac_2,
      ce       => '1',
      data_out => ldac_2_delay_1);

  ldac_2_delay_ff_2 : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => ldac_2_delay_1,
      ce       => '1',
      data_out => ldac_2_delay_2);

  ldac_2 <= not(ldac_2_delay_1 or ldac_2_delay_2);


end Behavioral;

