library IEEE;
use IEEE.STD_LOGIC_1164.all;

library surf;
library lsst_reb;

entity si5342_multiclock_top is
  generic (
    CLK_PERIOD_G : real
  );
  port (
    -- input clock
    sys_clk_local :  in   std_logic;
    sys_rst_local :  in   std_logic;
    -- output clock
    sys_clk_out   : out   std_logic;
    sys_rst_out   : out   std_logic;
    -- config
    start_config  :  in   std_logic;
    config        :  in   std_logic_vector(1 downto 0);
    status_bus    : out   std_logic_vector(5 downto 0);
    -- JC pins
    jc_los0       :  in   std_logic;
    jc_lol        :  in   std_logic;
    jc_refclk_in  :  in   std_logic;
    jc_refclk_out : out   std_logic;
    jc_rst_out    : out   std_logic;
    jc_miso       :  in   std_logic;
    jc_mosi       : out   std_logic;
    jc_cs         : out   std_logic;
    jc_sclk       : out   std_logic
  );
end entity si5342_multiclock_top;

architecture Behavioral of si5342_multiclock_top is

  signal sys_clk        : std_logic;
  signal sys_rst        : std_logic;
  signal jc_clk_in_en   : std_logic;
  signal jc_clk_rdy     : std_logic;
  signal jc_clk_not_rdy : std_logic;
  signal jc_config_busy : std_logic;
  signal jc_config_done : std_logic;

begin

  ------------------------------------------------------------------------------
  -- Jitter Cleaner (ENABLED for 10ns clock)
  ------------------------------------------------------------------------------
  U_use_jitter_cleaner : if CLK_PERIOD_G = 10.0E-9 generate

    jc_ref_clk_out : ODDR
      generic map(
        DDR_CLK_EDGE => "OPPOSITE_EDGE",  -- "OPPOSITE_EDGE" or "SAME_EDGE"
        INIT         => '1',              -- Initial value for Q port ('1' or '0')
        SRTYPE       => "SYNC"            -- Reset Type ("ASYNC" or "SYNC")
        ) port map (
          Q  => jc_refclk_out,            -- 1-bit DDR output
          C  => sys_clk_local,            -- 1-bit clock input
          CE => jc_clk_in_en,             -- 1-bit clock enable input
          D1 => '1',                      -- 1-bit data input (positive edge)
          D2 => '0',                      -- 1-bit data input (negative edge)
          R  => '0',                      -- 1-bit reset input
          S  => '0'                       -- 1-bit set input
          );

    jitter_cleaner : entity lsst_reb.si5342_jitter_cleaner_top
      port map (
        clk          => sys_clk,
        reset        => sys_rst,
        start_config => start_config,
        jc_config    => config,
        config_busy  => jc_config_busy,
        jc_clk_ready => jc_config_done,
        jc_clk_in_en => jc_clk_in_en,
        miso         => jc_miso,
        mosi         => jc_mosi,
        chip_select  => jc_cs,
        sclk         => jc_sclk);

    jc_rst_out <= '1'; -- NO reset

    jc_clk_rdy     <= jc_config_done and jc_lol and jc_los0;
    jc_clk_not_rdy <= not jc_clk_rdy;

    status_bus <= '0' & '0' & jc_clk_rdy & jc_config_done & jc_lol & jc_los0;

    BUFGCTRL_mux_100Mhz_clk : BUFGCTRL
      generic map (
        INIT_OUT     => 0,     -- Initial value of BUFGCTRL output ($VALUES;)
        PRESELECT_I0 => true,  -- BUFGCTRL output uses I0 input ($VALUES;)
        PRESELECT_I1 => false  -- BUFGCTRL output uses I1 input ($VALUES;)
        )
      port map (
        O       => sys_clk,               -- 1-bit output: Clock output
        CE0     => '1',                   -- CE not used
        CE1     => '1',                   -- CE not used
        I0      => sys_clk_local,         -- local clock generated form OSC
        I1      => jc_refclk_in,          -- clock from Jitter Cleaner
        IGNORE0 => '0',                   -- 1-bit input: Clock ignore input for I0
        IGNORE1 => '0',                   -- set to 1 to let the mux switch also when clk is not present
        S0      => jc_clk_not_rdy,        -- 1-bit input: Clock select for I0
        S1      => jc_clk_rdy             -- 1-bit input: Clock select for I1
        );

    -- sync reset for the user part (from PGP)
    reset_sync : entity surf.RstSync
      port map (
        clk      => sys_clk,
        asyncRst => sys_rst_local,
        syncRst  => sys_rst
      );

    sys_clk_out <= sys_clk;
    sys_rst_out <= sys_rst;

  end generate U_use_jitter_cleaner;

  ------------------------------------------------------------------------------
  -- Jitter Cleaner (DISABLED for non-10ns clock)
  ------------------------------------------------------------------------------
  U_no_jitter_cleaner : if CLK_PERIOD_G /= 10.0E-9 generate

    assert false report "No Jitter Cleaner config for non-10ns clocks, using passthrough" severity warning;

    sys_clk_out <= sys_clk_local;
    sys_rst_out <= sys_rst_local;

    status_bus <= (others => '0');

    jc_mosi       <= '0';
    jc_sclk       <= '0';
    jc_cs         <= '0';
    jc_rst_out    <= '1'; -- NO reset
    jc_refclk_out <= '0';

  end generate U_no_jitter_cleaner;


end architecture Behavioral;
