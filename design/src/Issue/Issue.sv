`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;

module Issue #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5)(
    input  logic clk,
    input  logic rst,
    input  logic flush,
    // from decode/dispatch
    input  RS_ENTRY_t issue_instruction_alu,
    input  RS_ENTRY_t issue_instruction_ls,
    input  RS_ENTRY_t issue_instruction_branch,
    input  logic issue_alu_valid,
    input  logic issue_ls_valid,
    input  logic issue_branch_valid,
    // output logic issue_alu_en,
    // output logic issue_ls_en,
    // output logic issue_branch_en,
    // output to physical registerfile
    output logic alu_valid,
    output logic ls_valid,
    output logic branch_valid,
    output logic [PHY_WIDTH-1:0]rs1_phy_alu,               
    output logic [PHY_WIDTH-1:0]rs2_phy_alu, 
    input  logic [DATA_WIDTH-1:0]rs1_data_alu,
    input  logic [DATA_WIDTH-1:0]rs2_data_alu,
    output logic [PHY_WIDTH-1:0]rs1_phy_ls,               
    output logic [PHY_WIDTH-1:0]rs2_phy_ls,
    input  logic [DATA_WIDTH-1:0]rs1_data_ls,
    input  logic [DATA_WIDTH-1:0]rs2_data_ls,
    output logic [PHY_WIDTH-1:0]rs1_phy_branch,               
    output logic [PHY_WIDTH-1:0]rs2_phy_branch, 
    input  logic [DATA_WIDTH-1:0]rs1_data_branch,
    input  logic [DATA_WIDTH-1:0]rs2_data_branch,
    // output to execution
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
    output logic [ADDR_WIDTH-1:0] jumpPC,
    output logic [ADDR_WIDTH-1:0] update_pc,
    output logic [PHY_WIDTH-1:0]rd_phy_branch,
    output logic isJump
);

    // assign issue_alu_en = 1;    // can be extended FIFO to avoid stuck
    // assign issue_ls_en = 1;     // can be extended FIFO to avoid stuck
    // assign issue_branch_en = 1; // can be extended FIFO to avoid stuck

    RS_ENTRY_t issue_instruction_alu_fifo;
    RS_ENTRY_t issue_instruction_ls_fifo;
    RS_ENTRY_t issue_instruction_branch_fifo;
    logic issue_alu_valid_fifo;
    logic issue_ls_valid_fifo;
    logic issue_branch_valid_fifo;

    always_comb begin
        issue_instruction_alu_fifo    = issue_instruction_alu;
        issue_instruction_ls_fifo     = issue_instruction_ls;
        issue_instruction_branch_fifo = issue_instruction_branch;
        issue_alu_valid_fifo          = (!flush && issue_alu_valid);
        issue_ls_valid_fifo           = (!flush && issue_ls_valid);
        issue_branch_valid_fifo       = (!flush && issue_branch_valid);
    end
    

    Execution #(ADDR_WIDTH, DATA_WIDTH, ROB_WIDTH, PHY_WIDTH) execution_unit(
        // from issue stage
        .issue_instruction_alu(issue_instruction_alu_fifo),
        .issue_instruction_ls(issue_instruction_ls_fifo),
        .issue_instruction_branch(issue_instruction_branch_fifo),
        .issue_alu_valid(issue_alu_valid_fifo),
        .issue_ls_valid(issue_ls_valid_fifo),
        .issue_branch_valid(issue_branch_valid_fifo),
        // read data from physical register
        .rs1_phy_alu(rs1_phy_alu),               
        .rs2_phy_alu(rs2_phy_alu), 
        .rs1_data_alu(rs1_data_alu),
        .rs2_data_alu(rs2_data_alu),
        .alu_valid(alu_valid),
        .rs1_phy_ls(rs1_phy_ls),               
        .rs2_phy_ls(rs2_phy_ls),
        .rs1_data_ls(rs1_data_ls),
        .rs2_data_ls(rs2_data_ls),
        .ls_valid(ls_valid),
        .rs1_phy_branch(rs1_phy_branch),               
        .rs2_phy_branch(rs2_phy_branch), 
        .rs1_data_branch(rs1_data_branch),
        .rs2_data_branch(rs2_data_branch),
        .branch_valid(branch_valid),
        // output to commit stage
        .alu_rob_id(alu_rob_id),
        .alu_output(alu_output),
        .rd_phy_alu(rd_phy_alu),
        // Load/Store outputs
        .ls_rob_id(ls_rob_id),
        .mem_read_en(mem_read_en),
        .mem_funct3(mem_funct3),
        .raddr(raddr),
        .rd_phy_ls(rd_phy_ls),
        .wdata(wdata),
        .waddr(waddr),
        .wdata_valid(wdata_valid),
        // Branch outputs
        .branch_rob_id(branch_rob_id),
        .actual_taken(actual_taken),
        .mispredict(mispredict),
        .actual_target(jumpPC),
        .update_pc(update_pc),
        .rd_phy_branch(rd_phy_branch),
        .isJump(isJump)
    );

endmodule
