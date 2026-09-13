`timescale 1ns/1ps

// Mixed-language regression for all FFT implementations in this fixture:
// the hand-written IFFT, the shared FFT/IFFT flow, and the Xilinx XFFT v9 IP.
// The Xilinx instance is a VHDL entity, so the complete test requires a
// mixed-language simulator (Vivado XSim or ModelSim/Questa).
module fft_ifft_tb;
    localparam integer USER_SAMPLES = 64;
    localparam integer LIB_SAMPLES = 16;
    localparam integer XILINX_SAMPLES = 64;

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

    integer user_sync_count = 0;
    integer user_nonzero_count = 0;
    integer lib_fft_count = 0;
    integer lib_ifft_count = 0;
    integer lib_fft_sync_count = 0;
    integer lib_ifft_sync_count = 0;
    integer xfft_sample_count = 0;
    integer xfft_frame_sample_count = 0;
    integer xfft_frame_count = 0;
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
        .TOTAL_STEP(4),
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
        .TOTAL_STEP(4),
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

    always @(posedge clk) begin
        cycle <= cycle + 1;

        if (!user_reset && user_ce && user_sync)
            user_sync_count <= user_sync_count + 1;
        if (!user_reset && user_ce && user_sync && (^user_result !== 1'bx) &&
                (user_result != 32'b0))
            user_nonzero_count <= user_nonzero_count + 1;

        if (lib_fft_en) begin
            if ((^lib_fft_real === 1'bx) || (^lib_fft_imag === 1'bx))
                $fatal(1, "shared FFT produced X/Z data at cycle %0d", cycle);
            lib_fft_count <= lib_fft_count + 1;
        end
        if (lib_ifft_en) begin
            if ((^lib_ifft_real === 1'bx) || (^lib_ifft_imag === 1'bx))
                $fatal(1, "shared IFFT produced X/Z data at cycle %0d", cycle);
            lib_ifft_count <= lib_ifft_count + 1;
        end
        if (lib_fft_sync)
            lib_fft_sync_count <= lib_fft_sync_count + 1;
        if (lib_ifft_sync)
            lib_ifft_sync_count <= lib_ifft_sync_count + 1;

        if (!xfft_reset_n) begin
            xfft_sample_count <= 0;
            xfft_frame_sample_count <= 0;
            xfft_frame_count <= 0;
        end else begin
            if (xfft_output_valid && xfft_output_ready) begin
                if (^xfft_output_data === 1'bx)
                    $fatal(1, "Xilinx XFFT produced X/Z data at cycle %0d", cycle);
                xfft_sample_count <= xfft_sample_count + 1;
                xfft_frame_sample_count <= xfft_frame_sample_count + 1;
                if (xfft_output_last) begin
                    xfft_frame_count <= xfft_frame_count + 1;
                    if (xfft_frame_sample_count + 1 != XILINX_SAMPLES)
                        $fatal(1, "Xilinx XFFT output frame has unexpected length: %0d",
                            xfft_frame_sample_count + 1);
                    xfft_frame_sample_count <= 0;
                end
            end
            if (xfft_event_tlast_unexpected === 1'b1)
                $fatal(1, "Xilinx XFFT reported event_tlast_unexpected");
            if (xfft_event_tlast_missing === 1'b1)
                $fatal(1, "Xilinx XFFT reported event_tlast_missing");
        end
    end

    // Drive one 64-sample impulse frame on the Xilinx AXI-stream input. The
    // configuration beat selects a forward transform; the generated IP has a
    // fixed transform size, so no NFFT field is needed.
    initial begin : xfft_stimulus
        integer n;
        wait (xfft_reset_n === 1'b1);

        // Bit zero selects the forward transform for this generated IP.
        @(negedge clk);
        xfft_config_data = 8'b1;
        xfft_config_valid = 1'b1;
        do
            @(posedge clk);
        while (xfft_config_ready !== 1'b1);
        @(negedge clk);
        xfft_config_valid = 1'b0;
        xfft_config_data = 8'b0;

        for (n = 0; n < XILINX_SAMPLES; n = n + 1) begin
            @(negedge clk);
            if (n == 0)
                xfft_data = {16'sd0, 16'sd1024};
            else
                xfft_data = 32'b0;
            xfft_data_last = (n == XILINX_SAMPLES - 1);
            xfft_data_valid = 1'b1;
            do
                @(posedge clk);
            while (xfft_data_ready !== 1'b1);
        end
        @(negedge clk);
        xfft_data_valid = 1'b0;
        xfft_data_last = 1'b0;
        xfft_data = 32'b0;
    end

    initial begin : stimulus
        integer n;

        repeat (4) @(posedge clk);
        @(negedge clk);
        user_reset = 1'b0;
        lib_reset_n = 1'b1;
        xfft_reset_n = 1'b1;
        user_ce = 1'b1;
        lib_en = 1'b1;

        // An impulse followed by zeroes is deterministic and exercises every
        // pipeline stage without relying on a simulator-specific math model.
        for (n = 0; n < 240; n = n + 1) begin
            @(negedge clk);
            if (n == 0)
                user_sample = {16'sd1024, 16'sd0};
            else
                user_sample = 32'b0;

            if (n == 0) begin
                lib_real = 12'sd256;
                lib_imag = 12'sd0;
            end else begin
                lib_real = 12'b0;
                lib_imag = 12'b0;
            end
        end

        @(negedge clk);
        user_ce = 1'b0;
        lib_en = 1'b0;
        repeat (40) @(posedge clk);

        // Allow the Xilinx pipeline to drain while retaining a bounded
        // timeout for a broken or missing vendor model.
        for (n = 0; n < 512 && xfft_frame_count == 0; n = n + 1)
            @(posedge clk);

        if (user_sync_count == 0)
            $fatal(1, "user/src/ifft did not produce an output frame");
        if (user_nonzero_count == 0)
            $fatal(1, "user/src/ifft produced only zero output");
        if (lib_fft_sync_count == 0 || lib_ifft_sync_count == 0)
            $fatal(1, "shared FFT/ IFFT did not report a frame");
        if (lib_fft_count < LIB_SAMPLES || lib_ifft_count < LIB_SAMPLES)
            $fatal(1, "shared FFT/ IFFT produced too few samples: fft=%0d ifft=%0d",
                lib_fft_count, lib_ifft_count);
        if (xfft_frame_count == 0)
            $fatal(1, "Xilinx XFFT did not produce an output frame");
        if (xfft_sample_count < XILINX_SAMPLES)
            $fatal(1, "Xilinx XFFT produced too few output samples: %0d",
                xfft_sample_count);

        $display("XFFT v9 regression passed; FFT/IFFT regression passed: user_sync=%0d shared_fft=%0d shared_ifft=%0d xilinx_fft=%0d",
            user_sync_count, lib_fft_count, lib_ifft_count, xfft_sample_count);
        $finish;
    end
endmodule
