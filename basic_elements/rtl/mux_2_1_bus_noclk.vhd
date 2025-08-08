library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux_2_1_bus_noclk is
  generic (
    bus_width : integer := 4
  );
  port (
    selector : in    std_logic;
    bus_in_0 : in    std_logic_vector(bus_width-1 downto 0);
    bus_in_1 : in    std_logic_vector(bus_width-1 downto 0);

    bus_out : out   std_logic_vector(bus_width-1 downto 0)
  );
end entity mux_2_1_bus_noclk;

architecture Behavioral of mux_2_1_bus_noclk is

begin

  process (selector, bus_in_0, bus_in_1) is
  begin

    case selector is

      when '0' =>

        bus_out <= bus_in_0;

      when '1' =>

        bus_out <= bus_in_1;

      when others =>

        bus_out <= bus_in_0;

    end case;

  end process;

end architecture Behavioral;

