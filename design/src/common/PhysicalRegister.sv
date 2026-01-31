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
    input WB_alu_t wb_alu,
    input WB_load_t wb_load,
    input WB_branch_t wb_branch,
    // ============= commit /retire interface ====================
    retire_if.retire_pr_sink retire_pr_bus_0,
    retire_if.retire_pr_sink retire_pr_bus_1,
    // === debugging interface =========================
    output logic [PHY_REGS*DATA_WIDTH-1:0]PRF_data_out,
    output logic [PHY_REGS-1:0]PRF_busy_out,
    output logic [PHY_REGS-1:0]PRF_valid_out
);
    // Physical Register file
    // | Tag | Architected Reg | Data | Valid | Busy |
    integer i;
    logic [DATA_WIDTH-1:0] PRF [0:PHY_REGS-1];

    logic [PHY_REGS-1:0] PRF_busy_tmp;
    logic [PHY_REGS-1:0] PRF_valid_tmp;

    logic retire_pr_valid_0, retire_pr_valid_1;
    logic [PHY_WIDTH-1:0] rd_arch_0, rd_arch_1;
    logic [PHY_WIDTH-1:0] rd_phy_old_0, rd_phy_old_1;
    logic [PHY_WIDTH-1:0] rd_phy_new_0, rd_phy_new_1;
    assign retire_pr_valid_0 = retire_pr_bus_0.retire_pr_pkg.retire_pr_valid;
    assign rd_arch_0         = retire_pr_bus_0.retire_pr_pkg.rd_arch;
    assign rd_phy_old_0      = retire_pr_bus_0.retire_pr_pkg.rd_phy_old;
    assign rd_phy_new_0      = retire_pr_bus_0.retire_pr_pkg.rd_phy_new;

    assign retire_pr_valid_1 = retire_pr_bus_1.retire_pr_pkg.retire_pr_valid;
    assign rd_arch_1         = retire_pr_bus_1.retire_pr_pkg.rd_arch;
    assign rd_phy_old_1      = retire_pr_bus_1.retire_pr_pkg.rd_phy_old;
    assign rd_phy_new_1      = retire_pr_bus_1.retire_pr_pkg.rd_phy_new;
    
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
            PRF_busy  <= PRF_busy_tmp;
            PRF_valid <= PRF_valid_tmp;
            // =========== writeback to PRF ==================
            if(wb_alu.alu_valid)begin
                PRF[wb_alu.rd_alu]       <= wb_alu.alu_result;
            end
            if(wb_load.load_valid)begin
                PRF[wb_load.rd_load]       <= wb_load.load_rdata;
            end
            if(wb_branch.branch_valid)begin
                if(wb_branch.jump_valid )begin
                    PRF[wb_branch.rd_branch] <= wb_branch.nextPC;
                end
            end

        end
    end


    always_comb begin
        PRF_busy_tmp = PRF_busy;
        PRF_valid_tmp = PRF_valid;
        if(flush || done) begin
            PRF_busy_tmp = 'h0;
        end
        else begin
            // =========== mark physical registers as busy ==================
            if(busy_valid[0])begin
                PRF_busy_tmp[rd_phy_busy_0]  = 1;
                PRF_valid_tmp[rd_phy_busy_0] = 0;
            end
            if(busy_valid[1])begin
                PRF_busy_tmp[rd_phy_busy_1]  = 1;
                PRF_valid_tmp[rd_phy_busy_1] = 0;
            end
            // =========== writeback to PRF ==================
            if(wb_alu.alu_valid)begin
                PRF_valid_tmp[wb_alu.rd_alu] = 1;
            end
            if(wb_load.load_valid)begin
                PRF_valid_tmp[wb_load.rd_load] = 1;
            end
            if(wb_branch.branch_valid)begin
                if(wb_branch.jump_valid )begin
                    PRF_valid_tmp[wb_branch.rd_branch] = 1;
                end
            end
            // =========== free physical registers on retire ==========
            if(retire_pr_valid_0) begin
                PRF_busy_tmp[rd_phy_new_0]  = 0;
                if(!PRF_busy[rd_phy_old_0])begin
                    PRF_valid_tmp[rd_phy_old_0] = 0;
                end
            end

            if(retire_pr_valid_1)begin
                PRF_busy_tmp[rd_phy_new_1]  = 0;
                if(!PRF_busy[rd_phy_old_1])begin
                    PRF_valid_tmp[rd_phy_old_1] = 0;
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


