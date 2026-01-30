`timescale 1ns/1ps

import typedef_pkg::*;

module Execution #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, ROB_WIDTH = 5, PHY_WIDTH = 6)(
    // from issue stage
    input  logic      clk,
    input  logic      rst,
    input  logic      flush,
    input  RS_ENTRY_t issue_instruction_alu,
    input  RS_ENTRY_t issue_instruction_ls,
    input  RS_ENTRY_t issue_instruction_branch,
    // read data from physical register
    physical_if.source alu_prf_bus,
    physical_if.source lsu_prf_bus,
    physical_if.source branch_prf_bus,
    // output to commit stage
    output EXE_alu_t   exe_alu,
    output EXE_lsu_t   exe_lsu,
    output EXE_branch_t exe_branch
);
    // ========== ALU unit ====================
    logic [3:0]alu_control;
    logic [DATA_WIDTH-1:0]alu_result;
    logic zero_flag;

    assign alu_prf_bus.rs1_phy = issue_instruction_alu.rs1_phy;
    assign alu_prf_bus.rs2_phy = issue_instruction_alu.rs2_phy;
    assign alu_prf_bus.valid   = (flush) ? 0 : issue_instruction_alu.valid;

    
    ALUControl alu_ctrl(
        .opcode(issue_instruction_alu.opcode),
        .funct7(issue_instruction_alu.funct7),
        .funct3(issue_instruction_alu.funct3),
        .alu_control(alu_control)
    );
    logic [DATA_WIDTH-1:0]rdata_1;
    logic [DATA_WIDTH-1:0]rdata_2;

    assign rdata_1 = alu_prf_bus.rs1_data;
    assign rdata_2 = (issue_instruction_alu.opcode == OP_IMM || issue_instruction_alu.opcode == LUI || issue_instruction_alu.opcode == AUIPC) ? 
                        issue_instruction_alu.immediate : alu_prf_bus.rs2_data;
    ALU #(DATA_WIDTH) alu(
        .rdata_1(rdata_1),
        .rdata_2(rdata_2),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .zero_flag(zero_flag)
    );


    always_comb begin
        exe_alu.alu_valid  = issue_instruction_alu.valid;
        exe_alu.alu_result = alu_result;
        exe_alu.alu_rob_id = issue_instruction_alu.rob_id;
        exe_alu.rd_phy_alu = issue_instruction_alu.rd_phy;
    end
    assign exe_alu.busy_alu = 0;
    // ============ Load/Store Unit =====================

    logic [ADDR_WIDTH-1:0]addr;
    logic [DATA_WIDTH-1:0]data;
    logic [2:0]funct3_ls;
    logic isLoad;
    logic isStore;
    logic [ROB_WIDTH-1:0]ls_rob_id;
    logic [PHY_WIDTH-1:0]rd_phy_ls;

    
    assign lsu_prf_bus.rs1_phy = issue_instruction_ls.rs1_phy;
    assign lsu_prf_bus.rs2_phy = issue_instruction_ls.rs2_phy;
    assign lsu_prf_bus.valid   = (flush) ? 0 : issue_instruction_ls.valid;

    assign rd_phy_ls  = issue_instruction_ls.rd_phy;
    assign funct3_ls = issue_instruction_ls.funct3;


    always_comb begin
        addr  = lsu_prf_bus.rs1_data + issue_instruction_ls.immediate;
        data = lsu_prf_bus.rs2_data;
        isLoad  = (issue_instruction_ls.valid) ? (issue_instruction_ls.opcode == LOAD) : 0;
        isStore = (issue_instruction_ls.valid) ? (issue_instruction_ls.opcode == STORE) : 0;
        ls_rob_id = (issue_instruction_ls.valid) ? issue_instruction_ls.rob_id : 0;
    end

    AddressGenerator #(ADDR_WIDTH, DATA_WIDTH, ROB_WIDTH, PHY_WIDTH) load_store_unit(
        .isLoad(isLoad),
        .isStore(isStore),
        .addr(addr),
        .data(data),
        .funct3(funct3_ls),  
        .rob_id(ls_rob_id),
        .rd_phy(rd_phy_ls),
        .store_waddr(exe_lsu.store_waddr), // store --> to memory
        .store_wdata(exe_lsu.store_wdata), // store
        .store_rob_id(exe_lsu.store_rob_id),
        .store_valid(exe_lsu.store_valid),
        .load_raddr(exe_lsu.load_raddr),
        .load_funct3(exe_lsu.load_funct3),
        .load_rob_id(exe_lsu.load_rob_id),
        .load_rd_phy(exe_lsu.load_rd_phy),
        .load_valid(exe_lsu.load_valid)
    );

    assign exe_lsu.busy_lsu = 0;
    // ============== Branch Unit ==================
    
    assign branch_prf_bus.rs1_phy = issue_instruction_branch.rs1_phy;
    assign branch_prf_bus.rs2_phy = issue_instruction_branch.rs2_phy;
    assign branch_prf_bus.valid   = (flush) ? 0 : issue_instruction_branch.valid;

    BranchUnit #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH) branchUnit(
        .issue_instruction_branch(issue_instruction_branch),
        .rs1_data_branch(branch_prf_bus.rs1_data),
        .rs2_data_branch(branch_prf_bus.rs2_data),
        .branch_valid(exe_branch.branch_valid),
        .jump_valid(exe_branch.jump_valid),
        .branch_rob_id(exe_branch.branch_rob_id),
        .rd_phy_branch(exe_branch.rd_phy_branch),
        .nextPC(exe_branch.nextPC),
        .mispredict(exe_branch.mispredict),
        .actual_taken(exe_branch.actual_taken),
        .actual_target(exe_branch.actual_target),
        .update_pc(exe_branch.update_pc)
    );

    assign exe_branch.busy_branch   = 0;

endmodule
