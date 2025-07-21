# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/onewire_master.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
