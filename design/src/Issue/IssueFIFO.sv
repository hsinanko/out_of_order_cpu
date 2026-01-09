`timescale 1ns / 1ps
import parameter_pkg::*;

module IssueFIFO #(parameter FIFO_DEPTH = 16) (
    input logic clk,
    input logic rst,
    input logic flush,
    input logic write_en,
    input RS_ENTRY_t write_data,
    input logic read_en,
    output RS_ENTRY_t read_data,
    output logic full,
    output logic empty
);
    // FIFO implementation here
    RS_ENTRY_t fifo_mem [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH):0] write_ptr, read_ptr;
    logic [$clog2(FIFO_DEPTH):0] fifo_count;
    assign full = (fifo_count == FIFO_DEPTH);
    assign empty = (fifo_count == 0);   

   always_ff @(posedge clk or posedge rst) begin
       if (rst) begin
           write_ptr <= 0;
           read_ptr <= 0;
           fifo_count <= 0;
       end 
       else if(flush)begin
            write_ptr <= 0;
            read_ptr <= 0;
            fifo_count <= 0;
       end
       else begin
           if (write_en && !full) begin
               fifo_mem[write_ptr] <= write_data;
               write_ptr <= write_ptr + 1;
               fifo_count <= fifo_count + 1;
           end
           if (read_en && !empty) begin
               read_ptr <= read_ptr + 1;
               fifo_count <= fifo_count - 1;
           end
       end
   end

   assign read_data = fifo_mem[read_ptr];


endmodule
