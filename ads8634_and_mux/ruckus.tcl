# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ads8634_and_mux_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ads8634_controller_fsm.vhd"
