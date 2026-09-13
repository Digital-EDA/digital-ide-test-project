library ieee;
use ieee.std_logic_1164.all;
use work.lang_vhdl_pkg.all;

entity lang_vhdl_stage is
  generic (WIDTH : integer := WIDTH_C + 0);
  port (
    data_in  : in  std_logic_vector(WIDTH - 1 downto 0);
    data_out : out std_logic_vector(WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of lang_vhdl_stage is
  constant MASK : std_logic_vector(WIDTH - 1 downto 0) := (others => '1');
begin
  data_out <= data_in xor MASK;
end architecture;
