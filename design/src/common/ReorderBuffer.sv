`timescale 1ns/1ps

import parameter_pkg::*;
import instruction_pkg::*;
import typedef_pkg::*;

module ReorderBuffer #(parameter NUM_ROB_ENTRY = 16, ROB_WIDTH = 4, PHY_WIDTH = 6)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  flush,
    // rename/dispatch
    input  [1:0]                 dispatch_valid,
    input  ROB_ENTRY_t           dispatch_rob_0,         // entry to be added
    output logic [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    input  ROB_ENTRY_t dispatch_rob_1,         // entry to be added
    output logic [ROB_WIDTH-1:0] rob_id_1,

    // commit 
    input  logic                  commit_alu_valid,
    input  logic [ROB_WIDTH-1:0]  commit_alu_rob_id,
    input  logic                  commit_load_valid,
    input  logic [ROB_WIDTH-1:0]  commit_load_rob_id,
    input  logic                  commit_store_valid,
    input  logic [ROB_WIDTH-1:0]  commit_store_rob_id,
    input  logic                  commit_branch_valid,
    input  logic [ROB_WIDTH-1:0]  commit_branch_rob_id,
    input  logic                  commit_mispredict,
    input  logic [ADDR_WIDTH-1:0] commit_actual_target, // actual target address for branch instructions
    input  logic                  commit_actual_taken,
    input  logic [ADDR_WIDTH-1:0] commit_update_pc,
    // outputs to backend/architectural state 
    output logic                 isFlush,
    output logic [4:0]           targetPC,
    output logic [4:0]           rd_arch_commit,
    output logic [PHY_WIDTH-1:0] rd_phy_old_commit,
    output logic [PHY_WIDTH-1:0] rd_phy_new_commit,
    output logic [ADDR_WIDTH-1:0] update_btb_pc,
    output logic                  update_btb_taken,
    output logic [ADDR_WIDTH-1:0] update_btb_target,
    output logic                 retire_pr_valid,
    output logic                 retire_store_valid, // retire store valid
    output logic                 retire_branch_valid,
    output logic                 retire_done_valid,
    output logic [ROB_WIDTH-1:0] rob_debug,
    output logic                 rob_full,
    output logic                 rob_empty
);

    ROB_ENTRY_t ROB [NUM_ROB_ENTRY-1:0]; // FIFO
    logic [NUM_ROB_ENTRY-1:0]ROB_FINISH; // check if this instruction is finished

    logic [ROB_WIDTH:0] count;
    logic [ROB_WIDTH-1:0] head;
    logic [ROB_WIDTH-1:0] tail;
    
    assign rob_id_0 = (dispatch_valid[0]) ? tail : {ROB_WIDTH{1'b0}};
    assign rob_id_1 = (dispatch_valid[1]) ? ((dispatch_valid[0]) ? tail + 4'd1 : tail) : {ROB_WIDTH{1'b0}};
    integer i;

    assign rob_full = (count >= NUM_ROB_ENTRY-2);
    assign rob_empty = (count == 0);
    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            for(i = 0; i < NUM_ROB_ENTRY; i = i + 1)begin
                ROB[i].rd_arch        = 'h0;
                ROB[i].rd_phy_old     = 'h0;
                ROB[i].rd_phy_new     = 'h0;
                ROB[i].opcode         = 'h0;
                ROB[i].actual_target  = 'h0;
                ROB[i].actual_taken   = 1'b0;
                ROB[i].update_pc      = 'h0;
                ROB[i].mispredict     = 1'b0;
            end
            count <= 0;
            tail  <= 0;
        end
        else if(flush)begin
            tail  <= 0;
            count <= 0;
        end
        else if(dispatch_valid == 2'b11)begin
            ROB[tail] <= dispatch_rob_0;
            ROB[tail+1] <= dispatch_rob_1;
            tail      <= tail + 2;
            count     <= count + 2;
        end
        else if(dispatch_valid == 2'b01)begin
            ROB[tail] <= dispatch_rob_0;
            tail      <= tail + 1;
            count     <= count + 1;
        end
        else if(dispatch_valid == 2'b10)begin
            ROB[tail] <= dispatch_rob_1;
            tail      <= tail + 1;
            count     <= count + 1;
        end
        else if(ROB_FINISH[head]) begin
            // when committing instructions
            tail  <= tail;
            count <= count - 1;
        end
        else begin
            tail  <= tail;
            count <= count;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            ROB_FINISH <= 'b0;
        end
        else if(flush) begin
            ROB_FINISH <= 'b0;
        end
        else begin
            if(commit_alu_valid) begin
                ROB_FINISH[commit_alu_rob_id] <= 1'b1;
            end
            if(commit_load_valid) begin
                ROB_FINISH[commit_load_rob_id] <= 1'b1;
            end
            if(commit_store_valid) begin
                ROB_FINISH[commit_store_rob_id] <= 1'b1;
            end
            if(commit_branch_valid) begin
                ROB_FINISH[commit_branch_rob_id]        <= 1'b1;
                ROB[commit_branch_rob_id].mispredict    <= commit_mispredict;
                ROB[commit_branch_rob_id].actual_target <= commit_actual_target; // to be used for updating PC on mispredict
                ROB[commit_branch_rob_id].actual_taken  <= commit_actual_taken;
                ROB[commit_branch_rob_id].update_pc     <= commit_update_pc;
            end
            
        end
    end

    // commit / retire logic

    logic isALU, isLoad, isStore, isBranch;
    assign isALU = (ROB[head].opcode == OP_IMM || ROB[head].opcode == OP || ROB[head].opcode == LUI || ROB[head].opcode == AUIPC);
    assign isLoad = (ROB[head].opcode == LOAD);
    assign isStore = (ROB[head].opcode == STORE);
    assign isBranch = (ROB[head].opcode == BRANCH);
    assign isJump = (ROB[head].opcode == JAL || ROB[head].opcode == JALR);
    assign isSystem = (ROB[head].opcode == SYSTEM);
    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            head <= 0;
        end
        else if(flush) begin
            head <= 0;
        end
        else if(ROB_FINISH[head]) begin
            ROB_FINISH[head] <= 1'b0;
            head <= head + 1;
        end
        else begin 
            head <= head;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            isFlush <= 1'b0;
        end
        else if(flush) begin
            isFlush <= 1'b0;
        end
        else begin
            if(ROB_FINISH[head] && (isBranch || isJump)) begin
                isFlush  <= ROB[head].mispredict;
                targetPC <= ROB[head].actual_target;
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
        else if(ROB_FINISH[head]) begin
            rob_debug = head;
            if(isALU) begin
                rd_arch_commit      = ROB[head].rd_arch;
                rd_phy_old_commit   = ROB[head].rd_phy_old;
                rd_phy_new_commit   = ROB[head].rd_phy_new;
                update_btb_pc       = '0;
                update_btb_taken    = '0;             
                update_btb_target   = '0;
                retire_pr_valid     = 1'b1;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b0;
                retire_done_valid         = 1'b0;
            end
            else if(isLoad) begin
                rd_arch_commit      = ROB[head].rd_arch;
                rd_phy_old_commit   = ROB[head].rd_phy_old;
                rd_phy_new_commit   = ROB[head].rd_phy_new;
                update_btb_pc       = '0;
                update_btb_taken    = '0;
                update_btb_target   = '0;
                retire_pr_valid     = 1'b1;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b0;
                retire_done_valid   = 1'b0;
            end
            else if(isStore) begin
                rd_arch_commit      = ROB[head].rd_arch;
                rd_phy_old_commit   = ROB[head].rd_phy_old;
                rd_phy_new_commit   = ROB[head].rd_phy_new;
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
                update_btb_pc       = ROB[head].update_pc;
                update_btb_taken    = ROB[head].actual_taken;
                update_btb_target   = ROB[head].actual_target;
                retire_pr_valid     = 1'b0;
                retire_store_valid  = 1'b0;
                retire_branch_valid = 1'b1;
                retire_done_valid   = 1'b0;
            end
            else if(isJump)begin
                rd_arch_commit      = ROB[head].rd_arch;
                rd_phy_old_commit   = ROB[head].rd_phy_old;
                rd_phy_new_commit   = ROB[head].rd_phy_new;
                update_btb_pc       = ROB[head].update_pc;
                update_btb_taken    = ROB[head].actual_taken;
                update_btb_target   = ROB[head].actual_target;
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
    

    // For debugging: dump ROB contents at each clock cycle
    integer mcd;
    logic [ROB_WIDTH-1:0] j;

    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/ROB.txt","w");
        $fdisplay(mcd,"----- ROB contents at time -----", $time);
        $fdisplay(mcd,"Index | rd_arch | rd_phy_old | rd_phy_new | Finished");
        $fdisplay(mcd,"-----------------------------------------");
        for (j = head; j != tail; j = j + 1) begin
            $fdisplay(mcd," %2d %8d %11d %11d %10d", j, ROB[j].rd_arch, ROB[j].rd_phy_old, ROB[j].rd_phy_new, ROB_FINISH[j]);
        end
        if(head != tail) begin
            $fdisplay(mcd," %2d %8d %11d %11d %10d", tail, ROB[tail].rd_arch, ROB[tail].rd_phy_old, ROB[tail].rd_phy_new, ROB_FINISH[tail]);
        end
        $fclose(mcd);
        //$display("ROB contents dumped to ROB file at time %0t", $time);
    end

endmodule
