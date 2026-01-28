`timescale 1ns / 1ps
import typedef_pkg::*;
import instruction_pkg::*;
module InstructionDecode #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic [ADDR_WIDTH-1:0] instruction_addr,  // instruction address from IF
    input  logic [DATA_WIDTH-1:0] instruction,       // instruction from IF
    output instruction_t          decoded_instruction
);
    
    assign decoded_instruction.addr = instruction_addr;
    assign decoded_instruction.opcode = instruction[6:0];

    always_comb begin
        case(decoded_instruction.opcode)
            LOAD: begin
                // Decode load instruction
                decoded_instruction.immediate = { {20{instruction[31]}}, instruction[31:20]};
                decoded_instruction.rs1_addr  = instruction[19:15];
                decoded_instruction.funct3    = instruction[14:12];
                decoded_instruction.rd_addr   = instruction[11:7];
                // don't use
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            STORE: begin
                // Decode store instruction
                decoded_instruction.immediate = { {20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                decoded_instruction.rs2_addr  = instruction[24:20];
                decoded_instruction.rs1_addr  = instruction[19:15];
                decoded_instruction.funct3    = instruction[14:12];
                // don't use
                decoded_instruction.rd_addr   = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            OP_IMM, JALR: begin
                // Decode immediate arithmetic instruction
                decoded_instruction.immediate = { {20{instruction[31]}}, instruction[31:20]};
                decoded_instruction.rs1_addr  = instruction[19:15];
                decoded_instruction.funct3    = instruction[14:12];
                decoded_instruction.rd_addr   = instruction[11:7];

                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            OP: begin
                // Decode register-register arithmetic instruction
                decoded_instruction.funct7   = instruction[31:25];
                decoded_instruction.rs2_addr = instruction[24:20];
                decoded_instruction.rs1_addr = instruction[19:15];
                decoded_instruction.funct3   = instruction[14:12];
                decoded_instruction.rd_addr  = instruction[11:7];
                // don't use
                decoded_instruction.immediate = 12'b0;
            end
            LUI, AUIPC: begin
                // Decode load upper immediate
                decoded_instruction.immediate = { {12{instruction[31]}},instruction[31:12], 12'h000};
                decoded_instruction.rd_addr   = instruction[11:7];
                // For LUI/AUIPC, rs1 and rs2 are not used
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.rs1_addr  = '0;
                decoded_instruction.funct3    = 3'b0;
                decoded_instruction.funct7    = 7'b0;
            end
            JAL: begin
                // Decode jump and link instruction
                decoded_instruction.immediate = { {11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
                decoded_instruction.rd_addr   = instruction[11:7];
                // don't use
                decoded_instruction.rs2_addr  = '0;
                decoded_instruction.rs1_addr  = '0;
                decoded_instruction.funct3    = 3'b0;
                decoded_instruction.funct7    = 7'b0;
            end
            BRANCH: begin
                // Decode branch instruction
                decoded_instruction.rs2_addr  = instruction[24:20];
                decoded_instruction.rs1_addr  = instruction[19:15];
                decoded_instruction.immediate = { {19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                decoded_instruction.funct3   = instruction[14:12];
                // don't use
                decoded_instruction.rd_addr   = '0;
                decoded_instruction.funct7    = 7'b0;
            end
            SYSTEM: begin
                // Decode system instruction (e.g., ECALL, EBREAK)
                decoded_instruction.immediate = instruction[31:25]; // No immediate for system instructions
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
