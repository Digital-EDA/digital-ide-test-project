library ieee;
use ieee.std_logic_1164.all;
use work.lang_vhdl_pkg.all;

-- VHDL rich hover regression: existing inverter, documentation only.
-- Second physical line must remain a separate line.
-- ------
--
-- ![Digital IDE](../../../../../../../extension/images/icon.png)
--
-- | Port | Direction | Meaning |
-- | --- | --- | --- |
-- | data_in | in | Input word |
-- | data_out | out | Inverted word |
--
-- - Read data_in.
-- - XOR with an all-ones mask.
--
-- 1. Set data_in.
-- 2. Observe data_out.
--
-- Formula: $y = x \oplus (2^W-1)$.
--
-- ```math
-- y_i = 1 - x_i
-- ```
--
-- ```wavedrom
-- {signal: [{name: 'data_in', wave: '=.=.', data: ['00', 'FF']},
--           {name: 'data_out', wave: '=.=.', data: ['FF', '00']}]}
-- ```
--
-- ```flowchart
-- s=>start: Input
-- op=>operation: XOR mask
-- e=>end: Output
-- s->op->e
-- ```
--
-- ```sequence
-- TB->Stage: data_in
-- Stage-->TB: data_out
-- ```
--
-- ```mermaid
-- flowchart LR
--   A[data_in] --> X[XOR mask]
--   X --> B[data_out]
-- ```
entity lang_vhdl_stage is generic (WIDTH : integer := WIDTH_C + 0);
  port (
    data_in  : in  std_logic_vector(WIDTH - 1 downto 0); data_out : out std_logic_vector(WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of lang_vhdl_stage is constant MASK : std_logic_vector(WIDTH - 1 downto 0) := (others => '1');
begin
  data_out <= data_in xor MASK;
end architecture;
