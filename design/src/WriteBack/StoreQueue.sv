`timescale 1ns/1ps
import parameter_pkg::*;
import typedef_pkg::*;

module StoreQueue #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, QUEUE = 16)(
    input logic clk,
    input logic rst,
    // from wb stage
    input logic wb_valid,
    input logic [DATA_WIDTH-1:0] wdata_wb,
    input logic [ADDR_WIDTH-1:0] waddr_wb,
    // to memory stage
    input  logic store_valid,
    output logic mem_write_en,
    output logic [ADDR_WIDTH-1:0]mem_waddr,
    output logic [DATA_WIDTH-1:0]mem_wdata
);
    // Store Queue implementation here
    FIFO #( .DATA_WIDTH(ADDR_WIDTH + DATA_WIDTH), .FIFO_DEPTH(QUEUE) ) store_queue (
        .clk(clk),
        .rst(rst),
        .write_en(wb_valid),
        .write_data({waddr_wb, wdata_wb}),
        .read_en(store_valid),
        .read_data({mem_waddr, mem_wdata}),
        .full(),
        .empty()
    );

    always@(posedge clk or posedge rst)begin
        if(rst)begin
            mem_write_en <= 1'b0;
        end
        else begin
            mem_write_en <= store_valid;
        end
    end

endmodule