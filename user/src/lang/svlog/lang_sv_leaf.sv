module lang_sv_leaf #(
  parameter int WIDTH = lang_sv_pkg::WIDTH
) (
  input  logic [WIDTH-1:0] input_a,
  input  logic [WIDTH-1:0] input_b,
  output logic [WIDTH-1:0] sum
);
  assign sum = input_a + input_b;
endmodule
