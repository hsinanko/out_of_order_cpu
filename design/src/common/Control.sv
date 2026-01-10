`timescale 1ns/1ps

module Control(
    input clk,
    input rst,
    input flush,
    input rob_full,
    input rob_empty,
    input free_list_full,
    input free_list_empty,
    output logic pc_valid,
    output logic stall_fetch,
    output logic stall_dispatch
);
    
    always_comb begin
        if (rst) begin
            stall_fetch = 1'b0;
            stall_dispatch = 1'b0;
            pc_valid = 1'b0;
        end
        else if (flush) begin
            stall_fetch = 1'b0;
            stall_dispatch = 1'b0;
            pc_valid = 1'b0;
        end
        else begin
            // Stall fetch if ROB is full
            if (rob_full || free_list_empty) begin
                stall_fetch = 1'b1;
                stall_dispatch = 1'b1;
                pc_valid = 1'b0;
            end
            else begin
                stall_fetch = 1'b0;
                stall_dispatch = 1'b0;
                pc_valid = 1'b1;
            end
        end
    end


endmodule

