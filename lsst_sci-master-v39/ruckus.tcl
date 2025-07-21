# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -dir "$::DIR_PATH/rtl"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
