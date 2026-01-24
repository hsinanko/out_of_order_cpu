`timescale 1ns/1ps
import typedef_pkg::*;
module Retire #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, NUM_ROB_ENTRY = 16)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                 flush,
    input  logic [NUM_ROB_ENTRY-1:0]       ROB_FINISH,
    input  ROB_ENTRY_t ROB[NUM_ROB_ENTRY-1:0],
    input  logic [ROB_WIDTH-1:0]  rob_head,
    output logic                  isFlush,
    output logic [4:0]            targetPC,
    output logic [4:0]            rd_arch_commit,
    output logic [PHY_WIDTH-1:0]  rd_phy_old_commit,
    output logic [PHY_WIDTH-1:0]  rd_phy_new_commit,
    output logic [ADDR_WIDTH-1:0] update_btb_pc,
    output logic [ADDR_WIDTH-1:0] update_btb_target,
    output logic                  update_btb_taken,
    output logic                  retire_pr_valid,
    output logic                  retire_store_valid, // retire store valid
    output logic                  retire_branch_valid,
    output logic                  retire_done_valid,
    output logic [ROB_WIDTH-1:0] rob_debug,
    output logic [ADDR_WIDTH-1:0] retire_addr
);



    logic isALU, isLoad, isStore, isBranch;
    assign isALU = (ROB[rob_head].opcode == OP_IMM || ROB[rob_head].opcode == OP || ROB[rob_head].opcode == LUI || ROB[rob_head].opcode == AUIPC);
    assign isLoad = (ROB[rob_head].opcode == LOAD);
    assign isStore = (ROB[rob_head].opcode == STORE);
    assign isBranch = (ROB[rob_head].opcode == BRANCH);
    assign isJump = (ROB[rob_head].opcode == JAL || ROB[rob_head].opcode == JALR);
    assign isSystem = (ROB[rob_head].opcode == SYSTEM);


    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            isFlush <= 1'b0;
        end
        else if(flush) begin
            isFlush <= 1'b0;
        end
        else begin
            if(ROB_FINISH[rob_head] && (isBranch || isJump)) begin
                isFlush  <= ROB[rob_head].mispredict;
                targetPC <= ROB[rob_head].actual_target;
            end
            else begin
                isFlush <= 1'b0;
            end
        end
    end


    always_comb begin
        if(flush)begin
            rd_arch_commit      = 'h0;
            rd_phy_old_commit   = 'h0;
            rd_phy_new_commit   = 'h0;
            update_btb_pc       = 'h0;
            update_btb_taken    = 1'b0;
            update_btb_target   = 'h0;
            retire_pr_valid     = 1'b0;
            retire_store_valid  = 1'b0;
            retire_branch_valid = 1'b0;
            retire_done_valid   = 1'b0;
        end
        else if(ROB_FINISH[rob_head]) begin
            rob_debug   = rob_head;
            retire_addr = ROB[rob_head].addr;
            if(isALU) begin
                rd_arch_commit      = ROB[rob_head].rd_arch;
                rd_phy_old_commit   = ROB[rob_head].rd_phy_old;
                rd_phy_new_commit   = ROB[rob_head].rd_phy_new;
                update_btb_pc       = '0;
                update_btb_taken    = '0;             
                update_btb_target   = '0;
                retire_pr_valid     = 1'b1;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b0;
                retire_done_valid   = 1'b0;
            end
            else if(isLoad) begin
                rd_arch_commit      = ROB[rob_head].rd_arch;
                rd_phy_old_commit   = ROB[rob_head].rd_phy_old;
                rd_phy_new_commit   = ROB[rob_head].rd_phy_new;
                update_btb_pc       = '0;
                update_btb_taken    = '0;
                update_btb_target   = '0;
                retire_pr_valid     = 1'b1;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b0;
                retire_done_valid   = 1'b0;
            end
            else if(isStore) begin
                rd_arch_commit      = ROB[rob_head].rd_arch;
                rd_phy_old_commit   = ROB[rob_head].rd_phy_old;
                rd_phy_new_commit   = ROB[rob_head].rd_phy_new;
                update_btb_pc       = '0;
                update_btb_taken    = '0;
                update_btb_target   = '0;
                retire_pr_valid     = 1'b0;
                retire_store_valid  = 1'b1;
                retire_branch_valid = 1'b0;
                retire_done_valid   = 1'b0;
            end
            else if(isBranch) begin
                rd_arch_commit      = 'h0;
                rd_phy_old_commit   = 'h0;
                rd_phy_new_commit   = 'h0;
                update_btb_pc       = ROB[rob_head].update_pc;
                update_btb_taken    = ROB[rob_head].actual_taken;
                update_btb_target   = ROB[rob_head].actual_target;
                retire_pr_valid     = 1'b0;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b1;
                retire_done_valid   = 1'b0;
            end
            else if(isJump)begin
                rd_arch_commit      = ROB[rob_head].rd_arch;
                rd_phy_old_commit   = ROB[rob_head].rd_phy_old;
                rd_phy_new_commit   = ROB[rob_head].rd_phy_new;
                update_btb_pc       = ROB[rob_head].update_pc;
                update_btb_taken    = ROB[rob_head].actual_taken;
                update_btb_target   = ROB[rob_head].actual_target;
                retire_pr_valid     = (rd_arch_commit != 'h0) ? 1'b1 : 1'b0;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b1;
                retire_done_valid   = 1'b0;
            end
            else if(isSystem)begin
                rd_arch_commit      = 'h0;
                rd_phy_old_commit   = 'h0;
                rd_phy_new_commit   = 'h0;
                update_btb_pc       = 'h0;
                update_btb_taken    = 'b0;
                update_btb_target   = 'h0;
                retire_pr_valid     = 1'b0;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b0;
                retire_done_valid   = 1'b1;
            end
            else begin
                rd_arch_commit      = 'h0;
                rd_phy_old_commit   = 'h0;
                rd_phy_new_commit   = 'h0;
                update_btb_pc       = 'h0;
                update_btb_taken    = 1'b0;
                update_btb_target   = 'h0;
                retire_pr_valid     = 1'b0;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b0;
                retire_done_valid   = 1'b0;
            end
        end
        else begin
            rd_arch_commit      = 'h0;
            rd_phy_old_commit   = 'h0;
            rd_phy_new_commit   = 'h0;
            update_btb_pc       = 'h0;
            update_btb_taken    = 1'b0;
            update_btb_target   = 'h0;
            retire_pr_valid     = 1'b0;
            retire_store_valid  = 1'b0;
            retire_branch_valid = 1'b0;
            retire_done_valid   = 1'b0;
        end
    end

endmodule
