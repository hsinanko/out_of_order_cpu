`timescale 1ns / 1ps

module Freelist #(parameter PHY_REGS = 64, PHY_WIDTH = 6)(
    input logic clk, 
    input logic rst,
    input logic [1:0]valid,
    output logic [PHY_WIDTH-1:0] rd_phy_new_0,           // physical register address to allocate
    output logic [PHY_WIDTH-1:0] rd_phy_new_1,            // physical register address to allocate
    // commit interface to free physical registers (handled in Back_RAT
    input logic [2:0]free_valid,
    input logic [PHY_WIDTH-1:0] rd_phy_free_0,
    input logic [PHY_WIDTH-1:0] rd_phy_free_1,
    input logic [PHY_WIDTH-1:0] rd_phy_free_2
);
    integer i;
    logic [PHY_WIDTH-1:0] FREELIST [0:PHY_REGS-2]; 
    logic [PHY_WIDTH-1:0] head;                         // points to the next free entry
    logic [PHY_WIDTH-1:0] tail;                         // points to the next allocated entry
    logic [PHY_WIDTH-1:0] num_free;                     // number of free entries

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            for (i = 0; i < PHY_REGS-1; i = i + 1) begin // minus one for PHY_ZERO
                FREELIST[i] <= i; // initialize freelist with all physical registers
                head        <= 0;
                tail        <= PHY_REGS-2;
                num_free    <= PHY_REGS-1;
            end
        end
        else begin
            // Allocate physical registers for renaming
            if(valid == 2'b11) begin
                head     <= head + 2;
                num_free <= num_free - 2;
            end
            else if(valid == 2'b01 || valid == 2'b10) begin
                head     <= head + 1;
                num_free <= num_free -1;
            end
            else begin
                head     <= head;
                num_free <= num_free;
            end


            if(free_valid == 3'b111) begin
                FREELIST[tail + 1] <= rd_phy_free_0 - 1; // -1 to skip PHY_ZERO
                FREELIST[tail + 2] <= rd_phy_free_1 - 1; // -1 to skip PHY_ZERO
                FREELIST[tail + 3] <= rd_phy_free_2 - 1; // -1 to skip PHY_ZERO
                tail               <= tail + 3;
                num_free          <= num_free + 3;
            end
            else if(free_valid[1:0] == 2'b11) begin
                FREELIST[tail + 1] <= rd_phy_free_0 - 1; // -1 to skip PHY_ZERO
                FREELIST[tail + 2] <= rd_phy_free_1 - 1; // -1 to skip PHY_ZERO
                tail               <= tail + 2;
                num_free          <= num_free + 2;
            end
            else if(free_valid[0] == 1'b1) begin
                FREELIST[tail + 1] <= rd_phy_free_0 - 1; // -1 to skip PHY_ZERO
                tail               <= tail + 1;
                num_free          <= num_free + 1;
            end
            else begin
                tail     <= tail;
                num_free <= num_free;
            end
        end
    end

    assign rd_phy_new_0 = (valid[0]) ? FREELIST[head]+1 : 'hx;        // +1 to skip PHY_ZERO
    assign rd_phy_new_1 = (valid[1]) ? ((valid[0]) ? FREELIST[head + 1]+1 : FREELIST[head]+1) : 'hx;    // +1 to skip PHY_ZERO


    // For debugging: dump Freelist contents at each clock cycle
    integer           mcd;
    logic [PHY_WIDTH-1:0] j;
    always_ff @(negedge clk) begin
        mcd = $fopen("./build/Freelist.txt","w");

        for(j = head; j != tail; j = j + 1) begin
            $fdisplay(mcd,"%3d", FREELIST[j]);
        end
        $fdisplay(mcd,"%3d", FREELIST[tail]);
        
        $fclose(mcd);
        //$display("Freelist contents dumped to Freelist file at time %0t", $time);
    end

endmodule 
