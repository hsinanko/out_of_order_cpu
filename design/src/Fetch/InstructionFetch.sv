`timescale 1ns / 1ps

import parameter_pkg::*;
import typedef_pkg::*;

module InstructionFetch #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [ADDR_WIDTH-1:0] pc,
    output logic [ADDR_WIDTH-1:0] instruction_addr_0,    // instruction address 0
    output logic [ADDR_WIDTH-1:0] instruction_addr_1,    // instruction address 1
    output logic [DATA_WIDTH-1:0] instruction_0,         // instruction 0 
    output logic [DATA_WIDTH-1:0] instruction_1,         // instruction 1
    output logic [1:0]            instruction_valid,
    // BTB Interface
    output logic                  predict_taken,
    output logic [ADDR_WIDTH-1:0] predict_target,
    input  logic                  update_valid,
    input  logic [ADDR_WIDTH-1:0] update_pc,
    input  logic                  update_taken,
    input  logic [ADDR_WIDTH-1:0] update_target
);

    BTB #(ADDR_WIDTH, BTB_ENTRIES, BTB_WIDTH) btb(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .pc_valid(1'b1),
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .update_valid(update_valid),
        .update_pc(update_pc),
        .update_taken(update_taken),
        .update_target(update_target)
    );

    InstructionROM #(ADDR_WIDTH, DATA_WIDTH) instr_rom (
        .addr(pc),
        .predict_taken(predict_taken),
        .instruction_addr_0(instruction_addr_0),
        .instruction_addr_1(instruction_addr_1),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .valid(instruction_valid)
    );


endmodule 


