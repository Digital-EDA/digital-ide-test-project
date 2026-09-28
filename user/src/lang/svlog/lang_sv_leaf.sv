/* Rich hover regression: existing adder, documentation only.
   Second physical line must remain a separate line.
   ------
  
   **Image** (relative to this declaration file):
   ![Digital IDE](../../../../../../../extension/images/icon.png)
  
   **Port table**
  
   | Port | Direction | Meaning |
   | --- | --- | --- |
   | input_a | input | First operand |
   | input_b | input | Second operand |
   | sum | output | Sum modulo 2^WIDTH |
  
   **Lists**
  
   - Read both operands.
   - Add without adding a pipeline stage.
     - Preserve the configured WIDTH.
  
   1. Set input_a.
   2. Set input_b and observe sum.
  
   **Formula**: $s = (a+b) \bmod 2^{W}$.
  
   $$
   X[k] = \sum_{n=0}^{N-1} x[n] e^{-j 2\pi kn/N}
   $$
  
   **WaveDrom**
   ```wavedrom
{
  "head": {
    "tick": 0
  },
  "signal": [
    {
      "name": "Registers_tb.clk",
      "wave": "0101010101"
    },
    {
      "data": [
        "A",
        "F",
        "A"
      ],
      "name": "Registers_tb.Read_Data_1",
      "wave": "x..=.=.=.."
    },
    {
      "data": [
        "A"
      ],
      "name": "Registers_tb.Read_Data_2",
      "wave": "x..=......"
    },
    {
      "data": [
        "0",
        "1"
      ],
      "name": "Registers_tb.Read_Register_1",
      "wave": "=...=....."
    }
  ]
}
   ```
  
   **Flowchart** (flowchart.js notation)
   ```flowchart
   start=>start: Start
   add=>operation: Add operands
   check=>condition: Fits WIDTH?
   done=>end: Output
   wrap=>operation: Truncate
   start->add->check
   check(yes)->done
   check(no)->wrap->done
   ```
  
   **Sequence** (sequence-diagram notation)
   ```sequence
   participant TB
   participant Adder
   TB->Adder: Set operands
   Adder-->TB: Combinational sum
   Note over TB,Adder: No extra clock latency
   ```
  
   **Mermaid** (flowchart)
   ```mermaid
   flowchart LR
     A[input_a] --> ADD[Add]
     B[input_b] --> ADD
     ADD --> S[sum]
   ```
  
   **Mermaid sequence**
   ```mermaid
   sequenceDiagram
     participant TB
     participant DUT
     TB->>DUT: input_a, input_b
     DUT-->>TB: sum
   ```
*/
module lang_sv_leaf #( parameter int WIDTH = lang_sv_pkg::WIDTH
) (
    input  logic [WIDTH-1:0] input_a,input  logic [WIDTH-1:0] input_b,output logic [WIDTH-1:0] sum
);
  assign sum = input_a + input_b;
endmodule
