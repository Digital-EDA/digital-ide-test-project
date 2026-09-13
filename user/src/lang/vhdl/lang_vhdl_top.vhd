library ieee;
use ieee.std_logic_1164.all;
use work.lang_vhdl_pkg.all;

entity lang_vhdl_top is
  port (
    input_a : in  word_t;
    input_b : in  word_t;
    result  : out word_t
  );
end entity;

architecture mixed of lang_vhdl_top is
  component lang_sv_core
    generic (WIDTH : integer := WIDTH_C + 0);
    port (
      input_a : in  std_logic_vector(WIDTH - 1 downto 0);
      input_b : in  std_logic_vector(WIDTH - 1 downto 0);
      sum     : out std_logic_vector(WIDTH - 1 downto 0)
    );
  end component;

  component lang_vlog_bridge
    generic (WIDTH : integer := WIDTH_C + 0);
    port (
      data_in  : in  std_logic_vector(WIDTH - 1 downto 0);
      data_out : out std_logic_vector(WIDTH - 1 downto 0)
    );
  end component;

  signal sv_sum : word_t;
  signal vlog_sum : word_t;
begin
  u_sv_core : lang_sv_core
    generic map (WIDTH => WIDTH_C)
    port map (
      input_a => input_a,
      input_b => input_b,
      sum => sv_sum
    );

  u_vlog_bridge : lang_vlog_bridge
    generic map (WIDTH => WIDTH_C)
    port map (
      data_in => sv_sum,
      data_out => vlog_sum
    );

  u_vhdl_stage : entity work.lang_vhdl_stage(rtl)
    generic map (WIDTH => WIDTH_C)
    port map (
      data_in => vlog_sum,
      data_out => result
    );
end architecture;
