`timescale 1ns / 1ps

import parameter_pkg::*;
import typedef_pkg::*;

module PhysicalRegister #(parameter REG_WIDTH = 32, PHY_REGS = 64, DATA_WIDTH = 32, PHY_WIDTH = 6)(
    input  logic clk,
    input  logic rst,
    input  logic stall,
    input  logic flush,
    // ========= rename interface ====================
    input  logic [1:0]busy_valid,
    input  logic [REG_WIDTH-1:0]rd_phy_busy_0,   // mark rd_phy busy
    input  logic [REG_WIDTH-1:0]rd_phy_busy_1,   // mark rs1_phy busy
    output logic [PHY_REGS-1:0]PRF_busy,         // if busy = 1 => this register is not ready
    // ========= read execution interface ===============
    output logic [PHY_REGS-1:0]PRF_valid,
    // alu
    input  logic [PHY_WIDTH-1:0]rs1_phy_alu,               
    input  logic [PHY_WIDTH-1:0]rs2_phy_alu,
    output logic [DATA_WIDTH-1:0]rs1_data_alu,
    output logic [DATA_WIDTH-1:0]rs2_data_alu,
    input  logic valid_alu,
    // load/store
    input  logic [PHY_WIDTH-1:0]rs1_phy_ls,               
    input  logic [PHY_WIDTH-1:0]rs2_phy_ls,
    output logic [DATA_WIDTH-1:0]rs1_data_ls,
    output logic [DATA_WIDTH-1:0]rs2_data_ls,
    input  logic valid_ls,
    // branch
    input  logic [PHY_WIDTH-1:0]rs1_phy_branch,               
    input  logic [PHY_WIDTH-1:0]rs2_phy_branch,
    output logic [DATA_WIDTH-1:0]rs1_data_branch,
    output logic [DATA_WIDTH-1:0]rs2_data_branch,
    input  logic valid_branch,
    // =========== writeback interface =================
    // alu commit interface
    input  logic wb_en_alu,                      // commit enable signal
    input  logic [PHY_WIDTH-1:0]rd_wb_alu,                 // physical register address to commit
    input  logic [REG_WIDTH-1:0] alu_output,     // data to writ
    // load/store commit interface
    input  logic wb_en_ls,                       // commit enable signal
    input  logic [PHY_WIDTH-1:0]rd_wb_ls,                  // physical register address to commit
    input  logic [REG_WIDTH-1:0] memory_output, // data to write
    // branch commit interface
    input  logic wb_en_branch,                   // commit enable signal
    input  logic [PHY_WIDTH-1:0]rd_wb_branch,              // physical register address to commit
    input  logic [REG_WIDTH-1:0] nextPC, // data to write
    // ============= commit /retire interface ====================
    input logic [PHY_WIDTH-1:0]rd_phy_old_commit,
    input logic [PHY_WIDTH-1:0]rd_phy_new_commit,
    input logic retire_valid
);
    // Physical Register file
    // | Tag | Architected Reg | Data | Valid | Busy |
    integer i;
    logic [DATA_WIDTH-1:0] PRF [0:PHY_REGS-1];

    // ========== Decode/Rename stage (read data from PRF) =========


    // ========== execution stage (read data from PRF) =========
    assign rs1_data_alu = (valid_alu) ? PRF[rs1_phy_alu] : 'hx;
    assign rs2_data_alu = (valid_alu) ? PRF[rs2_phy_alu] : 'hx;

    assign rs1_data_ls = (valid_ls) ? PRF[rs1_phy_ls] : 'hx;
    assign rs2_data_ls = (valid_ls) ? PRF[rs2_phy_ls] : 'hx;

    assign rs1_data_branch = (valid_branch) ? PRF[rs1_phy_branch] : 'hx;
    assign rs2_data_branch = (valid_branch) ? PRF[rs2_phy_branch] : 'hx;

    // ============== commit stage =====================

    always_ff @(negedge clk or posedge rst)begin
        if(rst)begin
            for(i = 0; i < PHY_REGS; i = i+1)begin
                PRF[i] <= 'h0;
            end
            PRF_busy  <= 'h0;
            PRF_valid <= {PHY_REGS{1'b1}};
        end
        else if(!stall && !flush)begin

            if(busy_valid[0])begin
                PRF_busy[rd_phy_busy_0]  <= 1;
                PRF_valid[rd_phy_busy_0] <= 0;
            end
            if(busy_valid[1])begin
                PRF_busy[rd_phy_busy_1]  <= 1;
                PRF_valid[rd_phy_busy_1] <= 0;
            end

            if(wb_en_alu)begin
                PRF[rd_wb_alu]       <= alu_output;
                PRF_valid[rd_wb_alu] <= 1;
            end
            if(wb_en_ls)begin
                PRF[rd_wb_ls]       <= memory_output;
                PRF_valid[rd_wb_ls] <= 1;
            end
            if(wb_en_branch)begin
                PRF[rd_wb_branch]       <= nextPC;
                PRF_valid[rd_wb_branch] <= 1;
            end

            if(retire_valid) begin
                if(!PRF_busy[rd_phy_old_commit])begin
                    PRF_valid[rd_phy_old_commit] <= 0;
                    PRF_busy[rd_phy_new_commit]  <= 0;
                end
                else begin
                    PRF_busy[rd_phy_new_commit]  <= 0;
                end
            end
        end
    end


    // For debugging: display PRF contents
    integer           mcd;
    always_ff @(negedge clk) begin
        mcd = $fopen("./build/PhysicalRegister.txt","w");
        $fdisplay(mcd,"Physical Register File Contents:");
        $fdisplay(mcd,"Index |    Data    | Busy | Valid");
        for (i = 0; i < PHY_REGS; i = i + 1) begin
            $fdisplay(mcd, "  %2d  | 0x%h |  %b   |  %b", i, PRF[i], PRF_busy[i], PRF_valid[i]);
        end
        $fdisplay(mcd,"---------------------------------------------------");
        $fclose(mcd);
    end

endmodule


