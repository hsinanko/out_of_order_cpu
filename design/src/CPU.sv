`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;
import instruction_pkg::*;
import info_pkg::*;

module O3O_CPU #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, REG_WIDTH = 32, PHY_REGS = 64, PHY_WIDTH = 6, ROB_WIDTH = 5, NUM_RS_ENTRIES = 8)(
    input logic clk,
    input logic rst,
    input logic [ADDR_WIDTH-1:0] boot_pc,
    output logic done,
    // === Debugging Interface ==================
    output logic [PHY_REGS*DATA_WIDTH-1:0]PRF_data_out,
    output logic [PHY_REGS-1:0]PRF_busy_out,
    output logic [PHY_REGS-1:0]PRF_valid_out,
    output logic [PHY_WIDTH*ARCH_REGS-1:0]front_rat_out
);

    // ============= Flush Logic ===================
    logic flush;
    logic isFlush;
    logic [ADDR_WIDTH-1:0] redirect_pc;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            flush <= 1'b0;
        end
        else if(isFlush)begin
            flush <= 1'b1;
            redirect_pc <= update_btb_target_reg;
        end
        else begin
            flush <= 1'b0;
            redirect_pc <= 'h0;
        end
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)
            done <= 1'b0;
        else if(retire_done_valid_reg && !flush)
            done <= 1'b1;
        else
            done <= done;
    end
    // ============= Instruction Fetch ===================

    logic [ADDR_WIDTH-1:0]pc;
    logic pc_valid;

    logic [ADDR_WIDTH-1:0]instruction_addr_0, instruction_addr_1;
    logic [DATA_WIDTH-1:0]instruction_0, instruction_1;
    logic [1:0] instruction_valid;

    logic predict_taken_0;
    logic predict_taken_1;
    logic [ADDR_WIDTH-1:0] predict_target_0;
    logic [ADDR_WIDTH-1:0] predict_target_1;
    logic update_valid;
    logic [ADDR_WIDTH-1:0] update_pc;
    logic update_taken;
    logic [ADDR_WIDTH-1:0] update_target;

    logic [ADDR_WIDTH-1:0]instruction_addr_0_reg, instruction_addr_1_reg;
    logic [DATA_WIDTH-1:0]instruction_0_reg, instruction_1_reg;
    logic [1:0] instruction_valid_reg;
    logic predict_taken_0_reg;
    logic [ADDR_WIDTH-1:0] predict_target_0_reg;

    logic predict_taken_1_reg;
    logic [ADDR_WIDTH-1:0] predict_target_1_reg;

    // ============= Decode / Rename Stage ==============
    logic [PHY_WIDTH-1:0] rd_phy_old_0, rd_phy_old_1;
    logic [4:0] rs1_arch_0, rs2_arch_0, rd_arch_0;
    logic [PHY_WIDTH-1:0] rs1_phy_0, rs2_phy_0;
    logic [PHY_WIDTH-1:0] rd_phy_0;

    logic [PHY_WIDTH-1:0] rd_phy_new_0;
    logic [4:0] rs1_arch_1, rs2_arch_1, rd_arch_1;
    logic [PHY_WIDTH-1:0] rd_phy_new_1;
    logic [PHY_WIDTH-1:0] rs1_phy_1, rs2_phy_1;
    logic [PHY_WIDTH-1:0] rd_phy_1;

    logic [1:0] instr_valid;
    logic [1:0] free_list_valid;
    // Dispatch signals produced by DecodeRename
    logic [1:0] dispatch_valid;
    ROB_ENTRY_t dispatch_rob_0;
    ROB_ENTRY_t dispatch_rob_1;
    logic [ROB_WIDTH-1:0] rob_id_0, rob_id_1;

    logic [1:0] busy_valid;
    logic [PHY_REGS-1:0] rd_phy_busy_0, rd_phy_busy_1;

    RS_ENTRY_t issue_instruction_alu, issue_instruction_ls, issue_instruction_branch;
    logic issue_alu_valid, issue_ls_valid, issue_branch_valid;

    RS_ENTRY_t issue_instruction_alu_reg, issue_instruction_ls_reg, issue_instruction_branch_reg;
    logic issue_alu_valid_reg, issue_ls_valid_reg, issue_branch_valid_reg;

    // ============ Issue / Execution Stage ==================
    logic [ROB_WIDTH-1:0]  alu_rob_id;
    logic [DATA_WIDTH-1:0] alu_output;
    logic [PHY_WIDTH-1:0]  rd_phy_alu;
    logic                  busy_alu;
    logic [ADDR_WIDTH-1:0] store_waddr;
    logic [DATA_WIDTH-1:0] store_wdata;
    logic [ROB_WIDTH-1:0]  store_rob_id;
    logic                  store_valid;
    logic [2:0]            load_funct3;
    logic [ADDR_WIDTH-1:0] load_raddr;
    logic [ROB_WIDTH-1:0]  load_rob_id;
    logic [PHY_WIDTH-1:0]  load_rd_phy;
    logic                  load_valid;
    logic                  busy_lsu;

    logic [ROB_WIDTH-1:0]  branch_rob_id;
    logic                  actual_taken;
    logic [ADDR_WIDTH-1:0] jumpPC;
    logic [ADDR_WIDTH-1:0] nextPC;
    logic [PHY_WIDTH-1:0]  rd_phy_branch;
    logic                  isJump;
    logic                  mispredict;
    logic                  busy_branch;


    logic [ROB_WIDTH-1:0]  alu_rob_id_reg;
    logic [DATA_WIDTH-1:0] alu_output_reg;
    logic [PHY_WIDTH-1:0]  rd_phy_alu_reg;
    logic                  alu_valid_reg;
    // Load/Store outputs
    logic [ADDR_WIDTH-1:0] store_waddr_reg;
    logic [DATA_WIDTH-1:0] store_wdata_reg;
    logic [ROB_WIDTH-1:0]  store_rob_id_reg;
    logic                  store_valid_reg;
    logic [2:0]            load_funct3_reg;
    logic [ADDR_WIDTH-1:0] load_raddr_reg;
    logic [ROB_WIDTH-1:0]  load_rob_id_reg;
    logic [PHY_WIDTH-1:0]  load_rd_phy_reg;
    logic                  load_valid_reg;
    // Branch outputs
    logic [ROB_WIDTH-1:0]  branch_rob_id_reg;
    logic                  actual_taken_reg;
    logic [ADDR_WIDTH-1:0] jumpPC_reg;
    logic [ADDR_WIDTH-1:0] update_pc_reg;
    logic [ADDR_WIDTH-1:0] nextPC_reg;
    logic [PHY_WIDTH-1:0]  rd_phy_branch_reg;
    logic                  isJump_reg;
    logic                  mispredict_reg;
    logic                  branch_valid_reg;


    // ============= Write Back Stage ==================
    logic                  commit_alu_valid;
    logic [ROB_WIDTH-1:0]  commit_alu_rob_id;
    logic [PHY_WIDTH-1:0]  commit_rd_alu;
    logic [DATA_WIDTH-1:0] commit_alu_result;
    // load
    logic                  commit_load_valid;
    logic [ROB_WIDTH-1:0]  commit_load_rob_id;
    logic [PHY_WIDTH-1:0]  commit_rd_load;
    logic [DATA_WIDTH-1:0] commit_load_rdata;
    // store
    logic                  commit_store_valid;
    logic [ROB_WIDTH-1:0]  commit_store_rob_id;
    // branch
    logic                  commit_branch_valid;
    logic                  commit_jump_valid;
    logic [ROB_WIDTH-1:0]  commit_branch_rob_id;
    logic [PHY_WIDTH-1:0]  commit_rd_branch;
    logic [ADDR_WIDTH-1:0] commit_nextPC;
    logic                  commit_mispredict;
    logic [ADDR_WIDTH-1:0] commit_actual_target;
    logic                  commit_actual_taken;
    logic [ADDR_WIDTH-1:0] commit_update_pc;
    // Write Back registers
    logic                  commit_alu_valid_reg;
    logic [ROB_WIDTH-1:0]  commit_alu_rob_id_reg;
    logic [PHY_WIDTH-1:0]  commit_rd_alu_reg;
    logic [DATA_WIDTH-1:0] commit_alu_result_reg;
    logic [1:0]            commit_load_valid_reg;
    logic [ROB_WIDTH-1:0]  commit_load_rob_id_reg;
    logic [PHY_WIDTH-1:0]  commit_rd_load_reg;
    logic [DATA_WIDTH-1:0] commit_load_rdata_reg;
    logic                  commit_store_valid_reg;
    logic [ROB_WIDTH-1:0]  commit_store_rob_id_reg;
    logic                  commit_branch_valid_reg;
    logic                  commit_jump_valid_reg;
    logic [ROB_WIDTH-1:0]  commit_branch_rob_id_reg;
    logic [PHY_WIDTH-1:0]  commit_rd_branch_reg;
    logic [ADDR_WIDTH-1:0] commit_nextPC_reg;
    logic                  commit_mispredict_reg;
    logic [ADDR_WIDTH-1:0] commit_actual_target_reg;
    logic                  commit_actual_taken_reg;
    logic [ADDR_WIDTH-1:0] commit_update_pc_reg;
    // ============= Physical Register File ==================
    logic [PHY_REGS-1:0]PRF_busy;
    logic [PHY_REGS-1:0]PRF_valid;


    logic alu_valid;
    logic ls_valid;
    logic branch_valid;
    logic [PHY_WIDTH-1:0] rs1_phy_alu;
    logic [PHY_WIDTH-1:0] rs2_phy_alu;
    logic [DATA_WIDTH-1:0] rs1_data_alu;
    logic [DATA_WIDTH-1:0] rs2_data_alu;
    logic [PHY_WIDTH-1:0] rs1_phy_ls;
    logic [PHY_WIDTH-1:0] rs2_phy_ls;
    logic [DATA_WIDTH-1:0] rs1_data_ls;
    logic [DATA_WIDTH-1:0] rs2_data_ls;
    logic [PHY_WIDTH-1:0] rs1_phy_branch;
    logic [PHY_WIDTH-1:0] rs2_phy_branch;
    logic [DATA_WIDTH-1:0] rs1_data_branch;
    logic [DATA_WIDTH-1:0] rs2_data_branch;

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
    // ============= Retire Stage ==================

    logic [4:0] rd_arch_commit;
    logic [PHY_REGS-1:0] rd_phy_old_commit;
    logic [PHY_REGS-1:0] rd_phy_new_commit;
    logic [ADDR_WIDTH-1:0] update_btb_pc;
    logic update_btb_taken;
    logic [ADDR_WIDTH-1:0] update_btb_target;
    logic retire_pr_valid;
    logic retire_store_valid;
    logic retire_branch_valid;
    logic retire_done_valid;
    // Retire logic
    logic [4:0] rd_arch_commit_reg;
    logic [PHY_WIDTH-1:0] rd_phy_old_commit_reg;
    logic [PHY_WIDTH-1:0] rd_phy_new_commit_reg;
    logic [ADDR_WIDTH-1:0] update_btb_pc_reg;
    logic update_btb_taken_reg;
    logic [ADDR_WIDTH-1:0] update_btb_target_reg;
    logic retire_pr_valid_reg;
    logic retire_store_valid_reg;
    logic retire_branch_valid_reg;
    logic retire_done_valid_reg;

    //============ Free List ==================
    logic free_list_full, free_list_empty;


    //============== Unified Instruction/Data Memory ==================
    
    Memory #(INSTR_ADDRESS, DATA_ADDRESS, INSTR_MEM_SIZE, DATA_MEM_SIZE, ADDR_WIDTH, DATA_WIDTH) UnifiedMemory(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .predict_taken_0(predict_taken_0),
        .predict_target_0(predict_target_0),
        .instruction_addr_0(instruction_addr_0),
        .instruction_addr_1(instruction_addr_1),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .instruction_valid(instruction_valid),
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
        .predict_taken_0(predict_taken_0),
        .predict_target_0(predict_target_0),
        .predict_taken_1(predict_taken_1),
        .predict_target_1(predict_target_1),
        .update_valid(update_valid),
        .update_btb_pc(update_btb_pc),
        .update_btb_taken(update_btb_taken),
        .update_btb_target(update_btb_target)
    );

    always_ff @(posedge clk or posedge rst)begin
        if (rst) begin
            pc                     <= boot_pc;
            instruction_addr_0_reg <= 0;
            instruction_addr_1_reg <= 4;
            instruction_0_reg      <= '0;
            instruction_1_reg      <= '0;
            predict_taken_0_reg    <= 'h0;
            predict_target_0_reg   <= 'h0;
            predict_taken_1_reg    <= 'h0;
            predict_target_1_reg   <= 'h0;
        end
        else if(flush)begin
            pc                     <= redirect_pc;
            instruction_addr_0_reg <= 'h0;
            instruction_addr_1_reg <= 'h0;
            instruction_0_reg      <= '0;
            instruction_1_reg      <= '0;
            instruction_valid_reg  <= '0;
            predict_taken_0_reg    <= 'h0;
            predict_target_0_reg   <= 'h0;
            predict_taken_1_reg    <= 'h0;
            predict_target_1_reg   <= 'h0;
        end
        else if(stall_fetch)begin
            pc                     <= pc;
            instruction_addr_0_reg <= instruction_addr_0_reg;
            instruction_addr_1_reg <= instruction_addr_1_reg;
            instruction_0_reg      <= instruction_0_reg;
            instruction_1_reg      <= instruction_1_reg;
            instruction_valid_reg  <= instruction_valid_reg;
            predict_taken_0_reg    <= predict_taken_0_reg;
            predict_target_0_reg   <= predict_target_0_reg;
            predict_taken_1_reg    <= predict_taken_1_reg;
            predict_target_1_reg   <= predict_target_1_reg;
        end
        else begin
            pc                     <= predict_target_1;
            instruction_addr_0_reg <= instruction_addr_0;
            instruction_addr_1_reg <= instruction_addr_1;
            instruction_0_reg      <= instruction_0;
            instruction_1_reg      <= instruction_1;
            instruction_valid_reg  <= instruction_valid;
            predict_taken_0_reg    <= predict_taken_0;
            predict_target_0_reg   <= predict_target_0;
            predict_taken_1_reg    <= predict_taken_1;
            predict_target_1_reg   <= predict_target_1;
        end
    end


    // ============= Decode / Rename Stage ==============



    Rename #(ADDR_WIDTH, DATA_WIDTH, REG_WIDTH, ARCH_REGS, PHY_REGS, NUM_RS_ENTRIES, ROB_WIDTH, PHY_WIDTH) Rename_Unit (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .PRF_valid(PRF_valid),
        .stall_dispatch(stall_dispatch),
        //======== Instruction Fetch =============================
        .instruction_valid(instruction_valid_reg),
        .instruction_addr_0(instruction_addr_0_reg),
        .instruction_0(instruction_0_reg),
        .instruction_addr_1(instruction_addr_1_reg),
        .instruction_1(instruction_1_reg),
        .predict_taken_0(predict_taken_0_reg),
        .predict_target_0(predict_target_0_reg),
        .predict_taken_1(predict_taken_1_reg),
        .predict_target_1(predict_target_1_reg),
        //======== Front RAT =============================
        .instr_valid(instr_valid),
        .rs1_arch_0(rs1_arch_0),
        .rs2_arch_0(rs2_arch_0),
        .rd_arch_0(rd_arch_0),
        .rs1_phy_0(rs1_phy_0),
        .rs2_phy_0(rs2_phy_0),
        .rd_phy_0(rd_phy_0),
        .rs1_arch_1(rs1_arch_1),
        .rs2_arch_1(rs2_arch_1),
        .rd_arch_1(rd_arch_1),
        .rs1_phy_1(rs1_phy_1),
        .rs2_phy_1(rs2_phy_1),
        .rd_phy_1(rd_phy_1),
        //======== Free List =================
        .free_list_valid(free_list_valid),
        .rd_phy_new_0(rd_phy_new_0),
        .rd_phy_new_1(rd_phy_new_1),
        //======== Reorder Buffer =================
        .dispatch_valid(dispatch_valid),
        .dispatch_rob_0(dispatch_rob_0),
        .rob_id_0(rob_id_0),
        .dispatch_rob_1(dispatch_rob_1),
        .rob_id_1(rob_id_1),
        // ======= Physical Register File =================
        .busy_valid(busy_valid),
        .rd_phy_busy_0(rd_phy_busy_0),
        .rd_phy_busy_1(rd_phy_busy_1),
        //====== DecodeRename to ReservationStation====
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .issue_alu_valid(issue_alu_valid),
        .issue_ls_valid(issue_ls_valid),
        .issue_branch_valid(issue_branch_valid),
        .busy_alu(busy_alu),
        .busy_lsu(busy_lsu),
        .busy_branch(busy_branch)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            issue_instruction_alu_reg    <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_instruction_ls_reg     <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_instruction_branch_reg <= '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
            issue_alu_valid_reg          <= 1'b0;
            issue_ls_valid_reg           <= 1'b0;
            issue_branch_valid_reg       <= 1'b0;
        end
        else begin
            issue_instruction_alu_reg    <= issue_instruction_alu;
            issue_instruction_ls_reg     <= issue_instruction_ls;
            issue_instruction_branch_reg <= issue_instruction_branch;
            issue_alu_valid_reg          <= issue_alu_valid;
            issue_ls_valid_reg           <= issue_ls_valid;
            issue_branch_valid_reg       <= issue_branch_valid;
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
        .issue_alu_valid(issue_alu_valid_reg),
        .issue_ls_valid(issue_ls_valid_reg),
        .issue_branch_valid(issue_branch_valid_reg),
        // to execution
        .rs1_phy_alu(rs1_phy_alu),               
        .rs2_phy_alu(rs2_phy_alu), 
        .rs1_data_alu(rs1_data_alu),
        .rs2_data_alu(rs2_data_alu),
        .alu_valid(alu_valid),
        .rs1_phy_ls(rs1_phy_ls),               
        .rs2_phy_ls(rs2_phy_ls),
        .rs1_data_ls(rs1_data_ls),
        .rs2_data_ls(rs2_data_ls),
        .ls_valid(ls_valid),
        .rs1_phy_branch(rs1_phy_branch),               
        .rs2_phy_branch(rs2_phy_branch), 
        .rs1_data_branch(rs1_data_branch),
        .rs2_data_branch(rs2_data_branch),
        .branch_valid(branch_valid),
        // output to commit stage
        .alu_rob_id(alu_rob_id),
        .alu_output(alu_output),
        .rd_phy_alu(rd_phy_alu),
        .busy_alu(busy_alu),
        // Store outputs
        .store_waddr(store_waddr),
        .store_wdata(store_wdata),
        .store_rob_id(store_rob_id),
        .store_valid(store_valid),
        // Load outputs
        .load_funct3(load_funct3),
        .load_valid(load_valid),
        .load_raddr(load_raddr),
        .load_rob_id(load_rob_id),
        .load_rd_phy(load_rd_phy),
        .busy_lsu(busy_lsu),
        // Branch outputs
        .branch_rob_id(branch_rob_id),
        .actual_taken(actual_taken),
        .mispredict(mispredict),
        .jumpPC(jumpPC),
        .update_pc(update_pc),
        .nextPC(nextPC),
        .rd_phy_branch(rd_phy_branch),
        .isJump(isJump),
        .busy_branch(busy_branch)
    );



    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            // alu outputs
            alu_rob_id_reg   <= 0;
            alu_output_reg   <= 0;
            rd_phy_alu_reg   <= 0;
            // Load/Store outputs
            store_waddr_reg  <= 0;
            store_wdata_reg  <= 0;
            store_rob_id_reg <= 0;
            store_valid_reg  <= 0;
            load_funct3_reg  <= 0;
            load_valid_reg   <= 0;
            load_raddr_reg   <= 0;
            load_rob_id_reg  <= 0;
            load_rd_phy_reg  <= 0;
            // Branch outputs
            branch_rob_id_reg <= 0;
            actual_taken_reg <= 0;
            jumpPC_reg        <= 0;
            nextPC_reg        <= 0;
            update_pc_reg     <= 0;
            rd_phy_branch_reg <= 0;
            isJump_reg        <= 0;
            mispredict_reg    <= 0;
        end else 
            // alu outputs
            if(alu_valid) begin
                alu_rob_id_reg   <= alu_rob_id;
                alu_output_reg   <= alu_output;
                rd_phy_alu_reg   <= rd_phy_alu;
                alu_valid_reg    <= alu_valid;
            end
            else begin
                alu_rob_id_reg   <= 0;
                alu_output_reg   <= 0;
                rd_phy_alu_reg   <= 0;
                alu_valid_reg    <= 0;
            end
            
            // Store outputs
            if(store_valid) begin
                store_waddr_reg  <= store_waddr;
                store_wdata_reg  <= store_wdata;
                store_rob_id_reg <= store_rob_id;
                store_valid_reg  <= store_valid;
            end
            else begin
                store_waddr_reg  <= 0;
                store_wdata_reg  <= 0;
                store_rob_id_reg <= 0;
                store_valid_reg  <= 0;
            end
            // Load outputs
            if(load_valid)begin
                load_funct3_reg  <= load_funct3;
                load_raddr_reg   <= load_raddr;
                load_rob_id_reg  <= load_rob_id;
                load_rd_phy_reg  <= load_rd_phy;
                load_valid_reg   <= load_valid;
            end
            else begin
                load_funct3_reg  <= 0;
                load_raddr_reg   <= 0;
                load_rob_id_reg  <= 0;
                load_rd_phy_reg  <= 0;
                load_valid_reg   <= 0;
            end


            // Branch outputs
            if(branch_valid) begin
                branch_rob_id_reg <= branch_rob_id;
                actual_taken_reg <= actual_taken;
                jumpPC_reg        <= jumpPC;
                nextPC_reg        <= nextPC;
                update_pc_reg     <= update_pc;
                rd_phy_branch_reg <= rd_phy_branch;
                isJump_reg        <= isJump;
                mispredict_reg    <= mispredict;
                branch_valid_reg  <= branch_valid;
            end
            else begin
                branch_rob_id_reg <= 0;
                actual_taken_reg <= 0;
                jumpPC_reg        <= 0;
                update_pc_reg     <= 0;
                nextPC_reg        <= 0;
                rd_phy_branch_reg <= 0;
                isJump_reg        <= 0;
                mispredict_reg    <= 0;
                branch_valid_reg  <= 0;
            end
            
        
    end

    // ============= Commit Stage ==================

    WriteBack #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH, FIFO_DEPTH) WriteBack_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // ============== from Execution (enqueue candidates) =================
        // from alu
        .alu_rob_id(alu_rob_id_reg),
        .alu_output(alu_output_reg),
        .rd_phy_alu(rd_phy_alu_reg),
        .alu_valid(alu_valid_reg),
        // Store outputs
        .store_waddr(store_waddr_reg),
        .store_wdata(store_wdata_reg),
        .store_rob_id(store_rob_id_reg),
        .store_valid(store_valid_reg),
        // Load outputs
        .load_funct3(load_funct3_reg),
        .load_valid(load_valid_reg),
        .load_raddr(load_raddr_reg),
        .load_rob_id(load_rob_id_reg),
        .load_rd_phy(load_rd_phy_reg),
        // Branch information
        .branch_rob_id(branch_rob_id_reg),
        .jumpPC(jumpPC_reg),
        .nextPC(nextPC_reg),
        .rd_phy_branch(rd_phy_branch_reg),
        .actual_taken(actual_taken_reg),
        .update_pc(update_pc_reg),
        .mispredict(mispredict_reg),
        .isJump(isJump_reg),
        .branch_valid(branch_valid_reg),
        // ========== Physical Register & ROB Commit Interface  ===========
        .commit_alu_rob_id(commit_alu_rob_id),
        .commit_alu_valid(commit_alu_valid),
        .commit_rd_alu(commit_rd_alu),
        .commit_alu_result(commit_alu_result),
        // load
        .commit_load_valid(commit_load_valid),
        .commit_load_rob_id(commit_load_rob_id),
        .commit_rd_load(commit_rd_load),
        .commit_load_rdata(commit_load_rdata),
        // store
        .commit_store_valid(commit_store_valid),
        .commit_store_rob_id(commit_store_rob_id),
        // branch
        .commit_branch_valid(commit_branch_valid),
        .commit_jump_valid(commit_jump_valid),
        .commit_branch_rob_id(commit_branch_rob_id),
        .commit_rd_branch(commit_rd_branch),
        .commit_nextPC(commit_nextPC),
        .commit_mispredict(commit_mispredict),
        .commit_actual_target(commit_actual_target),
        .commit_actual_taken(commit_actual_taken),
        .commit_update_pc(commit_update_pc),
        // ========== Retire Interface ===========
        // Memory Interface
        .mem_rd_en(mem_rd_en),
        .mem_raddr(mem_raddr),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        // Retire Interface
        .retire_store_valid(retire_store_valid_reg),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            commit_alu_valid_reg     <= 1'b0;
            commit_alu_rob_id_reg    <= 1'b0;
            commit_rd_alu_reg        <= 1'b0;
            commit_alu_result_reg    <= 1'b0;
            commit_load_valid_reg    <= 1'b0;
            commit_load_rob_id_reg   <= 1'b0;
            commit_rd_load_reg       <= 'b0;
            commit_load_rdata_reg    <= 'b0;
            commit_store_valid_reg   <= 1'b0;
            commit_store_rob_id_reg  <= 1'b0;
            commit_branch_valid_reg  <= 1'b0;
            commit_jump_valid_reg    <= 1'b0;
            commit_branch_rob_id_reg <= 1'b0;
            commit_rd_branch_reg     <= 1'b0;
            commit_nextPC_reg        <= 1'b0;
            commit_mispredict_reg    <= 1'b0;
            commit_actual_target_reg <= 1'b0;
            commit_actual_taken_reg  <= 1'b0;
            commit_update_pc_reg     <= 1'b0;
        end
        else begin
            commit_alu_valid_reg     <= commit_alu_valid;
            commit_alu_rob_id_reg    <= commit_alu_rob_id;
            commit_rd_alu_reg        <= commit_rd_alu;
            commit_alu_result_reg    <= commit_alu_result;
            commit_load_valid_reg    <= commit_load_valid;
            commit_load_rob_id_reg   <= commit_load_rob_id;
            commit_rd_load_reg       <= commit_rd_load;
            commit_load_rdata_reg    <= commit_load_rdata;
            commit_store_valid_reg   <= commit_store_valid;
            commit_store_rob_id_reg  <= commit_store_rob_id;
            commit_branch_valid_reg  <= commit_branch_valid;
            commit_jump_valid_reg    <= commit_jump_valid;
            commit_branch_rob_id_reg <= commit_branch_rob_id;
            commit_rd_branch_reg     <= commit_rd_branch;
            commit_nextPC_reg        <= commit_nextPC;
            commit_mispredict_reg    <= commit_mispredict;
            commit_actual_target_reg <= commit_actual_target;
            commit_actual_taken_reg  <= commit_actual_taken;
            commit_update_pc_reg     <= commit_update_pc;
        end
    end 

    // ============= Common ==================
    Front_RAT #(ARCH_REGS, PHY_WIDTH) front_rat (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(retire_done_valid_reg),
        // first instruction
        .instr_valid(instr_valid),
        .rs1_arch_0(rs1_arch_0),
        .rs2_arch_0(rs2_arch_0),
        .rd_arch_0(rd_arch_0),
        .rd_phy_new_0(rd_phy_new_0),
        .rs1_phy_0(rs1_phy_0),
        .rs2_phy_0(rs2_phy_0),
        .rd_phy_0(rd_phy_0),
        // second instruction
        .rs1_arch_1(rs1_arch_1),
        .rs2_arch_1(rs2_arch_1),
        .rd_arch_1(rd_arch_1),
        .rd_phy_new_1(rd_phy_new_1),
        .rs1_phy_1(rs1_phy_1),
        .rs2_phy_1(rs2_phy_1),
        .rd_phy_1(rd_phy_1),
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
        .done(retire_done_valid_reg),
        // rename interface to allocate physical registers
        .valid(free_list_valid),
        .rd_phy_new_0(rd_phy_new_0),
        .rd_phy_new_1(rd_phy_new_1),
        // commit interface to free physical registers
        .retire_valid(retire_pr_valid_reg),
        .rd_phy_old_commit(rd_phy_old_commit_reg),
        .rd_phy_new_commit(rd_phy_new_commit_reg)
    );

    logic [ROB_WIDTH-1:0] rob_debug;
    logic [ROB_WIDTH-1:0] rob_debug_reg;
    ReorderBuffer #(NUM_ROB_ENTRY, ROB_WIDTH, PHY_WIDTH) ROB(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .dispatch_valid(dispatch_valid),
        .dispatch_rob_0(dispatch_rob_0),
        .rob_id_0(rob_id_0),
        .dispatch_rob_1(dispatch_rob_1),
        .rob_id_1(rob_id_1),
        .commit_alu_valid(commit_alu_valid_reg),
        .commit_alu_rob_id(commit_alu_rob_id_reg),
        .commit_load_valid(commit_load_valid_reg),
        .commit_load_rob_id(commit_load_rob_id_reg),
        .commit_store_valid(commit_store_valid_reg),
        .commit_store_rob_id(commit_store_rob_id_reg),
        .commit_branch_valid(commit_branch_valid_reg),
        .commit_branch_rob_id(commit_branch_rob_id_reg),
        .commit_mispredict(commit_mispredict_reg),
        .commit_actual_target(commit_actual_target_reg),
        .commit_actual_taken(commit_actual_taken_reg),
        .commit_update_pc(commit_update_pc_reg),
        // outputs to backend/architectural state
        .isFlush(isFlush),
        .targetPC(targetPC),
        .rd_arch_commit(rd_arch_commit),
        .rd_phy_new_commit(rd_phy_new_commit),
        .rd_phy_old_commit(rd_phy_old_commit),
        .update_btb_pc(update_btb_pc),
        .update_btb_taken(update_btb_taken),
        .update_btb_target(update_btb_target),
        .retire_pr_valid(retire_pr_valid),
        .retire_store_valid(retire_store_valid),
        .retire_branch_valid(retire_branch_valid),
        .retire_done_valid(retire_done_valid),
        .rob_debug(rob_debug),
        .rob_full(rob_full),
        .rob_empty(rob_empty)
    );

    

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            rd_arch_commit_reg      <= 'h0;
            rd_phy_old_commit_reg   <= 'h0;
            rd_phy_new_commit_reg   <= 'h0;
            update_btb_pc_reg       <= 'h0;
            update_btb_taken_reg    <= 1'b0;
            update_btb_target_reg   <= 'h0;
            retire_pr_valid_reg     <= 1'b0;
            retire_store_valid_reg  <= 1'b0;
            retire_branch_valid_reg <= 1'b0;
            retire_done_valid_reg   <= 1'b0;
            rob_debug_reg           <= 'h0;
        end
        else begin
            rd_arch_commit_reg      <= rd_arch_commit;
            rd_phy_old_commit_reg   <= rd_phy_old_commit;
            rd_phy_new_commit_reg   <= rd_phy_new_commit;
            update_btb_pc_reg       <= update_btb_pc;
            update_btb_taken_reg    <= update_btb_taken;
            update_btb_target_reg   <= update_btb_target;
            retire_pr_valid_reg     <= retire_pr_valid;
            retire_store_valid_reg  <= retire_store_valid;
            retire_branch_valid_reg <= retire_branch_valid;
            retire_done_valid_reg   <= retire_done_valid;
            rob_debug_reg           <= rob_debug;
        end
    end

    Back_RAT #(ARCH_REGS, PHY_WIDTH) Back_RAT_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .retire_valid(retire_pr_valid_reg),
        .rd_arch_commit(rd_arch_commit_reg),
        .rd_phy_new_commit(rd_phy_new_commit_reg),
        .back_rat(back_rat)
    );

    Control Control_Unit(
        .clk(clk),
        .rst(rst),
        .rob_full(rob_full),
        .rob_empty(rob_empty),
        .pc_valid(pc_valid),
        .free_list_full(free_list_full),
        .free_list_empty(free_list_empty),
        .stall_fetch(stall_fetch),
        .stall_dispatch(stall_dispatch)
    );

    PhysicalRegister #(DATA_WIDTH, PHY_REGS) PhysicalRegisterFile(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .done(retire_done_valid_reg),
        .busy_valid(busy_valid),
        .rd_phy_busy_0(rd_phy_busy_0),
        .rd_phy_busy_1(rd_phy_busy_1),
        .PRF_busy(PRF_busy),
        // ========== read execution interface ===========
        .PRF_valid(PRF_valid),
        // alu
        .rs1_phy_alu(rs1_phy_alu),               
        .rs2_phy_alu(rs2_phy_alu),
        .rs1_data_alu(rs1_data_alu),
        .rs2_data_alu(rs2_data_alu),
        .alu_valid(alu_valid),
        // load/store 
        .rs1_phy_ls(rs1_phy_ls),
        .rs2_phy_ls(rs2_phy_ls),
        .rs1_data_ls(rs1_data_ls),
        .rs2_data_ls(rs2_data_ls),
        .ls_valid(ls_valid),
        // branch
        .rs1_phy_branch(rs1_phy_branch),
        .rs2_phy_branch(rs2_phy_branch),
        .rs1_data_branch(rs1_data_branch),
        .rs2_data_branch(rs2_data_branch),
        .branch_valid(branch_valid),
        // =========== writeback interface =================
        .commit_alu_valid(commit_alu_valid_reg),
        .commit_rd_alu(commit_rd_alu_reg),
        .commit_alu_result(commit_alu_result_reg),
        .commit_load_valid(commit_load_valid_reg),
        .commit_rd_load(commit_rd_load_reg),
        .commit_load_rdata(commit_load_rdata_reg),
        .commit_jump_valid(commit_jump_valid_reg),
        .commit_branch_valid(commit_branch_valid_reg),
        .commit_rd_branch(commit_rd_branch_reg),
        .commit_nextPC(commit_nextPC_reg),
        // from retire stage
        // =========== commit interface =================
        .rd_phy_old_commit(rd_phy_old_commit_reg),
        .rd_phy_new_commit(rd_phy_new_commit_reg),
        .retire_valid(retire_pr_valid_reg),
        // outputs for debug
        .PRF_data_out(PRF_data_out),
        .PRF_busy_out(PRF_busy_out),
        .PRF_valid_out(PRF_valid_out)
    );

    logic [ROB_WIDTH-1:0] retire_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            retire_count <= '0;
        end
        else if(flush) begin
            retire_count <= 0;
        end
        else if (retire_pr_valid || retire_store_valid || retire_branch_valid) begin
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
