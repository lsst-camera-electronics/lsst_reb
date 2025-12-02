library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.math_real.all;

library lsst_reb;
use lsst_reb.basic_elements_pkg.all;

entity ADC_data_handler_v4 is
  generic (
    CLK_PERIOD_G : real
  );
  port (
    reset             : in    std_logic;
    clk               : in    std_logic;
    testmode_rst      : in    std_logic;
    testmode_col      : in    std_logic;
    start_of_img      : in    std_logic;
    end_of_img        : in    std_logic;
    end_sequence      : in    std_logic;
    trigger           : in    std_logic;
    en_test_mode      : in    std_logic;
    test_mode_in      : in    std_logic;
    en_load_ccd_sel   : in    std_logic;
    ccd_sel_in        : in    std_logic_vector(2 downto 0);
    ccd_sel_out       : out   std_logic_vector(2 downto 0);
    SOT               : out   std_logic;
    EOT               : out   std_logic;
    write_enable      : out   std_logic;
    test_mode_enb_out : out   std_logic;
    data_out          : out   std_logic_vector(17 downto 0);
    adc_data_ccd_1    : in    std_logic_vector(15 downto 0) := (others => '0');
    adc_cnv_ccd_1     : out   std_logic;
    adc_sck_ccd_1     : out   std_logic;
    adc_data_ccd_2    : in    std_logic_vector(15 downto 0) := (others => '0');
    adc_cnv_ccd_2     : out   std_logic;
    adc_sck_ccd_2     : out   std_logic;
    adc_data_ccd_3    : in    std_logic_vector(15 downto 0) := (others => '0');
    adc_cnv_ccd_3     : out   std_logic;
    adc_sck_ccd_3     : out   std_logic
  );
end entity ADC_data_handler_v4;

architecture Behavioral of ADC_data_handler_v4 is

  --------------------------------------------------------------------------------
  -- 710ns is max conv time
  -- for 10ns clock:  750ns=75tics
  -- for 6.4ns clock: 768ns=120, 736ns=115, 710.4ns=111, 755.2ns=118, 748.8ns=117
  --------------------------------------------------------------------------------
  -- For sclk_half period,
  --   SCK period min: 12ns
  --   SCK falling edge to data ready max: 11ns
  --   SCK falling edge to data remains valid min: 3ns
  --   CNV low to SDO MSB Valid max: 10ns
  -- Data is sampled at the rising edge of SCK (1/2 period after going low)
  -- for 10ns clock: sclk_half_period set to 20ns=2
  -- for 6.4ns clock: 12.8ns=2, 19.2ns=3, 25.6=4
  ------------------------------------------------------------------------------
  -- For test_time doesn't really matter, it's the pixel rate for test data
  -- for 10ns clock: 1500ns=150
  -- for 6.4ns clock: 1497.6ns=234, 1504ns=235
  ------------------------------------------------------------------------------
  constant DEV_CONV_TIME_C     : real :=  750.0E-9;
  constant DEV_SCLK_HALF_PER_C : real :=   11.0E-9;
  constant DEV_TEST_TIME_C     : real := 1500.0E-9;

  constant CONV_TIME_C        : natural := calcClockPeriods(DEV_CONV_TIME_C,     CLK_PERIOD_G);
  constant SCLK_HALF_PERIOD_C : natural := calcClockPeriods(DEV_SCLK_HALF_PER_C, CLK_PERIOD_G);
  constant TEST_TIME_C        : natural := calcClockPeriods(DEV_TEST_TIME_C,     CLK_PERIOD_G);
  constant COL_INCR_VAL_C     : natural := 10;
  constant PIX_INCR_CAL_C     : natural := 8;

  signal cnt_en   : std_logic;
  signal init_cnt : std_logic;

  signal testmode_enb : std_logic;

  signal data_ready       : std_logic;
  signal data_ready_ccd_1 : std_logic;
  signal data_ready_ccd_2 : std_logic;
  signal data_ready_ccd_3 : std_logic;

  signal trigger_ccd_1 : std_logic;
  signal trigger_ccd_2 : std_logic;
  signal trigger_ccd_3 : std_logic;

  signal end_sequence_stretch     : std_logic;
  signal end_sequence_stretch_inv : std_logic;
  signal handler_busy             : std_logic;
  signal stretch_reset            : std_logic;

  signal ADC_CCD_1 : array1618;
  signal ADC_CCD_2 : array1618;
  signal ADC_CCD_3 : array1618;

  signal ccd_sel : std_logic_vector(2 downto 0);

