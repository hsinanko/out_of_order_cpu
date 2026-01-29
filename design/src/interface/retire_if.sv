interface retire_if #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, NUM_ROB_ENTRY = 32, FIFO_DEPTH = 16)();

    logic                  isFlush;
    logic [ADDR_WIDTH-1:0] targetPC;
    RETIRE_PR_t            retire_pr_pkg;
    RETIRE_STORE_t         retire_store_pkg;
    RETIRE_BRANCH_t        retire_branch_pkg;
    logic                  retire_done_valid;
    logic [ROB_WIDTH-1:0] rob_debug;
    logic [ADDR_WIDTH-1:0] retire_addr;


    modport retire_source(
        output isFlush,
        output targetPC,
        output retire_pr_pkg,
        output retire_store_pkg,
        output retire_branch_pkg,
        output retire_done_valid,
        output rob_debug,
        output retire_addr
    );


    modport retire_pr_sink(
        input retire_pr_pkg
    );

    modport retire_branch_sink(
        input retire_branch_pkg
    );

    modport retire_store_sink(
        input retire_store_pkg
    );

endinterface : retire_if
