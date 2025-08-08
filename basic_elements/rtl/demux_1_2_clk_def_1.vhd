library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity demux_1_2_clk_def_1 is
  port (
    reset    : in    std_logic;                   -- syncronus reset
    clk      : in    std_logic;                   -- clock
    data_in  : in    std_logic;                   -- data in
    selector : in    std_logic;
    data_out : out   std_logic_vector(1 downto 0) -- data out
  );
end entity demux_1_2_clk_def_1;

architecture Behavioral of demux_1_2_clk_def_1 is

begin

  process (clk) is
  begin

    if rising_edge(clk) then                 -- rising clock edge
      if (reset = '1') then                  -- synchronous reset
        data_out <= (others => '0');
      else
        ----------- default values -----------
        data_out <= (others => '1');

        case selector is

          when '0' =>

            data_out(0) <= data_in;

          when '1' =>

            data_out(1) <= data_in;

          when others =>

            data_out <= (others => '0');

        end case;

      end if;
    end if;

  end process;

end architecture Behavioral;
