library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

entity dual_ad53xx_DAC_top is
  generic (
    CLK_PERIOD_G : real
  );
  port (
    clk         : in    std_logic;
    reset       : in    std_logic;
    start_write : in    std_logic;
    start_ldac  : in    std_logic;
    d_to_slave  : in    std_logic_vector(16 downto 0);
    mosi        : out   std_logic;
    ss_dac_0    : out   std_logic;
    ss_dac_1    : out   std_logic;
    sclk        : out   std_logic;
    ldac        : out   std_logic
  );
end entity dual_ad53xx_DAC_top;

architecture Behavioral of dual_ad53xx_DAC_top is

  constant SPI_SCLK_PERIOD_C : real := 33.0E-9;
  constant MIN_LDAC_PULSE_C  : real := 20.0E-9;

  constant ACTUAL_WIDTH_C    : integer := integer(ceil(MIN_LDAC_PULSE_C / CLK_PERIOD_G));
  constant PULSE_WIDTH_C     : integer := ACTUAL_WIDTH_C  - 1;
  constant PULSE_BIT_WIDTH_C : integer := bitSize(PULSE_WIDTH_C);

  signal ss_int : std_logic_vector(1 downto 0);
  signal cs_int : std_logic_vector(0 downto 0);

  signal ldac_pulse_width    : std_logic_vector(PULSE_BIT_WIDTH_C-1 downto 0);

begin

  ------------------------------------------------------------------------------
  -- SPI Interface
  ------------------------------------------------------------------------------
  cs_int(0) <= d_to_slave(16);

  SPI_write_0 : entity surf.SpiMaster
    generic map (
      NUM_CHIPS_G       => 2,
      DATA_SIZE_G       => 16,
      CPHA_G            => '1',
      CPOL_G            => '0',
      CLK_PERIOD_G      => CLK_PERIOD_G,
      SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_C
    )
    port map (
      clk     => clk,
      sRst    => reset,
      chipSel => cs_int,
      wrEn    => start_write,
      wrData  => d_to_slave(15 downto 0),
      spiCsL  => ss_int,
      spiSclk => sclk,
      spiSdi  => mosi,
      spiSdo  => '0'
    );
    ss_dac_0 <= ss_int(0);
    ss_dac_1 <= ss_int(1);

  ------------------------------------------------------------------------------
  -- LDAC Pulse
  ------------------------------------------------------------------------------
  ldac_pulse_width <= std_logic_vector(to_unsigned(PULSE_WIDTH_C, PULSE_BIT_WIDTH_C));

  ldac_pulse_gen : entity surf.OneShot
    generic map (
      IN_POLARITY_G     => '1',
      OUT_POLARITY_G    => '0',
      PULSE_BIT_WIDTH_G => PULSE_BIT_WIDTH_C
    )
    port map (
      clk        => clk,
      rst        => reset,
      pulseWidth => ldac_pulse_width,
      trigIn     => start_ldac,
      pulseOut   => ldac
    );

end architecture Behavioral;

