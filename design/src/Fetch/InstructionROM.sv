`timescale 1ns / 1ps
import parameter_pkg::*;

module InstructionROM #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic [ADDR_WIDTH-1:0]  addr,           // Address input
    input  logic                   predict_taken_0, // Branch prediction signal
    input  logic [ADDR_WIDTH-1:0]  predict_target_0,
    output logic [DATA_WIDTH-1:0]  instruction_0,   // Fetched Instruction
    output logic [DATA_WIDTH-1:0]  instruction_1,
    output logic [1:0]             valid
);


    // Simple instruction memory (for simulation purposes) - store 32-bit words
    logic [7:0] instruction_memory [0:1023];

    logic [9:0] count;
    // Try to load a word-per-line hex memory file from common locations. If not
    // found, initialize memory to zeros and warn.
    initial begin
        integer fd;
        logic [32:0] inst;

        count = 0;
        fd = $fopen("../resources/instruction.txt", "r");

        while (!$feof(fd)) begin
            if ($fscanf(fd, "%h\n", inst) == 1) begin
                instruction_memory[count] = inst[7:0];
                instruction_memory[count + 1] = inst[15:8];
                instruction_memory[count + 2] = inst[23:16];
                instruction_memory[count + 3] = inst[31:24];
                count += 4;
            end
        end

        $fclose(fd);
    end

    // Combinational read logic
    always_comb begin
        instruction_0 = {instruction_memory[addr + 3], instruction_memory[addr + 2],
                         instruction_memory[addr + 1], instruction_memory[addr]};
        instruction_1 = {instruction_memory[predict_target_0 + 3], instruction_memory[predict_target_0 + 2],
                         instruction_memory[predict_target_0 + 1], instruction_memory[predict_target_0]};
          
        // valid signals
        valid[0] = (addr + 4 <= count) ? 1 : 0;
        valid[1] = (predict_target_0 + 4 <= count) ? 1 : 0;

    end



endmodule
