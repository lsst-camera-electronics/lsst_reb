library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library lsst_reb;
use lsst_reb.basic_elements_pkg.all;

entity max_11046_top is
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    start_write     : in    std_logic;
    start_read      : in    std_logic;
    EOC             : in    std_logic;
    data_to_adc     : in    std_logic_vector(3 downto 0);
    data_from_adc   : in    std_logic_vector(15 downto 0);
    link_busy       : out   std_logic;
    CS              : out   std_logic;
    RD              : out   std_logic;
    WR              : out   std_logic;
    CONVST          : out   std_logic;
    SHDN            : out   std_logic;
    write_en        : out   std_logic;
    data_to_adc_out : out   std_logic_vector(3 downto 0);
    cnv_results     : out   array816
  );
end entity max_11046_top;

architecture behavioural of max_11046_top is

  signal data_to_adc_int : std_logic_vector(3 downto 0);

  signal out_reg_en_bus : std_logic_vector(7 downto 0);

begin  -- behavioural

  max_11046_ctrl_fsm_1 : entity lsst_reb.max_11046_ctrl_fsm
    port map (
      clk            => clk,
      reset          => reset,
      start_read     => start_read,
      start_write    => start_write,
      EOC            => EOC,
      link_busy      => link_busy,
      CS             => CS,
      RD             => RD,
      WR             => WR,
      CONVST         => CONVST,
      SHDN           => SHDN,
      write_en       => write_en,
      out_reg_en_bus => out_reg_en_bus
    );

  data_to_adc_reg : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 3
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => start_write,
      init     => '0',
      data_in  => data_to_adc,
      data_out => data_to_adc_out
    );

  spi_out_reg_generate : for i in 0 to 7 generate

    out_lsw_reg : entity lsst_reb.generic_reg_ce_init
      generic map (
        width => 15
      )
      port map (
        reset    => reset,
        clk      => clk,
        ce       => out_reg_en_bus(i),
        init     => '0',
        data_in  => data_from_adc,
        data_out => cnv_results(i)
      );

  end generate spi_out_reg_generate;

end architecture behavioural;

