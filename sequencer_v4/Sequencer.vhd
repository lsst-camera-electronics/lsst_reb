library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_reb;
use lsst_reb.SequencerPkg.all;

entity Sequencer is
  generic (
    NUM_SENSORS_G    : integer range 1 to 3;
    NUM_SEQUENCERS_G : integer range 1 to 3
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    -- Register Interface
    regAddr   : in std_logic_vector(23 downto 0);
    regDataWr : in std_logic_vector(31 downto 0);
    -- Synchronous Command Interface
    sync_cmd_start         : in std_logic;
    sync_cmd_stop          : in std_logic;
    sync_cmd_step          : in std_logic;
    -- Register Command Interface
    reg_cmd_start          : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    reg_cmd_stop           : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    reg_cmd_step           : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    -- Sequencer Main Selection
    sync_cmd_main_addr      : in  std_logic_vector(4 downto 0);
    sequencer_start_addr_rd : out Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
    -- Various memory write and readback
    prog_mem_we            : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    prog_mem_rd            : out Slv32Array(NUM_SEQUENCERS_G-1 downto 0);
    ind_func_mem_we        : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    ind_func_mem_rd        : out Slv4Array (NUM_SEQUENCERS_G-1 downto 0);
    ind_rep_mem_we         : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    ind_rep_mem_rd         : out Slv24Array(NUM_SEQUENCERS_G-1 downto 0);
    ind_sub_add_mem_we     : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    ind_sub_add_mem_rd     : out Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
    ind_sub_rep_mem_we     : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    ind_sub_rep_mem_rd     : out Slv16Array(NUM_SEQUENCERS_G-1 downto 0);
    time_mem_we            : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    time_mem_rd            : out Slv16Array(NUM_SEQUENCERS_G-1 downto 0);
    out_mem_we             : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    out_mem_rd             : out Slv32Array(NUM_SEQUENCERS_G-1 downto 0);
    -- Error --
    op_code_error_reset    : in  std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    op_code_error          : out std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    op_code_error_add      : out Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
    -- Aligner Shifter
    enable_conv_shift     : in std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    init_conv_shift       : in std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    enable_conv_shift_out : out std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    -- Override --
    override_we            : in std_logic_vector(NUM_SENSORS_G-1 downto 0);
    override_rd            : out Slv32Array(NUM_SENSORS_G-1 downto 0);
    -- Sequencer Outputs --
    sequencer_busy         : out std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    end_sequence           : out std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    sequencer_out          : out SequencerOutputArray(NUM_SENSORS_G-1 downto 0)
  );
end entity Sequencer;

architecture Behavioral of Sequencer is

  signal sequencer_start_addr        : Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_start             : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_stop              : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_step              : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);

  signal sequencer_unaligned : Slv32Array(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_aligned   : Slv32Array(NUM_SEQUENCERS_G-1 downto 0);

  signal sequencer_override  : Slv32Array(NUM_SENSORS_G-1 downto 0);
  signal sequencer_masked    : Slv32Array(NUM_SENSORS_G-1 downto 0);

begin

  assert (NUM_SEQUENCERS_G = 1 or (NUM_SEQUENCERS_G = NUM_SENSORS_G))
    report "The number of sequencers must be 1 or equal to the number of sensors."
    severity failure;


  sequencers_generate : for i in 0 to NUM_SEQUENCERS_G-1 generate

    -- Sequencer Commmand Generation
    process (clk) is
    begin

      if rising_edge(clk) then
        -- Default state (no trigger)
        sequencer_start(i) <= '0';
        sequencer_stop(i)  <= reg_cmd_stop(i) or sync_cmd_stop;
        sequencer_step(i)  <= reg_cmd_step(i) or sync_cmd_step;
        -- Handle first trigger source
        if (sync_cmd_start = '1') then
          sequencer_start_addr(i) <= "000" & sync_cmd_main_addr & "00";
          sequencer_start(i)      <= '1';
        -- Handle second trigger source
        elsif (reg_cmd_start(i) = '1') then
          sequencer_start_addr(i) <= "000" & regDataWr(4 downto 0) & "00";
          sequencer_start(i)      <= '1';
        end if;
      end if;

    end process;


    sequencer_v4_0 : entity lsst_reb.sequencer_v4_top
      port map (
        clk                      => clk,
        reset                    => rst,
        seq_mem_w_add            => regAddr(9 downto 0),
        seq_mem_data_in          => regDataWr,
        start_sequence           => sequencer_start(i),
        stop_sequence            => sequencer_stop(i),
        step_sequence            => sequencer_step(i),
        program_mem_init_add_in  => sequencer_start_addr(i),
        program_mem_init_add_rbk => sequencer_start_addr_rd(i),
        program_mem_we           => prog_mem_we(i),
        prog_mem_redbk           => prog_mem_rd(i),
        ind_func_mem_we          => ind_func_mem_we(i),
        ind_func_mem_redbk       => ind_func_mem_rd(i),
        ind_rep_mem_we           => ind_rep_mem_we(i),
        ind_rep_mem_redbk        => ind_rep_mem_rd(i),
        ind_sub_add_mem_we       => ind_sub_add_mem_we(i),
        ind_sub_add_mem_redbk    => ind_sub_add_mem_rd(i),
        ind_sub_rep_mem_we       => ind_sub_rep_mem_we(i),
        ind_sub_rep_mem_redbk    => ind_sub_rep_mem_rd(i),
        time_mem_w_en            => time_mem_we(i),
        time_mem_readbk          => time_mem_rd(i),
        out_mem_w_en             => out_mem_we(i),
        out_mem_readbk           => out_mem_rd(i),
        op_code_error_reset      => op_code_error_reset(i),
        op_code_error            => op_code_error(i),
        op_code_error_add        => op_code_error_add(i),
        sequencer_busy           => sequencer_busy(i),
        end_sequence             => end_sequence(i),
        sequencer_out            => sequencer_unaligned(i)
      );


    sequencer_aligner_shifter : entity lsst_reb.sequencer_aligner_shifter_top
      generic map (
        start_adc_bit => 12
      )
      port map (
        clk           => clk,
        reset         => rst,
        shift_on_en   => enable_conv_shift(i),
        shift_on      => regDataWr(i),
        init_shift    => init_conv_shift(i),
        sequencer_in  => sequencer_unaligned(i),
        shift_on_out  => enable_conv_shift_out(i),
        sequencer_out => sequencer_aligned(i)
      );

  end generate sequencers_generate;


  sensors_generate : for s in 0 to NUM_SENSORS_G-1 generate

    sequencer_override_reg : entity surf.RegisterVector
      generic map (
        WIDTH_G => 32
      )
      port map (
        clk   => clk,
        rst   => rst,
        en    => override_we(s),
        sig_i => regDataWr,
        reg_o => sequencer_override(s)
      );

      override_rd(s) <= sequencer_override(s);

    one_sequencer_gen : if NUM_SEQUENCERS_G = 1 generate

      -- Single sequencer masked for each sensor
      sequencer_masked(s)(31 downto 13) <= sequencer_aligned(0)(31 downto 13);
      sequencer_masked(s)(12 downto  0) <= sequencer_aligned(0)(12 downto  0) when sequencer_override(s)(31) = '0' else sequencer_override(s)(12 downto 0);

    end generate one_sequencer_gen;

    multi_sequencer_gen : if NUM_SEQUENCERS_G > 1 generate

      -- Multi sequencer masked for each sensor
      sequencer_masked(s)(31 downto 13) <= sequencer_aligned(s)(31 downto 13);
      sequencer_masked(s)(12 downto  0) <= sequencer_aligned(s)(12 downto  0) when sequencer_override(s)(31) = '0' else sequencer_override(s)(12 downto 0);

    end generate multi_sequencer_gen;

    sequencer_out(s).aspic_r_up    <= sequencer_masked(s)(0);
    sequencer_out(s).aspic_r_down  <= sequencer_masked(s)(1);
    sequencer_out(s).aspic_reset   <= sequencer_masked(s)(2);
    sequencer_out(s).aspic_clamp   <= sequencer_masked(s)(3);
    sequencer_out(s).ser_clk(0)    <= sequencer_masked(s)(4);
    sequencer_out(s).ser_clk(1)    <= sequencer_masked(s)(5);
    sequencer_out(s).ser_clk(2)    <= sequencer_masked(s)(6);
    sequencer_out(s).reset_gate    <= sequencer_masked(s)(7);
    sequencer_out(s).par_clk(0)    <= sequencer_masked(s)(8);
    sequencer_out(s).par_clk(1)    <= sequencer_masked(s)(9);
    sequencer_out(s).par_clk(2)    <= sequencer_masked(s)(10);
    sequencer_out(s).par_clk(3)    <= sequencer_masked(s)(11);
    sequencer_out(s).adc_trigger   <= sequencer_masked(s)(12);
    sequencer_out(s).soi           <= sequencer_masked(s)(13);
    sequencer_out(s).eoi           <= sequencer_masked(s)(14);
    sequencer_out(s).cabac_pulse   <= sequencer_masked(s)(15);
    sequencer_out(s).pattern_reset <= sequencer_masked(s)(16);
    sequencer_out(s).user_bit      <= sequencer_masked(s)(31);

  end generate sensors_generate;

end architecture Behavioral;
