`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;
import instruction_pkg::*;


module O3O_CPU #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, REG_WIDTH = 32, PHY_REGS = 64, PHY_WIDTH = 6, ROB_WIDTH = 5, NUM_RS_ENTRIES = 8)(
    input logic clk,
    input logic rst,
    input logic [ADDR_WIDTH-1:0] start_addr
);

    // ============= Instruction Fetch ===================
    logic [ADDR_WIDTH-1:0]instruction_addr_0, instruction_addr_1;
    logic [DATA_WIDTH-1:0]instruction_0, instruction_1;
    logic [1:0] instruction_valid;

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

    instruction_t rename_instruction_0, rename_instruction_1;
    logic [1:0] rename_valid;
    logic [ROB_WIDTH-1:0] rename_rob_id_0, rename_rob_id_1;

    // ============= Decode / Dispatch Stage ==============
    RS_ENTRY_t issue_instruction_alu, issue_instruction_ls, issue_instruction_branch;
    logic issue_alu_valid, issue_ls_valid, issue_branch_valid;

    // ============ Issue / Execution Stage ==================
    logic [ADDR_WIDTH-1:0]instruction_addr_exec;
    logic [DATA_WIDTH-1:0]instruction_exec;
    logic issue_alu_en_exec, issue_ls_en_exec, issue_branch_en_exec;
    RS_ENTRY_t issue_instruction_alu_exec, issue_instruction_ls_exec, issue_instruction_branch_exec;
    logic issue_alu_valid_exec, issue_ls_valid_exec, issue_branch_valid_exec;

    logic [PHY_WIDTH-1:0] rs1_phy_alu;
    logic [PHY_WIDTH-1:0] rs2_phy_alu;
    logic [DATA_WIDTH-1:0] rs1_data_alu;
    logic [DATA_WIDTH-1:0] rs2_data_alu;
    logic valid_alu;
    logic [PHY_WIDTH-1:0] rs1_phy_ls;
    logic [PHY_WIDTH-1:0] rs2_phy_ls;
    logic [DATA_WIDTH-1:0] rs1_data_ls;
    logic [DATA_WIDTH-1:0] rs2_data_ls;
    logic valid_ls;
    logic [PHY_WIDTH-1:0] rs1_phy_branch;
    logic [PHY_WIDTH-1:0] rs2_phy_branch;
    logic [DATA_WIDTH-1:0] rs1_data_branch;
    logic [DATA_WIDTH-1:0] rs2_data_branch;
    logic valid_branch;


    logic [ROB_WIDTH-1:0] alu_rob_id;
    logic [DATA_WIDTH-1:0] alu_output;
    logic [PHY_WIDTH-1:0] rd_phy_alu;
    logic alu_valid;
    logic [ROB_WIDTH-1:0] ls_rob_id;
    logic [DATA_WIDTH-1:0] mem_read_en;
    logic [4:0] mem_funct3;
    logic [ADDR_WIDTH-1:0] raddr;
    logic [PHY_WIDTH-1:0] rd_phy_ls;
    logic [DATA_WIDTH-1:0] wdata;
    logic [ADDR_WIDTH-1:0] waddr;
    logic wdata_valid;
    logic ls_valid;
    logic [ROB_WIDTH-1:0] branch_rob_id;
    logic [ADDR_WIDTH-1:0] jumpPC;
    logic [ADDR_WIDTH-1:0] nextPC;
    logic [PHY_WIDTH-1:0] rd_phy_branch;
    logic isJump_exe;

    // ============= Common Stage ==================
    logic [PHY_REGS-1:0]PRF_busy;
    logic [PHY_REGS-1:0]PRF_valid;
    logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat;

    logic [ROB_WIDTH-1:0] alu_rob_id_wb;
    logic [DATA_WIDTH-1:0] alu_output_wb;
    logic [PHY_WIDTH-1:0] rd_phy_alu_wb;
    logic [ROB_WIDTH-1:0] ls_rob_id_wb;
    logic [DATA_WIDTH-1:0] memory_output_wb;
    logic [DATA_WIDTH-1:0] wdata_wb;
    logic [ADDR_WIDTH-1:0] waddr_wb;
    logic [PHY_WIDTH-1:0] rd_phy_ls_wb;
    logic [ROB_WIDTH-1:0] branch_rob_id_wb;
    logic [ADDR_WIDTH-1:0] jumpPC_wb;
    logic [ADDR_WIDTH-1:0] nextPC_wb;
    logic [PHY_WIDTH-1:0] rd_phy_branch_wb;
    logic wb_en_alu,  wb_en_branch;
    logic [1:0] wb_en_ls;
    logic [1:0] free_valid;
    logic [PHY_WIDTH-1:0] rd_phy_free_0, rd_phy_free_1, rd_phy_free_2;

    assign free_valid = {wb_en_branch, wb_en_ls[0], wb_en_alu};
    assign rd_phy_free_0 = rd_phy_alu_wb;
    assign rd_phy_free_1 = rd_phy_ls_wb;
    assign rd_phy_free_2 = rd_phy_branch_wb;


    logic [DATA_WIDTH-1:0] mem_rdata;
    logic mem_rdata_valid;

    // memory port
    logic mem_write_en;
    logic [ADDR_WIDTH-1:0] mem_waddr;
    logic [DATA_WIDTH-1:0] mem_wdata;

    logic [ADDR_WIDTH-1:0] mem_addr;

    // reorder buffer commit signals
    logic [4:0] rd_arch_commit;
    logic [PHY_WIDTH-1:0] rd_phy_commit;
    logic retire_valid;
    logic [ROB_WIDTH-1:0] commit_alu_rob_id;
    logic commit_alu_valid;
    logic [ROB_WIDTH-1:0] commit_ls_rob_id;
    logic commit_ls_valid;
    logic [ROB_WIDTH-1:0] commit_branch_rob_id;
    logic commit_branch_valid;
    logic store_valid;

    logic [PHY_REGS-1:0] rd_phy_old_commit;
    logic [PHY_REGS-1:0] rd_phy_new_commit;

    // ============= Instruction Fetch ===================


    InstructionFetch #(ADDR_WIDTH, DATA_WIDTH) Fetch(
        .clk(clk),
        .rst(rst),
        .isJump(isJump),
        .start_addr(start_addr),
        .jump_address(jump_address),
        .instruction_addr_0(instruction_addr_0),
        .instruction_addr_1(instruction_addr_1),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .instruction_valid(instruction_valid)
    );

    // ============= Decode / Rename Stage ==============


    
    Rename #(ADDR_WIDTH, DATA_WIDTH, REG_WIDTH, ARCH_REGS, PHY_REGS, ROB_WIDTH, PHY_WIDTH) Rename_Unit (
        .clk(clk),
        .rst(rst),
        .instruction_valid(instruction_valid),
        .instruction_addr_0(instruction_addr_0),
        .instruction_0(instruction_0),
        .instruction_addr_1(instruction_addr_1),
        .instruction_1(instruction_1),
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
        .rename_valid(rename_valid),
        .rename_instruction_0(rename_instruction_0),
        .rename_rob_id_0(rename_rob_id_0),
        .rename_instruction_1(rename_instruction_1),
        .rename_rob_id_1(rename_rob_id_1)
    );



    // ============= Decode / Dispatch Stage ==============


    Dispatch #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, PHY_WIDTH) Dispatch_Unit(
        .clk(clk),
        .rst(rst),
        .PRF_valid(PRF_valid),
        .rename_valid(rename_valid),
        .rename_instruction_0(rename_instruction_0),
        .rob_id_0(rename_rob_id_0),
        .rename_instruction_1(rename_instruction_1),
        .rob_id_1(rename_rob_id_1),
        // dispatch --> issue
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .issue_alu_valid(issue_alu_valid),
        .issue_ls_valid(issue_ls_valid),
        .issue_branch_valid(issue_branch_valid)
    );


    // ============= Issue / Execution Stage ==================


    Issue #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH, ROB_WIDTH) Issue_Unit(
        .clk(clk),
        .rst(rst),
        // from dispatch
        .instruction_addr(),
        .instruction(),
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .issue_alu_valid(issue_alu_valid),
        .issue_ls_valid(issue_ls_valid),
        .issue_branch_valid(issue_branch_valid),
        // to execution
        .rs1_phy_alu(rs1_phy_alu),               
        .rs2_phy_alu(rs2_phy_alu), 
        .rs1_data_alu(rs1_data_alu),
        .rs2_data_alu(rs2_data_alu),
        .valid_alu(valid_alu),
        .rs1_phy_ls(rs1_phy_ls),               
        .rs2_phy_ls(rs2_phy_ls),
        .rs1_data_ls(rs1_data_ls),
        .rs2_data_ls(rs2_data_ls),
        .valid_ls(valid_ls),
        .rs1_phy_branch(rs1_phy_branch),               
        .rs2_phy_branch(rs2_phy_branch), 
        .rs1_data_branch(rs1_data_branch),
        .rs2_data_branch(rs2_data_branch),
        .valid_branch(valid_branch),
        // to execution outputs
        .alu_rob_id_reg(alu_rob_id),
        .alu_output_reg(alu_output),
        .rd_phy_alu_reg(rd_phy_alu),
        .alu_valid_reg(alu_valid),
        .ls_rob_id_reg(ls_rob_id),
        .mem_read_en_reg(mem_read_en),
        .mem_funct3_reg(mem_funct3),
        .raddr_reg(raddr),
        .rd_phy_ls_reg(rd_phy_ls),
        .wdata_reg(wdata),
        .waddr_reg(waddr),
        .wdata_valid_reg(wdata_valid),
        .ls_valid_reg(ls_valid),
        .branch_rob_id_reg(branch_rob_id),
        .jumpPC_reg(jumpPC),
        .nextPC_reg(nextPC),
        .rd_phy_branch_reg(rd_phy_branch),
        .isJump_reg(isJump_exe),
        .branch_valid_reg(branch_valid)
    );



    // ============= Commit Stage ==================

    WriteBack #(ADDR_WIDTH, DATA_WIDTH, PHY_WIDTH) WriteBack_Unit(
        .clk(clk),
        .rst(rst),
        // ============== from Execution (enqueue candidates) =================
        // from alu
        .alu_rob_id(alu_rob_id),
        .alu_result(alu_output),
        .rd_phy_alu(rd_phy_alu),
        .alu_valid(alu_valid),
        // from load/store unit
        .ls_rob_id(ls_rob_id),
        .rd_phy_ls(rd_phy_ls),
        .mem_rdata(mem_rdata),
        .mem_rdata_valid(mem_rdata_valid),
        .wdata(wdata),
        .waddr(waddr),
        .wdata_valid(wdata_valid),
        .ls_valid(ls_valid),
        // Branch information
        .branch_rob_id(branch_rob_id),
        .jumpPC(jumpPC),
        .nextPC(nextPC),
        .rd_phy_branch(rd_phy_branch),
        .isJump(isJump_exe),
        .branch_valid(branch_valid),
        // ========== Physical Register Control signals ===========
        // outputs: commit to retirement/architectural state
        .wb_en_alu(wb_en_alu),                      // commit enable signal
        .rd_wb_alu(rd_phy_alu_wb),                 // physical register address to commit
        .alu_output(alu_output_wb),     // data to writ
        // load/store commit interface
        .wb_en_ls(wb_en_ls),                       // commit enable signal
        .rd_wb_ls(rd_phy_ls_wb),                  // physical register address to commit
        .memory_output(memory_output_wb),  // data to write
        .wdata_wb(wdata_wb),
        .waddr_wb(waddr_wb),
        // branch commit interface
        .wb_en_branch(wb_en_branch),                   // commit enable signal
        .rd_wb_branch(rd_phy_branch_wb),              // physical register address to commit
        .nextPC_reg(nextPC_wb),     // data to write
        // ================= ROB Commit Interface ==================
        .commit_alu_valid(commit_alu_valid),
        .commit_alu_rob_id(commit_alu_rob_id),
        .commit_ls_valid(commit_ls_valid),
        .commit_ls_rob_id(commit_ls_rob_id),
        .commit_branch_valid(commit_branch_valid),
        .commit_branch_rob_id(commit_branch_rob_id)
    );

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
        .dispatch_valid(dispatch_valid),
        .dispatch_rob_0(dispatch_rob_0),
        .rob_id_0(rob_id_0),
        .dispatch_rob_1(dispatch_rob_1),
        .rob_id_1(rob_id_1),
        .commit_alu_valid(commit_alu_valid),
        .commit_alu_rob_id(commit_alu_rob_id),
        .commit_ls_valid(commit_ls_valid),
        .commit_ls_rob_id(commit_ls_rob_id),
        .commit_branch_valid(commit_branch_valid),
        .commit_branch_rob_id(commit_branch_rob_id),
        // outputs to backend/architectural state
        .rd_arch_commit(rd_arch_commit),
        .rd_phy_new_commit(rd_phy_new_commit),
        .rd_phy_old_commit(rd_phy_old_commit),
        .retire_valid(retire_valid),
        .store_valid(store_valid)
    );

    StoreQueue #(ADDR_WIDTH, DATA_WIDTH, QUEUE) StoreQueue_Unit(
        .clk(clk),
        .rst(rst),
        .wb_valid(wb_en_ls[1]),
        .waddr_wb(waddr_wb),
        .wdata_wb(wdata_wb),
        .store_valid(store_valid),
        .mem_write_en(mem_write_en),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata)
    );

    Back_RAT #(ARCH_REGS, PHY_WIDTH) Back_RAT_Unit(
        .clk(clk),
        .rst(rst),
        .flush(),
        .stall(),
        .rd_arch_commit(rd_arch_commit),
        .rd_phy_new_commit(rd_phy_new_commit),
        .retire_valid(retire_valid),
        .back_rat(back_rat)
    );

    PhysicalRegister #(DATA_WIDTH, PHY_REGS) PRF(
        .clk(clk),
        .rst(rst),
        .stall(),
        .flush(),
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
        .valid_alu(valid_alu),
        // load/store 
        .rs1_phy_ls(rs1_phy_ls),
        .rs2_phy_ls(rs2_phy_ls),
        .rs1_data_ls(rs1_data_ls),
        .rs2_data_ls(rs2_data_ls),
        .valid_ls(valid_ls),
        // branch
        .rs1_phy_branch(rs1_phy_branch),
        .rs2_phy_branch(rs2_phy_branch),
        .rs1_data_branch(rs1_data_branch),
        .rs2_data_branch(rs2_data_branch),
        .valid_branch(valid_branch),
        // =========== writeback interface =================
        .wb_en_alu(wb_en_alu),
        .rd_wb_alu(rd_phy_alu_wb),
        .alu_output(alu_output_wb),
        .wb_en_ls(wb_en_ls),
        .rd_wb_ls(rd_phy_ls_wb),
        .memory_output(memory_output_wb),
        .wb_en_branch(wb_en_branch),
        .rd_wb_branch(rd_phy_branch_wb),
        .nextPC(nextPC_wb),
        // =========== commit interface =================
        .rd_phy_old_commit(rd_phy_old_commit),
        .rd_phy_new_commit(rd_phy_new_commit),
        .retire_valid(retire_valid)
    );


    // ============= Debug Tasks ==================

    always_ff @(posedge clk) begin
        if(rst) 
            $display("\n\n============ Resetting CPU ============\n\n");
        else begin
            // print debug information at each stage
            $display("*************************** Cycle %0d *************************", $time/10);
            print_Fetch();
            print_Rename();
            print_Dispatch();
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
        $display("\t------------ Decode / Rename Stage ------------");
        $display("\t===============================================");
        if(rename_valid == 2'b00) begin
            $display("\t\tNo valid instructions renamed.");
        end
        else begin
            $display("\t\tRenamed %2d valid instructions.", rename_valid-1);
            if(rename_valid[0]) begin
                $display("\tRenamed Instruction 0: PC=0x%h, ROB_ID=%0d, RD_PHY_NEW=%0d", rename_instruction_0.instruction_addr, rename_rob_id_0, rename_instruction_0.rd_addr);
            end

            if(rename_valid[1]) begin
                $display("\tRenamed Instruction 1: PC=0x%h, ROB_ID=%0d, RD_PHY_NEW=%0d", rename_instruction_1.instruction_addr, rename_rob_id_1, rename_instruction_1.rd_addr);
            end
        end
    endtask : print_Rename

    task print_Dispatch();
        $display("\n\t===============================================");
        $display("\t----------- Decode / Dispatch Stage -----------");
        $display("\t===============================================");
        if(issue_alu_valid == 0 && issue_ls_valid == 0 && issue_branch_valid == 0) begin
            if(rename_valid == 2'b00)
                $display("\t\tNo valid instructions issued.");
            else
                $display("\t Stored in Reservations but none issued this cycle.");
        end
        else begin
            $display("\tIssued Instructions:");
            if(issue_alu_valid) begin
                $display("\tALU Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_alu.addr, issue_instruction_alu.rob_id);
            end
            if(issue_ls_valid) begin
                if(issue_instruction_ls.opcode == LOAD)
                    $display("\tLoad Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_ls.addr, issue_instruction_ls.rob_id);
                else
                    $display("\tStore Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_ls.addr, issue_instruction_ls.rob_id);
            end
            if(issue_branch_valid) begin
                $display("\tBranch Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_branch.addr, issue_instruction_branch.rob_id);
            end
        end
    endtask : print_Dispatch

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

        if(!retire_valid) begin
            $display("\t\tNo valid instructions committed.");
        end
        else begin
            $display("\tCommitted Instruction: RD_ARCH=%0d, RD_PHY=%0d", rd_arch_commit, rd_phy_commit);
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
