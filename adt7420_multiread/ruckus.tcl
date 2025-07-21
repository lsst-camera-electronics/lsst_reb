# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/multi_read_2/adt7420_temp_multiread_2_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/multi_read_2/adt7420_temp_multiread_2_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/multi_read_4/adt7420_temp_multiread_4_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/multi_read_4/adt7420_temp_multiread4_fsm.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
