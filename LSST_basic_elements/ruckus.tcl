# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/basic_elements.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ff_ce.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ff_ce_pres.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_counter_comparator_ce_init.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_counter_rst_load_ce.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_mux_bus_4_1_clk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_reg_ce_init.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_reg_ce_init_1.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/generic_single_port_ram.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
