----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    10:51:29 05/02/2013
-- Design Name:
-- Module Name:    ad7794_top - Behavioral
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

entity ad7794_top is

port (
    clk             : in  std_logic;
    reset           : in  std_logic;
    start           : in  std_logic;
    start_reset     : in  std_logic;
    read_write      : in  std_logic;
    ad7794_dout_rdy : in  std_logic;
    reg_add         : in  std_logic_vector(2 downto 0);
    d_to_slave      : in  std_logic_vector(15 downto 0);
    ad7794_din      : out std_logic;
    ad7794_cs       : out std_logic;
    ad7794_sclk     : out std_logic;
    busy            : out std_logic;
    d_from_slave    : out std_logic_vector(23 downto 0)
    );

end ad7794_top;

architecture Behavioral of ad7794_top is

signal d_from_slave_ready   : std_logic;
signal d_to_slave_in_int    : std_logic_vector(19 downto 0);
signal d_to_slave_out_int   : std_logic_vector(19 downto 0);
signal d_from_slave_int     : std_logic_vector(23 downto 0);

begin

ad7794_programmer_0 : entity lsst_reb.ad7794_programmer
generic map (clk_divide => 4)
port map (
    clk     => clk,
    reset     => reset,
    start     => start,
    start_reset => start_reset,
    read_write  => d_to_slave_out_int(19),
    dout_rdy    => ad7794_dout_rdy,
    reg_add   => d_to_slave_out_int(18 downto 16),
    d_to_slave  => d_to_slave_out_int(15 downto 0),
    din           => ad7794_din,
    cs              => ad7794_cs,
    sclk            => ad7794_sclk,
    busy            => busy,
    d_from_slave_ready  => d_from_slave_ready,
    d_from_slave      => d_from_slave_int
    );

data_in_reg : entity lsst_reb.generic_reg_ce_init
      generic map(width => 19)
      port map (
        reset    => reset,
        clk      => clk,
        ce       => start,
        init   => '0',
        data_in  => d_to_slave_in_int,
        data_out => d_to_slave_out_int
        );


data_out_reg : entity lsst_reb.generic_reg_ce_init
      generic map(width => 23)
      port map (
        reset    => reset,
        clk      => clk,
        ce       => d_from_slave_ready,
        init   => '0',
        data_in  => d_from_slave_int,
        data_out => d_from_slave
        );


d_to_slave_in_int   <= read_write & reg_add & d_to_slave;

end Behavioral;
