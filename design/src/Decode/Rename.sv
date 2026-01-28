`timescale 1ns/1ps
import typedef_pkg::*;

module Rename #(parameter ADDR_WIDTH =  32, DATA_WIDTH = 32, ARCH_REGS = 32, PHY_REGS = 64, NUM_RS_ENTRIES = 16, ROB_WIDTH = 4, PHY_WIDTH = 6)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  flush,
    input  logic                  stall_dispatch,
    //====== Physical Register File =================
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
    rename_if.rat_source rat_0_bus,
    rename_if.rat_source rat_1_bus,
    //======== Free List =================
    rename_if.freelist_source freelist_0_bus,
    rename_if.freelist_source freelist_1_bus,
    //======== Reorder Buffer =================
    // rename/dispatch
    output ROB_ENTRY_t           rob_entry_0,         // entry to be added
    input  logic [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    output ROB_ENTRY_t           rob_entry_1,         // entry to be added
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
    output logic issue_branch_valid,
    input logic busy_alu,
    input logic busy_lsu,
    input logic busy_branch
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
    assign rat_0_bus.rd_arch  = instr_0.rd_addr;
    assign rat_0_bus.rs1_arch = instr_0.rs1_addr;
    assign rat_0_bus.rs2_arch = instr_0.rs2_addr;
    assign rat_0_bus.rd_arch  = instr_0.rd_addr;
    // second instruction
    assign rat_1_bus.rd_arch  = instr_1.rd_addr;
    assign rat_1_bus.rs1_arch = instr_1.rs1_addr;
    assign rat_1_bus.rs2_arch = instr_1.rs2_addr;
    assign rat_1_bus.rd_arch  = instr_1.rd_addr;


    logic isRename_0, isRename_1;
    assign isRename_0 = (instr_0.opcode != STORE && instr_0.opcode != BRANCH && instr_0.opcode != SYSTEM) && (rat_0_bus.rd_arch != 5'd0);
    assign isRename_1 = (instr_1.opcode != STORE && instr_1.opcode != BRANCH && instr_1.opcode != SYSTEM) && (rat_1_bus.rd_arch != 5'd0);

    always_comb begin
        if(flush || stall_dispatch) begin
            rat_0_bus.valid = 1'b0;
            rat_1_bus.valid = 1'b0;
        end
        else begin
            rat_0_bus.valid = (instruction_valid[0] && isRename_0);
            rat_1_bus.valid = (instruction_valid[1] && isRename_1);
        end
    end

    //=========== Freelist =================

    always_comb begin
        if(flush || stall_dispatch)begin
            freelist_0_bus.valid = 1'b0;
            freelist_1_bus.valid = 1'b0;
        end
        else begin
            freelist_0_bus.valid = (instruction_valid[0] && isRename_0);
            freelist_1_bus.valid = (instruction_valid[1] && isRename_1);
        end
    end

    //=========== Physical Register File =================
    // Physical Register File outputs
    always_comb begin
        if(flush) begin
            busy_valid = 2'b00;
        end
        else if(stall_dispatch) begin
            busy_valid = 2'b00;
        end
        else begin
            busy_valid[0] = (instruction_valid[0] && isRename_0);
            busy_valid[1] = (instruction_valid[1] && isRename_1);
        end
    end
    assign rd_phy_busy_0 = (busy_valid[0]) ? freelist_0_bus.rd_phy_new : 'h0;
    assign rd_phy_busy_1 = (busy_valid[1]) ? freelist_1_bus.rd_phy_new : 'h0;

    //=========== Reorder Buffer =================
    // Reorder Buffer inputs/outputs

    //========== First instruction =================
    assign rob_entry_0.rd_arch       = rat_0_bus.rd_arch;
    assign rob_entry_0.rd_phy_old    = rat_0_bus.rd_phy;
    assign rob_entry_0.rd_phy_new    = freelist_0_bus.rd_phy_new;
    assign rob_entry_0.opcode        = instr_0.opcode;
    assign rob_entry_0.actual_target = 'h0; // to be updated at commit stage
    assign rob_entry_0.actual_taken  = 1'b0;
    assign rob_entry_0.update_pc     = 'h0;
    assign rob_entry_0.mispredict    = 1'b0;
    assign rob_entry_0.valid         = (flush || stall_dispatch) ? 1'b0 : instruction_valid[0];
    // debugging info
    assign rob_entry_0.addr          = instr_0.addr;
    //========== Second instruction =================
    assign rob_entry_1.rd_arch       = rat_1_bus.rd_arch;
    assign rob_entry_1.rd_phy_old    = rat_1_bus.rd_phy;
    assign rob_entry_1.rd_phy_new    = freelist_1_bus.rd_phy_new;
    assign rob_entry_1.opcode        = instr_1.opcode;
    assign rob_entry_1.actual_target = 'h0; // to be updated at commit stage
    assign rob_entry_1.actual_taken  = 1'b0;
    assign rob_entry_1.update_pc     = 'h0;
    assign rob_entry_1.mispredict    = 1'b0;
    assign rob_entry_1.valid         = (flush || stall_dispatch) ? 1'b0 : instruction_valid[1];
    // debugging info
    assign rob_entry_1.addr = instr_1.addr;
    // ============= Decode / Dispatch Stage ==============
    instruction_t rename_instruction_0;
    instruction_t rename_instruction_1;

    assign rename_instruction_0.addr           = instr_0.addr;
    assign rename_instruction_0.opcode         = instr_0.opcode;
    assign rename_instruction_0.funct3         = instr_0.funct3;
    assign rename_instruction_0.funct7         = instr_0.funct7;
    assign rename_instruction_0.immediate      = instr_0.immediate;
    assign rename_instruction_0.rs1_addr       = rat_0_bus.rs1_phy;
    assign rename_instruction_0.rs2_addr       = rat_0_bus.rs2_phy;
    assign rename_instruction_0.rd_addr        = freelist_0_bus.rd_phy_new;
    assign rename_instruction_0.predict_taken  = predict_taken_0;
    assign rename_instruction_0.predict_target = predict_target_0;
    assign rename_instruction_0.rob_id         = rob_id_0;
    assign rename_instruction_0.valid          = (flush || stall_dispatch) ? 1'b0 : instruction_valid[0];
            // instruction 1
    assign rename_instruction_1.addr           = instr_1.addr;
    assign rename_instruction_1.opcode         = instr_1.opcode;
    assign rename_instruction_1.funct3         = instr_1.funct3;
    assign rename_instruction_1.funct7         = instr_1.funct7;
    assign rename_instruction_1.immediate      = instr_1.immediate;
    assign rename_instruction_1.rs1_addr       = rat_1_bus.rs1_phy;
    assign rename_instruction_1.rs2_addr       = rat_1_bus.rs2_phy;
    assign rename_instruction_1.rd_addr        = freelist_1_bus.rd_phy_new;
    assign rename_instruction_1.predict_taken  = predict_taken_1;
    assign rename_instruction_1.predict_target = predict_target_1;
    assign rename_instruction_1.rob_id         = rob_id_1;
    assign rename_instruction_1.valid          = (flush || stall_dispatch) ? 1'b0 : instruction_valid[1];


    Dispatch #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, PHY_WIDTH) Dispatch_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .stall_dispatch(stall_dispatch),
        .PRF_valid(PRF_valid),
        .rename_instruction_0(rename_instruction_0),
        .rename_instruction_1(rename_instruction_1),
        // dispatch --> issue
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .issue_alu_valid(issue_alu_valid),
        .issue_ls_valid(issue_ls_valid),
        .issue_branch_valid(issue_branch_valid),
        .busy_alu(busy_alu),
        .busy_lsu(busy_lsu),
        .busy_branch(busy_branch)
    );

endmodule
