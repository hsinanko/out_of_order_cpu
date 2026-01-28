`timescale 1ns/1ps
`include "../src/CPU.sv"

import parameter_pkg::*;
import register_pkg::*;
import debug_pkg::*;
import instruction_pkg::*;
import typedef_pkg::*;
module IssueExecution_tb();
    logic clk;
    logic rst;

    logic [ADDR_WIDTH-1:0] boot_pc;

    logic done;
    Debug_t debug_info;

    logic [PHY_WIDTH-1:0]front_rat[0:ARCH_REGS-1];
    logic [PHY_WIDTH-1:0]back_rat[0:ARCH_REGS-1];
    logic [DATA_WIDTH-1:0]prf [0:PHY_REGS-1];

    always #5 clk = ~clk; // Clock generation

    CPU #(ADDR_WIDTH, 
              DATA_WIDTH, 
              ARCH_REGS,
              PHY_REGS,
              PHY_WIDTH,
              NUM_ROB_ENTRY,
              ROB_WIDTH,
              NUM_RS_ENTRIES,
              BTB_ENTRIES,
              BTB_WIDTH,
              FIFO_DEPTH) 
    dut_cpu(
        .clk(clk),
        .rst(rst),
        .boot_pc(boot_pc),
        .done(done),
        .debug_info(debug_info)
    );



    initial begin
        $dumpfile("IssueExecution_tb.vcd");
        $dumpvars(0, IssueExecution_tb);
    end

    initial begin
        // Testbench initialization and stimulus code
        clk = 0;
        rst = 1;
        boot_pc = 0;
        $display("\n\t=========== Simulation started ===========\n");

        #10; rst = 0;
    end


    integer i, j;
    always_comb begin
        for(int i = 0; i < ARCH_REGS; i = i + 1) begin
            front_rat[i] = debug_info.front_rat_out[i*PHY_WIDTH +: PHY_WIDTH];
            back_rat[i]  = debug_info.back_rat_out[i*PHY_WIDTH +: PHY_WIDTH];
        end

        for(int j = 0; j < PHY_REGS; j = j + 1) begin
            prf[j] = debug_info.PRF_data_out[j*DATA_WIDTH +: DATA_WIDTH];
        end

    end

    logic [31:0]n_cycles;
    logic finished;

    // ========== Cycle Counter and Logging ==========
    always_ff @(posedge clk or posedge rst)begin
        if(rst) 
            n_cycles <= 0;
        else begin
            n_cycles <= n_cycles + 1;
        end
    end

    always_ff @(posedge clk)begin
        if(!rst)begin
            if(debug_info.retire_valid_reg)
                $display("Cycle: %5d Retired Address: 0x%08h", n_cycles, debug_info.retire_addr_reg);
            else
                $display("Cycle: %5d", n_cycles);
        end
    end

    // ========== Finish simulation after done signal ==========
    always_ff @(posedge clk)begin
        if(rst) 
            finished <= 0;
        else if(done) 
            finished <= 1;
        else 
            finished <= 0;
    end

    always_comb begin
        if(finished) begin
            $display("\n\t=========== Simulation ended ===========\n");
            print_CPU_State(1);
            $finish;
        end
        else if(n_cycles >= 6000) begin
            $display("\n\t=========== Max cycle reached, ending simulation ===========\n");
            print_CPU_State(0);
            $finish;
        end
    end

    task automatic print_CPU_State(logic finished);

        integer i;
        $display("\n================ Architecture Register DATA ================"); 
        
        if(finished) begin
        for(i = 0; i < ARCH_REGS; i = i + 8)
        $display("x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h", 
                 i, prf[front_rat[i]],   i+1, prf[front_rat[i+1]], i+2, prf[front_rat[i+2]], i+3, prf[front_rat[i+3]],
                 i+4, prf[front_rat[i+4]], i+5, prf[front_rat[i+5]], i+6, prf[front_rat[i+6]], i+7, prf[front_rat[i+7]]);
        end
        else begin
            for(i = 0; i < ARCH_REGS; i = i + 8)
                $display("x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h", 
                 i, prf[back_rat[i]],   i+1, prf[back_rat[i+1]], i+2, prf[back_rat[i+2]], i+3, prf[back_rat[i+3]],
                 i+4, prf[back_rat[i+4]], i+5, prf[back_rat[i+5]], i+6, prf[back_rat[i+6]], i+7, prf[back_rat[i+7]]);
        end
        $display("============================================================\n");
    endtask
endmodule

