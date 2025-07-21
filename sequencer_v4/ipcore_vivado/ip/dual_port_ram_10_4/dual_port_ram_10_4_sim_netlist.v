// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Wed Jul  2 17:06:05 2025
// Host        : lsst-daq02.slac.stanford.edu running 64-bit Rocky Linux release 8.10 (Green Obsidian)
// Command     : write_verilog -force -mode funcsim
//               /home/jgt/reb_firmware/WREB_v4/common/lsst_reb/sequencer_v4/ipcore_vivado/ip/dual_port_ram_10_4/dual_port_ram_10_4_sim_netlist.v
// Design      : dual_port_ram_10_4
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7k160tffg676-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "dual_port_ram_10_4,dist_mem_gen_v8_0_17,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "dist_mem_gen_v8_0_17,Vivado 2025.1" *) 
(* NotValidForBitStream *)
module dual_port_ram_10_4
   (a,
    d,
    dpra,
    clk,
    we,
    spo,
    dpo);
  input [3:0]a;
  input [9:0]d;
  input [3:0]dpra;
  input clk;
  input we;
  output [9:0]spo;
  output [9:0]dpo;

  wire [3:0]a;
  wire clk;
  wire [9:0]d;
  wire [9:0]dpo;
  wire [3:0]dpra;
  wire [9:0]spo;
  wire we;
  wire [9:0]NLW_U0_qdpo_UNCONNECTED;
  wire [9:0]NLW_U0_qspo_UNCONNECTED;

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
  (* c_width = "10" *) 
  (* is_du_within_envelope = "true" *) 
  dual_port_ram_10_4_dist_mem_gen_v8_0_17 U0
       (.a(a),
        .clk(clk),
        .d(d),
        .dpo(dpo),
        .dpra(dpra),
        .i_ce(1'b1),
        .qdpo(NLW_U0_qdpo_UNCONNECTED[9:0]),
        .qdpo_ce(1'b1),
        .qdpo_clk(1'b0),
        .qdpo_rst(1'b0),
        .qdpo_srst(1'b0),
        .qspo(NLW_U0_qspo_UNCONNECTED[9:0]),
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 15984)
`pragma protect data_block
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
DaIF6Q0mE574ZjsUHQ+qfjegn4uR8PC1
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
