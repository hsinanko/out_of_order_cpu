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
    retire_if.retire_branch_sink   retire_branch_bus
);

    // BTB Storage
    BTB_ENTRY_t btb [BTB_ENTRIES];
    BTB_ENTRY_t entry;
    logic [BTB_WIDTH-1:0] index;
    logic [BTB_WIDTH-1:0] update_index;

    assign update_index = retire_branch_bus.update_btb_pc[BTB_WIDTH+1:2];
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
        end else if (retire_branch_bus.retire_branch_valid) begin
            btb[update_index].valid  <= 1;
            btb[update_index].taken  <= retire_branch_bus.update_btb_taken;
            btb[update_index].target <= retire_branch_bus.update_btb_target;
            btb[update_index].tag    <= retire_branch_bus.update_btb_pc[ADDR_WIDTH-1:BTB_WIDTH+2];
        end
    end

endmodule

