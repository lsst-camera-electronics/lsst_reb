library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity mux_4_1_clk is
  port (
    reset    : in    std_logic; -- syncronus reset
    clk      : in    std_logic; -- clock
    selector : in    std_logic_vector(1 downto 0);
    in_0     : in    std_logic;
    in_1     : in    std_logic;
    in_2     : in    std_logic;
    in_3     : in    std_logic;

    output : out   std_logic
  );
end entity mux_4_1_clk;

architecture Behavioral of mux_4_1_clk is

begin

  process (clk) is
  begin

    if rising_edge(clk) then              -- rising clock edge
      if (reset = '1') then               -- synchronous reset
        output <= in_0;
      else

        case selector is

          when "00" =>

            output <= in_0;

          when "01" =>

            output <= in_1;

          when "10" =>

            output <= in_2;

          when "11" =>

            output <= in_3;

          when others =>

            output <= in_0;

        end case;

      end if;
    end if;

  end process;

end architecture Behavioral;

