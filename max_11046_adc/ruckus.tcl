# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_ctrl_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_multiple_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_multi_ctrl_fsm.vhd"
