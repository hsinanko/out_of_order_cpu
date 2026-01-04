`timescale 1ns/1ps

import parameter_pkg::*;
import instruction_pkg::*;

module BranchUnit #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input logic [ADDR_WIDTH-1:0] instruction_addr,
    input logic [DATA_WIDTH-1:0] rs1_data_branch,
    input logic [DATA_WIDTH-1:0] rs2_data_branch,
    input logic [6:0] opcode,
    input logic [11:0] immediate,
    input logic [2:0] funct3,
    input logic predict_taken,
    input logic [ADDR_WIDTH-1:0] predict_target,
    output logic mispredict,
    output logic isbranchTaken,
    output logic [ADDR_WIDTH-1:0] actual_target,
    output logic [ADDR_WIDTH-1:0] update_pc,
    output logic isJump
);

    logic [ADDR_WIDTH-1:0]branchTarget, jalTarget, jalrTarget;
    assign branchTarget = instruction_addr + immediate;
    assign jalTarget    = branchTarget;
    assign jalrTarget   = (rs1_data_branch + immediate) << 1;

    always_comb begin
        case(funct3)
            BEQ: isbranchTaken  = (rs1_data_branch == rs2_data_branch) ? 1 : 0;
            BNE: isbranchTaken  = (rs1_data_branch != rs2_data_branch) ? 1 : 0;
            BLT: isbranchTaken  = (rs1_data_branch < rs2_data_branch) ? 1 : 0;
            BGE: isbranchTaken  = (rs1_data_branch >= rs2_data_branch) ? 1 : 0;
            BLTU: isbranchTaken = ($unsigned(rs1_data_branch) < $unsigned(rs2_data_branch)) ? 1 : 0;
            BGEU: isbranchTaken = ($unsigned(rs1_data_branch) >= $unsigned(rs2_data_branch)) ? 1 : 0;
            default: isbranchTaken = 0;
        endcase
    end

    assign isJump = ((opcode == BRANCH && isbranchTaken) || opcode == JAL || opcode == JALR);
    always_comb begin
        update_pc = instruction_addr;
        if(opcode == JALR)
            actual_target = jalrTarget;
        else if(opcode == JAL)
            actual_target = jalTarget;
        else begin
            if(isbranchTaken)
                actual_target = branchTarget;
            else
                actual_target = instruction_addr + 'h4;
        end
    end

    assign mispredict = (isJump != predict_taken) || (isJump && (actual_target != predict_target));

endmodule
