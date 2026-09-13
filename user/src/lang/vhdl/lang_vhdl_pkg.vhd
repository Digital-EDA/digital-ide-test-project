library ieee;
use ieee.std_logic_1164.all;

package lang_vhdl_pkg is
  constant WIDTH_C : positive := 8;
  subtype word_t is std_logic_vector(WIDTH_C - 1 downto 0);

  function add_bias(value : word_t) return word_t;
end package;

package body lang_vhdl_pkg is
  function add_bias(value : word_t) return word_t is
  begin
    return value;
  end function;
end package body;
