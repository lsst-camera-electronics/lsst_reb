----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    15:06:03 07/10/2015
-- Design Name:
-- Module Name:    ad56xx_DAC_top - Behavioral
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
use IEEE.STD_LOGIC_1164.ALL;

library lsst_reb;

entity ad56xx_DAC_top is

port (
    clk           : in  std_logic;
    reset           : in  std_logic;
    start_write       : in  std_logic;
    start_ldac        : in  std_logic;
    d_to_slave        : in  std_logic_vector(23 downto 0);
    mosi            : out std_logic;
    ss              : out std_logic;
    sclk            : out std_logic;
    ldac            : out std_logic
    );

end ad56xx_DAC_top;

architecture Behavioral of ad56xx_DAC_top is

signal ldac_delay_1 : std_logic;
signal ldac_delay_2 : std_logic;

begin

SPI_write_0 : entity lsst_reb.SPI_write
generic map (clk_divide  => 2,
         num_bit_max => 24)
port map (
    clk           => clk,
    reset           => reset,
    start_write       => start_write,
    d_to_slave        => d_to_slave,
    mosi            => mosi,
    ss              => ss,
    sclk            => sclk
    );

ldac_delay_ff_1 : entity lsst_reb.ff_ce
port map (
    reset    => reset,
    clk      => clk,
    data_in  => start_ldac,
   ce       => '1',
    data_out => ldac_delay_1);

ldac_delay_ff_2 : entity lsst_reb.ff_ce
port map (
    reset    => reset,
    clk      => clk,
    data_in  => ldac_delay_1,
   ce       => '1',
    data_out => ldac_delay_2);

ldac  <= not(ldac_delay_1 or ldac_delay_2);

end Behavioral;

