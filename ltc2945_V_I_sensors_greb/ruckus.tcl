# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_multi_read_top_greb.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_multi_read_greb_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_core/i2c_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_core/i2c_master.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_core/i2c_handler_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_core/mux_bus_2_8_bit_clk.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
