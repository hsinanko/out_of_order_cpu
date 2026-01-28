`timescale 1ns/1ps
import typedef_pkg::*;
module Retire #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, NUM_ROB_ENTRY = 32, FIFO_DEPTH = 16)(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,
    input  ROB_status_t rob_status,
    retire_if.retire_source retire_bus
);

    logic [NUM_ROB_ENTRY-1:0] ROB_FINISH;
    ROB_ENTRY_t ROB[NUM_ROB_ENTRY-1:0];
    logic [ROB_WIDTH-1:0] rob_head;
    logic [ROB_WIDTH-1:0] rob_full;
    logic [ROB_WIDTH-1:0] rob_empty;


    assign ROB_FINISH = rob_status.rob_finish;
    assign ROB = rob_status.rob;
    assign rob_head = rob_status.rob_head;
    assign rob_full = rob_status.rob_full;
    assign rob_empty = rob_status.rob_empty;

    logic isALU, isLoad, isStore, isBranch, isJump, isSystem;
    assign isALU = (ROB[rob_head].opcode == OP_IMM || ROB[rob_head].opcode == OP || ROB[rob_head].opcode == LUI || ROB[rob_head].opcode == AUIPC);
    assign isLoad = (ROB[rob_head].opcode == LOAD);
    assign isStore = (ROB[rob_head].opcode == STORE);
    assign isBranch = (ROB[rob_head].opcode == BRANCH);
    assign isJump = (ROB[rob_head].opcode == JAL || ROB[rob_head].opcode == JALR);
    assign isSystem = (ROB[rob_head].opcode == SYSTEM);


    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            retire_bus.isFlush <= 1'b0;
        end
        else if(flush) begin
            retire_bus.isFlush <= 1'b0;
        end
        else begin
            if(ROB_FINISH[rob_head] && (isBranch || isJump)) begin
                retire_bus.isFlush  <= ROB[rob_head].mispredict;
                retire_bus.targetPC <= ROB[rob_head].actual_target;
            end
            else begin
                retire_bus.isFlush <= 1'b0;
            end
        end
    end


    always_comb begin
        if(flush)begin
            retire_bus.rd_arch             = 'h0;
            retire_bus.rd_phy_old          = 'h0;
            retire_bus.rd_phy_new          = 'h0;
            retire_bus.update_btb_pc       = 'h0;
            retire_bus.update_btb_taken    = 1'b0;
            retire_bus.update_btb_target   = 'h0;
            retire_bus.retire_pr_valid     = 1'b0;
            retire_bus.retire_store_valid  = 1'b0;
            retire_bus.retire_store_id     = '0;
            retire_bus.retire_branch_valid = 1'b0;
            retire_bus.retire_done_valid   = 1'b0;
        end
        else if(ROB_FINISH[rob_head]) begin
            retire_bus.rob_debug   = rob_head;
            retire_bus.retire_addr = ROB[rob_head].addr;
            if(isALU) begin
                retire_bus.rd_arch             = ROB[rob_head].rd_arch;
                retire_bus.rd_phy_old          = ROB[rob_head].rd_phy_old;
                retire_bus.rd_phy_new          = ROB[rob_head].rd_phy_new;
                retire_bus.update_btb_pc       = '0;
                retire_bus.update_btb_taken    = '0;             
                retire_bus.update_btb_target   = '0;
                retire_bus.retire_pr_valid     = 1'b1;
                retire_bus.retire_store_valid  = 1'b0;
                retire_bus.retire_store_id     = '0;
                retire_bus.retire_branch_valid = 1'b0;
                retire_bus.retire_done_valid   = 1'b0;
            end
            else if(isLoad) begin
                retire_bus.rd_arch             = ROB[rob_head].rd_arch;
                retire_bus.rd_phy_old          = ROB[rob_head].rd_phy_old;
                retire_bus.rd_phy_new          = ROB[rob_head].rd_phy_new;
                retire_bus.update_btb_pc       = '0;
                retire_bus.update_btb_taken    = '0;
                retire_bus.update_btb_target   = '0;
                retire_bus.retire_pr_valid     = 1'b1;
                retire_bus.retire_store_valid  = 1'b0;
                retire_bus.retire_store_id     = '0;
                retire_bus.retire_branch_valid = 1'b0;
                retire_bus.retire_done_valid   = 1'b0;
            end
            else if(isStore) begin
                retire_bus.rd_arch             = ROB[rob_head].rd_arch;
                retire_bus.rd_phy_old          = ROB[rob_head].rd_phy_old;
                retire_bus.rd_phy_new          = ROB[rob_head].rd_phy_new;
                retire_bus.update_btb_pc       = '0;
                retire_bus.update_btb_taken    = '0;
                retire_bus.update_btb_target   = '0;
                retire_bus.retire_pr_valid     = 1'b0;
                retire_bus.retire_store_valid  = 1'b1;
                retire_bus.retire_store_id     = ROB[rob_head].store_id;
                retire_bus.retire_branch_valid = 1'b0;
                retire_bus.retire_done_valid   = 1'b0;
            end
            else if(isBranch) begin
                retire_bus.rd_arch             = 'h0;
                retire_bus.rd_phy_old          = 'h0;
                retire_bus.rd_phy_new          = 'h0;
                retire_bus.update_btb_pc       = ROB[rob_head].update_pc;
                retire_bus.update_btb_taken    = ROB[rob_head].actual_taken;
                retire_bus.update_btb_target   = ROB[rob_head].actual_target;
                retire_bus.retire_pr_valid     = 1'b0;
                retire_bus.retire_store_valid  = 1'b0;
                retire_bus.retire_store_id     = '0;
                retire_bus.retire_branch_valid = 1'b1;
                retire_bus.retire_done_valid   = 1'b0;
            end
            else if(isJump)begin
                retire_bus.rd_arch             = ROB[rob_head].rd_arch;
                retire_bus.rd_phy_old          = ROB[rob_head].rd_phy_old;
                retire_bus.rd_phy_new          = ROB[rob_head].rd_phy_new;
                retire_bus.update_btb_pc       = ROB[rob_head].update_pc;
                retire_bus.update_btb_taken    = ROB[rob_head].actual_taken;
                retire_bus.update_btb_target   = ROB[rob_head].actual_target;
                retire_bus.retire_pr_valid     = (retire_bus.rd_arch != 'h0) ? 1'b1 : 1'b0;
                retire_bus.retire_store_valid  = 1'b0;
                retire_bus.retire_store_id     = '0;
                retire_bus.retire_branch_valid = 1'b1;
                retire_bus.retire_done_valid   = 1'b0;
            end
            else if(isSystem)begin
                retire_bus.rd_arch             = 'h0;
                retire_bus.rd_phy_old          = 'h0;
                retire_bus.rd_phy_new          = 'h0;
                retire_bus.update_btb_pc       = 'h0;
                retire_bus.update_btb_taken    = 'b0;
                retire_bus.update_btb_target   = 'h0;
                retire_bus.retire_pr_valid     = 1'b0;
                retire_bus.retire_store_valid  = 1'b0;
                retire_bus.retire_store_id     = '0;
                retire_bus.retire_branch_valid = 1'b0;
                retire_bus.retire_done_valid   = 1'b1;
            end
            else begin
                retire_bus.rd_arch             = 'h0;
                retire_bus.rd_phy_old          = 'h0;
                retire_bus.rd_phy_new          = 'h0;
                retire_bus.update_btb_pc       = 'h0;
                retire_bus.update_btb_taken    = 1'b0;
                retire_bus.update_btb_target   = 'h0;
                retire_bus.retire_pr_valid     = 1'b0;
                retire_bus.retire_store_valid  = 1'b0;
                retire_bus.retire_store_id     = '0;
                retire_bus.retire_branch_valid = 1'b0;
                retire_bus.retire_done_valid   = 1'b0;
            end
        end
        else begin
            retire_bus.rd_arch             = 'h0;
            retire_bus.rd_phy_old          = 'h0;
            retire_bus.rd_phy_new          = 'h0;
            retire_bus.update_btb_pc       = 'h0;
            retire_bus.update_btb_taken    = 1'b0;
            retire_bus.update_btb_target   = 'h0;
            retire_bus.retire_pr_valid     = 1'b0;
            retire_bus.retire_store_valid  = 1'b0;
            retire_bus.retire_store_id     = '0;
            retire_bus.retire_branch_valid = 1'b0;
            retire_bus.retire_done_valid   = 1'b0;
        end
    end

endmodule
