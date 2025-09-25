# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SPI_read_write_noss.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SPI_write_BusyatStart.vhd"
