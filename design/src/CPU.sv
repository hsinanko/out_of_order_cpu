`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;
import instruction_pkg::*;
import info_pkg::*;

module CPU #(parameter ADDR_WIDTH = 32, 
                           DATA_WIDTH = 32,
                           ARCH_REGS = 32,
                           PHY_REGS = 64, 
                           PHY_WIDTH = $clog2(PHY_REGS),  
                           NUM_ROB_ENTRY = 32,
                           ROB_WIDTH = $clog2(NUM_ROB_ENTRY),
                           NUM_RS_ENTRIES = 8,
                           BTB_ENTRIES = 16,
                           BTB_WIDTH = $clog2(BTB_ENTRIES),
                           FIFO_DEPTH = 16)
(
    input logic clk,
    input logic rst,
    input logic [ADDR_WIDTH-1:0] boot_pc,
    output logic done,
    // === Debugging Interface ==================
    output Debug_t debug_info
);

    // ============= Flush Logic ===================
    logic flush;
    logic isFlush;
    logic [ADDR_WIDTH-1:0] redirect_pc;
    logic [ADDR_WIDTH-1:0] target_pc;
    assign isFlush = retire_bus_0_reg.isFlush || retire_bus_1_reg.isFlush;
    assign target_pc = (retire_bus_0_reg.isFlush) ? retire_bus_0_reg.targetPC : retire_bus_1_reg.targetPC;
    

    // ============= Instruction Fetch ===================

    logic [ADDR_WIDTH-1:0]pc;
    logic pc_valid;

    fetch_t instruction_0, instruction_1;
    fetch_t instruction_0_reg, instruction_1_reg;

    predict_t predict_0, predict_1;
    predict_t predict_0_reg, predict_1_reg;

    // ============= Decode / Rename Stage ==============
    rename_if #( ARCH_REGS, PHY_WIDTH) rename_0();
    rename_if #( ARCH_REGS, PHY_WIDTH) rename_1();

    // Dispatch signals produced by DecodeRename
    ROB_ENTRY_t rob_entry_0;
    ROB_ENTRY_t rob_entry_1;
    logic [ROB_WIDTH-1:0] rob_id_0, rob_id_1;

    logic [1:0] busy_valid;
    logic [PHY_REGS-1:0] rd_phy_busy_0, rd_phy_busy_1;

    RS_ENTRY_t issue_instruction_alu, issue_instruction_ls, issue_instruction_branch;

    RS_ENTRY_t issue_instruction_alu_reg, issue_instruction_ls_reg, issue_instruction_branch_reg;

    // ============ Issue / Execution Stage ==================
    EXE_alu_t exe_alu, exe_alu_reg;
    EXE_lsu_t exe_lsu, exe_lsu_reg;
    EXE_branch_t exe_branch, exe_branch_reg;
        
    // ============= Write Back Stage ==================
    WB_alu_t wb_alu, wb_alu_reg;
    WB_store_t wb_store, wb_store_reg;
    WB_load_t  wb_load, wb_load_reg;
    WB_branch_t wb_branch, wb_branch_reg;

    // ============= Physical Register File ==================
    logic [PHY_REGS-1:0]PRF_busy;
    logic [PHY_REGS-1:0]PRF_valid;

    physical_if #(DATA_WIDTH, PHY_WIDTH) alu_prf_bus();
    physical_if #(DATA_WIDTH, PHY_WIDTH) lsu_prf_bus();
    physical_if #(DATA_WIDTH, PHY_WIDTH) branch_prf_bus();

    // ============ Back RAT ==================
    logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat;
    // ============= Control Unit ==================
    logic stall;
    // ================== Data Memory Interface (in the Unified Memory) ==================
    // memory port
    logic mem_rd_en;
    logic [ADDR_WIDTH-1:0] mem_raddr;
    logic [DATA_WIDTH-1:0] mem_rdata;
    logic mem_rdata_valid;
    logic mem_write_en;
    logic [ADDR_WIDTH-1:0] mem_waddr;
    logic [DATA_WIDTH-1:0] mem_wdata;
    // ============ Reorder Buffer ==================
    rob_status_if #(NUM_ROB_ENTRY, ROB_WIDTH)rob_status ();
    // ============= Retire Stage ==================
    
    retire_if #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH)retire_bus_0();
    retire_if #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH)retire_bus_1();
    retire_if #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH)retire_bus_0_reg();
    retire_if #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH)retire_bus_1_reg();
    
    logic store_full, store_empty;
    RETIRE_STORE_t retire_store;

    logic done_valid;
    assign done_valid = retire_bus_0_reg.retire_done_valid || retire_bus_1_reg.retire_done_valid;
    
    //============ Free List ==================
    logic free_list_full, free_list_empty;

    //============== Control Unit ==================
    Control #(ADDR_WIDTH) Control_Unit(
        .clk(clk),
        .rst(rst),
        .isFlush(isFlush),
        .target_pc(target_pc),
        .store_empty(store_empty),   
        .flush(flush),
        .redirect_pc(redirect_pc),
        .rob_full(rob_status.rob_full),
        .rob_empty(rob_status.rob_empty),
        .pc_valid(pc_valid),
        .free_list_full(free_list_full),
        .free_list_empty(free_list_empty),
        .stall(stall),
        .done_valid(done_valid),
        .done(done)
    );
    //============== Unified Instruction/Data Memory ==================
    
    Memory #(INSTR_ADDRESS, DATA_ADDRESS, INSTR_MEM_SIZE, DATA_MEM_SIZE, ADDR_WIDTH, DATA_WIDTH) UnifiedMemory(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .predict_0(predict_0),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .mem_write_en(mem_write_en),
        .waddr(mem_waddr),
        .wdata(mem_wdata),
        .mem_rd_en(mem_rd_en),
        .raddr(mem_raddr),
        .rdata(mem_rdata),
        .rdata_valid(mem_rdata_valid)
    );

    BTB #(ADDR_WIDTH, BTB_ENTRIES, BTB_WIDTH) BTB_unit(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .pc_valid(pc_valid),
        .predict_0(predict_0),
        .predict_1(predict_1),
        .retire_branch_bus_0(retire_bus_0_reg.retire_branch_sink),
        .retire_branch_bus_1(retire_bus_1_reg.retire_branch_sink)
    );

    always_ff @(posedge clk or posedge rst)begin
        if (rst) begin
            pc                     <= boot_pc;
            instruction_0_reg      <= '{0, 0, 0};
            instruction_1_reg      <= '{0, 0, 0};
            predict_0_reg          <= '{0, 0};
            predict_1_reg          <= '{0, 0};
        end
        else if(flush)begin
            pc                     <= redirect_pc;
            instruction_0_reg      <= '{0, 0, 0};
            instruction_1_reg      <= '{0, 0, 0};
            predict_0_reg          <= '{0, 0};
            predict_1_reg          <= '{0, 0};
        end
        else if(stall)begin
            pc                     <= pc;
            instruction_0_reg      <= instruction_0_reg;
            instruction_1_reg      <= instruction_1_reg;
            predict_0_reg          <= predict_0_reg;
            predict_1_reg          <= predict_1_reg;
        end
        else begin
            pc                     <= predict_1.predict_target;
            instruction_0_reg      <= instruction_0;
            instruction_1_reg      <= instruction_1;
            predict_0_reg          <= predict_0;
            predict_1_reg          <= predict_1;
        end
    end


    // ============= Decode / Rename Stage ==============



    Rename #(ADDR_WIDTH, DATA_WIDTH, ARCH_REGS, PHY_REGS, NUM_RS_ENTRIES, ROB_WIDTH, PHY_WIDTH) Rename_Unit (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .PRF_valid(PRF_valid),
        .stall_dispatch(stall),
        //======== Instruction Fetch =============================
        .instruction_0(instruction_0_reg),
        .instruction_1(instruction_1_reg),
        .predict_0(predict_0_reg),
        .predict_1(predict_1_reg),
        //======== Front RAT =============================
        .rat_0_bus(rename_0.rat_source),
        .rat_1_bus(rename_1.rat_source),
        //======== Free List =================
        .freelist_0_bus(rename_0.freelist_source),
        .freelist_1_bus(rename_1.freelist_source),
        //======== Reorder Buffer =================
        .rob_entry_0(rob_entry_0),
        .rob_id_0(rob_id_0),
        .rob_entry_1(rob_entry_1),
        .rob_id_1(rob_id_1),
        // ======= Physical Register File =================
        .busy_valid(busy_valid),
        .rd_phy_busy_0(rd_phy_busy_0),
        .rd_phy_busy_1(rd_phy_busy_1),
        //====== DecodeRename to ReservationStation====
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .busy_alu(busy_alu),
        .busy_lsu(busy_lsu),
        .busy_branch(busy_branch)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            issue_instruction_alu_reg    <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_instruction_ls_reg     <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_instruction_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        end
        else if(flush)begin
            issue_instruction_alu_reg    <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_instruction_ls_reg     <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_instruction_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        end
        else begin
            issue_instruction_alu_reg    <= issue_instruction_alu;
            issue_instruction_ls_reg     <= issue_instruction_ls;
            issue_instruction_branch_reg <= issue_instruction_branch;
        end
    end

    // ============= Issue / Execution Stage ==================


    Issue #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH) Issue_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // from dispatch
        .issue_instruction_alu(issue_instruction_alu_reg),
        .issue_instruction_ls(issue_instruction_ls_reg),
        .issue_instruction_branch(issue_instruction_branch_reg),
        // to execution
        .alu_prf_bus(alu_prf_bus.source),
        .lsu_prf_bus(lsu_prf_bus.source),
        .branch_prf_bus(branch_prf_bus.source),
        // output to commit stage
        .exe_alu(exe_alu),
        .exe_lsu(exe_lsu),
        .exe_branch(exe_branch)
    );



    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            exe_alu_reg <= '{0, 0, 0, 0, 0};
            exe_lsu_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            exe_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
        end
        else if(flush)begin
            exe_alu_reg <= '{0, 0, 0, 0, 0};
            exe_lsu_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            exe_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

        end
        else begin
            // alu outputs
            exe_alu_reg <= exe_alu;
            // lsu outputs
            exe_lsu_reg <= exe_lsu;
            // branch outputs
            exe_branch_reg <= exe_branch;
        end
        
    end

    LoadStoreQueue #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) LSQ (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // Load & Store inputs
        .exe_lsu(exe_lsu),
        // writeback outputs
        .wb_store(wb_store),
        .wb_load(wb_load),
        // ========= Memory Interface =================
        // load
        .mem_raddr(mem_raddr),
        .mem_rd_en(mem_rd_en),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        // ========= retire interface ==============
        .retire_store(retire_store),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );

    // ============= WriteBack Stage ==================

    WriteBack #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH, FIFO_DEPTH) WriteBack_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // ============== from Execution (enqueue candidates) =================
        .exe_alu(exe_alu_reg),
        .exe_branch(exe_branch_reg),
        // ========== Physical Register & ROB Commit Interface  ===========
        .wb_alu(wb_alu),
        .wb_branch(wb_branch)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst)begin
            wb_alu_reg    <= '{0, 0, 0, 0};
            wb_store_reg  <= '{0, 0, 0};
            wb_load_reg   <= '{0, 0, 0, 0};
            wb_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0};
        end
        else if(flush)begin
            wb_alu_reg    <= '{0, 0, 0, 0};
            wb_store_reg  <= '{0, 0, 0};
            wb_load_reg   <= '{0, 0, 0, 0};
            wb_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0};
        end
        else begin
            wb_alu_reg    <= wb_alu;
            wb_store_reg  <= wb_store;
            wb_load_reg   <= wb_load;
            wb_branch_reg <= wb_branch;
        end
    end


    // ============= Retire Stage ==================

    Retire #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH) Retire_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .rob_status(rob_status.sink),
        .retire_bus_0(retire_bus_0.retire_source),
        .retire_bus_1(retire_bus_1.retire_source)
    );

    
    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            // retire bus 0
            retire_bus_0_reg.isFlush             <= 1'b0;
            retire_bus_0_reg.targetPC            <= 'h0;
            retire_bus_0_reg.retire_pr_pkg       <= '{0, 0, 0, 0};
            retire_bus_0_reg.retire_store_pkg    <= '{0, 0};
            retire_bus_0_reg.retire_branch_pkg   <= '{0, 0, 0, 0};
            retire_bus_0_reg.retire_done_valid   <= 1'b0;
            retire_bus_0_reg.rob_debug           <= 'h0;
            retire_bus_0_reg.retire_addr         <= 'h0;
            // retire bus 1
            retire_bus_1_reg.isFlush             <= 1'b0;
            retire_bus_1_reg.targetPC            <= 'h0;
            retire_bus_1_reg.retire_pr_pkg       <= '{0, 0, 0, 0};
            retire_bus_1_reg.retire_store_pkg    <= '{0, 0};
            retire_bus_1_reg.retire_branch_pkg   <= '{0, 0, 0, 0};
            retire_bus_1_reg.retire_done_valid   <= 1'b0;
            retire_bus_1_reg.rob_debug           <= 'h0;
            retire_bus_1_reg.retire_addr         <= 'h0;
        end
        else if(flush)begin
            // retire bus 0
            retire_bus_0_reg.isFlush             <= 1'b0;
            retire_bus_0_reg.targetPC            <= 'h0;
            retire_bus_0_reg.retire_pr_pkg       <= '{0, 0, 0, 0};
            retire_bus_0_reg.retire_store_pkg    <= '{0, 0};
            retire_bus_0_reg.retire_branch_pkg   <= '{0, 0, 0, 0};
            retire_bus_0_reg.retire_done_valid   <= 1'b0;
            retire_bus_0_reg.rob_debug           <= 'h0;
            retire_bus_0_reg.retire_addr         <= 'h0;
            // retire bus 1
            retire_bus_1_reg.isFlush             <= 1'b0;
            retire_bus_1_reg.targetPC            <= 'h0;
            retire_bus_1_reg.retire_pr_pkg       <= '{0, 0, 0, 0};
            retire_bus_1_reg.retire_store_pkg    <= '{0, 0};
            retire_bus_1_reg.retire_branch_pkg   <= '{0, 0, 0, 0};
            retire_bus_1_reg.retire_done_valid   <= 1'b0;
            retire_bus_1_reg.rob_debug           <= 'h0;
            retire_bus_1_reg.retire_addr         <= 'h0;
        end
        else begin
            // retire bus 0
            retire_bus_0_reg.isFlush             <= retire_bus_0.isFlush;
            retire_bus_0_reg.targetPC            <= retire_bus_0.targetPC;
            retire_bus_0_reg.retire_pr_pkg       <= retire_bus_0.retire_pr_pkg;
            retire_bus_0_reg.retire_store_pkg    <= retire_bus_0.retire_store_pkg;
            retire_bus_0_reg.retire_branch_pkg   <= retire_bus_0.retire_branch_pkg;
            retire_bus_0_reg.retire_done_valid   <= retire_bus_0.retire_done_valid;
            retire_bus_0_reg.rob_debug           <= retire_bus_0.rob_debug;
            retire_bus_0_reg.retire_addr         <= retire_bus_0.retire_addr;
            // retire bus 1
            retire_bus_1_reg.isFlush             <= retire_bus_1.isFlush;
            retire_bus_1_reg.targetPC            <= retire_bus_1.targetPC;
            retire_bus_1_reg.retire_pr_pkg       <= retire_bus_1.retire_pr_pkg;
            retire_bus_1_reg.retire_store_pkg    <= retire_bus_1.retire_store_pkg;
            retire_bus_1_reg.retire_branch_pkg   <= retire_bus_1.retire_branch_pkg;
            retire_bus_1_reg.retire_done_valid   <= retire_bus_1.retire_done_valid;
            retire_bus_1_reg.rob_debug           <= retire_bus_1.rob_debug;
            retire_bus_1_reg.retire_addr         <= retire_bus_1.retire_addr;
        end
    end



    // ============= Common ==================
    Front_RAT #(ARCH_REGS, PHY_WIDTH) front_rat (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(done),
        .rat_0_bus(rename_0.rat_sink),
        .rat_1_bus(rename_1.rat_sink),
        .freelist_0_bus(rename_0.freelist_sink),
        .freelist_1_bus(rename_1.freelist_sink),
        // BACK_RAT will handle commit updates
        .back_rat(back_rat),
        .front_rat_out(debug_info.front_rat_out)
    );

    Freelist #(ARCH_REGS, PHY_REGS, PHY_WIDTH, FREE_REG) free_list(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .full(free_list_full),
        .empty(free_list_empty),
        .done(done),
        // rename interface to allocate physical registers
        .freelist_0_bus(rename_0.freelist_sink),
        .freelist_1_bus(rename_1.freelist_sink),
        // retire
        // commit interface to free physical registers
        .retire_pr_bus_0(retire_bus_0_reg.retire_pr_sink),
        .retire_pr_bus_1(retire_bus_1_reg.retire_pr_sink)
    );

    logic [ROB_WIDTH-1:0] rob_debug;
    logic [ROB_WIDTH-1:0] rob_debug_reg;
    ReorderBuffer #(NUM_ROB_ENTRY, ROB_WIDTH, PHY_WIDTH, FIFO_DEPTH) ROB_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .rob_entry_0(rob_entry_0),
        .rob_id_0(rob_id_0),
        .rob_entry_1(rob_entry_1),
        .rob_id_1(rob_id_1),
        .wb_alu(wb_alu_reg),
        .wb_store(wb_store_reg),
        .wb_load(wb_load_reg),
        .wb_branch(wb_branch_reg),
        // outputs to backend/architectural state
        .rob_status(rob_status.source)
    );


    // ============= Store Buffer ==================

    StoreBuffer #(DATA_WIDTH, FIFO_DEPTH) Store_Buffer(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(done),
        .store_full(store_full),
        .store_empty(store_empty),
        .retire_store_0(retire_bus_0_reg.retire_store_pkg),
        .retire_store_1(retire_bus_1_reg.retire_store_pkg),
        .retire_store(retire_store)
    );

    // ============= Back RAT ==================

    Back_RAT #(ARCH_REGS, PHY_WIDTH) Back_RAT_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(done),
        .retire_pr_bus_0(retire_bus_0_reg.retire_pr_sink),
        .retire_pr_bus_1(retire_bus_1_reg.retire_pr_sink),
        .back_rat(back_rat)
    );

    // ============= Physical Register File ==================

    PhysicalRegister #(PHY_REGS, PHY_WIDTH, DATA_WIDTH) PhysicalRegisterFile(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(done),
        .busy_valid(busy_valid),
        .rd_phy_busy_0(rd_phy_busy_0),
        .rd_phy_busy_1(rd_phy_busy_1),
        .PRF_busy(PRF_busy),
        // ========== read execution interface ===========
        .PRF_valid(PRF_valid),
        .alu_prf_bus(alu_prf_bus.sink),
        .lsu_prf_bus(lsu_prf_bus.sink),
        .branch_prf_bus(branch_prf_bus.sink),
        // =========== writeback interface =================
        .wb_alu(wb_alu_reg),
        .wb_load(wb_load_reg),
        .wb_branch(wb_branch_reg),
        // from retire stage
        // =========== commit interface =================
        .retire_pr_bus_0(retire_bus_0_reg.retire_pr_sink),
        .retire_pr_bus_1(retire_bus_1_reg.retire_pr_sink),
        // ===========
        // outputs for debug
        .PRF_data_out(debug_info.PRF_data_out),
        .PRF_busy_out(debug_info.PRF_busy_out),
        .PRF_valid_out(debug_info.PRF_valid_out)
    );


    // ============= Debugging ==================
    logic [ROB_WIDTH-1:0] retire_count;

    RETIRE_BRANCH_t retire_branch_0_debug, retire_branch_1_debug;
    RETIRE_PR_t retire_pr_0_debug, retire_pr_1_debug;
    RETIRE_STORE_t retire_store_0_debug, retire_store_1_debug;
    assign retire_branch_0_debug = retire_bus_0_reg.retire_branch_sink.retire_branch_pkg;
    assign retire_pr_0_debug     = retire_bus_0_reg.retire_pr_sink.retire_pr_pkg;
    assign retire_store_0_debug  = retire_bus_0_reg.retire_store_sink.retire_store_pkg;

    assign retire_branch_1_debug = retire_bus_1_reg.retire_branch_sink.retire_branch_pkg;
    assign retire_pr_1_debug     = retire_bus_1_reg.retire_pr_sink.retire_pr_pkg;
    assign retire_store_1_debug  = retire_bus_1_reg.retire_store_sink.retire_store_pkg; 

    assign debug_info.back_rat_out = back_rat;
    assign debug_info.retire_addr_0_reg  = (flush) ? 'hx : retire_bus_0_reg.retire_addr;
    assign debug_info.retire_valid_0_reg = (flush) ? 1'b0 : (retire_pr_0_debug.retire_pr_valid || retire_store_0_debug.retire_store_valid || retire_branch_0_debug.retire_branch_valid || retire_bus_0_reg.retire_done_valid);
    assign debug_info.retire_addr_1_reg  = (flush) ? 'h0 : retire_bus_1_reg.retire_addr;
    assign debug_info.retire_valid_1_reg = (flush) ? 1'b0 : (retire_pr_1_debug.retire_pr_valid || retire_store_1_debug.retire_store_valid || retire_branch_1_debug.retire_branch_valid || retire_bus_1_reg.retire_done_valid);
    assign debug_info.retire_count = retire_count;

    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            retire_count <= '0;
        end
        else if(flush) begin
            retire_count <= 0;
        end
        else if (debug_info.retire_valid_0_reg && debug_info.retire_valid_1_reg) begin
            retire_count <= retire_count + 2;
        end
        else if (debug_info.retire_valid_0_reg || debug_info.retire_valid_1_reg) begin
            retire_count <= retire_count + 1;
        end
    end

    // ============= Debug Tasks ==================

    // always_ff @(posedge clk) begin
    //     if(rst) 
    //         $display("\n\n\t============ Resetting CPU ============\n\n");
    //     else if(flush) begin
    //         $display("\n\n\t============ Flush Triggered ============\n\n");
    //     end
    //     else begin
    //         // print debug information at each stage
    //         $display("*************************** Cycle %0d *************************", $time/10);
    //         print_Fetch(instruction_valid_reg, instruction_addr_0_reg, instruction_0_reg, instruction_addr_1_reg, instruction_1_reg);
    //         print_Rename(instruction_valid_reg, instruction_addr_0_reg, instruction_0_reg, instruction_addr_1_reg, instruction_1_reg,
    //                      issue_alu_valid_reg, issue_instruction_alu_reg,
    //                      issue_ls_valid_reg, issue_instruction_ls_reg,
    //                      issue_branch_valid_reg, issue_instruction_branch_reg);
    //         // print_Execution(alu_valid, ls_valid, branch_valid,
    //         //                 alu_rob_id, alu_output,
    //         //                 ls_rob_id, wdata_valid, waddr, wdata, rd_phy_ls, mem_rdata,
    //         //                 branch_rob_id, nextPC);
    //         print_Commit(retire_pr_valid_reg, retire_store_valid_reg, retire_branch_valid_reg,
    //                      rd_arch_commit_reg, rd_phy_old_commit_reg, rd_phy_new_commit_reg);
    //         $display("**************************** END *****************************\n");
    //     end
    // end
endmodule
