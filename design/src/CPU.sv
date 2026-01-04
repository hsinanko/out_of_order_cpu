`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;
import instruction_pkg::*;


module O3O_CPU #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, REG_WIDTH = 32, PHY_REGS = 64, PHY_WIDTH = 6, ROB_WIDTH = 5, NUM_RS_ENTRIES = 8)(
    input logic clk,
    input logic rst,
    input logic [ADDR_WIDTH-1:0] start_addr
);

    logic flush;
    logic isFlush;
    logic [ADDR_WIDTH-1:0] targetPC;
    logic [ADDR_WIDTH-1:0] actual_target;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            flush <= 1'b0;
        end
        else if(isFlush)begin
            flush <= 1'b1;
            actual_target <= targetPC;
        end
        else begin
            flush <= 1'b0;
            actual_target <= 'h0;
        end
    end
    // ============= Instruction Fetch ===================
    logic [ADDR_WIDTH-1:0]instruction_addr_0, instruction_addr_1;
    logic [DATA_WIDTH-1:0]instruction_0, instruction_1;
    logic [1:0] instruction_valid;

    logic predict_taken;
    logic [ADDR_WIDTH-1:0] predict_target;
    logic update_valid;
    logic [ADDR_WIDTH-1:0] update_pc;
    logic update_taken;
    logic [ADDR_WIDTH-1:0] update_target;

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

    // ============ Issue / Execution Stage ==================

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


    logic [ROB_WIDTH-1:0] alu_rob_id;
    logic [DATA_WIDTH-1:0] alu_output;
    logic [PHY_WIDTH-1:0] rd_phy_alu;

    logic [ROB_WIDTH-1:0] ls_rob_id;
    logic [DATA_WIDTH-1:0] mem_read_en;
    logic [4:0] mem_funct3;
    logic [ADDR_WIDTH-1:0] raddr;
    logic [PHY_WIDTH-1:0] rd_phy_ls;
    logic [DATA_WIDTH-1:0] wdata;
    logic [ADDR_WIDTH-1:0] waddr;
    logic wdata_valid;

    logic [ROB_WIDTH-1:0] branch_rob_id;
    logic isbranchTaken;
    logic mispredict;
    logic [ADDR_WIDTH-1:0] jumpPC;
    logic [ADDR_WIDTH-1:0] nextPC;
    logic [PHY_WIDTH-1:0] rd_phy_branch;
    logic isJump;


    // ============= Write Back Stage ==================

    logic alu_wb_en;
    logic [PHY_WIDTH-1:0] rd_alu_wb;
    logic [DATA_WIDTH-1:0] alu_result;
    logic [1:0] ls_wb_en;
    logic [PHY_WIDTH-1:0] rd_ls_wb;
    logic [DATA_WIDTH-1:0] memory_output;
    logic [DATA_WIDTH-1:0] wdata_wb;
    logic [ADDR_WIDTH-1:0] waddr_wb;
    logic branch_wb_en;
    logic [PHY_WIDTH-1:0] rd_branch_wb;
    logic [ADDR_WIDTH-1:0] nextPC_wb;



    logic alu_wb_en_reg;
    logic [PHY_WIDTH-1:0] rd_alu_wb_reg;
    logic [DATA_WIDTH-1:0] alu_result_reg;
    logic [1:0] ls_wb_en_reg;
    logic [PHY_WIDTH-1:0] rd_ls_wb_reg;
    logic [DATA_WIDTH-1:0] memory_output_reg;
    logic [DATA_WIDTH-1:0] wdata_wb_reg;
    logic [ADDR_WIDTH-1:0] waddr_wb_reg;
    logic branch_wb_en_reg;
    logic [PHY_WIDTH-1:0] rd_branch_wb_reg;
    logic [ADDR_WIDTH-1:0] nextPC_wb_reg;

    logic [1:0] free_valid;
    logic [PHY_WIDTH-1:0] rd_phy_free_0, rd_phy_free_1, rd_phy_free_2;

    assign free_valid = {branch_wb_en_reg, ls_wb_en_reg[0], alu_wb_en_reg};
    assign rd_phy_free_0 = rd_alu_wb_reg;
    assign rd_phy_free_1 = rd_ls_wb_reg;
    assign rd_phy_free_2 = rd_branch_wb_reg;





    logic [PHY_WIDTH-1:0] rd_phy_commit_reg;
    
    logic [ROB_WIDTH-1:0] commit_alu_rob_id_reg;
    logic commit_alu_valid_reg;
    logic [ROB_WIDTH-1:0] commit_ls_rob_id_reg;
    logic commit_ls_valid_reg;
    logic [ROB_WIDTH-1:0] commit_branch_rob_id_reg;
    logic commit_branch_valid_reg;
    logic commit_mispredict_reg;
    logic [ADDR_WIDTH-1:0] commit_actual_target_reg;

    // ============= Physical Register File ==================
    logic [PHY_REGS-1:0]PRF_busy;
    logic [PHY_REGS-1:0]PRF_valid;
    logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat;

    // ================== Memory Interface ==================
    logic [DATA_WIDTH-1:0] mem_rdata;
    logic mem_rdata_valid;

    // memory port
    logic mem_write_en;
    logic [ADDR_WIDTH-1:0] mem_waddr;
    logic [DATA_WIDTH-1:0] mem_wdata;

    logic [ADDR_WIDTH-1:0] mem_addr;

    // ============ Reorder Buffer ==================

    logic [PHY_WIDTH-1:0] rd_phy_commit;
    
    logic [ROB_WIDTH-1:0] commit_alu_rob_id;
    logic commit_alu_valid;
    logic [ROB_WIDTH-1:0] commit_ls_rob_id;
    logic commit_ls_valid;
    logic [ROB_WIDTH-1:0] commit_branch_rob_id;
    logic commit_branch_valid;
    logic commit_mispredict;
    logic [ADDR_WIDTH-1:0] commit_actual_target;
    // ============= Retire Stage ==================

    logic [4:0] rd_arch_commit;
    logic [PHY_REGS-1:0] rd_phy_old_commit;
    logic [PHY_REGS-1:0] rd_phy_new_commit;
    logic retire_valid;
    logic store_valid;
    // Retire logic
    logic rd_arch_commit_reg;
    logic [PHY_WIDTH-1:0] rd_phy_old_commit_reg;
    logic [PHY_WIDTH-1:0] rd_phy_new_commit_reg;
    logic retire_valid_reg;
    logic store_valid_reg;




    // ============= Instruction Fetch ===================
    logic [ADDR_WIDTH-1:0]pc;
    logic [ADDR_WIDTH-1:0]instruction_addr_0_reg, instruction_addr_1_reg;
    logic [DATA_WIDTH-1:0]instruction_0_reg, instruction_1_reg;
    logic [1:0] instruction_valid_reg;
    logic predict_taken_0_reg;
    logic [ADDR_WIDTH-1:0] predict_target_0_reg;

    logic predict_taken_1_reg;
    logic [ADDR_WIDTH-1:0] predict_target_1_reg;
    InstructionFetch #(ADDR_WIDTH, DATA_WIDTH) Fetch(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instruction_addr_0(instruction_addr_0),
        .instruction_addr_1(instruction_addr_1),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .instruction_valid(instruction_valid),
        // BTB Interface
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .update_valid(update_valid),
        .update_pc(update_pc),
        .update_taken(update_taken),
        .update_target(jumpPC)
    );

    always_ff @(posedge clk or posedge rst)begin
        if (rst) begin
            pc                     <= start_addr;
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
            pc                     <= actual_target;
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
        else if(predict_taken)begin
            pc                     <= predict_target;
            instruction_addr_0_reg <= pc;
            instruction_addr_1_reg <= 'h0;
            instruction_0_reg      <= instruction_0;
            instruction_1_reg      <= '0;
            instruction_valid_reg  <= instruction_valid;
            predict_taken_0_reg    <= predict_taken;
            predict_target_0_reg   <= predict_target;
            predict_taken_1_reg    <= 'h0;
            predict_target_1_reg   <= 'h0;
        end
        else begin
            pc                     <= pc + 8;
            instruction_addr_0_reg <= pc;
            instruction_addr_1_reg <= pc + 4;
            instruction_0_reg      <= instruction_0;
            instruction_1_reg      <= instruction_1;
            instruction_valid_reg  <= instruction_valid;
            predict_taken_0_reg    <= predict_taken;
            predict_target_0_reg   <= predict_target;
            predict_taken_1_reg    <= predict_taken;
            predict_target_1_reg   <= predict_target;
        end
    end


    // ============= Decode / Rename Stage ==============

    RS_ENTRY_t issue_instruction_alu_reg, issue_instruction_ls_reg, issue_instruction_branch_reg;
    logic issue_alu_valid_reg, issue_ls_valid_reg, issue_branch_valid_reg;

    Rename #(ADDR_WIDTH, DATA_WIDTH, REG_WIDTH, ARCH_REGS, PHY_REGS, ROB_WIDTH, PHY_WIDTH) Rename_Unit (
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .PRF_valid(PRF_valid),
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
        .issue_branch_valid(issue_branch_valid)
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
        // to execution outputs
        .alu_rob_id(alu_rob_id),
        .alu_output(alu_output),
        .rd_phy_alu(rd_phy_alu),
        .ls_rob_id(ls_rob_id),
        .mem_read_en(mem_read_en),
        .mem_funct3(mem_funct3),
        .raddr(raddr),
        .rd_phy_ls(rd_phy_ls),
        .wdata(wdata),
        .waddr(waddr),
        .wdata_valid(wdata_valid),
        .branch_rob_id(branch_rob_id),
        .isbranchTaken(isbranchTaken),
        .mispredict(mispredict),
        .jumpPC(jumpPC),
        .update_pc(update_pc),
        .rd_phy_branch(rd_phy_branch),
        .isJump(isJump)
    );

    logic [ROB_WIDTH-1:0]alu_rob_id_reg;
    logic [DATA_WIDTH-1:0] alu_output_reg;
    logic [PHY_WIDTH-1:0]rd_phy_alu_reg;
    logic alu_valid_reg;
    // Load/Store outputs
    logic [ROB_WIDTH-1:0]ls_rob_id_reg;
    logic mem_read_en_reg;
    logic [4:0]mem_funct3_reg;
    logic [ADDR_WIDTH-1:0]raddr_reg;
    logic [PHY_WIDTH-1:0]rd_phy_ls_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [ADDR_WIDTH-1:0] waddr_reg;
    logic wdata_valid_reg;
    logic ls_valid_reg;
    // Branch outputs
    logic [ROB_WIDTH-1:0]branch_rob_id_reg;

    logic [ADDR_WIDTH-1:0] jumpPC_reg;
    logic [ADDR_WIDTH-1:0] update_pc_reg;
    logic [ADDR_WIDTH-1:0] nextPC_reg;
    logic [PHY_WIDTH-1:0]rd_phy_branch_reg;
    logic isJump_reg;
    logic mispredict_reg;
    logic branch_valid_reg;

    assign update_taken = isbranchTaken;
    assign update_target = jumpPC;
    assign update_valid  = branch_valid;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            // alu outputs
            alu_rob_id_reg   <= 0;
            alu_output_reg   <= 0;
            rd_phy_alu_reg   <= 0;
            // Load/Store outputs
            ls_rob_id_reg    <= 0;

            rd_phy_ls_reg    <= 0;
            wdata_reg        <= 0;
            waddr_reg        <= 0;
            wdata_valid_reg  <= 0;
            // Branch outputs
            branch_rob_id_reg <= 0;
            jumpPC_reg        <= 0;
            nextPC_reg        <= 0;
            rd_phy_branch_reg <= 0;
            isJump_reg        <= 0;
            mispredict_reg    <= 0;
        end else begin
            // alu outputs
            if(issue_alu_valid_reg) begin
                alu_rob_id_reg   <= alu_rob_id;
                alu_output_reg   <= alu_output;
                rd_phy_alu_reg   <= rd_phy_alu;
            end
            else begin
                alu_rob_id_reg   <= 0;
                alu_output_reg   <= 0;
                rd_phy_alu_reg   <= 0;
            end
            alu_valid_reg        <= alu_valid;
            // Load/Store outputs
            if(issue_ls_valid_reg) begin
                ls_rob_id_reg    <= ls_rob_id;
                rd_phy_ls_reg    <= rd_phy_ls;
                wdata_reg        <= wdata;
                waddr_reg        <= waddr;
                wdata_valid_reg  <= wdata_valid;
            end
            else begin
                ls_rob_id_reg    <= 0;
                rd_phy_ls_reg    <= 0;
                wdata_reg        <= 0;
                waddr_reg        <= 0;
                wdata_valid_reg  <= 0;
            end
            ls_valid_reg         <= ls_valid;

            // Branch outputs
            if(issue_branch_valid_reg) begin
                branch_rob_id_reg <= branch_rob_id;
                jumpPC_reg        <= jumpPC;
                nextPC_reg        <= (issue_instruction_branch.addr + 'h4);
                update_pc_reg     <= update_pc;
                rd_phy_branch_reg <= rd_phy_branch;
                isJump_reg        <= isJump;
                mispredict_reg    <= mispredict;
            end
            else begin
                branch_rob_id_reg <= 0;
                jumpPC_reg        <= 0;
                update_pc_reg     <= 0;
                nextPC_reg        <= 0;
                rd_phy_branch_reg <= 0;
                isJump_reg        <= 0;
                mispredict_reg    <= 0;
            end
            branch_valid_reg      <= branch_valid;
        end
    end

    // ============= Commit Stage ==================

    WriteBack #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH) WriteBack_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        // ============== from Execution (enqueue candidates) =================
        // from alu
        .alu_rob_id(alu_rob_id_reg),
        .alu_output(alu_output_reg),
        .rd_phy_alu(rd_phy_alu_reg),
        .alu_valid(alu_valid_reg),
        // from load/store unit
        .ls_rob_id(ls_rob_id_reg),
        .rd_phy_ls(rd_phy_ls_reg),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        .wdata(wdata_reg),
        .waddr(waddr_reg),
        .wdata_valid(wdata_valid_reg),
        .ls_valid(ls_valid_reg),
        // Branch information
        .branch_rob_id(branch_rob_id_reg),
        .jumpPC(jumpPC_reg),
        .nextPC(nextPC_reg),
        .rd_phy_branch(rd_phy_branch_reg),
        .mispredict(mispredict_reg),
        .isJump(isJump_reg),
        .branch_valid(branch_valid_reg),
        // ========== Physical Register Control signals ===========
        // outputs: commit to retirement/architectural state
        .alu_wb_en(alu_wb_en),                      // commit enable signal
        .rd_alu_wb(rd_alu_wb),                 // physical register address to commit
        .alu_result(alu_result_wb),     // data to writ
        // load/store commit interface
        .ls_wb_en(ls_wb_en),                       // commit enable signal
        .rd_ls_wb(rd_ls_wb),                  // physical register address to commit
        .memory_output(memory_output_wb),  // data to write
        .wdata_wb(wdata_wb),
        .waddr_wb(waddr_wb),
        // branch commit interface
        .branch_wb_en(branch_wb_en),                   // commit enable signal
        .rd_branch_wb(rd_branch_wb),              // physical register address to commit
        .nextPC_wb(nextPC_wb),     // data to write
        // ================= ROB Commit Interface ==================
        .commit_alu_valid(commit_alu_valid),
        .commit_alu_rob_id(commit_alu_rob_id),
        .commit_ls_valid(commit_ls_valid),
        .commit_ls_rob_id(commit_ls_rob_id),
        .commit_branch_valid(commit_branch_valid),
        .commit_branch_rob_id(commit_branch_rob_id),
        .commit_mispredict(commit_mispredict),
        .commit_actual_target(commit_actual_target)
    );


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_wb_en_reg     <= 1'b0;
            rd_alu_wb_reg     <= 'h0;
            alu_result_reg    <= 'h0;
            ls_wb_en_reg      <= 2'b0;
            rd_ls_wb_reg      <= 'h0;
            memory_output_reg <= 'h0;
            wdata_wb_reg      <= 'h0;
            waddr_wb_reg      <= 'h0;
            branch_wb_en_reg  <= 1'b0;
            rd_branch_wb_reg  <= 'h0;
            nextPC_wb_reg     <= 'h0;
        end
        else begin
            alu_wb_en_reg     <= alu_wb_en;
            rd_alu_wb_reg     <= rd_alu_wb;
            alu_result_reg    <= alu_result_wb;
            ls_wb_en_reg      <= ls_wb_en;
            rd_ls_wb_reg      <= rd_ls_wb;
            memory_output_reg <= memory_output_wb;
            wdata_wb_reg      <= wdata_wb;
            waddr_wb_reg      <= waddr_wb;
            branch_wb_en_reg  <= branch_wb_en;
            rd_branch_wb_reg  <= rd_branch_wb;
            nextPC_wb_reg     <= nextPC_wb;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            commit_alu_valid_reg     <= 1'b0;
            commit_alu_rob_id_reg    <= 'h0;
            commit_ls_valid_reg      <= 1'b0;
            commit_ls_rob_id_reg     <= 'h0;
            commit_branch_valid_reg  <= 1'b0;
            commit_branch_rob_id_reg <= 'h0;
            commit_mispredict_reg    <= 1'b0;
            commit_actual_target_reg <= 'h0;
        end
        else begin
            commit_alu_valid_reg     <= commit_alu_valid;
            commit_alu_rob_id_reg    <= commit_alu_rob_id;
            commit_ls_valid_reg      <= commit_ls_valid;
            commit_ls_rob_id_reg     <= commit_ls_rob_id;
            commit_branch_valid_reg  <= commit_branch_valid;
            commit_branch_rob_id_reg <= commit_branch_rob_id;
            commit_mispredict_reg    <= commit_mispredict;
            commit_actual_target_reg <= commit_actual_target;
        end
    end 

    // ============= Memory ==============


    Memory #(ADDR_WIDTH, DATA_WIDTH) Memory_Unit(
        .clk(clk),
        .rst(rst),
        .raddr(raddr),
        .waddr(mem_waddr),
        .wdata(mem_wdata),
        .funct3(mem_funct3),
        .mem_write_en(mem_write_en),
        .mem_read_en(mem_read_en),
        .rdata(mem_rdata),
        .rdata_valid(mem_rdata_valid)
    );


    // ============= Common ==================
    Front_RAT #(ARCH_REGS, PHY_WIDTH) front_rat (
        .clk(clk),
        .rst(rst),
        .flush(flush),
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
        .back_rat(back_rat)
    );

    Freelist #(PHY_REGS, PHY_WIDTH) free_list(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .valid(free_list_valid),
        .rd_phy_new_0(rd_phy_new_0),
        .rd_phy_new_1(rd_phy_new_1),
        // commit interface to free physical registers
        .free_valid(free_valid),
        .rd_phy_free_0(rd_phy_free_0),
        .rd_phy_free_1(rd_phy_free_1),
        .rd_phy_free_2(rd_phy_free_2)
    );


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
        .commit_ls_valid(commit_ls_valid_reg),
        .commit_ls_rob_id(commit_ls_rob_id_reg),
        .commit_branch_valid(commit_branch_valid_reg),
        .commit_branch_rob_id(commit_branch_rob_id_reg),
        .commit_mispredict(commit_mispredict_reg),
        .commit_actual_target(commit_actual_target_reg),
        // outputs to backend/architectural state
        .isFlush(isFlush),
        .targetPC(targetPC),
        .rd_arch_commit(rd_arch_commit),
        .rd_phy_new_commit(rd_phy_new_commit),
        .rd_phy_old_commit(rd_phy_old_commit),
        .retire_valid(retire_valid),
        .store_valid(store_valid)
    );


    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            rd_arch_commit_reg    <= 'h0;
            rd_phy_old_commit_reg <= 'h0;
            rd_phy_new_commit_reg <= 'h0;
            retire_valid_reg      <= 1'b0;
            store_valid_reg       <= 1'b0;
        end
        else begin
            rd_arch_commit_reg    <= rd_arch_commit;
            rd_phy_old_commit_reg <= rd_phy_old_commit;
            rd_phy_new_commit_reg <= rd_phy_new_commit;
            retire_valid_reg      <= retire_valid;
            store_valid_reg       <= store_valid;
        end
    end

    StoreQueue #(ADDR_WIDTH, DATA_WIDTH, QUEUE) StoreQueue_Unit(
        .clk(clk),
        .rst(rst),
        .wb_valid(ls_wb_en_reg[1]),
        .waddr_wb(waddr_wb_reg),
        .wdata_wb(wdata_wb_reg),
        .store_valid(store_valid_reg),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );

    Back_RAT #(ARCH_REGS, PHY_WIDTH) Back_RAT_Unit(
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .rd_arch_commit(rd_arch_commit),
        .rd_phy_new_commit(rd_phy_new_commit_reg),
        .retire_valid(retire_valid_reg),
        .back_rat(back_rat)
    );

    PhysicalRegister #(DATA_WIDTH, PHY_REGS) PRF(
        .clk(clk),
        .rst(rst),
        .flush(flush),
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
        .alu_wb_en(alu_wb_en),
        .rd_alu_wb(rd_alu_wb_reg),
        .alu_result(alu_result_reg),
        .ls_wb_en(ls_wb_en_reg),
        .rd_ls_wb(rd_ls_wb_reg),
        .memory_output(memory_output_reg),
        .branch_wb_en(branch_wb_en),
        .rd_branch_wb(rd_branch_wb_reg),
        .nextPC(nextPC_wb_reg),
        // =========== commit interface =================
        .rd_phy_old_commit(rd_phy_old_commit_reg),
        .rd_phy_new_commit(rd_phy_new_commit_reg),
        .retire_valid(retire_valid_reg)
    );


    // ============= Debug Tasks ==================

    always_ff @(posedge clk) begin
        if(rst) 
            $display("\n\n\t============ Resetting CPU ============\n\n");
        else begin
            // print debug information at each stage
            $display("*************************** Cycle %0d *************************", $time/10);
            print_Fetch();
            print_Rename();
            print_Execution();
            print_Commit();
            $display("**************************** END *****************************\n");
        end
    end

    task print_Fetch();
        $display("\t===============================================");
        $display("\t----------- Instruction Fetch Stage -----------");
        $display("\t===============================================");
        if(instruction_valid == 2'b00) begin
            $display("\t\tNo valid instructions fetched.");
        end
        else begin
            $display("\t\tFetched  %2d valid instructions.", instruction_valid-1);
            if(instruction_valid[0])begin
                $display("\tInstruction 0: PC = 0x%h, 0x%h", instruction_addr_0, instruction_0);
            end

            if(instruction_valid[1]) begin
                $display("\tInstruction 1: PC = 0x%h, 0x%h", instruction_addr_1, instruction_1);
            end
        end
    endtask : print_Fetch


    task print_Rename();
        $display("\n\t===============================================");
        $display("\t------- Decode - Rename, Dispatch Stage -------");
        $display("\t===============================================");
        if(instruction_valid_reg == 2'b00) begin
            $display("\t\tNo valid instructions renamed.");
        end
        else begin
            $display("\t\tRenamed %2d valid instructions.", instruction_valid_reg-1);
            if(instruction_valid_reg[0])begin
                $display("\tInstruction 0: PC = 0x%h, 0x%h", instruction_addr_0_reg, instruction_0_reg);
            end

            if(instruction_valid_reg[1]) begin
                $display("\tInstruction 1: PC = 0x%h, 0x%h", instruction_addr_1_reg, instruction_1_reg);
            end
            $display("\t\tDispatch to Reservation Station .....");
            if(issue_alu_valid_reg | issue_ls_valid_reg | issue_branch_valid_reg) begin
                $display("\t\tIssued Instructions");
                if(issue_alu_valid_reg) begin
                    $display("\tALU Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_alu_reg.addr, issue_instruction_alu_reg.rob_id);
                end
                if(issue_ls_valid_reg) begin
                    if(issue_instruction_ls_reg.opcode == LOAD)
                        $display("\tLoad Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_ls_reg.addr, issue_instruction_ls_reg.rob_id);
                    else
                        $display("\tStore Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_ls_reg.addr, issue_instruction_ls_reg.rob_id);
                end
                if(issue_branch_valid_reg) begin
                    $display("\tBranch Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_branch_reg.addr, issue_instruction_branch_reg.rob_id);
                end
            end
            else begin
                $display("\t\tNo valid instructions issued.");
            end

        end
    endtask : print_Rename

    task print_Execution();
        $display("\n\t===============================================");
        $display("\t----------- Issue / Execution Stage -----------");
        $display("\t===============================================");
        // Add execution stage debug information here
        if(!alu_valid && !ls_valid && !branch_valid) begin
            $display("\t\tNo valid instructions executed.");
        end
        else begin
            if(alu_valid) begin
                $display("\tALU Result: ROB_ID=%0d, Result=%h", alu_rob_id, alu_output);
            end
            if(ls_valid) begin
                if(wdata_valid)
                    $display("\tStore Data: ROB_ID=%0d, Addr=%h, Data=%h", ls_rob_id, waddr, wdata);
                else
                    $display("\tLoad Data: ROB_ID=%0d, rd_phy=%h, Data=%h", ls_rob_id, rd_phy_ls, mem_rdata);
            end
            if(branch_valid) begin
                $display("\tBranch Execution: ROB_ID=%0d, NextPC=%h", branch_rob_id, nextPC);
            end
        end

    endtask : print_Execution


    task print_Commit();
        $display("\n\t===============================================");
        $display("\t---------------- Commit Stage -----------------");
        $display("\t===============================================");

        if(!retire_valid_reg) begin
            $display("\t\tNo valid instructions committed.");
        end
        else begin
            $display("\tCommitted Instruction: RD_ARCH=%0d, RD_PHY=%0d", rd_arch_commit_reg, rd_phy_commit_reg);
        end
    endtask : print_Commit


    // task print_Freelist();
    //     $display("\n\t===============================================");
    //     $display("\t----------------- Free List -------------------");
    //     $display("\t===============================================");

    //     // Add freelist debug information here
    //     $display("\tFree List Contents:");
    //     for (i = 0; i < PHY_REGS; i = i + 1) begin
    //         if (!PRF_valid[i]) begin
    //             $display("\tFree Register: %0d", i);
    //         end
    //     end
    // endtask : print_Freelist

endmodule
