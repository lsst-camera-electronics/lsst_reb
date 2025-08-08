library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library lsst_reb;

entity i2c_top is
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    start_i2c     : in    std_logic;
    read_nwrite   : in    std_logic;
    double_read   : in    std_logic;
    latch_word_1  : out   std_logic;
    latch_word_2  : out   std_logic;
    end_procedure : out   std_logic;

    device_addr : IN    STD_LOGIC_VECTOR(6 DOWNTO 0); -- address of target slave
    reg_add     : in    std_logic_vector(7 downto 0);
    data_wr     : IN    STD_LOGIC_VECTOR(7 DOWNTO 0); -- data to write to slave
    data_rd     : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0); -- data read from slave
    ack_error   : buffer STD_LOGIC;                    -- flag if improper acknowledge from slave
    sda         : INOUT STD_LOGIC;                    -- serial data output of i2c bus
    scl         : INOUT STD_LOGIC                     -- serial clock output of i2c bus
  );
end entity i2c_top;

architecture Behavioral of i2c_top is

  signal i2c_busy    : std_logic;
  signal i2c_ena     : std_logic;
  signal i2c_rw      : std_logic;
  signal data_in_sel : std_logic;
  signal data_to_12c : std_logic_vector(7 downto 0);

begin

  i2c_handler_fsm_0 : entity lsst_reb.i2c_handler_fsm
    port map (
      clk           => clk,
      reset         => reset,
      start_i2c     => start_i2c,
      read_nwrite   => read_nwrite,
      double_read   => double_read,
      i2c_busy      => i2c_busy,
      i2c_ena       => i2c_ena,
      i2c_rw        => i2c_rw,
      latch_word_1  => latch_word_1,
      latch_word_2  => latch_word_2,
      data_in_sel   => data_in_sel,
      end_procedure => end_procedure
    );

  i2c_master_0 : entity lsst_reb.i2c_master
    generic map (
      input_clk => 100_000_000,
      bus_clk   => 400_000
    )
    port map (
      clk       => clk,
      reset     => reset,
      ena       => i2c_ena,
      addr      => device_addr,
      rw        => i2c_rw,
      data_wr   => data_to_12c,
      busy      => i2c_busy,
      data_rd   => data_rd,
      ack_error => ack_error,
      sda       => sda,
      scl       => scl
    );

  data_in_mux : entity lsst_reb.mux_bus_2_8_bit_clk
    port map (
      reset    => reset,
      clk      => clk,
      selector => data_in_sel,
      bus_in_0 => reg_add,
      bus_in_1 => data_wr,
      bus_out  => data_to_12c
    );

end architecture Behavioral;

