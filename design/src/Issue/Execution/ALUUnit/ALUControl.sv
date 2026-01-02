`timescale 1ns/1ps

import parameter_pkg::*;
module ALUControl(
    input logic [6:0] opcode,
    input logic [6:0] funct7,
    input logic [2:0] funct3,
    output logic [3:0] alu_control
);

    always_comb begin
        if(opcode == OP)begin
            case(funct3)
                ALU_ADD_SUB: alu_control = (funct7[5]) ? SUB : ADD;
                ALU_XOR:     alu_control = XOR;
                ALU_OR:      alu_control = OR;
                ALU_AND:     alu_control = AND;
                ALU_SLL:     alu_control = SLL;
                ALU_SRA_SLL: alu_control = (funct7[5]) ? SRA: SRL;
                ALU_SLT:     alu_control = SLT;
                ALU_SLTU:    alu_control = SLTU;
                default:     alu_control = ADD;
            endcase
        end
        else if(opcode == OP_IMM)begin
            case(funct3)
                ALU_ADD_SUB: alu_control = ADD; // there is no subi
                ALU_XOR:     alu_control = XOR;
                ALU_OR:      alu_control = OR;
                ALU_AND:     alu_control = AND;
                ALU_SLL:     alu_control = SLL;
                ALU_SRA_SLL: alu_control = (funct7[5]) ? SRA: SRL;
                ALU_SLT:     alu_control = SLT;
                ALU_SLTU:    alu_control = SLTU;
                default:     alu_control = ADD;
            endcase
        end
        else
            alu_control = ADD;
    end

endmodule
