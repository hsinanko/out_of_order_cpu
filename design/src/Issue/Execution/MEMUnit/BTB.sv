`timescale 1ns/1ps
import parameter_pkg::*;

module BTB #(parameter BTB_ENTRIES = 16, ADDR_WIDTH = 32)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic [ADDR_WIDTH-1:0]  pc_in,
    input  logic                   pc_valid,
    output logic                   btb_hit,
    output logic [ADDR_WIDTH-1:0]  target_addr
);

    typedef struct packed {
        logic                     valid;
        logic [ADDR_WIDTH-1:0]    tag;
        logic [ADDR_WIDTH-1:0]    target;
    } BTB_ENTRY_t;

    BTB_ENTRY_t BTB [BTB_ENTRIES-1:0];

    logic [3:0] index;
    logic [ADDR_WIDTH-1:0] pc_tag;

    assign index   = pc_in[5:2]; // example indexing
    assign pc_tag  = pc_in;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < BTB_ENTRIES; i = i + 1) begin
                BTB[i].valid  <= 1'b0;
                BTB[i].tag    <= 'h0;
                BTB[i].target <= 'h0;
            end
        end
        else if (pc_valid) begin
            if (BTB[index].valid && (BTB[index].tag == pc_tag)) begin
                btb_hit      <= 1'b1;
                target_addr  <= BTB[index].target;
            end
            else begin
                btb_hit      <= 1'b0;
                target_addr  <= 'h0;
            end
        end
    end

endmodule 

