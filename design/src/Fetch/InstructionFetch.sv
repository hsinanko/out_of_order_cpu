`timescale 1ns / 1ps

import parameter_pkg::*;
import typedef_pkg::*;

module InstructionFetch #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  isJump,
    input  logic [ADDR_WIDTH-1:0] start_addr,
    input  logic [ADDR_WIDTH-1:0] jump_address,          // jump address 
    output logic [ADDR_WIDTH-1:0] instruction_addr_0,    // instruction address 0
    output logic [ADDR_WIDTH-1:0] instruction_addr_1,    // instruction address 1
    output logic [DATA_WIDTH-1:0] instruction_0,         // instruction 0 
    output logic [DATA_WIDTH-1:0] instruction_1,         // instruction 1
    output logic [1:0]            instruction_valid
);
    // Simple instruction memory (for simulation purposes)
    logic [ADDR_WIDTH-1:0] pc;                 // program counter
    logic [DATA_WIDTH-1:0] instruction_fetch_0; // fetched instruction 0
    logic [DATA_WIDTH-1:0] instruction_fetch_1; // fetched instruction 1
    logic [1:0] valid;
    InstructionROM #(ADDR_WIDTH, DATA_WIDTH) instr_rom (
        .addr(pc),
        .instruction_0(instruction_fetch_0),
        .instruction_1(instruction_fetch_1),
        .valid(valid)
    );

    always_ff @(posedge clk or posedge rst)begin
        if (rst) begin
            pc <= start_addr;
            instruction_addr_0 <= 0;
            instruction_addr_1 <= 4;
            instruction_0 <= '0;
            instruction_1 <= '0;
        end
        else if(isJump) begin
            pc                 <= jump_address;
            instruction_addr_0 <= jump_address;
            instruction_addr_1 <= jump_address + 4;
            instruction_0      <= instruction_fetch_0;
            instruction_1      <= instruction_fetch_1;
            instruction_valid   <= valid;
        end
        else begin
            pc                 <= pc + 8;
            instruction_addr_0 <= pc;
            instruction_addr_1 <= pc + 4;
            instruction_0      <= instruction_fetch_0;
            instruction_1      <= instruction_fetch_1;
            instruction_valid  <= valid;
        end
    end


endmodule 


