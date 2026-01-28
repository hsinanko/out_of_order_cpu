`timescale 1ns/1ps

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
    // ================ physical registerfile interface ==============
    physical_if.source alu_prf_bus,
    physical_if.source lsu_prf_bus,
    physical_if.source branch_prf_bus,
    // ============= execution ==================
    execution_if.source exe_bus
);

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
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // from issue stage
        .issue_instruction_alu(issue_instruction_alu_fifo),
        .issue_instruction_ls(issue_instruction_ls_fifo),
        .issue_instruction_branch(issue_instruction_branch_fifo),
        .issue_alu_valid(issue_alu_valid_fifo),
        .issue_ls_valid(issue_ls_valid_fifo),
        .issue_branch_valid(issue_branch_valid_fifo),
        // read data from physical register
        .alu_prf_bus(alu_prf_bus),
        .lsu_prf_bus(lsu_prf_bus),
        .branch_prf_bus(branch_prf_bus),
        // output to commit stage
        .exe_bus(exe_bus)
    );

endmodule
