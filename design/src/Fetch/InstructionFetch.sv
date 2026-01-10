`timescale 1ns / 1ps

import parameter_pkg::*;
import typedef_pkg::*;

module InstructionFetch #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic                  clk,
    input  logic                  rst,
    // PC Interface
    input  logic [ADDR_WIDTH-1:0] pc,
    input  logic [4096*8-1:0]     instr_data,
    output logic [ADDR_WIDTH-1:0] instruction_addr_0,    // instruction address 0
    output logic [ADDR_WIDTH-1:0] instruction_addr_1,    // instruction address 1
    output logic [DATA_WIDTH-1:0] instruction_0,         // instruction 0 
    output logic [DATA_WIDTH-1:0] instruction_1,         // instruction 1
    output logic [1:0]            instruction_valid,
    // BTB Interface
    output logic                  predict_taken_0,
    output logic [ADDR_WIDTH-1:0] predict_target_0,
    output logic                  predict_taken_1,
    output logic [ADDR_WIDTH-1:0] predict_target_1,
    input  logic                  update_valid,
    input  logic [ADDR_WIDTH-1:0] update_btb_pc,
    input  logic                  update_btb_taken,
    input  logic [ADDR_WIDTH-1:0] update_btb_target
);

    BTB #(ADDR_WIDTH, BTB_ENTRIES, BTB_WIDTH) btb(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .pc_valid(1'b1),
        .predict_taken_0(predict_taken_0),
        .predict_target_0(predict_target_0),
        .predict_taken_1(predict_taken_1),
        .predict_target_1(predict_target_1),
        .update_valid(update_valid),
        .update_btb_pc(update_btb_pc),
        .update_btb_taken(update_btb_taken),
        .update_btb_target(update_btb_target)
    );

    InstructionROM #(ADDR_WIDTH, DATA_WIDTH) instr_rom (
        .instr_data(instr_data),
        .addr(pc),
        .predict_taken_0(predict_taken_0),
        .predict_target_0(predict_target_0),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .instruction_valid(instruction_valid)
    );

    assign instruction_addr_0 = pc;
    assign instruction_addr_1 = predict_target_0;

endmodule 