library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.math_real.all;

package basic_elements_pkg is

  function calcClockPeriods(goalTime, clockPeriod : real) return natural;

  subtype word_32 is std_logic_vector(31 downto 0);

  type array332 is array (2 downto 0) of word_32;

  type array432 is array (3 downto 0) of word_32;

  subtype word_24 is std_logic_vector(23 downto 0);

  type array324 is array (2 downto 0) of word_24;

  subtype word_16 is std_logic_vector(15 downto 0);

  type array316 is array (2 downto 0) of word_16;

  type array716 is array (6 downto 0) of word_16;

  type array816 is array (7 downto 0) of word_16;

  type array2416 is array (23 downto 0) of word_16;

  subtype word_18 is std_logic_vector(17 downto 0);

  type array1618 is array (15 downto 0) of word_18;

  subtype word_10 is std_logic_vector(9 downto 0);

  type array310 is array (2 downto 0) of word_10;

  subtype word_8 is std_logic_vector(7 downto 0);

  type array28 is array (1 downto 0) of word_8;

  type array48 is array (3 downto 0) of word_8;

  type array88 is array (7 downto 0) of word_8;

  type array108 is array (9 downto 0) of word_8;

  subtype word_4 is std_logic_vector(3 downto 0);

  type array34 is array (2 downto 0) of word_4;

end package basic_elements_pkg;

package body basic_elements_pkg is

-- Function to calculate clock periods needed to meet or exceed a given time period
function calcClockPeriods(goalTime, clockPeriod : real) return natural is
begin
  -- Return ceiling of the ratio to ensure we meet or exceed the target time
  if goalTime <= 0.0 or clockPeriod <= 0.0 then
    return 0;  -- Handle invalid inputs
  else
    return natural(CEIL(goalTime / clockPeriod));
  end if;
end function calcClockPeriods;

end package body basic_elements_pkg;
