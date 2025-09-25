library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

library lsst_reb;
use lsst_reb.basic_elements_pkg.all;

entity ltc2945_multi_read_top is
  generic (
    CLK_PERIOD_G : real
  );
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    start_procedure : in    std_logic;

    busy : out   std_logic;

    error_v6_voltage : out   std_logic;
    v6_voltage_out   : out   std_logic_vector(15 downto 0);

    error_v6_current : out   std_logic;
    v6_current_out   : out   std_logic_vector(15 downto 0);

    error_v9_voltage : out   std_logic;
    v9_voltage_out   : out   std_logic_vector(15 downto 0);

    error_v9_current : out   std_logic;
    v9_current_out   : out   std_logic_vector(15 downto 0);

    error_v24_voltage : out   std_logic;
    v24_voltage_out   : out   std_logic_vector(15 downto 0);

    error_v24_current : out   std_logic;
    v24_current_out   : out   std_logic_vector(15 downto 0);

    error_v40_voltage : out   std_logic;
    v40_voltage_out   : out   std_logic_vector(15 downto 0);

    error_v40_current : out   std_logic;
    v40_current_out   : out   std_logic_vector(15 downto 0);

    sda : INOUT STD_LOGIC; -- serial data output of i2c bus
    scl : INOUT STD_LOGIC  -- serial clock output of i2c bus
  );
end entity ltc2945_multi_read_top;

architecture Behavioral of ltc2945_multi_read_top is

  signal end_i2c       : std_logic;
  signal start_i2c     : std_logic;
  signal device_addr   : STD_LOGIC_VECTOR(6 DOWNTO 0);
  signal reg_add       : std_logic_vector(7 downto 0);
  signal latch_en_bus  : std_logic_vector(7 downto 0);
  signal latch_word_1  : std_logic;
  signal latch_word_2  : std_logic;
  signal i2c_read_byte : std_logic_vector(7 downto 0);
  signal ack_error     : STD_LOGIC;
  signal en_lsw        : std_logic_vector(7 downto 0);
  signal en_MSW        : std_logic_vector(7 downto 0);
  signal error_bus     : std_logic_vector(7 downto 0);
  signal error_bus_ce  : std_logic_vector(7 downto 0);

  signal out_lsw_array : array88;
  signal out_MSW_array : array88;

begin

  ltc2945_multi_read_fsm_0 : entity lsst_reb.ltc2945_multi_read_fsm
    port map (
      clk             => clk,
      reset           => reset,
      start_procedure => start_procedure,
      end_i2c         => end_i2c,

      busy         => busy,
      start_i2c    => start_i2c,
      device_addr  => device_addr,
      reg_add      => reg_add,
      latch_en_bus => latch_en_bus
    );

  i2c_top_0 : entity lsst_reb.i2c_top
    generic map(
      CLK_PERIOD_G     => CLK_PERIOD_G,
      I2C_SCL_PERIOD_G => 2500.0E-9 -- 400kHz
    )
    port map (
      clk           => clk,
      reset         => reset,
      start_i2c     => start_i2c,
      read_nwrite   => '1',
      double_read   => '1',
      latch_word_1  => latch_word_1,
      latch_word_2  => latch_word_2,
      end_procedure => end_i2c,

      device_addr => device_addr,
      reg_add     => reg_add,
      data_wr     => x"00",
      data_rd     => i2c_read_byte,
      ack_error   => ack_error,
      sda         => sda,
      scl         => scl
    );

  en_bus_lsw_generate : for i in 0 to 7 generate
    en_lsw(i) <= latch_en_bus(i) and latch_word_2;
  end generate en_bus_lsw_generate;

  en_bus_MSW_generate : for i in 0 to 7 generate
    en_MSW(i) <= latch_en_bus(i) and latch_word_1;
  end generate en_bus_MSW_generate;

  error_bus_generate : for i in 0 to 7 generate
    error_bus_ce(i) <= latch_en_bus(i) and ack_error;
  end generate error_bus_generate;

  lsw_reg_generate : for i in 0 to 7 generate

    out_lsw_reg : entity lsst_reb.generic_reg_ce_init
      generic map (
        width => 7
      )
      port map (
        reset    => reset,
        clk      => clk,
        ce       => en_lsw(i),
        init     => '0',
        data_in  => i2c_read_byte,
        data_out => out_lsw_array(I)
      );

  end generate lsw_reg_generate;

  MSW_reg_generate : for i in 0 to 7 generate

    out_MSW_reg : entity lsst_reb.generic_reg_ce_init
      generic map (
        width => 7
      )
      port map (
        reset    => reset,
        clk      => clk,
        ce       => en_MSW(i),
        init     => '0',
        data_in  => i2c_read_byte,
        data_out => out_MSW_array(I)
      );

  end generate MSW_reg_generate;

  error_ff_generate : for i in 0 to 7 generate

    error_ff : entity lsst_reb.ff_ce
      port map (
        reset    => reset,
        clk      => clk,
        data_in  => '1',
        ce       => error_bus_ce(i),
        data_out => error_bus(i)
      );

  end generate error_ff_generate;

  v6_voltage_out <= out_MSW_array(0) & out_lsw_array(0);
  v6_current_out <= out_MSW_array(1) & out_lsw_array(1);

  v9_voltage_out <= out_MSW_array(2) & out_lsw_array(2);
  v9_current_out <= out_MSW_array(3) & out_lsw_array(3);

  v24_voltage_out <= out_MSW_array(4) & out_lsw_array(4);
  v24_current_out <= out_MSW_array(5) & out_lsw_array(5);

  v40_voltage_out <= out_MSW_array(6) & out_lsw_array(6);
  v40_current_out <= out_MSW_array(7) & out_lsw_array(7);

  error_v6_voltage <= error_bus(0);
  error_v6_current <= error_bus(1);

  error_v9_voltage <= error_bus(2);
  error_v9_current <= error_bus(3);

  error_v24_voltage <= error_bus(4);
  error_v24_current <= error_bus(5);

  error_v40_voltage <= error_bus(6);
  error_v40_current <= error_bus(7);

end architecture Behavioral;

