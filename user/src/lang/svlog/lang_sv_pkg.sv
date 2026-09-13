package lang_sv_pkg;
  parameter int WIDTH = 8;
  typedef logic [WIDTH-1:0] word_t;
  typedef word_t alias_t;

`ifndef SYNTHESIS
  // The class is part of the language-service fixture. Vivado synthesis
  // defines SYNTHESIS and must not lower this verification-only declaration.
  class sample;
    rand int count;
    constraint count_limit { count inside {[0:255]}; }

    function new(int initial_count = 0);
      count = initial_count;
    endfunction

    virtual function void clear();
      count = 0;
    endfunction
  endclass
`endif

  function automatic word_t add_words(input word_t lhs, input word_t rhs);
    return lhs + rhs;
  endfunction
endpackage
