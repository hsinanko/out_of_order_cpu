`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;

module Issue #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5)(
    input  logic clk,
    input  logic rst,
    input  logic [ADDR_WIDTH-1:0]instruction_addr,
    input  logic [DATA_WIDTH-1:0]instruction,
    // from decode/dispatch
    input  RS_ENTRY_t issue_instruction_alu,
    input  RS_ENTRY_t issue_instruction_ls,
    input  RS_ENTRY_t issue_instruction_branch,
    input  logic issue_alu_valid,
    input  logic issue_ls_valid,
    input  logic issue_branch_valid,
    // output logic issue_alu_en,
    // output logic issue_ls_en,
    // output logic issue_branch_en,
    // output to physical registerfile
    output logic [PHY_WIDTH-1:0]rs1_phy_alu,               
    output logic [PHY_WIDTH-1:0]rs2_phy_alu, 
    input  logic [DATA_WIDTH-1:0]rs1_data_alu,
    input  logic [DATA_WIDTH-1:0]rs2_data_alu,
    output logic valid_alu,
    output logic [PHY_WIDTH-1:0]rs1_phy_ls,               
    output logic [PHY_WIDTH-1:0]rs2_phy_ls,
    input  logic [DATA_WIDTH-1:0]rs1_data_ls,
    input  logic [DATA_WIDTH-1:0]rs2_data_ls,
    output logic valid_ls,
    output logic [PHY_WIDTH-1:0]rs1_phy_branch,               
    output logic [PHY_WIDTH-1:0]rs2_phy_branch, 
    input  logic [DATA_WIDTH-1:0]rs1_data_branch,
    input  logic [DATA_WIDTH-1:0]rs2_data_branch,
    output logic valid_branch,
    // output to execution
    // ALU outputs
    output logic [ROB_WIDTH-1:0]alu_rob_id_reg,
    output logic [DATA_WIDTH-1:0] alu_output_reg,
    output logic [PHY_WIDTH-1:0]rd_phy_alu_reg,
    output logic alu_valid_reg,
    // Load/Store outputs
    output logic [ROB_WIDTH-1:0]ls_rob_id_reg,
    output logic mem_read_en_reg,
    output logic [4:0]mem_funct3_reg,
    output logic [ADDR_WIDTH-1:0]raddr_reg,
    output logic [PHY_WIDTH-1:0]rd_phy_ls_reg,
    output logic [DATA_WIDTH-1:0] wdata_reg,
    output logic [ADDR_WIDTH-1:0] waddr_reg,
    output logic wdata_valid_reg,
    output logic ls_valid_reg,
    // Branch outputs
    output logic [ROB_WIDTH-1:0]branch_rob_id_reg,
    output logic [ADDR_WIDTH-1:0] jumpPC_reg,
    output logic [ADDR_WIDTH-1:0] nextPC_reg,
    output logic [PHY_WIDTH-1:0]rd_phy_branch_reg,
    output logic isJump_reg,
    output logic branch_valid_reg
);

    // assign issue_alu_en = 1;    // can be extended FIFO to avoid stuck
    // assign issue_ls_en = 1;     // can be extended FIFO to avoid stuck
    // assign issue_branch_en = 1; // can be extended FIFO to avoid stuck

    RS_ENTRY_t issue_instruction_alu_fifo;
    RS_ENTRY_t issue_instruction_ls_fifo;
    RS_ENTRY_t issue_instruction_branch_fifo;
    logic issue_alu_valid_fifo;
    logic issue_ls_valid_fifo;
    logic issue_branch_valid_fifo;

    always_comb begin
        issue_instruction_alu_fifo    = issue_instruction_alu;
        issue_instruction_ls_fifo     = issue_instruction_ls;
        issue_instruction_branch_fifo = issue_instruction_branch;
        issue_alu_valid_fifo          = issue_alu_valid;
        issue_ls_valid_fifo           = issue_ls_valid;
        issue_branch_valid_fifo       = issue_branch_valid;
    end
    

    // ALU outputs
    logic [ROB_WIDTH-1:0]alu_rob_id;
    logic [DATA_WIDTH-1:0] alu_output;
    logic [PHY_WIDTH-1:0]rd_phy_alu;
    // Load/Store outputs
    logic [ROB_WIDTH-1:0]ls_rob_id;
    logic mem_read_en;
    logic [4:0]mem_funct3;
    logic [ADDR_WIDTH-1:0]raddr;
    logic [PHY_WIDTH-1:0]rd_phy_ls;
    logic [DATA_WIDTH-1:0] wdata;
    logic [ADDR_WIDTH-1:0] waddr;
    logic wdata_valid;
    // Branch outputs
    logic [ROB_WIDTH-1:0]branch_rob_id;
    logic [ADDR_WIDTH-1:0] jumpPC;
    logic [ADDR_WIDTH-1:0] nextPC;
    logic [PHY_WIDTH-1:0]rd_phy_branch;
    logic isJump;

    Execution #(ADDR_WIDTH, DATA_WIDTH, ROB_WIDTH, PHY_WIDTH) execution_unit(
        .instruction_addr(instruction_addr),
        .instruction(instruction),
        // from issue stage
        .issue_instruction_alu(issue_instruction_alu_fifo),
        .issue_instruction_ls(issue_instruction_ls_fifo),
        .issue_instruction_branch(issue_instruction_branch_fifo),
        .issue_alu_valid(issue_alu_valid_fifo),
        .issue_ls_valid(issue_ls_valid_fifo),
        .issue_branch_valid(issue_branch_valid_fifo),
        // read data from physical register
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
        // output to commit stage
        .alu_rob_id(alu_rob_id),
        .alu_output(alu_output),
        .rd_phy_alu(rd_phy_alu),
        // Load/Store outputs
        .ls_rob_id(ls_rob_id),
        .mem_read_en(mem_read_en),
        .mem_funct3(mem_funct3),
        .raddr(raddr),
        .rd_phy_ls(rd_phy_ls),
        .wdata(wdata),
        .waddr(waddr),
        .wdata_valid(wdata_valid),
        // Branch outputs
        .branch_rob_id(branch_rob_id),
        .jump_address(jumpPC),
        .next_address(nextPC),
        .rd_phy_branch(rd_phy_branch),
        .isJump(isJump)
    );
    assign mem_read_en_reg = mem_read_en;
    assign mem_funct3_reg  = mem_funct3;
    assign raddr_reg       = raddr;
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
        end else begin
            // alu outputs
            if(issue_alu_valid) begin
                alu_rob_id_reg   <= alu_rob_id;
                alu_output_reg   <= alu_output;
                rd_phy_alu_reg   <= rd_phy_alu;
            end
            else begin
                alu_rob_id_reg   <= 0;
                alu_output_reg   <= 0;
                rd_phy_alu_reg   <= 0;
            end
            alu_valid_reg        <= issue_alu_valid;
            // Load/Store outputs
            if(issue_ls_valid) begin
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
            ls_valid_reg         <= issue_ls_valid;

            // Branch outputs
            if(issue_branch_valid) begin
                branch_rob_id_reg <= branch_rob_id;
                jumpPC_reg        <= jumpPC;
                nextPC_reg        <= (instruction_addr + 'h4);
                rd_phy_branch_reg <= rd_phy_branch;
                isJump_reg        <= isJump;
            end
            else begin
                branch_rob_id_reg <= 0;
                jumpPC_reg        <= 0;
                nextPC_reg        <= 0;
                rd_phy_branch_reg <= 0;
                isJump_reg        <= 0;
            end
            branch_valid_reg      <= issue_branch_valid;
        end
    end

endmodule
