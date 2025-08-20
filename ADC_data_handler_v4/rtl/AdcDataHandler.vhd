library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library surf;
use surf.StdRtlPkg.all;

library lsst_sci;
use lsst_sci.LsstSciPackage.all;

library lsst_reb;
use lsst_reb.SequencerPkg.all;

entity AdcDataHandler is
  generic (
    NUM_SEQUENCERS_G : integer range 1 to 3 := 1;
    NUM_SENSORS_G    : integer range 1 to 3
  );
  port (
    rst               : in std_logic;
    clk               : in std_logic;
    regDataWr         : in std_logic_vector(31 downto 0);
    ccd_oe_we         : in std_logic;
    ccd_oe_rd         : out std_logic_vector(NUM_SENSORS_G-1 downto 0);
    testmode_rst      : in std_logic_vector(NUM_SENSORS_G-1 downto 0);
    sequencer_outputs : in SequencerOutputArray(NUM_SENSORS_G-1 downto 0);
    end_sequence      : in std_logic_vector(NUM_SEQUENCERS_G-1 downto 0);
    trigger           : in std_logic_vector(NUM_SENSORS_G-1 downto 0);
    en_test_mode      : in std_logic;
    test_mode_enb_out : out std_logic_vector(NUM_SENSORS_G-1 downto 0);
    sci_data          : out LsstSciImageDataArray(NUM_SENSORS_G-1 downto 0);
    adc_data          : in  Slv16Array(NUM_SENSORS_G-1 downto 0);
    adc_cnv           : out std_logic_vector(NUM_SENSORS_G-1 downto 0);
    adc_sck           : out std_logic_vector(NUM_SENSORS_G-1 downto 0)
  );
end entity AdcDataHandler;

architecture behavioral of AdcDataHandler is

  signal ccd_oe : std_logic_vector(NUM_SENSORS_G-1 downto 0);

  signal sci_data_int : LsstSciImageDataArray(NUM_SENSORS_G-1 downto 0);
  signal sot_int      : std_logic_vector(NUM_SENSORS_G-1 downto 0);
  signal eot_int      : std_logic_vector(NUM_SENSORS_G-1 downto 0);
  signal we_int       : std_logic_vector(NUM_SENSORS_G-1 downto 0);
  signal data_int     : Slv18Array(NUM_SENSORS_G-1 downto 0);

  signal sensor_mask  : std_logic_vector(2 downto 0);

