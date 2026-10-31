
// ============================================================================
// 8. Top-Level Tiny Tapeout ASIC Wrapper
// ============================================================================
module tt_um_protocol_emulator_top (
    input  logic [7:0] ui_in,    // [0]=CS_N, [1]=SCLK, [2]=MOSI, [7:3]=Spare
    output logic [7:0] uo_out,   // [0]=MISO, [7:1]=Dedicated extra outs
    input  logic [7:0] uio_in,   // Bidirectional GPIO pins 0-7
    output logic [7:0] uio_out,
    output logic [7:0] uio_oe,
    input  logic       ena,
    input  logic       clk,
    input  logic       rst_n
);
    logic [7:0] ui_sync_m, ui_sync;
    logic [7:0] uio_sync_m, uio_sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ui_sync_m  <= 8'h00;
            ui_sync    <= 8'h00;
            uio_sync_m <= 8'h00;
            uio_sync   <= 8'h00;
        end else begin
            ui_sync_m  <= ui_in;
            ui_sync    <= ui_sync_m;
            uio_sync_m <= uio_in;
            uio_sync   <= uio_sync_m;
        end
    end

    logic [4:0]  pc_sm0, pc_sm1;
    logic [15:0] instr_sm0, instr_sm1;
    logic        ram_we;
    logic [4:0]  ram_addr;
    logic [15:0] ram_wdata;

    logic [15:0] sm0_ctrl_reg;
    logic        sm0_restart;
    logic [4:0]  sm0_wrap_target, sm0_wrap;
    logic [15:0] sm0_clkdiv;
    logic        clk_en_sm0;
    logic        sm0_tx_wr, sm0_tx_rd, sm0_tx_full, sm0_tx_empty;
    logic        sm0_rx_wr, sm0_rx_rd, sm0_rx_full, sm0_rx_empty;
    logic [15:0] sm0_tx_wdata, sm0_tx_rdata;
    logic [15:0] sm0_rx_wdata, sm0_rx_rdata;
    logic [7:0]  sm0_pins_out, sm0_pins_pindir;
    logic [3:0]  sm0_sideset_out, sm0_sideset_pindir;

    logic [15:0] sm1_ctrl_reg;
    logic        sm1_restart;
    logic [4:0]  sm1_wrap_target, sm1_wrap;
    logic [15:0] sm1_clkdiv;
    logic        clk_en_sm1;
    logic        sm1_tx_wr, sm1_tx_rd, sm1_tx_full, sm1_tx_empty;
    logic        sm1_rx_wr, sm1_rx_rd, sm1_rx_full, sm1_rx_empty;
    logic [15:0] sm1_tx_wdata, sm1_tx_rdata;
    logic [15:0] sm1_rx_wdata, sm1_rx_rdata;
    logic [7:0]  sm1_pins_out, sm1_pins_pindir;
    logic [3:0]  sm1_sideset_out, sm1_sideset_pindir;

    logic [7:0]  irq_flags;
    logic [7:0]  sm0_irq_set, sm0_irq_clr;
    logic [7:0]  sm1_irq_set, sm1_irq_clr;

    logic        miso_out, miso_oe;

    host_spi_ctrl u_host (
        .clk            (clk),
        .rst_n          (rst_n),
        .sclk_sync      (ui_sync[1]),
        .cs_n_sync      (ui_sync[0]),
        .mosi_sync      (ui_sync[2]),
        .miso_out       (miso_out),
        .miso_oe        (miso_oe),
        .ram_we         (ram_we),
        .ram_addr       (ram_addr),
        .ram_wdata      (ram_wdata),
        .sm0_ctrl_reg   (sm0_ctrl_reg),
        .sm0_restart    (sm0_restart),
        .sm0_wrap_target(sm0_wrap_target),
        .sm0_wrap       (sm0_wrap),
        .sm0_clkdiv     (sm0_clkdiv),
        .sm0_tx_wr      (sm0_tx_wr),
        .sm0_tx_wdata   (sm0_tx_wdata),
        .sm0_tx_full    (sm0_tx_full),
        .sm0_rx_rdata   (sm0_rx_rdata),
        .sm0_rx_rd      (sm0_rx_rd),
        .sm0_rx_empty   (sm0_rx_empty),
        .sm1_ctrl_reg   (sm1_ctrl_reg),
        .sm1_restart    (sm1_restart),
        .sm1_wrap_target(sm1_wrap_target),
        .sm1_wrap       (sm1_wrap),
        .sm1_clkdiv     (sm1_clkdiv),
        .sm1_tx_wr      (sm1_tx_wr),
        .sm1_tx_wdata   (sm1_tx_wdata),
        .sm1_tx_full    (sm1_tx_full),
        .sm1_rx_rdata   (sm1_rx_rdata),
        .sm1_rx_rd      (sm1_rx_rd),
        .sm1_rx_empty   (sm1_rx_empty)
    );

    assign uo_out[0] = (ui_sync[0] == 1'b0) ? miso_out : sm0_pins_out[7];

    instr_sram_jane_street u_sram (
        .clk       (clk),
        .rst_n     (rst_n),
        .host_we   (ram_we),
        .host_addr (ram_addr),
        .host_wdata(ram_wdata),
        .sm0_pc    (pc_sm0),
        .sm0_instr (instr_sm0),
        .sm1_pc    (pc_sm1),
        .sm1_instr (instr_sm1)
    );

    pio_clkdiv u_div0 (
        .clk    (clk),
        .rst_n  (rst_n),
        .enable (sm0_ctrl_reg[0]),
        .restart(sm0_restart),
        .clkdiv ({8'h00, sm0_clkdiv}),
        .clk_en (clk_en_sm0)
    );

    pio_clkdiv u_div1 (
        .clk    (clk),
        .rst_n  (rst_n),
        .enable (sm1_ctrl_reg[0]),
        .restart(sm1_restart),
        .clkdiv ({8'h00, sm1_clkdiv}),
        .clk_en (clk_en_sm1)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq_flags <= 8'h00;
        end else begin
            irq_flags <= (irq_flags | sm0_irq_set | sm1_irq_set) & ~(sm0_irq_clr | sm1_irq_clr);
        end
    end

    sync_fifo #(.DATA_WIDTH(16), .DEPTH(4)) u_sm0_tx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (sm0_tx_wr),
        .wr_data (sm0_tx_wdata),
        .rd_en   (sm0_tx_rd),
        .rd_data (sm0_tx_rdata),
        .full    (sm0_tx_full),
        .empty   (sm0_tx_empty),
        .level   ()
    );

    sync_fifo #(.DATA_WIDTH(16), .DEPTH(4)) u_sm0_rx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (sm0_rx_wr),
        .wr_data (sm0_rx_wdata),
        .rd_en   (sm0_rx_rd),
        .rd_data (sm0_rx_rdata),
        .full    (sm0_rx_full),
        .empty   (sm0_rx_empty),
        .level   ()
    );

    state_machine_core #(.SM_ID(0)) u_sm0 (
        .clk               (clk),
        .rst_n             (rst_n),
        .sm_enable         (sm0_ctrl_reg[0]),
        .restart           (sm0_restart),
        .clk_en            (clk_en_sm0),
        .pc                (pc_sm0),
        .instr             (instr_sm0),
        .wrap_target       (sm0_wrap_target),
        .wrap              (sm0_wrap),
        .sideset_count     (sm0_ctrl_reg[4:2]),
        .sideset_opt       (sm0_ctrl_reg[5]),
        .sideset_pindirs   (sm0_ctrl_reg[6]),
        .out_base          (sm0_ctrl_reg[9:7]),
        .in_base           (sm0_ctrl_reg[12:10]),
        .sideset_base      (sm0_ctrl_reg[15:13]),
        .jmp_pin           (sm0_ctrl_reg[9:7]),
        .in_shift_dir      (1'b1),
        .out_shift_dir     (1'b1),
        .pins_in           (uio_sync),
        .pins_out          (sm0_pins_out),
        .pins_pindir       (sm0_pins_pindir),
        .sideset_out_bus   (sm0_sideset_out),
        .sideset_pindir_bus(sm0_sideset_pindir),
        .tx_empty          (sm0_tx_empty),
        .tx_rd_en          (sm0_tx_rd),
        .tx_data           (sm0_tx_rdata),
        .rx_full           (sm0_rx_full),
        .rx_wr_en          (sm0_rx_wr),
        .rx_data           (sm0_rx_wdata),
        .irq_in            (irq_flags),
        .irq_set           (sm0_irq_set),
        .irq_clr           (sm0_irq_clr)
    );

    sync_fifo #(.DATA_WIDTH(16), .DEPTH(4)) u_sm1_tx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (sm1_tx_wr),
        .wr_data (sm1_tx_wdata),
        .rd_en   (sm1_tx_rd),
        .rd_data (sm1_tx_rdata),
        .full    (sm1_tx_full),
        .empty   (sm1_tx_empty),
        .level   ()
    );

    sync_fifo #(.DATA_WIDTH(16), .DEPTH(4)) u_sm1_rx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (sm1_rx_wr),
        .wr_data (sm1_rx_wdata),
        .rd_en   (sm1_rx_rd),
        .rd_data (sm1_rx_rdata),
        .full    (sm1_rx_full),
        .empty   (sm1_rx_empty),
        .level   ()
    );

    state_machine_core #(.SM_ID(1)) u_sm1 (
        .clk               (clk),
        .rst_n             (rst_n),
        .sm_enable         (sm1_ctrl_reg[0]),
        .restart           (sm1_restart),
        .clk_en            (clk_en_sm1),
        .pc                (pc_sm1),
        .instr             (instr_sm1),
        .wrap_target       (sm1_wrap_target),
        .wrap              (sm1_wrap),
        .sideset_count     (sm1_ctrl_reg[4:2]),
        .sideset_opt       (sm1_ctrl_reg[5]),
        .sideset_pindirs   (sm1_ctrl_reg[6]),
        .out_base          (sm1_ctrl_reg[9:7]),
        .in_base           (sm1_ctrl_reg[12:10]),
        .sideset_base      (sm1_ctrl_reg[15:13]),
        .jmp_pin           (sm1_ctrl_reg[9:7]),
        .in_shift_dir      (1'b1),
        .out_shift_dir     (1'b1),
        .pins_in           (uio_sync),
        .pins_out          (sm1_pins_out),
        .pins_pindir       (sm1_pins_pindir),
        .sideset_out_bus   (sm1_sideset_out),
        .sideset_pindir_bus(sm1_sideset_pindir),
        .tx_empty          (sm1_tx_empty),
        .tx_rd_en          (sm1_tx_rd),
        .tx_data           (sm1_tx_rdata),
        .rx_full           (sm1_rx_full),
        .rx_wr_en          (sm1_rx_wr),
        .rx_data           (sm1_rx_wdata),
        .irq_in            (irq_flags),
        .irq_set           (sm1_irq_set),
        .irq_clr           (sm1_irq_clr)
    );

    assign uio_out[3:0] = sm0_ctrl_reg[6] ? sm0_sideset_out : sm0_pins_out[3:0];
    assign uio_oe[3:0]  = sm0_ctrl_reg[6] ? sm0_sideset_pindir : sm0_pins_pindir[3:0];

    assign uio_out[7:4] = sm1_ctrl_reg[6] ? sm1_sideset_out : sm1_pins_out[3:0];
    assign uio_oe[7:4]  = sm1_ctrl_reg[6] ? sm1_sideset_pindir : sm1_pins_pindir[3:0];

    assign uo_out[3:1]  = sm0_pins_out[6:4];
    assign uo_out[7:4]  = sm1_pins_out[7:4];
endmodule
