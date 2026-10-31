// ============================================================================
// 3. Program Counter Unit with SRAM Latency Bubble Generation
// ============================================================================
module sm_fetch_pc #(
    parameter int ADDR_W = 5
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              sm_enable,
    input  logic              restart,
    input  logic              clk_en,
    input  logic              stall,
    input  logic              jmp_taken,
    input  logic [ADDR_W-1:0] jmp_target,
    input  logic [ADDR_W-1:0] wrap_target,
    input  logic [ADDR_W-1:0] wrap,
    output logic [ADDR_W-1:0] pc,
    output logic              sram_bubble
);
    logic bubble_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc         <= '0;
            bubble_reg <= 1'b0;
        end else if (!sm_enable || restart) begin
            pc         <= wrap_target;
            bubble_reg <= 1'b0;
        end else if (clk_en) begin
            if (bubble_reg) begin
                bubble_reg <= 1'b0;
            end else if (!stall) begin
                if (jmp_taken) begin
                    pc         <= jmp_target;
                    bubble_reg <= 1'b1;
                end else if (pc == wrap) begin
                    pc         <= wrap_target;
                end else begin
                    pc         <= pc + 1'b1;
                end
            end
        end
    end

    assign sram_bubble = bubble_reg;
endmodule

