// 7. Physical Jane Street SRAM Wrapper
// ============================================================================
module instr_sram_jane_street (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        host_we,
    input  logic [4:0]  host_addr,
    input  logic [15:0] host_wdata,

    input  logic [4:0]  sm0_pc,
    output logic [15:0] sm0_instr,

    input  logic [4:0]  sm1_pc,
    output logic [15:0] sm1_instr
);
    logic [5:0]  sram0_addr,  sram1_addr;
    logic [15:0] sram0_wdata, sram1_wdata;
    logic [15:0] sram0_rdata, sram1_rdata;
    logic        sram0_ce_n,  sram1_ce_n;
    logic        sram0_we_n,  sram1_we_n;

    always_comb begin
        if (host_we) begin
            sram0_addr  = {1'b0, host_addr};
            sram0_wdata = host_wdata;
            sram0_ce_n  = 1'b0;
            sram0_we_n  = 1'b0;

            sram1_addr  = {1'b0, host_addr};
            sram1_wdata = host_wdata;
            sram1_ce_n  = 1'b0;
            sram1_we_n  = 1'b0;
        end else begin
            sram0_addr  = {1'b0, sm0_pc};
            sram0_wdata = 16'h0000;
            sram0_ce_n  = 1'b0;
            sram0_we_n  = 1'b1;

            sram1_addr  = {1'b0, sm1_pc};
            sram1_wdata = 16'h0000;
            sram1_ce_n  = 1'b0;
            sram1_we_n  = 1'b1;
        end
    end

    RM_IHPSG13_1P_core u_sram_bank0 (
        .CLK    (clk),
        .CE_N   (sram0_ce_n),
        .WE_N   (sram0_we_n),
        .TIE_HI (1'b1),
        .TIE_LO (1'b0),
        .A      (sram0_addr),
        .D      (sram0_wdata),
        .Q      (sram0_rdata)
    );

    RM_IHPSG13_1P_core u_sram_bank1 (
        .CLK    (clk),
        .CE_N   (sram1_ce_n),
        .WE_N   (sram1_we_n),
        .TIE_HI (1'b1),
        .TIE_LO (1'b0),
        .A      (sram1_addr),
        .D      (sram1_wdata),
        .Q      (sram1_rdata)
    );

    assign sm0_instr = sram0_rdata;
    assign sm1_instr = sram1_rdata;
endmodule

// ============================================================================
// 9. Blackbox Macro for Yosys Synthesis (Simulation Model Lives in sim/ folder)
// ============================================================================
(* blackbox *)
module RM_IHPSG13_1P_core (
    input  wire        CLK,
    input  wire        CE_N,
    input  wire        WE_N,
    input  wire        TIE_HI,
    input  wire        TIE_LO,
    input  wire [5:0]  A,
    input  wire [15:0] D,
    output wire [15:0] Q
);
endmodule

`default_nettype wire