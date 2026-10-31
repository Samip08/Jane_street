// ============================================================================
// 5. Host SPI Controller
// ============================================================================
module host_spi_ctrl (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        sclk_sync,
    input  logic        cs_n_sync,
    input  logic        mosi_sync,
    output logic        miso_out,
    output logic        miso_oe,

    output logic        ram_we,
    output logic [4:0]  ram_addr,
    output logic [15:0] ram_wdata,

    output logic [15:0] sm0_ctrl_reg,
    output logic        sm0_restart,
    output logic [4:0]  sm0_wrap_target,
    output logic [4:0]  sm0_wrap,
    output logic [15:0] sm0_clkdiv,
    output logic        sm0_tx_wr,
    output logic [15:0] sm0_tx_wdata,
    input  logic        sm0_tx_full,
    input  logic [15:0] sm0_rx_rdata,
    output logic        sm0_rx_rd,
    input  logic        sm0_rx_empty,

    output logic [15:0] sm1_ctrl_reg,
    output logic        sm1_restart,
    output logic [4:0]  sm1_wrap_target,
    output logic [4:0]  sm1_wrap,
    output logic [15:0] sm1_clkdiv,
    output logic        sm1_tx_wr,
    output logic [15:0] sm1_tx_wdata,
    input  logic        sm1_tx_full,
    input  logic [15:0] sm1_rx_rdata,
    output logic        sm1_rx_rd,
    input  logic        sm1_rx_empty
);
    logic sclk_d, cs_n_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_d <= 1'b0;
            cs_n_d <= 1'b1;
        end else begin
            sclk_d <= sclk_sync;
            cs_n_d <= cs_n_sync;
        end
    end

    wire sclk_posedge = (sclk_sync && !sclk_d) && !cs_n_sync;
    wire sclk_negedge = (!sclk_sync && sclk_d) && !cs_n_sync;

    logic [23:0] shift_in;
    logic [15:0] shift_out;
    logic [4:0]  bit_cnt;
    logic [23:0] word;
    logic        word_done;

    wire [15:0] status_word = {
        8'h00,
        sm1_tx_full, sm1_rx_empty, 2'b00,
        sm0_tx_full, sm0_rx_empty, 2'b00
    };

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt         <= '0;
            shift_in        <= '0;
            shift_out       <= '0;
            miso_out        <= 1'b0;
            miso_oe         <= 1'b0;
            word            <= '0;
            word_done       <= 1'b0;
            ram_we          <= 1'b0;
            sm0_tx_wr       <= 1'b0;
            sm1_tx_wr       <= 1'b0;
            sm0_rx_rd       <= 1'b0;
            sm1_rx_rd       <= 1'b0;
            sm0_restart     <= 1'b0;
            sm1_restart     <= 1'b0;
            sm0_ctrl_reg    <= 16'h0000;
            sm1_ctrl_reg    <= 16'h0000;
            sm0_wrap_target <= 5'd0;
            sm0_wrap        <= 5'd31;
            sm1_wrap_target <= 5'd0;
            sm1_wrap        <= 5'd31;
            sm0_clkdiv      <= 16'h0100;
            sm1_clkdiv      <= 16'h0100;
        end else begin
            ram_we      <= 1'b0;
            sm0_tx_wr   <= 1'b0;
            sm1_tx_wr   <= 1'b0;
            sm0_rx_rd   <= 1'b0;
            sm1_rx_rd   <= 1'b0;
            sm0_restart <= 1'b0;
            sm1_restart <= 1'b0;
            word_done   <= 1'b0;

            if (cs_n_sync) begin
                bit_cnt  <= '0;
                shift_in <= '0;
                miso_out <= 1'b0;
                miso_oe  <= 1'b0;
            end else begin
                miso_oe <= 1'b1;

                if (sclk_posedge) begin
                    shift_in <= {shift_in[22:0], mosi_sync};
                    bit_cnt  <= bit_cnt + 1'b1;

                    if (bit_cnt == 5'd7) begin
                        case ({shift_in[5:0], mosi_sync})
                            7'h00: shift_out <= sm0_ctrl_reg;
                            7'h02: shift_out <= sm0_rx_rdata;
                            7'h04: shift_out <= sm1_ctrl_reg;
                            7'h03: shift_out <= sm1_rx_rdata;
                            7'h06: shift_out <= status_word;
                            7'h08: shift_out <= {6'd0, sm0_wrap, sm0_wrap_target};
                            7'h09: shift_out <= {6'd0, sm1_wrap, sm1_wrap_target};
                            7'h0A: shift_out <= sm0_clkdiv;
                            7'h0B: shift_out <= sm1_clkdiv;
                            default: shift_out <= 16'hDEAD;
                        endcase
                    end

                    if (bit_cnt == 5'd23) begin
                        word      <= {shift_in[22:0], mosi_sync};
                        word_done <= 1'b1;
                    end
                end

                if (sclk_negedge) begin
                    if (bit_cnt >= 5'd8) begin
                        miso_out  <= shift_out[15];
                        shift_out <= {shift_out[14:0], 1'b0};
                    end
                end
            end

            if (word_done) begin
                if (word[23]) begin
                    case (word[22:16])
                        7'h00: begin
                            sm0_ctrl_reg <= word[15:0];
                            sm0_restart  <= word[1];
                        end
                        7'h01: sm0_tx_wr <= 1'b1;
                        7'h04: begin
                            sm1_ctrl_reg <= word[15:0];
                            sm1_restart  <= word[1];
                        end
                        7'h05: sm1_tx_wr <= 1'b1;
                        7'h08: {sm0_wrap, sm0_wrap_target} <= word[9:0];
                        7'h09: {sm1_wrap, sm1_wrap_target} <= word[9:0];
                        7'h0A: sm0_clkdiv <= word[15:0];
                        7'h0B: sm1_clkdiv <= word[15:0];
                        default: begin
                            if (word[22:21] == 2'b01) begin
                                ram_we <= 1'b1;
                            end
                        end
                    endcase
                end else begin
                    case (word[22:16])
                        7'h02: sm0_rx_rd <= !sm0_rx_empty;
                        7'h03: sm1_rx_rd <= !sm1_rx_empty;
                        default: ;
                    endcase
                end
            end
        end
    end

    assign ram_addr     = word[20:16];
    assign ram_wdata    = word[15:0];
    assign sm0_tx_wdata = word[15:0];
    assign sm1_tx_wdata = word[15:0];
endmodule

