# FFT simulation fixture

`fft_ifft_tb.sv` is the only simulation top in this directory. It instantiates
and checks all three FFT implementations in the fixture:

* `ifftmain` and its hand-written RTL under `user/src/ifft`;
* forward and inverse instances of `Basic/Math/Advance/FFT/Flow/FFT_IFFT.v`;
* the Xilinx `xfft_v9` AXI-stream IP generated from
  `user/ip/xfft_v9/xfft_v9.xci`.

All four instances use 64-point transforms. The shared FFT/IFFT instances set
`TOTAL_STEP = 6`; their input/output width remains 12 bits.

The test sends **three rounds of four frames**, continuously without resetting
between frames (12 frames / 768 input samples per instance):

| Case in each round | Real input | Imaginary input |
| --- | --- | --- |
| 0 | Impulse: first sample `A`, then zeros | 0 |
| 1 | `round(A * cos(2*pi*1*n/64 + phase))` | 0 |
| 2 | `round(A * cos(2*pi*4*n/64 + phase))` | 0 |
| 3 | `round(A * cos(2*pi*11*n/64 + phase))` | 0 |

For rounds 1, 2 and 3, `A` is 64, 128 and 256; `phase` is 0, pi/4
and pi/2, respectively. Here `round(x)` means `floor(x + 0.5)`. Every instance receives
the same signed integer samples, packed according to its own interface.
The Xilinx input respects AXI backpressure, so its timing can differ.
Zero input then flushes the continuously enabled user/shared pipelines.

The checks require 12 complete 64-sample frames from each instance, reject
X/Z and all-zero test frames, and check frame synchronization. The Xilinx
output must assert `TLAST` exactly on sample 64 of every frame, with no
unexpected/missing input `TLAST` events. A global watchdog also covers stalled
configuration/data handshakes. A successful run prints
`FFT/IFFT regression passed: 64 points, 3 rounds, 12 frames per DUT`.

This remains a data-flow/frame regression, not a numerical FFT accuracy test:
it does not compare against a software DFT or compensate for each core's
scaling and output ordering. The FFT and IFFT instances run in parallel;
they do not form an FFT-to-IFFT round trip. For an IFFT instance, these cosine
samples are frequency-domain input coefficients.

The workspace property selects `fft_ifft_tb` as the single simulation top;
files under `user/sim` are discovered recursively.

## Vivado/xsim

Open this workspace as a Xilinx project, refresh it, and run the project
simulation. The manager discovers `user/src/ifft`, `user/sim/fft`, the XCI under
`user/ip/xfft_v9`, and the configured common library path
`Basic/Math/Advance/FFT/Flow` (plus its declared dependencies).
The fixture sets `simRuntime` to `all`, so the command-line XSim flow does not
stop at Vivado's default 1000 ns before the mixed-language testbench completes.

## Third-party simulators

Use ModelSim or Questa with `fft_ifft_tb` and leave vendor preparation enabled.
Digital-IDE asks Vivado to compile the Xilinx simulator library and export the
XCI simulation sources, maps the generated `xfft_v9_1_*` library into
`modelsim.ini`, and runs the same SystemVerilog top. Set
`vendorCompileIpLibraries` when a fresh IP-library export is required;
`vendorForceLibraryRebuild` and `vendorForceExport` invalidate the two caches
independently.

Verilator cannot compile VHDL or the Xilinx compiled model. It can only run the
hand-written/shared portion after excluding the vendor IP from the Verilator
source set; the complete three-way check requires Vivado XSim or a
ModelSim/Questa mixed-language run.
