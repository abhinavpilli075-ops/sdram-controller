`timescale 1ns / 1ps

module sdram_controller #(
    parameter CLK_FREQ_MHZ   = 1,
    parameter CAS_LATENCY    = 2,
    parameter T_RC           = 9,
    parameter T_RCD          = 2,
    parameter T_RP           = 2,
    parameter T_WR           = 2,
    parameter T_MRD          = 2,
    parameter REFRESH_CYCLES = 750,
    parameter SDRAM_DATA_WIDTH = 16,
    parameter SDRAM_ADDR_WIDTH = 13,
    parameter SDRAM_COL_WIDTH  = 9,
    parameter SDRAM_ROW_WIDTH  = 13,
    parameter SDRAM_BANK_WIDTH = 2,
    parameter HOST_ADDR_WIDTH  = 24
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        host_req,
    input  wire                        host_we,
    input  wire [HOST_ADDR_WIDTH-1:0]  host_addr,
    input  wire [SDRAM_DATA_WIDTH-1:0] host_wdata,
    input  wire [1:0]                  host_be,
    output reg                         host_ack,
    output reg                         host_rdata_valid,
    output reg  [SDRAM_DATA_WIDTH-1:0] host_rdata,
    output reg                         sdram_cke,
    output reg                         sdram_cs_n,
    output reg                         sdram_ras_n,
    output reg                         sdram_cas_n,
    output reg                         sdram_we_n,
    output reg  [SDRAM_BANK_WIDTH-1:0] sdram_ba,
    output reg  [SDRAM_ADDR_WIDTH-1:0] sdram_addr,
    inout  wire [SDRAM_DATA_WIDTH-1:0] sdram_dq,
    output reg  [1:0]                  sdram_dqm
);

    localparam CMD_NOP       = 4'b0111;
    localparam CMD_ACTIVE    = 4'b0011;
    localparam CMD_READ      = 4'b0101;
    localparam CMD_WRITE     = 4'b0100;
    localparam CMD_PRECHARGE = 4'b0010;
    localparam CMD_REFRESH   = 4'b0001;
    localparam CMD_LOAD_MODE = 4'b0000;

    localparam S_INIT_WAIT = 4'd0;
    localparam S_INIT_PRE  = 4'd1;
    localparam S_INIT_REF1 = 4'd2;
    localparam S_INIT_REF2 = 4'd3;
    localparam S_INIT_MRS  = 4'd4;
    localparam S_IDLE      = 4'd5;
    localparam S_REFRESH   = 4'd6;
    localparam S_ACTIVE    = 4'd7;
    localparam S_READ      = 4'd8;
    localparam S_WRITE     = 4'd9;

    reg [3:0]  state;
    reg [15:0] init_timer;
    reg [9:0]  refresh_timer;
    reg [3:0]  cmd_timer;
    reg        refresh_req;

    wire [SDRAM_BANK_WIDTH-1:0] req_bank = host_addr[HOST_ADDR_WIDTH-1 : HOST_ADDR_WIDTH-SDRAM_BANK_WIDTH];
    wire [SDRAM_ROW_WIDTH-1:0]  req_row  = host_addr[HOST_ADDR_WIDTH-SDRAM_BANK_WIDTH-1 : SDRAM_COL_WIDTH];
    wire [SDRAM_COL_WIDTH-1:0]  req_col  = host_addr[SDRAM_COL_WIDTH-1:0];

    reg                          dq_oe;
    reg  [SDRAM_DATA_WIDTH-1:0]  dq_out;
    assign sdram_dq = dq_oe ? dq_out : {SDRAM_DATA_WIDTH{1'bz}};

    reg  [SDRAM_DATA_WIDTH-1:0]  rd_pipe [0:3];
    reg  [3:0]                   rd_valid_pipe;
    reg  [SDRAM_DATA_WIDTH-1:0]  wr_data_lat;
    reg  [1:0]                   wr_be_lat;
    reg                          wr_pending;

    localparam INIT_WAIT_CYCLES = 200 * CLK_FREQ_MHZ;

    // Refresh timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_timer <= 0;
            refresh_req   <= 0;
        end else begin
            if (state == S_REFRESH)
                refresh_req <= 0;
            else if (refresh_timer == REFRESH_CYCLES - 1) begin
                refresh_timer <= 0;
                refresh_req   <= 1;
            end else
                refresh_timer <= refresh_timer + 1;
        end
    end

    // Init timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            init_timer <= INIT_WAIT_CYCLES[15:0];
        else if (init_timer != 0)
            init_timer <= init_timer - 1;
    end

    // Command timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_timer <= 0;
        else if (cmd_timer != 0)
            cmd_timer <= cmd_timer - 1;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_INIT_WAIT;
            host_ack         <= 0;
            host_rdata_valid <= 0;
            dq_oe            <= 0;
            sdram_cke        <= 1;
            sdram_cs_n       <= 1;
            sdram_ras_n      <= 1;
            sdram_cas_n      <= 1;
            sdram_we_n       <= 1;
            sdram_ba         <= 0;
            sdram_addr       <= 0;
            sdram_dqm        <= 2'b11;
            rd_valid_pipe    <= 0;
            wr_pending       <= 0;
        end else begin

            // Defaults every cycle
            sdram_cs_n  <= 0;
            sdram_ras_n <= 1;
            sdram_cas_n <= 1;
            sdram_we_n  <= 1;
            host_ack    <= 0;
            dq_oe       <= 0;

            // Shift read pipeline
            rd_valid_pipe <= {rd_valid_pipe[2:0], 1'b0};
            rd_pipe[0]    <= sdram_dq;
            rd_pipe[1]    <= rd_pipe[0];
            rd_pipe[2]    <= rd_pipe[1];
            rd_pipe[3]    <= rd_pipe[2];

            // Read data output
            if (rd_valid_pipe[CAS_LATENCY]) begin
                host_rdata       <= rd_pipe[CAS_LATENCY-1];
                host_rdata_valid <= 1;
            end else
                host_rdata_valid <= 0;

            case (state)

                S_INIT_WAIT: begin
                    sdram_cs_n <= 1;
                    sdram_dqm  <= 2'b11;
                    if (init_timer == 0) begin
                        state       <= S_INIT_PRE;
                        sdram_cs_n  <= 0;
                        sdram_ras_n <= 0;
                        sdram_we_n  <= 0;
                        sdram_addr  <= 13'b0010000000000;
                        cmd_timer   <= T_RP;
                    end
                end

                S_INIT_PRE: begin
                    if (cmd_timer == 0) begin
                        state       <= S_INIT_REF1;
                        sdram_ras_n <= 0;
                        sdram_cas_n <= 0;
                        cmd_timer   <= T_RC;
                    end
                end

                S_INIT_REF1: begin
                    if (cmd_timer == 0) begin
                        state       <= S_INIT_REF2;
                        sdram_ras_n <= 0;
                        sdram_cas_n <= 0;
                        cmd_timer   <= T_RC;
                    end
                end

                S_INIT_REF2: begin
                    if (cmd_timer == 0) begin
                        state       <= S_INIT_MRS;
                        sdram_ras_n <= 0;
                        sdram_cas_n <= 0;
                        sdram_we_n  <= 0;
                        sdram_addr  <= 13'b0000000100000;
                        sdram_ba    <= 0;
                        cmd_timer   <= T_MRD;
                    end
                end

                S_INIT_MRS: begin
                    if (cmd_timer == 0)
                        state <= S_IDLE;
                end

                S_IDLE: begin
                    sdram_dqm <= 2'b11;
                    if (refresh_req) begin
                        state       <= S_REFRESH;
                        sdram_ras_n <= 0;
                        sdram_cas_n <= 0;
                        cmd_timer   <= T_RC;
                    end else if (host_req) begin
                        // Latch request
                        wr_data_lat <= host_wdata;
                        wr_be_lat   <= host_be;
                        wr_pending  <= host_we;
                        host_ack    <= 1;
                        // Issue ACTIVE
                        state       <= S_ACTIVE;
                        sdram_ras_n <= 0;
                        sdram_ba    <= req_bank;
                        sdram_addr  <= {{SDRAM_ADDR_WIDTH-SDRAM_ROW_WIDTH{1'b0}}, req_row};
                        cmd_timer   <= T_RCD;
                    end
                end

                S_REFRESH: begin
                    if (cmd_timer == 0)
                        state <= S_IDLE;
                end

                S_ACTIVE: begin
                    if (cmd_timer == 0) begin
                        if (wr_pending) begin
                            state       <= S_WRITE;
                            sdram_cas_n <= 0;
                            sdram_we_n  <= 0;
                            sdram_ba    <= req_bank;
                            sdram_addr  <= {{SDRAM_ADDR_WIDTH-SDRAM_COL_WIDTH-1{1'b0}}, 1'b1, req_col};
                            dq_oe       <= 1;
                            dq_out      <= wr_data_lat;
                            sdram_dqm   <= ~wr_be_lat;
                            cmd_timer   <= T_WR + T_RP;
                        end else begin
                            state       <= S_READ;
                            sdram_cas_n <= 0;
                            sdram_ba    <= req_bank;
                            sdram_addr  <= {{SDRAM_ADDR_WIDTH-SDRAM_COL_WIDTH-1{1'b0}}, 1'b1, req_col};
                            sdram_dqm   <= 2'b00;
                            rd_valid_pipe[0] <= 1;
                            cmd_timer   <= CAS_LATENCY + 1;
                        end
                    end
                end

                S_READ: begin
                    sdram_dqm <= 2'b00;
                    if (cmd_timer == 0)
                        state <= S_IDLE;
                end

                S_WRITE: begin
                    dq_oe     <= 1;
                    dq_out    <= wr_data_lat;
                    sdram_dqm <= ~wr_be_lat;
                    if (cmd_timer == 0) begin
                        dq_oe <= 0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule