`default_nettype none

// ============================================================================
// 1. Synchronous FIFO (4-word FWFT)
// ============================================================================
module sync_fifo #(
    parameter int DATA_WIDTH = 16,
    parameter int DEPTH      = 4,
    localparam int ADDR_W    = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  full,
    output logic                  empty,
    output logic [ADDR_W:0]       level
);
    logic [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    logic [ADDR_W:0] wr_ptr, rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && 
                   (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
    assign level = wr_ptr - rd_ptr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    assign rd_data = mem[rd_ptr[ADDR_W-1:0]];
endmodule
