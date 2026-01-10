`timescale 1ns / 1ps
// FreeSlot.sv
// TYPE: ALU =0, LOAD/STORE=1, BRANCH=2

import parameter_pkg::*;
module FreeSlot #(parameter NUM_RS_ENTRIES = 8, TYPE = 0)(
    input logic clk, 
    input logic rst,
    input logic flush,
    input logic valid_0,
    input logic valid_1,
    output logic [$clog2(NUM_RS_ENTRIES)-1:0] free_0,           // physical register address to allocate
    output logic [$clog2(NUM_RS_ENTRIES)-1:0] free_1,           // physical register address to allocate
    input logic  issue_free_valid,
    input logic [$clog2(NUM_RS_ENTRIES):0] issue_free
);

    logic [$clog2(NUM_RS_ENTRIES)-1:0] FREESLOT [0:NUM_RS_ENTRIES-1]; 
    logic [$clog2(NUM_RS_ENTRIES)-1:0] head;                         // points to the next free entry
    logic [$clog2(NUM_RS_ENTRIES)-1:0] tail;                         // points to the next allocated entry
    logic [$clog2(NUM_RS_ENTRIES):0] num_free;                     // number of free entries
    logic [$clog2(NUM_RS_ENTRIES):0] num_free_reg;
    integer i;

    always_comb begin
        if(rst || flush) num_free = NUM_RS_ENTRIES;
        else begin
            num_free = num_free_reg;
            if(valid_0 && valid_1) num_free = num_free - 2;
            else if(valid_0 || valid_1) num_free = num_free - 1;
        end
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            
            for (i = 0; i < NUM_RS_ENTRIES; i = i + 1) begin 
                FREESLOT[i] <= i; 
            end
            head         <= 0;
            tail         <= NUM_RS_ENTRIES - 1;
            num_free_reg <= num_free;
        end
        else if(flush) begin
            // On flush, reset head and tail pointers
            for (i = 0; i < NUM_RS_ENTRIES; i = i + 1) begin 
                FREESLOT[i] <= i; 
            end
            head         <= 0;
            tail         <= NUM_RS_ENTRIES - 1;
            num_free_reg <= num_free;
        end
        else begin
            // Allocate physical registers for renaming
            if(valid_0 && valid_1) begin
                head     <= head + 2;
            end
            else if(valid_0 && !valid_1) begin
                head     <= head + 1;
            end
            else if(!valid_0 && valid_1) begin
                head     <= head + 1;
            end
            else begin
                head     <= head;
            end

            if(issue_free_valid) begin
                FREESLOT[tail + 1] <= issue_free; // -1 to skip PHY_ZERO
                tail               <= tail + 1;
            end
        end
    end

    assign free_0 = (valid_0) ? FREESLOT[head] : 'hx; 
    assign free_1 = (valid_1) ? (valid_0 ? FREESLOT[head + 1] : FREESLOT[head]) : 'hx;

    // // For debugging: dump FreeSlot contents at each clock cycle
    // integer           mcd, i;

    // always_ff @(negedge clk) begin

    //     case(TYPE)
    //         0: mcd = $fopen("FreeSlot_ALU.txt","w");
    //         1: mcd = $fopen("FreeSlot_LSU.txt","w");
    //         2: mcd = $fopen("FreeSlot_BRU.txt","w");
    //         default: mcd = $fopen("FreeSlot_UNKNOWN","w");
    //     endcase

    //     for (i=head; i != tail; i=i+1) begin
    //         $fdisplay(mcd,"%2d %3d", i, FREESLOT[i]);
    //     end
    //     $fdisplay(mcd,"%2d %3d", tail, FREESLOT[tail]);

    //     $fclose(mcd);
    //     //$display("FreeSlot contents dumped to FreeSlot file at time %0t", $time);
    // end

endmodule 

