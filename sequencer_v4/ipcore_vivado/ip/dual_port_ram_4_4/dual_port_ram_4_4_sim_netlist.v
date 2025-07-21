// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Wed Jul  2 17:05:03 2025
// Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
// Command     : write_verilog -force -mode funcsim
//               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/sequencer_v4/ipcore_vivado/ip/dual_port_ram_4_4/dual_port_ram_4_4_sim_netlist.v
// Design      : dual_port_ram_4_4
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7k160tffg676-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "dual_port_ram_4_4,dist_mem_gen_v8_0_17,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "dist_mem_gen_v8_0_17,Vivado 2025.1" *) 
(* NotValidForBitStream *)
module dual_port_ram_4_4
   (a,
    d,
    dpra,
    clk,
    we,
    spo,
    dpo);
  input [3:0]a;
  input [3:0]d;
  input [3:0]dpra;
  input clk;
  input we;
  output [3:0]spo;
  output [3:0]dpo;

  wire [3:0]a;
  wire clk;
  wire [3:0]d;
  wire [3:0]dpo;
  wire [3:0]dpra;
  wire [3:0]spo;
  wire we;
  wire [3:0]NLW_U0_qdpo_UNCONNECTED;
  wire [3:0]NLW_U0_qspo_UNCONNECTED;

  (* C_FAMILY = "kintex7" *) 
  (* C_HAS_CLK = "1" *) 
  (* C_HAS_D = "1" *) 
  (* C_HAS_WE = "1" *) 
  (* C_MEM_TYPE = "2" *) 
  (* c_addr_width = "4" *) 
  (* c_default_data = "0" *) 
  (* c_depth = "16" *) 
  (* c_elaboration_dir = "./" *) 
  (* c_has_dpo = "1" *) 
  (* c_has_dpra = "1" *) 
  (* c_has_i_ce = "0" *) 
  (* c_has_qdpo = "0" *) 
  (* c_has_qdpo_ce = "0" *) 
  (* c_has_qdpo_clk = "0" *) 
  (* c_has_qdpo_rst = "0" *) 
  (* c_has_qdpo_srst = "0" *) 
  (* c_has_qspo = "0" *) 
  (* c_has_qspo_ce = "0" *) 
  (* c_has_qspo_rst = "0" *) 
  (* c_has_qspo_srst = "0" *) 
  (* c_has_spo = "1" *) 
  (* c_mem_init_file = "no_coe_file_loaded" *) 
  (* c_parser_type = "1" *) 
  (* c_pipeline_stages = "0" *) 
  (* c_qce_joined = "0" *) 
  (* c_qualify_we = "0" *) 
  (* c_read_mif = "0" *) 
  (* c_reg_a_d_inputs = "0" *) 
  (* c_reg_dpra_input = "0" *) 
  (* c_sync_enable = "1" *) 
  (* c_width = "4" *) 
  (* is_du_within_envelope = "true" *) 
  dual_port_ram_4_4_dist_mem_gen_v8_0_17 U0
       (.a(a),
        .clk(clk),
        .d(d),
        .dpo(dpo),
        .dpra(dpra),
        .i_ce(1'b1),
        .qdpo(NLW_U0_qdpo_UNCONNECTED[3:0]),
        .qdpo_ce(1'b1),
        .qdpo_clk(1'b0),
        .qdpo_rst(1'b0),
        .qdpo_srst(1'b0),
        .qspo(NLW_U0_qspo_UNCONNECTED[3:0]),
        .qspo_ce(1'b1),
        .qspo_rst(1'b0),
        .qspo_srst(1'b0),
        .spo(spo),
        .we(we));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2025.1"
`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
FdZ29m26W1vj+Cs/DLJCoTOUz/m7+OJG3sHOgt5s8NEPQ5FHtOFz4fRgqTgyrNzvNq21lk0VjpX9
UMVEbSXbJrC40crYnx5XneHRwr6z9uk6MXgKoH1FHcznnKhevagwuCchTCpQ6oqoMbhzWd2QHx/v
Pkor8V47KvEBnEHja7Q=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
DgywwNcpeS8jND8bxEa71yZJ3FJdVEzcLynb64dnb2TzUo3pKSGFBfaFrgTZF3YNHGzuUJ2QQktc
gOS5J0CcVw+n+aerigILzjTclkLc9eUIulkdUapbmj6Staw/UyV8tYP4SZZ8/c285RLhOXD7yU47
aByWm7LmxxWjooRAz26ybpmdt7lpHBQaNTc1Ljp9oCyvtSqxXf5Fzr6NwE9wCWHGozsMntKGlBWq
/Ld4jJ9UVtrIM3FKdUF21rHccua0AApkyY92z4umdT7kj4mZxPKTdC7zYiKWRUq2hGAlbh1z47nC
oAaSpPvOVZY7BQppznHPyLPhJ+OgKj6/rfTVMA==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
TpTqgO7LVAmk2RI9B8mgZrp5H21SnS0bmTRlpg9WONkWIeKkOMiqYzKXNi+GTasTvmpRPk/h3m9P
wkWG5aX3dHNZUb1oSMhjGbyAcJpO+SX7mcsmzpt+efdEtPDukAHegpQfvEWKkx2SrrkkgD0X++Oj
CaqCq5FvcRl9RjvTxK4=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
sckknZF7xLyHpnPIcxIFLiAYqXW1FY2CS9FWi2Hqz5vcUlh7by0h8yYiwSXxIUNrBJPATd3AyESC
487cvtya2VioL8riKucCJWyqQBG7eDyT0O7JtdZYcpo9uNh6dkN86IV7J1BLYVlk/Z2uc+LRdLiA
I2w8Z4wc+UHp3wx4497iJfYpHaKSPNO+8A8WV/JJ1mzSLBI14cO9CDFly9KlHktwr4HKutMId1R2
VPSy/znW8qx9XUnd0EN31c/9LJnfU1yhBPG9Wx8Hd96IBwI9D/WgN7ZQyH8bSZCcHX+SYoIGPwXn
K5ZKQy1K7ELwUBUUPbGlR+ir3yvvGjob1CTeMg==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
T6BTO2RUQcpX9TpJR2JO50hT+cXyiDyIjrO2Ps17SKTmMhVBfSGD2AUMwzKJINBU1/wI4nqsnk0R
B5YRLWXrZfCSjSapre9CmGTRvLCDEK4mm3l4Jo9Ij9iBFg2OvLFfyBLP/fZtLtzCPHtMlTmKn7C3
9Ert7v3yDGnFF+1Msw/UpTjpdSZ4dNE8UGUe5ymCwpDVeCcYuoCTBe5o7BDlcM6cbXMfHvxQkBDH
BQkO5txX5aV2qeKOYfWQucZe9q7aoq4zcNG3roo8G4OrO31xnxdwAQU8tvOCztoGHXLSPEwLy86h
lybMIS19uovvmz2FF0BKAfQmf2zT2kdhs/0E/g==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2025.1-2029.x", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
qFdGo2cl1WGkQBqlM3e3YM1+NstrsuheqspzsHjhiEdsfZE7cNV3QtgmcPm0sQ6Ur85Vr+VLP+qi
kfkSBZv/cp96m2VbdU3wKRoyTYzTU2jPpW7sGFFNzWS9+RUl8sTVLht5d4t2CNOGni/aTPg72L/m
EMDSFNr5zmZHrz9ZfvCDtOuBIV7kMLfZPmDdxV5IwsKMxabGnoXOJGz+hfjGo4fS3o0ORBwIVK+l
mvU1GZj8rJVgjjtXmyh6mIw/6PchaANzWFqpNusTs0IG2f3q7OE0VBOM5Am+iaDdeW6TlD3NJO83
Fu/vCJwu/i0r7tthiRGj94Azl8RnEN2KK7tBlA==

`pragma protect key_keyowner="Metrics Technologies Inc.", key_keyname="DSim", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
g77N+3QvAPAYw+4OcZm63AqmcCkwUoxBBbPDHeq2Nfprvo7Bj7LixjYXj3xyrnR8haey/83rTRib
U8uD29Fgb15vpUc0WthyXJ59GM2fKf1KCeTQtG6TwZDLuOLNJNaeGFe+JU6iYvvLnOQZ3aPsmfcT
4GCJv1sKrMCf5d2VkK5yqBhV9Xik8ugmxG6gW1xkr0ULwrG4CYrZAEPhwUoiL+6RLajwaMyW0fhu
TihpJjKW17O8yAizfvC4zdrTR7abBHMBRX51n0fYXfSNTJZH84wlEZ/uaRGrT3tziopYXWPsmWSq
JJ5Q30ZViY8s/kqmcILk7jzkE5iBk7FfRk2AHw==

`pragma protect key_keyowner="Atrenta", key_keyname="ATR-SG-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=384)
`pragma protect key_block
KCCTN2ufL/SeejpVpXJmjN/FwrAflQw79fl4pWJPTrncXR+h72Z53BIfG+PPQuyFWo2dT+31hFh2
sUjBKcBwHP9yjxsmRjhWVA4YtsuTiFCa3GwHalwHMC9EJN8EOmcee6T0DD8eKj13S7DJ+LDuhg0a
CAhAdS+Z3c57AAFhfKZ64/xN+dwK+7T+oXbmBDtxKw+D7VXMZLVjJ7ozXveIocAFo9MLpyq0mXPL
m47fmY77h7JdJ8BnZ0qXpublK3I9ahjB6+iTR7hAu417IqmFRnmc0ICovANVgmMBsOU54gzqFRS1
4jIQ7pPGSuMMJ5F+bWiKn1kahxg2JXS+3rf9r5Jyc2Ht4bO62YYec93HOrFxzErn9LzUFSvXe8JC
M/OAkWw+gqiiLbQsh+1Hfn4j9JSiL/n8yCkGXAr8x/vdfzkIBv4QpsSo5rGTuXS2x27KOAsuV7X7
maV86bXDbpBaMN1hZLtFkWNpTJE03j5Hq7cTDh+EySOe2NSwB0potFkw

`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="CDS_RSA_KEY_VER_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
DB5hKjvS9FmG+/wPMbBeHe5M88req0CpR1ooQpQHlIx5dQoUMI8l84F0JQ8hAkUaWLkU1VXXMNmW
eRJoUf6rnT4CbNo5SFwNWSXohTyDSupMazp2OYDlVlTgfUyyJ+lVIViRHiC3vIbi1J7fLoZ1Bt9F
cr98l0aF9q+NPMPI9Xs8X4XYYXL9FyHNyb3bAoEI1OPmH5ywFB+fJ73hp3aEXHx9pcl2RKryf1m/
Q98GVV/ZXzQmgGNEdveABCSK3XNXC0Ro6IHFjACUVo3VTsjMMx1k2n+MWq7Zbp5l8ZcvX+F+NHY6
q/Cm8B96kJQ4bGZ0qnzIYoKDGY7YEGWVJFoWQg==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 8128)
`pragma protect data_block
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
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
