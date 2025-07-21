# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/multiboot_fsm_read.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/multiboot_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SpiFlashProgrammer_multiboot.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/SpiSerDes.vhd"

loadIpCore -path "$::DIR_PATH/ip/bitfile_fifo_in.xci"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
