`timescale 1ns/1ps

module BTB #(parameter ADDR_WIDTH = 32, BTB_ENTRIES = 16, BTB_WIDTH = $clog2(BTB_ENTRIES))(
    input  logic                     clk,
    input  logic                     rst,
    // Input from Fetch Stage
    input  logic [ADDR_WIDTH-1:0]    pc,
    input  logic                     pc_valid,
    // Output to Fetch Stage
    output logic                     predict_taken_0,
    output logic [ADDR_WIDTH-1:0]    predict_target_0,
    output logic                     predict_taken_1,
    output logic [ADDR_WIDTH-1:0]    predict_target_1,
    // Input from Commit Stage
    retire_if.retire_branch_sink   retire_branch_bus
);

    // BTB Entry Structure
    typedef struct packed {
        logic                     valid;
        logic                     taken;
        logic [(ADDR_WIDTH-BTB_WIDTH-3):0] tag;
        logic [ADDR_WIDTH-1:0]    target;
    } BTB_ENTRY_t;

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
                predict_taken_0 = 1;
                predict_target_0 = entry.target;

            end else begin
                predict_taken_0 = 0;
                predict_target_0 = pc + 4;
            end

            index = predict_target_0[BTB_WIDTH+1:2];
            entry = btb[index];
            if (entry.valid && entry.taken && entry.tag == predict_target_0[ADDR_WIDTH-1:BTB_WIDTH+2]) begin
                predict_taken_1 = 1;
                predict_target_1 = entry.target;
            end
            else begin
                predict_taken_1 = 0;
                predict_target_1 = predict_target_0 + 4;
            end
        end else begin
            predict_taken_0 = 0;
            predict_target_0 = pc + 4;
            predict_taken_1 = 0;
            predict_target_1 = predict_target_0 + 4;
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

