# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_multi_read_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_multi_read_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_single_read_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_single_read_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ltc2945_add_package.vhd"
