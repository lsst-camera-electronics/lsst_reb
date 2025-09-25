library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_reb;
--use lsst_reb.SystemClkPkg.all;

entity SystemClock is
  generic (
    SYS_CLK_PER_G : real -- system clock period
  );
  port (
    refClk : in std_logic;
    usrClk : in std_logic;
    usrRst : in std_logic;

    stableClk     : out std_logic;
    stableRst     : out std_logic;
    stableSlowClk : out std_logic;
    stableSlowRst : out std_logic;
    stableLocked  : out std_logic;

    sysClk    : out std_logic;
    sysRst    : out std_logic
  );
end entity SystemClock;

architecture Behavioral of SystemClock is

  constant TPD_C : time := 1 ns;

  signal sysClk_int : std_logic;
  signal sysRst_int : std_logic;

begin

  assert (SYS_CLK_PER_G = 10.0E-9 or SYS_CLK_PER_G = 6.4E-9)
    report "Only system clocks of 10ns (100MHz) or 6.4ns (156.25MHz) supported."
    severity failure;

  --------------------------------------------------------------------------
  -- Generate Stable Clock and Reset from Reference Clock (250MHz)
  --------------------------------------------------------------------------
  ClockManager_stable_clk : entity surf.ClockManager7
    generic map (
      TPD_G              => TPD_C,
      TYPE_G             => "MMCM",
      INPUT_BUFG_G       => true,
      FB_BUFG_G          => true,
      OUTPUT_BUFG_G      => true,
      RST_IN_POLARITY_G  => '1',
      NUM_CLOCKS_G       => 2,
      BANDWIDTH_G        => "OPTIMIZED",
      CLKIN_PERIOD_G     => 4.0,
      DIVCLK_DIVIDE_G    => 1,
      CLKFBOUT_MULT_F_G  => 4.000,
      CLKOUT0_DIVIDE_F_G => 10.000,
      CLKOUT0_RST_HOLD_G => 8,
      CLKOUT1_DIVIDE_G   => 40,
      CLKOUT1_RST_HOLD_G => 8
    )
    port map (
      clkIn     => refClk,
      rstIn     => '0',
      clkOut(0) => stableClk,
      clkOut(1) => stableSlowClk,
      rstOut(0) => stableRst,
      rstOut(1) => stableSlowRst
    );

  --------------------------------------------------------------------------
  -- Generate System Clock and Reset from User Clock (156.25MHz)
  --------------------------------------------------------------------------
  U_10ns_clock : if SYS_CLK_PER_G = 10.0E-9 generate

    ClockManager_sys_clk : entity surf.ClockManager7
      generic map (
        TPD_G              => TPD_C,
        TYPE_G             => "MMCM",
        INPUT_BUFG_G       => false,
        FB_BUFG_G          => true,
        OUTPUT_BUFG_G      => true,
        RST_IN_POLARITY_G  => '1',
        NUM_CLOCKS_G       => 1,
        BANDWIDTH_G        => "OPTIMIZED",
        CLKIN_PERIOD_G     => 6.4,
        DIVCLK_DIVIDE_G    => 5,
        CLKFBOUT_MULT_F_G  => 32.000,
        CLKOUT0_DIVIDE_G   => 10,
        CLKOUT0_RST_HOLD_G => 8
      )
      port map (
        clkIn     => usrClk,
        clkOut(0) => sysClk_int
      );

    -- sync reset for the user part (from PGP)
    reset_sync : entity surf.RstSync
      port map (
        clk      => sysClk_int,
        asyncRst => usrRst,
        syncRst  => sysRst_int
      );

      sysClk <= sysClk_int;
      sysRst <= sysRst_int;

  end generate U_10ns_clock;

  U_6_4ns_clock : if SYS_CLK_PER_G = 6.4E-9 generate

    sysClk <= usrClk;
    sysRst <= usrRst;

  end generate U_6_4ns_clock;

end architecture Behavioral;
