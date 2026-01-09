library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library surf;
use surf.StdRtlPkg.all;

package reb_config_pkg is

  type RebConfigType is record
    numSequencers : integer range 1 to 3;
    sysClkPer     : real;
    gdAddr        : std_logic_vector(3 downto 0);
    odAddr        : std_logic_vector(3 downto 0);
    rdAddr        : std_logic_vector(3 downto 0);
    gdThresh      : IntegerArray(0 to 2);
    odThresh      : IntegerArray(0 to 2);
    rdThresh      : IntegerArray(0 to 2);
    reserved_1    : std_logic_vector(31 downto 0);
    reserved_2    : std_logic_vector(31 downto 0);
    reserved_3    : std_logic_vector(31 downto 0);
  end record RebConfigType;

  procedure check_configuration(
    cfg       : in RebConfigType;
    sensors   : in integer range 1 to 3;
    multiboot : in boolean;
    fwVersion : in std_logic_vector(31 downto 0);
    sci_ver   : in std_logic_vector(7 downto 0)
  );

end package reb_config_pkg;

package body reb_config_pkg is

  procedure check_configuration(
    cfg       : in RebConfigType;
    sensors   : in integer range 1 to 3;
    multiboot : in boolean;
    fwVersion : in std_logic_vector(31 downto 0);
    sci_ver   : in std_logic_vector(7 downto 0)
  ) is
  begin
    assert (cfg.numSequencers = 1 or (cfg.numSequencers = sensors))
      report "The number of sequencers must be 1 or equal to the number of sensors."
      severity failure;

    assert (fwVersion(31 downto 28) = std_logic_vector(to_unsigned(sensors, 4)))
      report "The version board type is not equal to the number of sensors."
      severity failure;

    assert (
      (multiboot = true  and fwVersion(27 downto 24) = x"1") or
      (multiboot = false and fwVersion(27 downto 24) = x"0")
      )
      report "The version multiboot config does not match."
      severity failure;

    assert (fwVersion(23 downto 16) = sci_ver)
      report "The SCI version number does not match."
      severity failure;
  end procedure;

end package body;
