`timescale 1ns / 1ps
package instruction_pkg;

    typedef enum logic [3:0]{
        ADD,
        SUB,
        XOR,
        OR,
        AND,
        SLL,
        SRL,
        SRA,
        SLT,
        SLTU
    } ALUFunctions;

    typedef enum logic [2:0]{
        ALU_ADD_SUB = 'h0,
        ALU_XOR     = 'h4,
        ALU_OR      = 'h6,
        ALU_AND     = 'h7,
        ALU_SLL     = 'h1,
        ALU_SRA_SLL = 'h5,
        ALU_SLT     = 'h2,
        ALU_SLTU    = 'h3
    }ALU_FUNCT3;

    typedef enum logic [2:0]{
        LB  = 'h0,
        LH  = 'h1,
        LW  = 'h2,
        LBU = 'h4,
        LHU = 'h5
    }LOAD_FUNCT3;

    typedef enum logic [2:0]{
        SB = 'h0,
        SH = 'h1,
        SW = 'h2
    }STORE_FUNCT3;

    typedef enum logic [2:0]{
        BEQ  = 'h0, 
        BNE  = 'h1, 
        BLT  = 'h4, 
        BGE  = 'h5, 
        BLTU = 'h6, 
        BGEU = 'h7
    } BRANCH_FUNCT3;

    typedef enum logic [6:0] {
       LOAD     = 'b0000011,
       OP_IMM   = 'b0010011,
       STORE    = 'b0100011,
       OP       = 'b0110011,
       LUI      = 'b0110111,
       AUIPC    = 'b0010111,
       JAL      = 'b1101111,
       JALR     = 'b1100111,
       BRANCH   = 'b1100011,
       SYSTEM   = 'b1110011
    } OPCODE;
    
 endpackage
