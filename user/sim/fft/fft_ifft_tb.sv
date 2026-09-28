`timescale 1ns/1ps

// Mixed-language regression for all FFT implementations in this fixture:
// the hand-written IFFT, the shared FFT/IFFT flow, and the Xilinx XFFT v9 IP.
// The Xilinx instance is a VHDL entity, so the complete test requires a
// mixed-language simulator (Vivado XSim or ModelSim/Questa).
module fft_ifft_tb;
    localparam integer FFT_STEPS = 6;
    localparam integer SAMPLES = 1 << FFT_STEPS;
    localparam integer ROUNDS = 3;
    localparam integer CASES_PER_ROUND = 4;
    localparam integer TEST_FRAMES = ROUNDS * CASES_PER_ROUND;
    localparam integer DRAIN_CYCLES = 16 * SAMPLES;
    localparam real PI = 3.14159265358979323846;

    // Each round: impulse, then cosines at bins 1, 4 and 11. All four DUTs
    // receive identical integer samples, with a zero imaginary component.
    // Change amplitude and phase between rounds; stay within 12-bit input.
    function automatic integer stimulus_value(input integer frame, input integer n);
        integer round_id, case_id, amplitude, bin_id;
        begin
            round_id = frame / CASES_PER_ROUND;
            case_id = frame % CASES_PER_ROUND;
            amplitude = 64 << round_id;
            case (case_id)
                1: bin_id = 1;
                2: bin_id = 4;
                default: bin_id = 11;
            endcase
            if (case_id == 0)
                stimulus_value = (n == 0) ? amplitude : 0;
            else
                stimulus_value = $rtoi($floor(amplitude *
                    $cos(2.0 * PI * bin_id * n / SAMPLES + round_id * PI / 4.0) + 0.5));
        end
    endfunction

    logic clk = 1'b0;
    logic user_reset = 1'b1;
    logic user_ce = 1'b0;
    logic [31:0] user_sample = 32'b0;
    wire [31:0] user_result;
    wire user_sync;

    logic lib_reset_n = 1'b0;
    logic lib_en = 1'b0;
    logic [11:0] lib_real = 12'b0;
    logic [11:0] lib_imag = 12'b0;
    wire lib_fft_en;
    wire lib_fft_sync;
    wire [11:0] lib_fft_real;
    wire [11:0] lib_fft_imag;
    wire lib_ifft_en;
    wire lib_ifft_sync;
    wire [11:0] lib_ifft_real;
    wire [11:0] lib_ifft_imag;

    logic xfft_reset_n = 1'b0;
    logic [7:0] xfft_config_data = 8'b0;
    logic xfft_config_valid = 1'b0;
    wire xfft_config_ready;
    logic [31:0] xfft_data = 32'b0;
    logic xfft_data_valid = 1'b0;
    wire xfft_data_ready;
    logic xfft_data_last = 1'b0;
    wire [47:0] xfft_output_data;
    wire xfft_output_valid;
    logic xfft_output_ready = 1'b1;
    wire xfft_output_last;
    wire xfft_event_frame_started;
    wire xfft_event_tlast_unexpected;
    wire xfft_event_tlast_missing;
    wire xfft_event_status_channel_halt;
    wire xfft_event_data_in_channel_halt;
    wire xfft_event_data_out_channel_halt;

    // Streams 0/1/2 are the user IFFT, shared FFT and shared IFFT.
    integer frame_count [0:2] = '{0, 0, 0};
    integer sample_count [0:2] = '{0, 0, 0};
    integer nonzero_count [0:2] = '{0, 0, 0};
    bit started [0:2] = '{0, 0, 0};
    integer xfft_frame_sample_count = 0;
    integer xfft_frame_count = 0;
    integer xfft_nonzero_count = 0;
    bit xfft_input_done = 0;
    integer cycle = 0;

    always #5 clk = ~clk;

    ifftmain u_user_ifft (
        .i_clk(clk),
        .i_reset(user_reset),
        .i_ce(user_ce),
        .i_sample(user_sample),
        .o_result(user_result),
        .o_sync(user_sync)
    );

    FFT_IFFT #(
        .FFT_IFFT(1),
        .ORDERING(0),
        .TOTAL_STEP(FFT_STEPS),
        .DATA_WIDTH(12)
    ) u_library_fft (
        .iclk(clk),
        .rstn(lib_reset_n),
        .ien(lib_en),
        .iReal(lib_real),
        .iImag(lib_imag),
        .oen(lib_fft_en),
        .osync(lib_fft_sync),
        .oReal(lib_fft_real),
        .oImag(lib_fft_imag)
    );

    FFT_IFFT #(
        .FFT_IFFT(0),
        .ORDERING(0),
        .TOTAL_STEP(FFT_STEPS),
        .DATA_WIDTH(12)
    ) u_library_ifft (
        .iclk(clk),
        .rstn(lib_reset_n),
        .ien(lib_en),
        .iReal(lib_real),
        .iImag(lib_imag),
        .oen(lib_ifft_en),
        .osync(lib_ifft_sync),
        .oReal(lib_ifft_real),
        .oImag(lib_ifft_imag)
    );

    // xfft_v9 is the VHDL wrapper generated from user/ip/xfft_v9/xfft_v9.xci.
    // Mixed-language simulators resolve this instance to the VHDL entity in
    // the work library; no second testbench top is needed.
    xfft_v9 u_xilinx_fft (
        .aclk(clk),
        .aresetn(xfft_reset_n),
        .s_axis_config_tdata(xfft_config_data),
        .s_axis_config_tvalid(xfft_config_valid),
        .s_axis_config_tready(xfft_config_ready),
        .s_axis_data_tdata(xfft_data),
        .s_axis_data_tvalid(xfft_data_valid),
        .s_axis_data_tready(xfft_data_ready),
        .s_axis_data_tlast(xfft_data_last),
        .m_axis_data_tdata(xfft_output_data),
        .m_axis_data_tvalid(xfft_output_valid),
        .m_axis_data_tready(xfft_output_ready),
        .m_axis_data_tlast(xfft_output_last),
        .event_frame_started(xfft_event_frame_started),
        .event_tlast_unexpected(xfft_event_tlast_unexpected),
        .event_tlast_missing(xfft_event_tlast_missing),
        .event_status_channel_halt(xfft_event_status_channel_halt),
        .event_data_in_channel_halt(xfft_event_data_in_channel_halt),
        .event_data_out_channel_halt(xfft_event_data_out_channel_halt)
    );

    // Check every sample of every requested frame, not just the first sync.
    // Zero frames used to flush the pipelines are excluded from this check.
    task automatic check_stream(input integer stream, input logic sync,
                                input logic [31:0] value);
        begin
            if (frame_count[stream] < TEST_FRAMES) begin
                if (sync === 1'b1) begin
                    if (sample_count[stream] != 0)
                        $fatal(1, "stream %0d: premature sync in frame %0d", stream, frame_count[stream]);
                    started[stream] = 1;
                end
                if (started[stream]) begin
                    if (sample_count[stream] == 0 && sync !== 1'b1)
                        $fatal(1, "stream %0d: missing frame sync", stream);
                    if (^value === 1'bx)
                        $fatal(1, "stream %0d frame %0d sample %0d: X/Z data",
                            stream, frame_count[stream], sample_count[stream]);
                    if (value != 0)
                        nonzero_count[stream] = nonzero_count[stream] + 1;
                    sample_count[stream] = sample_count[stream] + 1;
                    if (sample_count[stream] == SAMPLES) begin
                        if (nonzero_count[stream] == 0)
                            $fatal(1, "stream %0d frame %0d: all-zero output", stream, frame_count[stream]);
                        frame_count[stream] = frame_count[stream] + 1;
                        sample_count[stream] = 0;
                        nonzero_count[stream] = 0;
                    end
                end
            end
        end
    endtask

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if (!user_reset && user_ce)
            check_stream(0, user_sync, user_result);
        if (lib_reset_n && lib_fft_en)
            check_stream(1, lib_fft_sync, {8'b0, lib_fft_real, lib_fft_imag});
        if (lib_reset_n && lib_ifft_en)
            check_stream(2, lib_ifft_sync, {8'b0, lib_ifft_real, lib_ifft_imag});
        if (xfft_reset_n) begin
            if (xfft_output_valid && xfft_output_ready) begin
                if (^xfft_output_data === 1'bx)
                    $fatal(1, "Xilinx XFFT produced X/Z data at cycle %0d", cycle);
                if (xfft_frame_count >= TEST_FRAMES)
                    $fatal(1, "Xilinx XFFT produced an extra frame");
                if (xfft_output_data != 0)
                    xfft_nonzero_count = xfft_nonzero_count + 1;
                if (xfft_output_last !== (xfft_frame_sample_count == SAMPLES - 1))
                    $fatal(1, "Xilinx XFFT frame %0d: incorrect TLAST at sample %0d",
                        xfft_frame_count, xfft_frame_sample_count);
                xfft_frame_sample_count = xfft_frame_sample_count + 1;
                if (xfft_output_last) begin
                    if (xfft_nonzero_count == 0)
                        $fatal(1, "Xilinx XFFT frame %0d: all-zero output", xfft_frame_count);
                    xfft_frame_count = xfft_frame_count + 1;
                    xfft_frame_sample_count = 0;
                    xfft_nonzero_count = 0;
                end
            end
            if (xfft_event_tlast_unexpected === 1'b1 || xfft_event_tlast_missing === 1'b1)
                $fatal(1, "Xilinx XFFT reported an input TLAST error");
        end
    end

    // AXI backpressure may delay this stream relative to the other DUTs.
    // Hold each sample and TLAST until accepted; configure forward FFT once.
    initial begin : xfft_stimulus
        integer frame, n, value;
        wait (xfft_reset_n === 1'b1);
        @(negedge clk);
        xfft_config_data = 8'b1;
        xfft_config_valid = 1'b1;
        do @(posedge clk); while (xfft_config_ready !== 1'b1);
        @(negedge clk);
        xfft_config_valid = 1'b0;

        for (frame = 0; frame < TEST_FRAMES; frame = frame + 1) begin
            for (n = 0; n < SAMPLES; n = n + 1) begin
                @(negedge clk);
                value = stimulus_value(frame, n);
                xfft_data = {16'b0, value[15:0]};
                xfft_data_last = (n == SAMPLES - 1);
                xfft_data_valid = 1'b1;
                do @(posedge clk); while (xfft_data_ready !== 1'b1);
            end
        end
        @(negedge clk);
        xfft_data_valid = 1'b0;
        xfft_data_last = 1'b0;
        xfft_data = 0;
        xfft_input_done = 1;
    end

    initial begin : stimulus
        integer frame, n, value;
        repeat (4) @(posedge clk);
        // Set the first sample on the SAME edge as enabling the input, so
        // reset release does not accidentally insert a leading zero sample.
        for (frame = 0; frame < TEST_FRAMES; frame = frame + 1) begin
            $display("FFT test round %0d/%0d case %0d: %0d-point %s, amplitude=%0d",
                frame / CASES_PER_ROUND + 1, ROUNDS, frame % CASES_PER_ROUND,
                SAMPLES, (frame % CASES_PER_ROUND == 0) ? "impulse" : "cosine",
                64 << (frame / CASES_PER_ROUND));
            for (n = 0; n < SAMPLES; n = n + 1) begin
                @(negedge clk);
                user_reset = 0;
                lib_reset_n = 1;
                xfft_reset_n = 1;
                user_ce = 1;
                lib_en = 1;
                value = stimulus_value(frame, n);
                user_sample = {value[15:0], 16'b0};
                lib_real = value[11:0];
                lib_imag = 0;
            end
        end
        // Continuous-enable cores need clocked zero input to flush latency.
        @(negedge clk);
        user_sample = 0;
        lib_real = 0;
        repeat (DRAIN_CYCLES) @(negedge clk);
        user_ce = 0;
        lib_en = 0;
        wait (xfft_input_done && xfft_frame_count == TEST_FRAMES);
        repeat (8) @(negedge clk);
        for (n = 0; n < 3; n = n + 1)
            if (frame_count[n] != TEST_FRAMES)
                $fatal(1, "stream %0d: expected %0d frames, got %0d",
                    n, TEST_FRAMES, frame_count[n]);
        $display("FFT/IFFT regression passed: %0d points, %0d rounds, %0d frames per DUT; user=%0d shared_fft=%0d shared_ifft=%0d xilinx=%0d",
            SAMPLES, ROUNDS, TEST_FRAMES, frame_count[0], frame_count[1], frame_count[2], xfft_frame_count);
        $finish;
    end

    // Also covers stuck AXI config/data handshakes and missing output frames.
    initial begin : watchdog
        repeat (TEST_FRAMES * SAMPLES * 64) @(posedge clk);
        $fatal(1, "FFT/IFFT timeout: user=%0d shared_fft=%0d shared_ifft=%0d xilinx=%0d",
            frame_count[0], frame_count[1], frame_count[2], xfft_frame_count);
    end
endmodule
