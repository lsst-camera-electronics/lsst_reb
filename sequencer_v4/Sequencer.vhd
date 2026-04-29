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

    -- Register Interface (handshake)
    reg_req     : in  std_logic;                      -- pulse: read or write request
    reg_op      : in  std_logic;                      -- '0'=read, '1'=write
    reg_addr    : in  std_logic_vector(23 downto 0);  -- full address
    reg_wr_data : in  std_logic_vector(31 downto 0);  -- write data
    reg_rd_data : out std_logic_vector(31 downto 0);  -- read data (valid on reg_ack)
    reg_ack     : out std_logic;                      -- pulse: operation complete

    -- Synchronous Command Interface
    sync_cmd_start    : in std_logic;
    sync_cmd_stop     : in std_logic;
    sync_cmd_step     : in std_logic;
    sync_cmd_main_addr : in std_logic_vector(4 downto 0);

    -- Sequencer Outputs
    sequencer_busy : out std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    end_sequence   : out std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    sequencer_out  : out SequencerOutputArray(NUM_SENSORS_G-1 downto 0)
  );
end entity Sequencer;

architecture Behavioral of Sequencer is

  -- Internal sequencer signals
  signal sequencer_start_addr : Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_start      : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_stop       : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_step       : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);

  signal sequencer_unaligned : Slv32Array(NUM_SEQUENCERS_G-1 downto 0);
  signal sequencer_aligned   : Slv32Array(NUM_SEQUENCERS_G-1 downto 0);

  signal sequencer_override : Slv32Array(NUM_SENSORS_G-1 downto 0);
  signal sequencer_masked   : Slv32Array(NUM_SENSORS_G-1 downto 0);

  -- Per-instance memory interface (directly connected to sequencer_v4_top)
  signal seq_mem_w_add   : std_logic_vector(9 downto 0);
  signal seq_mem_data_in : std_logic_vector(31 downto 0);

  signal prog_mem_we_i      : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal prog_mem_rd_i      : Slv32Array(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_func_mem_we_i  : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_func_mem_rd_i  : Slv4Array(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_rep_mem_we_i   : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_rep_mem_rd_i   : Slv24Array(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_sub_add_mem_we_i : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_sub_add_mem_rd_i : Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_sub_rep_mem_we_i : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal ind_sub_rep_mem_rd_i : Slv16Array(NUM_SEQUENCERS_G-1 downto 0);
  signal time_mem_we_i      : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal time_mem_rd_i      : Slv16Array(NUM_SEQUENCERS_G-1 downto 0);
  signal out_mem_we_i       : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal out_mem_rd_i       : Slv32Array(NUM_SEQUENCERS_G-1 downto 0);
  signal op_code_error_i    : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal op_code_error_add_i : Slv10Array(NUM_SEQUENCERS_G-1 downto 0);
  signal op_code_error_reset_i : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);

  signal enable_conv_shift_i  : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal init_conv_shift_i    : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal enable_conv_shift_out_i : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);

  signal start_addr_rd_i      : Slv10Array(NUM_SEQUENCERS_G-1 downto 0);

  -- Register interface state machine
  type reg_state_type is (IDLE, RESPOND);
  signal reg_state : reg_state_type;

  -- Registered request fields
  signal req_op       : std_logic;
  signal req_addr     : std_logic_vector(23 downto 0);
  signal req_wr_data  : std_logic_vector(31 downto 0);
  signal req_instance : integer range 0 to 3;
  signal req_upper    : std_logic_vector(7 downto 0);

  -- Register-driven command pulses (active for one cycle after request registered)
  signal reg_cmd_start_i : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal reg_cmd_stop_i  : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
  signal reg_cmd_step_i  : std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);

  -- Override write-enable
  signal override_we_i : std_logic_vector(NUM_SENSORS_G-1 downto 0);

