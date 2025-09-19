library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity generic_counter_comparator_ce_init is
  generic (
    length_cnt : integer := 15
  );
  port (
    reset     : in    std_logic;                             -- syncronus reset
    clk       : in    std_logic;                             -- clock
    max_value : in    std_logic_vector(length_cnt downto 0); -- maximum value the counter has to count
    enable    : in    std_logic;                             -- enable
    init      : in    std_logic;
    cnt_end   : out   std_logic;                             -- signal = 1 when the counter reach the maximum
    q_out     : out   std_logic_vector(length_cnt downto 0)
  );
end entity generic_counter_comparator_ce_init;

architecture Behavioral of generic_counter_comparator_ce_init is

  signal qi : std_logic_vector(length_cnt downto 0);

begin

  process (clk) is
  begin  -- process

    if rising_edge(clk) then
      if (reset = '1' or init = '1') then
        qi <= (others => '0');
      elsif (enable = '1') then
        qi <= qi + 1;
      else
        qi <= qi;
      end if;
    end if;

  end process;

  process (qi, max_value) is
  begin

    if ((qi) = max_value) then
      cnt_end <= '1';
    else
      cnt_end <= '0';
    end if;

  end process;

  q_out <= qi;

end architecture Behavioral;

