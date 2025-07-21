-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
-- Date        : Wed Jul  2 17:05:03 2025
-- Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
-- Command     : write_vhdl -force -mode synth_stub
--               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/sequencer_v4/ipcore_vivado/ip/dual_port_ram_4_4/dual_port_ram_4_4_stub.vhdl
-- Design      : dual_port_ram_4_4
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7k160tffg676-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dual_port_ram_4_4 is
  Port ( 
    a : in STD_LOGIC_VECTOR ( 3 downto 0 );
    d : in STD_LOGIC_VECTOR ( 3 downto 0 );
    dpra : in STD_LOGIC_VECTOR ( 3 downto 0 );
    clk : in STD_LOGIC;
    we : in STD_LOGIC;
    spo : out STD_LOGIC_VECTOR ( 3 downto 0 );
    dpo : out STD_LOGIC_VECTOR ( 3 downto 0 )
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of dual_port_ram_4_4 : entity is "dual_port_ram_4_4,dist_mem_gen_v8_0_17,{}";
  attribute core_generation_info : string;
  attribute core_generation_info of dual_port_ram_4_4 : entity is "dual_port_ram_4_4,dist_mem_gen_v8_0_17,{x_ipProduct=Vivado 2025.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=dist_mem_gen,x_ipVersion=8.0,x_ipCoreRevision=17,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,C_FAMILY=kintex7,C_ADDR_WIDTH=4,C_DEFAULT_DATA=0,C_DEPTH=16,C_HAS_CLK=1,C_HAS_D=1,C_HAS_DPO=1,C_HAS_DPRA=1,C_HAS_I_CE=0,C_HAS_QDPO=0,C_HAS_QDPO_CE=0,C_HAS_QDPO_CLK=0,C_HAS_QDPO_RST=0,C_HAS_QDPO_SRST=0,C_HAS_QSPO=0,C_HAS_QSPO_CE=0,C_HAS_QSPO_RST=0,C_HAS_QSPO_SRST=0,C_HAS_SPO=1,C_HAS_WE=1,C_MEM_INIT_FILE=no_coe_file_loaded,C_ELABORATION_DIR=./,C_MEM_TYPE=2,C_PIPELINE_STAGES=0,C_QCE_JOINED=0,C_QUALIFY_WE=0,C_READ_MIF=0,C_REG_A_D_INPUTS=0,C_REG_DPRA_INPUT=0,C_SYNC_ENABLE=1,C_WIDTH=4,C_PARSER_TYPE=1}";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of dual_port_ram_4_4 : entity is "yes";
end dual_port_ram_4_4;

architecture stub of dual_port_ram_4_4 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "a[3:0],d[3:0],dpra[3:0],clk,we,spo[3:0],dpo[3:0]";
  attribute x_core_info : string;
  attribute x_core_info of stub : architecture is "dist_mem_gen_v8_0_17,Vivado 2025.1";
begin
end;
