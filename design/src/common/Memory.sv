`timescale 1ns/1ps

module Memory #(parameter INSTR_ADDRESS = 32'h0000_0000, DATA_ADDRESS = 32'h0000_1000, INSTR_MEM_SIZE = 4096, DATA_MEM_SIZE = 4096, ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic clk,
    input  logic rst,
    input  logic [ADDR_WIDTH-1:0] pc,           // Address input
    input  predict_t              predict_0,      // Prediction from BTB
    output fetch_t                instruction_0,   // Fetched Instruction
    output fetch_t                instruction_1,
    // data memory interface
    input  logic mem_write_en,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic mem_rd_en,
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic rdata_valid
);

    logic [7:0] MEM [0:(INSTR_MEM_SIZE + DATA_MEM_SIZE)-1];
    logic [INSTR_MEM_SIZE*8-1:0] instr_data;
    logic [DATA_MEM_SIZE*8-1:0] data_data;
    initial begin
        $readmemh("../resources/mem.hex", MEM, INSTR_ADDRESS);
        for (int i = 0; i < INSTR_MEM_SIZE; i = i + 1) begin
            instr_data[i*8 +: 8] = MEM[INSTR_ADDRESS + i];
        end
        for (int i = 0; i < DATA_MEM_SIZE; i = i + 1) begin
            data_data[i*8 +: 8] = MEM[DATA_ADDRESS + i];
        end
    end

    InstructionROM #(ADDR_WIDTH, DATA_WIDTH, INSTR_MEM_SIZE) instr_rom (
        .instr_data(instr_data),
        .addr(pc),
        .predict_0(predict_0),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1)
    );

    DataMemory #(DATA_WIDTH, ADDR_WIDTH, DATA_MEM_SIZE) data_mem (
        .clk(clk),
        .rst(rst),
        .init_data(data_data),
        .mem_write_en(mem_write_en),
        .waddr(waddr),
        .wdata(wdata),
        .mem_rd_en(mem_rd_en),
        .raddr(raddr),
        .rdata(rdata),
        .rdata_valid(rdata_valid)
    );

endmodule
