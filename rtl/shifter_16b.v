
// ============================================================================
// 2. 16-Bit Barrel Shifter
// ============================================================================
module shifter_16b (
    input  logic [15:0] d_in,
    input  logic [15:0] d_fill,
    input  logic [4:0]  shift_cnt,
    input  logic        shift_dir,
    output logic [15:0] d_out,
    output logic [15:0] d_shifted
);
    logic [31:0] concat_r;
    logic [15:0] fill_mask;

    assign concat_r  = {d_fill, d_in};
    assign fill_mask = ~(16'hFFFF << shift_cnt);

    always_comb begin
        if (shift_dir) begin
            d_out     = 16'(concat_r >> shift_cnt);
            d_shifted = d_in & fill_mask;
        end else begin
            d_out = (d_in << shift_cnt) | (d_fill & fill_mask);
            if (shift_cnt >= 5'd16) begin
                d_shifted = d_in;
            end else if (shift_cnt == 5'd0) begin
                d_shifted = 16'h0000;
            end else begin
                d_shifted = 16'(d_in >> (5'd16 - shift_cnt));
            end
        end
    end
endmodule

