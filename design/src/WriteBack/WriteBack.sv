`timescale 1ns/1ps

import parameter_pkg::*;

module WriteBack #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6)(
    input logic clk,
    input logic rst,
    input logic flush,
    // ============== from Execution (enqueue candidates) =================
    // from alu
    input logic [4:0]alu_rob_id,
    input logic [DATA_WIDTH-1:0] alu_output,
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
    input logic mispredict,
    input logic isJump,
    input logic branch_valid,
    // ========== Physical Register Control signals ===========
    // outputs: commit to retirement/architectural state
    output  logic alu_wb_en,                      // commit enable signal
    output  logic [PHY_WIDTH-1:0]rd_alu_wb,                 // physical register address to commit
    output  logic [DATA_WIDTH-1:0] alu_result,     // data to writ
    // load/store commit interface
    output  logic [1:0] ls_wb_en,                       // commit enable signal
    output  logic [PHY_WIDTH-1:0]rd_ls_wb,                  // physical register address to commit
    output  logic [DATA_WIDTH-1:0] memory_output,  // data to write
    output  logic [DATA_WIDTH-1:0] wdata_wb,
    output  logic [ADDR_WIDTH-1:0] waddr_wb,
    // branch commit interface
    output  logic branch_wb_en,                   // commit enable signal
    output  logic [PHY_WIDTH-1:0]rd_branch_wb,              // physical register address to commit
    output  logic [ADDR_WIDTH-1:0] nextPC_wb,     // data to write
    
    // ================= ROB Commit Interface ==================
    output  logic       commit_alu_valid,
    output  logic [3:0] commit_alu_rob_id,
    output  logic       commit_ls_valid,
    output  logic [3:0] commit_ls_rob_id,
    output  logic       commit_branch_valid,
    output  logic [3:0] commit_branch_rob_id,
    output  logic       commit_mispredict,
    output  logic [ADDR_WIDTH-1:0] commit_actual_target
);

    always_comb begin
        // alu
        alu_wb_en      = (flush ) ? 1'b0 : alu_valid;
        rd_alu_wb      = rd_phy_alu;
        alu_result     = alu_output;
        // load/store
        ls_wb_en[0]    = (flush ) ? 1'b0 : (ls_valid & mem_rdata_valid);
        ls_wb_en[1]    = (flush ) ? 1'b0 : (ls_valid & wdata_valid);
        rd_ls_wb       = rd_phy_ls;
        memory_output  = mem_rdata;
        wdata_wb       = wdata;
        waddr_wb       = waddr;
        // branch
        branch_wb_en   = (flush ) ? 1'b0 : branch_valid;
        rd_branch_wb   = rd_phy_branch;
        nextPC_wb    = nextPC;
    end

    always_comb begin
        // commit signals to ROB
        commit_alu_valid      = (flush ) ? 1'b0 : alu_valid;
        commit_alu_rob_id     = alu_rob_id;
        commit_ls_valid       = (flush ) ? 1'b0 : (ls_valid & (mem_rdata_valid | wdata_valid));
        commit_ls_rob_id      = ls_rob_id;
        commit_branch_valid   = (flush ) ? 1'b0 : branch_valid;
        commit_branch_rob_id  = branch_rob_id;
        commit_mispredict     = mispredict;
        commit_actual_target  = (isJump) ? jumpPC : nextPC;
    end

    // commit signals to ROB


endmodule

