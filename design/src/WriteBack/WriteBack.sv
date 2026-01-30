`timescale 1ns/1ps


module WriteBack #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5, FIFO_DEPTH = 16)(
    input logic clk,
    input logic rst,
    input logic flush,
    // ============== from Execution (enqueue candidates) =================
    input EXE_alu_t   exe_alu,
    input EXE_branch_t exe_branch,
    // ========== Physical Register & ROB Commit Interface  ===========
    output WB_alu_t    wb_alu,
    output WB_branch_t wb_branch
);

    always_comb begin
        // commit signals to ROB
        wb_alu.alu_valid      = (flush) ? 1'b0 : exe_alu.alu_valid;
        wb_alu.alu_rob_id     = exe_alu.alu_rob_id;
        wb_alu.rd_alu         = exe_alu.rd_phy_alu;
        wb_alu.alu_result     = exe_alu.alu_result;
        // branch
        wb_branch.branch_valid   = (flush) ? 1'b0 : exe_branch.branch_valid;
        wb_branch.jump_valid     = (flush) ? 1'b0 : exe_branch.jump_valid;
        wb_branch.branch_rob_id  = exe_branch.branch_rob_id;
        wb_branch.rd_branch      = exe_branch.rd_phy_branch;
        wb_branch.nextPC         = exe_branch.nextPC;
        wb_branch.mispredict     = exe_branch.mispredict;
        wb_branch.actual_target  = exe_branch.actual_target;
        wb_branch.actual_taken   = exe_branch.actual_taken;
        wb_branch.update_pc      = exe_branch.update_pc;
    end

endmodule

