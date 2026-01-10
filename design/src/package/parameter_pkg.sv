package parameter_pkg;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter NUM_ROB_ENTRY = 32;
    parameter REG_WIDTH = 32;
    parameter ARCH_REGS = 32;
    parameter NUM_RS_ENTRIES = 32;
    parameter PHY_REGS = 64;    // physical registers 
    parameter QUEUE = 16;        // store queue size
    parameter BTB_ENTRIES = 16;
    parameter BTB_WIDTH = $clog2(BTB_ENTRIES);
    parameter FIFO_DEPTH = 16;
    
    parameter PHY_WIDTH = $clog2(PHY_REGS);
    parameter ROB_WIDTH = $clog2(NUM_ROB_ENTRY);
    parameter RS_WIDTH = $clog2(NUM_RS_ENTRIES);
    parameter FREE_REG = PHY_REGS - ARCH_REGS; // number of free physical registers

    parameter INSTR_ADDRESS = 32'h0000_0000;
    parameter DATA_ADDRESS  = 32'h0000_1000;
    parameter INSTR_MEM_SIZE = (DATA_ADDRESS - INSTR_ADDRESS) << 2; // in bytes
    parameter DATA_MEM_SIZE = (1024) << 2; // in bytes
    parameter BOOT_PC       = INSTR_ADDRESS;

endpackage
