library IEEE;
use IEEE.STD_LOGIC_1164.all;

library unisim;
use unisim.vcomponents.all;

entity programmable_delay is
  port (
    clk        : in    std_logic;
    reset      : in    std_logic;
    signal_in  : in    std_logic;
    delay_in   : in    std_logic_vector(7 downto 0);
    signal_out : out   std_logic
  );
end entity programmable_delay;

architecture Behavioral of programmable_delay is

  signal srl_q    : std_logic_vector(8 downto 0);
  signal srl_q_ch : std_logic_vector(8 downto 0);
  signal mux_fl   : std_logic_vector(3 downto 0);
  signal mux_sl   : std_logic_vector(1 downto 0);

begin

  srl_32_generate : for I in 0 to 7 generate

    SRLC32E_inst : component SRLC32E
      generic map (
        INIT => X"00000000"
      )
      port map (
        Q   => srl_q(I+1),
        Q31 => srl_q_ch(I+1),
        A   => delay_in(4 downto 0),
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
      S  => delay_in(5)
    );

  MUXF7_inst_1 : component MUXF7
    port map (
      O  => mux_fl(1),
      I0 => srl_q(3),
      I1 => srl_q(4),
      S  => delay_in(5)
    );

  MUXF7_inst_2 : component MUXF7
    port map (
      O  => mux_fl(2),
      I0 => srl_q(5),
      I1 => srl_q(6),
      S  => delay_in(5)
    );

  MUXF7_inst_3 : component MUXF7
    port map (
      O  => mux_fl(3),
      I0 => srl_q(7),
      I1 => srl_q(8),
      S  => delay_in(5)
    );

  -- MUXF8: CLB MUX to tie two MUXF7's together with general output
  --        Virtex-5
  -- Xilinx HDL Language Template, version 14.4

  MUXF8_inst_0 : component MUXF8
    port map (
      O  => mux_sl(0),
      I0 => mux_fl(0),
      I1 => mux_fl(1),
      S  => delay_in(6)
    );

  MUXF8_inst_1 : component MUXF8
    port map (
      O  => mux_sl(1),
      I0 => mux_fl(2),
      I1 => mux_fl(3),
      S  => delay_in(6)
    );

  srl_q_ch(0) <= signal_in;

  signal_out <= mux_sl(0) when delay_in(7) = '0' else
                mux_sl(1);

end architecture Behavioral;
