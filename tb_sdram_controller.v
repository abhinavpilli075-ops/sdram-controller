`timescale 1ns / 1ps

module tb_sdram_controller;

    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 16;
    localparam ADDR_WIDTH = 24;

    reg                    clk, rst_n;
    reg                    host_req, host_we;
    reg  [ADDR_WIDTH-1:0]  host_addr;
    reg  [DATA_WIDTH-1:0]  host_wdata;
    reg  [1:0]             host_be;

    wire                   host_ack;
    wire                   host_rdata_valid;
    wire [DATA_WIDTH-1:0]  host_rdata;
    wire                   sdram_cke, sdram_cs_n, sdram_ras_n;
    wire                   sdram_cas_n, sdram_we_n;
    wire [1:0]             sdram_ba, sdram_dqm;
    wire [12:0]            sdram_addr;
    wire [DATA_WIDTH-1:0]  sdram_dq;

    // Simple SDRAM model: drive dq_model onto the bus
    reg [DATA_WIDTH-1:0] sdram_dq_model;
    assign sdram_dq = sdram_dq_model;

    sdram_controller #(
        .CLK_FREQ_MHZ   (1),
        .CAS_LATENCY    (2),
        .REFRESH_CYCLES (750)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .host_req         (host_req),
        .host_we          (host_we),
        .host_addr        (host_addr),
        .host_wdata       (host_wdata),
        .host_be          (host_be),
        .host_ack         (host_ack),
        .host_rdata_valid (host_rdata_valid),
        .host_rdata       (host_rdata),
        .sdram_cke        (sdram_cke),
        .sdram_cs_n       (sdram_cs_n),
        .sdram_ras_n      (sdram_ras_n),
        .sdram_cas_n      (sdram_cas_n),
        .sdram_we_n       (sdram_we_n),
        .sdram_ba         (sdram_ba),
        .sdram_addr       (sdram_addr),
        .sdram_dq         (sdram_dq),
        .sdram_dqm        (sdram_dqm)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Timeout watchdog
    initial begin
        #2000000;
        $display("TIMEOUT - simulation exceeded time limit");
        $finish;
    end

    initial begin
        $dumpfile("sdram_tb.vcd");
        $dumpvars(0, tb_sdram_controller);

        // Initialise inputs
        sdram_dq_model = 16'hZZZZ;
        rst_n          = 0;
        host_req       = 0;
        host_we        = 0;
        host_addr      = 0;
        host_wdata     = 0;
        host_be        = 2'b11;

        // Hold reset for 5 cycles
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);

        // Wait until FSM is in S_IDLE (state = 5)
        wait (dut.state === 4'd5);
        @(posedge clk);
        $display("[%0t] FSM is IDLE - ready for transactions", $time);

        //--------------------------------------------------
        // WRITE: hold host_req HIGH until ack comes back
        //--------------------------------------------------
        $display("[%0t] Starting WRITE", $time);
        host_addr  = 24'h000100;
        host_wdata = 16'hABCD;
        host_be    = 2'b11;
        host_we    = 1;
        host_req   = 1;          // keep high until ack

        wait (host_ack === 1);   // FSM accepted the request
        @(posedge clk);
        host_req = 0;            // now safe to deassert
        $display("[%0t] Write ACK received", $time);

        // Wait for FSM to return to IDLE
        wait (dut.state === 4'd5);
        repeat(3) @(posedge clk);

        //--------------------------------------------------
        // READ: same pattern - hold req until ack
        //--------------------------------------------------
        $display("[%0t] Starting READ", $time);
        sdram_dq_model = 16'hABCD;   // SDRAM drives this data back
        host_addr = 24'h000100;
        host_we   = 0;
        host_req  = 1;               // keep high until ack

        wait (host_ack === 1);
        @(posedge clk);
        host_req = 0;
        $display("[%0t] Read ACK received", $time);

        // Wait for read data to come back through pipeline
        wait (host_rdata_valid === 1);
        $display("[%0t] Read data = 0x%04X  (expected 0xABCD)", $time, host_rdata);

        if (host_rdata === 16'hABCD)
            $display("PASS: data matches");
        else
            $display("FAIL: got 0x%04X", host_rdata);

        repeat(10) @(posedge clk);
        $display("Simulation complete.");
        $finish;
    end

endmodule