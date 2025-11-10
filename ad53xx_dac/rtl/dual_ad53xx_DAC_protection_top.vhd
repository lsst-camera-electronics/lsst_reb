library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_reb;

entity dual_ad53xx_DAC_protection_top is
  generic (
    CLK_PERIOD_G : real;
    GD_add       : std_logic_vector(3 downto 0);
    OD_add       : std_logic_vector(3 downto 0);
    RD_add       : std_logic_vector(3 downto 0);
    GD_0_th      : integer range 0 to 2**12-1 := 1138; -- equivalent to x"472"
    OD_0_th      : integer range 0 to 2**12-1 := 2275; -- equivalent to x"8E3"
    RD_0_th      : integer range 0 to 2**12-1 := 1632; -- equivalent to x"660"
    GD_1_th      : integer range 0 to 2**12-1 := 1138; -- equivalent to x"472"
    OD_1_th      : integer range 0 to 2**12-1 := 2275; -- equivalent to x"8E3"
    RD_1_th      : integer range 0 to 2**12-1 := 1632  -- equivalent to x"660"
  );
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    start_write     : in    std_logic;
    start_ldac      : in    std_logic;
    bbs_switch_on   : in    std_logic;
    d_to_slave      : in    std_logic_vector(16 downto 0);
    command_error   : out   std_logic_vector(5 downto 0);
    values_under_th : out   std_logic_vector(5 downto 0);
    mosi            : out   std_logic;
    ss_dac_0        : out   std_logic;
    ss_dac_1        : out   std_logic;
    sclk            : out   std_logic;
    ldac            : out   std_logic;
    gd_0_thresh     : out   std_logic_vector(11 downto 0);
    od_0_thresh     : out   std_logic_vector(11 downto 0);
    rd_0_thresh     : out   std_logic_vector(11 downto 0);
    gd_1_thresh     : out   std_logic_vector(11 downto 0);
    od_1_thresh     : out   std_logic_vector(11 downto 0);
    rd_1_thresh     : out   std_logic_vector(11 downto 0)
  );
end entity dual_ad53xx_DAC_protection_top;

architecture Behavioral of dual_ad53xx_DAC_protection_top is

  constant SPI_SCLK_PERIOD_C : real := 33.0E-9;
  constant MIN_LDAC_PULSE_C  : real := 20.0E-9;

  constant ACTUAL_WIDTH_C    : integer := integer(ceil(MIN_LDAC_PULSE_C / CLK_PERIOD_G));
  constant PULSE_WIDTH_C     : integer := ACTUAL_WIDTH_C  - 1;
  constant PULSE_BIT_WIDTH_C : integer := bitSize(PULSE_WIDTH_C);

  signal start_write_delay_1 : std_logic;
  signal d_to_slave_delay_1  : std_logic_vector(15 downto 0);

  signal ss_int : std_logic_vector(1 downto 0);
  signal cs_int : std_logic_vector(0 downto 0);

  signal ldac_pulse_width    : std_logic_vector(PULSE_BIT_WIDTH_C-1 downto 0);

  signal command_error_i    : std_logic_vector(5 downto 0);
  signal values_under_th_i  : std_logic_vector(5 downto 0);
  signal first_reset_done_i : unsigned(0 downto 0);

  signal GD_0_th_int : std_logic_vector(11 downto 0);
  signal OD_0_th_int : std_logic_vector(11 downto 0);
  signal RD_0_th_int : std_logic_vector(11 downto 0);
  signal GD_1_th_int : std_logic_vector(11 downto 0);
  signal OD_1_th_int : std_logic_vector(11 downto 0);
  signal RD_1_th_int : std_logic_vector(11 downto 0);

