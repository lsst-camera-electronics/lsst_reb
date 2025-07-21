# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_multiple_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_multi_ctrl_fsm.vhd"
# loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/max_11046_top_package.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/demux_1_4_clk_pres.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/rtl/mux_4_1_clk.vhd"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
