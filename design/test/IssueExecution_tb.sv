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
    logic [PHY_REGS*DATA_WIDTH-1:0]PRF_data_out;
    logic [PHY_REGS-1:0]PRF_busy_out;
    logic [PHY_REGS-1:0]PRF_valid_out;
    logic [PHY_WIDTH*ARCH_REGS-1:0]front_rat_out;
    always #5 clk = ~clk; // Clock generation

    O3O_CPU #(ADDR_WIDTH, DATA_WIDTH, REG_WIDTH, PHY_REGS, PHY_WIDTH, ROB_WIDTH, NUM_RS_ENTRIES) dut_cpu (
        .clk(clk),
        .rst(rst),
        .boot_pc(boot_pc),
        .done(done),
        .PRF_data_out(PRF_data_out),
        .PRF_busy_out(PRF_busy_out),
        .PRF_valid_out(PRF_valid_out),
        .front_rat_out(front_rat_out)
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




    logic [31:0]n_cycles;
    logic finished;
    always@(posedge clk)begin
        if(rst) begin
            finished <= 0;
        end
        else if(done)begin
            finished <= 1;
        end
        else begin
            finished <= 0;
        end
    end

    always @(posedge clk or posedge rst)begin
        if(rst) 
            n_cycles <= 0;
        else begin
            n_cycles <= n_cycles + 1;
            $display("Cycle: %0d", n_cycles);
        end
    end

    always_comb begin
        if(n_cycles >= 300) begin
            $display("\n\t=========== Max cycle reached, ending simulation ===========\n");
            $finish;
        end
    end

    always_comb begin
        if(finished) begin
            $display("\n=========== Simulation ended ===========\n");
            print_CPU_State(PRF_data_out, PRF_busy_out, PRF_valid_out, front_rat_out);
            $finish;
        end
    end

    task automatic print_CPU_State(logic [PHY_REGS*DATA_WIDTH-1:0]PRF_data_out,
                                   logic [PHY_REGS-1:0]PRF_busy_out,
                                   logic [PHY_REGS-1:0]PRF_valid_out,
                                   logic [PHY_WIDTH*ARCH_REGS-1:0]front_rat_out);

        logic [PHY_WIDTH-1:0]front_rat[0:ARCH_REGS-1];
        logic [DATA_WIDTH-1:0]prf [0:PHY_REGS-1];
        integer i;
        $display("\n================ Architecture Register DATA ================"); 
        
        for(i = 0; i < PHY_REGS; i = i + 1) begin
            prf[i] = PRF_data_out[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
        for(i = 0; i < ARCH_REGS; i = i + 1) begin
            front_rat[i] = front_rat_out[i*PHY_WIDTH +: PHY_WIDTH];
            
        end

        for(i = 0; i < ARCH_REGS; i = i + 8)
        $display("x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h, x%02d = 0x%8h", 
                 i, prf[front_rat[i]],   i+1, prf[front_rat[i+1]], i+2, prf[front_rat[i+2]], i+3, prf[front_rat[i+3]],
                 i+4, prf[front_rat[i+4]], i+5, prf[front_rat[i+5]], i+6, prf[front_rat[i+6]], i+7, prf[front_rat[i+7]]);


        $display("==========================================\n");

    endtask
endmodule

