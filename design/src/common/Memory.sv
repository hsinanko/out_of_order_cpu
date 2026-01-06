
`timescale 1ns/1ps

import parameter_pkg::*;

module Memory #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024,
    parameter ADDR_WIDTH = 32
) (
    input  logic clk,
    input  logic rst,
    input  logic [ADDR_WIDTH-1:0] raddr,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [2:0] funct3,
    input  logic mem_write_en,
    input  logic mem_read_en,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic rdata_valid
);
    // Simple memory array (word addressed)
    logic [DATA_WIDTH-1:0] MEM [0:DEPTH-1];

    // byte offset within a word
    logic [1:0] memory_index;
    logic [7:0] bytes [0:3];
    logic [15:0] half;
    // word index computed from byte address (word-aligned accesses expected)
    logic [$clog2(DEPTH)-1:0] word_idx;

    assign memory_index = raddr[1:0];
    assign word_idx = raddr[($clog2(DEPTH)+1):2];
    assign bytes[0] = MEM[word_idx][7:0];
    assign bytes[1] = MEM[word_idx][15:8];
    assign bytes[2] = MEM[word_idx][23:16];
    assign bytes[3] = MEM[word_idx][31:24];
    assign half = (memory_index[1] == 1'b0) ? MEM[word_idx][15:0] : MEM[word_idx][31:16];

    integer i;

    always_ff @(negedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                MEM[i] <= 'h0;
        end else if (mem_write_en) begin
            MEM[waddr] <= wdata;
        end
    end

    // synchronous read on negedge as in original code (keeps timing similar)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rdata <= 'x;
            rdata_valid <= 1'b0;
        end else if (mem_read_en) begin
            rdata_valid <= 1'b1;
            if (word_idx >= DEPTH) begin
                rdata <= '0;
            end else begin
                case (funct3)
                    // LB: sign-extend selected byte
                    LB:  rdata <= {{24{bytes[memory_index][7]}}, bytes[memory_index]};
                    // LH: sign-extend halfword
                    LH:  rdata <= {{16{half[15]}}, half};
                    // LW: full word
                    LW:  rdata <= MEM[word_idx];
                    // LBU: zero-extend byte
                    LBU: rdata <= {{24{1'b0}}, bytes[memory_index]};
                    // LHU: zero-extend halfword
                    LHU: rdata <= {{16{1'b0}}, half};
                    default: begin
                        rdata <= '0;
                        rdata_valid <= 1'b0;
                    end
                endcase
            end
        end else begin
            rdata_valid <= 1'b0;
        end
    end


    // For debugging: dump memory contents at each clock cycle
    integer           mcd;

    always_ff @(negedge clk) begin
        mcd = $fopen("../../test/build/Memory.txt","w");

        for (i=0; i< DEPTH; i=i+1) begin
            $fdisplay(mcd,"%2d %8h", i, MEM[i]);
        end
        $fclose(mcd);
        //$display("Memory contents dumped to Memory file at time %0t", $time);
    end

endmodule
