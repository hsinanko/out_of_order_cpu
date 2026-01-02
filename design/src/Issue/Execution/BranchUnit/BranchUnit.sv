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
    output logic [ADDR_WIDTH-1:0] jump_address,
    output logic isJump
);

    logic [ADDR_WIDTH-1:0]branchTarget, jalTarget, jalrTarget;
    logic isbranchTaken;
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
        endcase
    end

    assign isJump = ((opcode == BRANCH && isbranchTaken) || opcode == JAL || opcode == JALR);
    always_comb begin
        if(opcode == JALR)
            jump_address = jalrTarget;
        else if(opcode == JAL)
            jump_address = jalTarget;
        else
            jump_address = branchTarget;
    end

endmodule
