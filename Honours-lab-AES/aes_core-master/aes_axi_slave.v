`timescale 1ns/1ps

module aes_axi_slave #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 6
)(
    //============================================================
    // AXI4-Lite Global Signals
    //============================================================
    input  wire                         S_AXI_ACLK,
    input  wire                         S_AXI_ARESETN,

    //============================================================
    // AXI4-Lite Write Address Channel
    //============================================================
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [2:0]                    S_AXI_AWPROT,
    input  wire                          S_AXI_AWVALID,
    output reg                           S_AXI_AWREADY,

    //============================================================
    // AXI4-Lite Write Data Channel
    //============================================================
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                          S_AXI_WVALID,
    output reg                           S_AXI_WREADY,

    //============================================================
    // AXI4-Lite Write Response Channel
    //============================================================
    output reg [1:0]                     S_AXI_BRESP,
    output reg                           S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,

    //============================================================
    // AXI4-Lite Read Address Channel
    //============================================================
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [2:0]                    S_AXI_ARPROT,
    input  wire                          S_AXI_ARVALID,
    output reg                           S_AXI_ARREADY,

    //============================================================
    // AXI4-Lite Read Data Channel
    //============================================================
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [1:0]                     S_AXI_RRESP,
    output reg                           S_AXI_RVALID,
    input  wire                          S_AXI_RREADY
);

    //============================================================
    // AXI internal registers
    //============================================================

    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_reg;

    reg aw_hold;
    reg w_hold;

    reg [C_S_AXI_ADDR_WIDTH-1:0] araddr_reg;

    //============================================================
    // AES registers
    //============================================================

    reg [127:0] key_reg;
    reg [127:0] text_in_reg;

    reg [127:0] text_out_reg;

    reg         load_reg;
    reg         done_reg;

    //============================================================
    // AES signals
    //============================================================

    wire        aes_done;
    wire [127:0] aes_text_out;

    //============================================================
    // Write strobe function
    //============================================================

    function [31:0] apply_wstrb;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0]  wstrb;

        begin

            apply_wstrb = old_data;

            if (wstrb[0])
                apply_wstrb[7:0] = new_data[7:0];

            if (wstrb[1])
                apply_wstrb[15:8] = new_data[15:8];

            if (wstrb[2])
                apply_wstrb[23:16] = new_data[23:16];

            if (wstrb[3])
                apply_wstrb[31:24] = new_data[31:24];

        end
    endfunction

    //============================================================
    // AXI WRITE ADDRESS and DATA HANDLING
    //============================================================

    always @(posedge S_AXI_ACLK) begin

        if (!S_AXI_ARESETN) begin

            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;

            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;

            awaddr_reg    <= 6'b0;
            wdata_reg     <= 32'b0;
            wstrb_reg     <= 4'b0;

            aw_hold       <= 1'b0;
            w_hold        <= 1'b0;

        end
        else begin

            //====================================================
            // Accept AXI write address
            //====================================================

            if (!aw_hold && !S_AXI_BVALID) begin

                S_AXI_AWREADY <= 1'b1;

                if (S_AXI_AWVALID && S_AXI_AWREADY) begin

                    awaddr_reg <= S_AXI_AWADDR;
                    aw_hold    <= 1'b1;

                    S_AXI_AWREADY <= 1'b0;

                end

            end
            else begin

                S_AXI_AWREADY <= 1'b0;

            end

            //====================================================
            // Accept AXI write data
            //====================================================

            if (!w_hold && !S_AXI_BVALID) begin

                S_AXI_WREADY <= 1'b1;

                if (S_AXI_WVALID && S_AXI_WREADY) begin

                    wdata_reg <= S_AXI_WDATA;
                    wstrb_reg <= S_AXI_WSTRB;

                    w_hold <= 1'b1;

                    S_AXI_WREADY <= 1'b0;

                end

            end
            else begin

                S_AXI_WREADY <= 1'b0;

            end

            //====================================================
            // Generate write transaction when both address
            // and data are available
            //====================================================

            if (aw_hold && w_hold && !S_AXI_BVALID) begin

                aw_hold <= 1'b0;
                w_hold  <= 1'b0;

                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00;       // OKAY

            end

            //====================================================
            // Write response accepted by AXI master
            //====================================================

            if (S_AXI_BVALID && S_AXI_BREADY) begin

                S_AXI_BVALID <= 1'b0;

            end

        end

    end

    //============================================================
    // AES Register WRITE LOGIC
    //============================================================

    always @(posedge S_AXI_ACLK) begin

        if (!S_AXI_ARESETN) begin

            key_reg     <= 128'b0;
            text_in_reg <= 128'b0;

            load_reg    <= 1'b0;
            done_reg    <= 1'b0;

        end
        else begin

            //====================================================
            // LOAD is a one-clock pulse
            //====================================================

            load_reg <= 1'b0;

            //====================================================
            // Clear DONE when a new encryption is started
            //====================================================

            if (load_reg)
                done_reg <= 1'b0;

            //====================================================
            // AXI WRITE -> AES REGISTERS
            //====================================================

            if (aw_hold && w_hold && !S_AXI_BVALID) begin

                case (awaddr_reg)

                    //================================================
                    // CONTROL REGISTER
                    //================================================

                    6'h00: begin

                        if (wstrb_reg[0]) begin

                            if (wdata_reg[0])
                                load_reg <= 1'b1;

                        end

                    end

                    //================================================
                    // KEY REGISTERS
                    //================================================

                    6'h04: begin
                        key_reg[31:0] <= apply_wstrb(
                            key_reg[31:0],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    6'h08: begin
                        key_reg[63:32] <= apply_wstrb(
                            key_reg[63:32],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    6'h0C: begin
                        key_reg[95:64] <= apply_wstrb(
                            key_reg[95:64],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    6'h10: begin
                        key_reg[127:96] <= apply_wstrb(
                            key_reg[127:96],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    //================================================
                    // TEXT INPUT REGISTERS
                    //================================================

                    6'h14: begin
                        text_in_reg[31:0] <= apply_wstrb(
                            text_in_reg[31:0],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    6'h18: begin
                        text_in_reg[63:32] <= apply_wstrb(
                            text_in_reg[63:32],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    6'h1C: begin
                        text_in_reg[95:64] <= apply_wstrb(
                            text_in_reg[95:64],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    6'h20: begin
                        text_in_reg[127:96] <= apply_wstrb(
                            text_in_reg[127:96],
                            wdata_reg,
                            wstrb_reg
                        );
                    end

                    default: begin

                    end

                endcase

            end

        end

    end

    //============================================================
    // Capture AES output when DONE is asserted
    //============================================================

    always @(posedge S_AXI_ACLK) begin

        if (!S_AXI_ARESETN) begin

            text_out_reg <= 128'b0;

        end
        else begin

            if (aes_done) begin

                text_out_reg <= aes_text_out;
                done_reg     <= 1'b1;

            end

        end

    end

    //============================================================
    // AXI READ CHANNEL
    //============================================================

    always @(posedge S_AXI_ACLK) begin

        if (!S_AXI_ARESETN) begin

            S_AXI_ARREADY <= 1'b0;

            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RDATA   <= 32'b0;

            araddr_reg    <= 6'b0;

        end
        else begin

            //====================================================
            // Accept read address
            //====================================================

            if (!S_AXI_RVALID) begin

                S_AXI_ARREADY <= 1'b1;

                if (S_AXI_ARVALID && S_AXI_ARREADY) begin

                    araddr_reg <= S_AXI_ARADDR;

                    S_AXI_ARREADY <= 1'b0;
                    S_AXI_RVALID  <= 1'b1;
                    S_AXI_RRESP   <= 2'b00;

                    //================================================
                    // Select register to read
                    //================================================

                    case (S_AXI_ARADDR)

                        //============================================
                        // CONTROL / STATUS
                        //============================================

                        6'h00: begin

                            S_AXI_RDATA <= {
                                30'b0,
                                done_reg,
                                1'b0
                            };

                        end

                        //============================================
                        // KEY
                        //============================================

                        6'h04:
                            S_AXI_RDATA <= key_reg[31:0];

                        6'h08:
                            S_AXI_RDATA <= key_reg[63:32];

                        6'h0C:
                            S_AXI_RDATA <= key_reg[95:64];

                        6'h10:
                            S_AXI_RDATA <= key_reg[127:96];

                        //============================================
                        // TEXT INPUT
                        //============================================

                        6'h14:
                            S_AXI_RDATA <= text_in_reg[31:0];

                        6'h18:
                            S_AXI_RDATA <= text_in_reg[63:32];

                        6'h1C:
                            S_AXI_RDATA <= text_in_reg[95:64];

                        6'h20:
                            S_AXI_RDATA <= text_in_reg[127:96];

                        //============================================
                        // TEXT OUTPUT
                        //============================================

                        6'h24:
                            S_AXI_RDATA <= text_out_reg[31:0];

                        6'h28:
                            S_AXI_RDATA <= text_out_reg[63:32];

                        6'h2C:
                            S_AXI_RDATA <= text_out_reg[95:64];

                        6'h30:
                            S_AXI_RDATA <= text_out_reg[127:96];

                        default:
                            S_AXI_RDATA <= 32'b0;

                    endcase

                end

            end
            else begin

                S_AXI_ARREADY <= 1'b0;

            end

            //====================================================
            // Read data accepted
            //====================================================

            if (S_AXI_RVALID && S_AXI_RREADY) begin

                S_AXI_RVALID <= 1'b0;

            end

        end

    end

    //============================================================
    // AES CIPHER CORE
    //============================================================

    aes_cipher_top aes_core (

        .clk       (S_AXI_ACLK),

        .rst       (S_AXI_ARESETN),

        .ld        (load_reg),

        .done      (aes_done),

        .key       (key_reg),

        .text_in   (text_in_reg),

        .text_out  (aes_text_out)

    );

endmodule
