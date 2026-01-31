`timescale 1ns/1ps

import typedef_pkg::*;
import instruction_pkg::*;
module LoadStoreQueue #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, FIFO_DEPTH = 16)(
    input clk,
    input rst,
    input flush,
    // load & Store inputs
    input EXE_lsu_t exe_lsu,
    // store outpus
    output WB_store_t wb_store,
    // Load outputs
    output WB_load_t wb_load,
    // ========= Memory Interface =================
    // load
    output logic [ADDR_WIDTH-1:0] mem_raddr,
    output logic                  mem_rd_en,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic                  mem_rdata_valid,
    // ========= retire interface ==============
    input  RETIRE_STORE_t retire_store,
    // store
    output logic                  mem_write_en,
    output logic [ADDR_WIDTH-1:0] mem_waddr,
    output logic [DATA_WIDTH-1:0] mem_wdata
);
    // Store Queue Entry Definition
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
    
    assign isStore = exe_lsu.store_valid && !store_full;
    assign isRetire = retire_store_valid && !store_empty;

    always_ff@(posedge clk or posedge rst) begin
        if (rst) begin
            current_age <= 0;
        end
        else if(flush)begin
            current_age <= 0;
        end
        else if(exe_lsu.load_valid || exe_lsu.store_valid) begin
            current_age <= current_age + 1;
        end
        else
            current_age <= current_age; 
    end


    // ========== Store Queue Management ==========
    integer i;

    logic [$clog2(FIFO_DEPTH)-1:0] retire_store_id;
    logic retire_store_valid;

    assign retire_store_id  = retire_store.retire_store_id;
    assign retire_store_valid = retire_store.retire_store_valid;
    

    logic [1:0] state_s, next_state_s;
    parameter IDLE_S = 2'b00, INQUEUE = 2'b01, FLUSHING = 2'b10;

    always_ff @(posedge clk or posedge rst) begin
        if(rst)
            state_s <= IDLE_S;
        else
            state_s <= next_state_s;
    end

    always_comb begin
        case(state_s)
            IDLE_S: begin
                if(rst)
                    next_state_s = IDLE_S;
                else
                    next_state_s = INQUEUE;
            end
            INQUEUE: begin
                if(flush)
                    next_state_s = FLUSHING;
                else
                    next_state_s = INQUEUE;
            end
            FLUSHING: begin
                if(flush)
                    next_state_s = FLUSHING;
                else
                    next_state_s = IDLE_S;
            end
            default:
                next_state_s = IDLE_S;
        endcase
    end

    always_comb begin
        case(state_s)
            IDLE_S: begin
                for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                    StoreQueue[i].age   <= 0;
                    StoreQueue[i].addr  <= 0;
                    StoreQueue[i].data  <= 0;
                    StoreQueue[i].valid <= 1'b0;
                end
                mem_write_en = 1'b0;
                mem_waddr    = 'h0;
                mem_wdata    = 'h0;
                store_count  = 0;
            end
            INQUEUE: begin
                if(isStore) begin
                    StoreQueue[free_store_id].age   = current_age;
                    StoreQueue[free_store_id].addr  = exe_lsu.store_waddr;
                    StoreQueue[free_store_id].data  = exe_lsu.store_wdata;
                    StoreQueue[free_store_id].valid = exe_lsu.store_valid;
                    store_count = store_count + 1;
                end

                if(retire_store_valid) begin
                    StoreQueue[retire_store_id].valid = 1'b0;
                    mem_write_en = 1'b1;
                    mem_waddr    = StoreQueue[retire_store_id].addr;
                    mem_wdata    = StoreQueue[retire_store_id].data;
                    store_count  = store_count - 1;
                end
                else begin
                    mem_write_en = 1'b0;
                    mem_waddr    = 'h0;
                    mem_wdata    = 'h0;
                end
            end
            FLUSHING: begin
                if(retire_store_valid) begin
                    StoreQueue[retire_store_id].valid = 1'b0;
                    mem_write_en = 1'b1;
                    mem_waddr    = StoreQueue[retire_store_id].addr;
                    mem_wdata    = StoreQueue[retire_store_id].data;
                    store_count  = store_count - 1;
                end
                else begin
                    mem_write_en = 1'b0;
                    mem_waddr    = 'h0;
                    mem_wdata    = 'h0;
                end
            end
            default: begin
                mem_write_en = 1'b0;
                mem_waddr    = 'h0;
                mem_wdata    = 'h0;
            end
        endcase
    end

    logic [$clog2(FIFO_DEPTH)-1:0] free_store_id;
    FreeEntry #(FIFO_DEPTH) store_free_entry (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .valid(isStore),
        .is_empty(store_empty),
        .is_full(store_full),
        .free_entry(free_store_id),
        .retire_store_valid(retire_store_valid),
        .retire_entry(retire_store_id) 
    );

    assign wb_store.store_valid = (isStore) ? 1'b1 : 1'b0;
    assign wb_store.store_rob_id = (isStore) ? exe_lsu.store_rob_id : 'hx;
    assign wb_store.store_id = (isStore) ? free_store_id : 'hx;

    // ========== Load Queue Management ==========

    assign isLoad  = exe_lsu.load_valid && !load_full;
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
                LoadQueue[tail_load].addr   <= exe_lsu.load_raddr;
                LoadQueue[tail_load].data   <= 0; // data to be filled on memory response
                LoadQueue[tail_load].funct3 <= exe_lsu.load_funct3;
                LoadQueue[tail_load].rob_id <= exe_lsu.load_rob_id;
                LoadQueue[tail_load].rd_phy <= exe_lsu.load_rd_phy;
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
                if(flush)
                    next_state = IDLE;
                else
                    next_state = (LoadEntry.valid) ? SEND: WAIT;
            end
            SEND: begin
                if(flush)
                    next_state = IDLE;
                else
                    next_state = IDLE;
            end
            WAIT: begin
                if(flush)
                    next_state = IDLE;
                else begin
                    if(mem_rdata_valid)
                        next_state = SEND;
                    else
                        next_state = WAIT;
                end
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
                wb_load.load_valid = 1'b0;
                wb_load.load_rob_id = 'h0;
                wb_load.load_rdata  = 'h0;
                wb_load.rd_load     = 'h0;
            end
            CHECK: begin
                LoadEntry= load_entry(LoadQueue[head_load]);
                mem_rd_en = 1'b1;
                mem_raddr = LoadEntry.addr;
                wb_load.load_valid  = 1'b0;
                wb_load.load_rob_id = 'h0;
                wb_load.load_rdata  = 'h0;
                wb_load.rd_load     = 'h0;
                
            end
            SEND: begin
                mem_rd_en = 1'b0;
                mem_raddr = 'h0;
                wb_load.load_valid  = 1'b1;
                wb_load.load_rob_id = LoadEntry.rob_id;
                wb_load.rd_load     = LoadEntry.rd_phy;
                wb_load.load_rdata  = LoadEntry.data;
            end
            WAIT: begin
                mem_rd_en = 1'b0;
                mem_raddr = 'h0;
                wb_load.load_valid  = 1'b0;
                wb_load.load_rob_id = 'h0;
                wb_load.load_rdata  = 'h0;
                wb_load.rd_load     = 'h0;
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
                wb_load.load_valid  = 1'b0;
                wb_load.load_rob_id = 'h0;
                wb_load.load_rdata  = 'h0;
                wb_load.rd_load     = 'h0;
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

