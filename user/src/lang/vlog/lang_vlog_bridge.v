`timescale 1ns/1ps

module lang_vlog_bridge #(parameter WIDTH = 8) (data_in, data_out);
  input  [WIDTH-1:0] data_in;
  output [WIDTH-1:0] data_out;

  // Verilog-2001-only declarations and procedural forms.  In particular,
  // this file deliberately avoids SystemVerilog's 4-state declaration and
  // procedural shorthand so the Verilog dialect path is exercised alone.
  wire [WIDTH-1:0] inverted_data;
  reg [WIDTH-1:0] legacy_register;
  reg [WIDTH-1:0] case_probe;
  integer bit_index;
  tri [WIDTH-1:0] tri_data;
  wand [WIDTH-1:0] wired_and;
  wor [WIDTH-1:0] wired_or;

  // These are legal identifiers under IEEE 1364-2005 but become reserved
  // keywords in SystemVerilog.  Their declarations prove that .v files are
  // not tokenized through the SystemVerilog keyword table.
  wire logic;
  reg bit;
  integer priority;
  wire interface;
  wire package;
  wire class;

  assign inverted_data = data_in ^ {WIDTH{1'b1}};
  assign tri_data = inverted_data;
  assign wired_and = tri_data;
  assign wired_or = tri_data;

  function [WIDTH-1:0] invert_value;
    input [WIDTH-1:0] value;
    begin
      invert_value = value ^ {WIDTH{1'b1}};
    end
  endfunction

  task record_value;
    input [WIDTH-1:0] value;
    begin
      legacy_register = value;
    end
  endtask

  always @* begin : legacy_combination
    legacy_register = invert_value(data_in);
    casez (data_in)
      {WIDTH{1'bz}}: case_probe = {WIDTH{1'b0}};
      default: case_probe = data_in;
    endcase
    casex (data_in)
      {WIDTH{1'bx}}: case_probe = {WIDTH{1'b1}};
      default: case_probe = case_probe;
    endcase
  end

  always @* begin : legacy_loop
    for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1) begin
      if (data_in[bit_index]) legacy_register[bit_index] = inverted_data[bit_index];
    end
  end

  generate
    genvar generated_index;
    for (generated_index = 0; generated_index < WIDTH; generated_index = generated_index + 1) begin : generated_bits
      wire generated_bit;
      assign generated_bit = inverted_data[generated_index];
    end
  endgenerate

  assign data_out = inverted_data;
endmodule
