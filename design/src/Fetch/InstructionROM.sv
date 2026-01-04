`timescale 1ns / 1ps
import parameter_pkg::*;

module InstructionROM #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic [ADDR_WIDTH-1:0]  addr,          // Address input
    input  logic                   predict_taken, // Branch prediction signal
    output logic [ADDR_WIDTH-1:0]  instruction_addr_0,   // Fetched Instruction
    output logic [ADDR_WIDTH-1:0]  instruction_addr_1,   // Fetched Instruction
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
        instruction_1 = {instruction_memory[addr + 7], instruction_memory[addr + 6],
                         instruction_memory[addr + 5], instruction_memory[addr + 4]};
       
        instruction_addr_0 = addr;
       
        instruction_addr_1 = addr + 4;
        
        // valid signals

        if(predict_taken) begin
            valid[0] = (addr + 4 <= count) ? 1 : 0;
            valid[1] = 0;
        end else begin
            valid[0] = (addr + 4 <= count) ? 1 : 0;
            valid[1] = (addr + 8 <= count) ? 1 : 0;
        end

    end



endmodule
