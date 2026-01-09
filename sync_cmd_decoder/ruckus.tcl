# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/sync_cmd_decoder_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/sync_cmd_decoder.vhd"
