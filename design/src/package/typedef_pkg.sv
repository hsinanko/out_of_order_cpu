
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
        logic [11:0]immediate;   // immediate value
        logic predict_taken;
        logic [ADDR_WIDTH-1:0] predict_target;
    }instruction_t;

    typedef struct{
        logic [4:0] rd_arch;
        logic [PHY_WIDTH-1:0] rd_phy_old;
        logic [PHY_WIDTH-1:0] rd_phy_new;
        logic [6:0]opcode;
        logic [ADDR_WIDTH-1:0] actual_target;
        logic mispredict;
    } ROB_ENTRY_t;

    typedef struct{
        logic [ADDR_WIDTH-1:0] addr;
        logic [4:0] rob_id;
        logic [4:0] funct7;
        logic [2:0] funct3; 
        logic [PHY_WIDTH-1:0] rs1_phy;
        logic [PHY_WIDTH-1:0] rs2_phy;
        logic [PHY_WIDTH-1:0] rd_phy;
        logic [11:0] immediate;
        logic [6:0] opcode;
        logic predict_taken;
        logic [ADDR_WIDTH-1:0] predict_target;
        logic valid;
        logic [4:0] age;
    } RS_ENTRY_t;

endpackage

