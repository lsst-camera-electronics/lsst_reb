# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_multi_read_top_greb.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_multi_read_greb_fsm.vhd"
