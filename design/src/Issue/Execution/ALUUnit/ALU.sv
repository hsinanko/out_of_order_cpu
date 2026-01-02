`timescale 1ns/1ps

import parameter_pkg::*;
module ALU #(parameter DATA_WIDTH = 32)(
    input  logic [DATA_WIDTH-1:0] rdata_1,   // First operand
    input  logic [DATA_WIDTH-1:0] rdata_2,   // Second operand
    input  logic [3:0]            alu_control, // ALU control signal
    output logic [DATA_WIDTH-1:0] alu_result,  // ALU result
    output logic                  zero_flag    // Zero flag
);

    // ALU Operations
    always_comb begin
        case (alu_control)
            ADD:  alu_result = rdata_1 + rdata_2;
            SUB:  alu_result = rdata_1 - rdata_2;
            XOR:  alu_result = rdata_1 ^ rdata_2;
            OR:   alu_result = rdata_1 | rdata_2;
            SLL:  alu_result = rdata_1 << rdata_2;
            SRL:  alu_result = rdata_1 >> rdata_2;
            SRA:  alu_result = rdata_1 >>> rdata_2;
            SLT:  alu_result = ($signed(rdata_1) < $signed(rdata_2)) ? 1 : 0;
            SLTU: alu_result = ($unsigned(rdata_1) < $unsigned(rdata_2)) ? 1 : 0;
            default: alu_result = '0; // Default case
        endcase
    end

    // Zero Flag
    assign zero_flag = (alu_result == 0);
endmodule
