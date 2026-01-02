`timescale 1ns / 1ps
import parameter_pkg::*;
import register_pkg::*;
import debug_pkg::*;

module DecodeDispatch_tb();
    logic clk;
    logic rst;
    logic isJump;
    logic [ADDR_WIDTH-1:0] jump_address;

    // ============= Instruction Fetch ===================
    logic [ADDR_WIDTH-1:0]instruction_addr_0, instruction_addr_1;
    logic [DATA_WIDTH-1:0]instruction_0, instruction_1;
    logic [1:0] instruction_valid;

    InstructionFetch #(ADDR_WIDTH, DATA_WIDTH) IF(
        .clk(clk),
        .rst(rst),
        .isJump(isJump),
        .start_addr(0),
        .jump_address(jump_address),
        .instruction_addr_0(instruction_addr_0),
        .instruction_addr_1(instruction_addr_1),
        .instruction_0(instruction_0),
        .instruction_1(instruction_1),
        .instruction_valid(instruction_valid)
    );

    // ============= Decode / Rename Stage ==============

    logic [1:0] busy_valid;
    logic [PHY_REGS-1:0] rd_phy_busy_0, rd_phy_busy_1;

    instruction_t rename_instruction_0, rename_instruction_1;
    logic [1:0] rename_valid;
    logic [ROB_WIDTH-1:0] rob_id_0, rob_id_1;

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
        // ======= Physical Register File =================
        .busy_valid(busy_valid),
        .rd_phy_busy_0(rd_phy_busy_0),
        .rd_phy_busy_1(rd_phy_busy_1),
        //====== DecodeRename to ReservationStation====
        .rename_valid(rename_valid),
        .rename_instruction_0(rename_instruction_0),
        .rename_rob_id_0(rob_id_0),
        .rename_instruction_1(rename_instruction_1),
        .rename_rob_id_1(rob_id_1)
    );

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
        .rd_phy_0(rd_phy_old_0),
        // second instruction
        .rs1_arch_1(rs1_arch_1),
        .rs2_arch_1(rs2_arch_1),
        .rd_arch_1(rd_arch_1),
        .rd_phy_new_1(rd_phy_new_1),
        .rs1_phy_1(rs1_phy_1),
        .rs2_phy_1(rs2_phy_1),
        .rd_phy_1(rd_phy_old_1)
    );

    Freelist #(PHY_REGS, PHY_WIDTH) free_list(
        .clk(clk),
        .rst(rst),
        .valid(free_list_valid),
        .rd_phy_new_0(rd_phy_new_0),
        .rd_phy_new_1(rd_phy_new_1)
    );

    ReorderBuffer #(NUM_ROB_ENTRY, ROB_WIDTH, PHY_WIDTH) ROB(
        .clk(clk),
        .rst(rst),
        .dispatch_valid(dispatch_valid),
        .dispatch_rob_0(dispatch_rob_0),
        .rob_id_0(rob_id_0),
        .dispatch_rob_1(dispatch_rob_1),
        .rob_id_1(rob_id_1)
    );

    // ============= Decode / Dispatch Stage ==============
    RS_ENTRY_t issue_instruction_alu, issue_instruction_ls, issue_instruction_branch;
    logic issue_alu_valid, issue_ls_valid, issue_branch_valid;
    logic [PHY_REGS-1:0]PRF_busy;
    assign PRF_busy = {PHY_REGS{1'b0}};
    Dispatch #(NUM_RS_ENTRIES, ROB_WIDTH, PHY_REGS, PHY_WIDTH) Dispatch_Unit(
        .clk(clk),
        .rst(rst),
        .PRF_busy(PRF_busy),
        .rename_valid(rename_valid),
        .rename_instruction_0(rename_instruction_0),
        .rob_id_0(rob_id_0),
        .rename_instruction_1(rename_instruction_1),
        .rob_id_1(rob_id_1),
        // dispatch --> issue
        .issue_instruction_alu(issue_instruction_alu),
        .issue_instruction_ls(issue_instruction_ls),
        .issue_instruction_branch(issue_instruction_branch),
        .issue_alu_valid(issue_alu_valid),
        .issue_ls_valid(issue_ls_valid),
        .issue_branch_valid(issue_branch_valid)
    );


    always #5 clk = ~clk; // Clock generation

    initial begin
        $dumpfile("DecodeDispatch_tb.vcd");
        $dumpvars(0, DecodeDispatch_tb);
    end

    initial begin
        // Testbench initialization and stimulus code
        clk = 0;
        rst = 1;
        $display("\n=========== Simulation started ===========");

        #10; rst = 0;
    end


    logic [7:0]n_cycles;
    always@(posedge clk)begin
        if(rst) begin
            n_cycles <= 0;
        end
        else if(n_cycles < 10)begin
            n_cycles <= n_cycles + 1;
        end
        else begin
            $display("\n=========== Simulation ended ===========");
            $finish;
        end
    end


    always@(posedge clk) begin
        if(!rst && rename_valid[0]) begin
            printed_dispatch_instruction(rename_instruction_0, rename_valid[0]);

        end
        if(!rst && rename_valid[1]) begin
            printed_dispatch_instruction(rename_instruction_1, rename_valid[1]);
        end
        if(!rst && issue_alu_valid) begin
            printed_issue_instruction(issue_instruction_alu, issue_alu_valid, 2'd0);
        end
        if(!rst && issue_ls_valid) begin
            printed_issue_instruction(issue_instruction_ls, issue_ls_valid, 2'd1);
        end
        if(!rst && issue_branch_valid) begin
            printed_issue_instruction(issue_instruction_branch, issue_branch_valid, 2'd2);
        end

        $display("---------------------------------------------------");
    end


    task printed_dispatch_instruction(
        input instruction_t instr,
        input logic valid
    );

        integer fh, ret, a, b;
        string line;
        logic [4:0] phy_turn_arch[0:63];

        for (int i = 0; i < 64; i++) begin
            phy_turn_arch[i] = i; // default mapping (or set to some invalid value)
        end

        // Open file (use relative or absolute path as appropriate)
        
        fh = $fopen("Front_RAT.txt", "r"); // prefer an extension, adjust path if necessary
        if (fh == 0) begin
            // File not present yet; print a warning and continue with default mapping
            $display("[%0t] Warning: Front_RAT file not found; using default RAT mapping", $time);
        end else begin
            // Read lines robustly using $fgets. ret == 0 indicates EOF in many sims.
            // Use a safety bound to avoid any accidental infinite loop in case of simulator differences.
            for (int iter = 0; iter < 1024; iter++) begin
                ret = $fgets(line, fh);
                if (ret == 0) begin
                    // EOF or read error
                    break;
                end
                // skip empty or whitespace-only lines
                if (line.len() == 0) continue;
                // try parsing two integers: arch_index phy_index
                if ($sscanf(line, "%d %d", a, b) == 2) begin
                    if (b >= 0 && b < 64) begin
                        phy_turn_arch[b] = a; // assign parsed phy index
                    end
                end
            end
            $fclose(fh);
        end
        
        if (valid) begin
            string instr_str;
            instr.rs1_addr = (instr.rs1_addr == 5'd0) ? 5'd0 : phy_turn_arch[instr.rs1_addr];
            instr.rs2_addr = (instr.rs2_addr == 5'd0) ? 5'd0 : phy_turn_arch[instr.rs2_addr];
            instr.rd_addr  = (instr.rd_addr == 5'd0) ? 5'd0 : phy_turn_arch[instr.rd_addr];
            instr_str = instruction_brief_name(instr);
            $display("%s", instr_str);
        end else begin
            $display("No valid instruction dispatched.");
        end

    endtask

    task printed_issue_instruction(
        input RS_ENTRY_t instr,
        input logic valid,
        input [1:0] issue_type // 0: ALU, 1: LS, 2: Branch
    );

        integer fh, ret, a, b;
        string line;
        
        if (valid) begin
            string instr_str;
            instr_str = rs_issue_instruction(instr, issue_type);
            $display("%s", instr_str);
        end else begin
            $display("No valid instruction issued.");
        end

    endtask
endmodule 

