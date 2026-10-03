`timescale 1ns/1ps

module axi_aes_tb;

    //============================================================
    // AXI PARAMETERS
    //============================================================
    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter C_S_AXI_ADDR_WIDTH = 6;

    //============================================================
    // CLOCK AND RESET
    //============================================================
    reg S_AXI_ACLK;
    reg S_AXI_ARESETN;

    //============================================================
    // AXI WRITE ADDRESS CHANNEL
    //============================================================
    reg  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg  [2:0]                    S_AXI_AWPROT;
    reg                           S_AXI_AWVALID;
    wire                          S_AXI_AWREADY;

    //============================================================
    // AXI WRITE DATA CHANNEL
    //============================================================
    reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                           S_AXI_WVALID;
    wire                          S_AXI_WREADY;

    //============================================================
    // AXI WRITE RESPONSE CHANNEL
    //============================================================
    wire [1:0] S_AXI_BRESP;
    wire       S_AXI_BVALID;
    reg        S_AXI_BREADY;

    //============================================================
    // AXI READ ADDRESS CHANNEL
    //============================================================
    reg  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg  [2:0]                    S_AXI_ARPROT;
    reg                           S_AXI_ARVALID;
    wire                          S_AXI_ARREADY;

    //============================================================
    // AXI READ DATA CHANNEL
    //============================================================
    wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]                    S_AXI_RRESP;
    wire                          S_AXI_RVALID;
    reg                           S_AXI_RREADY;

    //============================================================
    // EXPECTED AES VALUES
    //============================================================
    reg [127:0] expected_cipher;
    reg [127:0] received_cipher;

    //============================================================
    // CLOCK GENERATION
    // 10 ns clock period
    //============================================================
    initial begin
        S_AXI_ACLK = 1'b0;
        forever #5 S_AXI_ACLK = ~S_AXI_ACLK;
    end

    //============================================================
    // DUT
    //============================================================
    aes_axi_slave #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (

        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),

        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),

        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),

        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),

        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),

        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY)
    );

    //============================================================
    // AXI WRITE TASK
    //============================================================
    task axi_write;

        input [5:0]  address;
        input [31:0] data;

        begin

            // Write address
            @(posedge S_AXI_ACLK);

            S_AXI_AWADDR  <= address;
            S_AXI_AWPROT  <= 3'b000;
            S_AXI_AWVALID <= 1'b1;

            // Write data
            S_AXI_WDATA   <= data;
            S_AXI_WSTRB   <= 4'b1111;
            S_AXI_WVALID  <= 1'b1;

            // Wait for both address and data handshake
            while (!(S_AXI_AWREADY && S_AXI_AWVALID &&
                     S_AXI_WREADY  && S_AXI_WVALID))
                @(posedge S_AXI_ACLK);

            @(posedge S_AXI_ACLK);

            S_AXI_AWVALID <= 1'b0;
            S_AXI_WVALID  <= 1'b0;

            // Response
            S_AXI_BREADY <= 1'b1;

            while (!S_AXI_BVALID)
                @(posedge S_AXI_ACLK);

            @(posedge S_AXI_ACLK);

            S_AXI_BREADY <= 1'b0;

            if (S_AXI_BRESP != 2'b00)
                $display("AXI WRITE ERROR at address %h", address);

        end

    endtask

    //============================================================
    // AXI READ TASK
    //============================================================
    task axi_read;

        input  [5:0]  address;
        output [31:0] data;

        begin

            @(posedge S_AXI_ACLK);

            S_AXI_ARADDR  <= address;
            S_AXI_ARPROT  <= 3'b000;
            S_AXI_ARVALID <= 1'b1;

            while (!(S_AXI_ARREADY && S_AXI_ARVALID))
                @(posedge S_AXI_ACLK);

            @(posedge S_AXI_ACLK);

            S_AXI_ARVALID <= 1'b0;

            S_AXI_RREADY <= 1'b1;

            while (!S_AXI_RVALID)
                @(posedge S_AXI_ACLK);

            data = S_AXI_RDATA;

            @(posedge S_AXI_ACLK);

            S_AXI_RREADY <= 1'b0;

        end

    endtask

    //============================================================
    // TEST
    //============================================================
    reg [31:0] status_data;
    reg [31:0] read_data;

    integer i;

    initial begin
//========================================================
    // WAVEFORM DUMP
    //========================================================
    $fsdbDumpfile("axi_aes.fsdb");
    $fsdbDumpvars(0, axi_aes_tb);

        //========================================================
        // INITIAL VALUES
        //========================================================
        S_AXI_ARESETN = 1'b0;

        S_AXI_AWADDR  = 6'b0;
        S_AXI_AWPROT  = 3'b0;
        S_AXI_AWVALID = 1'b0;

        S_AXI_WDATA   = 32'b0;
        S_AXI_WSTRB   = 4'b0;
        S_AXI_WVALID  = 1'b0;

        S_AXI_BREADY  = 1'b0;

        S_AXI_ARADDR  = 6'b0;
        S_AXI_ARPROT  = 3'b0;
        S_AXI_ARVALID = 1'b0;

        S_AXI_RREADY  = 1'b0;

        expected_cipher = 128'h8e979bc71cf0fb0716eeae49f5e6c467;

        //========================================================
        // RESET
        //========================================================
        $display("");
        $display("==============================================");
        $display("       AES AXI4-LITE TEST START");
        $display("==============================================");

        repeat (5)
            @(posedge S_AXI_ACLK);

        S_AXI_ARESETN = 1'b1;

        repeat (2)
            @(posedge S_AXI_ACLK);

        //========================================================
        // WRITE AES KEY
        //
        // KEY =
        // 01A10000000000000000000000000000
        //========================================================

        $display("");
        $display("Writing AES key...");

        axi_write(6'h04, 32'h00000000);
        axi_write(6'h08, 32'h00000000);
        axi_write(6'h0C, 32'h00000000);
        axi_write(6'h10, 32'h01A10000);

        $display("KEY = 01A10000000000000000000000000000");

        //========================================================
        // WRITE PLAINTEXT
        //
        // PLAINTEXT =
        // F34481EC3CC627BACD5DC3FB08F273E6
        //========================================================

        $display("");
        $display("Writing plaintext...");

        axi_write(6'h14, 32'h08F273E6);
        axi_write(6'h18, 32'hCD5DC3FB);
        axi_write(6'h1C, 32'h3CC627BA);
        axi_write(6'h20, 32'hF34481EC);

        $display("PLAINTEXT = F34481EC3CC627BACD5DC3FB08F273E6");

        //========================================================
        // START AES
        // CONTROL[0] = LOAD
        //========================================================

        $display("");
        $display("Starting AES encryption...");

axi_write(6'h00, 32'h00000001);
        

        //========================================================
        // WAIT FOR DONE
        // CONTROL/STATUS[1] = DONE
        //========================================================

        $display("Waiting for AES DONE...");

        status_data = 32'b0;

        for (i = 0; i < 30; i = i + 1) begin

            axi_read(6'h00, status_data);

            $display("Cycle %0d : STATUS = %h", i, status_data);

            if (status_data[1] == 1'b1)
                i = 30;

        end

        //========================================================
        // READ CIPHERTEXT
        //========================================================

        $display("");
        $display("Reading ciphertext...");

        axi_read(6'h24, read_data);
        received_cipher[31:0] = read_data;

        axi_read(6'h28, read_data);
        received_cipher[63:32] = read_data;

        axi_read(6'h2C, read_data);
        received_cipher[95:64] = read_data;

        axi_read(6'h30, read_data);
        received_cipher[127:96] = read_data;

        //========================================================
        // DISPLAY RESULTS
        //========================================================

        $display("");
        $display("==============================================");
        $display("              AES RESULT");
        $display("==============================================");

        $display("Expected = %h", expected_cipher);
        $display("Received = %h", received_cipher);

        //========================================================
        // COMPARE
        //========================================================

        if (received_cipher == expected_cipher) begin

            $display("");
            $display("==============================================");
            $display("             TEST PASSED");
            $display("==============================================");

        end
        else begin

            $display("");
            $display("==============================================");
            $display("             TEST FAILED");
            $display("==============================================");

        end

        #50;

        $finish;

    end

endmodule
