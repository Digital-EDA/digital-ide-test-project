// Mixed-language hardware top used by the Xilinx build flow.
//
// The visible output is a two-bit running light. The pattern is deliberately
// passed through lang_vhdl_top so this top also exercises the SV -> VHDL -> SV
// mixed-language boundary during Vivado elaboration and implementation.
module func #(
  parameter integer CLK_FREQ_HZ = 50_000_000,
  parameter integer STEP_HZ = 1
) (
  input  logic       sys_clk,
  input  logic       rst_n,
  output logic [1:0] led
);
  localparam integer STEP_DIVIDER = (CLK_FREQ_HZ < STEP_HZ || STEP_HZ < 1)
      ? 1
      : (CLK_FREQ_HZ / STEP_HZ);
  localparam integer DIVIDER_WIDTH = (STEP_DIVIDER <= 1)
      ? 1
      : $clog2(STEP_DIVIDER);

  logic [DIVIDER_WIDTH-1:0] divider;
  logic [1:0] running_pattern;
  logic [7:0] vhdl_input_a;
  logic [7:0] vhdl_input_b;
  wire  [7:0] vhdl_result;

  // lang_vhdl_top's datapath is input_a + input_b + 1.  8'hff cancels the
  // bias modulo 8 bits, so the VHDL result is exactly the running pattern.
  assign vhdl_input_a = {6'b0, running_pattern};
  assign vhdl_input_b = 8'hff;

  lang_vhdl_top u_lang_vhdl_top (
    .input_a(vhdl_input_a),
    .input_b(vhdl_input_b),
    .result(vhdl_result)
  );

  assign led = vhdl_result[1:0];

  always_ff @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
      divider <= '0;
      running_pattern <= 2'b01;
    end else if (divider == STEP_DIVIDER - 1) begin
      divider <= '0;
      running_pattern <= {running_pattern[0], running_pattern[1]};
    end else begin
      divider <= divider + 1'b1;
    end
  end
endmodule
