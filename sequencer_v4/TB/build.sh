#!/usr/bin/env bash
# build.sh
# Build and run tb_sequencer against lsst_reb.
# Expects to live in lsst_reb/sequencer_v4/TB/ with surf at ../../../surf.
# Usage: bash build.sh
set -e

VIVADO_BIN=/home/jgt/xilinx/Vivado/2024.1/bin
VIVADO_DATA=/home/jgt/xilinx/Vivado/2024.1/data
XVHDL=$VIVADO_BIN/xvhdl
XELAB=$VIVADO_BIN/xelab
XSIM=$VIVADO_BIN/xsim

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

DEV=$ROOT/../..
BASIC=$DEV/basic_elements/rtl
SEQ4=$DEV/sequencer_v4
SURF=$ROOT/../../../surf

echo "========================================"
echo "  tb_sequencer  (lsst_reb @ $(cd $DEV && git rev-parse --short HEAD))"
echo "========================================"

# ── Clean ─────────────────────────────────────────────────────────────────────
echo "[1/6] Cleaning..."
rm -rf xsim.dir xvhdl.pb xelab.pb *.log *.jou run.tcl

# ── xvhdl.ini ─────────────────────────────────────────────────────────────────
echo "[2/6] Creating xvhdl.ini..."
cat > xvhdl.ini <<EOF
unisim=${VIVADO_DATA}/xsim/vhdl/unisim
EOF

# ── SURF ──────────────────────────────────────────────────────────────────────
echo "[3/6] Compiling surf..."
SURF_OPTS="--2008 --work surf --initfile xvhdl.ini"
$XVHDL $SURF_OPTS $SURF/base/general/rtl/StdRtlPkg.vhd
$XVHDL $SURF_OPTS $SURF/base/general/rtl/RegisterVector.vhd
$XVHDL $SURF_OPTS $SURF/base/ram/inferred/LutRam.vhd
$XVHDL $SURF_OPTS $SURF/base/ram/inferred/TrueDualPortRam.vhd
$XVHDL $SURF_OPTS $SURF/base/ram/inferred/SimpleDualPortRam.vhd
$XVHDL $SURF_OPTS $SURF/base/ram/inferred/DualPortRam.vhd
$XVHDL $SURF_OPTS $SURF/base/fifo/rtl/inferred/FifoWrFsm.vhd
$XVHDL $SURF_OPTS $SURF/base/fifo/rtl/inferred/FifoRdFsm.vhd
$XVHDL $SURF_OPTS $SURF/base/fifo/rtl/FifoOutputPipeline.vhd
$XVHDL $SURF_OPTS $SURF/base/fifo/rtl/inferred/FifoSync.vhd

# ── lsst_reb ──────────────────────────────────────────────────────────────────
echo "[4/6] Compiling lsst_reb..."
LSST_OPTS="--2008 --work lsst_reb --initfile xvhdl.ini"

$XVHDL $LSST_OPTS $BASIC/basic_elements_pkg.vhd
$XVHDL $LSST_OPTS $BASIC/ff_ce.vhd
$XVHDL $LSST_OPTS $BASIC/generic_reg_ce_init.vhd
$XVHDL $LSST_OPTS $BASIC/generic_single_port_ram.vhd
$XVHDL $LSST_OPTS $BASIC/generic_counter_comparator_ce_init.vhd
$XVHDL $LSST_OPTS $BASIC/generic_mux_bus_4_1_clk.vhd
$XVHDL $LSST_OPTS $BASIC/mux_2_1_bus_noclk.vhd

$XVHDL $LSST_OPTS $SEQ4/sequencer_v3_package.vhd
$XVHDL $LSST_OPTS $SEQ4/SequencerPkg.vhd

$XVHDL $LSST_OPTS $SEQ4/function_v3/function_executor_v3.vhd
$XVHDL $LSST_OPTS $SEQ4/function_v3/function_fsm_v3.vhd
$XVHDL $LSST_OPTS $SEQ4/function_v3/function_v3.vhd
$XVHDL $LSST_OPTS $SEQ4/function_v3/function_v3_top.vhd

$XVHDL $LSST_OPTS $DEV/seq_aligner_shifter/rtl/sequencer_aligner_shifter_top.vhd

$XVHDL $LSST_OPTS $SEQ4/func_handler_v4/parameter_extractor_fsm_v3.vhd
$XVHDL $LSST_OPTS $SEQ4/func_handler_v4/sequencer_parameter_extractor_top_v4.vhd
$XVHDL $LSST_OPTS $SEQ4/sequencer_v4_top.vhd
$XVHDL $LSST_OPTS $SEQ4/Sequencer.vhd

# ── Testbench ─────────────────────────────────────────────────────────────────
echo "[5/6] Compiling testbench..."
$XVHDL --2008 --work work --initfile xvhdl.ini $ROOT/tb_sequencer.vhd

# ── Elaborate + Simulate ──────────────────────────────────────────────────────
echo "[6a/6] Elaborating..."
$XELAB --initfile xvhdl.ini \
  -L surf -L lsst_reb -L unisim \
  --debug typical \
  --snapshot tb_sequencer_snap \
  work.tb_sequencer \
  2>&1 | tee xelab.log

echo "[6b/6] Simulating..."
mkdir -p sim_data
cat > run.tcl <<'EOF'
run -all
quit
EOF
$XSIM tb_sequencer_snap --tclbatch run.tcl --log xsim.log 2>&1 | tee xsim_stdout.log

echo ""
echo "========================================"
PASS_COUNT=$(grep -c "^Note: PASS:" xsim.log || true)
FAIL_COUNT=$(grep -c "^Note: FAIL:" xsim.log || true)
echo "  Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    grep "^Note: FAIL:" xsim.log
fi
echo "========================================"
[ "$FAIL_COUNT" -eq 0 ]
