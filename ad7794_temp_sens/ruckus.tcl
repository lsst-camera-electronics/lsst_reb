# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ad7794_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ad7794_programmer.vhd"
