// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Wed Jul  2 17:05:03 2025
// Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
// Command     : write_verilog -force -mode synth_stub
//               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/sequencer_v4/ipcore_vivado/ip/dual_port_ram_4_4/dual_port_ram_4_4_stub.v
// Design      : dual_port_ram_4_4
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k160tffg676-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "dual_port_ram_4_4,dist_mem_gen_v8_0_17,{}" *) (* core_generation_info = "dual_port_ram_4_4,dist_mem_gen_v8_0_17,{x_ipProduct=Vivado 2025.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=dist_mem_gen,x_ipVersion=8.0,x_ipCoreRevision=17,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,C_FAMILY=kintex7,C_ADDR_WIDTH=4,C_DEFAULT_DATA=0,C_DEPTH=16,C_HAS_CLK=1,C_HAS_D=1,C_HAS_DPO=1,C_HAS_DPRA=1,C_HAS_I_CE=0,C_HAS_QDPO=0,C_HAS_QDPO_CE=0,C_HAS_QDPO_CLK=0,C_HAS_QDPO_RST=0,C_HAS_QDPO_SRST=0,C_HAS_QSPO=0,C_HAS_QSPO_CE=0,C_HAS_QSPO_RST=0,C_HAS_QSPO_SRST=0,C_HAS_SPO=1,C_HAS_WE=1,C_MEM_INIT_FILE=no_coe_file_loaded,C_ELABORATION_DIR=./,C_MEM_TYPE=2,C_PIPELINE_STAGES=0,C_QCE_JOINED=0,C_QUALIFY_WE=0,C_READ_MIF=0,C_REG_A_D_INPUTS=0,C_REG_DPRA_INPUT=0,C_SYNC_ENABLE=1,C_WIDTH=4,C_PARSER_TYPE=1}" *) (* downgradeipidentifiedwarnings = "yes" *) 
(* x_core_info = "dist_mem_gen_v8_0_17,Vivado 2025.1" *) 
module dual_port_ram_4_4(a, d, dpra, clk, we, spo, dpo)
/* synthesis syn_black_box black_box_pad_pin="a[3:0],d[3:0],dpra[3:0],we,spo[3:0],dpo[3:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input [3:0]a;
  input [3:0]d;
  input [3:0]dpra;
  input clk /* synthesis syn_isclock = 1 */;
  input we;
  output [3:0]spo;
  output [3:0]dpo;
endmodule
