`timescale 1ns/1ps

module Back_RAT #(parameter ARCH_REGS = 32, PHY_WIDTH = 6)(
    input logic clk,
    input logic rst,
    input logic flush,
    input logic done,
    retire_if.retire_pr_sink retire_pr_bus_0,
    retire_if.retire_pr_sink retire_pr_bus_1,
    output [PHY_WIDTH*ARCH_REGS-1:0]back_rat
);
    logic [PHY_WIDTH-1:0] BACK_RAT [0:ARCH_REGS-1];

    logic [PHY_WIDTH-1:0] BACK_RAT_tmp [0:ARCH_REGS-1];

    logic retire_pr_valid_0, retire_pr_valid_1;
    logic [PHY_WIDTH-1:0] rd_arch_0, rd_arch_1;
    logic [PHY_WIDTH-1:0] rd_phy_old_0, rd_phy_old_1;
    logic [PHY_WIDTH-1:0] rd_phy_new_0, rd_phy_new_1;

    assign retire_pr_valid_0 = retire_pr_bus_0.retire_pr_pkg.retire_pr_valid;
    assign rd_arch_0         = retire_pr_bus_0.retire_pr_pkg.rd_arch;
    assign rd_phy_old_0      = retire_pr_bus_0.retire_pr_pkg.rd_phy_old;
    assign rd_phy_new_0      = retire_pr_bus_0.retire_pr_pkg.rd_phy_new;
    
    assign retire_pr_valid_1 = retire_pr_bus_1.retire_pr_pkg.retire_pr_valid;
    assign rd_arch_1         = retire_pr_bus_1.retire_pr_pkg.rd_arch;
    assign rd_phy_old_1      = retire_pr_bus_1.retire_pr_pkg.rd_phy_old;
    assign rd_phy_new_1      = retire_pr_bus_1.retire_pr_pkg.rd_phy_new;
    
    integer i;
    // generate
    //     for(i = 0; i < ARCH_REGS; i = i + 1) begin : gen_back_rat
    //         // continuous assignment for each slice of the packed output
    //         assign back_rat[i*PHY_WIDTH +: PHY_WIDTH] = BACK_RAT[i];
    //     end
    // endgenerate

    // sequential logic for reset and commit updates
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            back_rat <= 'h0;
            for (i = 0; i < ARCH_REGS; i = i + 1)
                BACK_RAT[i] <= i;
        end
        else if(flush || done) begin
            // On flush, restore BACK_RAT to previous state
            for(i = 0; i < ARCH_REGS; i = i + 1) begin : gen_back_rat
            // continuous assignment for each slice of the packed output
                back_rat[i*PHY_WIDTH +: PHY_WIDTH] = BACK_RAT[i];
        end
        end
        else begin
            BACK_RAT <= BACK_RAT_tmp;
            back_rat <= 'h0;
        end
    end


    always_comb begin
        BACK_RAT_tmp = BACK_RAT;
        if(retire_pr_valid_0) begin
            BACK_RAT_tmp[rd_arch_0] = rd_phy_new_0;
        end
        if(retire_pr_valid_1) begin
            BACK_RAT_tmp[rd_arch_1] = rd_phy_new_1;
        end
    end

        // For debugging: dump RAT contents at each clock cycle
    integer           mcd;

    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/Back_RAT.txt","w");

        for (i=0; i< ARCH_REGS; i=i+1) begin
            $fdisplay(mcd,"%2d %3d", i, BACK_RAT[i]);
        end
        $fclose(mcd);
        //$display("Back_RAT contents dumped to Back_RAT file at time %0t", $time);
    end

endmodule
