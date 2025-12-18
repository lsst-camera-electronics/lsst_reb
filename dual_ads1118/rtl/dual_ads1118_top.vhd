library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity dual_ads1118_top is
  generic (
    TPD_G        : time := 1 ns;
    CLK_PERIOD_G : real
  );
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    start_read    : in    std_logic;
    device_select : in    std_logic;
    miso          : in    std_logic;
    mosi          : out   std_logic;
    ss_adc        : out   std_logic_vector(1 downto 0);
    sclk          : out   std_logic;
    link_busy     : out   std_logic;
    data_from_adc : out   Slv32Array(3 downto 0)
  );
end entity dual_ads1118_top;

architecture Behavioral of dual_ads1118_top is

  -- From the TI forums:
  -- After checking with out experts it seems there is an error when the ADS1118
  -- is read using continuous SCLK speeds greater than 1MHz, where this bit gets
  -- corrupted and will read a 0 instead of a 1.
  -- To prevent this error we recommend ensuring there is at least 16µS between
  -- the first bit and the 17th bit in data transfer. Is the SCLK speed faster than 1MHz?
  constant SPI_SCLK_PERIOD_C : real := 1100.0E-9;

  constant COMMANDS_C : Slv32Array(4 downto 0) := (
    0 => x"C3EB" & x"C3EB", -- reads channel 0 range +-4.096 T_ASPIC_top
    1 => x"D3EB" & x"D3EB", -- reads channel 1 range +-4.096 T_ASPIC_bot
    2 => x"E3EB" & x"E3EB", -- reads channel 2 range +-4.096 2.5V
    3 => x"F3EB" & x"F3EB", -- reads channel 3 range +-4.096 5V (voltage divider on the board)
    4 => x"43EB" & x"43EB"  -- dummy for last read
  );

  type StateType is (
    IDLE_S,
    CMD_WAIT_S,
    CMD_SEND_S,
    WAIT_S,
    TIMEOUT_S
    );

  type RegType is record
    state        : StateType;
    spi_chip_sel : std_logic_vector(0 downto 0);
    spi_wr_en    : std_logic;
    spi_wr_data  : std_logic_vector(31 downto 0);
    data_out     : Slv32Array(3 downto 0);
    busy         : std_logic;
    sensor       : natural range 0 to 1;
    channel      : natural range 0 to 4;
    count        : natural range 0 to 1e9;
  end record RegType;

  constant REG_INIT_C : RegType := (
    state        => IDLE_S,
    spi_chip_sel => (others => '0'),
    spi_wr_en    => '0',
    spi_wr_data  => (others => '0'),
    data_out     => (others => (others => '0')),
    busy         => '0',
    sensor       => 0,
    channel      => 0,
    count        => 0
  );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal spi_csL_int : std_logic_vector(1 downto 0);
  signal spi_busy    : std_logic;
  signal data_ready  : std_logic;
  signal spi_rd_data : std_logic_vector(31 downto 0);

  --attribute MARK_DEBUG : string;
  --attribute MARK_DEBUG of r : signal is "TRUE";
  --attribute MARK_DEBUG of spi_csL_int : signal is "TRUE";
  --attribute MARK_DEBUG of spi_busy : signal is "TRUE";
  --attribute MARK_DEBUG of data_ready : signal is "TRUE";
  --attribute MARK_DEBUG of spi_rd_data : signal is "TRUE";
  --attribute MARK_DEBUG of start_read : signal is "TRUE";
  --attribute MARK_DEBUG of device_select : signal is "TRUE";

begin

  comb : process (start_read, device_select, data_ready, spi_rd_data, spi_busy, r, reset) is
    variable v : RegType;

  begin
    v := r;

    case (r.state) is

      when IDLE_S =>
        v.spi_chip_sel := (others => '0');
        v.spi_wr_data  := (others => '0');
        v.spi_wr_en    := '0';
        v.busy         := '0';
        v.sensor       :=  0;
        v.channel      :=  0;

        if (start_read = '1') then
          v.spi_chip_sel(0) := device_select;
          v.sensor          := to_integer(unsigned'("0"&device_select));
          v.busy            := '1';
          v.spi_wr_data     := COMMANDS_C(r.channel);
          v.spi_wr_en       := '1';
          v.count           := 0;
          v.state           := CMD_WAIT_S;
        else
          v.count           := r.count + 1;
        end if;

      when CMD_WAIT_S =>

        if (spi_busy = '1') then
          v.spi_wr_en   := '0';
          v.count := 0;
          v.state := CMD_SEND_S;
        elsif (r.count = 20) then
          v.count := 0;
          v.state := TIMEOUT_S;
        else
          v.count       := r.count + 1;
        end if;

      when CMD_SEND_S =>

        if (spi_busy = '0') then
          if(r.channel > 0) then
            v.data_out(r.channel - 1) := spi_rd_data;
          end if;

          v.count := 0;
          if(r.channel < 4) then
            v.state       := WAIT_S;
            v.spi_wr_data := COMMANDS_C(r.channel + 1);
          else
            v.state := IDLE_S;
          end if;
        else
          v.count := r.count + 1;
        end if;

      when WAIT_S =>

        if (data_ready = '1') then
          v.channel     := r.channel + 1;
          v.spi_wr_en   := '1';
          v.count       := 0;
          v.state       := CMD_WAIT_S;
        elsif (r.count = 1E9) then
          v.count := 0;
          v.state := TIMEOUT_S;
        else
          v.count := r.count + 1;
        end if;

      when TIMEOUT_S =>
        v.data_out := (others => (others => '0'));
        v.state    := IDLE_S;

    end case;

    if (reset = '1') then
      v := REG_INIT_C;
    end if;

    rin <= v;

  end process comb;

  seq : process (clk) is
    variable v_spi_busy : std_logic;
  begin
    if (rising_edge(clk)) then
      r          <= rin after TPD_G;
      data_ready <= not miso after TPD_G;

      if r.spi_chip_sel(0) = '1' then
        v_spi_busy := not spi_csL_int(1);
      else
        v_spi_busy := not spi_csL_int(0);
      end if;
      spi_busy <= v_spi_busy;
    end if;
  end process seq;

  SPI_ads1118_0 : entity surf.SpiMaster
    generic map (
      NUM_CHIPS_G       => 2,
      DATA_SIZE_G       => 32,
      CPHA_G            => '1',
      CPOL_G            => '0',
      CLK_PERIOD_G      => CLK_PERIOD_G,
      SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_C
    )
    port map (
      clk     => clk,
      sRst    => reset,
      chipSel => r.spi_chip_sel,
      wrEn    => r.spi_wr_en,
      wrData  => r.spi_wr_data,
      rdData  => spi_rd_data,
      spiCsL  => spi_csL_int,
      spiSclk => sclk,
      spiSdi  => mosi,
      spiSdo  => miso
    );

    ss_adc <= not (decode(r.spi_chip_sel)(1 downto 0)) when r.busy = '1' else (others => '1');
    data_from_adc <= r.data_out;
    link_busy     <= r.busy;

end architecture Behavioral;
