`timescale 1ns/1ps

import typedef_pkg::*;

module Execution #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, ROB_WIDTH = 5, PHY_WIDTH = 6)(
    // from issue stage
    input  logic                clk,
    input  logic                rst,
    input  logic                flush,
    input  RS_ENTRY_t issue_instruction_alu,
    input  RS_ENTRY_t issue_instruction_ls,
    input  RS_ENTRY_t issue_instruction_branch,
    input  logic issue_alu_valid,
    input  logic issue_ls_valid,
    input  logic issue_branch_valid,
    // read data from physical register
    physical_if.source alu_prf_bus,
    physical_if.source lsu_prf_bus,
    physical_if.source branch_prf_bus,
    // output to commit stage
    execution_if.source exe_bus
);
    // ========== ALU unit ====================
    logic [3:0]alu_control;
    logic [DATA_WIDTH-1:0]alu_result;
    logic zero_flag;

    assign alu_prf_bus.rs1_phy = issue_instruction_alu.rs1_phy;
    assign alu_prf_bus.rs2_phy = issue_instruction_alu.rs2_phy;
    assign alu_prf_bus.valid   = issue_alu_valid;

    
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
        exe_bus.alu_valid  = issue_alu_valid;
        exe_bus.alu_result = alu_result;
        exe_bus.alu_rob_id = issue_instruction_alu.rob_id;
        exe_bus.rd_phy_alu = issue_instruction_alu.rd_phy;
    end
    assign exe_bus.busy_alu = 0;
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
    assign lsu_prf_bus.valid   = issue_ls_valid;

    assign rd_phy_ls  = issue_instruction_ls.rd_phy;
    assign funct3_ls = issue_instruction_ls.funct3;


    always_comb begin
        addr  = lsu_prf_bus.rs1_data + issue_instruction_ls.immediate;
        data = lsu_prf_bus.rs2_data;
        isLoad  = (issue_ls_valid) ? (issue_instruction_ls.opcode == LOAD) : 0;
        isStore = (issue_ls_valid) ? (issue_instruction_ls.opcode == STORE) : 0;
        ls_rob_id = (issue_ls_valid) ? issue_instruction_ls.rob_id : 0;
    end

    AddressGenerator #(ADDR_WIDTH, DATA_WIDTH, ROB_WIDTH, PHY_WIDTH) load_store_unit(
        .isLoad(isLoad),
        .isStore(isStore),
        .addr(addr),
        .data(data),
        .funct3(funct3_ls),  
        .rob_id(ls_rob_id),
        .rd_phy(rd_phy_ls),
        .store_waddr(exe_bus.store_waddr), // store --> to memory
        .store_wdata(exe_bus.store_wdata), // store
        .store_rob_id(exe_bus.store_rob_id),
        .store_valid(exe_bus.store_valid),
        .load_raddr(exe_bus.load_raddr),
        .load_funct3(exe_bus.load_funct3),
        .load_rob_id(exe_bus.load_rob_id),
        .load_rd_phy(exe_bus.load_rd_phy),
        .load_valid(exe_bus.load_valid)
    );

    assign exe_bus.busy_lsu = 0;
    // ============== Branch Unit ==================
    
    assign exe_bus.busy_branch   = 0;
    assign exe_bus.branch_rob_id = issue_instruction_branch.rob_id;
    assign exe_bus.branch_valid  = issue_branch_valid;
    assign exe_bus.rd_phy_branch  = issue_instruction_branch.rd_phy;

    assign branch_prf_bus.rs1_phy = issue_instruction_branch.rs1_phy;
    assign branch_prf_bus.rs2_phy = issue_instruction_branch.rs2_phy;
    assign branch_prf_bus.valid   = issue_branch_valid;

    BranchUnit #(ADDR_WIDTH, DATA_WIDTH) branchUnit(
        .instruction_addr(issue_instruction_branch.addr),
        .rs1_data_branch(branch_prf_bus.rs1_data),
        .rs2_data_branch(branch_prf_bus.rs2_data),
        .opcode(issue_instruction_branch.opcode),
        .immediate(issue_instruction_branch.immediate),
        .funct3(issue_instruction_branch.funct3),
        .predict_taken(issue_instruction_branch.predict_taken),
        .predict_target(issue_instruction_branch.predict_target),
        .mispredict(exe_bus.mispredict),
        .actual_taken(exe_bus.actual_taken),
        .actual_target(exe_bus.actual_target),
        .update_pc(exe_bus.update_pc),
        .nextPC(exe_bus.nextPC),
        .isJump(exe_bus.isJump)
    );

endmodule
