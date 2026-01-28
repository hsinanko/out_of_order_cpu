interface execution_if #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, PHY_WIDTH = 6, ROB_WIDTH = 5)();
    // ALU outputs
    logic                  alu_valid;
    logic [ROB_WIDTH-1:0]  alu_rob_id;
    logic [DATA_WIDTH-1:0] alu_result;
    logic [PHY_WIDTH-1:0]  rd_phy_alu;
    logic                  busy_alu;
    // Store outputs
    logic                  store_valid;
    logic [ADDR_WIDTH-1:0] store_waddr; 
    logic [DATA_WIDTH-1:0] store_wdata;
    logic [ROB_WIDTH-1:0]  store_rob_id;

    // Load outputs
    logic                  load_valid;
    logic [2:0]            load_funct3;
    logic [ADDR_WIDTH-1:0] load_raddr;
    logic [ROB_WIDTH-1:0]  load_rob_id;
    logic [PHY_WIDTH-1:0]  load_rd_phy;
    logic                  busy_lsu;
    // Branch outputs
    logic                  branch_valid;
    logic [ROB_WIDTH-1:0]  branch_rob_id;
    logic                  actual_taken;
    logic                  mispredict;
    logic [ADDR_WIDTH-1:0] actual_target;
    logic [ADDR_WIDTH-1:0] update_pc;
    logic [ADDR_WIDTH-1:0] nextPC;
    logic [PHY_WIDTH-1:0]  rd_phy_branch;
    logic                  isJump;
    logic                  busy_branch;


    modport source (
        output alu_valid,
        output alu_rob_id,
        output alu_result,
        output rd_phy_alu,
        output busy_alu,
        // load/store
        output store_waddr,
        output store_wdata,
        output store_rob_id,
        output store_valid,
        output load_funct3,
        output load_raddr,
        output load_rob_id,
        output load_rd_phy,
        output load_valid,
        output busy_lsu,
        // branch
        output branch_valid,
        output branch_rob_id,
        output actual_taken,
        output mispredict,
        output actual_target,
        output update_pc,
        output nextPC,
        output rd_phy_branch,
        output isJump,
        output busy_branch
    );

    modport sink (
        input alu_valid,
        input alu_rob_id,
        input alu_result,
        input rd_phy_alu,
        input busy_alu,
        // load/store
        input store_waddr,
        input store_wdata,
        input store_rob_id,
        input store_valid,
        input load_funct3,
        input load_raddr,
        input load_rob_id,
        input load_rd_phy,
        input load_valid,
        input busy_lsu,
        // branch
        input branch_valid,
        input branch_rob_id,
        input actual_taken,
        input mispredict,
        input actual_target,
        input update_pc,
        input nextPC,
        input rd_phy_branch,
        input isJump,
        input busy_branch
    );
endinterface : execution_if
