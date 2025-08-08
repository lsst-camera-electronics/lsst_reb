library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ff_ce_pres is
  port (
    preset   : in    std_logic; -- syncronus reset
    clk      : in    std_logic; -- clock
    data_in  : in    std_logic; -- data in
    ce       : in    std_logic; -- clock enable
    data_out : out   std_logic  -- data out
  );
end entity ff_ce_pres;

architecture Behavioral of ff_ce_pres is

  signal data_out_i : std_logic;

begin

  process (clk) is
  begin                                       -- process

    if rising_edge(clk) then                  -- rising clock edge
      if (preset = '1') then                  -- synchronous reset
        data_out_i <= '1';
      else
        if (ce = '1') then
          data_out_i <= data_in;
        else
          data_out_i <= data_out_i;
        end if;
      end if;
    end if;

  end process;

  data_out <= data_out_i;

end architecture Behavioral;

