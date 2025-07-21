# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/sync_cmd_decoder_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/sync_cmd_decoder.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/pulse_stretcher.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/programmable_delay.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
