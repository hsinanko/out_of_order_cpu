`timescale 1ns/1ps
import parameter_pkg::*;

module Front_RAT #(parameter ARCH_REGS = 32, PHY_WIDTH = 6)(
    input  logic clk,
    input  logic rst,
    // first instruction
    input  logic [1:0]instr_valid,      // instr_valid[0] = first instruction valid, instr_valid[1] = second instruction valid
    input  logic [4:0] rs1_arch_0,      // architected register address
    input  logic [4:0] rs2_arch_0,
    input  logic [4:0] rd_arch_0,
    input  logic [PHY_WIDTH-1:0] rd_phy_new_0,    // physical register address to allocate
    output logic [PHY_WIDTH-1:0] rs1_phy_0,
    output logic [PHY_WIDTH-1:0] rs2_phy_0,
    output logic [PHY_WIDTH-1:0] rd_phy_0,
    // second instruction
    input  logic [4:0] rs1_arch_1,      // architected register address
    input  logic [4:0] rs2_arch_1,
    input  logic [4:0] rd_arch_1,
    input  logic [PHY_WIDTH-1:0] rd_phy_new_1,    // physical register address to allocate
    output logic [PHY_WIDTH-1:0] rs1_phy_1,
    output logic [PHY_WIDTH-1:0] rs2_phy_1,
    output logic [PHY_WIDTH-1:0] rd_phy_1,
    // BACK_RAT will handle commit updates
    input  logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat
);

    // Register Alias Table (RAT)
    logic [PHY_WIDTH-1:0] FRONT_RAT [0:ARCH_REGS-1];
    logic [PHY_WIDTH-1:0] rat_tmp [0:ARCH_REGS-1];
    integer i;
    always_comb begin

        // start from current RAT
        for (i = 0; i < ARCH_REGS; i++)
            rat_tmp[i] = FRONT_RAT[i];
        // -------- Slot 0 rename --------

        rs1_phy_0 = rat_tmp[rs1_arch_0];
        rs2_phy_0 = rat_tmp[rs2_arch_0];
        rd_phy_0  = rat_tmp[rd_arch_0];

        if (instr_valid[0]) begin
            rat_tmp[rd_arch_0] = rd_phy_new_0;
        end

        // -------- Slot 1 rename --------

        rs1_phy_1 = rat_tmp[rs1_arch_1];
        rs2_phy_1 = rat_tmp[rs2_arch_1];
        rd_phy_1  = rat_tmp[rd_arch_1];

        if (instr_valid[1]) begin
            rat_tmp[rd_arch_1] = rd_phy_new_1;
        end

    end


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < ARCH_REGS; i++)
                FRONT_RAT[i] <= i;
        end else begin
            FRONT_RAT <= rat_tmp;
        end
    end


    // Output mapped physical register

    // Second instruction outputs


    // For debugging: dump RAT contents at each clock cycle
    integer           mcd;

    always_ff @(negedge clk) begin
        mcd = $fopen("./build/Front_RAT.txt","w");

        for (i=0; i< ARCH_REGS; i=i+1) begin
            $fdisplay(mcd,"%2d %3d", i, FRONT_RAT[i]);
        end
        $fclose(mcd);
        //$display("Front_RAT contents dumped to Front_RAT file at time %0t", $time);
    end

endmodule
