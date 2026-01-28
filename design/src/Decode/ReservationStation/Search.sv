`timescale 1ns / 1ps
import typedef_pkg::*;

module Search #(parameter NUM_RS_ENTRIES = 16)(
    input  RS_ENTRY_t RS[0:NUM_RS_ENTRIES-1],
    input  logic [PHY_REGS-1:0]PRF_valid,
    output logic [$clog2(NUM_RS_ENTRIES)-1:0] best,
    output logic best_valid
);
    integer i;

    
    always_comb begin
        best_valid = 1'b0;
        for (i = 0; i < NUM_RS_ENTRIES; i = i + 1) begin
            if(RS[i].valid)begin
                case(RS[i].opcode)
                    LOAD, STORE:begin
                        if (!best_valid || (RS[i].age < RS[best].age))begin
                            best = i;
                            best_valid = 1'b1;
                        end
                    end
                    BRANCH: begin
                        if (PRF_valid[RS[i].rs1_phy] && PRF_valid[RS[i].rs2_phy]) begin
                            if (!best_valid || (RS[i].age < RS[best].age))begin
                                best = i;
                                best_valid = 1'b1;
                            end
                        end
                    end
                    JAL, LUI, AUIPC: begin
                        if (!best_valid || (RS[i].age < RS[best].age))begin
                            best = i;
                            best_valid = 1'b1;
                        end
                    end
                    OP_IMM, JALR: begin
                        if (PRF_valid[RS[i].rs1_phy]) begin
                            if (!best_valid || (RS[i].age < RS[best].age))begin
                                best = i;
                                best_valid = 1'b1;
                            end
                        end
                    end
                    OP: begin
                        if (PRF_valid[RS[i].rs1_phy] && PRF_valid[RS[i].rs2_phy]) begin
                            if (!best_valid || (RS[i].age < RS[best].age))begin
                                best = i;
                                best_valid = 1'b1;
                            end
                        end
                    end
                    SYSTEM: begin
                        if (!best_valid || (RS[i].age < RS[best].age))begin
                            best = i;
                            best_valid = 1'b1;
                        end
                    end
                    default: begin
                        best_valid = 0;
                        best = 'x;
                    end
                endcase
            end
        end

        if(best_valid && RS[best].opcode == LOAD) begin
            if (!PRF_valid[RS[best].rs1_phy]) begin
                best_valid = 0;
                best = 'x;
            end
        end
        else if(best_valid && RS[best].opcode == STORE) begin
            if (!(PRF_valid[RS[best].rs1_phy] && PRF_valid[RS[best].rs2_phy])) begin
                best_valid = 0;
                best = 'x;
            end
        end
    end

endmodule
