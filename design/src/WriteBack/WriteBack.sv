`timescale 1ns/1ps

import parameter_pkg::*;

module WriteBack #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5)(
    input logic clk,
    input logic rst,
    input logic flush,
    // ============== from Execution (enqueue candidates) =================
    // from alu
    input logic [ROB_WIDTH-1:0]alu_rob_id,
    input logic [DATA_WIDTH-1:0] alu_output,
    input logic [PHY_WIDTH-1:0]rd_phy_alu,
    input logic alu_valid,
    // from load/store unit
    input logic [ROB_WIDTH-1:0]ls_rob_id,
    input logic [PHY_WIDTH-1:0]rd_phy_ls,
    input logic [DATA_WIDTH-1:0] mem_rdata,
    input logic mem_rdata_valid,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [ADDR_WIDTH-1:0] waddr,
    input logic wdata_valid,
    input logic ls_valid,
    // Branch information
    input logic [ROB_WIDTH-1:0]branch_rob_id,
    input logic [ADDR_WIDTH-1:0] jumpPC,
    input logic [ADDR_WIDTH-1:0] nextPC,
    input logic [PHY_WIDTH-1:0]rd_phy_branch,
    input logic actual_taken,
    input logic mispredict,
    input logic [ADDR_WIDTH-1:0] update_pc,
    input logic isJump,
    input logic branch_valid,
    // ========== Physical Register & ROB Commit Interface ===========
    // alu
    output  logic                  commit_alu_valid,
    output  logic [ROB_WIDTH-1:0]  commit_alu_rob_id,
    output  logic [PHY_WIDTH-1:0]  commit_rd_alu,
    output  logic [DATA_WIDTH-1:0] commit_alu_result,
     // load/store
    output  logic [1:0]            commit_ls_valid,
    output  logic [ROB_WIDTH-1:0]  commit_ls_rob_id,
    output  logic [PHY_WIDTH-1:0]  commit_rd_ls,
    output  logic [DATA_WIDTH-1:0] commit_mem_output,
    output  logic [DATA_WIDTH-1:0] commit_wdata,
    output  logic [ADDR_WIDTH-1:0] commit_waddr,
    // branch
    output  logic                  commit_branch_valid,
    output  logic                  commit_jump_valid,
    output  logic [ROB_WIDTH-1:0]  commit_branch_rob_id,
    output  logic [PHY_WIDTH-1:0]  commit_rd_branch,
    output  logic [ADDR_WIDTH-1:0] commit_nextPC,
    output  logic                  commit_mispredict,
    output  logic [ADDR_WIDTH-1:0] commit_actual_target,
    output  logic                  commit_actual_taken,
    output  logic [ADDR_WIDTH-1:0] commit_update_pc
);


    always_comb begin
        // commit signals to ROB
        commit_alu_valid      = (flush) ? 1'b0 : alu_valid;
        commit_alu_rob_id     = alu_rob_id;
        commit_rd_alu         = rd_phy_alu;
        commit_alu_result     = alu_output;
        // load/store
        commit_ls_valid[0]    = (flush) ? 1'b0 : (ls_valid & mem_rdata_valid);
        commit_ls_valid[1]    = (flush) ? 1'b0 : (ls_valid & wdata_valid);
        commit_ls_rob_id      = ls_rob_id;
        commit_rd_ls          = rd_phy_ls;
        commit_mem_output     = mem_rdata;
        commit_wdata          = wdata;
        commit_waddr          = waddr;
        // branch
        commit_branch_valid   = (flush) ? 1'b0 : branch_valid;
        commit_jump_valid     = (flush) ? 1'b0 : isJump;
        commit_branch_rob_id  = branch_rob_id;
        commit_rd_branch      = rd_phy_branch;
        commit_nextPC         = nextPC;
        commit_mispredict     = mispredict;
        commit_actual_target  = jumpPC;
        commit_actual_taken   = actual_taken;
        commit_update_pc      = update_pc;
    end

    // commit signals to ROB


endmodule

