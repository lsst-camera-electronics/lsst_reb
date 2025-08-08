library IEEE;
use IEEE.STD_LOGIC_1164.all;

library lsst_reb;
use lsst_reb.basic_elements_pkg.all;

entity ads8634_and_mux_top is
  port (
    clk                  : in    std_logic;
    reset                : in    std_logic;
    start_multiread      : in    std_logic;
    start_singleread     : in    std_logic;
    start_read_adc_reg   : in    std_logic;
    mux_address_in       : in    std_logic_vector(5 downto 0);
    data_to_adc          : in    std_logic_vector(15 downto 0);
    miso                 : in    std_logic;
    mosi                 : out   std_logic;
    ss                   : out   std_logic;
    sclk                 : out   std_logic;
    link_busy            : out   std_logic;
    pwd_line             : out   std_logic;
    mux_sam_en_out       : out   std_logic;
    mux_bias_en_out      : out   std_logic;
    mux_sam_address_out  : out   std_logic_vector(2 downto 0);
    mux_bias_address_out : out   std_logic_vector(2 downto 0);
    data_out             : out   array716
  );
end entity ads8634_and_mux_top;

architecture Behavioral of ads8634_and_mux_top is

  signal spi_busy        : std_logic;
  signal ss_int          : std_logic;
  signal start_spi       : std_logic;
  signal latch_reg_in    : std_logic;
  signal data_to_adc_int : std_logic_vector(15 downto 0);
  signal data_to_spi     : std_logic_vector(15 downto 0);
  signal out_reg_en_bus  : std_logic_vector(6 downto 0);
  signal data_from_spi   : std_logic_vector(15 downto 0);
  signal mux_address_int : std_logic_vector(5 downto 0);

  signal adc_add_int : std_logic_vector(3 downto 0);
  signal adc_out_int : std_logic_vector(23 downto 0);

begin

  ads8634_controller_fsm_0 : entity lsst_reb.ads8634_controller_fsm
    port map (
      clk                  => clk,
      reset                => reset,
      start_multiread      => start_multiread,
      start_singleread     => start_singleread,
      start_read_adc_reg   => start_read_adc_reg,
      spi_busy             => spi_busy,
      data_to_adc          => data_to_adc_int,
      mux_address_in       => mux_address_int,
      start_spi            => start_spi,
      link_busy            => link_busy,
      pwd_line             => pwd_line,
      mux_sam_en_out       => mux_sam_en_out,
      mux_bias_en_out      => mux_bias_en_out,
      mux_sam_address_out  => mux_sam_address_out,
      mux_bias_address_out => mux_bias_address_out,
      data_to_spi          => data_to_spi,
      out_reg_en_bus       => out_reg_en_bus
    );

  SPI_read_write_ads8634_0 : entity lsst_reb.SPI_read_write_ads8634
    generic map (
      clk_divide  => 2,
      num_bit_max => 16
    )
    port map (
      clk          => clk,
      reset        => reset,
      start_write  => start_spi,
      d_to_slave   => data_to_spi,
      miso         => miso,
      mosi         => mosi,
      ss           => ss_int,
      sclk         => sclk,
      d_from_slave => data_from_spi
    );

  spi_out_reg_generate : for i in 0 to 6 generate

    out_lsw_reg : entity lsst_reb.generic_reg_ce_init
      generic map (
        width => 15
      )
      port map (
        reset    => reset,
        clk      => clk,
        ce       => out_reg_en_bus(i),
        init     => '0',
        data_in  => data_from_spi,
        data_out => data_out(I)
      );

  end generate spi_out_reg_generate;

  mux_add_reg : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 5
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => latch_reg_in,
      init     => '0',
      data_in  => mux_address_in,
      data_out => mux_address_int
    );

  adc_data_in_reg : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 15
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => latch_reg_in,
      init     => '0',
      data_in  => data_to_adc,
      data_out => data_to_adc_int
    );

  ss           <= ss_int;
  spi_busy     <= not ss_int;
  latch_reg_in <= start_multiread or start_singleread or start_read_adc_reg;

end architecture Behavioral;

