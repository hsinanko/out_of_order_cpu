`timescale 1ns / 1ps
import typedef_pkg::*;
import instruction_pkg::*;
module InstructionDecode #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  fetch_t       instruction,
    output instruction_t decoded_instruction
);
    
    assign decoded_instruction.addr   = instruction.addr;
    assign decoded_instruction.opcode = instruction.data[6:0];
    assign decoded_instruction.valid  = instruction.valid;
    always_comb begin
        case(decoded_instruction.opcode)
            LOAD: begin
                // Decode load instruction
                decoded_instruction.immediate = { {20{instruction.data[31]}}, instruction.data[31:20]};
                decoded_instruction.rs1_addr  = instruction.data[19:15];
                decoded_instruction.funct3    = instruction.data[14:12];
                decoded_instruction.rd_addr   = instruction.data[11:7];
                // don't use
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            STORE: begin
                // Decode store instruction
                decoded_instruction.immediate = { {20{instruction.data[31]}}, instruction.data[31:25], instruction.data[11:7]};
                decoded_instruction.rs2_addr  = instruction.data[24:20];
                decoded_instruction.rs1_addr  = instruction.data[19:15];
                decoded_instruction.funct3    = instruction.data[14:12];
                // don't use
                decoded_instruction.rd_addr   = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            OP_IMM, JALR: begin
                // Decode immediate arithmetic instruction
                decoded_instruction.immediate = { {20{instruction.data[31]}}, instruction.data[31:20]};
                decoded_instruction.rs1_addr  = instruction.data[19:15];
                decoded_instruction.funct3    = instruction.data[14:12];
                decoded_instruction.rd_addr   = instruction.data[11:7];

                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            OP: begin
                // Decode register-register arithmetic instruction
                decoded_instruction.funct7   = instruction.data[31:25];
                decoded_instruction.rs2_addr = instruction.data[24:20];
                decoded_instruction.rs1_addr = instruction.data[19:15];
                decoded_instruction.funct3   = instruction.data[14:12];
                decoded_instruction.rd_addr  = instruction.data[11:7];
                // don't use
                decoded_instruction.immediate = 12'b0;
            end
            LUI, AUIPC: begin
                // Decode load upper immediate
                decoded_instruction.immediate = { {12{instruction.data[31]}},instruction.data[31:12], 12'h000};
                decoded_instruction.rd_addr   = instruction.data[11:7];
                // For LUI/AUIPC, rs1 and rs2 are not used
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.rs1_addr  = '0;
                decoded_instruction.funct3    = 3'b0;
                decoded_instruction.funct7    = 7'b0;
            end
            JAL: begin
                // Decode jump and link instruction
                decoded_instruction.immediate = { {11{instruction.data[31]}}, instruction.data[31], instruction.data[19:12], instruction.data[20], instruction.data[30:21], 1'b0};
                decoded_instruction.rd_addr   = instruction.data[11:7];
                // don't use
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.rs1_addr  = '0;
                decoded_instruction.funct3    = 3'b0;
                decoded_instruction.funct7    = 7'b0;
            end
            BRANCH: begin
                // Decode branch instruction
                decoded_instruction.rs2_addr  = instruction.data[24:20];
                decoded_instruction.rs1_addr  = instruction.data[19:15];
                decoded_instruction.immediate = { {19{instruction.data[31]}}, instruction.data[31], instruction.data[7], instruction.data[30:25], instruction.data[11:8], 1'b0};
                decoded_instruction.funct3   = instruction.data[14:12];
                // don't use
                decoded_instruction.rd_addr   = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            SYSTEM: begin
                // Decode system instruction (e.g., ECALL, EBREAK)
                decoded_instruction.immediate = instruction.data[31:25]; // No immediate for system instructions
                // don't use
                decoded_instruction.rs1_addr  = '0;
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.funct3    = 3'b0;
                decoded_instruction.funct7    = 7'b0;
                decoded_instruction.rd_addr   = '0;
            end
            default: begin
                // Handle other instructions or illegal opcode
                decoded_instruction.immediate = 12'b0;
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.rs1_addr  = '0;
                decoded_instruction.funct3    = 3'b0;
                decoded_instruction.funct7    = 7'b0;
                decoded_instruction.rd_addr   = '0;
            end
        endcase
    end


endmodule
