# lsst_reb

Shared VHDL IP library for LSST Raft Electronics Boards (REB_v5, GREB_v2,
WREB_v4). Contains peripheral drivers, the CCD clocking sequencer, and
board-level infrastructure logic.

## Usage

This repository is consumed as a git submodule by each board-level project.
The top-level `ruckus.tcl` loads all modules into the Vivado build via the
ruckus framework. It has no standalone top-level entity.

**Dependencies:** `surf` (SLAC firmware library, sibling submodule in the
parent project).

## Modules

| Directory | Description |
|-----------|-------------|
| `ad53xx_dac` | AD53xx DAC SPI driver with protection |
| `ad56xx_dac` | AD56xx DAC SPI driver |
| `ad7794_temp_sens` | AD7794 temperature sensor readout |
| `ADC_data_handler_v4` | CCD ADC data capture and formatting |
| `ads8634_and_mux` | ADS8634 ADC with mux control |
| `adt7420_multiread` | ADT7420 I2C temperature multi-sensor reader |
| `aspic_spi_link` | ASPIC configuration SPI interface |
| `backbias_switch` | Back-bias voltage switch control |
| `basic_elements` | Generic reusable logic primitives |
| `brs` | Base register set (command/status registers) |
| `clk_2MHz_gen` | 2 MHz clock generator |
| `dual_ads1118` | Dual ADS1118 ADC readout |
| `i2c` | I2C bus master controller |
| `led_blink` | LED blink indicator |
| `ltc2945_V_I_sensors` | LTC2945 voltage/current sensor readout |
| `max_11046_adc` | MAX11046 multi-channel ADC controller |
| `multiboot` | FPGA multiboot and SPI flash programmer |
| `onewire_iface_v2` | 1-Wire bus master interface |
| `reb_config` | Board configuration constants and packages |
| `REB_interrupt` | Interrupt handler |
| `seq_aligner_shifter` | Sequencer output alignment pipeline |
| `sequencer_v4` | CCD clocking sequencer engine |
| `si5342_jitter_cleaner` | SI5342 jitter cleaner configuration |
| `SPI` | Generic SPI read/write primitives |
| `sync_cmd_decoder` | Synchronous command decoder |
| `system_clk` | System clock management |

## Sequencer

The `sequencer_v4/` module is the most complex component — a programmable
waveform engine that generates CCD clocking patterns. See
[`sequencer_v4/SEQUENCER_THEORY.md`](sequencer_v4/SEQUENCER_THEORY.md) for
full architectural documentation and
[`sequencer_v4/TB/README.md`](sequencer_v4/TB/README.md) for the regression
testbench.
