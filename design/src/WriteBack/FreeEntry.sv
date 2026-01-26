`timescale 1ns / 1ps
// FreeEntry.sv

module FreeEntry #(parameter FIFO_DEPTH = 16)(
    input logic clk, 
    input logic rst,
    input logic flush,
    input logic valid,
    output logic is_empty,
    output logic is_full,
    output logic [$clog2(FIFO_DEPTH)-1:0] free_entry,
    input logic  retire_store_valid,
    input logic [$clog2(FIFO_DEPTH)-1:0] retire_entry
);

    logic [$clog2(FIFO_DEPTH)-1:0] FREEENTRY [0:FIFO_DEPTH-1]; 
    logic [$clog2(FIFO_DEPTH)-1:0] head;                         // points to the next free entry
    logic [$clog2(FIFO_DEPTH)-1:0] tail;                         // points to the next allocated entry
    logic [$clog2(FIFO_DEPTH):0] num_free;                     // number of free entries
    logic [$clog2(FIFO_DEPTH):0] num_free_reg;           
    integer i;

    assign is_empty = (num_free == FIFO_DEPTH);
    assign is_full  = (num_free == 0);

    always_comb begin
        if(rst || flush) num_free = FIFO_DEPTH;
        else begin
            num_free = num_free_reg;
            if(valid) num_free = num_free - 1;
            if(retire_store_valid) num_free = num_free + 1;
        end
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin 
                FREEENTRY[i] <= i; 
            end
            head         <= 0;
            tail         <= FIFO_DEPTH - 1;
            num_free_reg <= FIFO_DEPTH;
        end
        else if(flush) begin
            // On flush, reset head and tail pointers
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin 
                FREEENTRY[i] <= i; 
            end
            head         <= 0;
            tail         <= FIFO_DEPTH - 1;
            num_free_reg <= FIFO_DEPTH;
        end
        else begin
            // Allocate physical registers for renaming
            num_free_reg <= num_free;
            if(valid) begin
                head <= head + 1;
            end
            else begin
                head <= head;
            end

            if(retire_store_valid) begin
                FREEENTRY[tail+1] <= retire_entry; 
                tail                <= tail + 1;
            end
        end
    end

    assign free_entry = (valid) ? FREEENTRY[head] : 'hx; 

endmodule 
