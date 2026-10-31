// ============================================================================
// 4. State Machine Core
// ============================================================================
module state_machine_core #(
    parameter int SM_ID = 0
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        sm_enable,
    input  logic        restart,
    input  logic        clk_en,

    output logic [4:0]  pc,
    input  logic [15:0] instr,

    input  logic [4:0]  wrap_target,
    input  logic [4:0]  wrap,
    input  logic [3:0]  sideset_count,
    input  logic        sideset_opt,
    input  logic        sideset_pindirs,
    input  logic [2:0]  out_base,
    input  logic [2:0]  in_base,
    input  logic [2:0]  sideset_base,
    input  logic [2:0]  jmp_pin,
    input  logic        in_shift_dir,
    input  logic        out_shift_dir,

    input  logic [7:0]  pins_in,
    output logic [7:0]  pins_out,
    output logic [7:0]  pins_pindir,

    output logic [3:0]  sideset_out_bus,
    output logic [3:0]  sideset_pindir_bus,

    input  logic        tx_empty,
    output logic        tx_rd_en,
    input  logic [15:0] tx_data,

    input  logic        rx_full,
    output logic        rx_wr_en,
    output logic [15:0] rx_data,

    input  logic [7:0]  irq_in,
    output logic [7:0]  irq_set,
    output logic [7:0]  irq_clr
);
    wire [3:0] opcode            = instr[15:12];
    wire [3:0] delay_sideset_raw = instr[11:8];
    wire [7:0] arg               = instr[7:0];

    wire [3:0] raw_bit_cnt = arg[3:0];
    wire [4:0] eff_bit_cnt = (raw_bit_cnt == 4'd0) ? 5'd16 : {1'b0, raw_bit_cnt};

    logic [3:0] cur_sideset;
    logic       sideset_valid;

    always_comb begin
        if (sideset_count == 4'd0) begin
            cur_sideset   = 4'd0;
            sideset_valid = 1'b0;
        end else if (sideset_opt) begin
            sideset_valid = delay_sideset_raw[3];
            cur_sideset   = delay_sideset_raw[2:0] & ~(4'hF << sideset_count);
        end else begin
            sideset_valid = 1'b1;
            cur_sideset   = delay_sideset_raw >> (4 - sideset_count);
        end
    end

    logic [3:0] eff_delay;
logic [2:0] delay_bits;
    always_comb begin
        delay_bits = 4 - sideset_count - (sideset_opt ? 1 : 0);
        if (delay_bits == 0) begin
            eff_delay = 4'd0;
        end else begin
            eff_delay = delay_sideset_raw & ~(4'hF << delay_bits);
        end
    end

    logic [15:0] x_reg, y_reg;
    logic [15:0] osr_reg, isr_reg;
    logic [4:0]  shift_cnt_out, shift_cnt_in;
    logic [3:0]  delay_cnt;
    logic        delay_active;
    logic        stall, cond_met, jmp_taken;
    logic        sram_bubble;

    logic [15:0] isr_next, isr_shifted;
    logic [15:0] osr_next, osr_shifted;

    wire [7:0] in_pins_rotated = (pins_in >> in_base) | (pins_in << (3'd8 - in_base));

    shifter_16b u_isr_shifter (
        .d_in      (isr_reg),
        .d_fill    ({8'h00, in_pins_rotated}),
        .shift_cnt (eff_bit_cnt),
        .shift_dir (in_shift_dir),
        .d_out     (isr_next),
        .d_shifted (isr_shifted)
    );

    shifter_16b u_osr_shifter (
        .d_in      (osr_reg),
        .d_fill    (16'h0000),
        .shift_cnt (eff_bit_cnt),
        .shift_dir (out_shift_dir),
        .d_out     (osr_next),
        .d_shifted (osr_shifted)
    );

    always_comb begin
        cond_met = 1'b0;
        case (arg[7:5])
            3'b000: cond_met = 1'b1;
            3'b001: cond_met = (x_reg == 16'h0);
            3'b010: cond_met = (x_reg != 16'h0);
            3'b011: cond_met = (y_reg == 16'h0);
            3'b100: cond_met = (y_reg != 16'h0);
            3'b101: cond_met = (x_reg != y_reg);
            3'b110: cond_met = pins_in[jmp_pin];
            3'b111: cond_met = (shift_cnt_out == 5'd0);
        endcase
    end

    always_comb begin
        stall     = !sm_enable || delay_active || sram_bubble;
        jmp_taken = 1'b0;
        tx_rd_en  = 1'b0;
        rx_wr_en  = 1'b0;
        irq_set   = '0;
        irq_clr   = '0;

        if (sm_enable && !delay_active && !sram_bubble) begin
            case (opcode)
                4'h0: jmp_taken = cond_met;
                4'h1: begin // WAIT
                    case (arg[6:5])
                        2'b00: if (pins_in[arg[2:0]] != arg[7]) stall = 1'b1;
                        2'b01: if (pins_in[(arg[2:0] + in_base) & 3'd7] != arg[7]) stall = 1'b1;
                        2'b10: if (irq_in[arg[2:0]] != arg[7]) stall = 1'b1;
                        default: ;
                    endcase
                end
                4'h4: begin // PUSH
                    if (rx_full) stall = 1'b1;
                    else if (clk_en) rx_wr_en = 1'b1;
                end
                4'h5: begin // PULL
                    if (tx_empty) stall = 1'b1;
                    else if (clk_en) tx_rd_en = 1'b1;
                end
                4'h7: begin // IRQ
                    if (clk_en) begin
                        if (arg[6]) irq_clr[arg[2:0]] = 1'b1;
                        else        irq_set[arg[2:0]] = 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end

    sm_fetch_pc #(.ADDR_W(5)) u_pc (
        .clk        (clk),
        .rst_n      (rst_n),
        .sm_enable  (sm_enable),
        .restart    (restart),
        .clk_en     (clk_en),
        .stall      (stall),
        .jmp_taken  (jmp_taken),
        .jmp_target (arg[4:0]),
        .wrap_target(wrap_target),
        .wrap       (wrap),
        .pc         (pc),
        .sram_bubble(sram_bubble)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt    <= 4'd0;
            delay_active <= 1'b0;
        end else if (!sm_enable || restart) begin
            delay_cnt    <= 4'd0;
            delay_active <= 1'b0;
        end else if (clk_en) begin
            if (!stall && (eff_delay != 4'd0)) begin
                delay_cnt    <= eff_delay;
                delay_active <= 1'b1;
            end else if (delay_active) begin
                if (delay_cnt == 4'd1) begin
                    delay_active <= 1'b0;
                    delay_cnt    <= 4'd0;
                end else begin
                    delay_cnt <= delay_cnt - 1'b1;
                end
            end
        end
    end

    logic [7:0]  mask_8b;
    logic [15:0] rot_mask_16b, rot_data_16b;
    logic [7:0]  eff_mask, eff_data;

    wire [3:0] pin_cnt = (opcode == 4'h8) ? 4'd5 : (eff_bit_cnt > 5'd8 ? 4'd8 : eff_bit_cnt[3:0]);
    wire [7:0] pin_src = (opcode == 4'h8) ? {3'b000, arg[4:0]} : osr_shifted[7:0];

    assign mask_8b      = ~(8'hFF << pin_cnt);
    assign rot_mask_16b = {mask_8b, mask_8b} << out_base;
    assign rot_data_16b = {pin_src, pin_src} << out_base;
    assign eff_mask     = rot_mask_16b[15:8] | rot_mask_16b[7:0];
    assign eff_data     = rot_data_16b[15:8] | rot_data_16b[7:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sideset_out_bus    <= '0;
            sideset_pindir_bus <= '0;
        end else if (!sm_enable || restart) begin
            sideset_out_bus    <= '0;
            sideset_pindir_bus <= '0;
        end else if (clk_en && !stall && sideset_valid) begin
            if (sideset_pindirs) sideset_pindir_bus <= cur_sideset;
            else                 sideset_out_bus    <= cur_sideset;
        end
    end

    assign rx_data = isr_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg         <= 16'h0000;
            y_reg         <= 16'h0000;
            osr_reg       <= 16'h0000;
            isr_reg       <= 16'h0000;
            shift_cnt_out <= 5'd0;
            shift_cnt_in  <= 5'd0;
            pins_out      <= 8'h00;
            pins_pindir   <= 8'h00;
        end else if (!sm_enable || restart) begin
            shift_cnt_out <= 5'd0;
            shift_cnt_in  <= 5'd0;
        end else if (clk_en && !stall) begin
            if (opcode == 4'h0 && arg[7:5] == 3'b010) x_reg <= x_reg - 1'b1;
            if (opcode == 4'h0 && arg[7:5] == 3'b100) y_reg <= y_reg - 1'b1;

            case (opcode)
                4'h2: begin // IN
                    isr_reg      <= isr_next;
                    shift_cnt_in <= (shift_cnt_in + eff_bit_cnt > 5'd16) ? 5'd16 : (shift_cnt_in + eff_bit_cnt);
                end
                4'h3: begin // OUT
                    case (arg[7:5])
                        3'b000: pins_out    <= (pins_out & ~eff_mask) | (eff_data & eff_mask);
                        3'b001: x_reg       <= osr_shifted;
                        3'b010: y_reg       <= osr_shifted;
                        3'b011: pins_pindir <= (pins_pindir & ~eff_mask) | (eff_data & eff_mask);
                        3'b100: isr_reg     <= osr_shifted;
                        default: ;
                    endcase
                    osr_reg       <= osr_next;
                    shift_cnt_out <= (shift_cnt_out < eff_bit_cnt) ? 5'd0 : (shift_cnt_out - eff_bit_cnt);
                end
                4'h4: begin // PUSH
                    isr_reg      <= 16'h0000;
                    shift_cnt_in <= 5'd0;
                end
                4'h5: begin // PULL
                    osr_reg       <= tx_data;
                    shift_cnt_out <= 5'd16;
                end
                4'h6: begin // MOV
                    logic [15:0] mov_src;
                    case (arg[2:0])
                        3'b000: mov_src = {8'h00, in_pins_rotated};
                        3'b001: mov_src = x_reg;
                        3'b010: mov_src = y_reg;
                        3'b011: mov_src = 16'h0000;
                        3'b101: mov_src = isr_reg;
                        3'b110: mov_src = osr_reg;
                        default: mov_src = 16'h0000;
                    endcase

                    if (arg[4:3] == 2'b01) mov_src = ~mov_src;
                    if (arg[4:3] == 2'b10) begin
                        for (int i = 0; i < 16; i++) mov_src[i] = mov_src[15-i];
                    end

                    case (arg[7:5])
                        3'b000: pins_out    <= mov_src[7:0];
                        3'b001: x_reg       <= mov_src;
                        3'b010: y_reg       <= mov_src;
                        3'b011: pins_pindir <= mov_src[7:0];
                        3'b100: isr_reg     <= mov_src;
                        3'b101: osr_reg     <= mov_src;
                        default: ;
                    endcase
                end
                4'h8: begin // SET
                    case (arg[7:5])
                        3'b000: pins_out    <= (pins_out & ~eff_mask) | (eff_data & eff_mask);
                        3'b001: x_reg       <= {11'h0, arg[4:0]};
                        3'b010: y_reg       <= {11'h0, arg[4:0]};
                        3'b100: pins_pindir <= (pins_pindir & ~eff_mask) | (eff_data & eff_mask);
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    end
endmodule

