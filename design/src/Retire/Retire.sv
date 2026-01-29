`timescale 1ns/1ps
import typedef_pkg::*;
module Retire #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, NUM_ROB_ENTRY = 32, FIFO_DEPTH = 16)(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,
    rob_status_if.sink  rob_status,
    retire_if.retire_source retire_bus_0,
    retire_if.retire_source retire_bus_1
);

    logic [NUM_ROB_ENTRY-1:0] ROB_FINISH;
    ROB_ENTRY_t ROB[NUM_ROB_ENTRY-1:0];
    logic [ROB_WIDTH-1:0] rob_head;
    logic rob_full;
    logic rob_empty;
    logic [ROB_WIDTH-1:0]retire_num;

    RETIRE_PR_t     retire_pr_pkg_0, retire_pr_pkg_1;
    RETIRE_STORE_t  retire_store_pkg_0, retire_store_pkg_1;
    RETIRE_BRANCH_t retire_branch_pkg_0, retire_branch_pkg_1;

    assign ROB_FINISH = rob_status.rob_finish;
    assign ROB        = rob_status.rob;
    assign rob_head   = rob_status.rob_head;
    assign rob_full   = rob_status.rob_full;
    assign rob_empty  = rob_status.rob_empty;
    assign rob_status.retire_num = retire_num;

    logic isALU_0, isLoad_0, isStore_0, isBranch_0, isJump_0, isSystem_0;
    assign isALU_0 = (ROB[rob_head].opcode == OP_IMM || ROB[rob_head].opcode == OP || ROB[rob_head].opcode == LUI || ROB[rob_head].opcode == AUIPC);
    assign isLoad_0 = (ROB[rob_head].opcode == LOAD);
    assign isStore_0 = (ROB[rob_head].opcode == STORE);
    assign isBranch_0 = (ROB[rob_head].opcode == BRANCH);
    assign isJump_0 = (ROB[rob_head].opcode == JAL || ROB[rob_head].opcode == JALR);
    assign isSystem_0 = (ROB[rob_head].opcode == SYSTEM);

    logic isALU_1, isLoad_1, isStore_1, isBranch_1, isJump_1, isSystem_1;
    assign isALU_1 = (ROB[rob_head+1].opcode == OP_IMM || ROB[rob_head+1].opcode == OP || ROB[rob_head+1].opcode == LUI || ROB[rob_head+1].opcode == AUIPC);
    assign isLoad_1 = (ROB[rob_head+1].opcode == LOAD);
    assign isStore_1 = (ROB[rob_head+1].opcode == STORE);
    assign isBranch_1 = (ROB[rob_head+1].opcode == BRANCH);
    assign isJump_1 = (ROB[rob_head+1].opcode == JAL || ROB[rob_head+1].opcode == JALR);
    assign isSystem_1 = (ROB[rob_head+1].opcode == SYSTEM);

    // Retire Logic
    assign retire_bus_0.retire_pr_pkg     = retire_pr_pkg_0;
    assign retire_bus_0.retire_store_pkg  = retire_store_pkg_0;
    assign retire_bus_0.retire_branch_pkg = retire_branch_pkg_0;

    assign retire_bus_1.retire_pr_pkg     = retire_pr_pkg_1;
    assign retire_bus_1.retire_store_pkg  = retire_store_pkg_1;
    assign retire_bus_1.retire_branch_pkg = retire_branch_pkg_1;


    logic retire_second_block;
    assign retire_second_block = 1 || ((isStore_0 && isStore_1) ||
                                 (isBranch_0 && isBranch_1) ||
                                 (isJump_0 && isJump_1) ||
                                 (isSystem_0 && isSystem_1));

    always_comb begin
        if(flush) 
            retire_num = 0;
        else if(ROB_FINISH[rob_head])begin
            if(ROB_FINISH[rob_head+1])begin 
                if(retire_second_block) 
                    retire_num = 1;
                else 
                    retire_num = 2;
            end
            else
                retire_num = 1;
        end
        else begin
            retire_num = 0;
        end
    end

    always_comb begin
        if(flush)begin
            retire_pr_pkg_0.rd_arch                 = 'h0;
            retire_pr_pkg_0.rd_phy_old              = 'h0;
            retire_pr_pkg_0.rd_phy_new              = 'h0;
            retire_pr_pkg_0.retire_pr_valid         = 1'b0;

            retire_branch_pkg_0.update_btb_pc       = 'h0;
            retire_branch_pkg_0.update_btb_taken    = 1'b0;
            retire_branch_pkg_0.update_btb_target   = 'h0;
            retire_branch_pkg_0.retire_branch_valid = 1'b0;

            retire_store_pkg_0.retire_store_valid   = 1'b0;
            retire_store_pkg_0.retire_store_id      = '0;

            retire_bus_0.isFlush             = 'h0;
            retire_bus_0.targetPC            = 'h0;
            retire_bus_0.retire_done_valid   = 1'b0;
        end
        else if(ROB_FINISH[rob_head]) begin
            retire_bus_0.rob_debug   = rob_head;
            retire_bus_0.retire_addr = ROB[rob_head].addr;
            if(isALU_0) begin
                retire_pr_pkg_0.rd_arch                 = ROB[rob_head].rd_arch;
                retire_pr_pkg_0.rd_phy_old              = ROB[rob_head].rd_phy_old;
                retire_pr_pkg_0.rd_phy_new              = ROB[rob_head].rd_phy_new;
                retire_pr_pkg_0.retire_pr_valid         = 1'b1;

                retire_branch_pkg_0.update_btb_pc       = '0;
                retire_branch_pkg_0.update_btb_taken    = '0;             
                retire_branch_pkg_0.update_btb_target   = '0;
                retire_branch_pkg_0.retire_branch_valid = 1'b0;

                retire_store_pkg_0.retire_store_valid   = 1'b0;
                retire_store_pkg_0.retire_store_id      = '0;

                retire_bus_0.isFlush             = 'h0;
                retire_bus_0.targetPC            = 'h0;
                retire_bus_0.retire_done_valid   = 1'b0;
            end
            else if(isLoad_0) begin
                retire_pr_pkg_0.rd_arch                 = ROB[rob_head].rd_arch;
                retire_pr_pkg_0.rd_phy_old              = ROB[rob_head].rd_phy_old;
                retire_pr_pkg_0.rd_phy_new              = ROB[rob_head].rd_phy_new;

                retire_pr_pkg_0.retire_pr_valid         = 1'b1;
                retire_branch_pkg_0.update_btb_pc       = '0;
                retire_branch_pkg_0.update_btb_taken    = '0;
                retire_branch_pkg_0.update_btb_target   = '0;
                retire_branch_pkg_0.retire_branch_valid = 1'b0;

                retire_store_pkg_0.retire_store_valid   = 1'b0;
                retire_store_pkg_0.retire_store_id      = '0;
                
                retire_bus_0.isFlush             = 'h0;
                retire_bus_0.targetPC            = 'h0;
                retire_bus_0.retire_done_valid   = 1'b0;
            end
            else if(isStore_0) begin
                retire_pr_pkg_0.rd_arch                 = ROB[rob_head].rd_arch;
                retire_pr_pkg_0.rd_phy_old              = ROB[rob_head].rd_phy_old;
                retire_pr_pkg_0.rd_phy_new              = ROB[rob_head].rd_phy_new;
                retire_pr_pkg_0.retire_pr_valid         = 1'b0;

                retire_branch_pkg_0.update_btb_pc       = '0;
                retire_branch_pkg_0.update_btb_taken    = '0;
                retire_branch_pkg_0.update_btb_target   = '0;
                retire_branch_pkg_0.retire_branch_valid = 1'b0;

                retire_store_pkg_0.retire_store_valid   = 1'b1;
                retire_store_pkg_0.retire_store_id      = ROB[rob_head].store_id;

                retire_bus_0.isFlush             = 'h0;
                retire_bus_0.targetPC            = 'h0;
                retire_bus_0.retire_done_valid   = 1'b0;
            end
            else if(isBranch_0) begin
                retire_pr_pkg_0.rd_arch             = 'h0;
                retire_pr_pkg_0.rd_phy_old          = 'h0;
                retire_pr_pkg_0.rd_phy_new          = 'h0;
                retire_pr_pkg_0.retire_pr_valid     = 1'b0;

                retire_branch_pkg_0.update_btb_pc       = ROB[rob_head].update_pc;
                retire_branch_pkg_0.update_btb_taken    = ROB[rob_head].actual_taken;
                retire_branch_pkg_0.update_btb_target   = ROB[rob_head].actual_target;
                retire_branch_pkg_0.retire_branch_valid = 1'b1;

                retire_store_pkg_0.retire_store_valid   = 1'b0;
                retire_store_pkg_0.retire_store_id      = '0;

                retire_bus_0.isFlush             = ROB[rob_head].mispredict;
                retire_bus_0.targetPC            = ROB[rob_head].actual_target;
                retire_bus_0.retire_done_valid   = 1'b0;
            end
            else if(isJump_0)begin
                retire_pr_pkg_0.rd_arch                 = ROB[rob_head].rd_arch;
                retire_pr_pkg_0.rd_phy_old              = ROB[rob_head].rd_phy_old;
                retire_pr_pkg_0.rd_phy_new              = ROB[rob_head].rd_phy_new;
                retire_pr_pkg_0.retire_pr_valid         = (retire_pr_pkg_0.rd_arch != 'h0) ? 1'b1 : 1'b0;
                
                retire_branch_pkg_0.update_btb_pc       = ROB[rob_head].update_pc;
                retire_branch_pkg_0.update_btb_taken    = ROB[rob_head].actual_taken;
                retire_branch_pkg_0.update_btb_target   = ROB[rob_head].actual_target;
                retire_branch_pkg_0.retire_branch_valid = 1'b1;

                retire_store_pkg_0.retire_store_valid   = 1'b0;
                retire_store_pkg_0.retire_store_id      = '0;

                retire_bus_0.isFlush             = ROB[rob_head].mispredict;
                retire_bus_0.targetPC            = ROB[rob_head].actual_target;
                retire_bus_0.retire_done_valid   = 1'b0;
            end
            else if(isSystem_0)begin
                retire_pr_pkg_0.rd_arch             = 'h0;
                retire_pr_pkg_0.rd_phy_old          = 'h0;
                retire_pr_pkg_0.rd_phy_new          = 'h0;
                retire_pr_pkg_0.retire_pr_valid     = 1'b0;

                retire_branch_pkg_0.update_btb_pc       = 'h0;
                retire_branch_pkg_0.update_btb_taken    = 'b0;
                retire_branch_pkg_0.update_btb_target   = 'h0;
                retire_branch_pkg_0.retire_branch_valid = 1'b0;

                retire_store_pkg_0.retire_store_valid  = 1'b0;
                retire_store_pkg_0.retire_store_id     = '0;

                retire_bus_0.isFlush             = 'h0;
                retire_bus_0.targetPC            = 'h0;
                retire_bus_0.retire_done_valid   = 1'b1;
            end
            else begin
                retire_pr_pkg_0.rd_arch             = 'h0;
                retire_pr_pkg_0.rd_phy_old          = 'h0;
                retire_pr_pkg_0.rd_phy_new          = 'h0;
                retire_pr_pkg_0.retire_pr_valid     = 1'b0;

                retire_branch_pkg_0.update_btb_pc       = 'h0;
                retire_branch_pkg_0.update_btb_taken    = 1'b0;
                retire_branch_pkg_0.update_btb_target   = 'h0;
                retire_branch_pkg_0.retire_branch_valid = 1'b0;

                retire_store_pkg_0.retire_store_valid  = 1'b0;
                retire_store_pkg_0.retire_store_id     = '0;

                retire_bus_0.isFlush             = 'h0;
                retire_bus_0.targetPC            = 'h0;
                retire_bus_0.retire_done_valid   = 1'b0;
            end
        end
        else begin

            retire_pr_pkg_0.rd_arch             = 'h0;
            retire_pr_pkg_0.rd_phy_old          = 'h0;
            retire_pr_pkg_0.rd_phy_new          = 'h0;
            retire_pr_pkg_0.retire_pr_valid     = 1'b0;

            retire_branch_pkg_0.update_btb_pc       = 'h0;
            retire_branch_pkg_0.update_btb_taken    = 1'b0;
            retire_branch_pkg_0.update_btb_target   = 'h0;
            retire_branch_pkg_0.retire_branch_valid = 1'b0;

            retire_store_pkg_0.retire_store_valid  = 1'b0;
            retire_store_pkg_0.retire_store_id     = '0;

            retire_bus_0.isFlush             = 'h0;
            retire_bus_0.targetPC            = 'h0;
            retire_bus_0.retire_done_valid   = 1'b0;
            // debugging info
            retire_bus_0.rob_debug   = 'h0;
            retire_bus_0.retire_addr = 'h0;
        end
    end


    //======================= Retire second instruction ==============================

    
    always_comb begin
        if(flush)begin
            retire_pr_pkg_1.rd_arch                 = 'h0;
            retire_pr_pkg_1.rd_phy_old              = 'h0;
            retire_pr_pkg_1.rd_phy_new              = 'h0;
            retire_pr_pkg_1.retire_pr_valid         = 1'b0;

            retire_branch_pkg_1.update_btb_pc       = 'h0;
            retire_branch_pkg_1.update_btb_taken    = 1'b0;
            retire_branch_pkg_1.update_btb_target   = 'h0;
            retire_branch_pkg_1.retire_branch_valid = 1'b0;

            retire_store_pkg_1.retire_store_valid   = 1'b0;
            retire_store_pkg_1.retire_store_id      = '0;

            retire_bus_1.isFlush             = 'h0;
            retire_bus_1.targetPC            = 'h0;
            retire_bus_1.retire_done_valid   = 1'b0;
        end
        else if(ROB_FINISH[rob_head] && ROB_FINISH[rob_head+1] && !retire_second_block) begin
            retire_bus_1.rob_debug   = rob_head + 1;
            retire_bus_1.retire_addr = ROB[rob_head+1].addr;
            if(isALU_1) begin
                retire_pr_pkg_1.rd_arch                 = ROB[rob_head+1].rd_arch;
                retire_pr_pkg_1.rd_phy_old              = ROB[rob_head+1].rd_phy_old;
                retire_pr_pkg_1.rd_phy_new              = ROB[rob_head+1].rd_phy_new;
                retire_pr_pkg_1.retire_pr_valid         = 1'b1;

                retire_branch_pkg_1.update_btb_pc       = '0;
                retire_branch_pkg_1.update_btb_taken    = '0;             
                retire_branch_pkg_1.update_btb_target   = '0;
                retire_branch_pkg_1.retire_branch_valid = 1'b0;

                retire_store_pkg_1.retire_store_valid   = 1'b0;
                retire_store_pkg_1.retire_store_id      = '0;

                retire_bus_1.isFlush             = 'h0;
                retire_bus_1.targetPC            = 'h0;
                retire_bus_1.retire_done_valid   = 1'b0;
            end
            else if(isLoad_1) begin
                retire_pr_pkg_1.rd_arch                 = ROB[rob_head+1].rd_arch;
                retire_pr_pkg_1.rd_phy_old              = ROB[rob_head+1].rd_phy_old;
                retire_pr_pkg_1.rd_phy_new              = ROB[rob_head+1].rd_phy_new;

                retire_pr_pkg_1.retire_pr_valid         = 1'b1;
                retire_branch_pkg_1.update_btb_pc       = '0;
                retire_branch_pkg_1.update_btb_taken    = '0;
                retire_branch_pkg_1.update_btb_target   = '0;
                retire_branch_pkg_1.retire_branch_valid = 1'b0;

                retire_store_pkg_1.retire_store_valid   = 1'b0;
                retire_store_pkg_1.retire_store_id      = '0;
                
                retire_bus_1.isFlush             = 'h0;
                retire_bus_1.targetPC            = 'h0;
                retire_bus_1.retire_done_valid   = 1'b0;
            end
            else if(isStore_1) begin
                retire_pr_pkg_1.rd_arch                 = ROB[rob_head+1].rd_arch;
                retire_pr_pkg_1.rd_phy_old              = ROB[rob_head+1].rd_phy_old;
                retire_pr_pkg_1.rd_phy_new              = ROB[rob_head+1].rd_phy_new;
                retire_pr_pkg_1.retire_pr_valid         = 1'b0;

                retire_branch_pkg_1.update_btb_pc       = '0;
                retire_branch_pkg_1.update_btb_taken    = '0;
                retire_branch_pkg_1.update_btb_target   = '0;
                retire_branch_pkg_1.retire_branch_valid = 1'b0;

                retire_store_pkg_1.retire_store_valid   = 1'b1;
                retire_store_pkg_1.retire_store_id      = ROB[rob_head+1].store_id;

                retire_bus_1.isFlush             = 'h0;
                retire_bus_1.targetPC            = 'h0;
                retire_bus_1.retire_done_valid   = 1'b0;
            end
            else if(isBranch_1) begin
                retire_pr_pkg_1.rd_arch             = 'h0;
                retire_pr_pkg_1.rd_phy_old          = 'h0;
                retire_pr_pkg_1.rd_phy_new          = 'h0;
                retire_pr_pkg_1.retire_pr_valid     = 1'b0;

                retire_branch_pkg_1.update_btb_pc       = ROB[rob_head+1].update_pc;
                retire_branch_pkg_1.update_btb_taken    = ROB[rob_head+1].actual_taken;
                retire_branch_pkg_1.update_btb_target   = ROB[rob_head+1].actual_target;
                retire_branch_pkg_1.retire_branch_valid = 1'b1;

                retire_store_pkg_1.retire_store_valid   = 1'b0;
                retire_store_pkg_1.retire_store_id      = '0;

                retire_bus_1.isFlush             = ROB[rob_head+1].mispredict;
                retire_bus_1.targetPC            = ROB[rob_head+1].actual_target;
                retire_bus_1.retire_done_valid   = 1'b0;
            end
            else if(isJump_1)begin
                retire_pr_pkg_1.rd_arch                 = ROB[rob_head+1].rd_arch;
                retire_pr_pkg_1.rd_phy_old              = ROB[rob_head+1].rd_phy_old;
                retire_pr_pkg_1.rd_phy_new              = ROB[rob_head+1].rd_phy_new;
                retire_pr_pkg_1.retire_pr_valid         = (retire_pr_pkg_1.rd_arch != 'h0) ? 1'b1 : 1'b0;
                
                retire_branch_pkg_1.update_btb_pc       = ROB[rob_head+1].update_pc;
                retire_branch_pkg_1.update_btb_taken    = ROB[rob_head+1].actual_taken;
                retire_branch_pkg_1.update_btb_target   = ROB[rob_head+1].actual_target;
                retire_branch_pkg_1.retire_branch_valid = 1'b1;

                retire_store_pkg_1.retire_store_valid   = 1'b0;
                retire_store_pkg_1.retire_store_id      = '0;

                retire_bus_1.isFlush             = ROB[rob_head+1].mispredict;
                retire_bus_1.targetPC            = ROB[rob_head+1].actual_target;
                retire_bus_1.retire_done_valid   = 1'b0;
            end
            else if(isSystem_1)begin
                retire_pr_pkg_1.rd_arch             = 'h0;
                retire_pr_pkg_1.rd_phy_old          = 'h0;
                retire_pr_pkg_1.rd_phy_new          = 'h0;
                retire_pr_pkg_1.retire_pr_valid     = 1'b0;

                retire_branch_pkg_1.update_btb_pc       = 'h0;
                retire_branch_pkg_1.update_btb_taken    = 'b0;
                retire_branch_pkg_1.update_btb_target   = 'h0;
                retire_branch_pkg_1.retire_branch_valid = 1'b0;

                retire_store_pkg_1.retire_store_valid  = 1'b0;
                retire_store_pkg_1.retire_store_id     = '0;

                retire_bus_1.isFlush             = 'h0;
                retire_bus_1.targetPC            = 'h0;
                retire_bus_1.retire_done_valid   = 1'b1;
            end
            else begin
                retire_pr_pkg_1.rd_arch             = 'h0;
                retire_pr_pkg_1.rd_phy_old          = 'h0;
                retire_pr_pkg_1.rd_phy_new          = 'h0;
                retire_pr_pkg_1.retire_pr_valid     = 1'b0;

                retire_branch_pkg_1.update_btb_pc       = 'h0;
                retire_branch_pkg_1.update_btb_taken    = 1'b0;
                retire_branch_pkg_1.update_btb_target   = 'h0;
                retire_branch_pkg_1.retire_branch_valid = 1'b0;

                retire_store_pkg_1.retire_store_valid  = 1'b0;
                retire_store_pkg_1.retire_store_id     = '0;

                retire_bus_1.isFlush             = 'h0;
                retire_bus_1.targetPC            = 'h0;
                retire_bus_1.retire_done_valid   = 1'b0;
            end
        end
        else begin
            retire_pr_pkg_1.rd_arch             = 'h0;
            retire_pr_pkg_1.rd_phy_old          = 'h0;
            retire_pr_pkg_1.rd_phy_new          = 'h0;
            retire_pr_pkg_1.retire_pr_valid     = 1'b0;

            retire_branch_pkg_1.update_btb_pc       = 'h0;
            retire_branch_pkg_1.update_btb_taken    = 1'b0;
            retire_branch_pkg_1.update_btb_target   = 'h0;
            retire_branch_pkg_1.retire_branch_valid = 1'b0;

            retire_store_pkg_1.retire_store_valid  = 1'b0;
            retire_store_pkg_1.retire_store_id     = '0;

            retire_bus_1.isFlush             = 'h0;
            retire_bus_1.targetPC            = 'h0;
            retire_bus_1.retire_done_valid   = 1'b0;

            // debugging info
            retire_bus_1.rob_debug   = 'h0;
            retire_bus_1.retire_addr = 'h0;
        end
    end

endmodule
