# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ADC_data_handler_v4.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ADC_data_handler_fsm_v4.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/readadcs_v5.vhd"