begin

  ------------------------------------------------------------------------------
  -- SPI Interface
  ------------------------------------------------------------------------------
  cs_int(0) <= d_to_slave(16);

  SPI_write_0 : entity surf.SpiMaster
    generic map (
      NUM_CHIPS_G       => 2,
      DATA_SIZE_G       => 16,
      CPHA_G            => '1',
      CPOL_G            => '0',
      CLK_PERIOD_G      => CLK_PERIOD_G,
      SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_C
    )
    port map (
      clk     => clk,
      sRst    => reset,
      chipSel => cs_int,
      wrEn    => start_write,
      wrData  => d_to_slave(15 downto 0),
      spiCsL  => ss_int,
      spiSclk => sclk,
      spiSdi  => mosi,
      spiSdo  => '0'
    );
    ss_dac_0 <= ss_int(0);
    ss_dac_1 <= ss_int(1);

  ------------------------------------------------------------------------------
  -- LDAC Pulse
  ------------------------------------------------------------------------------
  ldac_pulse_width <= std_logic_vector(to_unsigned(PULSE_WIDTH_C, PULSE_BIT_WIDTH_C));

  ldac_pulse_gen : entity surf.OneShot
    generic map (
      IN_POLARITY_G     => '1',
      OUT_POLARITY_G    => '0',
      PULSE_BIT_WIDTH_G => PULSE_BIT_WIDTH_C
    )
    port map (
      clk        => clk,
      rst        => reset,
      pulseWidth => ldac_pulse_width,
      trigIn     => start_ldac,
      pulseOut   => ldac
    );

  ------------------------------------------------------------------------------
  -- protection logic
  ------------------------------------------------------------------------------
  -- Convert integer generics to std_logic_vector
  GD_0_th_int <= std_logic_vector(to_unsigned(GD_0_th, 12));
  OD_0_th_int <= std_logic_vector(to_unsigned(OD_0_th, 12));
  RD_0_th_int <= std_logic_vector(to_unsigned(RD_0_th, 12));
  GD_1_th_int <= std_logic_vector(to_unsigned(GD_1_th, 12));
  OD_1_th_int <= std_logic_vector(to_unsigned(OD_1_th, 12));
  RD_1_th_int <= std_logic_vector(to_unsigned(RD_1_th, 12));
  -- readback outputs
  gd_0_thresh <= GD_0_th_int;
  od_0_thresh <= OD_0_th_int;
  rd_0_thresh <= RD_0_th_int;
  gd_1_thresh <= GD_1_th_int;
  od_1_thresh <= OD_1_th_int;
  rd_1_thresh <= RD_1_th_int;

  process (clk) is
  begin

    if rising_edge(clk) then
      if (reset = '1') then
        start_write_delay_1 <= '0';
        d_to_slave_delay_1  <= (others => '0');
        command_error_i     <= (others => '0');
        if (first_reset_done_i = "0") then
          -- First reset (power-up) initialization
          first_reset_done_i <= "1";   -- Mark that first reset has occurred
          values_under_th_i  <= (others => '1');
        end if;
      else
        if (start_write = '1' and d_to_slave(15 downto 12) = GD_add) then
          if ((d_to_slave(16) = '0' and d_to_slave(11 downto 0) < GD_0_th_int) or
              (d_to_slave(16) = '1' and d_to_slave(11 downto 0) < GD_1_th_int)) then
            if (bbs_switch_on = '1') then
              start_write_delay_1 <= '0';
              d_to_slave_delay_1  <= (others => '0');
              if (d_to_slave(16) = '0') then
                command_error_i(0) <= '1';
                command_error_i(3) <= command_error_i(3);
              else
                command_error_i(0) <= command_error_i(0);
                command_error_i(3) <= '1';
              end if;
              command_error_i(1) <= command_error_i(1);
              command_error_i(2) <= command_error_i(2);
              command_error_i(4) <= command_error_i(4);
              command_error_i(5) <= command_error_i(5);
              values_under_th_i  <= values_under_th_i;
            else
              start_write_delay_1 <= start_write;
              d_to_slave_delay_1  <= d_to_slave(15 downto 0);
              if (d_to_slave(16) = '0') then
                command_error_i(0) <= '0';
                command_error_i(3) <= command_error_i(3);
              else
                command_error_i(0) <= command_error_i(0);
                command_error_i(3) <= '0';
              end if;
              command_error_i(1) <= command_error_i(1);
              command_error_i(2) <= command_error_i(2);
              command_error_i(4) <= command_error_i(4);
              command_error_i(5) <= command_error_i(5);
              if (d_to_slave(16) = '0') then
                values_under_th_i(0) <= '1';
                values_under_th_i(3) <= values_under_th_i(3);
              else
                values_under_th_i(0) <= values_under_th_i(0);
                values_under_th_i(3) <= '1';
              end if;
              values_under_th_i(1) <= values_under_th_i(1);
              values_under_th_i(2) <= values_under_th_i(2);
              values_under_th_i(4) <= values_under_th_i(4);
              values_under_th_i(5) <= values_under_th_i(5);
            end if;
          else
            start_write_delay_1 <= start_write;
            d_to_slave_delay_1  <= d_to_slave(15 downto 0);
            if (d_to_slave(16) = '0') then
              command_error_i(0) <= '0';
              command_error_i(3) <= command_error_i(3);
            else
              command_error_i(0) <= command_error_i(0);
              command_error_i(3) <= '0';
            end if;
            command_error_i(1) <= command_error_i(1);
            command_error_i(2) <= command_error_i(2);
            command_error_i(4) <= command_error_i(4);
            command_error_i(5) <= command_error_i(5);
            if (d_to_slave(16) = '0') then
              values_under_th_i(0) <= '0';
              values_under_th_i(3) <= values_under_th_i(3);
            else
              values_under_th_i(0) <= values_under_th_i(0);
              values_under_th_i(3) <= '0';
            end if;
            values_under_th_i(1) <= values_under_th_i(1);
            values_under_th_i(2) <= values_under_th_i(2);
            values_under_th_i(4) <= values_under_th_i(4);
            values_under_th_i(5) <= values_under_th_i(5);
          end if;
        elsif (start_write = '1' and d_to_slave(15 downto 12) = OD_add) then
          if ((d_to_slave(16) = '0' and d_to_slave(11 downto 0) < OD_0_th_int) or
              (d_to_slave(16) = '1' and d_to_slave(11 downto 0) < OD_1_th_int)) then
            if (bbs_switch_on = '1') then
              start_write_delay_1 <= '0';
              d_to_slave_delay_1  <= (others => '0');
              command_error_i(0)  <= command_error_i(0);
              if (d_to_slave(16) = '0') then
                command_error_i(1) <= '1';
                command_error_i(4) <= command_error_i(4);
              else
                command_error_i(1) <= command_error_i(1);
                command_error_i(4) <= '1';
              end if;
              command_error_i(2) <= command_error_i(2);
              command_error_i(3) <= command_error_i(3);
              command_error_i(5) <= command_error_i(5);
              values_under_th_i  <= values_under_th_i;
            else
              start_write_delay_1 <= start_write;
              d_to_slave_delay_1  <= d_to_slave(15 downto 0);
              command_error_i(0)  <= command_error_i(0);
              if (d_to_slave(16) = '0') then
                command_error_i(1) <= '0';
                command_error_i(4) <= command_error_i(4);
              else
                command_error_i(1) <= command_error_i(1);
                command_error_i(4) <= '0';
              end if;
              command_error_i(2) <= command_error_i(2);
              command_error_i(3) <= command_error_i(3);
              command_error_i(5) <= command_error_i(5);

              values_under_th_i(0) <= values_under_th_i(0);
              if (d_to_slave(16) = '0') then
                values_under_th_i(1) <= '1';
                values_under_th_i(4) <= values_under_th_i(4);
              else
                values_under_th_i(1) <= values_under_th_i(1);
                values_under_th_i(4) <= '1';
              end if;
              values_under_th_i(2) <= values_under_th_i(2);
              values_under_th_i(3) <= values_under_th_i(3);
              values_under_th_i(5) <= values_under_th_i(5);
            end if;
          else
            start_write_delay_1 <= start_write;
            d_to_slave_delay_1  <= d_to_slave(15 downto 0);
            command_error_i(0)  <= command_error_i(0);
            if (d_to_slave(16) = '0') then
              command_error_i(1) <= '0';
              command_error_i(4) <= command_error_i(4);
            else
              command_error_i(1) <= command_error_i(1);
              command_error_i(4) <= '0';
            end if;
            command_error_i(2) <= command_error_i(2);
            command_error_i(3) <= command_error_i(3);
            command_error_i(5) <= command_error_i(5);

            values_under_th_i(0) <= values_under_th_i(0);
            if (d_to_slave(16) = '0') then
              values_under_th_i(1) <= '0';
              values_under_th_i(4) <= values_under_th_i(4);
            else
              values_under_th_i(1) <= values_under_th_i(1);
              values_under_th_i(4) <= '0';
            end if;
            values_under_th_i(2) <= values_under_th_i(2);
            values_under_th_i(3) <= values_under_th_i(3);
            values_under_th_i(5) <= values_under_th_i(5);
          end if;
        elsif (start_write = '1' and d_to_slave(15 downto 12) = RD_add) then
          if ((d_to_slave(16) = '0' and d_to_slave(11 downto 0) < RD_0_th_int) or
              (d_to_slave(16) = '1' and d_to_slave(11 downto 0) < RD_1_th_int)) then
            if (bbs_switch_on = '1') then
              start_write_delay_1 <= '0';
              d_to_slave_delay_1  <= (others => '0');
              command_error_i(0)  <= command_error_i(0);
              command_error_i(1)  <= command_error_i(1);
              command_error_i(3)  <= command_error_i(3);
              command_error_i(4)  <= command_error_i(4);
              if (d_to_slave(16) = '0') then
                command_error_i(2) <= '1';
                command_error_i(5) <= command_error_i(5);
              else
                command_error_i(2) <= command_error_i(2);
                command_error_i(5) <= '1';
              end if;

              values_under_th_i <= values_under_th_i;
            else
              start_write_delay_1 <= start_write;
              d_to_slave_delay_1  <= d_to_slave(15 downto 0);
              command_error_i(0)  <= command_error_i(0);
              command_error_i(1)  <= command_error_i(1);
              command_error_i(3)  <= command_error_i(3);
              command_error_i(4)  <= command_error_i(4);
              if (d_to_slave(16) = '0') then
                command_error_i(2) <= '0';
                command_error_i(5) <= command_error_i(5);
              else
                command_error_i(2) <= command_error_i(2);
                command_error_i(5) <= '0';
              end if;

              values_under_th_i(0) <= values_under_th_i(0);
              values_under_th_i(1) <= values_under_th_i(1);
              values_under_th_i(3) <= values_under_th_i(3);
              values_under_th_i(4) <= values_under_th_i(4);
              if (d_to_slave(16) = '0') then
                values_under_th_i(2) <= '1';
                values_under_th_i(5) <= values_under_th_i(5);
              else
                values_under_th_i(2) <= values_under_th_i(2);
                values_under_th_i(5) <= '1';
              end if;
            end if;
          else
            start_write_delay_1 <= start_write;
            d_to_slave_delay_1  <= d_to_slave(15 downto 0);
            command_error_i(0)  <= command_error_i(0);
            command_error_i(1)  <= command_error_i(1);
            command_error_i(3)  <= command_error_i(3);
            command_error_i(4)  <= command_error_i(4);
            if (d_to_slave(16) = '0') then
              command_error_i(2) <= '0';
              command_error_i(5) <= command_error_i(5);
            else
              command_error_i(2) <= command_error_i(2);
              command_error_i(5) <= '0';
            end if;
            values_under_th_i(0) <= values_under_th_i(0);
            values_under_th_i(1) <= values_under_th_i(1);
            values_under_th_i(3) <= values_under_th_i(3);
            values_under_th_i(4) <= values_under_th_i(4);
            if (d_to_slave(16) = '0') then
              values_under_th_i(2) <= '0';
              values_under_th_i(5) <= values_under_th_i(5);
            else
              values_under_th_i(2) <= values_under_th_i(2);
              values_under_th_i(5) <= '0';
            end if;
          end if;
        else
          start_write_delay_1 <= start_write;
          d_to_slave_delay_1  <= d_to_slave(15 downto 0);
          command_error_i     <= command_error_i;
          values_under_th_i   <= values_under_th_i;
        end if;
      end if;
    end if;

  end process;

  command_error   <= command_error_i;
  values_under_th <= values_under_th_i;

end architecture Behavioral;

