`timescale 1ns/1ps

import typedef_pkg::*;
import instruction_pkg::*;
module LoadStoreQueue #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, FIFO_DEPTH = 16)(
    input clk,
    input rst,
    input flush,
    // Store inputs
    input logic [ADDR_WIDTH-1:0] store_waddr, 
    input logic [DATA_WIDTH-1:0] store_wdata,
    input logic [ROB_WIDTH-1:0]  store_rob_id,
    input logic                  store_valid,
    output logic [$clog2(FIFO_DEPTH)-1:0] store_id,
    // Load inputs
    input logic [2:0]            load_funct3,
    input logic [ADDR_WIDTH-1:0] load_raddr,
    input logic [ROB_WIDTH-1:0]  load_rob_id,
    input logic [PHY_WIDTH-1:0]  load_rd_phy,
    input logic                  load_valid,
    output logic [DATA_WIDTH-1:0] wb_load_valid,
    output logic [ROB_WIDTH-1:0]  wb_load_rob_id,
    output logic [DATA_WIDTH-1:0] wb_load_rdata,
    output logic [PHY_WIDTH-1:0]  wb_rd_load,
    // ========= Memory Interface =================
    // load
    output logic [ADDR_WIDTH-1:0] mem_raddr,
    output logic                  mem_rd_en,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic                  mem_rdata_valid,
    // ========= retire interface ==============
    retire_if.retire_store_sink   retire_store_bus,
    output logic                  mem_write_en,
    output logic [ADDR_WIDTH-1:0] mem_waddr,
    output logic [DATA_WIDTH-1:0] mem_wdata
);



    STORE_entry_t StoreQueue [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH):0] head_store, tail_store;
    logic [$clog2(FIFO_DEPTH):0] store_count;
    logic store_full, store_empty;
    logic isStore, isRetire;

    LOAD_entry_t  LoadQueue  [0:FIFO_DEPTH-1];
    logic [$clog2(FIFO_DEPTH):0] head_load, tail_load;
    logic load_full, load_empty;
    logic [$clog2(FIFO_DEPTH):0] load_count;
    logic isLoad, isSend;
     // Age counter
    logic [31:0] current_age;
     // FIFO control signals
    assign store_full = (store_count == FIFO_DEPTH);
    assign store_empty = (store_count == 0);   
    
    assign isStore = store_valid && !store_full;
    assign isRetire = retire_store_bus.retire_store_valid && !store_empty;

    always_ff@(posedge clk or posedge rst) begin
        if (rst) begin
            current_age <= 0;
        end
        else if(flush)begin
            current_age <= 0;
        end
        else if(load_valid || store_valid) begin
            current_age <= current_age + 1;
        end
        else
            current_age <= current_age; 
    end


    // ========== Store Queue Management ==========
    integer i;
    logic [$clog2(FIFO_DEPTH)-1:0] free_store_id;
    FreeEntry #(FIFO_DEPTH) store_free_entry (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .valid(isStore),
        .is_empty(store_empty),
        .is_full(store_full),
        .free_entry(free_store_id),
        .retire_store_valid(retire_store_bus.retire_store_valid),
        .retire_entry(retire_store_bus.retire_store_id) 
    );

    assign store_id = (isStore) ? free_store_id : 'hx;
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                StoreQueue[i].age   <= 0;
                StoreQueue[i].addr  <= 0;
                StoreQueue[i].data  <= 0;
                StoreQueue[i].valid <= 1'b0;
            end
            store_count <= 0;
        end
        else if(flush) begin
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                StoreQueue[i].age   <= 0;
                StoreQueue[i].addr  <= 0;
                StoreQueue[i].data  <= 0;
                StoreQueue[i].valid <= 1'b0;
            end
            store_count <= 0;
        end
        else begin
            if(store_valid) begin
                StoreQueue[free_store_id].age   <= current_age;
                StoreQueue[free_store_id].addr  <= store_waddr;
                StoreQueue[free_store_id].data  <= store_wdata;
                StoreQueue[free_store_id].valid <= 1'b1;
            end

            if(retire_store_bus.retire_store_valid) begin
                StoreQueue[retire_store_bus.retire_store_id].valid <= 1'b0;
                mem_write_en <= 1'b1;
                mem_waddr    <= StoreQueue[retire_store_bus.retire_store_id].addr;
                mem_wdata    <= StoreQueue[retire_store_bus.retire_store_id].data;
            end
            else begin
                mem_write_en <= 1'b0;
                mem_waddr    <= 'h0;
                mem_wdata    <= 'h0;
            end

            if(isStore && isRetire) begin
                store_count <= store_count;
            end
            else if(isStore && !isRetire) begin
                store_count <= store_count + 1;
            end
            else if(!isStore && isRetire) begin
                store_count <= store_count - 1;
            end
            else begin
                store_count <= store_count;
            end

        end
    end

    // ========== Load Queue Management ==========

    assign isLoad  = load_valid && !load_full;
    assign isSend  = mem_rdata_valid && !load_empty;

    assign load_full = (load_count == FIFO_DEPTH);
    assign load_empty = (load_count == 0);
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            head_load  <= 0;
            tail_load  <= 0;
            load_count <= 0;
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                LoadQueue[i].age    <= 0;
                LoadQueue[i].addr   <= 0;
                LoadQueue[i].data   <= 0;
                LoadQueue[i].funct3 <= 0;
                LoadQueue[i].rob_id <= 0;
                LoadQueue[i].rd_phy <= 0;
                LoadQueue[i].valid  <= 1'b0;
            end
        end
        else if(flush) begin
            head_load  <= 0;
            tail_load  <= 0;
            load_count <= 0;
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                LoadQueue[i].age    <= 0;
                LoadQueue[i].addr   <= 0;
                LoadQueue[i].data   <= 0;
                LoadQueue[i].funct3 <= 0;
                LoadQueue[i].rob_id <= 0;
                LoadQueue[i].rd_phy <= 0;
                LoadQueue[i].valid  <= 1'b0;
            end
        end
        else begin
            if(isLoad) begin
                tail_load <= tail_load + 1;
                LoadQueue[tail_load].age    <= current_age;
                LoadQueue[tail_load].addr   <= load_raddr;
                LoadQueue[tail_load].data   <= 0; // data to be filled on memory response
                LoadQueue[tail_load].funct3 <= load_funct3;
                LoadQueue[tail_load].rob_id <= load_rob_id;
                LoadQueue[tail_load].rd_phy <= load_rd_phy;
                LoadQueue[tail_load].valid  <= 1'b0;
            end

            if(isLoad && isSend) begin
                load_count <= load_count;
            end
            else if(isLoad && !isSend) begin
                load_count <= load_count + 1;
            end
            else if(!isLoad && isSend) begin
                load_count <= load_count - 1;
            end
            else begin
                load_count <= load_count;
            end

            if(isSend)begin
                head_load <= head_load + 1;
            end

        end
    end



    logic [1:0] state, next_state;
    LOAD_entry_t LoadEntry;
    logic [1:0]memory_index;
    localparam IDLE = 2'b00, CHECK = 2'b01, SEND = 2'b10, WAIT = 2'b11;

    always_ff @(posedge clk or posedge rst) begin
        if(rst)
            state <= IDLE;
        else if(flush)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        case(state)
            IDLE: begin
                if(!load_empty)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end
            CHECK: begin
                next_state = (LoadEntry.valid) ? SEND: WAIT;
            end
            SEND: begin
                next_state = IDLE;
            end
            WAIT: begin
                if(mem_rdata_valid)
                    next_state = SEND;
                else
                    next_state = WAIT;
            end
            default:
                next_state = IDLE;
        endcase
    end

   
    always_comb begin
        case(state)
            IDLE: begin
                mem_rd_en   = 1'b0;
                mem_raddr   = 'h0;
                wb_load_valid = 1'b0;
                wb_load_rob_id = 'h0;
                wb_load_rdata  = 'h0;
                wb_rd_load     = 'h0;
            end
            CHECK: begin
                LoadEntry= load_entry(LoadQueue[head_load]);
                mem_rd_en = 1'b1;
                mem_raddr = LoadEntry.addr;
                wb_load_valid  = 1'b0;
                wb_load_rob_id = 'h0;
                wb_load_rdata  = 'h0;
                wb_rd_load     = 'h0;
                
            end
            SEND: begin
                mem_rd_en = 1'b0;
                mem_raddr = 'h0;
                wb_load_valid  = 1'b1;
                wb_load_rob_id = LoadEntry.rob_id;
                wb_rd_load     = LoadEntry.rd_phy;
                wb_load_rdata  = LoadEntry.data;
            end
            WAIT: begin
                mem_rd_en = 1'b0;
                mem_raddr = 'h0;
                wb_load_valid  = 1'b0;
                wb_load_rob_id = 'h0;
                wb_load_rdata  = 'h0;
                wb_rd_load     = 'h0;
                if(mem_rdata_valid) begin
                    memory_index = LoadEntry.addr[1:0];
                    case(LoadEntry.funct3)
                        LB: LoadEntry.data = {{24{mem_rdata[(memory_index << 3) +:8][7]}}, mem_rdata[(memory_index << 3) +:8]};
                        LH: begin
                            if(memory_index[1])
                                LoadEntry.data = {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                            else
                                LoadEntry.data = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                        end
                        LW: LoadEntry.data = mem_rdata;
                        LBU: LoadEntry.data = {24'b0, mem_rdata[(memory_index << 3) +:8]};
                        LHU: begin
                            if(memory_index[1])
                                LoadEntry.data = {16'b0, mem_rdata[31:16]};
                            else
                                LoadEntry.data = {16'b0, mem_rdata[15:0]};
                        end
                        default: LoadEntry.data = 0;
                    endcase
                end
                else begin
                    LoadEntry.data = 0;
                end

            end
            default: begin
                mem_rd_en      = 1'b0;
                mem_raddr      = 'h0;
                wb_load_valid  = 1'b0;
                wb_load_rob_id = 'h0;
                wb_load_rdata  = 'h0;
                wb_rd_load     = 'h0;
            end
        endcase
    end

    function LOAD_entry_t load_entry(input LOAD_entry_t load);
    begin
        load_entry = load;
        for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
            if(StoreQueue[i].valid && (StoreQueue[i].age < load_entry.age) && (StoreQueue[i].addr == load_entry.addr)) begin
                load_entry.data = StoreQueue[i].data;
                load_entry.valid = 1'b1;
            end
        end
    end
    endfunction


endmodule

