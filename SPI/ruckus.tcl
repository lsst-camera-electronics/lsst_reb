# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ad56xx_DAC_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/ad53xx_DAC_protection_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SPI_write.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SPI_read_write_noss.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SPI_write_BusyatStart.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
