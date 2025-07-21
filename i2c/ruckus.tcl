# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_master.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_handler_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/mux_4_1_clk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/mux_bus_2_8_bit_clk.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/demux_1_4_clk_pres.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/demux_1_4_clk.vhd"
