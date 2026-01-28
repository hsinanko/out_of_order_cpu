interface writeback_if #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5, FIFO_DEPTH = 16)();
    // ======= ALU Commit Signals =======
    logic                  alu_valid;
    logic [ROB_WIDTH-1:0]  alu_rob_id;
    logic [PHY_WIDTH-1:0]  rd_alu;
    logic [DATA_WIDTH-1:0] alu_result;

    // ======= Load Commit Signals =======
    logic                  load_valid;
    logic [ROB_WIDTH-1:0]  load_rob_id;
    logic [PHY_WIDTH-1:0]  rd_load;
    logic [DATA_WIDTH-1:0] load_rdata;
    // ======= Store Commit Signals =======
    logic                  store_valid;
    logic [ROB_WIDTH-1:0]  store_rob_id;
    logic [$clog2(FIFO_DEPTH)-1:0] store_id;

    // ======= Branch Commit Signals =======
    logic                  branch_valid;
    logic                  jump_valid;
    logic [ROB_WIDTH-1:0]  branch_rob_id;
    logic [PHY_WIDTH-1:0]  rd_branch;
    logic [ADDR_WIDTH-1:0] nextPC;
    logic                  mispredict;
    logic [ADDR_WIDTH-1:0] actual_target;
    logic                  actual_taken;
    logic [ADDR_WIDTH-1:0] update_pc;

    
    modport source (
        output alu_valid,
        output alu_rob_id,
        output rd_alu,
        output alu_result,
        output load_valid,
        output load_rob_id,
        output rd_load,
        output load_rdata,
        output store_valid,
        output store_rob_id,
        output store_id,
        output branch_valid,
        output jump_valid,
        output branch_rob_id,
        output rd_branch,
        output nextPC,
        output mispredict,
        output actual_target,
        output actual_taken,
        output update_pc
    );

    modport sink (
        input alu_valid,
        input alu_rob_id,
        input rd_alu,
        input alu_result,
        input load_valid,
        input load_rob_id,
        input rd_load,
        input load_rdata,
        input store_valid,
        input store_rob_id,
        input store_id,
        input branch_valid,
        input jump_valid,
        input branch_rob_id,
        input rd_branch,
        input nextPC,
        input mispredict,
        input actual_target,
        input actual_taken,
        input update_pc
    );


endinterface : writeback_if
