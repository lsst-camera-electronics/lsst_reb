library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity generic_single_port_ram is
  generic (
    data_width : integer := 32;
    add_width  : integer := 8
  );
  port (
    clk          : in    std_logic;                              -- clock
    ram_wr_en    : in    std_logic;                              -- data in
    ram_add      : in    std_logic_vector(add_width-1 downto 0);
    ram_data_in  : in    std_logic_vector(data_width-1 downto 0);
    ram_data_out : out   std_logic_vector(data_width-1 downto 0) -- data out
  );
end entity generic_single_port_ram;

architecture Behavioral of generic_single_port_ram is

  constant RAM_DEPTH : integer := 2**add_width;
  type ram_type is array (RAM_DEPTH-1 downto 0) of std_logic_vector(data_width-1 downto 0);

  signal ram : ram_type;

begin

  process (clk) is
  begin

    if (rising_edge(clk)) then
      if (ram_wr_en = '1') then
        ram(conv_integer(ram_add)) <= ram_data_in;
      end if;
    end if;

  end process;

  ram_data_out <= ram(conv_integer(ram_add));

end architecture Behavioral;

