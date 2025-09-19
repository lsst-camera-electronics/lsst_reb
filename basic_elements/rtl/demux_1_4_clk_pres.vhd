library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity demux_1_4_clk_pres is
  port (
    reset    : in    std_logic;                   -- syncronus reset
    clk      : in    std_logic;                   -- clock
    data_in  : in    std_logic;                   -- data in
    selector : in    std_logic_vector(1 downto 0);
    data_out : out   std_logic_vector(3 downto 0) -- data out
  );
end entity demux_1_4_clk_pres;

architecture Behavioral of demux_1_4_clk_pres is

begin

  process (clk) is
  begin

    if rising_edge(clk) then              -- rising clock edge
      if (reset = '1') then               -- synchronous reset
        data_out <= (others => '1');
      else
        ----------- default values -----------
        data_out <= (others => '1');

        case selector is

          when "00" =>

            data_out(0) <= data_in;

          when "01" =>

            data_out(1) <= data_in;

          when "10" =>

            data_out(2) <= data_in;

          when "11" =>

            data_out(3) <= data_in;

          when others =>

            data_out <= (others => '1');

        end case;

      end if;
    end if;

  end process;

end architecture Behavioral;

