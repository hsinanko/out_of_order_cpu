`timescale 1ns/1ps

module BTB #(parameter ADDR_WIDTH = 32, BTB_ENTRIES = 16, BTB_WIDTH = $clog2(BTB_ENTRIES))(
    input  logic                     clk,
    input  logic                     rst,
    // Input from Fetch Stage
    input  logic [ADDR_WIDTH-1:0]    pc,
    input  logic                     pc_valid,
    // Output to Fetch Stage
    output logic                     predict_taken,
    output logic [ADDR_WIDTH-1:0]    predict_target,
    // Input from Commit Stage
    input  logic                     update_valid,
    input  logic [ADDR_WIDTH-1:0]    update_pc,
    input  logic                     update_taken,
    input  logic [ADDR_WIDTH-1:0]    update_target
);

    // BTB Entry Structure
    typedef struct packed {
        logic                     valid;
        logic                     taken;
        logic [ADDR_WIDTH-1:0]    target;
    } BTB_ENTRY_t;

    // BTB Storage
    BTB_ENTRY_t btb [BTB_ENTRIES];


    logic [BTB_WIDTH-1:0] index;
    assign index = pc[BTB_WIDTH+1:2];
    // Predict Logic
    always_comb begin
        if (pc_valid) begin
            BTB_ENTRY_t entry = btb[index];
            if (entry.valid && entry.taken) begin
                predict_taken = 1;
                predict_target = entry.target;
            end else begin
                predict_taken = 0;
                predict_target = pc + 4;
            end
        end else begin
            predict_taken = 0;
            predict_target = pc + 4;
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
            end
        end else if (update_valid) begin
            BTB_ENTRY_t entry;
            entry.valid <= 1;
            entry.taken <= update_taken;
            entry.target <= update_target;
            btb[index] <= entry;
        end
    end

endmodule