begin

  assert (NUM_SEQUENCERS_G = 1 or (NUM_SEQUENCERS_G = NUM_SENSORS_G))
    report "The number of sequencers must be 1 or equal to the number of sensors."
    severity failure;

  with NUM_SENSORS_G select
    sensor_mask <= "001" when 1,
                   "011" when 2,
                   "111" when 3,
                   "000" when others;

  one_sequencer_gen : if NUM_SEQUENCERS_G = 1 generate

    Image_data_handler_0 : entity lsst_reb.ADC_data_handler_v4
      port map (
        reset             => rst,
        clk               => clk,
        testmode_rst      => testmode_rst(0),
        testmode_col      => sequencer_outputs(0).par_clk(0),
        start_of_img      => sequencer_outputs(0).soi,
        end_of_img        => sequencer_outputs(0).eoi,
        end_sequence      => end_sequence(0),
        trigger           => trigger(0),
        en_test_mode      => en_test_mode,
        test_mode_in      => regDataWr(0),
        en_load_ccd_sel   => '1',
        ccd_sel_in        => sensor_mask,
        ccd_sel_out       => open,
        SOT               => sot_int(0),
        EOT               => eot_int(0),
        write_enable      => we_int(0),
        data_out          => data_int(0),
        test_mode_enb_out => test_mode_enb_out(0),
        adc_data_ccd_1    => adc_data(0),
        adc_cnv_ccd_1     => adc_cnv(0),
        adc_sck_ccd_1     => adc_sck(0),
        adc_data_ccd_2    => adc_data(1),
        adc_cnv_ccd_2     => adc_cnv(1),
        adc_sck_ccd_2     => adc_sck(1),
        adc_data_ccd_3    => adc_data(2),
        adc_cnv_ccd_3     => adc_cnv(2),
        adc_sck_ccd_3     => adc_sck(2)
      );


  end generate one_sequencer_gen;


  two_sequencer_gen : if NUM_SEQUENCERS_G = 2 generate

    assert(NUM_SENSORS_G = 2);

    Image_data_handler_ccd_0 : entity lsst_reb.ADC_data_handler_v4
      port map (
        reset             => rst,
        clk               => clk,
        testmode_rst      => testmode_rst(0),
        testmode_col      => sequencer_outputs(0).par_clk(0),
        start_of_img      => sequencer_outputs(0).soi,
        end_of_img        => sequencer_outputs(0).eoi,
        end_sequence      => end_sequence(0),
        trigger           => trigger(0),
        en_test_mode      => en_test_mode,
        test_mode_in      => regDataWr(0),
        en_load_ccd_sel   => '1',
        ccd_sel_in        => "001",
        ccd_sel_out       => open,
        SOT               => sot_int(0),
        EOT               => eot_int(0),
        write_enable      => we_int(0),
        data_out          => data_int(0),
        test_mode_enb_out => test_mode_enb_out(0),
        adc_data_ccd_1    => adc_data(0),
        adc_cnv_ccd_1     => adc_cnv(0),
        adc_sck_ccd_1     => adc_sck(0)
      );

    Image_data_handler_ccd_1 : entity lsst_reb.ADC_data_handler_v4
      port map (
        reset             => rst,
        clk               => clk,
        testmode_rst      => testmode_rst(1),
        testmode_col      => sequencer_outputs(1).par_clk(0),
        start_of_img      => sequencer_outputs(1).soi,
        end_of_img        => sequencer_outputs(1).eoi,
        end_sequence      => end_sequence(1),
        trigger           => trigger(1),
        en_test_mode      => en_test_mode,
        test_mode_in      => regDataWr(1),
        en_load_ccd_sel   => '1',
        ccd_sel_in        => "010",
        ccd_sel_out       => open,
        SOT               => sot_int(1),
        EOT               => eot_int(1),
        write_enable      => we_int(1),
        data_out          => data_int(1),
        test_mode_enb_out => test_mode_enb_out(1),
        adc_data_ccd_2    => adc_data(1),
        adc_cnv_ccd_2     => adc_cnv(1),
        adc_sck_ccd_2     => adc_sck(1)
      );

  end generate two_sequencer_gen;


  three_sequencer_gen : if NUM_SEQUENCERS_G = 3 generate

    assert(NUM_SENSORS_G = 3);

    Image_data_handler_0 : entity lsst_reb.ADC_data_handler_v4
      port map (
        reset             => rst,
        clk               => clk,
        testmode_rst      => testmode_rst(0),
        testmode_col      => sequencer_outputs(0).par_clk(0),
        start_of_img      => sequencer_outputs(0).soi,
        end_of_img        => sequencer_outputs(0).eoi,
        end_sequence      => end_sequence(0),
        trigger           => trigger(0),
        en_test_mode      => en_test_mode,
        test_mode_in      => regDataWr(0),
        en_load_ccd_sel   => '1',
        ccd_sel_in        => "001",
        ccd_sel_out       => open,
        SOT               => sot_int(0),
        EOT               => eot_int(0),
        write_enable      => we_int(0),
        data_out          => data_int(0),
        test_mode_enb_out => test_mode_enb_out(0),
        adc_data_ccd_1    => adc_data(0),
        adc_cnv_ccd_1     => adc_cnv(0),
        adc_sck_ccd_1     => adc_sck(0)
      );

    Image_data_handler_1 : entity lsst_reb.ADC_data_handler_v4
      port map (
        reset             => rst,
        clk               => clk,
        testmode_rst      => testmode_rst(1),
        testmode_col      => sequencer_outputs(1).par_clk(0),
        start_of_img      => sequencer_outputs(1).soi,
        end_of_img        => sequencer_outputs(1).eoi,
        end_sequence      => end_sequence(1),
        trigger           => trigger(1),
        en_test_mode      => en_test_mode,
        test_mode_in      => regDataWr(1),
        en_load_ccd_sel   => '1',
        ccd_sel_in        => "010",
        ccd_sel_out       => open,
        SOT               => sot_int(1),
        EOT               => eot_int(1),
        write_enable      => we_int(1),
        data_out          => data_int(1),
        test_mode_enb_out => test_mode_enb_out(1),
        adc_data_ccd_2    => adc_data(1),
        adc_cnv_ccd_2     => adc_cnv(1),
        adc_sck_ccd_2     => adc_sck(1)
      );

    Image_data_handler_2 : entity lsst_reb.ADC_data_handler_v4
      port map (
        reset             => rst,
        clk               => clk,
        testmode_rst      => testmode_rst(2),
        testmode_col      => sequencer_outputs(2).par_clk(0),
        start_of_img      => sequencer_outputs(2).soi,
        end_of_img        => sequencer_outputs(2).eoi,
        end_sequence      => end_sequence(2),
        trigger           => trigger(2),
        en_test_mode      => en_test_mode,
        test_mode_in      => regDataWr(2),
        en_load_ccd_sel   => '1',
        ccd_sel_in        => "100",
        ccd_sel_out       => open,
        SOT               => sot_int(2),
        EOT               => eot_int(2),
        write_enable      => we_int(2),
        data_out          => data_int(2),
        test_mode_enb_out => test_mode_enb_out(2),
        adc_data_ccd_3    => adc_data(2),
        adc_cnv_ccd_3     => adc_cnv(2),
        adc_sck_ccd_3     => adc_sck(2)
      );


  end generate three_sequencer_gen;

  output_enable_reg : entity surf.RegisterVector
    generic map (
      WIDTH_G => NUM_SENSORS_G,
      INIT_G => slvOne(NUM_SENSORS_G)
    )
    port map (
      clk => clk,
      rst => rst,
      en  => ccd_oe_we,
      sig_i => regDataWr(NUM_SENSORS_G-1 downto 0),
      reg_o => ccd_oe
    );

  sequencer_loop : for i in 0 to NUM_SENSORS_G-1 generate

    sci_data_int(i).wrEn <= ccd_oe(i) and we_int(i);
    sci_data_int(i).sot  <= sot_int(i);
    sci_data_int(i).eot  <= eot_int(i);
    sci_data_int(i).data <= data_int(i);

  end generate sequencer_loop;

  -- Set unused outputs to '0' when NUM_SENSORS_G > NUM_SEQUENCERS_G
  unused_outputs_generate : if NUM_SENSORS_G > NUM_SEQUENCERS_G generate
    unused_range_generate : for i in NUM_SEQUENCERS_G to NUM_SENSORS_G-1 generate
        we_int(i)   <= '0';
        sot_int(i)  <= '0';
        eot_int(i)  <= '0';
        data_int(i) <= (others => '0');
    end generate unused_range_generate;
  end generate unused_outputs_generate;

  ccd_oe_rd <= ccd_oe;
  sci_data <= sci_data_int;

end architecture behavioral;