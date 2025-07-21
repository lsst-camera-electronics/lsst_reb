-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
-- Date        : Wed Jul  2 16:48:35 2025
-- Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
-- Command     : write_vhdl -force -mode synth_stub
--               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/dcm_user_clk/dcm_user_clk_stub.vhdl
-- Design      : dcm_user_clk
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7k160tffg676-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dcm_user_clk is
  Port ( 
    CLK_OUT1 : out STD_LOGIC;
    CLK_OUT2 : out STD_LOGIC;
    LOCKED : out STD_LOGIC;
    CLK_IN1 : in STD_LOGIC
  );

  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of dcm_user_clk : entity is "dcm_user_clk,clk_wiz_v6_0_16_0_0,{component_name=dcm_user_clk,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,enable_axi=0,feedback_source=FDBK_AUTO,PRIMITIVE=MMCM,num_out_clk=2,clkin1_period=6.400,clkin2_period=10.000,use_power_down=false,use_reset=false,use_locked=true,use_inclk_stopped=false,feedback_type=SINGLE,CLOCK_MGR_TYPE=NA,manual_override=false}";
end dcm_user_clk;

architecture stub of dcm_user_clk is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "CLK_OUT1,CLK_OUT2,LOCKED,CLK_IN1";
begin
end;
