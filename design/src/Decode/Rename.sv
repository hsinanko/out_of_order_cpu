`timescale 1ns/1ps
import typedef_pkg::*;
import parameter_pkg::*;
module Rename #(parameter ADDR_WIDTH =  32, DATA_WIDTH = 32, REG_WIDTH = 32, ARCH_REGS = 32, PHY_REGS = 64, ROB_WIDTH = 4, PHY_WIDTH = 6)(
    input  logic                  clk,
    input  logic                  rst,
    //====== Instruction Decode ===================
    input  logic [1:0]instruction_valid,
    // first instruction
    input  logic [ADDR_WIDTH-1:0] instruction_addr_0,   // instruction address from IF
    input  logic [DATA_WIDTH-1:0] instruction_0,        // instruction from IF
    // second instruction
    input  logic [ADDR_WIDTH-1:0] instruction_addr_1,   // instruction address from IF
    input  logic [DATA_WIDTH-1:0] instruction_1,
    //======== Front RAT =============================
    output logic [1:0] instr_valid,     // front RAT
    output logic [4:0] rs1_arch_0,      // architected register address
    output logic [4:0] rs2_arch_0,
    output logic [4:0] rd_arch_0,
    input  logic [PHY_WIDTH-1:0] rs1_phy_0,
    input  logic [PHY_WIDTH-1:0] rs2_phy_0,
    input  logic [PHY_WIDTH-1:0] rd_phy_0,
    output logic [4:0] rs1_arch_1,                // architected register address
    output logic [4:0] rs2_arch_1,
    output logic [4:0] rd_arch_1,
    input  logic [PHY_WIDTH-1:0] rs1_phy_1,
    input  logic [PHY_WIDTH-1:0] rs2_phy_1,
    input  logic [PHY_WIDTH-1:0] rd_phy_1,
    //======== Free List =================
    output logic [1:0] free_list_valid, // free list valid signals for both instructions
    input logic [PHY_WIDTH-1:0] rd_phy_new_0,
    input logic [PHY_WIDTH-1:0] rd_phy_new_1,
    //======== Reorder Buffer =================
    // rename/dispatch
    output logic [1:0]          dispatch_valid,
    output ROB_ENTRY_t           dispatch_rob_0,         // entry to be added
    input  logic [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    output ROB_ENTRY_t           dispatch_rob_1,         // entry to be added
    input  logic [ROB_WIDTH-1:0] rob_id_1,

    //======== Physical Register File =================
    output logic [1:0]busy_valid, // rename valid signals for both instructions
    output logic [PHY_REGS-1:0] rd_phy_busy_0,
    output logic [PHY_REGS-1:0] rd_phy_busy_1,
    //====== DecodeRename to ReservationStation====
    output logic [1:0]rename_valid,
    output instruction_t rename_instruction_0,
    output [4:0] rename_rob_id_0,
    output instruction_t rename_instruction_1,
    output [4:0] rename_rob_id_1
);
    
    // Instruction Decode
    instruction_t instr_0, instr_1;

    InstructionDecode #(ADDR_WIDTH, DATA_WIDTH) instr_decode_0 (
        .instruction_addr(instruction_addr_0),
        .instruction(instruction_0),
        .decoded_instruction(instr_0)
    );

    InstructionDecode #(ADDR_WIDTH, DATA_WIDTH) instr_decode_1 (
        .instruction_addr(instruction_addr_1),
        .instruction(instruction_1),
        .decoded_instruction(instr_1)
    );

    // ========== Front RAT =================

    // first instruction
    assign rd_arch_0  = instr_0.rd_addr;
    assign rs1_arch_0 = instr_0.rs1_addr;
    assign rs2_arch_0 = instr_0.rs2_addr;
    assign rd_arch_0  = instr_0.rd_addr;
    // second instruction
    assign rd_arch_1  = instr_1.rd_addr;
    assign rs1_arch_1 = instr_1.rs1_addr;
    assign rs2_arch_1 = instr_1.rs2_addr;
    assign rd_arch_1  = instr_1.rd_addr;

    assign instr_valid = instruction_valid;

    //=========== Freelist =================
    assign free_list_valid[0] = (instruction_valid[0] && (rd_arch_0 != 5'd0) && (instr_0.opcode != STORE));
    assign free_list_valid[1] = (instruction_valid[1] && (rd_arch_1 != 5'd0) && (instr_1.opcode != STORE));

    //=========== Physical Register File =================
    // Physical Register File outputs
    assign busy_valid[0] = (instruction_valid[0] && (rd_arch_0 != 5'd0) && (instr_0.opcode != STORE));
    assign busy_valid[1] = (instruction_valid[1] && (rd_arch_1 != 5'd0) && (instr_1.opcode != STORE));
    assign rd_phy_busy_0 = (busy_valid[0]) ? rd_phy_new_0 : 'h0;
    assign rd_phy_busy_1 = (busy_valid[1]) ? rd_phy_new_1 : 'h0;

    //=========== Reorder Buffer =================
    // Reorder Buffer inputs/outputs

    assign dispatch_valid = instruction_valid;
    //========== First instruction =================
    assign dispatch_rob_0.rd_arch    = rd_arch_0;
    assign dispatch_rob_0.rd_phy_old = rd_phy_0;
    assign dispatch_rob_0.rd_phy_new = rd_phy_new_0;
    assign dispatch_rob_0.opcode     = instr_0.opcode;
    
    // assuming not a branch at rename stage
    // actual target and taken will be updated at commit stage
    assign dispatch_rob_0.pred_target = instr_0.instruction_addr + {{20{instr_0.immediate[11]}}, instr_0.immediate, 1'b0};
    assign dispatch_rob_0.pred_taken  = 1'b1;
    assign dispatch_rob_0.actual_target = '0;
    assign dispatch_rob_0.actual_taken  = 1'b0;
    //========== Second instruction =================
    assign dispatch_rob_1.rd_arch    = rd_arch_1;
    assign dispatch_rob_1.rd_phy_old = rd_phy_1;
    assign dispatch_rob_1.rd_phy_new = rd_phy_new_1;
    assign dispatch_rob_1.opcode     = instr_1.opcode;
    // assuming not a branch at rename stage
    // actual target and taken will be updated at commit stage
    assign dispatch_rob_1.pred_target = instr_1.instruction_addr + {{20{instr_1.immediate[11]}}, instr_1.immediate, 1'b0};
    assign dispatch_rob_1.pred_taken  = 1'b1;
    assign dispatch_rob_1.actual_target = '0;
    assign dispatch_rob_1.actual_taken  = 1'b0;


    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            rename_rob_id_0 <= 5'b0;
            rename_rob_id_1 <= 5'b0;
        end
        else begin
            rename_rob_id_0 <= rob_id_0;
            rename_rob_id_1 <= rob_id_1;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            rename_valid <= 2'b0;
        else begin
            rename_valid[0] <= instruction_valid[0];
            rename_valid[1] <= instruction_valid[1];
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // instruction 0
            rename_instruction_0.instruction_addr <= 0;
            rename_instruction_0.opcode           <= 0;
            rename_instruction_0.funct3           <= 0;
            rename_instruction_0.funct7           <= 0;
            rename_instruction_0.immediate        <= 0;
            rename_instruction_0.rs1_addr         <= 0;
            rename_instruction_0.rs2_addr         <= 0;
            rename_instruction_0.rd_addr          <= 0;
            // instruction 1
            rename_instruction_1.instruction_addr <= 0;
            rename_instruction_1.opcode           <= 0;
            rename_instruction_1.funct3           <= 0;
            rename_instruction_1.funct7           <= 0;
            rename_instruction_1.immediate        <= 0;
            rename_instruction_1.rs1_addr         <= 0;
            rename_instruction_1.rs2_addr         <= 0;
            rename_instruction_1.rd_addr          <= 0;
        end
        else begin
            // instruction 0
            rename_instruction_0.instruction_addr <= instr_0.instruction_addr;
            rename_instruction_0.opcode           <= instr_0.opcode;
            rename_instruction_0.funct3           <= instr_0.funct3;
            rename_instruction_0.funct7           <= instr_0.funct7;
            rename_instruction_0.immediate        <= instr_0.immediate;
            rename_instruction_0.rs1_addr         <= rs1_phy_0;
            rename_instruction_0.rs2_addr         <= rs2_phy_0;
            rename_instruction_0.rd_addr          <= rd_phy_new_0;
            // instruction 1
            rename_instruction_1.instruction_addr <= instr_1.instruction_addr;
            rename_instruction_1.opcode           <= instr_1.opcode;
            rename_instruction_1.funct3           <= instr_1.funct3;
            rename_instruction_1.funct7           <= instr_1.funct7;
            rename_instruction_1.immediate        <= instr_1.immediate;
            rename_instruction_1.rs1_addr         <= rs1_phy_1;
            rename_instruction_1.rs2_addr         <= rs2_phy_1;
            rename_instruction_1.rd_addr          <= rd_phy_new_1;
        end
    end


endmodule
