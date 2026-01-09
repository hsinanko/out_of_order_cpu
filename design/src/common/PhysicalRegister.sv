`timescale 1ns / 1ps

import parameter_pkg::*;
import typedef_pkg::*;

module PhysicalRegister #(parameter REG_WIDTH = 32, PHY_REGS = 64, DATA_WIDTH = 32, PHY_WIDTH = 6)(
    input  logic clk,
    input  logic rst,
    input  logic flush,
    input  logic done,
    // ========= rename interface ====================
    input  logic [1:0]busy_valid,
    input  logic [REG_WIDTH-1:0]rd_phy_busy_0,   // mark rd_phy busy
    input  logic [REG_WIDTH-1:0]rd_phy_busy_1,   // mark rs1_phy busy
    output logic [PHY_REGS-1:0]PRF_busy,         // if busy = 1 => this register is not ready
    // ========= read execution interface ===============
    output logic [PHY_REGS-1:0]PRF_valid,
    // alu
    input  logic [PHY_WIDTH-1:0]rs1_phy_alu,               
    input  logic [PHY_WIDTH-1:0]rs2_phy_alu,
    output logic [DATA_WIDTH-1:0]rs1_data_alu,
    output logic [DATA_WIDTH-1:0]rs2_data_alu,
    input  logic alu_valid,
    // load/store
    input  logic [PHY_WIDTH-1:0]rs1_phy_ls,               
    input  logic [PHY_WIDTH-1:0]rs2_phy_ls,
    output logic [DATA_WIDTH-1:0]rs1_data_ls,
    output logic [DATA_WIDTH-1:0]rs2_data_ls,
    input  logic ls_valid,
    // branch
    input  logic [PHY_WIDTH-1:0]rs1_phy_branch,               
    input  logic [PHY_WIDTH-1:0]rs2_phy_branch,
    output logic [DATA_WIDTH-1:0]rs1_data_branch,
    output logic [DATA_WIDTH-1:0]rs2_data_branch,
    input  logic branch_valid,
    // =========== writeback interface =================
    // alu commit interface
    input  logic commit_alu_valid,                     // commit enable signal
    input  logic [PHY_WIDTH-1:0]commit_rd_alu,                 // physical register address to commit
    input  logic [REG_WIDTH-1:0]commit_alu_result,     // data to writ
    // load/store commit interface
    input  logic commit_load_valid,                       // commit enable signal
    input  logic [PHY_WIDTH-1:0]commit_rd_load,                  // physical register address to commit
    input  logic [REG_WIDTH-1:0]commit_load_rdata, // data to write
    // branch commit interface
    input  logic commit_jump_valid,                   // commit enable 
    input  logic commit_branch_valid,
    input  logic [PHY_WIDTH-1:0]commit_rd_branch,              // physical register address to commit
    input  logic [REG_WIDTH-1:0]commit_nextPC, // data to write
    // ============= commit /retire interface ====================
    input logic [PHY_WIDTH-1:0]rd_phy_old_commit,
    input logic [PHY_WIDTH-1:0]rd_phy_new_commit,
    input logic retire_valid,
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
    assign rs1_data_alu = (alu_valid) ? PRF[rs1_phy_alu] : 'hx;
    assign rs2_data_alu = (alu_valid) ? PRF[rs2_phy_alu] : 'hx;

    assign rs1_data_ls = (ls_valid) ? PRF[rs1_phy_ls] : 'hx;
    assign rs2_data_ls = (ls_valid) ? PRF[rs2_phy_ls] : 'hx;

    assign rs1_data_branch = (branch_valid) ? PRF[rs1_phy_branch] : 'hx;
    assign rs2_data_branch = (branch_valid) ? PRF[rs2_phy_branch] : 'hx;

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

            if(commit_alu_valid)begin
                PRF[commit_rd_alu]       <= commit_alu_result;
                PRF_valid[commit_rd_alu] <= 1;
            end
            if(commit_load_valid)begin
                PRF[commit_rd_load]       <= commit_load_rdata;
                PRF_valid[commit_rd_load] <= 1;
            end
            if(commit_jump_valid)begin
                if(commit_rd_branch != '0)begin
                    PRF[commit_rd_branch]       <= commit_nextPC;
                    PRF_valid[commit_rd_branch] <= 1;
                end
            end
            if(commit_branch_valid)begin
                PRF_valid[commit_rd_branch] <= 1;
            end
            if(retire_valid) begin
                if(!PRF_busy[rd_phy_old_commit])begin
                    PRF_valid[rd_phy_old_commit] <= 0;
                    PRF_busy[rd_phy_new_commit]  <= 0;
                end
                else begin
                    PRF_busy[rd_phy_new_commit]  <= 0;
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


