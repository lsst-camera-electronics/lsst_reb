library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity generic_mux_bus_4_1_clk is
  generic (
    width : integer := 32
  );
  port (
    reset    : in    std_logic; -- syncronus reset
    clk      : in    std_logic; -- clock
    selector : in    std_logic_vector(1 downto 0);
    bus_in_0 : in    std_logic_vector(width-1 downto 0);
    bus_in_1 : in    std_logic_vector(width-1 downto 0);
    bus_in_2 : in    std_logic_vector(width-1 downto 0);
    bus_in_3 : in    std_logic_vector(width-1 downto 0);
    bus_out  : out   std_logic_vector(width-1 downto 0)
  );
end entity generic_mux_bus_4_1_clk;

architecture Behavioral of generic_mux_bus_4_1_clk is

begin

  process (clk) is
  begin

    if rising_edge(clk) then              -- rising clock edge
      if (reset = '1') then               -- synchronous reset
        bus_out <= bus_in_0;
      else

        case selector is

          when "00" =>

            bus_out <= bus_in_0;

          when "01" =>

            bus_out <= bus_in_1;

          when "10" =>

            bus_out <= bus_in_2;

          when "11" =>

            bus_out <= bus_in_3;

          when others =>

            bus_out <= bus_in_0;

        end case;

      end if;
    end if;

  end process;

end architecture Behavioral;

