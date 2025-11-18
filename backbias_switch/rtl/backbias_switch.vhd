library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_misc.all;

entity backbias_switch is
port (
  sys_clk            :  in std_logic;
  sys_rst            :  in std_logic;
  all_bias_v_undr_th :  in std_logic_vector(8 downto 0);
  sw_wr_en           :  in std_logic;
  sw_wr              :  in std_logic;
  sw_error           : out std_logic;
  sw_state           : out std_logic;
  cl_state           : out std_logic;
  clamp              : out std_logic;
  ssbe               : out std_logic
);
end entity backbias_switch;

architecture rtl of backbias_switch is

  signal first_reset_done : std_logic;
  signal first_reset      : std_logic;
  signal prev_sys_rst     : std_logic;
  signal sw_state_int     : std_logic;
  signal sw_error_int     : std_logic;
  signal cl_state_int     : std_logic;

begin

  process (sys_clk) is
  begin

    if rising_edge(sys_clk) then
      if (first_reset_done = '0') then
        first_reset <= sys_rst;
        -- Detect the falling edge of the first reset
        if (prev_sys_rst = '1' and sys_rst = '0') then
          first_reset_done <= '1';
        end if;
        prev_sys_rst <= sys_rst;
      else
        first_reset <= '0';
      end if;

      if first_reset = '1' then
        sw_state_int <= '0';
        sw_error_int <= '0';
      elsif sw_wr_en = '1' then
        sw_state_int <= sw_wr and not (or_reduce(all_bias_v_undr_th));
        sw_error_int <= sw_wr and     (or_reduce(all_bias_v_undr_th));
      end if;

      cl_state_int <= not sw_state_int;

      if first_reset = '1' then
        ssbe  <= '0';
        clamp <= '1';
      else
        ssbe  <= sw_state_int;
        clamp <= cl_state_int;
      end if;

      sw_state <= sw_state_int;
      sw_error <= sw_error_int;
      cl_state <= cl_state_int;

    end if;
  end process;

end architecture rtl;