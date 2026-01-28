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
    output logic [ADDR_WIDTH-1:0] retire_addr_reg,
    output logic retire_valid_reg,
    output logic [PHY_REGS*DATA_WIDTH-1:0]PRF_data_out,
    output logic [PHY_REGS-1:0]PRF_busy_out,
    output logic [PHY_REGS-1:0]PRF_valid_out,
    output logic [PHY_WIDTH*ARCH_REGS-1:0]front_rat_out,
    output logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat_out
);

    // ============= Flush Logic ===================
    logic flush;
    logic isFlush;
    logic [ADDR_WIDTH-1:0] redirect_pc;

    assign isFlush = retire_bus.isFlush;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            flush <= 1'b0;
        end
        else if(isFlush)begin
            flush <= 1'b1;
            redirect_pc <= retire_bus.targetPC;
        end
        else begin
            flush <= 1'b0;
            redirect_pc <= 'h0;
        end
    end

    
    always_ff @(posedge clk or posedge rst)begin
        if(rst)
            done <= 1'b0;
        else if(done_valid && !flush)
            done <= 1'b1;
        else
            done <= done;
    end
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
    execution_if #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH)exe_bus();
    execution_if #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH)exe_bus_reg();
        
    // ============= Write Back Stage ==================
    writeback_if #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH, FIFO_DEPTH)wb_bus();
    writeback_if #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH, FIFO_DEPTH)wb_bus_reg();

    // ============= Physical Register File ==================
    logic [PHY_REGS-1:0]PRF_busy;
    logic [PHY_REGS-1:0]PRF_valid;

    physical_if #(DATA_WIDTH, PHY_WIDTH) alu_prf_bus();
    physical_if #(DATA_WIDTH, PHY_WIDTH) lsu_prf_bus();
    physical_if #(DATA_WIDTH, PHY_WIDTH) branch_prf_bus();

    // ============ Back RAT ==================
    logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat;
    // ============= Control Unit ==================
    logic stall_fetch;
    logic stall_dispatch;
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
    logic rob_full, rob_empty;
    logic [NUM_ROB_ENTRY-1:0]       ROB_FINISH;
    ROB_ENTRY_t ROB[NUM_ROB_ENTRY-1:0];
    logic [ROB_WIDTH-1:0] rob_head;
    // ============= Retire Stage ==================
    logic done_valid;
    retire_if #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH)retire_bus();
    retire_if #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH)retire_bus_reg();
    
    assign done_valid = retire_bus_reg.retire_done_valid;

    //============ Free List ==================
    logic free_list_full, free_list_empty;
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
        .retire_branch_bus(retire_bus_reg.retire_branch_sink)
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
        else if(stall_fetch)begin
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
        .stall_dispatch(stall_dispatch),
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
        .exe_bus(exe_bus)
    );



    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            // alu outputs
            exe_bus_reg.alu_rob_id <= 0;
            exe_bus_reg.alu_result <= 0;
            exe_bus_reg.rd_phy_alu <= 0;
            // Load/Store outputs
            exe_bus_reg.store_waddr <= 0;
            exe_bus_reg.store_wdata <= 0;
            exe_bus_reg.store_rob_id <= 0;
            exe_bus_reg.store_valid  <= 0;
            exe_bus_reg.load_funct3  <= 0;
            exe_bus_reg.load_valid   <= 0;
            exe_bus_reg.load_raddr   <= 0;
            exe_bus_reg.load_rob_id  <= 0;
            exe_bus_reg.load_rd_phy  <= 0;
            // Branch outputs
            exe_bus_reg.branch_rob_id <= 0;
            exe_bus_reg.actual_taken  <= 0;
            exe_bus_reg.actual_target <= 0;
            exe_bus_reg.nextPC        <= 0;
            exe_bus_reg.update_pc     <= 0;
            exe_bus_reg.rd_phy_branch <= 0;
            exe_bus_reg.isJump        <= 0;
            exe_bus_reg.mispredict    <= 0;
        end
        // else if(flush)begin
        //     // alu outputs
        //     exe_bus_reg.alu_rob_id <= 0;
        //     exe_bus_reg.alu_result <= 0;
        //     exe_bus_reg.rd_phy_alu <= 0;
        //     // Load/Store outputs
        //     exe_bus_reg.store_waddr <= 0;
        //     exe_bus_reg.store_wdata <= 0;
        //     exe_bus_reg.store_rob_id <= 0;
        //     exe_bus_reg.store_valid  <= 0;
        //     exe_bus_reg.load_funct3  <= 0;
        //     exe_bus_reg.load_valid   <= 0;
        //     exe_bus_reg.load_raddr   <= 0;
        //     exe_bus_reg.load_rob_id  <= 0;
        //     exe_bus_reg.load_rd_phy  <= 0;
        //     // Branch outputs
        //     exe_bus_reg.branch_rob_id <= 0;
        //     exe_bus_reg.actual_taken  <= 0;
        //     exe_bus_reg.actual_target <= 0;
        //     exe_bus_reg.nextPC        <= 0;
        //     exe_bus_reg.update_pc     <= 0;
        //     exe_bus_reg.rd_phy_branch <= 0;
        //     exe_bus_reg.isJump        <= 0;
        //     exe_bus_reg.mispredict    <= 0;
        // end
        else begin
            // alu outputs
            exe_bus_reg.alu_rob_id   <= exe_bus.alu_rob_id;
            exe_bus_reg.alu_result   <= exe_bus.alu_result;
            exe_bus_reg.rd_phy_alu   <= exe_bus.rd_phy_alu;
            exe_bus_reg.alu_valid    <= exe_bus.alu_valid;
            // Store outputs
            exe_bus_reg.store_waddr  <= exe_bus.store_waddr;
            exe_bus_reg.store_wdata  <= exe_bus.store_wdata;
            exe_bus_reg.store_rob_id <= exe_bus.store_rob_id;
            exe_bus_reg.store_valid  <= exe_bus.store_valid;

            // Load outputs
            exe_bus_reg.load_funct3  <= exe_bus.load_funct3;
            exe_bus_reg.load_raddr   <= exe_bus.load_raddr;
            exe_bus_reg.load_rob_id  <= exe_bus.load_rob_id;
            exe_bus_reg.load_rd_phy  <= exe_bus.load_rd_phy;
            exe_bus_reg.load_valid   <= exe_bus.load_valid;
            // Branch outputs
            exe_bus_reg.branch_valid  <= exe_bus.branch_valid;
            exe_bus_reg.branch_rob_id <= exe_bus.branch_rob_id;
            exe_bus_reg.actual_taken  <= exe_bus.actual_taken;
            exe_bus_reg.mispredict    <= exe_bus.mispredict;
            exe_bus_reg.actual_target <= exe_bus.actual_target;
            exe_bus_reg.update_pc     <= exe_bus.update_pc;
            exe_bus_reg.nextPC        <= exe_bus.nextPC;
            exe_bus_reg.rd_phy_branch <= exe_bus.rd_phy_branch;
            exe_bus_reg.isJump        <= exe_bus.isJump;

        end  
        
    end

    // ============= Commit Stage ==================

    WriteBack #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH, FIFO_DEPTH) WriteBack_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // ============== from Execution (enqueue candidates) =================
        .exe_to_wb_bus(exe_bus_reg),
        // ========== Physical Register & ROB Commit Interface  ===========
        .wb_bus(wb_bus),
        // ========== Retire Interface ===========
        // Memory Interface
        .mem_rd_en(mem_rd_en),
        .mem_raddr(mem_raddr),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        // Retire Interface
        .retire_store_bus(retire_bus_reg.retire_store_sink),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst)begin
            wb_bus_reg.alu_valid    <= 1'b0;
            wb_bus_reg.alu_rob_id   <= 'h0;
            wb_bus_reg.rd_alu       <= 'h0;
            wb_bus_reg.alu_result   <= 'h0;
            wb_bus_reg.load_valid   <= 1'b0;
            wb_bus_reg.load_rob_id  <= 'h0;
            wb_bus_reg.rd_load      <= 'h0;
            wb_bus_reg.load_rdata   <= 'h0;
            wb_bus_reg.store_valid  <= 'h0;
            wb_bus_reg.store_rob_id <= 'h0;
            wb_bus_reg.store_id     <= 'h0;
            wb_bus_reg.branch_valid <= 'h0;
            wb_bus_reg.jump_valid   <= 'h0;
            wb_bus_reg.branch_rob_id<= 'h0;
            wb_bus_reg.rd_branch    <= 'h0;
            wb_bus_reg.nextPC       <= 'h0;
            wb_bus_reg.mispredict   <= 'h0;
            wb_bus_reg.actual_target<= 'h0;
            wb_bus_reg.actual_taken <= 'h0;
            wb_bus_reg.update_pc    <= 'h0;
        end
        else if(flush)begin
            wb_bus_reg.alu_valid    <= 1'b0;
            wb_bus_reg.alu_rob_id   <= 'h0;
            wb_bus_reg.rd_alu       <= 'h0;
            wb_bus_reg.alu_result   <= 'h0;
            wb_bus_reg.load_valid   <= 1'b0;
            wb_bus_reg.load_rob_id  <= 'h0;
            wb_bus_reg.rd_load      <= 'h0;
            wb_bus_reg.load_rdata   <= 'h0;
            wb_bus_reg.store_valid  <= 'h0;
            wb_bus_reg.store_rob_id <= 'h0;
            wb_bus_reg.store_id     <= 'h0;
            wb_bus_reg.branch_valid <= 'h0;
            wb_bus_reg.jump_valid   <= 'h0;
            wb_bus_reg.branch_rob_id<= 'h0;
            wb_bus_reg.rd_branch    <= 'h0;
            wb_bus_reg.nextPC       <= 'h0;
            wb_bus_reg.mispredict   <= 'h0;
            wb_bus_reg.actual_target<= 'h0;
            wb_bus_reg.actual_taken <= 'h0;
            wb_bus_reg.update_pc    <= 'h0;
        end
        else begin
            wb_bus_reg.alu_valid    <= wb_bus.alu_valid;
            wb_bus_reg.alu_rob_id   <= wb_bus.alu_rob_id;
            wb_bus_reg.rd_alu       <= wb_bus.rd_alu;
            wb_bus_reg.alu_result   <= wb_bus.alu_result;
            wb_bus_reg.load_valid   <= wb_bus.load_valid;
            wb_bus_reg.load_rob_id  <= wb_bus.load_rob_id;
            wb_bus_reg.rd_load      <= wb_bus.rd_load;
            wb_bus_reg.load_rdata   <= wb_bus.load_rdata;
            wb_bus_reg.store_valid  <= wb_bus.store_valid;
            wb_bus_reg.store_rob_id <= wb_bus.store_rob_id;
            wb_bus_reg.store_id     <= wb_bus.store_id;
            wb_bus_reg.branch_valid <= wb_bus.branch_valid;
            wb_bus_reg.jump_valid   <= wb_bus.jump_valid;
            wb_bus_reg.branch_rob_id<= wb_bus.branch_rob_id;
            wb_bus_reg.rd_branch    <= wb_bus.rd_branch;
            wb_bus_reg.nextPC       <= wb_bus.nextPC;
            wb_bus_reg.mispredict   <= wb_bus.mispredict;
            wb_bus_reg.actual_target<= wb_bus.actual_target;
            wb_bus_reg.actual_taken <= wb_bus.actual_taken;
            wb_bus_reg.update_pc    <= wb_bus.update_pc;
        end
    end


    // ============= Common ==================
    Front_RAT #(ARCH_REGS, PHY_WIDTH) front_rat (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(done_valid),
        .rat_0_bus(rename_0.rat_sink),
        .rat_1_bus(rename_1.rat_sink),
        .freelist_0_bus(rename_0.freelist_sink),
        .freelist_1_bus(rename_1.freelist_sink),
        // BACK_RAT will handle commit updates
        .back_rat(back_rat),
        .front_rat_out(front_rat_out)
    );

    Freelist #(ARCH_REGS, PHY_REGS, PHY_WIDTH, FREE_REG) free_list(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .full(free_list_full),
        .empty(free_list_empty),
        .done(done_valid),
        // rename interface to allocate physical registers
        .freelist_0_bus(rename_0.freelist_sink),
        .freelist_1_bus(rename_1.freelist_sink),
        // retire
        // commit interface to free physical registers
        .retire_pr_bus(retire_bus_reg.retire_pr_sink)
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
        .wb_to_rob_bus(wb_bus_reg.sink),
        // outputs to backend/architectural state
        .rob_finish(ROB_FINISH),
        .rob(ROB),
        .rob_head(rob_head),
        .rob_full(rob_full),
        .rob_empty(rob_empty)
    );

    Retire #(ADDR_WIDTH, DATA_WIDTH, NUM_ROB_ENTRY, FIFO_DEPTH) Retire_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .ROB_FINISH(ROB_FINISH),
        .ROB(ROB),
        .rob_head(rob_head),
        .retire_bus(retire_bus.retire_source)
    );

    
    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            retire_bus_reg.isFlush             <= 1'b0;
            retire_bus_reg.targetPC            <= 'h0;
            retire_bus_reg.rd_arch             <= 'h0;
            retire_bus_reg.rd_phy_old          <= 'h0;
            retire_bus_reg.rd_phy_new          <= 'h0;
            retire_bus_reg.update_btb_pc       <= 'h0;
            retire_bus_reg.update_btb_taken    <= 1'b0;
            retire_bus_reg.update_btb_target   <= 'h0;
            retire_bus_reg.retire_pr_valid     <= 1'b0;
            retire_bus_reg.retire_store_valid  <= 1'b0;
            retire_bus_reg.retire_store_id     <= 'h0;
            retire_bus_reg.retire_branch_valid <= 1'b0;
            retire_bus_reg.retire_done_valid   <= 1'b0;
            retire_bus_reg.rob_debug           <= 'h0;
            retire_bus_reg.retire_addr         <= 'h0;
        end
        else if(flush)begin
            retire_bus_reg.isFlush             <= 1'b0;
            retire_bus_reg.targetPC            <= 'h0;
            retire_bus_reg.rd_arch             <= 'h0;
            retire_bus_reg.rd_phy_old          <= 'h0;
            retire_bus_reg.rd_phy_new          <= 'h0;
            retire_bus_reg.update_btb_pc       <= 'h0;
            retire_bus_reg.update_btb_taken    <= 1'b0;
            retire_bus_reg.update_btb_target   <= 'h0;
            retire_bus_reg.retire_pr_valid     <= 1'b0;
            retire_bus_reg.retire_store_valid  <= 1'b0;
            retire_bus_reg.retire_store_id     <= 'h0;
            retire_bus_reg.retire_branch_valid <= 1'b0;
            retire_bus_reg.retire_done_valid   <= 1'b0;
            retire_bus_reg.rob_debug           <= 'h0;
            retire_bus_reg.retire_addr         <= 'h0;
        end
        else begin
            retire_bus_reg.isFlush             <= retire_bus.isFlush;
            retire_bus_reg.targetPC            <= retire_bus.targetPC;
            retire_bus_reg.rd_arch             <= retire_bus.rd_arch;
            retire_bus_reg.rd_phy_old          <= retire_bus.rd_phy_old;
            retire_bus_reg.rd_phy_new          <= retire_bus.rd_phy_new;
            retire_bus_reg.update_btb_pc       <= retire_bus.update_btb_pc;
            retire_bus_reg.update_btb_taken    <= retire_bus.update_btb_taken;
            retire_bus_reg.update_btb_target   <= retire_bus.update_btb_target;
            retire_bus_reg.retire_pr_valid     <= retire_bus.retire_pr_valid;
            retire_bus_reg.retire_store_valid  <= retire_bus.retire_store_valid;
            retire_bus_reg.retire_store_id     <= retire_bus.retire_store_id;
            retire_bus_reg.retire_branch_valid <= retire_bus.retire_branch_valid;
            retire_bus_reg.retire_done_valid   <= retire_bus.retire_done_valid;
            retire_bus_reg.rob_debug           <= retire_bus.rob_debug;
            retire_bus_reg.retire_addr         <= retire_bus.retire_addr;
        end
    end

    Back_RAT #(ARCH_REGS, PHY_WIDTH) Back_RAT_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .retire_pr_bus(retire_bus_reg.retire_pr_sink),
        .back_rat(back_rat)
    );

    Control Control_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .rob_full(rob_full),
        .rob_empty(rob_empty),
        .pc_valid(pc_valid),
        .free_list_full(free_list_full),
        .free_list_empty(free_list_empty),
        .stall_fetch(stall_fetch),
        .stall_dispatch(stall_dispatch)
    );

    PhysicalRegister #(PHY_REGS, PHY_WIDTH, DATA_WIDTH) PhysicalRegisterFile(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(done_valid),
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
        .wb_to_prf_bus(wb_bus_reg.sink),
        // from retire stage
        // =========== commit interface =================
        .retire_pr_bus(retire_bus_reg.retire_pr_sink),
        // ===========
        // outputs for debug
        .PRF_data_out(PRF_data_out),
        .PRF_busy_out(PRF_busy_out),
        .PRF_valid_out(PRF_valid_out)
    );


    // ============= Debugging ==================
    assign back_rat_out = back_rat;

    assign retire_addr_reg  = (flush) ? 'h0 : retire_bus_reg.retire_addr;
    assign retire_valid_reg = (flush) ? 1'b0 : (retire_bus_reg.retire_pr_valid || retire_bus_reg.retire_store_valid || retire_bus_reg.retire_branch_valid);
    logic [ROB_WIDTH-1:0] retire_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            retire_count <= '0;
        end
        else if(flush) begin
            retire_count <= 0;
        end
        else if (retire_bus_reg.retire_pr_valid || retire_bus_reg.retire_store_valid || retire_bus_reg.retire_branch_valid) begin
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
