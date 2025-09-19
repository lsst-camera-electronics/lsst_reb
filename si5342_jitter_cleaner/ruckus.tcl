# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/si5342_jitter_cleaner_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/si5342_jitter_cleaner_fsm_rom.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/si5342_reg_write_fsm.vhd"
