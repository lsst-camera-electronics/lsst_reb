----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    10:56:53 04/10/2013
-- Design Name:
-- Module Name:    function_v3 - Behavioral
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

library surf;
library lsst_reb;

entity function_v3 is

  generic (time_bus_width : integer := 16;
           out_bus_width  : integer := 32;
           time_slice_num : integer := 16;
           function_num   : integer := 15
           );

  port (
    reset          : in std_logic;      -- syncronus reset
    clk            : in std_logic;      -- clock
    start_func     : in std_logic;
    sequencer_busy : in std_logic;

    time_mem_w_en  : in  std_logic;
    time_mem_in    : in  std_logic_vector(time_bus_width-1 downto 0);
    time_mem_w_add : in  std_logic_vector(7 downto 0);
    time_func_add  : in  std_logic_vector(3 downto 0);
    time_mem_out_2 : out std_logic_vector(time_bus_width-1 downto 0);

    out_mem_w_en  : in  std_logic;
    out_mem_in    : in  std_logic_vector(out_bus_width-1 downto 0);
    out_mem_w_add : in  std_logic_vector(7 downto 0);
    out_func_add  : in  std_logic_vector(3 downto 0);
    out_mem_out_2 : out std_logic_vector(out_bus_width-1 downto 0);

    end_func        : out std_logic;
    signal_out_func : out std_logic_vector(out_bus_width-1 downto 0));

end function_v3;

architecture Behavioral of function_v3 is

  signal time_add_timeslice       : std_logic_vector(3 downto 0);
  signal time_add_timeslice_plus1 : std_logic_vector(3 downto 0);
  signal out_add_timeslice        : std_logic_vector(3 downto 0);
  signal time_bus_int             : std_logic_vector(15 downto 0);
  signal time_bus_2_int           : std_logic_vector(15 downto 0);
  signal time_add_w_mux           : std_logic_vector(7 downto 0);
  signal time_add_plus1           : std_logic_vector(7 downto 0);
  signal time_add_read            : std_logic_vector(7 downto 0);
  signal out_add_read             : std_logic_vector(7 downto 0);

begin


  function_fsm_v3_0 : entity lsst_reb.function_fsm_v3
    port map (
      reset               => reset,
      clk                 => clk,
      start_function      => start_func,
      func_time_in        => time_bus_int,
      func_time_in_plus1  => time_bus_2_int,
      func_time_add       => time_add_timeslice,
      func_time_add_plus1 => time_add_timeslice_plus1,
      func_out_add        => out_add_timeslice,
      function_end        => end_func
      );

  time_add_mux : entity lsst_reb.mux_2_1_bus_noclk
    generic map (bus_width => 8)
    port map (
      selector => sequencer_busy,
      bus_in_0 => time_mem_w_add,
      bus_in_1 => time_add_plus1,

      bus_out => time_add_w_mux
      );

  time_mem : entity surf.DualPortRam
    generic map (
        MEMORY_TYPE_G => "distributed",
        REG_EN_G      => false,
        DOA_REG_G     => false,
        DOB_REG_G     => false,
        MODE_G        => "no-change",
        DATA_WIDTH_G  => 16,
        ADDR_WIDTH_G  => 8)
    port map (
        addra => time_add_w_mux,
        dina  => time_mem_in,
        addrb => time_add_read,
        clka  => clk,
        clkb  => clk,
        wea   => time_mem_w_en,
        douta => time_bus_2_int,
        doutb => time_bus_int);

  out_mem : entity surf.DualPortRam
    generic map (
        MEMORY_TYPE_G => "distributed",
        REG_EN_G      => false,
        DOA_REG_G     => false,
        DOB_REG_G     => false,
        MODE_G        => "no-change",
        DATA_WIDTH_G  => 32,
        ADDR_WIDTH_G  => 8)
    port map (
        addra => out_mem_w_add,
        dina  => out_mem_in,
        addrb => out_add_read,
        clka  => clk,
        clkb  => clk,
        wea   => out_mem_w_en,
        douta => out_mem_out_2,
        doutb => signal_out_func);

  time_mem_out_2 <= time_bus_2_int;
  time_add_plus1 <= time_func_add & time_add_timeslice_plus1;
  time_add_read  <= time_func_add & time_add_timeslice;
  out_add_read   <= out_func_add & out_add_timeslice;

end Behavioral;

