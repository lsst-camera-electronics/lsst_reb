# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/aspic_3_spi_link_top_mux.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/aspic_3_spi_link_programmer.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
