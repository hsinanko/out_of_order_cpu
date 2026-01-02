`timescale 1ns / 1ps
import parameter_pkg::*;
import register_pkg::*;
import debug_pkg::*;

module DecodeRename_tb();
    
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
    logic rename_valid_0, rename_valid_1;
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
        .rename_instruction_0(rename_instruction_0),
        .rename_valid_0(rename_valid_0),
        .rename_rob_id_0(rob_id_0),
        .rename_instruction_1(rename_instruction_1),
        .rename_valid_1(rename_valid_1),
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


    always #5 clk = ~clk; // Clock generation

    initial begin
        $dumpfile("DecodeRename_tb.vcd");
        $dumpvars(0, DecodeRename_tb);
    end

    initial begin
        // Testbench initialization and stimulus code
        clk = 0;
        rst = 1;
        $display("\n=========== Simulation started ===========");

        #10 rst = 0;
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
        if(!rst && rename_valid_0) begin
            printed_dispatch_instruction(rename_instruction_0, rename_valid_0);

        end
        if(!rst && rename_valid_1) begin
            printed_dispatch_instruction(rename_instruction_1, rename_valid_1);
        end
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

        fh = $fopen("../build/Front_RAT.txt", "r"); // prefer an extension, adjust path if necessary
        if (fh == 0) $fatal("[%0t] Cannot open Front_RAT.txt - check path (cwd) and filename", $time);

        // Read lines robustly using $fgets. ret == 0 indicates EOF in many sims.
        while (1) begin
            ret = $fgets(line, fh);
            if (ret == 0) begin
                // EOF or read error
                break;
            end
            // skip empty or whitespace-only lines
            if (line.len() == 0) continue;
            // try parsing two integers: arch_index phy_index
            if ($sscanf(line, "%d %d", a, b) == 2) begin
                phy_turn_arch[b] = a; // assign parsed phy index
            end
        end

        $fclose(fh);
        
        if (valid) begin
            string instr_str;
            instr.rs1_addr = (instr.rs1_addr == 6'd0) ? 6'd0 : phy_turn_arch[instr.rs1_addr];
            instr.rs2_addr = (instr.rs2_addr == 6'd0) ? 6'd0 : phy_turn_arch[instr.rs2_addr];
            instr.rd_addr  = (instr.rd_addr == 6'd0) ? 6'd0 : phy_turn_arch[instr.rd_addr];
            instr_str = instruction_brief_name(instr);
            $display("%s", instr_str);
        end else begin
            $display("No valid instruction dispatched.");
        end

    endtask

endmodule

