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


    always_comb begin
        issue_instruction_alu_fifo    = issue_instruction_alu;
        issue_instruction_ls_fifo     = issue_instruction_ls;
        issue_instruction_branch_fifo = issue_instruction_branch;

        issue_instruction_alu_fifo.valid    = !flush && issue_instruction_alu.valid;
        issue_instruction_ls_fifo.valid     = !flush && issue_instruction_ls.valid;
        issue_instruction_branch_fifo.valid = !flush && issue_instruction_branch.valid;
    end
    

    Execution #(ADDR_WIDTH, DATA_WIDTH, ROB_WIDTH, PHY_WIDTH) execution_unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // from issue stage
        .issue_instruction_alu(issue_instruction_alu_fifo),
        .issue_instruction_ls(issue_instruction_ls_fifo),
        .issue_instruction_branch(issue_instruction_branch_fifo),
        // read data from physical register
        .alu_prf_bus(alu_prf_bus),
        .lsu_prf_bus(lsu_prf_bus),
        .branch_prf_bus(branch_prf_bus),
        // output to commit stage
        .exe_bus(exe_bus)
    );

endmodule
