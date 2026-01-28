`timescale 1ns / 1ps

import parameter_pkg::*;
import typedef_pkg::*;

module PhysicalRegister #(parameter PHY_REGS = 64, PHY_WIDTH = 6, DATA_WIDTH = 32)(
    input  logic clk,
    input  logic rst,
    input  logic flush,
    input  logic done,
    // ========= rename interface ====================
    input  logic [1:0]busy_valid,
    input  logic [PHY_WIDTH-1:0]rd_phy_busy_0,   // mark rd_phy busy
    input  logic [PHY_WIDTH-1:0]rd_phy_busy_1,   // mark rs1_phy busy
    output logic [PHY_REGS-1:0]PRF_busy,         // if busy = 1 => this register is not ready
    // ========= read execution interface ===============
    output logic [PHY_REGS-1:0]PRF_valid,
    // alu
    physical_if.sink  alu_prf_bus,
    // load/store
    physical_if.sink  lsu_prf_bus,
    // branch
    physical_if.sink  branch_prf_bus,
    // =========== writeback interface =================
    writeback_if.sink wb_to_prf_bus,
    // ============= commit /retire interface ====================
    retire_if.retire_pr_sink retire_pr_bus,
    // === debugging interface =========================
    output logic [PHY_REGS*DATA_WIDTH-1:0]PRF_data_out,
    output logic [PHY_REGS-1:0]PRF_busy_out,
    output logic [PHY_REGS-1:0]PRF_valid_out
);
    // Physical Register file
    // | Tag | Architected Reg | Data | Valid | Busy |
    integer i;
    logic [DATA_WIDTH-1:0] PRF [0:PHY_REGS-1];

    
    genvar j;

    generate
        for(j = 0; j < PHY_REGS; j = j + 1) begin : gen_prf_data
            // continuous assignment for each register for waveform visibility
            logic [DATA_WIDTH-1:0] prf_data;
            assign prf_data = PRF[j];
        end
    endgenerate

    // output PRF data for debugging
    generate
        for(j = 0; j < PHY_REGS; j = j + 1) begin : gen_prf_data_out
            assign PRF_data_out[(j+1)*DATA_WIDTH-1 -: DATA_WIDTH] = PRF[j];
            assign PRF_busy_out[j] = PRF_busy[j];
            assign PRF_valid_out[j] = PRF_valid[j];
        end
    endgenerate


    // ========== execution stage (read data from PRF) =========
    assign alu_prf_bus.rs1_data = (alu_prf_bus.valid) ? PRF[alu_prf_bus.rs1_phy] : 'hx;
    assign alu_prf_bus.rs2_data = (alu_prf_bus.valid) ? PRF[alu_prf_bus.rs2_phy] : 'hx;

    assign lsu_prf_bus.rs1_data = (lsu_prf_bus.valid) ? PRF[lsu_prf_bus.rs1_phy] : 'hx;
    assign lsu_prf_bus.rs2_data = (lsu_prf_bus.valid) ? PRF[lsu_prf_bus.rs2_phy] : 'hx;

    assign branch_prf_bus.rs1_data = (branch_prf_bus.valid) ? PRF[branch_prf_bus.rs1_phy] : 'hx;
    assign branch_prf_bus.rs2_data = (branch_prf_bus.valid) ? PRF[branch_prf_bus.rs2_phy] : 'hx;

    // ============== commit stage =====================

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            for(i = 0; i < PHY_REGS; i = i+1)begin
                PRF[i] <= 'h0;
            end
            PRF_busy  <= 'h0;
            PRF_valid <= {ARCH_REGS{1'b1}};
        end
        else if(flush) begin
            // On flush, reset PRF busy and valid bits
            PRF_busy  <= 'h0;
        end
        else if(done) begin
            PRF_busy  <= 'h0;
        end
        else begin

            if(busy_valid[0])begin
                PRF_busy[rd_phy_busy_0]  <= 1;
                PRF_valid[rd_phy_busy_0] <= 0;
            end
            if(busy_valid[1])begin
                PRF_busy[rd_phy_busy_1]  <= 1;
                PRF_valid[rd_phy_busy_1] <= 0;
            end

            if(wb_to_prf_bus.alu_valid)begin
                PRF[wb_to_prf_bus.rd_alu]       <= wb_to_prf_bus.alu_result;
                PRF_valid[wb_to_prf_bus.rd_alu] <= 1;
            end
            if(wb_to_prf_bus.load_valid)begin
                PRF[wb_to_prf_bus.rd_load]       <= wb_to_prf_bus.load_rdata;
                PRF_valid[wb_to_prf_bus.rd_load] <= 1;
            end
            if(wb_to_prf_bus.jump_valid)begin
                if(wb_to_prf_bus.rd_branch != '0)begin
                    PRF[wb_to_prf_bus.rd_branch]       <= wb_to_prf_bus.nextPC;
                    PRF_valid[wb_to_prf_bus.rd_branch] <= 1;
                end
            end
            if(wb_to_prf_bus.branch_valid)begin
                PRF_valid[wb_to_prf_bus.rd_branch] <= 1;
            end
            if(retire_pr_bus.retire_pr_valid) begin
                if(!PRF_busy[retire_pr_bus.rd_phy_old])begin
                    PRF_valid[retire_pr_bus.rd_phy_old] <= 0;
                    PRF_busy[retire_pr_bus.rd_phy_new]  <= 0;
                end
                else begin
                    PRF_busy[retire_pr_bus.rd_phy_new]  <= 0;
                end
            end
        end
    end


    // For debugging: display PRF contents
    integer           mcd;
    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/PhysicalRegister.txt","w");
        $fdisplay(mcd,"Physical Register File Contents:");
        $fdisplay(mcd,"Index |    Data    | Busy | Valid");
        for (i = 0; i < PHY_REGS; i = i + 1) begin
            $fdisplay(mcd, "  %2d  | 0x%h |  %b   |  %b", i, PRF[i], PRF_busy[i], PRF_valid[i]);
        end
        $fdisplay(mcd,"---------------------------------------------------");
        $fclose(mcd);
    end

endmodule


