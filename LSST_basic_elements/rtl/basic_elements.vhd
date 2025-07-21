library IEEE;
use IEEE.STD_LOGIC_1164.all;

package basic_elements is

  subtype word_32 is std_logic_vector (31 downto 0);
  type    array432 is array (3 downto 0) of word_32;

  subtype word_16 is std_logic_vector (15 downto 0);
  type    array816 is array (7 downto 0) of word_16;
  type    array2416 is array (23 downto 0) of word_16;

end basic_elements;

package body basic_elements is

end basic_elements;
