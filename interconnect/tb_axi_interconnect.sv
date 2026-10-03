`timescale 1ns/1ps
`default_nettype none

module tb_axi_interconnect;

    localparam integer S_COUNT = 3;
    localparam integer M_COUNT = 10;
    localparam integer DATA_WIDTH = 32;
    localparam integer ADDR_WIDTH = 32;
    localparam integer STRB_WIDTH = 4;
    localparam integer ID_WIDTH = 8;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    // AXI slave-side signals: S00, S01, S02
    reg  [S_COUNT*ID_WIDTH-1:0]    s_awid;
    reg  [S_COUNT*ADDR_WIDTH-1:0]  s_awaddr;
    reg  [S_COUNT*8-1:0]            s_awlen;
    reg  [S_COUNT*3-1:0]            s_awsize;
    reg  [S_COUNT*2-1:0]            s_awburst;
    reg  [S_COUNT-1:0]              s_awlock;
    reg  [S_COUNT*4-1:0]            s_awcache;
    reg  [S_COUNT*3-1:0]            s_awprot;
    reg  [S_COUNT*4-1:0]            s_awqos;
    reg  [S_COUNT-1:0]              s_awvalid;
    wire [S_COUNT-1:0]              s_awready;

    reg  [S_COUNT*DATA_WIDTH-1:0]   s_wdata;
    reg  [S_COUNT*STRB_WIDTH-1:0]   s_wstrb;
    reg  [S_COUNT-1:0]              s_wlast;
    reg  [S_COUNT-1:0]              s_wvalid;
    wire [S_COUNT-1:0]              s_wready;

    wire [S_COUNT*ID_WIDTH-1:0]     s_bid;
    wire [S_COUNT*2-1:0]            s_bresp;
    wire [S_COUNT-1:0]              s_bvalid;
    reg  [S_COUNT-1:0]              s_bready;

    reg  [S_COUNT*ID_WIDTH-1:0]     s_arid;
    reg  [S_COUNT*ADDR_WIDTH-1:0]   s_araddr;
    reg  [S_COUNT*8-1:0]            s_arlen;
    reg  [S_COUNT*3-1:0]            s_arsize;
    reg  [S_COUNT*2-1:0]            s_arburst;
    reg  [S_COUNT-1:0]              s_arlock;
    reg  [S_COUNT*4-1:0]            s_arcache;
    reg  [S_COUNT*3-1:0]            s_arprot;
    reg  [S_COUNT*4-1:0]            s_arqos;
    reg  [S_COUNT-1:0]              s_arvalid;
    wire [S_COUNT-1:0]              s_arready;

    wire [S_COUNT*ID_WIDTH-1:0]     s_rid;
    wire [S_COUNT*DATA_WIDTH-1:0]   s_rdata;
    wire [S_COUNT*2-1:0]            s_rresp;
    wire [S_COUNT-1:0]              s_rlast;
    wire [S_COUNT-1:0]              s_rvalid;
    reg  [S_COUNT-1:0]              s_rready;

    // AXI master-side signals: M00..M09
    wire [M_COUNT*ID_WIDTH-1:0]     m_awid;
    wire [M_COUNT*ADDR_WIDTH-1:0]   m_awaddr;
    wire [M_COUNT*8-1:0]            m_awlen;
    wire [M_COUNT*3-1:0]            m_awsize;
    wire [M_COUNT*2-1:0]            m_awburst;
    wire [M_COUNT-1:0]              m_awlock;
    wire [M_COUNT*4-1:0]            m_awcache;
    wire [M_COUNT*3-1:0]            m_awprot;
    wire [M_COUNT*4-1:0]            m_awqos;
    wire [M_COUNT*4-1:0]            m_awregion;
    wire [M_COUNT-1:0]              m_awvalid;
    reg  [M_COUNT-1:0]              m_awready;

    wire [M_COUNT*DATA_WIDTH-1:0]   m_wdata;
    wire [M_COUNT*STRB_WIDTH-1:0]   m_wstrb;
    wire [M_COUNT-1:0]              m_wlast;
    wire [M_COUNT-1:0]              m_wvalid;
    reg  [M_COUNT-1:0]              m_wready;

    reg  [M_COUNT*ID_WIDTH-1:0]     m_bid;
    reg  [M_COUNT*2-1:0]            m_bresp;
    reg  [M_COUNT-1:0]              m_bvalid;
    wire [M_COUNT-1:0]              m_bready;

    wire [M_COUNT*ID_WIDTH-1:0]     m_arid;
    wire [M_COUNT*ADDR_WIDTH-1:0]   m_araddr;
    wire [M_COUNT*8-1:0]            m_arlen;
    wire [M_COUNT*3-1:0]            m_arsize;
    wire [M_COUNT*2-1:0]            m_arburst;
    wire [M_COUNT-1:0]              m_arlock;
    wire [M_COUNT*4-1:0]            m_arcache;
    wire [M_COUNT*3-1:0]            m_arprot;
    wire [M_COUNT*4-1:0]            m_arqos;
    wire [M_COUNT*4-1:0]            m_arregion;
    wire [M_COUNT-1:0]              m_arvalid;
    reg  [M_COUNT-1:0]              m_arready;

    reg  [M_COUNT*ID_WIDTH-1:0]     m_rid;
    reg  [M_COUNT*DATA_WIDTH-1:0]   m_rdata;
    reg  [M_COUNT*2-1:0]            m_rresp;
    reg  [M_COUNT-1:0]              m_rlast;
    reg  [M_COUNT-1:0]              m_rvalid;
    wire [M_COUNT-1:0]              m_rready;

    axi_interconnect #(
        .S_COUNT(S_COUNT),
        .M_COUNT(M_COUNT),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .M_REGIONS(1),
        .M_BASE_ADDR(0),
        .M_ADDR_WIDTH({10{32'd24}})
    ) dut (
        .clk(clk), .rst(rst),
        .s_axi_awid(s_awid), .s_axi_awaddr(s_awaddr), .s_axi_awlen(s_awlen),
        .s_axi_awsize(s_awsize), .s_axi_awburst(s_awburst), .s_axi_awlock(s_awlock),
        .s_axi_awcache(s_awcache), .s_axi_awprot(s_awprot), .s_axi_awqos(s_awqos),
        .s_axi_awuser({S_COUNT{1'b0}}), .s_axi_awvalid(s_awvalid), .s_axi_awready(s_awready),
        .s_axi_wdata(s_wdata), .s_axi_wstrb(s_wstrb), .s_axi_wlast(s_wlast),
        .s_axi_wuser({S_COUNT{1'b0}}), .s_axi_wvalid(s_wvalid), .s_axi_wready(s_wready),
        .s_axi_bid(s_bid), .s_axi_bresp(s_bresp), .s_axi_buser(), .s_axi_bvalid(s_bvalid), .s_axi_bready(s_bready),
        .s_axi_arid(s_arid), .s_axi_araddr(s_araddr), .s_axi_arlen(s_arlen),
        .s_axi_arsize(s_arsize), .s_axi_arburst(s_arburst), .s_axi_arlock(s_arlock),
        .s_axi_arcache(s_arcache), .s_axi_arprot(s_arprot), .s_axi_arqos(s_arqos),
        .s_axi_aruser({S_COUNT{1'b0}}), .s_axi_arvalid(s_arvalid), .s_axi_arready(s_arready),
        .s_axi_rid(s_rid), .s_axi_rdata(s_rdata), .s_axi_rresp(s_rresp), .s_axi_rlast(s_rlast),
        .s_axi_ruser(), .s_axi_rvalid(s_rvalid), .s_axi_rready(s_rready),
        .m_axi_awid(m_awid), .m_axi_awaddr(m_awaddr), .m_axi_awlen(m_awlen), .m_axi_awsize(m_awsize),
        .m_axi_awburst(m_awburst), .m_axi_awlock(m_awlock), .m_axi_awcache(m_awcache), .m_axi_awprot(m_awprot),
        .m_axi_awqos(m_awqos), .m_axi_awregion(m_awregion), .m_axi_awuser(), .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb), .m_axi_wlast(m_wlast), .m_axi_wuser(), .m_axi_wvalid(m_wvalid), .m_axi_wready(m_wready),
        .m_axi_bid(m_bid), .m_axi_bresp(m_bresp), .m_axi_buser({M_COUNT{1'b0}}), .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_arid(m_arid), .m_axi_araddr(m_araddr), .m_axi_arlen(m_arlen), .m_axi_arsize(m_arsize),
        .m_axi_arburst(m_arburst), .m_axi_arlock(m_arlock), .m_axi_arcache(m_arcache), .m_axi_arprot(m_arprot),
        .m_axi_arqos(m_arqos), .m_axi_arregion(m_arregion), .m_axi_aruser(), .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rid(m_rid), .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp), .m_axi_rlast(m_rlast), .m_axi_ruser({M_COUNT{1'b0}}),
        .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready)
    );

    // All master ports are always able to accept a transaction.
    // Only M00 and M01 generate responses in this first testbench.
    always @* begin
        m_awready = {M_COUNT{1'b1}};
        m_wready  = {M_COUNT{1'b1}};
        m_arready = {M_COUNT{1'b1}};
    end

    // Simple M00..M09 memory/peripheral response model.
    // For this first test, the selected master returns a fixed read value and OKAY write response.
    integer k;
    always @(posedge clk) begin
        if (rst) begin
            m_bvalid <= 0;
            m_rvalid <= 0;
            m_bid    <= 0;
            m_bresp  <= 0;
            m_rid    <= 0;
            m_rdata  <= 0;
            m_rresp  <= 0;
            m_rlast  <= 0;
        end else begin
            for (k = 0; k < M_COUNT; k = k + 1) begin
                if (m_bvalid[k] && m_bready[k])
                    m_bvalid[k] <= 1'b0;
                if (m_rvalid[k] && m_rready[k])
                    m_rvalid[k] <= 1'b0;
            end

            for (k = 0; k < M_COUNT; k = k + 1) begin
                if (m_awvalid[k] && m_awready[k] && m_wvalid[k] && m_wready[k]) begin
                    m_bvalid[k] <= 1'b1;
                    m_bid[k*ID_WIDTH +: ID_WIDTH] <= m_awid[k*ID_WIDTH +: ID_WIDTH];
                    m_bresp[k*2 +: 2] <= 2'b00;
                    $display("%0t WRITE accepted at M%0d addr=%h data=%h", $time, k,
                             m_awaddr[k*ADDR_WIDTH +: ADDR_WIDTH], m_wdata[k*DATA_WIDTH +: DATA_WIDTH]);
                end
                if (m_arvalid[k] && m_arready[k]) begin
                    m_rvalid[k] <= 1'b1;
                    m_rid[k*ID_WIDTH +: ID_WIDTH] <= m_arid[k*ID_WIDTH +: ID_WIDTH];
                    m_rdata[k*DATA_WIDTH +: DATA_WIDTH] <= 32'hA5000000 + k;
                    m_rresp[k*2 +: 2] <= 2'b00;
                    m_rlast[k] <= 1'b1;
                    $display("%0t READ accepted at M%0d addr=%h", $time, k,
                             m_araddr[k*ADDR_WIDTH +: ADDR_WIDTH]);
                end
            end
        end
    end

    task automatic axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_awid[0 +: ID_WIDTH] = 8'h01;
            s_awaddr[0 +: ADDR_WIDTH] = addr;
            s_awlen[0 +: 8] = 0;
            s_awsize[0 +: 3] = 3'd2;
            s_awburst[0 +: 2] = 2'b01;
            s_awlock[0] = 0;
            s_awcache[0 +: 4] = 0;
            s_awprot[0 +: 3] = 0;
            s_awqos[0 +: 4] = 0;
            s_awvalid[0] = 1;
            s_wdata[0 +: DATA_WIDTH] = data;
            s_wstrb[0 +: STRB_WIDTH] = 4'hF;
            s_wlast[0] = 1;
            s_wvalid[0] = 1;
            while (!(s_awready[0] && s_wready[0])) @(posedge clk);
            @(posedge clk);
            s_awvalid[0] = 0;
            s_wvalid[0] = 0;
            while (!s_bvalid[0]) @(posedge clk);
            @(posedge clk);
            $display("%0t WRITE response from interconnect: BRESP=%b", $time, s_bresp[0 +: 2]);
        end
    endtask

    task automatic axi_read(input [31:0] addr);
        begin
            @(posedge clk);
            s_arid[0 +: ID_WIDTH] = 8'h02;
            s_araddr[0 +: ADDR_WIDTH] = addr;
            s_arlen[0 +: 8] = 0;
            s_arsize[0 +: 3] = 3'd2;
            s_arburst[0 +: 2] = 2'b01;
            s_arlock[0] = 0;
            s_arcache[0 +: 4] = 0;
            s_arprot[0 +: 3] = 0;
            s_arqos[0 +: 4] = 0;
            s_arvalid[0] = 1;
            while (!s_arready[0]) @(posedge clk);
            @(posedge clk);
            s_arvalid[0] = 0;
            while (!s_rvalid[0]) @(posedge clk);
            @(posedge clk);
            $display("%0t READ response from interconnect: RDATA=%h RRESP=%b", $time,
                     s_rdata[0 +: DATA_WIDTH], s_rresp[0 +: 2]);
        end
    endtask

    initial begin
        s_awid = 0; s_awaddr = 0; s_awlen = 0; s_awsize = 0; s_awburst = 0;
        s_awlock = 0; s_awcache = 0; s_awprot = 0; s_awqos = 0; s_awvalid = 0;
        s_wdata = 0; s_wstrb = 0; s_wlast = 0; s_wvalid = 0; s_bready = 3'b111;
        s_arid = 0; s_araddr = 0; s_arlen = 0; s_arsize = 0; s_arburst = 0;
        s_arlock = 0; s_arcache = 0; s_arprot = 0; s_arqos = 0; s_arvalid = 0; s_rready = 3'b111;
        m_bid = 0; m_bresp = 0; m_bvalid = 0;
        m_rid = 0; m_rdata = 0; m_rresp = 0; m_rlast = 0; m_rvalid = 0;

        $dumpfile("axi_interconnect.vcd");
        $dumpvars(0, tb_axi_interconnect);

        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        $display("\n===== TEST 1: WRITE to M00 region =====");
        axi_write(32'h00000010, 32'h12345678);

        $display("\n===== TEST 2: READ from M00 region =====");
        axi_read(32'h00000010);

        $display("\n===== TEST 3: WRITE to M01 region =====");
        axi_write(32'h01000020, 32'hCAFEBABE);

        $display("\n===== TEST 4: READ from M01 region =====");
        axi_read(32'h01000020);

        repeat (10) @(posedge clk);
        $display("\n===== SIMULATION COMPLETE =====");
        $finish;
    end

endmodule

`default_nettype wire