begin

  assert (NUM_SEQUENCERS_G = 1 or (NUM_SEQUENCERS_G = NUM_SENSORS_G))
    report "The number of sequencers must be 1 or equal to the number of sensors."
    severity failure;

  ---------------------------------------------------------------------------
  -- Register Interface Process
  --
  -- Cycle 1 (IDLE, reg_req pulse): Register address/data/op, drive memory
  --   address and WE (for writes), transition to RESPOND.
  -- Cycle 2 (RESPOND): Capture memory read data (now stable from distributed
  --   RAM addressed in cycle 1), drive reg_rd_data and reg_ack, return to IDLE.
  ---------------------------------------------------------------------------
  reg_interface_proc : process (clk) is
    variable v_instance : integer range 0 to 3;
    variable v_upper    : std_logic_vector(7 downto 0);
    variable v_sensor   : integer range 0 to 3;
  begin
    if rising_edge(clk) then
      -- Defaults: all single-cycle pulses deassert
      reg_ack            <= '0';
      reg_rd_data        <= (others => '0');
      prog_mem_we_i      <= (others => '0');
      ind_func_mem_we_i  <= (others => '0');
      ind_rep_mem_we_i   <= (others => '0');
      ind_sub_add_mem_we_i <= (others => '0');
      ind_sub_rep_mem_we_i <= (others => '0');
      time_mem_we_i      <= (others => '0');
      out_mem_we_i       <= (others => '0');
      op_code_error_reset_i <= (others => '0');
      enable_conv_shift_i <= (others => '0');
      init_conv_shift_i   <= (others => '0');

      reg_cmd_start_i    <= (others => '0');
      reg_cmd_stop_i     <= (others => '0');
      reg_cmd_step_i     <= (others => '0');
      override_we_i      <= (others => '0');

      if rst = '1' then
        reg_state <= IDLE;
      else
        case reg_state is

          when IDLE =>
            if reg_req = '1' then
              -- Register inputs
              req_op      <= reg_op;
              req_addr    <= reg_addr;
              req_wr_data <= reg_wr_data;
              req_upper   <= reg_addr(23 downto 16);
              req_instance <= to_integer(unsigned(reg_addr(13 downto 12)));

              -- Drive memory address and write data to all instances
              -- (only the targeted instance gets WE)
              seq_mem_w_add   <= reg_addr(9 downto 0);
              seq_mem_data_in <= reg_wr_data;

              v_instance := to_integer(unsigned(reg_addr(13 downto 12)));
              v_upper    := reg_addr(23 downto 16);

              if reg_op = '1' then
                -- WRITE: assert appropriate WE this cycle
                if v_instance < NUM_SEQUENCERS_G then
                  case v_upper is
                    when x"10" => out_mem_we_i(v_instance)       <= '1';
                    when x"20" => time_mem_we_i(v_instance)      <= '1';
                    when x"30" => prog_mem_we_i(v_instance)      <= '1';
                    when x"31" => reg_cmd_step_i(v_instance)     <= '1';
                    when x"32" => reg_cmd_stop_i(v_instance)     <= '1';
                    when x"33" =>
                      if reg_addr(0) = '0' then
                        enable_conv_shift_i(v_instance) <= '1';
                      else
                        init_conv_shift_i(v_instance) <= '1';
                      end if;
                    when x"34" =>
                      reg_cmd_start_i(v_instance) <= '1';
                    when x"35" => ind_func_mem_we_i(v_instance)    <= '1';
                    when x"36" => ind_rep_mem_we_i(v_instance)     <= '1';
                    when x"37" => ind_sub_add_mem_we_i(v_instance) <= '1';
                    when x"38" => ind_sub_rep_mem_we_i(v_instance) <= '1';
                    when x"39" =>
                      if reg_addr(0) = '1' then
                        op_code_error_reset_i(v_instance) <= '1';
                      end if;
                    when others => null;
                  end case;
                end if;

                -- Override writes (sensor-indexed, address x"41")
                if v_upper = x"41" then
                  v_sensor := to_integer(unsigned(reg_addr(1 downto 0)));
                  if v_sensor < NUM_SENSORS_G then
                    override_we_i(v_sensor) <= '1';
                  end if;
                end if;


              end if;

              reg_state <= RESPOND;
            end if;

          when RESPOND =>
            -- Read data is now stable (address was driven in previous cycle)
            reg_ack <= '1';

            if req_op = '0' then
              -- READ: mux the appropriate readback
              if req_instance < NUM_SEQUENCERS_G then
                case req_upper is
                  when x"10" => reg_rd_data <= out_mem_rd_i(req_instance);
                  when x"20" => reg_rd_data(15 downto 0) <= time_mem_rd_i(req_instance);
                  when x"30" => reg_rd_data <= prog_mem_rd_i(req_instance);
                  when x"33" => reg_rd_data(0) <= enable_conv_shift_out_i(req_instance);
                  when x"34" => reg_rd_data(9 downto 0) <= start_addr_rd_i(req_instance);
                  when x"35" => reg_rd_data(3 downto 0) <= ind_func_mem_rd_i(req_instance);
                  when x"36" => reg_rd_data(23 downto 0) <= ind_rep_mem_rd_i(req_instance);
                  when x"37" => reg_rd_data(9 downto 0) <= ind_sub_add_mem_rd_i(req_instance);
                  when x"38" => reg_rd_data(15 downto 0) <= ind_sub_rep_mem_rd_i(req_instance);
                  when x"39" =>
                    reg_rd_data(0) <= op_code_error_i(req_instance);
                    reg_rd_data(10 downto 1) <= op_code_error_add_i(req_instance);
                  when others => null;
                end case;
              end if;

              -- Override reads (sensor-indexed)
              if req_upper = x"41" then
                v_sensor := to_integer(unsigned(req_addr(1 downto 0)));
                if v_sensor < NUM_SENSORS_G then
                  reg_rd_data <= sequencer_override(v_sensor);
                end if;
              end if;
            end if;

            reg_state <= IDLE;

        end case;
      end if;
    end if;
  end process reg_interface_proc;

  ---------------------------------------------------------------------------
  -- Sequencer Instance Generation
  ---------------------------------------------------------------------------
  sequencers_generate : for i in 0 to NUM_SEQUENCERS_G-1 generate

    -- Sequencer Command Generation
    process (clk) is
    begin
      if rising_edge(clk) then
        -- Default state (no trigger)
        sequencer_start(i) <= '0';
        sequencer_stop(i)  <= reg_cmd_stop_i(i) or sync_cmd_stop;
        sequencer_step(i)  <= reg_cmd_step_i(i) or sync_cmd_step;
        -- Handle first trigger source
        if (sync_cmd_start = '1') then
          sequencer_start_addr(i) <= "000" & sync_cmd_main_addr & "00";
          sequencer_start(i)      <= '1';
        -- Handle second trigger source (register-driven)
        elsif (reg_cmd_start_i(i) = '1') then
          sequencer_start_addr(i) <= "000" & req_wr_data(4 downto 0) & "00";
          sequencer_start(i)      <= '1';
        end if;
      end if;
    end process;


    sequencer_v4_0 : entity lsst_reb.sequencer_v4_top
      port map (
        clk                      => clk,
        reset                    => rst,
        seq_mem_w_add            => seq_mem_w_add,
        seq_mem_data_in          => seq_mem_data_in,
        start_sequence           => sequencer_start(i),
        stop_sequence            => sequencer_stop(i),
        step_sequence            => sequencer_step(i),
        program_mem_init_add_in  => sequencer_start_addr(i),
        program_mem_init_add_rbk => start_addr_rd_i(i),
        program_mem_we           => prog_mem_we_i(i),
        prog_mem_redbk           => prog_mem_rd_i(i),
        ind_func_mem_we          => ind_func_mem_we_i(i),
        ind_func_mem_redbk       => ind_func_mem_rd_i(i),
        ind_rep_mem_we           => ind_rep_mem_we_i(i),
        ind_rep_mem_redbk        => ind_rep_mem_rd_i(i),
        ind_sub_add_mem_we       => ind_sub_add_mem_we_i(i),
        ind_sub_add_mem_redbk    => ind_sub_add_mem_rd_i(i),
        ind_sub_rep_mem_we       => ind_sub_rep_mem_we_i(i),
        ind_sub_rep_mem_redbk    => ind_sub_rep_mem_rd_i(i),
        time_mem_w_en            => time_mem_we_i(i),
        time_mem_readbk          => time_mem_rd_i(i),
        out_mem_w_en             => out_mem_we_i(i),
        out_mem_readbk           => out_mem_rd_i(i),
        op_code_error_reset      => op_code_error_reset_i(i),
        op_code_error            => op_code_error_i(i),
        op_code_error_add        => op_code_error_add_i(i),
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
        shift_on_en   => enable_conv_shift_i(i),
        shift_on      => seq_mem_data_in(i),
        init_shift    => init_conv_shift_i(i),
        sequencer_in  => sequencer_unaligned(i),
        shift_on_out  => enable_conv_shift_out_i(i),
        sequencer_out => sequencer_aligned(i)
      );

  end generate sequencers_generate;


  ---------------------------------------------------------------------------
  -- Sensor Output Generation (override masking)
  ---------------------------------------------------------------------------
  sensors_generate : for s in 0 to NUM_SENSORS_G-1 generate

    sequencer_override_reg : entity surf.RegisterVector
      generic map (
        WIDTH_G => 32
      )
      port map (
        clk   => clk,
        rst   => rst,
        en    => override_we_i(s),
        sig_i => seq_mem_data_in,
        reg_o => sequencer_override(s)
      );

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
