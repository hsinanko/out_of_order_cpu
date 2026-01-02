`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;

module ReservationStation #(parameter NUM_RS_ENTRIES = 8, ROB_WIDTH = 4, PHY_REGS = 64, TYPE = 0)(
    input logic clk,
    input logic rst,
    input logic [PHY_REGS-1:0]PRF_valid,
    // ====== dispatch instruction ======
    // first instruction
    input instruction_t dispatch_instruction_0,
    input logic [ROB_WIDTH-1:0] rob_id_0,
    input logic dispatch_valid_0,
    // second instruction
    input instruction_t dispatch_instruction_1,
    input logic [ROB_WIDTH-1:0] rob_id_1,
    input logic dispatch_valid_1,

    // RS --> issue
    output RS_ENTRY_t issue_instruction,
    output logic issue_valid
);

    RS_ENTRY_t RS[0:NUM_RS_ENTRIES-1];

    logic [$clog2(NUM_RS_ENTRIES)-1:0]head;
    logic [$clog2(NUM_RS_ENTRIES)-1:0]tail;
    logic [$clog2(NUM_RS_ENTRIES)-1:0]num_free;
    logic [4:0]global_age;
    logic issue_free_valid;
    logic [$clog2(NUM_RS_ENTRIES)-1:0]issue_free;
    integer i;
    // Find free slot for dispatching instructions
    logic [$clog2(NUM_RS_ENTRIES)-1:0]free_slot_0, free_slot_1;
    FreeSlot #(NUM_RS_ENTRIES, TYPE) free_slot_inst (
        .clk(clk),
        .rst(rst),
        .valid_0(dispatch_valid_0),
        .valid_1(dispatch_valid_1),
        .free_0(free_slot_0),
        .free_1(free_slot_1),
        .issue_free_valid(issue_free_valid),
        .issue_free(issue_free)
    );

    logic [$clog2(NUM_RS_ENTRIES):0] best;
    logic [$clog2(NUM_RS_ENTRIES):0] invalid_index = 1'b1 << $clog2(NUM_RS_ENTRIES);

    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            
            for(i = 0; i < NUM_RS_ENTRIES; i = i + 1)begin
                RS[i].valid <= 1'b0;
            end
            num_free    <= NUM_RS_ENTRIES;
            global_age  <= 5'b0;
        end
        else begin
            // Dispatch first instruction
            if(dispatch_valid_0)begin
                RS[free_slot_0].addr      <= dispatch_instruction_0.instruction_addr;
                RS[free_slot_0].rob_id    <= rob_id_0;
                RS[free_slot_0].funct7    <= dispatch_instruction_0.funct7;
                RS[free_slot_0].funct3    <= dispatch_instruction_0.funct3;
                RS[free_slot_0].rs1_phy   <= dispatch_instruction_0.rs1_addr;
                RS[free_slot_0].rs2_phy   <= dispatch_instruction_0.rs2_addr;
                RS[free_slot_0].rd_phy    <= dispatch_instruction_0.rd_addr;
                RS[free_slot_0].immediate <= dispatch_instruction_0.immediate;
                RS[free_slot_0].opcode    <= dispatch_instruction_0.opcode;
                RS[free_slot_0].age       <= global_age;
                RS[free_slot_0].valid     <= 1'b1;
            end
            // Dispatch second instruction
            if(dispatch_valid_1)begin
                RS[free_slot_1].addr      <= dispatch_instruction_1.instruction_addr;
                RS[free_slot_1].rob_id    <= rob_id_1;
                RS[free_slot_1].funct7    <= dispatch_instruction_1.funct7;
                RS[free_slot_1].funct3    <= dispatch_instruction_1.funct3;
                RS[free_slot_1].rs1_phy   <= dispatch_instruction_1.rs1_addr;
                RS[free_slot_1].rs2_phy   <= dispatch_instruction_1.rs2_addr;
                RS[free_slot_1].rd_phy    <= dispatch_instruction_1.rd_addr;
                RS[free_slot_1].immediate <= dispatch_instruction_1.immediate;
                RS[free_slot_1].opcode    <= dispatch_instruction_1.opcode;
                RS[free_slot_1].age       <= (dispatch_valid_0) ? global_age+1: global_age;
                RS[free_slot_1].valid     <= 1'b1;
            end

            
            if(dispatch_valid_0 && dispatch_valid_1)
                global_age <= global_age + 3;
            if(dispatch_valid_0 || dispatch_valid_1)
                global_age <= global_age + 2;
            else
                global_age <= global_age;
        end
    end

    
    always_ff @(posedge clk or posedge rst)begin
        if(rst)begin
            issue_instruction.rob_id    <= 'h0;
            issue_instruction.funct7    <= 'h0;
            issue_instruction.funct3    <= 'h0;
            issue_instruction.rs1_phy   <= 'h0;
            issue_instruction.rs2_phy   <= 'h0;
            issue_instruction.rd_phy    <= 'h0;
            issue_instruction.opcode    <= 'h0;
            issue_instruction.immediate <= 'h0;
        end
        else begin
            if(best != invalid_index)begin
                issue_instruction <= RS[best];
                issue_valid       <= 1'b1;
                RS[best].valid    <= 1'b0;
                issue_free        <= 0;
                issue_free_valid  <= 1'b1;
                issue_free        <= best;
            end
            else begin
                //issue_instruction <= 'h0;
                issue_valid       <= 1'b0;
                issue_free_valid  <= 1'b0;
                issue_free        <= best;
                issue_free_valid  <= 1'b0;
                issue_free        <= 'hx;
            end
        end
        
    end
    // Find the youngest ready instruction

    always_latch begin
        best = invalid_index; // Initialize to invalid index
        for (int i = 0; i < NUM_RS_ENTRIES; i++) begin
            if(RS[i].valid)begin
                case(RS[i].opcode)
                    LOAD, STORE: begin
                        if (PRF_valid[RS[i].rs1_phy]) begin
                            if ((best == invalid_index) || RS[i].age < RS[best].age)
                                best = i;
                        end
                    end
                    BRANCH: begin
                        if (PRF_valid[RS[i].rs1_phy] && PRF_valid[RS[i].rs2_phy]) begin
                            if ((best == invalid_index) || RS[i].age < RS[best].age)
                                best = i;
                        end
                    end
                    JAL, LUI, AUIPC: begin
                        if ((best == invalid_index) || RS[i].age < RS[best].age)
                            best = i;
                    end
                    OP_IMM, SYSTEM, JALR: begin
                        if (PRF_valid[RS[i].rs1_phy]) begin
                            if ((best == invalid_index) || RS[i].age < RS[best].age)
                                best = i;
                        end
                    end
                    OP: begin
                        if (PRF_valid[RS[i].rs1_phy] && PRF_valid[RS[i].rs2_phy]) begin
                            if ((best == invalid_index) || RS[i].age < RS[best].age)
                                best = i;
                        end
                    end

                endcase
            end
        end
    end

    // For debugging: dump Reservation Station contents at each clock cycle
    integer           mcd;

    always_ff @(negedge clk) begin

        case(TYPE)
            0: mcd = $fopen("./build/RS_ALU.txt","w");
            1: mcd = $fopen("./build/RS_LSU.txt","w");
            2: mcd = $fopen("./build/RS_BRU.txt","w");
            default: mcd = $fopen("./build/RS_UNKNOWN.txt","w");
        endcase

        $fdisplay(mcd,"----- RS contents at time -----");
        $fdisplay(mcd,"Index | rob_id | funct7 | funct3 | rs1_phy | rs2_phy | rd_phy | immediate | opcode |age | valid");
        $fdisplay(mcd,"-----------------------------------------");

        for (i=0; i < NUM_RS_ENTRIES; i=i+1) begin
            $fdisplay(mcd,"%5d |  %4d  |  %3b   |  %3b   |   %3d   |   %2d     |   %2d  |   %4d    |  %7b | %d |  %b", 
                i, RS[i].rob_id, RS[i].funct7, RS[i].funct3, RS[i].rs1_phy, RS[i].rs2_phy, RS[i].rd_phy, RS[i].immediate, RS[i].opcode, RS[i].age, RS[i].valid);
        end

        $fclose(mcd);
        //$display("RS contents dumped to RS file at time %0t", $time);
    end

endmodule

