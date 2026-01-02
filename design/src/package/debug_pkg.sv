package debug_pkg;
    function string phy_reg_name(logic [5:0] preg);
        phy_reg_name = $sformatf("r%0d", preg);
    endfunction

    function string reg_name(logic [4:0] register, bit showArch = 1);
        case (register)
            'b00000: reg_name = (showArch) ? "x0" : "zero";
            'b00001: reg_name = (showArch) ? "x1" : "ra";
            'b00010: reg_name = (showArch) ? "x2" : "sp";
            'b00011: reg_name = (showArch) ? "x3" : "gp";
            'b00100: reg_name = (showArch) ? "x4" : "tp";
            'b00101: reg_name = (showArch) ? "x5" : "t0";
            'b00110: reg_name = (showArch) ? "x6" : "t1";
            'b00111: reg_name = (showArch) ? "x7" : "t2";
            'b01000: reg_name = (showArch) ? "x8" : "s0";
            'b01001: reg_name = (showArch) ? "x9" : "s1";
            'b01010: reg_name = (showArch) ? "x10" : "a0";
            'b01011: reg_name = (showArch) ? "x11" : "a1";
            'b01100: reg_name = (showArch) ? "x12" : "a2";
            'b01101: reg_name = (showArch) ? "x13" : "a3";
            'b01110: reg_name = (showArch) ? "x14" : "a4";
            'b01111: reg_name = (showArch) ? "x15" : "a5";
            'b10000: reg_name = (showArch) ? "x16" : "a6";
            'b10001: reg_name = (showArch) ? "x17" : "a7";
            'b10010: reg_name = (showArch) ? "x18" : "s2";
            'b10011: reg_name = (showArch) ? "x19" : "s3";
            'b10100: reg_name = (showArch) ? "x20" : "s4";
            'b10101: reg_name = (showArch) ? "x21" : "s5";
            'b10110: reg_name = (showArch) ? "x22" : "s6";
            'b10111: reg_name = (showArch) ? "x23" : "s7";
            'b11000: reg_name = (showArch) ? "x24" : "s8";
            'b11001: reg_name = (showArch) ? "x25" : "s9";
            'b11010: reg_name = (showArch) ? "x26" : "s10";
            'b11011: reg_name = (showArch) ? "x27" : "s11";
            'b11100: reg_name = (showArch) ? "x28" : "t3";
            'b11101: reg_name = (showArch) ? "x29" : "t4";
            'b11110: reg_name = (showArch) ? "x30" : "t5";
            'b11111: reg_name = (showArch) ? "x31" : "t6";
            default: reg_name = "unknown";
        endcase
    endfunction

    function string opcode_name(logic [6:0] opcode, logic [2:0] funct3, logic [6:0] funct7);
        case (opcode)
            'b0000011: begin
                case(funct3)
                    'b000: opcode_name = "lb";
                    'b001: opcode_name = "lh";
                    'b010: opcode_name = "lw";
                    'b100: opcode_name = "lbu";
                    'b101: opcode_name = "lhu";
                    default: opcode_name = "LOAD_UNKNOWN";
                endcase
            end
            'b0010011: begin
                case(funct3)
                    'b000: opcode_name = "addi";
                    'b010: opcode_name = "slti";
                    'b011: opcode_name = "sltiu";
                    'b100: opcode_name = "xori";
                    'b110: opcode_name = "ori";
                    'b111: opcode_name = "andi";
                    'b001: opcode_name = "slli";
                    'b101: opcode_name = (funct7[5]) ? "srai" : "srli";
                    default: opcode_name = "OP_IMM_UNKNOWN";
                endcase
            end
            'b0100011: begin
                case(funct3)
                    'b000: opcode_name = "sb";
                    'b001: opcode_name = "sh";
                    'b010: opcode_name = "sw";
                    default: opcode_name = "STORE_UNKNOWN";
                endcase
            end
            'b0110011: begin
                case(funct3)
                    'b000: opcode_name = (funct7[5]) ? "sub" : "add";
                    'b001: opcode_name = "sll";
                    'b010: opcode_name = "slt";
                    'b011: opcode_name = "sltu";
                    'b100: opcode_name = "xor";
                    'b101: opcode_name = (funct7[5]) ? "sra" : "srl";
                    'b110: opcode_name = "or";
                    'b111: opcode_name = "and";
                    default: opcode_name = "OP_UNKNOWN";
                endcase
            end
            'b0110111: begin
                opcode_name = "lui";
            end
            'b0010111: begin
                opcode_name = "auipc";
            end
            'b1101111: begin
                opcode_name = "jal";
            end
            'b1100111: begin
                opcode_name = "jalr";
            end
            'b1100011: begin
                case(funct3)
                    'b000: opcode_name = "beq";
                    'b001: opcode_name = "bne";
                    'b100: opcode_name = "blt";
                    'b101: opcode_name = "bge";
                    'b110: opcode_name = "bltu";
                    'b111: opcode_name = "bgeu";
                    default: opcode_name = "BRANCH_UNKNOWN";
                endcase
            end
            'b0001111: begin
                opcode_name = "MISC_MEM";
            end
            'b1110011: begin
                opcode_name = "SYSTEM";
            end
            default:   opcode_name = "UNKNOWN";
        endcase
    endfunction

    function string rob_entry_name(ROB_ENTRY_t entry);
        rob_entry_name = $sformatf("ROB Entry - rd_arch: x%d, rd_phy_old: r%d, rd_phy_new: r%d",
                                   entry.rd_arch, entry.rd_phy_old, entry.rd_phy_new);
    endfunction

    function string instruction_brief_name(instruction_t instr);
        if(instr.opcode == '0) begin
            instruction_brief_name = "NOP";
        end
        else if(instr.opcode == 'b0110011)begin // R-type
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %s, %s",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            reg_name(instr.rs1_addr, 1),
                                            reg_name(instr.rs2_addr, 1));
        end
        else if(instr.opcode == 'b0010011)begin // I-type
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %s, %0d",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            reg_name(instr.rs1_addr, 1),
                                            $signed(instr.immediate));
        end
        else if(instr.opcode == 'b0000011)begin // Load
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %0d(%s)",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            $signed(instr.immediate),
                                            reg_name(instr.rs1_addr, 1));
        end
        else if(instr.opcode == 'b0100011)begin // Store
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %0d(%s)",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rs2_addr, 1),
                                            $signed(instr.immediate),
                                            reg_name(instr.rs1_addr, 1));
        end
        else if(instr.opcode == 'b1100011)begin // Branch
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %s, %0d",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rs1_addr, 1),
                                            reg_name(instr.rs2_addr, 1),
                                            $signed(instr.immediate));
        end
        else if(instr.opcode == 'b1101111)begin // JAL
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %0d",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            $signed(instr.immediate));
        end
        else if(instr.opcode == 'b1100111)begin // JALR
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %s, %0d",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            reg_name(instr.rs1_addr, 1),
                                            $signed(instr.immediate));
        end
        else if(instr.opcode == 'b0110111)begin // LUI
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %0d",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            $signed(instr.immediate));
        end
        else if(instr.opcode == 'b0010111)begin // AUIPC
            instruction_brief_name = $sformatf("addr: %h, Instruction:  %s %s, %0d",
                                            instr.instruction_addr,
                                            opcode_name(instr.opcode, instr.funct3, instr.funct7),
                                            reg_name(instr.rd_addr, 1),
                                            $signed(instr.immediate));
        end
        else begin
            instruction_brief_name = $sformatf("addr: %h, Instruction: UNKNOWN",
                                            instr.instruction_addr);
        end

    endfunction

    function string rs_issue_instruction(RS_ENTRY_t entry, input [1:0] issue_type);
        rs_issue_instruction = $sformatf("RS Entry - rob_id: %d, funct7: %d, funct3: %d, rs1_phy: r%0d, rs2_phy: r%0d, rd_phy: r%0d, immediate: %d, valid: %b, age: %d, issue_type: %d",
                                   entry.rob_id, entry.funct7, entry.funct3,
                                   entry.rs1_phy, entry.rs2_phy, entry.rd_phy,
                                   entry.immediate, entry.valid, entry.age, issue_type);
    endfunction
endpackage
