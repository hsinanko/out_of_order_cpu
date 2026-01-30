`timescale 1ns/1ps

import instruction_pkg::*;

module BranchUnit #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5)(
    input RS_ENTRY_t issue_instruction_branch,
    input logic [DATA_WIDTH-1:0] rs1_data_branch,
    input logic [DATA_WIDTH-1:0] rs2_data_branch,
    output logic branch_valid,
    output logic jump_valid,
    output logic [ROB_WIDTH-1:0] branch_rob_id,
    output logic [PHY_WIDTH-1:0] rd_phy_branch,
    output logic [ADDR_WIDTH-1:0] nextPC,
    output logic mispredict,
    output logic actual_taken,
    output logic [ADDR_WIDTH-1:0] actual_target,
    output logic [ADDR_WIDTH-1:0] update_pc,
);

    logic [ADDR_WIDTH-1:0] instruction_addr;
    logic [6:0] opcode;
    logic [ADDR_WIDTH-1:0] immediate;
    logic [2:0]funct3;
    logic [ADDR_WIDTH-1:0] predict_target;
    logic predict_taken;

    assign instruction_addr = issue_instruction_branch.addr;
    assign opcode           = issue_instruction_branch.opcode;
    assign immediate        = issue_instruction_branch.immediate;
    assign funct3           = issue_instruction_branch.funct3;
    assign predict_target   = issue_instruction_branch.predict_target;
    assign predict_taken    = issue_instruction_branch.predict_taken;
    assign branch_valid     = issue_instruction_branch.valid;
    assign branch_rob_id    = issue_instruction_branch.rob_id;
    assign rd_phy_branch    = issue_instruction_branch.rd_phy;

    logic [ADDR_WIDTH-1:0]branchTarget, jalTarget, jalrTarget;
    assign branchTarget = instruction_addr + immediate;
    assign jalTarget    = branchTarget;
    assign jalrTarget   = (rs1_data_branch + immediate);
    assign nextPC       = (opcode == JALR || opcode == JAL) ? (instruction_addr + 32'h4) : 'h0;
    always_comb begin
        if(opcode == BRANCH)begin
            case(funct3)
                BEQ: actual_taken  = (rs1_data_branch == rs2_data_branch) ? 1 : 0;
                BNE: actual_taken  = (rs1_data_branch != rs2_data_branch) ? 1 : 0;
                BLT: actual_taken  = (rs1_data_branch < rs2_data_branch) ? 1 : 0;
                BGE: actual_taken  = (rs1_data_branch >= rs2_data_branch) ? 1 : 0;
                BLTU: actual_taken = ($unsigned(rs1_data_branch) < $unsigned(rs2_data_branch)) ? 1 : 0;
                BGEU: actual_taken = ($unsigned(rs1_data_branch) >= $unsigned(rs2_data_branch)) ? 1 : 0;
                default: actual_taken = 0;
            endcase
        end
        else if(opcode == JAL || opcode == JALR) begin
            actual_taken = 1;
        end
        else begin
            actual_taken = 0;
        end
    end

    assign jump_valid = (opcode == JAL || opcode == JALR);
    always_comb begin
        update_pc = instruction_addr;
        if(opcode == JALR)
            actual_target = jalrTarget;
        else if(opcode == JAL)
            actual_target = jalTarget;
        else begin
            if(actual_taken)
                actual_target = branchTarget;
            else
                actual_target = instruction_addr + 'h4;
        end
    end

    assign mispredict = (actual_target != predict_target) || (actual_taken != predict_taken);

endmodule
