`timescale 1ns/1ps

import typedef_pkg::*;

module Dispatch #(parameter NUM_RS_ENTRIES = 16, ROB_WIDTH = 4, PHY_REGS = 64, PHY_WIDTH = 6)(
    input clk,
    input rst,
    input logic flush,
    input logic stall_dispatch,
    input [PHY_REGS-1:0]PRF_valid,
    // ========== Instruction Decode ==============
    // first instruction
    input logic [1:0]rename_valid,
    input instruction_t rename_instruction_0,
    input [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    input instruction_t rename_instruction_1,
    input [ROB_WIDTH-1:0] rob_id_1,
    input logic predict_taken,
    input logic [ADDR_WIDTH-1:0] predict_target,
    //======== Dispatch to ReservationStation====
    output RS_ENTRY_t issue_instruction_alu,
    output RS_ENTRY_t issue_instruction_ls,
    output RS_ENTRY_t issue_instruction_branch,
    output logic issue_alu_valid,
    output logic issue_ls_valid,
    output logic issue_branch_valid,
    // issue --> dispatch
    input logic busy_alu,
    input logic busy_lsu,
    input logic busy_branch
);
    logic dispatch_alu_valid_0, dispatch_ls_valid_0, dispatch_branch_valid_0;
    logic dispatch_alu_valid_1, dispatch_ls_valid_1, dispatch_branch_valid_1;

    logic isALU_0, isLoad_0, isStore_0, isBranch_0;

    assign isALU_0 = (rename_instruction_0.opcode == OP_IMM || rename_instruction_0.opcode == OP || rename_instruction_0.opcode == LUI || rename_instruction_0.opcode == AUIPC || rename_instruction_0.opcode == SYSTEM);
    assign isLoad_0 = (rename_instruction_0.opcode == LOAD);
    assign isStore_0 = (rename_instruction_0.opcode == STORE);
    assign isBranch_0 = (rename_instruction_0.opcode == BRANCH || rename_instruction_0.opcode == JAL || rename_instruction_0.opcode == JALR);

    logic isALU_1, isLoad_1, isStore_1, isBranch_1;
    assign isALU_1 = (rename_instruction_1.opcode == OP_IMM || rename_instruction_1.opcode == OP || rename_instruction_1.opcode == LUI || rename_instruction_1.opcode == AUIPC || rename_instruction_1.opcode == SYSTEM);
    assign isLoad_1 = (rename_instruction_1.opcode == LOAD);
    assign isStore_1 = (rename_instruction_1.opcode == STORE);
    assign isBranch_1 = (rename_instruction_1.opcode == BRANCH || rename_instruction_1.opcode == JAL || rename_instruction_1.opcode == JALR);

    always_comb begin
        if(flush || stall_dispatch) begin
            dispatch_alu_valid_0    = 1'b0;
            dispatch_ls_valid_0     = 1'b0;
            dispatch_branch_valid_0 = 1'b0;
        end
        else begin
            dispatch_alu_valid_0    = (rename_valid[0] && (isALU_0)) ? 1 : 0;
            dispatch_ls_valid_0     = (rename_valid[0] && (isLoad_0 || isStore_0)) ? 1 : 0;
            dispatch_branch_valid_0 = (rename_valid[0] && (isBranch_0)) ? 1 : 0;
        end
    end

    always_comb begin
        if(flush || stall_dispatch) begin
            dispatch_alu_valid_1    = 1'b0;
            dispatch_ls_valid_1     = 1'b0;
            dispatch_branch_valid_1 = 1'b0;
        end
        else begin
            dispatch_alu_valid_1    = (rename_valid[1] && (isALU_1)) ? 1 : 0;
            dispatch_ls_valid_1     = (rename_valid[1] && (isLoad_1 || isStore_1)) ? 1 : 0;
            dispatch_branch_valid_1 = (rename_valid[1] && (isBranch_1)) ? 1 : 0;
        end
    end

    ReservationStation #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, 0) RS_ALU(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .stall_dispatch(stall_dispatch),
        .PRF_valid(PRF_valid),
        .dispatch_instruction_0(rename_instruction_0),
        .rob_id_0(rob_id_0),
        .dispatch_valid_0(dispatch_alu_valid_0),
        .dispatch_instruction_1(rename_instruction_1),
        .rob_id_1(rob_id_1),
        .dispatch_valid_1(dispatch_alu_valid_1),
        .issue_instruction(issue_instruction_alu),
        .issue_valid(issue_alu_valid),
        .busy(busy_alu)
    );

    ReservationStation #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, 1) RS_LSU(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .stall_dispatch(stall_dispatch),
        .PRF_valid(PRF_valid),
        .dispatch_instruction_0(rename_instruction_0),
        .rob_id_0(rob_id_0),
        .dispatch_valid_0(dispatch_ls_valid_0),
        .dispatch_instruction_1(rename_instruction_1),
        .rob_id_1(rob_id_1),
        .dispatch_valid_1(dispatch_ls_valid_1),
        .issue_instruction(issue_instruction_ls),
        .issue_valid(issue_ls_valid),
        .busy(busy_lsu)
    );

    ReservationStation #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, 2) RS_BRU(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .stall_dispatch(stall_dispatch),
        .PRF_valid(PRF_valid),
        .dispatch_instruction_0(rename_instruction_0),
        .rob_id_0(rob_id_0),
        .dispatch_valid_0(dispatch_branch_valid_0),
        .dispatch_instruction_1(rename_instruction_1),
        .rob_id_1(rob_id_1),
        .dispatch_valid_1(dispatch_branch_valid_1),
        .issue_instruction(issue_instruction_branch),
        .issue_valid(issue_branch_valid),
        .busy(busy_branch)
    );

    // for debug

    // always_ff @(negedge clk)begin
    //     if(!rst) begin
    //         if(issue_alu_valid) begin
    //             $display("Dispatch - Issued ALU Instruction: PC=%h, ROB_ID=%0d", issue_instruction_alu.pc, issue_instruction_alu.rob_id);
    //         end
    //         if(issue_ls_valid) begin
    //             $display("Dispatch - Issued LS Instruction: PC=%h, ROB_ID=%0d", issue_instruction_ls.pc, issue_instruction_ls.rob_id);
    //         end
    //         if(issue_branch_valid) begin
    //             $display("Dispatch - Issued BR Instruction: PC=%h, ROB_ID=%0d", issue_instruction_branch.pc, issue_instruction_branch.rob_id);
    //         end
    //     end
    // end


endmodule 

