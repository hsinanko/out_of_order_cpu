`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;

module Execution #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, ROB_WIDTH = 5, PHY_WIDTH = 6)(
    // from issue stage
    input  RS_ENTRY_t issue_instruction_alu,
    input  RS_ENTRY_t issue_instruction_ls,
    input  RS_ENTRY_t issue_instruction_branch,
    input  logic issue_alu_valid,
    input  logic issue_ls_valid,
    input  logic issue_branch_valid,
    // read data from physical register
    output logic [PHY_WIDTH-1:0]rs1_phy_alu,               
    output logic [PHY_WIDTH-1:0]rs2_phy_alu, 
    input  logic [DATA_WIDTH-1:0]rs1_data_alu,
    input  logic [DATA_WIDTH-1:0]rs2_data_alu,
    output logic alu_valid,
    output logic [PHY_WIDTH-1:0]rs1_phy_ls,               
    output logic [PHY_WIDTH-1:0]rs2_phy_ls,
    input  logic [DATA_WIDTH-1:0]rs1_data_ls,
    input  logic [DATA_WIDTH-1:0]rs2_data_ls,
    output logic ls_valid,
    output logic [PHY_WIDTH-1:0]rs1_phy_branch,               
    output logic [PHY_WIDTH-1:0]rs2_phy_branch, 
    input  logic [DATA_WIDTH-1:0]rs1_data_branch,
    input  logic [DATA_WIDTH-1:0]rs2_data_branch,
    output logic branch_valid,
    // output to commit stage
    // ALU outputs
    output logic [ROB_WIDTH-1:0]alu_rob_id,
    output logic [DATA_WIDTH-1:0] alu_output,
    output logic [PHY_WIDTH-1:0]rd_phy_alu,
    // Load/Store outputs
    output logic [ROB_WIDTH-1:0]ls_rob_id,
    output logic mem_read_en,
    output logic [4:0]mem_funct3,
    output logic [ADDR_WIDTH-1:0]raddr,
    output logic [PHY_WIDTH-1:0]rd_phy_ls,
    output logic [DATA_WIDTH-1:0] wdata,
    output logic [ADDR_WIDTH-1:0] waddr,
    output logic wdata_valid,
    // Branch outputs
    output logic [ROB_WIDTH-1:0]branch_rob_id,
    output logic actual_taken,
    output logic mispredict,
    output logic [ADDR_WIDTH-1:0] actual_target,
    output logic [ADDR_WIDTH-1:0] update_pc,
    output logic [PHY_WIDTH-1:0]rd_phy_branch,
    output logic isJump
);
    // ========== ALU unit ====================
    logic [3:0]alu_control;
    logic [DATA_WIDTH-1:0]alu_result;
    logic zero_flag;

    assign rs1_phy_alu = issue_instruction_alu.rs1_phy;
    assign rs2_phy_alu = issue_instruction_alu.rs2_phy;
    assign alu_valid = issue_alu_valid;
    ALUControl alu_ctrl(
        .opcode(issue_instruction_alu.opcode),
        .funct7(issue_instruction_alu.funct7),
        .funct3(issue_instruction_alu.funct3),
        .alu_control(alu_control)
    );
    logic [DATA_WIDTH-1:0]rdata_2;
    assign rdata_2 = (issue_instruction_alu.opcode == OP_IMM || issue_instruction_alu.opcode == LUI || issue_instruction_alu.opcode == AUIPC) ? 
                        issue_instruction_alu.immediate : rs2_data_alu;
    ALU #(DATA_WIDTH) alu(
        .rdata_1(rs1_data_alu),
        .rdata_2(rdata_2),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .zero_flag(zero_flag)
    );


    always_comb begin
        alu_output = alu_result;
        alu_rob_id = issue_instruction_alu.rob_id;
        rd_phy_alu = issue_instruction_alu.rd_phy;
    end

    // ============ Load/Store Unit =====================

    logic [ADDR_WIDTH-1:0]addr;
    logic [DATA_WIDTH-1:0]data;
    logic [2:0]funct3_ls;
    logic isLoad, isStore;

    // logic [DATA_WIDTH-1:0]wdata;
    // logic [ADDR_WIDTH-1:0]waddr;
    // logic wdata_valid;

    assign rd_phy_ls = issue_instruction_ls.rd_phy;
    assign rs1_phy_ls = issue_instruction_ls.rs1_phy;
    assign rs2_phy_ls = issue_instruction_ls.rs2_phy;
    assign funct3_ls = issue_instruction_ls.funct3;
    assign ls_valid = issue_ls_valid;
    always_comb begin
        addr  = rs1_data_ls + issue_instruction_ls.immediate;
        data = rs2_data_ls;
        isLoad  = (issue_ls_valid) ? (issue_instruction_ls.opcode == LOAD) : 0;
        isStore = (issue_ls_valid) ? (issue_instruction_ls.opcode == STORE) : 0;
        ls_rob_id = (issue_ls_valid) ? issue_instruction_ls.rob_id : 0;
    end

    MEMUnit #(ADDR_WIDTH, DATA_WIDTH) MEM(
        .addr(addr),
        .data(data),
        .funct3(funct3_ls),
        .isLoad(isLoad),          
        .isStore(isStore),
        .mem_funct3(mem_funct3),        // load --> to memory
        .mem_read_en(mem_read_en),      // load --> to memory
        .raddr(raddr),                  // load/store --> to memory
        .wdata(wdata),                  // store
        .waddr(waddr),                  // store
        .wdata_valid(wdata_valid)       // store
    );
    
    // ============== Branch Unit ==================
    
    assign rs1_phy_branch = issue_instruction_branch.rs1_phy;
    assign rs2_phy_branch = issue_instruction_branch.rs2_phy;

    assign branch_rob_id = issue_instruction_branch.rob_id;
    assign rd_phy_branch = issue_instruction_branch.rd_phy;
    assign branch_valid = issue_branch_valid;
    BranchUnit #(ADDR_WIDTH, DATA_WIDTH) branchUnit(
        .instruction_addr(issue_instruction_branch.addr),
        .rs1_data_branch(rs1_data_branch),
        .rs2_data_branch(rs2_data_branch),
        .opcode(issue_instruction_branch.opcode),
        .immediate(issue_instruction_branch.immediate),
        .funct3(issue_instruction_branch.funct3),
        .predict_taken(issue_instruction_branch.predict_taken),
        .predict_target(issue_instruction_branch.predict_target),
        .mispredict(mispredict),
        .actual_taken(actual_taken),
        .actual_target(actual_target),
        .update_pc(update_pc),
        .isJump(isJump)
    );

endmodule
