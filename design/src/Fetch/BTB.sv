`timescale 1ns/1ps
import typedef_pkg::*;

module BTB #(parameter ADDR_WIDTH = 32, BTB_ENTRIES = 16, BTB_WIDTH = $clog2(BTB_ENTRIES))(
    input  logic                     clk,
    input  logic                     rst,
    // Input from Fetch Stage
    input  logic [ADDR_WIDTH-1:0]    pc,
    input  logic                     pc_valid,
    // Output to Fetch Stage
    output predict_t              predict_0,
    output predict_t              predict_1,
    // Input from Commit Stage
    retire_if.retire_branch_sink   retire_branch_bus_0,
    retire_if.retire_branch_sink   retire_branch_bus_1
);
    logic [ADDR_WIDTH-1:0] update_btb_pc_0, update_btb_pc_1;
    logic [ADDR_WIDTH-1:0] update_btb_target_0, update_btb_target_1;
    logic                  update_btb_taken_0, update_btb_taken_1;
    logic                  retire_branch_valid_0, retire_branch_valid_1;

    assign update_btb_pc_0       = retire_branch_bus_0.retire_branch_pkg.update_btb_pc;
    assign update_btb_target_0   = retire_branch_bus_0.retire_branch_pkg.update_btb_target;
    assign update_btb_taken_0    = retire_branch_bus_0.retire_branch_pkg.update_btb_taken;
    assign retire_branch_valid_0 = retire_branch_bus_0.retire_branch_pkg.retire_branch_valid;

    assign update_btb_pc_1       = retire_branch_bus_1.retire_branch_pkg.update_btb_pc;
    assign update_btb_target_1   = retire_branch_bus_1.retire_branch_pkg.update_btb_target;
    assign update_btb_taken_1    = retire_branch_bus_1.retire_branch_pkg.update_btb_taken;
    assign retire_branch_valid_1 = retire_branch_bus_1.retire_branch_pkg.retire_branch_valid;

    // BTB Storage
    BTB_ENTRY_t btb [BTB_ENTRIES];
    BTB_ENTRY_t entry;
    logic [BTB_WIDTH-1:0] index;
    logic [BTB_WIDTH-1:0] update_index_0, update_index_1;

    assign update_index_0 = update_btb_pc_0[BTB_WIDTH+1:2];
    assign update_index_1 = update_btb_pc_1[BTB_WIDTH+1:2];
    // Predict Logic
    always_comb begin
        if (pc_valid) begin
            index = pc[BTB_WIDTH+1:2];
            entry = btb[index];
            if (entry.valid && entry.taken && entry.tag == pc[ADDR_WIDTH-1:BTB_WIDTH+2]) begin
                predict_0.predict_taken = 1;
                predict_0.predict_target = entry.target;

            end else begin
                predict_0.predict_taken = 0;
                predict_0.predict_target = pc + 4;
            end

            index = predict_0.predict_target[BTB_WIDTH+1:2];
            entry = btb[index];
            if (entry.valid && entry.taken && entry.tag == predict_0.predict_target[ADDR_WIDTH-1:BTB_WIDTH+2]) begin
                predict_1.predict_taken = 1;
                predict_1.predict_target = entry.target;
            end
            else begin
                predict_1.predict_taken = 0;
                predict_1.predict_target = predict_0.predict_target + 4;
            end
        end else begin
            predict_0.predict_taken = 0;
            predict_0.predict_target = pc + 4;
            predict_1.predict_taken = 0;
            predict_1.predict_target = predict_0.predict_target + 4;
        end
    end

    // Update Logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize BTB entries on reset
            for (int i = 0; i < BTB_ENTRIES; i++) begin
                btb[i].valid <= 0;
                btb[i].taken <= 0;
                btb[i].target <= '0;
                btb[i].tag <= '0;
            end
        end 
        else begin
            if (retire_branch_valid_0) begin
                btb[update_index_0].valid  <= 1;
                btb[update_index_0].taken  <= update_btb_taken_0;
                btb[update_index_0].target <= update_btb_target_0;
                btb[update_index_0].tag    <= update_btb_pc_0[ADDR_WIDTH-1:BTB_WIDTH+2];
            end

            if(retire_branch_valid_1) begin
                btb[update_index_1].valid  <= 1;
                btb[update_index_1].taken  <= update_btb_taken_1;
                btb[update_index_1].target <= update_btb_target_1;
                btb[update_index_1].tag    <= update_btb_pc_1[ADDR_WIDTH-1:BTB_WIDTH+2];
            end

        end
    end

endmodule

