interface retire_if #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, NUM_ROB_ENTRY = 32, FIFO_DEPTH = 16)();

    logic                  isFlush;
    logic [ADDR_WIDTH-1:0] targetPC;
    logic [4:0]            rd_arch;
    logic [PHY_WIDTH-1:0]  rd_phy_old;
    logic [PHY_WIDTH-1:0]  rd_phy_new;
    logic [ADDR_WIDTH-1:0] update_btb_pc;
    logic [ADDR_WIDTH-1:0] update_btb_target;
    logic                  update_btb_taken;
    logic                  retire_pr_valid;
    logic                  retire_store_valid; // retire store valid
    logic [$clog2(FIFO_DEPTH)-1:0] retire_store_id;
    logic                  retire_branch_valid;
    logic                  retire_done_valid;
    logic [ROB_WIDTH-1:0] rob_debug;
    logic [ADDR_WIDTH-1:0] retire_addr;


    modport retire_source(
        output isFlush,
        output targetPC,
        output rd_arch,
        output rd_phy_old,
        output rd_phy_new,
        output update_btb_pc,
        output update_btb_target,
        output update_btb_taken,
        output retire_pr_valid,
        output retire_store_valid,
        output retire_store_id,
        output retire_branch_valid,
        output retire_done_valid,
        output rob_debug,
        output retire_addr
    );


    modport retire_pr_sink(
        input rd_arch,
        input rd_phy_old,
        input rd_phy_new,
        input retire_pr_valid
    );

    modport retire_branch_sink(
        input update_btb_pc,
        input update_btb_target,
        input update_btb_taken,
        input retire_branch_valid
    );

    modport retire_store_sink(
        input retire_store_valid,
        input retire_store_id
    );

endinterface : retire_if
