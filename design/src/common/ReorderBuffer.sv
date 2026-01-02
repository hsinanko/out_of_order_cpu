`timescale 1ns/1ps

import parameter_pkg::*;
import instruction_pkg::*;
import typedef_pkg::*;

module ReorderBuffer #(parameter NUM_ROB_ENTRY = 16, ROB_WIDTH = 4, PHY_WIDTH = 6)(
    input  logic       clk,
    input  logic       rst,
    // rename/dispatch
    input  [1:0] dispatch_valid,
    input  ROB_ENTRY_t           dispatch_rob_0,         // entry to be added
    output logic [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    input  ROB_ENTRY_t dispatch_rob_1,         // entry to be added
    output logic [ROB_WIDTH-1:0] rob_id_1,

    // commit 
    input  logic                 commit_alu_valid,
    input  logic [ROB_WIDTH-1:0] commit_alu_rob_id,
    input  logic                 commit_ls_valid,
    input  logic [ROB_WIDTH-1:0] commit_ls_rob_id,
    input  logic                 commit_branch_valid,
    input  logic [ROB_WIDTH-1:0] commit_branch_rob_id,
    // outputs to backend/architectural state 
    output logic [4:0]           rd_arch_commit,
    output logic [PHY_WIDTH-1:0]  rd_phy_old_commit,
    output logic [PHY_WIDTH-1:0]  rd_phy_new_commit,
    output logic                 retire_valid,
    output logic                 store_valid // retire store valid
);

    ROB_ENTRY_t ROB [NUM_ROB_ENTRY-1:0]; // FIFO
    logic [NUM_ROB_ENTRY-1:0]ROB_FINISH; // check if this instruction is finished

    logic [ROB_WIDTH-1:0] count;
    logic [ROB_WIDTH-1:0] head;
    logic [ROB_WIDTH-1:0] tail;

    assign rob_id_0 = (dispatch_valid[0]) ? tail : 4'd0;
    assign rob_id_1 = (dispatch_valid[1]) ? ((dispatch_valid[0]) ? tail + 4'd1 : tail) : 4'd0;

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            integer i;
            for(i = 0; i < NUM_ROB_ENTRY; i = i + 1)begin
                ROB[i].rd_arch       <= 'h0;
                ROB[i].rd_phy_old    <= 'h0;
                ROB[i].rd_phy_new    <= 'h0;
                ROB[i].opcode        <= 'h0;
                ROB[i].pred_target   <= 'h0;
                ROB[i].pred_taken    <= 1'b0;
                ROB[i].actual_target <= 'h0;
                ROB[i].actual_taken  <= 1'b0;
            end
            count <= 0;
            tail  <= 0;
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
        else begin
            tail  <= tail;
            count <= count;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            ROB_FINISH = 'b0;
        end
        else begin
            if(commit_alu_valid) begin
                ROB_FINISH[commit_alu_rob_id] <= 1'b1;
            end
            if(commit_ls_valid) begin
                ROB_FINISH[commit_ls_rob_id] <= 1'b1;
            end
            if(commit_branch_valid) begin
                ROB_FINISH[commit_branch_rob_id] <= 1'b1;
            end
            
        end
    end

    // commit / retire logic

    logic isALU, isLoad, isStore, isBranch;
    assign isALU = (ROB[head].opcode == OP_IMM || ROB[head].opcode == OP || ROB[head].opcode == LUI || ROB[head].opcode == AUIPC || ROB[head].opcode == SYSTEM);
    assign isLoad = (ROB[head].opcode == LOAD);
    assign isStore = (ROB[head].opcode == STORE);
    assign isBranch = (ROB[head].opcode == BRANCH || ROB[head].opcode == JAL || ROB[head].opcode == JALR);

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            head <= 0;
            rd_arch_commit    <= 'h0;
            rd_phy_old_commit <= 'h0;
            rd_phy_new_commit <= 'h0;
            retire_valid      <= 1'b0;
            store_valid       <= 1'b0;
        end
        else begin
            if(ROB_FINISH[head]) begin
                ROB_FINISH[head] <= 1'b0;
                if(isALU) begin
                    head              <= head + 1;
                    rd_arch_commit    <= ROB[head].rd_arch;
                    rd_phy_old_commit <= ROB[head].rd_phy_old;
                    rd_phy_new_commit <= ROB[head].rd_phy_new;
                    retire_valid      <= 1'b1;
                end
                else if(isLoad) begin
                    head              <= head + 1;
                    rd_arch_commit    <= ROB[head].rd_arch;
                    rd_phy_old_commit <= ROB[head].rd_phy_old;
                    rd_phy_new_commit <= ROB[head].rd_phy_new;
                    retire_valid      <= 1'b1;
                end
                else if(isStore) begin
                    head              <= head + 1;
                    rd_arch_commit    <= ROB[head].rd_arch;
                    rd_phy_old_commit <= ROB[head].rd_phy_old;
                    rd_phy_new_commit <= ROB[head].rd_phy_new;
                    retire_valid      <= 1'b0;
                    store_valid       <= 1'b1;
                end
                else if(isBranch) begin
                    head              <= head + 1;
                    rd_arch_commit    <= ROB[head].rd_arch;
                    rd_phy_old_commit <= ROB[head].rd_phy_old;
                    rd_phy_new_commit <= ROB[head].rd_phy_new;
                    retire_valid      <= 1'b1;
                    store_valid       <= 1'b0;
                end
                else begin
                    head              <= head + 1;
                    rd_arch_commit    <= 'h0;
                    rd_phy_old_commit <= 'h0;
                    rd_phy_new_commit <= 'h0;
                    retire_valid      <= 1'b0;
                    store_valid       <= 1'b0;
                end
            end
            else begin
                head              <= head;
                rd_arch_commit    <= 'h0;
                rd_phy_old_commit <= 'h0;
                rd_phy_new_commit <= 'h0;
                retire_valid      <= 1'b0;
                store_valid       <= 1'b0;
            end
        end
    end
    

    // For debugging: dump ROB contents at each clock cycle
    integer mcd;
    logic [ROB_WIDTH-1:0] j;

    always_ff @(negedge clk) begin
        mcd = $fopen("./build/ROB.txt","w");
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
