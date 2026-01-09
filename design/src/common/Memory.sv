`timescale 1ns/1ps

module Memory #(parameter INSTR_ADDRESS = 32'h0000_0000, parameter DATA_ADDRESS = 32'h0000_1000, ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    output logic  [4096*8-1:0] instr_data,
    output logic  [4096*8-1:0] data_data
);

    logic [7:0] MEM [0:8191];

    initial begin
        $readmemh("../resources/mem.hex", MEM, INSTR_ADDRESS);
        for (int i = 0; i < 4096; i = i + 1) begin
            instr_data[i*8 +: 8] = MEM[INSTR_ADDRESS + i];
        end
        for (int i = 0; i < 4096; i = i + 1) begin
            data_data[i*8 +: 8] = MEM[DATA_ADDRESS + i];
        end
    end

endmodule
