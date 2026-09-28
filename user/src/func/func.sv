// Xilinx hardware-debug top used for real-board ILA/VIO validation.
`ifndef SYNTHESIS
module BUFG(input wire I, output wire O);
  assign O = I;
endmodule
`endif

module func #(
  parameter integer CLK_FREQ_HZ = 50_000_000,
  parameter integer STEP_HZ = 1
) (
  input  logic       sys_clk,
  output logic [1:0] led
);
  localparam integer STEP_DIVIDER = (CLK_FREQ_HZ < STEP_HZ || STEP_HZ < 1)
      ? 1
      : (CLK_FREQ_HZ / STEP_HZ);
  localparam integer DIVIDER_WIDTH = (STEP_DIVIDER <= 1)
      ? 1
      : $clog2(STEP_DIVIDER);

  logic [DIVIDER_WIDTH-1:0] divider = '0;
  logic [1:0] running_pattern = 2'b01;
  logic [15:0] debug_counter = '0;

  // VIO 0 provides a real-board read/write loopback. Bit 3 enables the
  // front-panel LED override and bits [1:0] select the LED value.
  (* vio, vio_id=0, probe_type=2 *) wire vio_clk;
  (* vio, vio_id=0, direction="out", init_val=5 *) wire [3:0] control;
  (* vio, vio_id=0, direction="in" *) wire [3:0] loopback = control;

  // ILA 0 exercises capture/trigger conditions. ILA 1 is available for an
  // immediate capture and is linked from ILA 0 by func.debug.toml.
  (* ila, ila_id=0, probe_type=2 *) wire condition_clk;
  (* ila, ila_id=0, probe_mode=1 *) wire [15:0] condition_counter = debug_counter;
  (* ila, ila_id=0, probe_type=3 *) wire sample_valid = debug_counter[0];
  (* ila, ila_id=0, probe_mode=2 *) wire [3:0] condition_control = control;

  (* ila, ila_id=1, probe_type=2 *) wire immediate_clk;
  (* ila, ila_id=1, probe_mode=2 *) wire [15:0] immediate_counter = debug_counter;
  (* ila, ila_id=1, probe_mode=2 *) wire [3:0] immediate_control = control;

  BUFG u_condition_clock_buffer (.I(sys_clk), .O(condition_clk));
  BUFG u_immediate_clock_buffer (.I(sys_clk), .O(immediate_clk));
  BUFG u_vio_clock_buffer       (.I(sys_clk), .O(vio_clk));

  assign led = control[3] ? control[1:0] : running_pattern;

  // The free-running counter guarantees that a connected target can always
  // satisfy the ILA trigger without depending on external stimulus.
  always_ff @(posedge condition_clk) begin
    debug_counter <= debug_counter + 1'b1;
  end

  always_ff @(posedge condition_clk) begin
    if (divider == STEP_DIVIDER - 1) begin
      divider <= '0;
      running_pattern <= {running_pattern[0], running_pattern[1]};
    end else begin
      divider <= divider + 1'b1;
    end
  end
endmodule
