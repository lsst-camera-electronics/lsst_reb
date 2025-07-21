# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/onewire_iface.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/clk_div.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/onewire_master.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/shreg.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/jcounter.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/bitreg.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/bytereg.vhd"
loadSource -path lsst_reb -path "$::DIR_PATH/rtl/crcreg.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
