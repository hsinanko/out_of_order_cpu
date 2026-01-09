package info_pkg; 
    import parameter_pkg::*;
    import typedef_pkg::*;
    task print_Fetch(logic [1:0] instruction_valid,
                     logic [ADDR_WIDTH-1:0] instruction_addr_0,
                     logic [DATA_WIDTH-1:0] instruction_0,
                     logic [ADDR_WIDTH-1:0] instruction_addr_1,
                     logic [DATA_WIDTH-1:0] instruction_1);
        $display("\t===============================================");
        $display("\t----------- Instruction Fetch Stage -----------");
        $display("\t===============================================");
        if(instruction_valid == 2'b00) begin
            $display("\t\tNo valid instructions fetched.");
        end
        else begin
            if(instruction_valid == 2'b01 || instruction_valid == 2'b10)
                $display("\t\tFetched  %2d valid instructions.", 1);
            else if(instruction_valid == 2'b11)
                $display("\t\tFetched  %2d valid instructions.", 2);
            if(instruction_valid[0])begin
                $display("\tInstruction 0: PC = 0x%h, 0x%h", instruction_addr_0, instruction_0);
            end

            if(instruction_valid[1]) begin
                $display("\tInstruction 1: PC = 0x%h, 0x%h", instruction_addr_1, instruction_1);
            end
        end
    endtask : print_Fetch


    task print_Rename(logic [1:0] instruction_valid_reg,
                      logic [ADDR_WIDTH-1:0] instruction_addr_0_reg,
                      logic [DATA_WIDTH-1:0] instruction_0_reg,
                      logic [ADDR_WIDTH-1:0] instruction_addr_1_reg,
                      logic [DATA_WIDTH-1:0] instruction_1_reg,
                      logic issue_alu_valid_reg,
                      RS_ENTRY_t issue_instruction_alu_reg,
                      logic issue_ls_valid_reg,
                      RS_ENTRY_t issue_instruction_ls_reg,
                      logic issue_branch_valid_reg,
                      RS_ENTRY_t issue_instruction_branch_reg);
        $display("\n\t===============================================");
        $display("\t------- Decode - Rename, Dispatch Stage -------");
        $display("\t===============================================");
        if(instruction_valid_reg == 2'b00) begin
            $display("\t\tNo valid instructions renamed.");
        end
        else begin
            if(instruction_valid_reg == 2'b01 || instruction_valid_reg == 2'b10)
                $display("\t\tRenamed %2d valid instructions.", 1);
            else if(instruction_valid_reg == 2'b11)
                $display("\t\tRenamed %2d valid instructions.", 2);

            if(instruction_valid_reg[0])begin
                $display("\tInstruction 0: PC = 0x%h, 0x%h", instruction_addr_0_reg, instruction_0_reg);
            end

            if(instruction_valid_reg[1]) begin
                $display("\tInstruction 1: PC = 0x%h, 0x%h", instruction_addr_1_reg, instruction_1_reg);
            end
            $display("\t\tDispatch to Reservation Station .....");
            if(issue_alu_valid_reg | issue_ls_valid_reg | issue_branch_valid_reg) begin
                $display("\t\tIssued Instructions");
                if(issue_alu_valid_reg) begin
                    $display("\tALU Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_alu_reg.addr, issue_instruction_alu_reg.rob_id);
                end
                if(issue_ls_valid_reg) begin
                    if(issue_instruction_ls_reg.opcode == LOAD)
                        $display("\tLoad Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_ls_reg.addr, issue_instruction_ls_reg.rob_id);
                    else
                        $display("\tStore Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_ls_reg.addr, issue_instruction_ls_reg.rob_id);
                end
                if(issue_branch_valid_reg) begin
                    $display("\tBranch Instruction: PC=0x%h, ROB_ID=%0d", issue_instruction_branch_reg.addr, issue_instruction_branch_reg.rob_id);
                end
            end
            else begin
                $display("\t\tNo valid instructions issued.");
            end

        end
    endtask : print_Rename

    task print_Execution(logic alu_valid,
                         logic ls_valid,
                         logic branch_valid,
                         logic [ROB_WIDTH-1:0] alu_rob_id,
                         logic [DATA_WIDTH-1:0] alu_output,
                         logic [ROB_WIDTH-1:0] ls_rob_id,
                         logic wdata_valid,
                         logic [ADDR_WIDTH-1:0] waddr,
                         logic [DATA_WIDTH-1:0] wdata,
                         logic [PHY_WIDTH-1:0] rd_phy_ls,
                         logic [DATA_WIDTH-1:0] mem_rdata,
                         logic [ROB_WIDTH-1:0] branch_rob_id,
                         logic [ADDR_WIDTH-1:0] nextPC);
        $display("\n\t===============================================");
        $display("\t----------- Issue / Execution Stage -----------");
        $display("\t===============================================");
        // Add execution stage debug information here
        if(!alu_valid && !ls_valid && !branch_valid) begin
            $display("\t\tNo valid instructions executed.");
        end
        else begin
            if(alu_valid) begin
                $display("\tALU Result: ROB_ID=%0d, Result=%h", alu_rob_id, alu_output);
            end
            if(ls_valid) begin
                if(wdata_valid)
                    $display("\tStore Data: ROB_ID=%0d, Addr=%h, Data=%h", ls_rob_id, waddr, wdata);
                else
                    $display("\tLoad Data: ROB_ID=%0d, rd_phy=%h, Data=%h", ls_rob_id, rd_phy_ls, mem_rdata);
            end
            if(branch_valid) begin
                $display("\tBranch Execution: ROB_ID=%0d, NextPC=%h", branch_rob_id, nextPC);
            end
        end

    endtask : print_Execution


    task print_Commit(logic retire_pr_valid_reg,
                      logic retire_store_valid_reg,
                      logic retire_branch_valid_reg,
                      logic [REG_WIDTH-1:0] rd_arch_commit_reg,
                      logic [PHY_WIDTH-1:0] rd_phy_old_commit_reg,
                      logic [PHY_WIDTH-1:0] rd_phy_new_commit_reg);
        $display("\n\t===============================================");
        $display("\t---------------- Commit Stage -----------------");
        $display("\t===============================================");

        if(!retire_pr_valid_reg && !retire_store_valid_reg && !retire_branch_valid_reg) begin
            $display("\t\tNo valid instructions committed.");
        end
        else begin
            $display("\tCommitted Instruction: RD_ARCH=%0d, RD_PHY_OLD=%0d, RD_PHY_NEW=%0d", rd_arch_commit_reg, rd_phy_old_commit_reg, rd_phy_new_commit_reg);
        end
    endtask : print_Commit
endpackage : info_pkg
