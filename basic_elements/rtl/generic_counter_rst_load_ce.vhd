library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity generic_counter_rst_load_ce is
  generic (
    length_cnt : integer := 15
  );
  port (
    reset    : in    std_logic;                             -- syncronus reset
    clk      : in    std_logic;                             -- clock
    preset   : in    std_logic_vector(length_cnt downto 0); -- maximum value the counter has to count
    enable   : in    std_logic;                             -- enable
    load_lsw : in    std_logic;
    load_MSW : in    std_logic;
    q_out    : out   std_logic_vector(length_cnt downto 0)
  );
end entity generic_counter_rst_load_ce;

architecture Behavioral of generic_counter_rst_load_ce is

  signal qi : std_logic_vector(length_cnt downto 0);

begin

  process (clk) is
  begin  -- process

    if rising_edge(clk) then
      if (reset = '1') then
        qi <= (others => '0');
      elsif (load_lsw = '1') then
        qi(31 downto 0) <= preset(31 downto 0);
      elsif (load_MSW = '1') then
        qi(63 downto 32) <= preset(63 downto 32);
      else
        if (enable = '1') then
          qi <= qi + 1;
        else
          qi <= qi;
        end if;
      end if;
    end if;

  end process;

  q_out <= qi;

end architecture Behavioral;

