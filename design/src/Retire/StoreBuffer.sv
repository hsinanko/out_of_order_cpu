`timescale 1ns/1ps

import typedef_pkg::*;

module StoreBuffer #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, FIFO_DEPTH= 16)(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic done,
    output logic store_full,
    output logic store_empty,
    // from wb stage
    input  RETIRE_STORE_t retire_store_0,
    input  RETIRE_STORE_t retire_store_1,
    // to memory stage
    output RETIRE_STORE_t retire_store
);

    logic [$clog2(FIFO_DEPTH)-1:0] retire_store_id_0, retire_store_id_1;
    logic retire_store_valid_0, retire_store_valid_1;

    assign retire_store_id_0  = retire_store_0.retire_store_id;
    assign retire_store_valid_0 = retire_store_0.retire_store_valid;

    assign retire_store_id_1  = retire_store_1.retire_store_id;
    assign retire_store_valid_1 = retire_store_1.retire_store_valid;


    RETIRE_STORE_t store_buffer [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH)-1:0] head;
    logic [$clog2(FIFO_DEPTH)-1:0] tail;
    logic [$clog2(FIFO_DEPTH):0] num_entries;

    RETIRE_STORE_t store_buffer_tmp [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH)-1:0] head_tmp;
    logic [$clog2(FIFO_DEPTH)-1:0] tail_tmp;
    logic [$clog2(FIFO_DEPTH):0] num_entries_tmp;

    assign store_full = (num_entries == FIFO_DEPTH);
    assign store_empty = (num_entries == 0);


    logic [1:0] state, next_state;
    parameter EMPTY = 2'b00, NON_EMPTY = 2'b01, FLUSHING = 2'b10, DONE = 2'b11;


    always_ff @(posedge clk or posedge rst) begin
        if(rst)
            state <= EMPTY;
        else
            state <= next_state;
    end


    always_comb begin
        case(state)
            EMPTY: begin
                if(flush) begin
                    next_state = FLUSHING;
                end
                else if(retire_store_valid_0 && retire_store_valid_1) begin
                    next_state = NON_EMPTY;
                end
                else if(retire_store_valid_0 || retire_store_valid_1) begin
                    next_state = EMPTY;
                end
                else begin
                    next_state = EMPTY;
                end
            end
            NON_EMPTY: begin
                if(flush) begin
                    next_state = FLUSHING;
                end
                else if(retire_store_valid_0 || retire_store_valid_1) begin
                    next_state = NON_EMPTY;
                end
                else if(!retire_store_valid_0 && !retire_store_valid_1) begin
                    if(num_entries == 1) begin
                        next_state = EMPTY;
                    end
                    else begin
                        next_state = NON_EMPTY;
                    end
                end
                else begin
                    next_state = NON_EMPTY; 
                end
            end
            FLUSHING: begin
                if(num_entries == 1 || num_entries == 0) begin
                    next_state = DONE;
                end
                else begin
                    next_state = FLUSHING;
                end
            end
            DONE: begin
                next_state = EMPTY;
            end
            default: begin
                next_state = EMPTY;
            end
        endcase
    end

    always_comb begin
        case(state)
            EMPTY: begin
                if(flush) begin
                    retire_store.retire_store_id = '0;
                    retire_store.retire_store_valid = 1'b0;
                end
                else if(retire_store_valid_0 && retire_store_valid_1) begin
                    retire_store.retire_store_id = retire_store_id_0;
                    retire_store.retire_store_valid = retire_store_valid_0;
                end
                else if(retire_store_valid_0) begin
                    retire_store.retire_store_id = retire_store_id_0;
                    retire_store.retire_store_valid = retire_store_valid_0;
                end
                else if(retire_store_valid_1) begin
                    retire_store.retire_store_id = retire_store_id_1;
                    retire_store.retire_store_valid = retire_store_valid_1;
                end
                else begin
                    retire_store.retire_store_id = '0;
                    retire_store.retire_store_valid = 1'b0;
                end
            end
            NON_EMPTY: begin
                retire_store.retire_store_id = store_buffer[head].retire_store_id;
                retire_store.retire_store_valid = store_buffer[head].retire_store_valid;
            end
            FLUSHING: begin
                retire_store.retire_store_id = store_buffer[head].retire_store_id;
                retire_store.retire_store_valid = store_buffer[head].retire_store_valid;
            end
            default: begin
                retire_store.retire_store_id = 'h0;
                retire_store.retire_store_valid = 1'b0;
            end
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            head <= '0;
            tail <= '0;
            num_entries <= '0;
            for(int i = 0; i < FIFO_DEPTH; i = i + 1) begin
                store_buffer[i] <= '0;
            end
        end
        else begin
            head <= head_tmp;
            tail <= tail_tmp;
            num_entries <= num_entries_tmp;
            for(int i = 0; i < FIFO_DEPTH; i = i + 1) begin
                store_buffer[i] <= store_buffer_tmp[i];
            end
        end
    end


    always_comb begin
        head_tmp = head;
        tail_tmp = tail;
        num_entries_tmp = num_entries;
        for(int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            store_buffer_tmp[i] <= store_buffer[i];
        end

        case(state)
            EMPTY: begin
                if(retire_store_valid_0 && retire_store_valid_1) begin
                    store_buffer_tmp[tail_tmp] = retire_store_1;
                    tail_tmp = tail_tmp + 1;
                    num_entries_tmp = num_entries_tmp + 1;
                end
            end
            NON_EMPTY: begin
                if(retire_store_valid_0 && retire_store_valid_1) begin
                    store_buffer_tmp[tail_tmp] = retire_store_0;
                    tail_tmp = tail_tmp + 1;
                    num_entries_tmp = num_entries_tmp + 1; 
                    
                    store_buffer_tmp[tail_tmp] = retire_store_1;
                    tail_tmp = tail_tmp + 1;
                    num_entries_tmp = num_entries_tmp + 1; 
                end
                else if(retire_store_valid_0) begin
                    store_buffer_tmp[tail_tmp] = retire_store_0;
                    tail_tmp = tail_tmp + 1;
                    num_entries_tmp = num_entries_tmp + 1; 
                end
                else if(retire_store_valid_1) begin
                    store_buffer_tmp[tail_tmp] = retire_store_1;
                    tail_tmp = tail_tmp + 1;
                    num_entries_tmp = num_entries_tmp + 1; 
                end

                head_tmp = head_tmp + 1;
                num_entries_tmp = num_entries_tmp - 1;
            end
            FLUSHING: begin
                head_tmp = head_tmp + 1;
                num_entries_tmp = num_entries_tmp - 1;
            end
            DONE: begin
                head_tmp = '0;
                tail_tmp = '0;
                num_entries_tmp = '0;
            end
            default: begin
                head_tmp = '0;
                tail_tmp = '0;
                num_entries_tmp = '0;
                store_buffer_tmp = '{default:'0};
            end
        endcase 

    end

endmodule
