# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/dual_ad53xx_DAC_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/dual_ad53xx_DAC_protection_top.vhd"
