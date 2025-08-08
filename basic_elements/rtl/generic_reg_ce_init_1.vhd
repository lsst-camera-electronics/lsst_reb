library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity generic_reg_ce_init_1 is
  generic (
    width : integer := 15
  );
  port (
    reset    : in    std_logic;                        -- syncronus reset
    clk      : in    std_logic;                        -- clock
    ce       : in    std_logic;                        -- clock enable
    init     : in    std_logic;                        -- signal to reset the reg (active high)
    data_in  : in    std_logic_vector(width downto 0); -- data in
    data_out : out   std_logic_vector(width downto 0)  -- data out
  );
end entity generic_reg_ce_init_1;

architecture Behavioral of generic_reg_ce_init_1 is

  signal data_out_i : std_logic_vector(width downto 0);

begin

  process (clk) is
  begin                                                    -- process

    if rising_edge(clk) then                               -- rising clock edge
      if (reset = '1' or init = '1') then                  -- synchronous reset
        data_out_i <= (others => '1');
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

