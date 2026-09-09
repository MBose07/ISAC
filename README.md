# RX RTL

This folder implements a streaming OFDM receiver with carrier-frequency-offset (CFO) correction, FFT processing, channel equalization, common-phase-error (CPE) correction, and BPSK demodulation.

## Top-level data path

```text
Complex input samples
        |
        v
Preamble correlation -> CFO estimation -> CFO correction
        |
        v
Cyclic-prefix removal -> 128-point SDF FFT -> bit reversal
        |
        v
Channel estimation -> Zero-forcing equalizer -> CPE estimation/rotation
        |
        v
BPSK demodulator -> demodulated bits
```

The integrated top level is `full_ofdm_rx_with_cfo` in `full_ofdm_rx.v`. Its default configuration is 16-bit signed I/Q samples, 128 subcarriers, and a 32-sample cyclic prefix. Data is transferred with `valid` signals; reset is active-low inside the RTL even where the top-level port is named `rst` or `reset`.

## Directory contents

### `PREAMBLE/`
- `correlation.v`: Correlates the incoming complex stream with the configured preamble and detects a match. Also provides the aligned delayed sample stream.
- `mac.v`: Multiply/accumulate and delay-line building block used by the correlator.

### `CFO/`
- `cfo_estimator.v`: Accumulates complex products from the repeated preamble to estimate carrier-frequency offset.
- `angle.v`: Extracts an angle from the accumulated complex correlation result.
- `CFO_apply.v`: Applies the estimated phase rotation to incoming complex samples.
- `CFO_top.v`: Supporting CFO pipeline wrapper.
- `fifo.v`: FIFO used by the CFO estimator.

### `OTHERS/`
- `rx_main.v`: Defines the `cfo_top` pipeline, connecting correlation, buffering, CFO estimation/application, CP removal, and FFT.
- `controller.v`: Controls the CFO estimation and buffered sample readout phases.
- `CP_rem.v`: Removes the cyclic prefix and forwards useful OFDM samples.
- `sync_fifo.v`: Synchronous sample buffer used between correlation and CFO correction.

### `FFT/`
- `top.v`: `isac_ofdm_fft_top`, a parameterized streaming radix-2 SDF FFT. The default integration uses 128 points and seven stages.
- `sdf_stage.v`: One FFT pipeline stage.
- `butterfly.v`: FFT butterfly arithmetic.
- `delay_line.v`: Stage delay storage.
- `twiddle_rom.v`: Twiddle-factor lookup.
- `bit_reversal.v`: Reorders FFT output bins and generates block-end indication.

### `POST_FFT/`
- `ch_est.v`: Builds and stores channel estimates from the training symbol, then reads them during payload symbols.
- `equalizer_stream.v`: Performs pipelined complex zero-forcing equalization and classifies null, pilot, and data subcarriers.
- `pipelined_divider.v`: Pipelined signed divider used by the equalizer.
- `cpe_top.v`: Coordinates CPE angle estimation, data alignment, and phase rotation.
- `cpe_angle_calc.v`: Estimates common phase error from pilot subcarriers.
- `cpe_apply_stream.v`: Applies the estimated phase correction.
- `cpe_data_delay.v`: Delays equalized data to align with the CPE estimate.
- `cordic_atan2.v`: LUT-based phase/angle extraction.
- `cordic_rotator.v`: LUT-based complex rotation.
- `bpsk_demod_stream.v`: Converts corrected data subcarriers to output bits.

## Simulation testbenches

- `tb_final.v`: End-to-end receiver test. Reads `../cfo_stimulus.mem` and writes demodulated output and intermediate logs in the parent `RX` directory.
- `tb_post_fft.v`: Tests the post-FFT chain from saved FFT samples through channel estimation, equalization, CPE correction, and BPSK demodulation. Reads `../fft_output_log.txt`.
- `tb_cpe.v`: Focused testbench for CPE processing.

The testbenches expect to be compiled or run with the working directory set to `RTL`, because their file paths are relative to that directory. Generated simulation files include `simulation_log.txt`, `fft_output_log.txt`, `test.txt`, and optional waveform output.

## Typical compilation inputs

Compile the selected testbench together with all RTL source files, for example with a Verilog simulator such as Icarus Verilog:

```sh
iverilog full_ofdm_rx.v CFO/*.v FFT/*.v OTHERS/*.v PREAMBLE/*.v POST_FFT/*.v tb_final.v
vvp a.ouy
```

Use `tb_post_fft.v` or `tb_cpe.v` instead of `tb_final.v` for focused simulations. Check the simulator file list and top-level selection when compiling, since `rx_main.v` contains the `cfo_top` module used by `full_ofdm_rx.v`.