begin

  assert false report "ADC_data_handler_v4 timing constants"                      severity note;
  assert false report "CONV_TIME_C:         " & integer'image(CONV_TIME_C)        severity note;
  assert false report "SCLK_HALF_PERIOD_C:  " & integer'image(SCLK_HALF_PERIOD_C) severity note;
  assert false report "TEST_TIME_C:         " & integer'image(TEST_TIME_C)        severity note;

  test_mode_enb_out <= testmode_enb;

  trigger_ccd_1 <= trigger and ccd_sel(0);
  trigger_ccd_2 <= trigger and ccd_sel(1);
  trigger_ccd_3 <= trigger and ccd_sel(2);

  data_ready <= data_ready_ccd_1 or data_ready_ccd_2 or data_ready_ccd_3;

  ccd_sel_out <= ccd_sel;

  stretch_reset            <= reset or (not handler_busy);
  end_sequence_stretch_inv <= not end_sequence_stretch;

  ADC_data_handler_fsm_v4_0 : entity lsst_reb.ADC_data_handler_fsm_v4
    port map (
      reset        => reset,
      clk          => clk,
      trigger      => data_ready,
      start_of_img => start_of_img,
      end_of_img   => end_of_img,
      end_sequence => end_sequence_stretch,
      ccd_sel      => ccd_sel,
      data_ccd_1   => ADC_CCD_1,
      data_ccd_2   => ADC_CCD_2,
      data_ccd_3   => ADC_CCD_3,
      cnt_en       => cnt_en,
      init_cnt     => init_cnt,
      SOT          => SOT,
      EOT          => EOT,
      write_enable => write_enable,
      handler_busy => handler_busy,
      data_out     => data_out
    );

  end_seq_stretch : entity lsst_reb.ff_ce
    port map (
      reset    => stretch_reset,
      clk      => clk,
      data_in  => end_sequence,
      ce       => end_sequence_stretch_inv,
      data_out => end_sequence_stretch
    );

  sel_ccd_reg : entity lsst_reb.generic_reg_ce_init_1
    generic map (
      width => 2
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => en_load_ccd_sel,
      init     => '0',
      data_in  => ccd_sel_in,
      data_out => ccd_sel
    );

  trigger_counter : entity lsst_reb.generic_counter_comparator_ce_init
    generic map (
      length_cnt => 31
    )
    port map (
      reset     => reset,
      clk       => clk,
      max_value => x"00000000",
      enable    => cnt_en,
      init      => init_cnt,
      cnt_end   => open,
      q_out     => open
    );

  readadcs_v5_0_ccd1 : entity lsst_reb.readadcs_v5
    generic map (
      conv_time        => CONV_TIME_C,
      sclk_half_period => SCLK_HALF_PERIOD_C,
      test_time        => TEST_TIME_C,
      col_incr_val     => COL_INCR_VAL_C,
      pix_incr_val     => PIX_INCR_CAL_C
    )
    port map (
      clk          => clk,
      reset        => reset,
      start_conv   => trigger_ccd_1,
      testmode_enb => testmode_enb,
      testmode_rst => testmode_rst,
      testmode_col => testmode_col,
      adc_data     => adc_data_ccd_1,
      adc_cnv      => adc_cnv_ccd_1,
      adc_sck      => adc_sck_ccd_1,
      data_ready   => data_ready_ccd_1,
      adc_ch       => ADC_CCD_1
    );

  readadcs_v5_0_ccd2 : entity lsst_reb.readadcs_v5
    generic map (
      conv_time        => CONV_TIME_C,
      sclk_half_period => SCLK_HALF_PERIOD_C,
      test_time        => TEST_TIME_C,
      col_incr_val     => COL_INCR_VAL_C,
      pix_incr_val     => PIX_INCR_CAL_C
    )
    port map (
      clk          => clk,
      reset        => reset,
      start_conv   => trigger_ccd_2,
      testmode_enb => testmode_enb,
      testmode_rst => testmode_rst,
      testmode_col => testmode_col,
      adc_data     => adc_data_ccd_2,
      adc_cnv      => adc_cnv_ccd_2,
      adc_sck      => adc_sck_ccd_2,
      data_ready   => data_ready_ccd_2,
      adc_ch       => ADC_CCD_2
    );

  readadcs_v5_0_ccd3 : entity lsst_reb.readadcs_v5
    generic map (
      conv_time        => CONV_TIME_C,
      sclk_half_period => SCLK_HALF_PERIOD_C,
      test_time        => TEST_TIME_C,
      col_incr_val     => COL_INCR_VAL_C,
      pix_incr_val     => PIX_INCR_CAL_C
    )
    port map (
      clk          => clk,
      reset        => reset,
      start_conv   => trigger_ccd_3,
      testmode_enb => testmode_enb,
      testmode_rst => testmode_rst,
      testmode_col => testmode_col,
      adc_data     => adc_data_ccd_3,
      adc_cnv      => adc_cnv_ccd_3,
      adc_sck      => adc_sck_ccd_3,
      data_ready   => data_ready_ccd_3,
      adc_ch       => ADC_CCD_3
    );

  test_mode_ff : entity lsst_reb.ff_ce
    port map (
      reset => reset,

      clk     => clk,
      data_in => test_mode_in,
      ce      => en_test_mode,

      data_out => testmode_enb
    );

end architecture Behavioral;

