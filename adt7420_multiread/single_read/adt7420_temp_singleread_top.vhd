library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

library lsst_reb;

entity adt7420_temp_singleread_top is
  generic (
    CLK_PERIOD_G : real
  );
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    start_procedure : in    std_logic;

    busy : out   std_logic;

    error_T1 : out   std_logic;
    T1_out   : out   std_logic_vector(15 downto 0);

    sda : INOUT STD_LOGIC; -- serial data output of i2c bus
    scl : INOUT STD_LOGIC  -- serial clock output of i2c bus
  );
end entity adt7420_temp_singleread_top;

architecture Behavioral of adt7420_temp_singleread_top is

  signal latch_word_1  : std_logic;
  signal latch_word_2  : std_logic;
  signal end_i2c       : std_logic;
  signal i2c_read_byte : std_logic_vector(7 downto 0);
  signal ack_error     : std_logic;
  signal T1_lsw        : std_logic_vector(7 downto 0);
  signal T1_MSW        : std_logic_vector(7 downto 0);

begin

  i2c_top_0 : entity lsst_reb.i2c_top
    generic map(
      CLK_PERIOD_G     => CLK_PERIOD_G,
      I2C_SCL_PERIOD_G => 2500.0E-9 -- 400kHz
    )
    port map (
      clk           => clk,
      reset         => reset,
      start_i2c     => start_procedure,
      read_nwrite   => '1',
      double_read   => '1',
      latch_word_1  => latch_word_1,
      latch_word_2  => latch_word_2,
      end_procedure => end_i2c,

      device_addr => "1001000",
      reg_add     => x"00",
      data_wr     => x"00",
      data_rd     => i2c_read_byte,
      ack_error   => ack_error,
      sda         => sda,
      scl         => scl
    );

  out_lsw_reg : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 7
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => latch_word_2,
      init     => '0',
      data_in  => i2c_read_byte,
      data_out => T1_lsw
    );

  out_MSW_reg : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 7
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => latch_word_1,
      init     => '0',
      data_in  => i2c_read_byte,
      data_out => T1_MSW
    );

  error_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => '1',
      ce       => ack_error,
      data_out => error_T1
    );

  T1_out <= T1_MSW & T1_lsw;

end architecture Behavioral;

