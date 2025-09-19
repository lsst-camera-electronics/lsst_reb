# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_top_slow.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_master.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/i2c_handler_fsm.vhd"
