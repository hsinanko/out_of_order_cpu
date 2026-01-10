
`timescale 1ns/1ps

import parameter_pkg::*;

module DataMemory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_MEM_SIZE = 4096
) (
    input  logic clk,
    input  logic rst,
    input  logic [(DATA_MEM_SIZE*4*8)-1:0] init_data,
    input  logic mem_write_en,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic mem_rd_en,
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic rdata_valid
);
    // Simple memory array (word addressed)
    logic [7:0] DataMem [0:DATA_MEM_SIZE-1];

    // byte offset within a word
    logic [1:0] memory_index;
    logic [7:0] bytes [0:3];
    logic [15:0] half;
    // word index computed from byte address (word-aligned accesses expected)

    assign memory_index = raddr[1:0];
    assign word_idx = raddr[ADDR_WIDTH-1:2];

    integer i;

    initial begin
        for (i = 0; i < DATA_MEM_SIZE; i = i + 1)
            DataMem[i] = init_data[i*8 +: 8];
    end

    logic [$clog2(DATA_MEM_SIZE)-1:0] phys_waddr;
    logic [$clog2(DATA_MEM_SIZE)-1:0] phys_raddr;

    assign phys_waddr = waddr[$clog2(DATA_MEM_SIZE)-1:0];
    assign phys_raddr = raddr[$clog2(DATA_MEM_SIZE)-1:0]; 

    always_ff @(negedge clk or posedge rst) begin
        if (!rst) begin
            if (mem_write_en) begin
                {DataMem[phys_waddr+3], DataMem[phys_waddr+2], DataMem[phys_waddr+1], DataMem[phys_waddr]} <= wdata;
            end
        end
    end

    // synchronous read on negedge as in original code (keeps timing similar)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rdata <= 'x;
            rdata_valid <= 1'b0;
        end else if (mem_rd_en) begin
            rdata_valid <= 1'b1;
            rdata       <= {DataMem[phys_raddr+3], DataMem[phys_raddr+2], DataMem[phys_raddr+1], DataMem[phys_raddr]};
        end else begin
            rdata_valid <= 1'b0;
        end
    end

    // For debugging: dump memory contents at each clock cycle
    integer           mcd;

    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/DataMemory.txt","w");

        for (i=0; i< DATA_MEM_SIZE; i=i+4) begin
            $fdisplay(mcd,"%4h %2h%2h%2h%2h", i, DataMem[i+3], DataMem[i+2], DataMem[i+1], DataMem[i]);
        end
        $fclose(mcd);
        //$display("Memory contents dumpe to Memory file at time %0t", $time);
    end

endmodule
