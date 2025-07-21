# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib lsst_reb -path "$::DIR_PATH/sequencer_v3_package.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/sequencer_v4_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/func_handler_v4/sequencer_parameter_extractor_top_v4.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/func_handler_v4/parameter_extractor_fsm_v3.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/function_v3/function_v3_top.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/function_v3/function_fsm_v3.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/function_v3/function_executor_v3.vhd"
loadSource -lib lsst_reb -path "$::DIR_PATH/function_v3/function_v3.vhd"

loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_ip.xci"
loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_4_4.xci"
loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_24_4.xci"
loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_10_4.xci"
loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_16_4.xci"
loadIpCore -path "$::DIR_PATH/ip/seq_param_fifo_v3.xci"
loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_8_16.xci"
loadIpCore -path "$::DIR_PATH/ip/dual_port_ram_8_32.xci"

# Load Simulation
#loadSource -lib lsst_reb -sim_only -dir "$::DIR_PATH/TB"
