# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
# loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/dual_ads1118_top_package.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/dual_ads1118_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/dual_ads1118_controller_fsm.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SPI_read_write_noss.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
