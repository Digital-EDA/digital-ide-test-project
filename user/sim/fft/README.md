# FFT simulation fixture

`fft_ifft_tb.sv` is the only simulation top in this directory. It instantiates
and checks all three FFT implementations in the fixture:

* `ifftmain` and its hand-written RTL under `user/src/ifft`;
* forward and inverse instances of `Basic/Math/Advance/FFT/Flow/FFT_IFFT.v`;
* the Xilinx `xfft_v9` AXI-stream IP generated from
  `user/ip/xfft_v9/xfft_v9.xci`.

The test drives an impulse frame into each implementation, checks that every
implementation produces data, verifies the Xilinx 64-sample `TLAST` boundary,
and fails on unknown data or Xilinx input framing events. The workspace
property selects `fft_ifft_tb` as the single simulation top; files under
`user/sim` are discovered recursively.

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
