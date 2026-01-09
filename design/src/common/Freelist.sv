`timescale 1ns / 1ps

module Freelist #(parameter ARCH_REGS = 32, PHY_REGS = 64, PHY_WIDTH = 6, FREE_REG = 32)(
    input logic clk, 
    input logic rst,
    input logic flush,
    input logic done,
    output logic full,
    output logic empty,
    // rename interface to allocate physical registers
    input logic [1:0]valid,
    output logic [PHY_WIDTH-1:0] rd_phy_new_0,           // physical register address to allocate
    output logic [PHY_WIDTH-1:0] rd_phy_new_1,            // physical register address to allocate
    // commit interface to free physical registers (handled in Back_RAT
    input logic retire_valid,
    input logic [PHY_WIDTH-1:0] rd_phy_old_commit,
    input logic [PHY_WIDTH-1:0] rd_phy_new_commit
);
    integer i;

    logic [PHY_WIDTH-1:0] FREELIST [0:FREE_REG-1]; // stores the list of free physical registers
    logic [$clog2(FREE_REG)-1:0] head;                         // points to the next free entry
    logic [$clog2(FREE_REG)-1:0] tail;                         // points to the next allocated entry
    logic [$clog2(FREE_REG):0] num_free;                     // number of free entries
    
    logic [$clog2(FREE_REG)-1:0] tail_tmp;

    logic [PHY_REGS-1:0] is_busy;

    logic [PHY_WIDTH-1:0] freelist_rebuilt [0:FREE_REG-1];
    assign full  = (num_free == 0);
    assign empty = (num_free == FREE_REG);
    always_latch begin
        for(i = 0; i < PHY_REGS; i = i + 1)begin
            freelist_rebuilt[i] = FREELIST[i];
        end

        if(flush || done) begin
            // On flush, rebuild freelist from PRF_busy
            tail_tmp = tail;
            for (i = 1; i < PHY_REGS; i = i + 1) begin
                if (is_busy[i]) begin
                    freelist_rebuilt[tail_tmp+1] = i;
                    tail_tmp = tail_tmp + 1;
                end
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
            num_free <= FREE_REG;
        end
        else if(flush) begin
            // On flush, reset freelist to initial state
            FREELIST <= freelist_rebuilt;
            head     <= 0;
            tail     <= FREE_REG-1;
            num_free <= FREE_REG;
            is_busy  <= '0;
        end
        else begin
            // Allocate physical registers for renaming
            if(valid == 2'b11) begin
                head     <= head + 2;
                num_free <= num_free - 2;
                is_busy[FREELIST[head]]     <= 1'b1;
                is_busy[FREELIST[head + 1]] <= 1'b1;
            end
            else if(valid == 2'b01 || valid == 2'b10) begin
                head     <= head + 1;
                num_free <= num_free -1;
                is_busy[FREELIST[head]]     <= 1'b1;
            end
            else begin
                head     <= head;
                num_free <= num_free;
            end


            if(retire_valid) begin
            // Free physical registers on commit
                FREELIST[tail + 1] <= rd_phy_old_commit;
                is_busy[rd_phy_new_commit] <= 1'b0;
                tail     <= tail + 1;
                num_free <= num_free + 1;
            end
        end
    end

    assign rd_phy_new_0 = (valid[0]) ? (FREELIST[head]): 'hx;        // +1 to skip PHY_ZERO
    assign rd_phy_new_1 = (valid[1]) ? ((valid[0]) ? (FREELIST[head + 1]) : (FREELIST[head])) : 'hx;    // +1 to skip PHY_ZERO


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
