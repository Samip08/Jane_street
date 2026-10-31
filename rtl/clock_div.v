// ============================================================================
// 6. 16.8 Fractional Clock Divider
// ============================================================================
module pio_clkdiv (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        restart,
    input  logic [23:0] clkdiv,
    output logic        clk_en
);
    logic [15:0] int_cnt;
    logic [8:0]  frac_acc;

    wire [15:0] int_part = (clkdiv[23:8] == 16'd0) ? 16'd1 : clkdiv[23:8];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_cnt  <= 16'd0;
            frac_acc <= 9'd0;
            clk_en   <= 1'b0;
        end else if (!enable || restart) begin
            int_cnt  <= 16'd0;
            frac_acc <= 9'd0;
            clk_en   <= 1'b0;
        end else begin
            if (int_cnt == 16'd0) begin
                clk_en   <= 1'b1;
                frac_acc <= {1'b0, frac_acc[7:0]} + {1'b0, clkdiv[7:0]};
                int_cnt  <= int_part + {15'd0, frac_acc[8]} - 16'd1;
            end else begin
                clk_en  <= 1'b0;
                int_cnt <= int_cnt - 16'd1;
            end
        end
    end
endmodule

