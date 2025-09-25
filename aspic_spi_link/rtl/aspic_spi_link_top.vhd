library ieee;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;

entity aspic_spi_link_top is
  generic (
    TPD_G         : time := 1 ns;
    NUM_SENSORS_G : integer range 1 to 3;
    CLK_PERIOD_G  : real
  );
  port (
    clk           : in    std_logic;
    reset         : in    std_logic;
    start_trans   : in    std_logic;
    start_reset   : in    std_logic;
    data_in       : in    std_logic_vector(31 downto 0);
    aspic_miso    : in    std_logic_vector(NUM_SENSORS_G-1 downto 0);
    aspic_mosi    : out   std_logic_vector(NUM_SENSORS_G-1 downto 0);
    ss_t_ccd      : out   std_logic_vector(NUM_SENSORS_G-1 downto 0);
    ss_b_ccd      : out   std_logic_vector(NUM_SENSORS_G-1 downto 0);
    aspic_sclk    : out   std_logic_vector(NUM_SENSORS_G-1 downto 0);
    aspic_reset   : out   std_logic_vector(NUM_SENSORS_G-1 downto 0);
    busy          : out   std_logic;
    data_out      : out   Slv16Array(NUM_SENSORS_G-1 downto 0)
  );
end entity aspic_spi_link_top;

architecture rtl of aspic_spi_link_top is

  constant SPI_SCLK_PERIOD_C : real     := 80.0E-9;
  constant DATA_SIZE_C       : natural  := 25;
  constant RD_DATA_SIZE_C    : natural  := 25;
  constant WR_DATA_SIZE_C    : natural  := 24;
  signal   dataSize          : std_logic_vector(bitSize(DATA_SIZE_C)-1 downto 0);

  -- Reset Pulse Calculations
  constant ACTUAL_WIDTH_C     : integer := integer(ceil(SPI_SCLK_PERIOD_C / CLK_PERIOD_G))*4;
  constant PULSE_WIDTH_C      : integer := ACTUAL_WIDTH_C  - 1;
  constant PULSE_BIT_WIDTH_C  : integer := bitSize(PULSE_WIDTH_C);
  signal   reset_pulse_width  : std_logic_vector(PULSE_BIT_WIDTH_C-1 downto 0);
  signal   reset_pulse   : std_logic;

  -- SPI signals
  signal spi_csL     : Slv1Array(NUM_SENSORS_G-1 downto 0);
  signal spi_cs      : std_logic_vector(NUM_SENSORS_G-1 downto 0);
  signal spi_rdEn    : std_logic_vector(NUM_SENSORS_G-1 downto 0);
  signal spi_rdData  : Slv25Array(NUM_SENSORS_G-1 downto 0);
  signal wrEn        : std_logic_vector(NUM_SENSORS_G-1 downto 0);
  signal wrData      : std_logic_vector(DATA_SIZE_C-1 downto 0);

  -- SPI state machine
  type StateType is (
    IDLE_S,
    START_S,
    WAIT_S
  );

  type RegType is record
    state    : StateType;
    busy     : std_logic;
    sen_en   : std_logic_vector(2 downto 0);
    tb_en    : std_logic_vector(1 downto 0);
    wrData   : std_logic_vector(DATA_SIZE_C-1 downto 0);
    dir      : std_logic;
    wrEn     : std_logic_vector(NUM_SENSORS_G-1 downto 0);
    dataSize : std_logic_vector(bitSize(DATA_SIZE_C)-1 downto 0);
    rdData   : Slv16Array(NUM_SENSORS_G-1 downto 0);
  end record RegType;

  constant REG_INIT_C : RegType := (
    state    => IDLE_S,
    busy     => '0',
    sen_en   => (others => '0'),
    tb_en    => (others => '0'),
    wrData   => (others => '0'),
    dir      => '0',
    wrEn     => (others => '0'),
    dataSize => (others => '0'),
    rdData   => (others => (others => '0'))
  );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  -- Data in structure
  alias sensor_enable : std_logic_vector(2 downto 0) is data_in(28 downto 26);
  alias topbot_enable : std_logic_vector(1 downto 0) is data_in(25 downto 24);
  alias readwr_dir    : std_logic                    is data_in(23);

