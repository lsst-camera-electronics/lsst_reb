// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Wed Jul  2 17:07:38 2025
// Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
// Command     : write_verilog -force -mode synth_stub
//               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/sequencer_v4/ipcore_vivado/ip/gtwizard_0/gtwizard_0_stub.v
// Design      : gtwizard_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k160tffg676-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* core_generation_info = "gtwizard_0,gtwizard_v3_6_17,{protocol_file=Start_from_scratch}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "gtwizard_0,gtwizard_v3_6_17,{protocol_file=Start_from_scratch}" *) 
module gtwizard_0(SYSCLK_IN, SOFT_RESET_TX_IN, 
  SOFT_RESET_RX_IN, DONT_RESET_ON_DATA_ERROR_IN, GT0_TX_FSM_RESET_DONE_OUT, 
  GT0_RX_FSM_RESET_DONE_OUT, GT0_DATA_VALID_IN, gt0_cpllfbclklost_out, gt0_cplllock_out, 
  gt0_cplllockdetclk_in, gt0_cpllreset_in, gt0_gtrefclk0_in, gt0_gtrefclk1_in, 
  gt0_drpaddr_in, gt0_drpclk_in, gt0_drpdi_in, gt0_drpdo_out, gt0_drpen_in, gt0_drprdy_out, 
  gt0_drpwe_in, gt0_dmonitorout_out, gt0_eyescanreset_in, gt0_rxuserrdy_in, 
  gt0_eyescandataerror_out, gt0_eyescantrigger_in, gt0_rxusrclk_in, gt0_rxusrclk2_in, 
  gt0_rxdata_out, gt0_gtxrxp_in, gt0_gtxrxn_in, gt0_rxdfelpmreset_in, gt0_rxmonitorout_out, 
  gt0_rxmonitorsel_in, gt0_rxoutclkfabric_out, gt0_gtrxreset_in, gt0_rxpmareset_in, 
  gt0_rxslide_in, gt0_rxresetdone_out, gt0_gttxreset_in, gt0_txuserrdy_in, gt0_txusrclk_in, 
  gt0_txusrclk2_in, gt0_txdata_in, gt0_gtxtxn_out, gt0_gtxtxp_out, gt0_txoutclk_out, 
  gt0_txoutclkfabric_out, gt0_txoutclkpcs_out, gt0_txresetdone_out, GT0_QPLLOUTCLK_IN, 
  GT0_QPLLOUTREFCLK_IN)
/* synthesis syn_black_box black_box_pad_pin="SOFT_RESET_TX_IN,SOFT_RESET_RX_IN,DONT_RESET_ON_DATA_ERROR_IN,GT0_TX_FSM_RESET_DONE_OUT,GT0_RX_FSM_RESET_DONE_OUT,GT0_DATA_VALID_IN,gt0_cpllfbclklost_out,gt0_cplllock_out,gt0_cpllreset_in,gt0_drpaddr_in[8:0],gt0_drpdi_in[15:0],gt0_drpdo_out[15:0],gt0_drpen_in,gt0_drprdy_out,gt0_drpwe_in,gt0_dmonitorout_out[7:0],gt0_eyescanreset_in,gt0_rxuserrdy_in,gt0_eyescandataerror_out,gt0_eyescantrigger_in,gt0_rxdata_out[19:0],gt0_gtxrxp_in,gt0_gtxrxn_in,gt0_rxdfelpmreset_in,gt0_rxmonitorout_out[6:0],gt0_rxmonitorsel_in[1:0],gt0_rxoutclkfabric_out,gt0_gtrxreset_in,gt0_rxpmareset_in,gt0_rxslide_in,gt0_rxresetdone_out,gt0_gttxreset_in,gt0_txuserrdy_in,gt0_txdata_in[19:0],gt0_gtxtxn_out,gt0_gtxtxp_out,gt0_txoutclk_out,gt0_txoutclkfabric_out,gt0_txoutclkpcs_out,gt0_txresetdone_out,GT0_QPLLOUTREFCLK_IN" */
/* synthesis syn_force_seq_prim="SYSCLK_IN" */
/* synthesis syn_force_seq_prim="gt0_cplllockdetclk_in" */
/* synthesis syn_force_seq_prim="gt0_gtrefclk0_in" */
/* synthesis syn_force_seq_prim="gt0_gtrefclk1_in" */
/* synthesis syn_force_seq_prim="gt0_drpclk_in" */
/* synthesis syn_force_seq_prim="gt0_rxusrclk_in" */
/* synthesis syn_force_seq_prim="gt0_rxusrclk2_in" */
/* synthesis syn_force_seq_prim="gt0_txusrclk_in" */
/* synthesis syn_force_seq_prim="gt0_txusrclk2_in" */
/* synthesis syn_force_seq_prim="GT0_QPLLOUTCLK_IN" */;
  input SYSCLK_IN /* synthesis syn_isclock = 1 */;
  input SOFT_RESET_TX_IN;
  input SOFT_RESET_RX_IN;
  input DONT_RESET_ON_DATA_ERROR_IN;
  output GT0_TX_FSM_RESET_DONE_OUT;
  output GT0_RX_FSM_RESET_DONE_OUT;
  input GT0_DATA_VALID_IN;
  output gt0_cpllfbclklost_out;
  output gt0_cplllock_out;
  input gt0_cplllockdetclk_in /* synthesis syn_isclock = 1 */;
  input gt0_cpllreset_in;
  input gt0_gtrefclk0_in /* synthesis syn_isclock = 1 */;
  input gt0_gtrefclk1_in /* synthesis syn_isclock = 1 */;
  input [8:0]gt0_drpaddr_in;
  input gt0_drpclk_in /* synthesis syn_isclock = 1 */;
  input [15:0]gt0_drpdi_in;
  output [15:0]gt0_drpdo_out;
  input gt0_drpen_in;
  output gt0_drprdy_out;
  input gt0_drpwe_in;
  output [7:0]gt0_dmonitorout_out;
  input gt0_eyescanreset_in;
  input gt0_rxuserrdy_in;
  output gt0_eyescandataerror_out;
  input gt0_eyescantrigger_in;
  input gt0_rxusrclk_in /* synthesis syn_isclock = 1 */;
  input gt0_rxusrclk2_in /* synthesis syn_isclock = 1 */;
  output [19:0]gt0_rxdata_out;
  input gt0_gtxrxp_in;
  input gt0_gtxrxn_in;
  input gt0_rxdfelpmreset_in;
  output [6:0]gt0_rxmonitorout_out;
  input [1:0]gt0_rxmonitorsel_in;
  output gt0_rxoutclkfabric_out;
  input gt0_gtrxreset_in;
  input gt0_rxpmareset_in;
  input gt0_rxslide_in;
  output gt0_rxresetdone_out;
  input gt0_gttxreset_in;
  input gt0_txuserrdy_in;
  input gt0_txusrclk_in /* synthesis syn_isclock = 1 */;
  input gt0_txusrclk2_in /* synthesis syn_isclock = 1 */;
  input [19:0]gt0_txdata_in;
  output gt0_gtxtxn_out;
  output gt0_gtxtxp_out;
  output gt0_txoutclk_out;
  output gt0_txoutclkfabric_out;
  output gt0_txoutclkpcs_out;
  output gt0_txresetdone_out;
  input GT0_QPLLOUTCLK_IN /* synthesis syn_isclock = 1 */;
  input GT0_QPLLOUTREFCLK_IN;
endmodule
