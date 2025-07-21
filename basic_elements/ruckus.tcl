# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/basic_elements_pkg.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ff_ce.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ff_ce_pres.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_counter_comparator_ce_init.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_counter_rst_load_ce.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_mux_bus_4_1_clk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_reg_ce_init.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_reg_ce_init_1.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_single_port_ram.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/demux_1_2_clk_def_1.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/mux_2_1_bus_noclk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/mux_4_1_clk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/mux_bus_2_8_bit_clk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/demux_1_4_clk_pres.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/demux_1_4_clk.vhd"
