package parameter_pkg;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter NUM_ROB_ENTRY = 16;
    parameter REG_WIDTH = 32;
    parameter ARCH_REGS = 32;
    parameter NUM_RS_ENTRIES = 16;
    parameter PHY_REGS = 64;    // physical registers 
    parameter QUEUE = 16;        // store queue size
    parameter BTB_ENTRIES = 16;
    parameter BTB_WIDTH = $clog2(BTB_ENTRIES);

    parameter PHY_WIDTH = $clog2(PHY_REGS);
    parameter ROB_WIDTH = $clog2(NUM_ROB_ENTRY);
    parameter RS_WIDTH = $clog2(NUM_RS_ENTRIES);
    

endpackage
