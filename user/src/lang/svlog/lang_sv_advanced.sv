`timescale 1ns/1ps

// This is a functional language-service fixture.  It deliberately combines
// the SystemVerilog constructs exercised by Slang's all.sv into one module
// that is instantiated by lang_sv_core; it is not a copied regression file.
timeunit 1ns;
timeprecision 1ps;

package lang_syntax_pkg;
  timeunit 1ns / 1ps;
  parameter int DEFAULT_WIDTH = 8;
  parameter type sample_type = logic [DEFAULT_WIDTH-1:0];
  localparam int PACKAGE_VERSION = 1;

  typedef enum logic [1:0] {PKG_IDLE, PKG_BUSY, PKG_DONE} package_state_t;
  typedef struct packed {
    logic valid;
    sample_type payload;
  } package_packet_t;
  typedef union tagged {
    void Empty;
    sample_type Value;
  } package_value_t;
  typedef sample_type package_alias_t;

  class package_item;
    rand int count;
    constraint count_range { count inside {[0:DEFAULT_WIDTH * 32]}; }
    function new(int initial_count = 0);
      count = initial_count;
    endfunction
    virtual function void clear();
      count = 0;
    endfunction
  endclass

  class generic_item #(type T = sample_type);
    T value;
    extern function T transform(T input_value);
  endclass

  function automatic sample_type add_sample(input sample_type lhs, input sample_type rhs);
    return lhs + rhs;
  endfunction

  function generic_item::T generic_item::transform(T input_value);
    return input_value;
  endfunction

  // Package export/import syntax is part of the language surface used by the
  // editor even when this fixture uses the local package directly.
  export *::*;
endpackage

import lang_syntax_pkg::*;

// The former standalone bus-interface fixture is kept on this syntax-heavy
// source so the workspace exercises interface, modport, and parameterized
// interface parsing without a second test-only file.
interface lang_bus_if #(
  parameter int BUS_WIDTH = DEFAULT_WIDTH
) (
  input logic clk
);
  logic valid;
  logic ready;
  logic [BUS_WIDTH-1:0] payload;

  modport master (
    input clk, ready,
    output valid, payload
  );

  modport slave (
    input clk, valid, payload,
    output ready
  );
endinterface

function automatic logic [DEFAULT_WIDTH-1:0] resolve_syntax_net(
  input logic [DEFAULT_WIDTH-1:0] drivers[]
);
  return drivers.size() == 0 ? '0 : drivers[0];
endfunction

nettype logic [DEFAULT_WIDTH-1:0] syntax_net with resolve_syntax_net;

extern interface lang_syntax_if(input logic clk, input logic valid, output logic ready);
extern interface lang_wildcard_if(input logic clk);

interface lang_syntax_if(input logic clk, input logic valid, output logic ready);
  logic [DEFAULT_WIDTH-1:0] payload;
  clocking cb @(posedge clk);
    default input #1step output #1step;
    input valid, payload;
    output ready;
  endclocking
  modport master(input clk, ready, output valid, payload);
  modport slave(input clk, valid, payload, output ready);
endinterface

interface lang_nested_if(input logic clk);
  interface child(input int q);
    clocking child_clock @(posedge clk); endclocking
    logic a, b;
    modport child_mp(input q, output b);
  endinterface
  child child_instance(1);
endinterface

interface lang_wildcard_if(.*);
  logic wildcard_signal;
endinterface

interface lang_method_if;
  function void foo(int value, real scale);
  endfunction
  extern forkjoin task t3();
  modport methods(export foo, task t3);
endinterface

module lang_port_forms #(
  parameter int PORT_WIDTH = DEFAULT_WIDTH,
  parameter type PORT_T = logic
) (
  input int values[],
  (* port_attribute = "fixture" *) output logic status,
  ref PORT_T reference_value,
  lang_syntax_if.master bus
);
  assign status = bus.valid && (reference_value == reference_value);
endmodule

module automatic lang_imported_module import lang_syntax_pkg::*, lang_syntax_pkg::DEFAULT_WIDTH;
  #(parameter int IMPORT_WIDTH = DEFAULT_WIDTH)
  (input logic [IMPORT_WIDTH-1:0] value, output logic [IMPORT_WIDTH-1:0] result);
  assign result = value;
endmodule

extern macromodule lang_legacy_macro(input logic a, output logic y);

macromodule lang_legacy_macro(input logic a, output logic y);
  assign y = ~a;
endmodule

extern primitive lang_ext_udp(output q, input d, input clk);

primitive lang_ext_udp(output q, input d, input clk);
  table
    0  0 : 0;
    1  0 : 1;
  endtable
endprimitive

extern program lang_external_program(input logic clk, input logic d);

program lang_external_program(input logic clk, input logic d);
  initial @(posedge clk) $display("program=%0d", d);
endprogram

extern primitive lang_reg_udp(output reg q, input d);

primitive lang_reg_udp(output reg q, input d);
  initial q = 1'b0;
  table
    0 : ? : 0;
    1 : 0 : 1;
  endtable
endprimitive

(* fixture = "mixed-language" *)
module lang_sv_advanced #(
  parameter int WIDTH = DEFAULT_WIDTH,
  parameter type DATA_T = logic [WIDTH-1:0],
  localparam int LAST = WIDTH - 1
) (
  input logic clk,
  input logic reset,
  input DATA_T data_in,
  output logic [WIDTH-1:0] data_out
);
  typedef enum logic [1:0] {IDLE, ACTIVE, COMPLETE} state_t;
  typedef struct packed {
    logic valid;
    logic [WIDTH-1:0] payload;
  } packet_t;
  typedef union packed {
    logic [WIDTH:0] bits;
    packet_t packet;
  } packet_union_t;
  typedef union tagged {
    void Invalid;
    int Valid;
  } tagged_value_t;
  typedef lang_syntax_pkg::sample_type qualified_sample_t;

  state_t state;
  packet_t packet;
  packet_union_t packed_view;
  tagged_value_t tagged_value;
  DATA_T storage [0:3];
  DATA_T dynamic_storage[];
  DATA_T queue_storage[$:3];
  logic [1:0] matrix [0:1][0:1];
  logic event_signal;
  logic macro_out;
  logic ready_signal;
  logic procedural_signal;
  logic wildcard_signal;
  logic [WIDTH-1:0] latch_value;
  logic [WIDTH-1:0] udp_out;
  logic [WIDTH-1:0] bound_result;
  logic [WIDTH-1:0] sequence_value;
  logic let_result;
  wire pull_net;
  logic port_status;
  logic port_reference;
  int port_values[0:1];
  event syntax_event;
  chandle foreign_handle;
  realtime timestamp[*];
  virtual interface lang_syntax_if virtual_bus;
  integer loop_index;
  wor [WIDTH-1:0] wired_or;
  wor [WIDTH-1:0] alias_net;
  syntax_net resolved_data;
  trireg (large) logic #(0, 0, 0) capacitive_net;

  // Generate for/if/case forms, including named scopes and nested declarations.
  genvar g;
  generate
    for (g = 0; g < WIDTH; g += 1) begin : generated_bits
      logic generated_value;
      assign generated_value = data_in[g] ^ reset;
    end
    if (WIDTH > 4) begin : generated_wide
      logic wide_value;
      assign wide_value = &data_in;
    end else begin : generated_narrow
      logic narrow_value;
      assign narrow_value = |data_in;
    end
    case (WIDTH)
      1: begin : generated_one assign wired_or = data_in; end
      default: begin : generated_many assign wired_or = data_in; end
    endcase
    for (genvar inline_g = 0; inline_g < 1; inline_g++) begin : inline_generate
      logic inline_value;
      assign inline_value = data_in[0];
    end
  endgenerate

  assign (supply0, weak1) #(1:2:3, 2:3:4) capacitive_net = data_in[0];
  assign resolved_data = data_in;
  rcmos #1step (event_signal, data_in[0], data_in[1], udp_out[0]);
  alias {wired_or} = alias_net;

  lang_legacy_macro u_macro(.a(data_in[0]), .y(macro_out));
  lang_ext_udp u_udp(udp_out[0], data_in[0], clk);
  lang_syntax_if syntax_bus(.clk(clk), .valid(macro_out), .ready(ready_signal));
  lang_nested_if nested_bus(clk);
  lang_method_if method_bus();
  lang_port_forms #(.PORT_WIDTH(WIDTH)) u_port_forms(
    .values(port_values),
    .status(port_status),
    .reference_value(port_reference),
    .bus(syntax_bus)
  );
  defparam u_port_forms.PORT_WIDTH = WIDTH;
  pullup (strong1) pull_signal(pull_net);

  function automatic DATA_T add_data(input DATA_T lhs, input DATA_T rhs);
    return lhs + rhs;
  endfunction

  task automatic capture(input DATA_T next_value);
    storage[0] = next_value;
  endtask

  always_ff @(posedge clk iff !reset) begin
    state <= ACTIVE;
    packet.valid <= 1'b1;
    packet.payload <= data_in;
    foreach (storage[index]) storage[index] <= data_in;
  end

  always_comb begin : combinational_logic
    packed_view.packet = packet;
    data_out = add_data(packed_view.packet.payload, '0);
      unique0 casez (state)
      IDLE: data_out = data_in;
      ACTIVE: data_out = packet.payload;
      default: data_out = '0;
    endcase
  end : combinational_logic

  always_latch begin
    if (!clk) latch_value <= data_in;
  end

  initial begin : procedural_examples
    byte q, r, x;
    q = 0;
    r = 1;
    repeat (2) @(negedge clk) x = #1 q + r;
    wait (event_signal) ++q;
    wait fork;
    wait_order (syntax_event) q++;
    fork : worker_fork
      automatic int worker = 1;
      begin -> syntax_event; end
    join_none
    disable worker_fork;
    disable fork;
    assign procedural_signal = 1'b1;
    deassign procedural_signal;
    force procedural_signal = 1'b0;
    release procedural_signal;
    if (q) begin end else begin end
    case (q) inside
      [0:2]: x = q;
      default: x = r;
    endcase
    unique0 casex (q)
      8'b0?: x = 0;
      default: x = 1;
    endcase
    case (tagged_value) matches
      tagged Invalid: x = 0;
      tagged Valid .value: x = value[0];
      default: x = 0;
    endcase
    if (tagged_value matches (tagged Valid .value) &&& event_signal)
      x = value[0];
    x <= #1step 1;
    x <= repeat (1) @(syntax_event) 1;
    randcase
      q + 1: x = 1;
      r + 1: x = 2;
      1: x = 3;
    endcase
  end

  always @(posedge clk) begin : loop_examples
    forever begin
      break;
    end
    repeat (2) continue;
    while (loop_index < WIDTH) loop_index++;
    for (int i = 0, j = 0; i < WIDTH; i++, j += i) begin end
    foreach (matrix[row, col]) matrix[row][col] = data_in;
  end : loop_examples

  always @* begin : wildcard_process
    wildcard_signal = ^data_in;
  end : wildcard_process

  clocking bus_clock @(posedge clk);
    default input #1step output #1step;
    input data_in;
    output data_out;
  endclocking
  clocking edge_clock @(event_signal or clk);
    default input posedge #3ps;
    input data_in;
  endclocking
  default clocking bus_clock;
  default disable iff reset;
  global clocking global_bus_clock @(posedge clk); endclocking

  sequence active_sequence;
    @(posedge clk) !reset ##1 state == ACTIVE;
  endsequence

  property reset_to_idle;
    @(posedge clk) reset |=> state == IDLE;
  endproperty

  property data_progress;
    @(posedge clk) state == ACTIVE |-> ##1 state == COMPLETE;
  endproperty

  property rich_temporal(logic a, logic b);
    int local_a, local_b;
    @(posedge clk)
      strong((a, local_a = 1) intersect first_match(b, local_b = 2))
      and not sync_accept_on(reset)
      (a throughout b or event_signal)
      implies (a iff always[1:2] b
        until a s_until b s_until_with a until_with b);
  endproperty

  assert property (reset_to_idle) else $error("reset did not clear state");
  assume property (data_progress);
  cover property (@(posedge clk) active_sequence);
  cover sequence (active_sequence);
  restrict property (@(posedge clk) event_signal);

  assertion_label: assert #0 (1 == 1) else $display("assertion example");
  assumption_label: assume final (1 == 1) else $display("assumption example");
  cover #0 (1 == 1);

  checker lang_checker(logic expression, event clock = $inferred_clock);
    default clocking @clock; endclocking
    a_checker: assert property (expression) else $error("checker failed");
  endchecker

  lang_checker u_checker(event_signal, clk);

  covergroup syntax_coverage @(posedge clk);
    option.comment = "language fixture";
    state_cp: coverpoint state {
      bins idle = {IDLE};
      bins active = {ACTIVE};
      bins complete = {COMPLETE};
    }
    data_cp: coverpoint data_in {
      wildcard bins low_data = {[0:3]};
      bins data_values[] = {[4:7]};
    }
    state_data: cross state_cp, data_cp;
  endgroup
  syntax_coverage coverage_inst = new;

  function void sample_event();
  endfunction

  covergroup event_coverage @@(begin sample_event or end sample_event);
  endgroup

  covergroup sampled_coverage with function sample();
  endgroup

  initial begin
    dynamic_storage = new[WIDTH];
    queue_storage.push_back(data_in);
    {<< byte{dynamic_storage with [0 +: WIDTH]}} = queue_storage;
    tagged_value = tagged Valid 1;
    if (type(dynamic_storage) == type(queue_storage)) $display("types match");
    $display("width=%0d", $bits(data_out));
    ##(2 + 1) loop_index <= 1;
    ->> syntax_event;
    expect (@(posedge clk) event_signal);
    randsequence(main)
      main : first second;
      first : add | subtract := (1 + 1);
      second : repeat (2) first;
      add : { sequence_value = data_in; };
      subtract : { sequence_value = data_in - 1; };
    endsequence
  end

  let same_value(x, y = data_in) = x == y;
  assign let_result = same_value(data_in[LAST]);

  final begin
    sequence_value = sequence_value + 1;
    sequence_value = sequence_value - 1;
    sequence_value = sequence_value * 1;
    sequence_value = sequence_value / 1;
    sequence_value = sequence_value % 2;
    sequence_value = sequence_value ** 1;
    sequence_value = sequence_value << 1;
    sequence_value = sequence_value >>> 1;
    sequence_value += 1;
    sequence_value -= 1;
    sequence_value *= 1;
    sequence_value /= 1;
    sequence_value %= 2;
    sequence_value = sequence_value === data_in;
    sequence_value = sequence_value !== data_in;
    sequence_value = sequence_value ==? data_in;
    sequence_value = sequence_value !=? data_in;
    sequence_value = ~^sequence_value;
  end
endmodule

// These declarations came from the former standalone feature fixture.  They
// intentionally remain a separate module inside this shared source file so
// the parser sees the complete always/generate/enum/struct/SVA surface while
// the real adder path continues to use lang_sv_advanced above.
module lang_sv_feature_probe #(
  parameter int FEATURE_WIDTH = DEFAULT_WIDTH
) (
  input logic feature_clk,
  input logic feature_reset,
  input logic [FEATURE_WIDTH-1:0] feature_in,
  output logic [FEATURE_WIDTH-1:0] feature_out
);
  typedef enum logic [1:0] {FEATURE_IDLE, FEATURE_BUSY, FEATURE_DONE} feature_state_t;
  typedef struct packed {
    logic valid;
    logic [FEATURE_WIDTH-1:0] payload;
  } feature_packet_t;
  typedef union packed {
    logic [FEATURE_WIDTH:0] bits;
    feature_packet_t packet;
  } feature_union_t;

  feature_state_t feature_state;
  feature_packet_t feature_packet;
  feature_union_t feature_union;
  logic [FEATURE_WIDTH-1:0] feature_storage [0:3];
  logic [FEATURE_WIDTH-1:0] feature_matrix [0:1][0:1];

  genvar feature_index;
  generate
    for (feature_index = 0; feature_index < FEATURE_WIDTH; feature_index++) begin : feature_bits
      logic bit_value;
      assign bit_value = feature_in[feature_index] ^ feature_reset;
    end
    if (FEATURE_WIDTH > 4) begin : feature_wide
      logic wide_flag;
      assign wide_flag = &feature_in;
    end else begin : feature_narrow
      logic narrow_flag;
      assign narrow_flag = |feature_in;
    end
  endgenerate

  always_ff @(posedge feature_clk or posedge feature_reset) begin
    if (feature_reset) begin
      feature_state <= FEATURE_IDLE;
      feature_packet <= '0;
      foreach (feature_storage[index]) feature_storage[index] <= '0;
    end else begin
      unique case (feature_state)
        FEATURE_IDLE: feature_state <= FEATURE_BUSY;
        FEATURE_BUSY: feature_state <= FEATURE_DONE;
        default: feature_state <= FEATURE_IDLE;
      endcase
      feature_packet.valid <= 1'b1;
      feature_packet.payload <= feature_in;
    end
  end

  always_comb begin
    feature_union.packet = feature_packet;
    feature_out = feature_union.packet.payload;
  end

  always_latch begin
    if (!feature_clk) feature_matrix[0][0] <= feature_in;
  end

  function automatic logic feature_ready(input feature_state_t current_state);
    return current_state == FEATURE_DONE;
  endfunction

  task automatic clear_feature_storage;
    foreach (feature_storage[index]) feature_storage[index] = '0;
  endtask

  clocking feature_clock @(posedge feature_clk);
    default input #1step output #1step;
    input feature_in;
    output feature_out;
  endclocking

  sequence feature_reset_sequence;
    feature_reset ##1 !feature_reset;
  endsequence

  property feature_reset_returns_idle;
    @(posedge feature_clk) feature_reset |=> feature_state == FEATURE_IDLE;
  endproperty

  assert property (feature_reset_returns_idle);
  cover property (@(posedge feature_clk) feature_ready(feature_state));
endmodule

module lang_specify_probe(input wire a, input wire clk, output logic y);
  specify
    specparam t_setup = 1, t_hold = 2:3:4;
    if (a) (posedge clk *> y) = (t_setup, t_hold);
    $setup(posedge clk, a, t_setup);
    $hold(posedge clk, a, t_hold);
  endspecify
  assign y = a;
endmodule

module lang_nonansi_probe(clk, data, result);
  input clk;
  input [DEFAULT_WIDTH-1:0] data;
  output result;
  reg result;
  always @(posedge clk) result <= ^data;
endmodule

module lang_program_host(input logic clk, input logic data, output logic result);
  program automatic lang_program(input logic p_clk, input logic p_data, output logic p_result);
    initial begin
      @(posedge p_clk);
      p_result = p_data;
    end
  endprogram
  lang_program u_program(clk, data, result);
endmodule

module lang_external_program_host(input logic clk, input logic data);
  lang_external_program u_program(clk, data);
endmodule

bind lang_sv_advanced lang_nonansi_probe u_bound(clk, data_in[0], bound_result[0]);

config lang_syntax_config;
  design work.lang_sv_advanced;
  default liblist work;
  cell lang_sv_advanced use work.lang_sv_advanced;
endconfig

module lang_dpi_probe;
  import "DPI-C" function void lang_dpi(input int value);
  export "DPI-C" function lang_dpi_export;
  function void lang_dpi_export;
    lang_dpi(0);
  endfunction
endmodule

interface class lang_contract;
  pure virtual function void ping();
endclass

typedef class lang_forward;

class lang_forward #(parameter int P = 1);
  typedef struct {
    real scale;
    bit [P-1:0] bits;
  } payload_t;
  static function payload_t sum(payload_t values[]);
    sum.scale = 0.0;
    sum.bits = '0;
    foreach (values[index]) sum.bits += values[index].bits;
  endfunction
endclass

class lang_base;
  int id;
  function new(int value = 0);
    id = value;
  endfunction
endclass

class lang_implementation extends lang_base implements lang_contract;
  rand bit [7:0] value;
  constraint value_limit { value inside {[1:254]}; }
  function new(int value = 0);
    super.new(value);
  endfunction
  virtual function void ping();
    id = id + 1;
  endfunction
endclass

class lang_final extends lang_base;
  function :final ping();
    id = id + 1;
  endfunction
  constraint declaration_only;
endclass

class lang_static_methods;
  extern static function real measure;
endclass

function real lang_static_methods::measure;
  return 0.0;
endfunction
