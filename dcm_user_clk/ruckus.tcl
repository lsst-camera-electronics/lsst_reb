# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadIpCore -path "$::DIR_PATH/ip/dcm_user_clk.xci"