begin

  ------------------------------------------------------------------------------
  -- SPI control logic
  ------------------------------------------------------------------------------
  comb : process(r, reset, start_trans, spi_rdEn, data_in, spi_rdData)
    variable v : RegType;
  begin
    v := r;

    case r.state is

      when IDLE_S =>
        v.busy     := '0';
        v.sen_en   := (others => '0');
        v.tb_en    := (others => '0');
        v.wrData   := (others => '0');
        v.dir      := '0';
        v.wrEn     := (others => '0');
        v.dataSize := (others => '0');
        if (start_trans = '1') then
          v.busy   := '1';
          v.sen_en := sensor_enable;
          v.tb_en  := topbot_enable;
          v.dir    := readwr_dir;
          v.wrEn   := sensor_enable;
          v.state  := START_S;
          if (readwr_dir = '0') then
            v.wrData   := data_in(23 downto 16) & '1' & x"0000";
            v.dataSize := std_logic_vector(to_unsigned(RD_DATA_SIZE_C-1, bitSize(DATA_SIZE_C)));
          else
            v.wrData   := data_in(23 downto 0) & '0';
            v.dataSize := std_logic_vector(to_unsigned(WR_DATA_SIZE_C-1, bitSize(DATA_SIZE_C)));
          end if;
        end if;

      when START_S =>
        v.busy := '1';
        v.wrEn := (others => '0');
        if(uAnd(spi_rdEn) = '0') then
          v.state := WAIT_S;
        end if;

      when WAIT_S =>
        v.busy := '1';
        if(r.dir = '0') then
          for s in 0 to NUM_SENSORS_G-1 loop
            if(sensor_enable(s) = '1') then
              if(spi_rdEn(s) = '1') then
                v.rdData(s) := spi_rdData(s)(15 downto 0); -- or is it 23 downto 8?
              end if;
            end if;
          end loop;
        end if;

        if(uAnd(spi_rdEn) = '1') then
          v.state := IDLE_S;
        end if;
    end case;

    if(reset = '1') then
      v := REG_INIT_C;
    end if;

    rin <= v;

  end process comb;

  -- Reset
  seq : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  -- SPI signals
  wrEn     <= r.wrEn;
  wrData   <= r.wrData;
  dataSize <= r.dataSize;

  -- Output
  busy     <= r.busy;
  data_out <= r.rdData;

  -- Chip select logic
  chip_select : process(r, spi_csL, spi_cs)

  begin
    ss_t_ccd <= (others => '0');
    ss_b_ccd <= (others => '0');

    for s in 0 to NUM_SENSORS_G-1 loop
      spi_cs(s) <= not spi_csL(s)(0);
      if(spi_cs(s) = '1') then
        if(r.dir = '1') then
          ss_t_ccd(s) <= r.sen_en(s) and r.tb_en(0);
          ss_b_ccd(s) <= r.sen_en(s) and r.tb_en(1);
        else
          if(r.tb_en(0) = '1') then
            ss_t_ccd(s) <= r.sen_en(s);
          else
            if(r.tb_en(1) = '1') then
              ss_b_ccd(s) <= r.sen_en(s);
            end if;
          end if;
        end if;
      end if;
    end loop;

  end process chip_select;

  ------------------------------------------------------------------------------
  -- SPI Interface (tie outputs together to support broadcast)
  ------------------------------------------------------------------------------
  -- to allow 3 simultaneous reads (of either top or bottom)
  -- we need 3 separate masters
  sensor_apsic : for s in 0 to NUM_SENSORS_G-1 generate
    U_SpiMaster : entity surf.SpiMaster
      generic map (
        TPD_G             => TPD_G,
        NUM_CHIPS_G       => 1,
        DATA_SIZE_G       => DATA_SIZE_C,
        CPHA_G            => '1',
        CPOL_G            => '0',
        CLK_PERIOD_G      => CLK_PERIOD_G,
        SPI_SCLK_PERIOD_G => SPI_SCLK_PERIOD_C
      )
      port map (
        -- Clocks and resets
        clk        => clk,
        sRst       => reset,
        -- Parallel interface
        chipSel    => "0",
        wrEn       => wrEn(s),
        wrData     => wrData,
        dataSize   => dataSize,
        rdEn       => spi_rdEn(s),
        rdData     => spi_rdData(s),
        -- SPI interface
        spiCsL     => spi_csL(s),
        spiSclk    => aspic_sclk(s),
        spiSdi     => aspic_mosi(s),
        spiSdo     => aspic_miso(s)
      );
  end generate sensor_apsic;

  ------------------------------------------------------------------------------
  -- Reset Pulse
  ------------------------------------------------------------------------------
  reset_pulse_width <= std_logic_vector(to_unsigned(PULSE_WIDTH_C, PULSE_BIT_WIDTH_C));

  U_ResetPulse : entity surf.OneShot
    generic map (
      IN_POLARITY_G     => '1',
      OUT_POLARITY_G    => '1',
      PULSE_BIT_WIDTH_G => PULSE_BIT_WIDTH_C
    )
    port map (
      clk        => clk,
      rst        => reset,
      pulseWidth => reset_pulse_width,
      trigIn     => start_reset,
      pulseOut   => reset_pulse
    );

  aspic_reset <= sensor_enable(NUM_SENSORS_G-1 downto 0) when reset_pulse = '1' else (others => '0');


end rtl;