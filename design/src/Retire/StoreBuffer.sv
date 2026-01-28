`timescale 1ns/1ps

import typedef_pkg::*;

module StoreBuffer #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, FIFO_DEPTH= 16)(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic done,
    output logic full,
    output logic empty,
    // from wb stage
    input MEM_WRITE_t mem_write_0,
    input MEM_WRITE_t mem_write_1,
    // to memory stage
    output logic mem_write_en,
    output logic [ADDR_WIDTH-1:0]mem_waddr,
    output logic [DATA_WIDTH-1:0]mem_wdata
);

    logic [FIFO_DEPTH-1:0] is_full;
    logic [FIFO_DEPTH-1:0] is_empty;

    MEM_WRITE_t store_buffer [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH)-1:0] head;
    logic [$clog2(FIFO_DEPTH)-1:0] tail;
    logic [$clog2(FIFO_DEPTH):0] num_entries;

    MEM_WRITE_t store_buffer_tmp [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH)-1:0] head_tmp;
    logic [$clog2(FIFO_DEPTH)-1:0] tail_tmp;
    logic [$clog2(FIFO_DEPTH):0] num_entries_tmp;

    assign is_full = (num_entries == FIFO_DEPTH);
    assign is_empty = (num_entries == 0);
    assign full  = is_full;
    assign empty = is_empty;
    always_comb begin
        head_tmp = head;
        tail_tmp = tail;
        num_entries_tmp = num_entries;
        if(flush || done) begin
            tail_tmp = 0;
            num_entries_tmp = 0;
        end
        else begin
            for(integer i = 0; i < FIFO_DEPTH; i = i + 1) begin
                store_buffer_tmp[i] = store_buffer[i];
            end
            head_tmp = head;
            tail_tmp = tail;
            num_entries_tmp = num_entries;
            if(mem_write_0.mem_write_en)begin
                store_buffer_tmp[tail_tmp] = mem_write_0;
                tail_tmp = tail_tmp + 1;
                num_entries_tmp = num_entries_tmp + 1;
            end
            if(mem_write_1.mem_write_en)begin
                store_buffer_tmp[tail_tmp] = mem_write_1;
                tail_tmp = tail_tmp + 1;
                num_entries_tmp = num_entries_tmp + 1;
            end

            if(!is_empty) begin
                head_tmp = head + 1;
                num_entries_tmp = num_entries_tmp - 1;
            end

        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            head         <= 0;
            tail         <= 0;
            num_entries  <= 0;
            for(integer i = 0; i < FIFO_DEPTH; i = i + 1) begin
                store_buffer[i] = '{0, 0, 0};
            end
        end
        else if(flush || done) begin
            head         <= 0;
            tail         <= 0;
            num_entries  <= 0;
            store_buffer <= store_buffer_tmp;
        end
        else begin
            head         <= head_tmp;
            tail         <= tail_tmp;
            num_entries  <= num_entries_tmp;
            store_buffer <= store_buffer_tmp;

        end
    end

    always_comb begin
        if(!is_empty) begin
            mem_write_en  = 1'b1;
            mem_waddr     = store_buffer[head].mem_waddr;
            mem_wdata     = store_buffer[head].mem_wdata;
        end
        else begin
            mem_write_en  = 1'b0;
            mem_waddr     = '0;
            mem_wdata     = '0;
        end
    end



endmodule
