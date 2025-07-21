# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Check for submodule tagging
if { [info exists ::env(OVERRIDE_SUBMODULE_LOCKS)] != 1 || $::env(OVERRIDE_SUBMODULE_LOCKS) == 0 } {
   if { [SubmoduleCheck {ruckus} {4.9.0} ] < 0 } {exit -1}
} else {
   puts "\n\n*********************************************************"
   puts "OVERRIDE_SUBMODULE_LOCKS != 0"
   puts "Ignoring the submodule locks in surf/ruckus.tcl"
   puts "*********************************************************\n\n"
}

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/basic_elements"
loadRuckusTcl "$::DIR_PATH/ad7794_temp_sens"
loadRuckusTcl "$::DIR_PATH/ADC_data_handler_v4"
loadRuckusTcl "$::DIR_PATH/adt7420_multiread"
loadRuckusTcl "$::DIR_PATH/aspic_3_program"
# loadRuckusTcl "$::DIR_PATH/clk_2MHz_gen" used on REB
loadRuckusTcl "$::DIR_PATH/dcm_user_clk"
loadRuckusTcl "$::DIR_PATH/dual_ad53xx"
loadRuckusTcl "$::DIR_PATH/dual_ads1118"
loadRuckusTcl "$::DIR_PATH/i2c"
# loadRuckusTcl "$::DIR_PATH/dual_ldac_ad53xx" used on GREB
# loadRuckusTcl "$::DIR_PATH/led_blink"
# loadRuckusTcl "$::DIR_PATH/ltc2945_V_I_sensors" used on REB
loadRuckusTcl "$::DIR_PATH/ltc2945_V_I_sensors_greb"
loadRuckusTcl "$::DIR_PATH/max_11046_adc"
# loadRuckusTcl "$::DIR_PATH/mon_xadc" Used by REB
loadRuckusTcl "$::DIR_PATH/multiboot"
loadRuckusTcl "$::DIR_PATH/onewire_iface_v2"
loadRuckusTcl "$::DIR_PATH/REB_interrupt"
loadRuckusTcl "$::DIR_PATH/seq_aligner_shifter"
loadRuckusTcl "$::DIR_PATH/sequencer_v4"
loadRuckusTcl "$::DIR_PATH/SPI"
loadRuckusTcl "$::DIR_PATH/sync_cmd_decoder"
