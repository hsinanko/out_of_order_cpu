
package typedef_pkg;
    import parameter_pkg::*;
    
    typedef struct{
        logic [ADDR_WIDTH-1:0] instruction_addr;        // program counter
        logic [6:0] opcode;      // opcode field
        logic [6:0] funct7;      // funct7 field
        logic [2:0] funct3;      // funct3 field
        logic [PHY_WIDTH-1:0] rs1_addr;    // source register 1  physical register width
        logic [PHY_WIDTH-1:0] rs2_addr;    // source register 2  physical register width
        logic [PHY_WIDTH-1:0] rd_addr;     // destination register
        logic [DATA_WIDTH-1:0]immediate;   // immediate value
        logic predict_taken;
        logic [ADDR_WIDTH-1:0] predict_target;
    }instruction_t;

    typedef struct{
        logic [4:0] rd_arch;
        logic [PHY_WIDTH-1:0] rd_phy_old;
        logic [PHY_WIDTH-1:0] rd_phy_new;
        logic [6:0]opcode;
        logic [ADDR_WIDTH-1:0] actual_target;
        logic actual_taken;
        logic [ADDR_WIDTH-1:0] update_pc;
        logic mispredict;
        logic [$clog2(FIFO_DEPTH)-1:0] store_id;
        // debugging info
        logic [ADDR_WIDTH-1:0] addr;
    } ROB_ENTRY_t;

    typedef struct{
        logic [ADDR_WIDTH-1:0] addr;
        logic [ROB_WIDTH-1:0] rob_id;
        logic [6:0] funct7;
        logic [2:0] funct3; 
        logic [PHY_WIDTH-1:0] rs1_phy;
        logic [PHY_WIDTH-1:0] rs2_phy;
        logic [PHY_WIDTH-1:0] rd_phy;
        logic [DATA_WIDTH-1:0] immediate;
        logic [6:0] opcode;
        logic predict_taken;
        logic [ADDR_WIDTH-1:0] predict_target;
        logic valid;
        logic [31:0] age;
    } RS_ENTRY_t;

    typedef struct packed {
        logic [31:0] age;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
        logic valid;
    } STORE_entry_t;

    typedef struct packed {
        logic [31:0] age;
        logic [2:0] funct3;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
        logic [ROB_WIDTH-1:0]  rob_id;
        logic [PHY_WIDTH-1:0]  rd_phy;
        logic valid;
    } LOAD_entry_t;

endpackage

