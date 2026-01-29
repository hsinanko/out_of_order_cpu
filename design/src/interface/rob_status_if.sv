interface rob_status_if #(NUM_ROB_ENTRY = 32, ROB_WIDTH = 5)();
    import typedef_pkg::*;
    logic [NUM_ROB_ENTRY-1:0]       rob_finish;
    ROB_ENTRY_t rob[NUM_ROB_ENTRY-1:0];
    logic [NUM_ROB_ENTRY-1:0]       rob_head;
    logic                           rob_full;
    logic                           rob_empty;
    logic [ROB_WIDTH-1:0]           retire_num;

    modport source(
        output rob_finish,
        output rob,
        output rob_head,
        output rob_full,
        output rob_empty,
        input retire_num
    );

    modport sink(
        input rob_finish,
        input rob,
        input rob_head,
        input rob_full,
        input rob_empty,
        output retire_num
    );
    
endinterface