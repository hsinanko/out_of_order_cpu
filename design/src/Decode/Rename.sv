`timescale 1ns/1ps
import typedef_pkg::*;
import parameter_pkg::*;
module Rename #(parameter ADDR_WIDTH =  32, DATA_WIDTH = 32, REG_WIDTH = 32, ARCH_REGS = 32, PHY_REGS = 64, ROB_WIDTH = 4, PHY_WIDTH = 6)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  flush,
    input  logic [PHY_REGS-1:0]   PRF_valid,
    //====== Instruction Decode ===================
    input  logic [1:0]instruction_valid,
    // first instruction
    input  logic [ADDR_WIDTH-1:0] instruction_addr_0,   // instruction address from IF
    input  logic [DATA_WIDTH-1:0] instruction_0,        // instruction from IF
    // second instruction
    input  logic [ADDR_WIDTH-1:0] instruction_addr_1,   // instruction address from IF
    input  logic [DATA_WIDTH-1:0] instruction_1,
    // prediction branch
    input  logic predict_taken_0,
    input  logic [ADDR_WIDTH-1:0] predict_target_0,
    input  logic predict_taken_1,
    input  logic [ADDR_WIDTH-1:0] predict_target_1,
    //======== Front RAT =============================
    output logic [1:0] instr_valid,     // front RAT
    output logic [4:0] rs1_arch_0,      // architected register address
    output logic [4:0] rs2_arch_0,
    output logic [4:0] rd_arch_0,
    input  logic [PHY_WIDTH-1:0] rs1_phy_0,
    input  logic [PHY_WIDTH-1:0] rs2_phy_0,
    input  logic [PHY_WIDTH-1:0] rd_phy_0,
    output logic [4:0] rs1_arch_1,                // architected register address
    output logic [4:0] rs2_arch_1,
    output logic [4:0] rd_arch_1,
    input  logic [PHY_WIDTH-1:0] rs1_phy_1,
    input  logic [PHY_WIDTH-1:0] rs2_phy_1,
    input  logic [PHY_WIDTH-1:0] rd_phy_1,
    //======== Free List =================
    output logic [1:0] free_list_valid, // free list valid signals for both instructions
    input logic [PHY_WIDTH-1:0] rd_phy_new_0,
    input logic [PHY_WIDTH-1:0] rd_phy_new_1,
    //======== Reorder Buffer =================
    // rename/dispatch
    output logic [1:0]          dispatch_valid,
    output ROB_ENTRY_t           dispatch_rob_0,         // entry to be added
    input  logic [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    output ROB_ENTRY_t           dispatch_rob_1,         // entry to be added
    input  logic [ROB_WIDTH-1:0] rob_id_1,

    //======== Physical Register File =================
    output logic [1:0]busy_valid, // rename valid signals for both instructions
    output logic [PHY_REGS-1:0] rd_phy_busy_0,
    output logic [PHY_REGS-1:0] rd_phy_busy_1,
    //====== DecodeRename to ReservationStation====
    output RS_ENTRY_t issue_instruction_alu,
    output RS_ENTRY_t issue_instruction_ls,
    output RS_ENTRY_t issue_instruction_branch,
    output logic issue_alu_valid,
    output logic issue_ls_valid,
    output logic issue_branch_valid
);
    
    // Instruction Decode
    instruction_t instr_0, instr_1;

    InstructionDecode #(ADDR_WIDTH, DATA_WIDTH) Decode_0 (
        .instruction_addr(instruction_addr_0),
        .instruction(instruction_0),
        .decoded_instruction(instr_0)
    );

    InstructionDecode #(ADDR_WIDTH, DATA_WIDTH) Decode_1 (
        .instruction_addr(instruction_addr_1),
        .instruction(instruction_1),
        .decoded_instruction(instr_1)
    );

    // ========== Front RAT =================

    // first instruction
    assign rd_arch_0  = instr_0.rd_addr;
    assign rs1_arch_0 = instr_0.rs1_addr;
    assign rs2_arch_0 = instr_0.rs2_addr;
    assign rd_arch_0  = instr_0.rd_addr;
    // second instruction
    assign rd_arch_1  = instr_1.rd_addr;
    assign rs1_arch_1 = instr_1.rs1_addr;
    assign rs2_arch_1 = instr_1.rs2_addr;
    assign rd_arch_1  = instr_1.rd_addr;


    always_comb begin
        case(instr_0.opcode)
            STORE: instr_valid[0] = 1'b0;
            BRANCH: instr_valid[0] = 1'b0;
            default: instr_valid[0] = instruction_valid[0];
        endcase

        case(instr_1.opcode)
            STORE: instr_valid[1] = 1'b0;
            BRANCH: instr_valid[1] = 1'b0;
            default: instr_valid[1] = instruction_valid[1];
        endcase
    end


    logic isRename_0, isRename_1;
    assign isRename_0 = (instr_0.opcode != STORE && instr_0.opcode != BRANCH || instr_0.opcode != SYSTEM) && (rd_arch_0 != 5'd0);
    assign isRename_1 = (instr_1.opcode != STORE && instr_1.opcode != BRANCH || instr_1.opcode != SYSTEM) && (rd_arch_1 != 5'd0);
    //=========== Freelist =================
    assign free_list_valid[0] = (!flush && instruction_valid[0] && isRename_0);
    assign free_list_valid[1] = (!flush && instruction_valid[1] && isRename_1);

    //=========== Physical Register File =================
    // Physical Register File outputs
    assign busy_valid[0] = (!flush && instruction_valid[0] && isRename_0);
    assign busy_valid[1] = (!flush && instruction_valid[1] && isRename_1);
    assign rd_phy_busy_0 = (busy_valid[0]) ? rd_phy_new_0 : 'h0;
    assign rd_phy_busy_1 = (busy_valid[1]) ? rd_phy_new_1 : 'h0;

    //=========== Reorder Buffer =================
    // Reorder Buffer inputs/outputs

    assign dispatch_valid = (!flush) ? instruction_valid : 2'b00;
    //========== First instruction =================
    assign dispatch_rob_0.rd_arch    = rd_arch_0;
    assign dispatch_rob_0.rd_phy_old = rd_phy_0;
    assign dispatch_rob_0.rd_phy_new = rd_phy_new_0;
    assign dispatch_rob_0.opcode     = instr_0.opcode;
    assign dispatch_rob_0.actual_target = 'h0; // to be updated at commit stage
    assign dispatch_rob_0.actual_taken = 1'b0;
    assign dispatch_rob_0.update_pc    = 'h0;
    assign dispatch_rob_0.mispredict = 1'b0;
    //========== Second instruction =================
    assign dispatch_rob_1.rd_arch    = rd_arch_1;
    assign dispatch_rob_1.rd_phy_old = rd_phy_1;
    assign dispatch_rob_1.rd_phy_new = rd_phy_new_1;
    assign dispatch_rob_1.opcode     = instr_1.opcode;
    assign dispatch_rob_1.actual_target = 'h0; // to be updated at commit stage
    assign dispatch_rob_1.actual_taken = 1'b0;
    assign dispatch_rob_1.update_pc    = 'h0;
    assign dispatch_rob_1.mispredict = 1'b0;


    // ============= Decode / Dispatch Stage ==============
    logic [1:0]rename_valid;
    instruction_t rename_instruction_0;
    logic [4:0] rename_rob_id_0;
    instruction_t rename_instruction_1;
    logic [4:0] rename_rob_id_1;

    assign rename_rob_id_0 = rob_id_0;
    assign rename_rob_id_1 = rob_id_1;

    assign rename_valid[0] = (!flush) ? instruction_valid[0] : 1'b0;
    assign rename_valid[1] = (!flush) ? instruction_valid[1] : 1'b0;

    assign rename_instruction_0.instruction_addr = instr_0.instruction_addr;
    assign rename_instruction_0.opcode           = instr_0.opcode;
    assign rename_instruction_0.funct3           = instr_0.funct3;
    assign rename_instruction_0.funct7           = instr_0.funct7;
    assign rename_instruction_0.immediate        = instr_0.immediate;
    assign rename_instruction_0.rs1_addr         = rs1_phy_0;
    assign rename_instruction_0.rs2_addr         = rs2_phy_0;
    assign rename_instruction_0.rd_addr          = rd_phy_new_0;
    assign rename_instruction_0.predict_taken   = predict_taken_0;
    assign rename_instruction_0.predict_target  = predict_target_0;
            // instruction 1
    assign rename_instruction_1.instruction_addr = instr_1.instruction_addr;
    assign rename_instruction_1.opcode           = instr_1.opcode;
    assign rename_instruction_1.funct3           = instr_1.funct3;
    assign rename_instruction_1.funct7           = instr_1.funct7;
    assign rename_instruction_1.immediate        = instr_1.immediate;
    assign rename_instruction_1.rs1_addr         = rs1_phy_1;
    assign rename_instruction_1.rs2_addr         = rs2_phy_1;
    assign rename_instruction_1.rd_addr          = rd_phy_new_1;
    assign rename_instruction_1.predict_taken   = predict_taken_1;
    assign rename_instruction_1.predict_target  = predict_target_1;



    Dispatch #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, PHY_WIDTH) Dispatch_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .PRF_valid(PRF_valid),
        .rename_valid(rename_valid),
        .rename_instruction_0(rename_instruction_0),
        .rob_id_0(rename_rob_id_0),
        .rename_instruction_1(rename_instruction_1),
        .rob_id_1(rename_rob_id_1),
        // dispatch --> issue
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .issue_alu_valid(issue_alu_valid),
        .issue_ls_valid(issue_ls_valid),
        .issue_branch_valid(issue_branch_valid)
    );

endmodule
