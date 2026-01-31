`timescale 1ns / 1ps

module Freelist #(parameter ARCH_REGS = 32, PHY_REGS = 64, PHY_WIDTH = 6, FREE_REG = 32)(
    input logic clk, 
    input logic rst,
    input logic flush,
    input logic done,
    output logic full,
    output logic empty,
    // rename interface to allocate physical registers
    rename_if.freelist_sink freelist_0_bus,
    rename_if.freelist_sink freelist_1_bus,
    // commit interface to free physical registers (handled in Back_RAT
    retire_if.retire_pr_sink retire_pr_bus_0,
    retire_if.retire_pr_sink retire_pr_bus_1
);

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

    logic [PHY_WIDTH-1:0] FREELIST [0:FREE_REG-1]; // stores the list of free physical registers
    logic [$clog2(FREE_REG)-1:0] head;                         // points to the next free entry
    logic [$clog2(FREE_REG)-1:0] tail;                         // points to the next allocated entry
    logic [$clog2(FREE_REG):0] num_free;                     // number of free entries
    
    logic [$clog2(FREE_REG)-1:0] head_tmp;
    logic [$clog2(FREE_REG)-1:0] tail_tmp;
    logic [$clog2(FREE_REG):0] num_free_tmp;


    logic [PHY_REGS-1:0] is_busy;

    logic [PHY_WIDTH-1:0] freelist_rebuilt [0:FREE_REG-1];
    assign full  = (num_free == FREE_REG);
    assign empty = (num_free == 0);
 
    always_comb begin
        for(i = 0; i < PHY_REGS; i = i + 1)begin
            freelist_rebuilt[i] = FREELIST[i];
        end
        if(rst || flush) begin
            num_free_tmp = FREE_REG;
            tail_tmp = tail;
            for (i = 1; i < PHY_REGS; i = i + 1) begin
                if (is_busy[i]) begin
                    freelist_rebuilt[tail_tmp+1] = i;
                    tail_tmp = tail_tmp + 1;
                end
            end
            tail_tmp = FREE_REG - 1;
            head_tmp = 0;
        end
        else begin
            num_free_tmp = num_free;
            tail_tmp = tail;
            head_tmp = head;

            if(retire_pr_valid_0)begin
                tail_tmp = tail_tmp + 1;
                freelist_rebuilt[tail_tmp] = rd_phy_old_0;
                num_free_tmp = num_free_tmp + 1;
            end
            if(retire_pr_valid_1) begin
                tail_tmp = tail_tmp + 1;
                freelist_rebuilt[tail_tmp] = rd_phy_old_1;
                num_free_tmp = num_free_tmp + 1;
            end

            if(freelist_0_bus.valid && freelist_1_bus.valid) begin
                head_tmp = head_tmp + 2;
                num_free_tmp = num_free_tmp - 2;
            end
            else if(freelist_0_bus.valid || freelist_1_bus.valid) begin
                head_tmp = head_tmp + 1;
                num_free_tmp = num_free_tmp - 1;
            end
            else begin
                head_tmp = head_tmp;
            end
        end
    end


    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            for (i = 0; i < FREE_REG; i = i + 1) begin // minus one for PHY_ZERO
                FREELIST[i] <= i + FREE_REG; // initialize freelist with all physical registers
            end
            head     <= 0;
            tail     <= FREE_REG-1;
            num_free <= num_free_tmp;
            is_busy  <= '0;
        end
        else if(flush) begin
            // On flush, reset freelist to initial state
            FREELIST <= freelist_rebuilt;
            head     <= 0;
            tail     <= FREE_REG-1;
            num_free <= num_free_tmp;
            is_busy  <= '0;
        end
        else begin
            // Allocate physical registers for renaming
            num_free <= num_free_tmp;
            if(freelist_0_bus.valid && freelist_1_bus.valid) begin
                is_busy[FREELIST[head]]     <= 1'b1;
                is_busy[FREELIST[head + 1]] <= 1'b1;
            end
            else if(freelist_0_bus.valid || freelist_1_bus.valid) begin
                is_busy[FREELIST[head]]     <= 1'b1;
            end

            head     <= head_tmp;
            tail     <= tail_tmp;
            FREELIST <= freelist_rebuilt;
            if(retire_pr_valid_0) begin
            // Free physical registers on commit
                is_busy[rd_phy_new_0] <= 1'b0;
            end
            if(retire_pr_valid_1) begin
            // Free physical registers on commit
                is_busy[rd_phy_new_1] <= 1'b0;
            end

        end
    end


    assign freelist_0_bus.rd_phy_new = (freelist_0_bus.valid) ? (FREELIST[head]): 'hx;        // +1 to skip PHY_ZERO
    assign freelist_1_bus.rd_phy_new = (freelist_1_bus.valid) ? ((freelist_0_bus.valid) ? (FREELIST[head + 1]) : (FREELIST[head])) : 'hx;    // +1 to skip PHY_ZERO


    // For debugging: dump Freelist contents at each clock cycle
    integer           mcd;
    logic [PHY_WIDTH-1:0] j;
    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/Freelist.txt","w");

        for(j = head; j != tail; j = j + 1) begin
            $fdisplay(mcd,"%3d", FREELIST[j]); // +1 to skip PHY_ZERO
        end
        $fdisplay(mcd,"%3d", FREELIST[tail]); // +1 to skip PHY_ZERO
        
        $fclose(mcd);
        //$display("Freelist contents dumped to Freelist file at time %0t", $time);
    end

endmodule 