library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library surf;

library lsst_reb;

entity sequencer_parameter_extractor_top_v4 is
  port (
    clk             : in    std_logic;
    reset           : in    std_logic;
    start_sequence  : in    std_logic;
    program_mem_we  : in    std_logic;
    seq_mem_w_add   : in    std_logic_vector(9 downto 0);
    seq_mem_data_in : in    std_logic_vector(31 downto 0);

    program_mem_init_add_in  : in    std_logic_vector(9 downto 0);
    program_mem_init_add_rbk : out   std_logic_vector(9 downto 0);

    ind_func_mem_we    : in    std_logic;
    ind_func_mem_redbk : out   std_logic_vector(3 downto 0);

    ind_rep_mem_we    : in    std_logic;
    ind_rep_mem_redbk : out   std_logic_vector(23 downto 0);

    ind_sub_add_mem_we    : in    std_logic;
    ind_sub_add_mem_redbk : out   std_logic_vector(9 downto 0);

    ind_sub_rep_mem_we    : in    std_logic;
    ind_sub_rep_mem_redbk : out   std_logic_vector(15 downto 0);

    fifo_param_re : in    std_logic;

    op_code_error_reset : in    std_logic;
    op_code_error       : out   std_logic;
    op_code_error_add   : out   std_logic_vector(9 downto 0);

    prog_mem_redbk   : out   std_logic_vector(31 downto 0);
    fifo_param_empty : out   std_logic;
    fifo_param_out   : out   std_logic_vector(31 downto 0)
  );
end entity sequencer_parameter_extractor_top_v4;

architecture Behavioral of sequencer_parameter_extractor_top_v4 is

  signal fifo_param_full          : std_logic;
  signal prog_mem_data_out        : std_logic_vector(31 downto 0);
  signal data_from_stack          : std_logic_vector(31 downto 0);
  signal fifo_param_we            : std_logic;
  signal fifo_param_we_reg        : std_logic;
  signal sub_stack_w_en           : std_logic;
  signal ind_sub_rep_flag         : std_logic;
  signal sub_stack_add            : std_logic_vector(3 downto 0);
  signal program_mem_rd_add       : std_logic_vector(9 downto 0);
  signal stack_data_in            : std_logic_vector(31 downto 0);
  signal sub_rep_cnt              : std_logic_vector(15 downto 0);
  signal program_mem_init_add_int : std_logic_vector(9 downto 0);
  signal ind_func_mem_data_out    : std_logic_vector(3 downto 0);
  signal ind_rep_mem_data_out     : std_logic_vector(23 downto 0);
  signal ind_sub_add_mem_data_out : std_logic_vector(9 downto 0);
  signal ind_sub_rep_mem_data_out : std_logic_vector(15 downto 0);
  signal fifo_in_mux_sel          : std_logic_vector(1 downto 0);
  signal prog_mem_rep_ind         : std_logic_vector(31 downto 0);
  signal prog_mem_func_ind        : std_logic_vector(31 downto 0);
  signal prog_mem_all_ind         : std_logic_vector(31 downto 0);
  signal fifo_in_bus              : std_logic_vector(31 downto 0);

  -- attribute MARK_DEBUG : string;
  -- attribute MARK_DEBUG of seq_mem_w_add       : signal is "TRUE";
  -- attribute MARK_DEBUG of seq_mem_data_in     : signal is "TRUE";
  -- attribute MARK_DEBUG of program_mem_rd_add  : signal is "TRUE";
  -- attribute MARK_DEBUG of program_mem_we      : signal is "TRUE";
  -- attribute MARK_DEBUG of prog_mem_redbk      : signal is "TRUE";
  -- attribute MARK_DEBUG of prog_mem_data_out   : signal is "TRUE";

