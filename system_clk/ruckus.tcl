# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
# loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SystemClockPkg.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SystemClock.vhd"

