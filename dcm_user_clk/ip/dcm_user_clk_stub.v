// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Wed Jul  2 16:48:35 2025
// Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
// Command     : write_verilog -force -mode synth_stub
//               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/dcm_user_clk/dcm_user_clk_stub.v
// Design      : dcm_user_clk
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k160tffg676-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CORE_GENERATION_INFO = "dcm_user_clk,clk_wiz_v6_0_16_0_0,{component_name=dcm_user_clk,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,enable_axi=0,feedback_source=FDBK_AUTO,PRIMITIVE=MMCM,num_out_clk=2,clkin1_period=6.400,clkin2_period=10.000,use_power_down=false,use_reset=false,use_locked=true,use_inclk_stopped=false,feedback_type=SINGLE,CLOCK_MGR_TYPE=NA,manual_override=false}" *) 
module dcm_user_clk(CLK_OUT1, CLK_OUT2, LOCKED, CLK_IN1)
/* synthesis syn_black_box black_box_pad_pin="LOCKED" */
/* synthesis syn_force_seq_prim="CLK_OUT1" */
/* synthesis syn_force_seq_prim="CLK_OUT2" */
/* synthesis syn_force_seq_prim="CLK_IN1" */;
  output CLK_OUT1 /* synthesis syn_isclock = 1 */;
  output CLK_OUT2 /* synthesis syn_isclock = 1 */;
  output LOCKED;
  input CLK_IN1 /* synthesis syn_isclock = 1 */;
endmodule
