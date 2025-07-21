# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/Base_Register_Set_package_wreb_v4.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/base_reg_set_top.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
