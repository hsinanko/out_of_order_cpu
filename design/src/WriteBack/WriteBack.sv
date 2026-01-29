`timescale 1ns/1ps


module WriteBack #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5, FIFO_DEPTH = 16)(
    input logic clk,
    input logic rst,
    input logic flush,
    // ============== from Execution (enqueue candidates) =================
    execution_if.sink   exe_to_wb_bus,
    // ========== Physical Register & ROB Commit Interface ===========
    // alu
    writeback_if.source wb_bus,
    
    // =========== Memory Interface =================
    output logic                  mem_rd_en,
    output logic [ADDR_WIDTH-1:0] mem_raddr,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic                  mem_rdata_valid,
    // ========== retire interface ==============
    retire_if.retire_store_sink   retire_store_bus_0,
    retire_if.retire_store_sink   retire_store_bus_1,
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
        .store_waddr(exe_to_wb_bus.store_waddr), 
        .store_wdata(exe_to_wb_bus.store_wdata),
        .store_rob_id(exe_to_wb_bus.store_rob_id),
        .store_valid(exe_to_wb_bus.store_valid),
        .store_id(store_id),
        // Load inputs
        .load_funct3(exe_to_wb_bus.load_funct3),
        .load_raddr(exe_to_wb_bus.load_raddr),
        .load_rob_id(exe_to_wb_bus.load_rob_id),
        .load_rd_phy(exe_to_wb_bus.load_rd_phy),
        .load_valid(exe_to_wb_bus.load_valid),
        // commit outputs
        .wb_load_valid(wb_bus.load_valid),
        .wb_load_rob_id(wb_bus.load_rob_id),
        .wb_load_rdata(wb_bus.load_rdata),
        .wb_rd_load(wb_bus.rd_load),
        // ========= Memory Interface =================
        // load
        .mem_raddr(mem_raddr),
        .mem_rd_en(mem_rd_en),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        // ========= retire interface ==============
        .retire_store_bus_0(retire_store_bus_0),
        .retire_store_bus_1(retire_store_bus_1),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );

    always_comb begin
        // commit signals to ROB
        wb_bus.alu_valid      = (flush) ? 1'b0 : exe_to_wb_bus.alu_valid;
        wb_bus.alu_rob_id     = exe_to_wb_bus.alu_rob_id;
        wb_bus.rd_alu         = exe_to_wb_bus.rd_phy_alu;
        wb_bus.alu_result     = exe_to_wb_bus.alu_result;
        // store
        wb_bus.store_valid    = (flush) ? 1'b0 : (exe_to_wb_bus.store_valid);
        wb_bus.store_rob_id   = exe_to_wb_bus.store_rob_id;
        wb_bus.store_id       = store_id;
        // branch
        wb_bus.branch_valid   = (flush) ? 1'b0 : exe_to_wb_bus.branch_valid;
        wb_bus.jump_valid     = (flush) ? 1'b0 : exe_to_wb_bus.isJump;
        wb_bus.branch_rob_id  = exe_to_wb_bus.branch_rob_id;
        wb_bus.rd_branch      = exe_to_wb_bus.rd_phy_branch;
        wb_bus.nextPC         = exe_to_wb_bus.nextPC;
        wb_bus.mispredict     = exe_to_wb_bus.mispredict;
        wb_bus.actual_target  = exe_to_wb_bus.actual_target;
        wb_bus.actual_taken   = exe_to_wb_bus.actual_taken;
        wb_bus.update_pc      = exe_to_wb_bus.update_pc;
    end

endmodule

