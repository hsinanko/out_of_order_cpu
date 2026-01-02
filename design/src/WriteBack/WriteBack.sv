`timescale 1ns/1ps

import parameter_pkg::*;

module WriteBack #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6)(
    input logic clk,
    input logic rst,
    // ============== from Execution (enqueue candidates) =================
    // from alu
    input logic [4:0]alu_rob_id,
    input logic [DATA_WIDTH-1:0] alu_result,
    input logic [4:0]rd_phy_alu,
    input logic alu_valid,
    // from load/store unit
    input logic [4:0]ls_rob_id,
    input logic [4:0]rd_phy_ls,
    input logic [DATA_WIDTH-1:0] mem_rdata,
    input logic mem_rdata_valid,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [ADDR_WIDTH-1:0] waddr,
    input logic wdata_valid,
    input logic ls_valid,
    // Branch information
    input logic [4:0]branch_rob_id,
    input logic [ADDR_WIDTH-1:0] jumpPC,
    input logic [ADDR_WIDTH-1:0] nextPC,
    input logic [4:0]rd_phy_branch,
    input logic isJump,
    input logic branch_valid,
    // ========== Physical Register Control signals ===========
    // outputs: commit to retirement/architectural state
    output  logic wb_en_alu,                      // commit enable signal
    output  logic [PHY_WIDTH-1:0]rd_wb_alu,                 // physical register address to commit
    output  logic [DATA_WIDTH-1:0] alu_output,     // data to writ
    // load/store commit interface
    output  logic [1:0] wb_en_ls,                       // commit enable signal
    output  logic [PHY_WIDTH-1:0]rd_wb_ls,                  // physical register address to commit
    output  logic [DATA_WIDTH-1:0] memory_output,  // data to write
    output  logic [DATA_WIDTH-1:0] wdata_wb,
    output  logic [ADDR_WIDTH-1:0] waddr_wb,
    // branch commit interface
    output  logic wb_en_branch,                   // commit enable signal
    output  logic [PHY_WIDTH-1:0]rd_wb_branch,              // physical register address to commit
    output  logic [ADDR_WIDTH-1:0] nextPC_reg,     // data to write
    // ================= ROB Commit Interface ==================
    output  logic       commit_alu_valid,
    output  logic [3:0] commit_alu_rob_id,
    output  logic       commit_ls_valid,
    output  logic [3:0] commit_ls_rob_id,
    output  logic       commit_branch_valid,
    output  logic [3:0] commit_branch_rob_id
);

    always_comb begin
        // alu
        wb_en_alu      = alu_valid;
        rd_wb_alu      = rd_phy_alu;
        alu_output     = alu_result;
        // load/store
        wb_en_ls[0]    = ls_valid & mem_rdata_valid;
        wb_en_ls[1]    = ls_valid & wdata_valid;
        rd_wb_ls       = rd_phy_ls;
        memory_output  = mem_rdata;
        wdata_wb       = wdata;
        waddr_wb       = waddr;
        // branch
        wb_en_branch   = branch_valid;
        rd_wb_branch   = rd_phy_branch;
        nextPC_reg     = nextPC;
    end

    always_comb begin
        // commit signals to ROB
        commit_alu_valid      = alu_valid;
        commit_alu_rob_id     = alu_rob_id;
        commit_ls_valid       = ls_valid & (mem_rdata_valid | wdata_valid);
        commit_ls_rob_id      = ls_rob_id;
        commit_branch_valid   = branch_valid;
        commit_branch_rob_id  = branch_rob_id;
    end

    // commit signals to ROB


endmodule

