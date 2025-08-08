library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.vcomponents.all;

library lsst_reb;

entity sequencer_aligner_shifter_top is
  generic (
    start_adc_bit : natural := 12
  );
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    shift_on_en   : in    std_logic;
    shift_on      : in    std_logic;
    init_shift    : in    std_logic;
    sequencer_in  : in    std_logic_vector(31 downto 0);
    shift_on_out  : out   std_logic;
    sequencer_out : out   std_logic_vector(31 downto 0)
  );
end entity sequencer_aligner_shifter_top;

architecture Behavioral of sequencer_aligner_shifter_top is

  signal sequencer_int_1        : std_logic_vector(31 downto 0);
  signal sequencer_int_2        : std_logic_vector(31 downto 0);
  signal sequencer_int_3        : std_logic_vector(31 downto 0);
  signal shift_counter          : std_logic_vector(7 downto 0);
  signal shift_counter_en       : std_logic;
  signal sequencer_shift_out    : std_logic;
  signal en_shift_counter       : std_logic;
  signal shift_counter_en_delay : std_logic;

  signal srl_q                    : std_logic_vector(8 downto 0);
  signal srl_q_ch                 : std_logic_vector(8 downto 0);
  signal mux_fl                   : std_logic_vector(3 downto 0);
  signal mux_sl                   : std_logic_vector(1 downto 0);
  signal sequencer_shift_out_reg  : std_logic;
  signal shift_counter_enable     : std_logic;
  signal shift_counter_enable_reg : std_logic;

begin

  sequencer_delay_1 : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 31
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => '1',
      init     => '0',
      data_in  => sequencer_in,
      data_out => sequencer_int_1
    );

  sequencer_delay_2 : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 31
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => '1',
      init     => '0',
      data_in  => sequencer_int_1,
      data_out => sequencer_int_2
    );

  sequencer_delay_3 : entity lsst_reb.generic_reg_ce_init
    generic map (
      width => 31
    )
    port map (
      reset    => reset,
      clk      => clk,
      ce       => '1',
      init     => '0',
      data_in  => sequencer_int_2,
      data_out => sequencer_int_3
    );

  shift_counter_1 : entity lsst_reb.generic_counter_comparator_ce_init
    generic map (
      length_cnt => 7
    )
    port map (
      reset     => reset,
      clk       => clk,
      max_value => "11111111",
      enable    => shift_counter_enable_reg,
      init      => init_shift,
      cnt_end   => open,
      q_out     => shift_counter
    );

  -- SRLC32E: 32-bit variable length shift register LUT
  --          with clock enable
  --          Virtex-5
  -- Xilinx HDL Language Template, version 14.4

  srl_32_generate : for I in 0 to 7 generate

    SRLC32E_inst : component SRLC32E
      generic map (
        INIT => X"00000000"
      )
      port map (
        Q   => srl_q(I+1),
        Q31 => srl_q_ch(I+1),
        A   => shift_counter(4 downto 0),
        CE  => '1',
        CLK => clk,
        D   => srl_q_ch(I)
      );

  end generate srl_32_generate;

  -- MUXF7: CLB MUX to tie two LUT6's together with general output
  --        Virtex-5
  -- Xilinx HDL Language Template, version 14.4

  MUXF7_inst_0 : component MUXF7
    port map (
      O  => mux_fl(0),
      I0 => srl_q(1),
      I1 => srl_q(2),
      S  => shift_counter(5)
    );

  MUXF7_inst_1 : component MUXF7
    port map (
      O  => mux_fl(1),
      I0 => srl_q(3),
      I1 => srl_q(4),
      S  => shift_counter(5)
    );

  MUXF7_inst_2 : component MUXF7
    port map (
      O  => mux_fl(2),
      I0 => srl_q(5),
      I1 => srl_q(6),
      S  => shift_counter(5)
    );

  MUXF7_inst_3 : component MUXF7
    port map (
      O  => mux_fl(3),
      I0 => srl_q(7),
      I1 => srl_q(8),
      S  => shift_counter(5)
    );

  -- MUXF8: CLB MUX to tie two MUXF7's together with general output
  --        Virtex-5
  -- Xilinx HDL Language Template, version 14.4

  MUXF8_inst_0 : component MUXF8
    port map (
      O  => mux_sl(0),
      I0 => mux_fl(0),
      I1 => mux_fl(1),
      S  => shift_counter(6)
    );

  MUXF8_inst_1 : component MUXF8
    port map (
      O  => mux_sl(1),
      I0 => mux_fl(2),
      I1 => mux_fl(3),
      S  => shift_counter(6)
    );

  sequencer_shift_out <= mux_sl(0) WHEN shift_counter(7) = '0' ELSE
                         mux_sl(1);

  srl_q_ch(0) <= sequencer_in(start_adc_bit);

  shift_reg_out_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => sequencer_shift_out,
      ce       => '1',
      data_out => sequencer_shift_out_reg
    );

  shift_mode_en_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => shift_on,
      ce       => shift_on_en,
      data_out => en_shift_counter
    );

  shift_counter_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => shift_counter_en,
      ce       => '1',
      data_out => shift_counter_en_delay
    );

  shift_counter_enable_ff : entity lsst_reb.ff_ce
    port map (
      reset    => reset,
      clk      => clk,
      data_in  => shift_counter_enable,
      ce       => '1',
      data_out => shift_counter_enable_reg
    );

  shift_counter_en <= sequencer_shift_out_reg and en_shift_counter;
  sequencer_out    <= sequencer_int_3(31 downto start_adc_bit + 1) & sequencer_shift_out_reg & sequencer_int_3(start_adc_bit - 1 downto 0);

  shift_counter_enable <= shift_counter_en_delay and not shift_counter_en;

  shift_on_out <= en_shift_counter;

end architecture Behavioral;

