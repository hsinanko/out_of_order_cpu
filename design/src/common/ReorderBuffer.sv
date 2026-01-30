`timescale 1ns/1ps

import instruction_pkg::*;
import typedef_pkg::*;

module ReorderBuffer #(parameter NUM_ROB_ENTRY = 16, ROB_WIDTH = 4, PHY_WIDTH = 6, FIFO_DEPTH = 16)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  flush,
    // rename/dispatch
    input  ROB_ENTRY_t           rob_entry_0,         // entry to be added
    output logic [ROB_WIDTH-1:0] rob_id_0,
    // second instruction
    input  ROB_ENTRY_t           rob_entry_1,         // entry to be added
    output logic [ROB_WIDTH-1:0] rob_id_1,

    // commit 
    input WB_alu_t wb_alu,
    input WB_store_t wb_store,
    input WB_load_t wb_load,
    input WB_branch_t wb_branch,
    // ROB status
    rob_status_if.source rob_status
    // debugging interface
);

    ROB_ENTRY_t ROB[NUM_ROB_ENTRY-1:0];
    logic [NUM_ROB_ENTRY-1:0]       ROB_FINISH;

    logic [ROB_WIDTH:0] count;
    logic [ROB_WIDTH-1:0] head;
    logic [ROB_WIDTH-1:0] tail;
    
    assign rob_id_0 = (rob_entry_0.valid) ? tail : {ROB_WIDTH{1'b0}};
    assign rob_id_1 = (rob_entry_1.valid) ? ((rob_entry_0.valid) ? tail + 4'd1 : tail) : {ROB_WIDTH{1'b0}};
    integer i;

    assign rob_status.rob_finish = ROB_FINISH;
    assign rob_status.rob = ROB;
    assign rob_status.rob_head = head;
    assign rob_status.rob_full = (count >= NUM_ROB_ENTRY-2);
    assign rob_status.rob_empty = (count == 0);
    
    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            for(i = 0; i < NUM_ROB_ENTRY; i = i + 1)begin
                ROB[i].rd_arch        <= 'h0;
                ROB[i].rd_phy_old     <= 'h0;
                ROB[i].rd_phy_new     <= 'h0;
                ROB[i].opcode         <= 'h0;
                ROB[i].actual_target  <= 'h0;
                ROB[i].actual_taken   <= 1'b0;
                ROB[i].update_pc      <= 'h0;
                ROB[i].mispredict     <= 1'b0;
                ROB[i].store_id       <= 'h0;
                ROB[i].valid          <= 1'b0;
                // debugging info
                ROB[i].addr           <= 'h0;
            end
            count <= 0;
            tail  <= 0;
        end
        else if(flush)begin
            tail  <= 0;
            count <= 0;
        end
        else if(rob_entry_0.valid && rob_entry_1.valid)begin
            ROB[tail]   <= rob_entry_0;
            ROB[tail+1] <= rob_entry_1;
            tail      <= tail + 2;
            count     <= count + 2;
        end
        else if(rob_entry_0.valid && !rob_entry_1.valid)begin
            ROB[tail] <= rob_entry_0;
            tail      <= tail + 1;
            count     <= count + 1;
        end
        else if(!rob_entry_0.valid && rob_entry_1.valid)begin
            ROB[tail] <= rob_entry_1;
            tail      <= tail + 1;
            count     <= count + 1;
        end
        else if(ROB_FINISH[head]) begin
            // when committing instructions
            tail  <= tail;
            count <= count - 1;
        end
        else begin
            tail  <= tail;
            count <= count;
        end
    end

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            head <= 0;
        end
        else if(flush) begin
            head <= 0;
        end
        else if(ROB_FINISH[head]) begin
            if(rob_status.retire_num == 2) begin
                ROB_FINISH[head]   <= 1'b0;
                ROB_FINISH[head+1] <= 1'b0;
                head <= head + 2;
            end
            else begin
                ROB_FINISH[head] <= 1'b0;
                head <= head + 1;
            end
        end
        else begin 
            head <= head;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            ROB_FINISH <= 'b0;
        end
        else if(flush) begin
            ROB_FINISH <= 'b0;
        end
        else begin
            if(wb_alu.alu_valid) begin
                ROB_FINISH[wb_alu.alu_rob_id] <= 1'b1;
            end
            if(wb_load.load_valid) begin
                ROB_FINISH[wb_load.load_rob_id] <= 1'b1;
            end
            if(wb_store.store_valid) begin
                ROB_FINISH[wb_store.store_rob_id] <= 1'b1;
                ROB[wb_store.store_rob_id].store_id <= wb_store.store_id;
            end
            if(wb_branch.branch_valid) begin
                ROB_FINISH[wb_branch.branch_rob_id]        <= 1'b1;
                ROB[wb_branch.branch_rob_id].mispredict    <= wb_branch.mispredict;
                ROB[wb_branch.branch_rob_id].actual_target <= wb_branch.actual_target; // to be used for updating PC on mispredict
                ROB[wb_branch.branch_rob_id].actual_taken  <= wb_branch.actual_taken;
                ROB[wb_branch.branch_rob_id].update_pc     <= wb_branch.update_pc;
            end
            
        end
    end


    // For debugging: dump ROB contents at each clock cycle
    integer mcd;
    logic [ROB_WIDTH-1:0] j;

    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/ROB.txt","w");
        $fdisplay(mcd,"----- ROB contents at time -----", $time);
        $fdisplay(mcd,"Index | rd_arch | rd_phy_old | rd_phy_new | Finished");
        $fdisplay(mcd,"-----------------------------------------");
        for (j = head; j != tail; j = j + 1) begin
            $fdisplay(mcd," %2d %8d %11d %11d %10d", j, ROB[j].rd_arch, ROB[j].rd_phy_old, ROB[j].rd_phy_new, ROB_FINISH[j]);
        end
        if(head != tail) begin
            $fdisplay(mcd," %2d %8d %11d %11d %10d", tail, ROB[tail].rd_arch, ROB[tail].rd_phy_old, ROB[tail].rd_phy_new, ROB_FINISH[tail]);
        end
        $fclose(mcd);
        //$display("ROB contents dumped to ROB file at time %0t", $time);
    end

endmodule
