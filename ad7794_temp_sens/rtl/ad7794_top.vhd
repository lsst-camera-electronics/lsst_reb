library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_reb;

entity ad7794_top is
  generic (
    CLK_PERIOD_G : real
  );
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    start           : in    std_logic;
    start_reset     : in    std_logic;
    read_dir        : in    std_logic;
    reg_add         : in    std_logic_vector(2 downto 0);
    data_in         : in    std_logic_vector(15 downto 0);
    ad7794_dout_rdy : in    std_logic;
    ad7794_din      : out   std_logic;
    ad7794_cs       : out   std_logic;
    ad7794_sclk     : out   std_logic;
    busy            : out   std_logic;
    data_out        : out   std_logic_vector(23 downto 0)
  );
end entity ad7794_top;

architecture Behavioral of ad7794_top is

  constant SPI_SCLK_PERIOD_C : real := 200.0E-9;

  -- Data Sizes for the different registers
  constant DATA_SIZE_C  : natural  := 32;
  constant DATA_WIDTH_C : positive := log2(DATA_SIZE_C);

  type bit_length_array_t is array (0 to 7) of natural;
  constant REG_BIT_LENGTHS : bit_length_array_t := (
    0 =>  8,
    1 => 16,
    2 => 16,
    3 => 24,
    4 =>  8,
    5 =>  8,
    6 => 24,
    7 => 24
  );

  function command_byte(read_dir : std_logic; reg_addr : std_logic_vector(2 downto 0))
    return std_logic_vector is
    variable cmd : std_logic_vector(7 downto 0);
  begin
    cmd := '0' & read_dir & reg_addr & "000";
    return cmd;
  end function;

  function wr_payload(reg_addr : std_logic_vector(2 downto 0); data_in : std_logic_vector(15 downto 0))
    return std_logic_vector is
    variable size : natural;
    variable data_24bit : std_logic_vector(23 downto 0);
  begin
    size := REG_BIT_LENGTHS(to_integer(unsigned(reg_addr)));
    data_24bit := resize(data_in, 24);
    -- It looks like the old firmware (and therefore CCS) is expecting the data
    -- to be left shifted to 16 bits, and 24 bit writes are not supported. Sigh.
    --return std_logic_vector(shift_left(unsigned(data_24bit), 24-size));
    return std_logic_vector(shift_left(unsigned(data_24bit), 8));
  end function;

  function data_size(reg_addr: std_logic_vector(2 downto 0))
    return std_logic_vector is
    variable addr      : natural;
    variable orig_size : natural;
    variable adj_size  : natural;
  begin
    addr      := to_integer(unsigned(reg_addr));
    orig_size := REG_BIT_LENGTHS(addr);
    adj_size  := 8+orig_size -1;
    return std_logic_vector(to_unsigned(adj_size, DATA_WIDTH_C));
  end function;

  -- SPI signals
  signal wrEn     : std_logic;
  signal wrData   : std_logic_vector(DATA_SIZE_C-1 downto 0);
  signal dataSize : std_logic_vector(DATA_WIDTH_C-1 downto 0);
  signal rdEn     : std_logic;
  signal rdData   : std_logic_vector(DATA_SIZE_C-1 downto 0);
  signal spiCsL   : std_logic_vector(0 downto 0);
  signal spiSclk  : std_logic;
  signal spiSdi   : std_logic;
  signal spiSdo   : std_logic;

  -- SPI Control
  type StateType is (
    IDLE_S,
    START_S,
    WAIT_S
  );

  type RegType is record
    state    : StateType;
    busy     : std_logic;
    wrData   : std_logic_vector(DATA_SIZE_C-1 downto 0);
    wrEn     : std_logic;
    dataSize : std_logic_vector(DATA_WIDTH_C-1 downto 0);
    read_data : std_logic_vector(23 downto 0);
  end record RegType;

  constant REG_INIT_C : RegType := (
    state    => IDLE_S,
    busy     => '0',
    wrData   => (others => '0'),
    wrEn     => '0',
    dataSize => (others => '0'),
    read_data => (others => '0')
  );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  ------------------------------------------------------------------------------
  -- SPI control logic
  ------------------------------------------------------------------------------
  comb : process(r, reset, start, start_reset, read_dir, reg_add, data_in, rdEn, rdData)
    variable v : RegType;
  begin
    v := r;

    case r.state is
      when IDLE_S =>
        v.busy   := '0';
        v.wrData := (others => '0');
        v.wrEn   := '0';

        if (start = '1') then
          v.busy     := '1';
          v.wrEn     := '1';

          v.wrData(DATA_SIZE_C-1 downto 24) := command_byte(read_dir, reg_add);
          v.dataSize := data_size(reg_add);
          if(read_dir = '0') then
            v.wrData(23 downto 0) := wr_payload(reg_add, data_in);
          else
            v.wrData(23 downto 0) := slvZero(24);
          end if;

          v.state := START_S;
        end if;

        if(start_reset = '1') then
          v.busy     := '1';
          v.wrEn     := '1';
          v.wrData   := slvOne(DATA_SIZE_C);
          v.dataSize := std_logic_vector(to_unsigned(DATA_SIZE_C-1, DATA_WIDTH_C));
          v.state := START_S;
        end if;

      when START_S =>
        if(rdEn = '0') then
          v.state := WAIT_S;
        end if;

      when WAIT_S =>
        v.wrEn := '0';

        if(rdEn = '1') then
          v.read_data := rdData(23 downto 0);
          v.state     := IDLE_S;
        end if;

    end case;

    if(reset = '1') then
      v.state    := WAIT_S;
    end if;

    rin <= v;

  end process comb;

  seq : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process seq;

  wrEn     <= r.wrEn;
  wrData   <= r.wrData;
  dataSize <= r.dataSize;
  data_out <= r.read_data;

  ------------------------------------------------------------------------------
  -- SPI Interface (tie outputs together to support broadcast)
  ------------------------------------------------------------------------------
  U_SpiMaster : entity surf.SpiMaster
    generic map (
      NUM_CHIPS_G       => 1,
      DATA_SIZE_G       => DATA_SIZE_C,
      CPHA_G            => '1',
      CPOL_G            => '1',
      CLK_PERIOD_G      => CLK_PERIOD_G,
      SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_C
    )
    port map (
      -- Clocks and resets
      clk        => clk,
      sRst       => reset,
      -- Parallel interface
      chipSel    => "0",
      wrEn       => wrEn,
      wrData     => wrData,
      dataSize   => dataSize,
      rdEn       => rdEn,
      rdData     => rdData,
      -- SPI interface
      spiCsL     => spiCsL,
      spiSclk    => spiSclk,
      spiSdi     => spiSdi,
      spiSdo     => spiSdo
    );

    -- SPI outputs
    spiSdo <= ad7794_dout_rdy;
    ad7794_din      <= spiSdi;
    ad7794_cs       <= spiCsL(0);
    ad7794_sclk     <= spiSclk;


end architecture Behavioral;
