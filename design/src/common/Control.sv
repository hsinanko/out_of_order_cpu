`timescale 1ns/1ps

module Control #(parameter ADDR_WIDTH = 32)(
    input clk,
    input rst,
    // flush signals
    input logic isFlush,
    input logic [ADDR_WIDTH-1:0] target_pc,
    input logic store_empty,
    output logic flush,
    output logic [ADDR_WIDTH-1:0] redirect_pc,
    // stall signals
    input logic rob_full,
    input logic rob_empty,
    input logic free_list_full,
    input logic free_list_empty,
    output logic pc_valid,
    output logic stall,
    // done signals
    input logic done_valid,
    output logic done
);


    logic [2:0] state, next_state;
    parameter IDLE = 3'b001, STALL = 3'b010, FLUSH = 3'b011, DONE = 3'b100;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            IDLE: begin
                if (isFlush) begin
                    next_state = FLUSH;
                end
                else if( done_valid ) begin
                    next_state = DONE;
                end
                else if (rob_full || free_list_empty) begin
                    next_state = STALL;
                end
                else begin
                    next_state = IDLE;
                end
            end
            STALL: begin
                if (isFlush) begin
                    next_state = FLUSH;
                end
                else if (!rob_full && !free_list_empty) begin
                    next_state = IDLE;
                end
                else begin
                    next_state = STALL;
                end
            end
            FLUSH: begin
                next_state = (store_empty) ? IDLE : FLUSH;
                //next_state = IDLE;
            end
            DONE: begin
                next_state = DONE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_comb begin
        case(state)
            IDLE: begin
                flush = 1'b0;
                redirect_pc = (isFlush) ? target_pc : 'h0;
                stall = (rob_full || free_list_empty) ? 1'b1 : 1'b0;
                pc_valid = (isFlush || rob_full || free_list_empty) ? 1'b0 : 1'b1;
                done = 1'b0;
            end
            STALL: begin
                flush = 1'b0;
                redirect_pc = (isFlush) ? target_pc : 'h0;
                stall = 1'b1;
                pc_valid = 1'b0;
                done = 1'b0;
            end
            FLUSH: begin
                flush = 1'b1;
                redirect_pc = redirect_pc;
                stall = 1'b0;
                pc_valid = 1'b0;
                done = 1'b0;
            end
            DONE: begin
                flush = 1'b0;
                redirect_pc = 'h0;
                stall = 1'b0;
                pc_valid = 1'b1;
                done = 1'b1;
            end
        endcase
    end



endmodule

