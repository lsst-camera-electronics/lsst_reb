library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.vcomponents.all;

entity clk_2MHz_generator is
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    clk_2MHz_en     : in    std_logic;
    clk_2MHz_en_in  : in    std_logic;
    clk_2MHz_en_out : out   std_logic;
    clk_2MHz_out    : out   std_logic
  );
end entity clk_2MHz_generator;

architecture Behavioral of clk_2MHz_generator is

  signal clk_2MHz_en_int : std_logic;
  signal d               : std_logic;
  signal q               : std_logic;

begin

  SRLC32E_inst : component SRLC32E
    generic map (
      INIT => X"00000000"
    )
    port map (
      Q   => q,
      Q31 => open,
      A   => "11000",
      CE  => clk_2MHz_en_int,
      CLK => clk,
      D   => d
    );

  clk_enable : component FDRE
    generic map (
      INIT => '0'
    )
    port map (
      Q  => clk_2MHz_en_int,
      C  => clk,
      CE => clk_2MHz_en,
      R  => reset,
      D  => clk_2MHz_en_in
    );

  d               <= not q;
  clk_2MHz_out    <= not q;
  clk_2MHz_en_out <= clk_2MHz_en_int;

end architecture Behavioral;

