`include "lang_sv_include.svh"

import lang_sv_pkg::*;

module lang_sv_core #(
  parameter int WIDTH = lang_sv_pkg::WIDTH
) (
  input  logic [WIDTH-1:0] input_a,
  input  logic [WIDTH-1:0] input_b,
  output logic [WIDTH-1:0] sum
);
  localparam int VERSION = 32'd1;
  typedef word_t local_word_t;
  alias_t value;
  local_word_t captured;
  local_word_t raw_sum;
  logic [WIDTH-1:0] syntax_probe;
  logic hover_target;

  lang_sv_leaf #(
    .WIDTH(WIDTH)
  ) u_leaf (
    .input_a(input_a),
    .input_b(input_b),
    .sum(raw_sum)
  );

  // Keep the syntax-heavy fixture on the same functional design path.  Its
  // result is intentionally a probe; the public datapath remains the adder.
`ifndef SYNTHESIS
  lang_sv_advanced #(
    .WIDTH(WIDTH)
  ) u_syntax_advanced (
    .clk(1'b0),
    .reset(1'b0),
    .data_in(input_a),
    .data_out(syntax_probe)
  );
`endif

  function automatic local_word_t add_local(input local_word_t lhs, input local_word_t rhs);
    return add_words(lhs, rhs);
  endfunction

  task automatic capture(input local_word_t next_value);
    captured = next_value;
  endtask

  always_comb begin
    value = add_local(raw_sum, '0);
    captured = value;
    sum = value + `LANG_BIAS;
  end

  initial begin
    hover_target = 1'b0;
  end

  initial begin
    $display(`LANG_MESSAGE);
  end
endmodule
