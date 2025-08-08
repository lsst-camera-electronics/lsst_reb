library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library lsst_reb;

entity base_reg_set_top is
  port (
    clk                : in    std_logic;
    reset              : in    std_logic;
    en_time_base_cnt   : in    std_logic;
    load_time_base_lsw : in    std_logic;
    load_time_base_MSW : in    std_logic;
    StatusReset        : in    std_logic;
    trigger_TB         : in    std_logic;
    trigger_seq        : in    std_logic;
    trigger_V_I_read   : in    std_logic;
    trigger_temp_pcb   : in    std_logic;
    trigger_fast_adc   : in    std_logic;
    cnt_preset         : in    std_logic_vector(63 downto 0);
    cnt_busy           : out   std_logic;
    cnt_actual_value   : out   std_logic_vector(63 downto 0);
    trig_tm_value_SB   : out   std_logic_vector(63 downto 0);
    trig_tm_value_TB   : out   std_logic_vector(63 downto 0);
    trig_tm_value_seq  : out   std_logic_vector(63 downto 0);
    trig_tm_value_V_I  : out   std_logic_vector(63 downto 0);
    trig_tm_value_pcb  : out   std_logic_vector(63 downto 0);
    trig_tm_value_adc  : out   std_logic_vector(63 downto 0)
  );
end entity base_reg_set_top;

architecture Behavioral of base_reg_set_top is

  signal en_time_base_latched : std_logic;
  signal cnt_actual_value_int : std_logic_vector(63 downto 0);

begin

  cnt_en_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => trigger_TB,
      ce       => en_time_base_cnt,
      data_out => en_time_base_latched
    );

  time_base_cnt : entity lsst_reb.generic_counter_rst_load_ce
    generic map (
      length_cnt => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      preset   => cnt_preset,
      enable   => en_time_base_latched,
      load_lsw => load_time_base_lsw,
      load_MSW => load_time_base_MSW,
      q_out    => cnt_actual_value_int
    );

  trigger_time_SB : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => StatusReset,
      init     => '0',
      data_in  => cnt_actual_value_int,
      data_out => trig_tm_value_SB
    );

  trigger_time_TB : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => trigger_TB,
      init     => '0',
      data_in  => cnt_actual_value_int,
      data_out => trig_tm_value_TB
    );

  trigger_time_seq : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => trigger_seq,
      init     => '0',
      data_in  => cnt_actual_value_int,
      data_out => trig_tm_value_seq
    );

  trigger_time_V_I : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => trigger_V_I_read,
      init     => '0',
      data_in  => cnt_actual_value_int,
      data_out => trig_tm_value_V_I
    );

  trigger_time_temp_pcb : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => trigger_temp_pcb,
      init     => '0',
      data_in  => cnt_actual_value_int,
      data_out => trig_tm_value_pcb
    );

  trigger_time_fast_adc : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 63
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => trigger_fast_adc,
      init     => '0',
      data_in  => cnt_actual_value_int,
      data_out => trig_tm_value_adc
    );

  cnt_actual_value <= cnt_actual_value_int;
  cnt_busy         <= en_time_base_latched;

end architecture Behavioral;