begin

  parameter_extractor_fsm_v3_0 : entity lsst_reb.parameter_extractor_fsm_v3
    port map (
      clk                      => clk,
      reset                    => reset,
      start_sequence           => start_sequence,
      fifo_param_full          => fifo_param_full,
      op_code_error_reset      => op_code_error_reset,
      program_mem_data         => prog_mem_data_out,
      data_from_stack          => data_from_stack,
      ind_rep_mem_data_out     => ind_rep_mem_data_out,
      ind_sub_add_mem_data_out => ind_sub_add_mem_data_out,
      ind_sub_rep_mem_data_out => ind_sub_rep_mem_data_out,
      op_code_error            => op_code_error,
      program_mem_init_add     => program_mem_init_add_int,
      fifo_param_write         => fifo_param_we,
      sub_stack_w_en           => sub_stack_w_en,
      ind_sub_rep_flag         => ind_sub_rep_flag,
      fifo_mux_sel             => fifo_in_mux_sel,
      sub_stack_add            => sub_stack_add,
      sub_rep_cnt              => sub_rep_cnt,
      program_mem_add          => program_mem_rd_add
    );

  function_stack : entity lsst_reb.generic_single_port_ram
    generic map (
      data_width => 32,
      add_width  => 4
    )
    port map (
      clk          => clk,
      ram_wr_en    => sub_stack_w_en,
      ram_add      => sub_stack_add,
      ram_data_in  => stack_data_in,
      ram_data_out => data_from_stack
    );

  program_memory : entity surf.DualPortRam
    generic map (
      MEMORY_TYPE_G => "distributed",
      REG_EN_G      => false,
      DOA_REG_G     => false,
      DOB_REG_G     => false,
      MODE_G        => "no-change",
      DATA_WIDTH_G  => 32,
      ADDR_WIDTH_G  => 10
    )
    port map (
      addra => seq_mem_w_add,
      dina  => seq_mem_data_in,
      addrb => program_mem_rd_add,
      clka  => clk,
      clkb  => clk,
      wea   => program_mem_we,
      douta => prog_mem_redbk,
      doutb => prog_mem_data_out
    );

  indirect_func_mem : entity surf.DualPortRam
    generic map (
      MEMORY_TYPE_G => "distributed",
      REG_EN_G      => false,
      DOA_REG_G     => false,
      DOB_REG_G     => false,
      MODE_G        => "no-change",
      DATA_WIDTH_G  => 4,
      ADDR_WIDTH_G  => 4
    )
    port map (
      addra => seq_mem_w_add(3 downto 0),
      dina  => seq_mem_data_in(3 downto 0),
      addrb => prog_mem_data_out(27 downto 24),
      clka  => clk,
      clkb  => clk,
      wea   => ind_func_mem_we,
      douta => ind_func_mem_redbk,
      doutb => ind_func_mem_data_out
    );

  indirect_rep_mem : entity surf.DualPortRam
    generic map (
      MEMORY_TYPE_G => "distributed",
      REG_EN_G      => false,
      DOA_REG_G     => false,
      DOB_REG_G     => false,
      MODE_G        => "no-change",
      DATA_WIDTH_G  => 24,
      ADDR_WIDTH_G  => 4
    )
    port map (
      addra => seq_mem_w_add(3 downto 0),
      dina  => seq_mem_data_in(23 downto 0),
      addrb => prog_mem_data_out(3 downto 0),
      clka  => clk,
      clkb  => clk,
      wea   => ind_rep_mem_we,
      douta => ind_rep_mem_redbk,
      doutb => ind_rep_mem_data_out
    );

  generic_mux_bus_4_1_clk_0 : entity lsst_reb.generic_mux_bus_4_1_clk
    generic map (
      width => 32
    )
    port map (
      reset    => reset,
      clk      => clk,
      selector => fifo_in_mux_sel,
      bus_in_0 => prog_mem_data_out,
      bus_in_1 => prog_mem_func_ind,
      bus_in_2 => prog_mem_rep_ind,
      bus_in_3 => prog_mem_all_ind,
      bus_out  => fifo_in_bus
    );

  fifo_param_we_reg <= fifo_param_we;

  indirect_sub_add_mem : entity surf.DualPortRam
    generic map (
      MEMORY_TYPE_G => "distributed",
      REG_EN_G      => false,
      DOA_REG_G     => false,
      DOB_REG_G     => false,
      MODE_G        => "no-change",
      DATA_WIDTH_G  => 10,
      ADDR_WIDTH_G  => 4
    )
    port map (
      addra => seq_mem_w_add(3 downto 0),
      dina  => seq_mem_data_in(9 downto 0),
      addrb => prog_mem_data_out(19 downto 16),
      clka  => clk,
      clkb  => clk,
      wea   => ind_sub_add_mem_we,
      douta => ind_sub_add_mem_redbk,
      doutb => ind_sub_add_mem_data_out
    );

  indirect_sub_rep_mem : entity surf.DualPortRam
    generic map (
      MEMORY_TYPE_G => "distributed",
      REG_EN_G      => false,
      DOA_REG_G     => false,
      DOB_REG_G     => false,
      MODE_G        => "no-change",
      DATA_WIDTH_G  => 16,
      ADDR_WIDTH_G  => 4
    )
    port map (
      addra => seq_mem_w_add(3 downto 0),
      dina  => seq_mem_data_in(15 downto 0),
      addrb => prog_mem_data_out(3 downto 0),
      clka  => clk,
      clkb  => clk,
      wea   => ind_sub_rep_mem_we,
      douta => ind_sub_rep_mem_redbk,
      doutb => ind_sub_rep_mem_data_out
    );

  seq_param_fifo_v3_0 : entity surf.FifoSync
    generic map (
      DATA_WIDTH_G => 32,
      ADDR_WIDTH_G => 10
    )
    port map (
      clk   => clk,
      rst   => reset,
      din   => fifo_in_bus,
      wr_en => fifo_param_we_reg,
      rd_en => fifo_param_re,
      dout  => fifo_param_out,
      full  => fifo_param_full,
      empty => fifo_param_empty
    );

  program_mem_init_add_int <= program_mem_init_add_in;
  program_mem_init_add_rbk <= program_mem_init_add_int;

  stack_data_in <= '0' & ind_sub_rep_flag & program_mem_rd_add & x"0" & sub_rep_cnt;

  prog_mem_rep_ind  <= prog_mem_data_out(31 downto 24) & ind_rep_mem_data_out;
  prog_mem_func_ind <= prog_mem_data_out(31 downto 28) & ind_func_mem_data_out & prog_mem_data_out(23 downto 0);
  prog_mem_all_ind  <= prog_mem_data_out(31 downto 28) & ind_func_mem_data_out & ind_rep_mem_data_out;

  op_code_error_add <= program_mem_rd_add;

end architecture Behavioral;

