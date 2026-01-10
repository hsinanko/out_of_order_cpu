`timescale 1ns/1ps

import instruction_pkg::*;

module BranchUnit #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input logic [ADDR_WIDTH-1:0] instruction_addr,
    input logic [DATA_WIDTH-1:0] rs1_data_branch,
    input logic [DATA_WIDTH-1:0] rs2_data_branch,
    input logic [6:0] opcode,
    input logic [ADDR_WIDTH-1:0] immediate,
    input logic [2:0] funct3,
    input logic predict_taken,
    input logic [ADDR_WIDTH-1:0] predict_target,
    input logic [DATA_WIDTH-1:0] rd_data_branch,
    output logic mispredict,
    output logic actual_taken,
    output logic [ADDR_WIDTH-1:0] actual_target,
    output logic [ADDR_WIDTH-1:0] update_pc,
    output logic [ADDR_WIDTH-1:0] nextPC,
    output logic isJump
);

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

    assign isJump = (opcode == JAL || opcode == JALR);
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
