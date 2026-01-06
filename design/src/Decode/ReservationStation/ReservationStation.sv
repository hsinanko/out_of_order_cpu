`timescale 1ns/1ps

import parameter_pkg::*;
import typedef_pkg::*;

module ReservationStation #(parameter NUM_RS_ENTRIES = 8, ROB_WIDTH = 4, PHY_REGS = 64, TYPE = 0)(
    input logic clk,
    input logic rst,
    input logic flush,
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
    logic [$clog2(NUM_RS_ENTRIES):0]num_free;
    logic [4:0]global_age;
    logic issue_free_valid;
    logic [$clog2(NUM_RS_ENTRIES)-1:0]issue_free;
    integer i;
    // Find free slot for dispatching instructions
    logic [$clog2(NUM_RS_ENTRIES)-1:0]free_slot_0, free_slot_1;
    FreeSlot #(NUM_RS_ENTRIES, TYPE) free_slot_inst (
        .clk(clk),
        .rst(rst),
        .flush(flush),
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
        else if(flush) begin
            // On flush, invalidate all entries in the reservation station
            for(i = 0; i < NUM_RS_ENTRIES; i = i + 1)begin
                RS[i].valid <= 1'b0;
            end
            num_free    <= NUM_RS_ENTRIES;
            global_age  <= 5'b0;
        end
        else begin
            // Dispatch first instruction
            if(dispatch_valid_0)begin
                RS[free_slot_0].addr           <= dispatch_instruction_0.instruction_addr;
                RS[free_slot_0].rob_id         <= rob_id_0;
                RS[free_slot_0].funct7         <= dispatch_instruction_0.funct7;
                RS[free_slot_0].funct3         <= dispatch_instruction_0.funct3;
                RS[free_slot_0].rs1_phy        <= dispatch_instruction_0.rs1_addr;
                RS[free_slot_0].rs2_phy        <= dispatch_instruction_0.rs2_addr;
                RS[free_slot_0].rd_phy         <= dispatch_instruction_0.rd_addr;
                RS[free_slot_0].immediate      <= dispatch_instruction_0.immediate;
                RS[free_slot_0].opcode         <= dispatch_instruction_0.opcode;
                RS[free_slot_0].predict_taken  <= dispatch_instruction_0.predict_taken;
                RS[free_slot_0].predict_target <= dispatch_instruction_0.predict_target;
                RS[free_slot_0].age            <= global_age;
                RS[free_slot_0].valid          <= 1'b1;
            end
            // Dispatch second instruction
            if(dispatch_valid_1)begin 
                RS[free_slot_1].addr           <= dispatch_instruction_1.instruction_addr;
                RS[free_slot_1].rob_id         <= rob_id_1;
                RS[free_slot_1].funct7         <= dispatch_instruction_1.funct7;
                RS[free_slot_1].funct3         <= dispatch_instruction_1.funct3;
                RS[free_slot_1].rs1_phy        <= dispatch_instruction_1.rs1_addr;
                RS[free_slot_1].rs2_phy        <= dispatch_instruction_1.rs2_addr;
                RS[free_slot_1].rd_phy         <= dispatch_instruction_1.rd_addr;
                RS[free_slot_1].immediate      <= dispatch_instruction_1.immediate;
                RS[free_slot_1].opcode         <= dispatch_instruction_1.opcode;
                RS[free_slot_1].predict_taken  <= dispatch_instruction_1.predict_taken;  // this should not happen in BRU
                RS[free_slot_1].predict_target <= dispatch_instruction_1.predict_target; // this should not happen in BRU
                RS[free_slot_1].age            <= (dispatch_valid_0) ? global_age+1: global_age;
                RS[free_slot_1].valid          <= 1'b1;
            end

            
            if(dispatch_valid_0 && dispatch_valid_1)
                global_age <= global_age + 3;
            if(dispatch_valid_0 || dispatch_valid_1)
                global_age <= global_age + 2;
            else
                global_age <= global_age;
        end
    end

    
    always@(posedge clk or posedge rst)begin
        if(!rst) begin
             best <= find_best();
            if(issue_valid) begin
                
            end
        end
    end

    logic [$clog2(NUM_RS_ENTRIES):0] best_reg;
    always_latch begin
        if(flush) begin
            issue_valid       = 1'b0;
            issue_free_valid  = 1'b0;
            issue_free        = 'hx;
        end
        else if(best != invalid_index)begin
            issue_instruction = RS[best];
            issue_valid       = 1'b1;
            issue_free        = 0;
            issue_free_valid  = 1'b1;
            issue_free        = best;
            RS[best].valid    = 1'b0;
        end
        else begin
            //issue_instruction <= 'h0;
            issue_valid       = 1'b0;
            issue_free_valid  = 1'b0;
            issue_free        = 'hx;
            issue_free_valid  = 1'b0;
            issue_free        = 'hx;
        end
    end
    // Find the youngest ready instruction

    function [$clog2(NUM_RS_ENTRIES):0] find_best();
    integer i;
    begin
        best = invalid_index; // Initialize to invalid index
        for (i = 0; i < NUM_RS_ENTRIES; i = i + 1) begin
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
        return best;
    end
    endfunction
    // For debugging: dump Reservation Station contents at each clock cycle
    integer           mcd;

    always_ff @(negedge clk) begin

        case(TYPE)
            0: mcd = $fopen("../test/build/RS_ALU.txt","w");
            1: mcd = $fopen("../test/build/RS_LSU.txt","w");
            2: mcd = $fopen("../test/build/RS_BRU.txt","w");
            default: mcd = $fopen("../test/build/RS_UNKNOWN.txt","w");
        endcase

        $fdisplay(mcd,"----- RS contents at time -----");
        $fdisplay(mcd,"Index | rob_id |   addr   | funct7 | funct3 | rs1_phy | rs2_phy | rd_phy | immediate | opcode | age | valid");
        $fdisplay(mcd,"-----------------------------------------");

        for (i=0; i < NUM_RS_ENTRIES; i=i+1) begin
            $fdisplay(mcd,"%5d |  %4d  | %8h |  %4b  |  %4b  |   %3d   |   %3d   |   %2d   |  %5d  | %7b  | %3d | %b", 
                i, RS[i].rob_id, RS[i].addr, RS[i].funct7, RS[i].funct3, RS[i].rs1_phy, RS[i].rs2_phy, RS[i].rd_phy, $signed(RS[i].immediate), RS[i].opcode, RS[i].age, RS[i].valid);
        end

        $fclose(mcd);
        //$display("RS contents dumped to RS file at time %0t", $time);
    end

endmodule

