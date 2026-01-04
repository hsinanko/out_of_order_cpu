`timescale 1ns / 1ps
import parameter_pkg::*;

module FIFO #(parameter DATA_WIDTH = 32,parameter FIFO_DEPTH = 16) (
    input logic clk,
    input logic rst,
    input logic flush,
    input logic write_en,
    input logic [DATA_WIDTH-1:0] write_data,
    input logic read_en,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic full,
    output logic empty
);
    // FIFO implementation here
    logic [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
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
               read_data <= fifo_mem[read_ptr];
               read_ptr <= read_ptr + 1;
               fifo_count <= fifo_count - 1;
           end
       end
   end


endmodule
