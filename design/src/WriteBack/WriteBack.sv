`timescale 1ns/1ps


module WriteBack #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5, FIFO_DEPTH = 16)(
    input logic clk,
    input logic rst,
    input logic flush,
    // ============== from Execution (enqueue candidates) =================
    // from alu
    input logic [ROB_WIDTH-1:0]  alu_rob_id,
    input logic [DATA_WIDTH-1:0] alu_output,
    input logic [PHY_WIDTH-1:0]  rd_phy_alu,
    input logic                  alu_valid,
    // Store outputs
    input logic [ADDR_WIDTH-1:0] store_waddr, 
    input logic [DATA_WIDTH-1:0] store_wdata,
    input logic [ROB_WIDTH-1:0]  store_rob_id,
    input logic                  store_valid,
    // Load outputs
    input logic [2:0]            load_funct3,
    input logic [ADDR_WIDTH-1:0] load_raddr,
    input logic [ROB_WIDTH-1:0]  load_rob_id,
    input logic [PHY_WIDTH-1:0]  load_rd_phy,
    input logic                  load_valid,
    // Branch information
    input logic [ROB_WIDTH-1:0]  branch_rob_id,
    input logic [ADDR_WIDTH-1:0] jumpPC,
    input logic [ADDR_WIDTH-1:0] nextPC,
    input logic [PHY_WIDTH-1:0]  rd_phy_branch,
    input logic actual_taken,
    input logic mispredict,
    input logic [ADDR_WIDTH-1:0] update_pc,
    input logic isJump,
    input logic branch_valid,
    // ========== Physical Register & ROB Commit Interface ===========
    // alu
    output  logic                  commit_alu_valid,
    output  logic [ROB_WIDTH-1:0]  commit_alu_rob_id,
    output  logic [PHY_WIDTH-1:0]  commit_rd_alu,
    output  logic [DATA_WIDTH-1:0] commit_alu_result,
    // load
    output  logic                  commit_load_valid,
    output  logic [ROB_WIDTH-1:0]  commit_load_rob_id,
    output  logic [PHY_WIDTH-1:0]  commit_rd_load,
    output  logic [DATA_WIDTH-1:0] commit_load_rdata,
    //store
    output  logic                  commit_store_valid,
    output  logic [ROB_WIDTH-1:0]  commit_store_rob_id,
    output  logic [$clog2(FIFO_DEPTH)-1:0] commit_store_id,
    // branch
    output  logic                  commit_branch_valid,
    output  logic                  commit_jump_valid,
    output  logic [ROB_WIDTH-1:0]  commit_branch_rob_id,
    output  logic [PHY_WIDTH-1:0]  commit_rd_branch,
    output  logic [ADDR_WIDTH-1:0] commit_nextPC,
    output  logic                  commit_mispredict,
    output  logic [ADDR_WIDTH-1:0] commit_actual_target,
    output  logic                  commit_actual_taken,
    output  logic [ADDR_WIDTH-1:0] commit_update_pc,
    
    // =========== Memory Interface =================
    output logic                  mem_rd_en,
    output logic [ADDR_WIDTH-1:0] mem_raddr,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic                  mem_rdata_valid,
    // ========== retire interface ==============
    input   logic                 retire_store_valid,
    input  logic [$clog2(FIFO_DEPTH)-1:0] retire_store_id,
    output logic                  mem_write_en,
    output logic [ADDR_WIDTH-1:0] mem_waddr,
    output logic [DATA_WIDTH-1:0] mem_wdata 
);

    logic [$clog2(FIFO_DEPTH)-1:0] store_id;
    LoadStoreQueue #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) LSQ (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // Store inputs
        .store_waddr(store_waddr), 
        .store_wdata(store_wdata),
        .store_rob_id(store_rob_id),
        .store_valid(store_valid),
        .store_id(store_id),
        // Load inputs
        .load_funct3(load_funct3),
        .load_raddr(load_raddr),
        .load_rob_id(load_rob_id),
        .load_rd_phy(load_rd_phy),
        .load_valid(load_valid),
        // commit outputs
        .commit_load_valid(commit_load_valid),
        .commit_load_rob_id(commit_load_rob_id),
        .commit_load_rdata(commit_load_rdata),
        .commit_rd_load(commit_rd_load),
        // ========= Memory Interface =================
        // load
        .mem_raddr(mem_raddr),
        .mem_rd_en(mem_rd_en),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        // ========= retire interface ==============
        .retire_store_valid(retire_store_valid),
        .retire_store_id(retire_store_id),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );

    always_comb begin
        // commit signals to ROB
        commit_alu_valid      = (flush) ? 1'b0 : alu_valid;
        commit_alu_rob_id     = alu_rob_id;
        commit_rd_alu         = rd_phy_alu;
        commit_alu_result     = alu_output;
        // store
        commit_store_valid    = (flush) ? 1'b0 : (store_valid);
        commit_store_rob_id   = store_rob_id;
        commit_store_id       = store_id;
        // branch
        commit_branch_valid   = (flush) ? 1'b0 : branch_valid;
        commit_jump_valid     = (flush) ? 1'b0 : isJump;
        commit_branch_rob_id  = branch_rob_id;
        commit_rd_branch      = rd_phy_branch;
        commit_nextPC         = nextPC;
        commit_mispredict     = mispredict;
        commit_actual_target  = jumpPC;
        commit_actual_taken   = actual_taken;
        commit_update_pc      = update_pc;
    end



endmodule

