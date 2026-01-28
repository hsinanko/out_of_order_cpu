`timescale 1ns / 1ps

import typedef_pkg::*;
module InstructionROM #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, INSTR_MEM_SIZE = 4096)(
    input  logic [INSTR_MEM_SIZE*8-1:0]      instr_data,
    input  logic [ADDR_WIDTH-1:0]  addr,           // Address input
    input  predict_t               predict_0,
    output fetch_t                 instruction_0,    // instruction address 0
    output fetch_t                 instruction_1,    // instruction address 1
);


    // Simple instruction memory (for simulation purposes) - store 32-bit words
    logic [7:0] instruction_memory [0:INSTR_MEM_SIZE-1];

    logic [9:0] count;
    // Try to load a word-per-line hex memory file from common locations. If not
    // found, initialize memory to zeros and warn.
    initial begin
        for (int i = 0; i < INSTR_MEM_SIZE; i = i + 1) begin
            instruction_memory[i] = instr_data[i*8 +: 8];
        end
    end

    // Combinational read logic
    always_comb begin
        instruction_0.data = {instruction_memory[addr + 3], instruction_memory[addr + 2],
                         instruction_memory[addr + 1], instruction_memory[addr]};
        instruction_1.data = {instruction_memory[predict_0.predict_target + 3], instruction_memory[predict_0.predict_target + 2],
                         instruction_memory[predict_0.predict_target + 1], instruction_memory[predict_0.predict_target]};
          
        // valid signals
        instruction_0.valid = (addr + 4 <= INSTR_MEM_SIZE) ? 1 : 0;
        instruction_1.valid = (predict_0.predict_target + 4 <= INSTR_MEM_SIZE) ? 1 : 0;

    end

    assign instruction_0.addr = addr;
    assign instruction_1.addr = predict_0.predict_target;


endmodule
