library IEEE;
use IEEE.STD_LOGIC_1164.all;

package SequencerPkg is

  type SequencerOutputType is record
    aspic_r_up    : std_logic;
    aspic_r_down  : std_logic;
    aspic_reset   : std_logic;
    aspic_clamp   : std_logic;
    ser_clk       : std_logic_vector(2 downto 0);
    reset_gate    : std_logic;
    par_clk       : std_logic_vector(3 downto 0);
    adc_trigger   : std_logic;
    soi           : std_logic;
    eoi           : std_logic;
    pattern_reset : std_logic;
    user_bit      : std_logic;
  end record SequencerOutputType;

  type SequencerOutputArray is array (natural range <>) of SequencerOutputType;

end package SequencerPkg;
