library IEEE;
use IEEE.STD_LOGIC_1164.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_reb;

entity sync_cmd_decoder_top is
  port (
    pgp_clk            : in    std_logic;
    pgp_reset          : in    std_logic;
    clk                : in    std_logic;
    reset              : in    std_logic;
    sync_cmd_en        : in    std_logic;
    delay_en           : in    std_logic;
    delay_in           : in    std_logic_vector(7 downto 0);
    delay_read         : out   std_logic_vector(7 downto 0);
    sync_cmd           : in    std_logic_vector(7 downto 0);
    sync_cmd_start_seq : out   std_logic;
    sync_cmd_step_seq  : out   std_logic;
    sync_cmd_stop_seq  : out   std_logic;
    sync_cmd_main_add  : out   std_logic_vector(4 downto 0)
  );
end entity sync_cmd_decoder_top;

architecture Behavioral of sync_cmd_decoder_top is

  signal sync_cmd_start_int  : std_logic;
  signal sync_cmd_step_int   : std_logic;
  signal sync_cmd_stop_int   : std_logic;
  signal sync_cmd_addr_int   : std_logic_vector(4 downto 0);
  signal delay_in_reg        : std_logic_vector(7 downto 0);
  signal delay_bus_in        : std_logic_vector(8 downto 0);
  signal delay_bus_out       : std_logic_vector(8 downto 0);
  signal sync_cmd_delay      : std_logic_vector(7 downto 0);
  signal sync_cmd_en_delay   : std_logic;

  signal sync_cmd_fifo_out    : std_logic_vector(7 downto 0);
  signal sync_cmd_fifo_valid  : std_logic;

begin

  -- synchonize the input
  sync_cmd_fifo : entity surf.SynchronizerFifo
    generic map (
      DATA_WIDTH_G => 8,
      ADDR_WIDTH_G => 4
    )
    port map (
      rst    => pgp_reset,
      wr_clk => pgp_clk,
      wr_en  => sync_cmd_en,
      din    => sync_cmd,
      rd_clk => clk,
      dout   => sync_cmd_fifo_out,
      valid  => sync_cmd_fifo_valid
    );

  -- Delay the command
  delay_register : entity surf.RegisterVector
    generic map (
      WIDTH_G => 8
    )
    port map (
      clk   => clk,
      rst   => reset,
      en    => delay_en,
      sig_i => delay_in,
      reg_o => delay_in_reg
    );

  delay_bus_in <= sync_cmd_fifo_valid & sync_cmd_fifo_out;

  sync_cmd_delay_reg : entity surf.SlvDelay
    generic map (
      DELAY_G => 255,
      WIDTH_G => 9
    )
    port map (
      clk   => clk,
      rst   => reset,
      delay => delay_in_reg,
      din   => delay_bus_in,
      dout  => delay_bus_out
    );

  sync_cmd_en_delay <= delay_bus_out(8);
  sync_cmd_delay    <= delay_bus_out(7 downto 0);

  sync_cmd_decoder_1 : entity lsst_reb.sync_cmd_decoder
    port map (
      clk            => clk,
      reset          => reset,
      sync_cmd_en    => sync_cmd_en_delay,
      sync_cmd       => sync_cmd_delay,
      sync_cmd_start => sync_cmd_start_int,
      sync_cmd_step  => sync_cmd_step_int,
      sync_cmd_stop  => sync_cmd_stop_int,
      sync_cmd_addr  => sync_cmd_addr_int
    );


  delay_read         <= delay_in_reg;
  sync_cmd_main_add  <= sync_cmd_addr_int;
  sync_cmd_start_seq <= sync_cmd_start_int;
  sync_cmd_step_seq  <= sync_cmd_step_int;
  sync_cmd_stop_seq  <= sync_cmd_stop_int;

end architecture Behavioral;

