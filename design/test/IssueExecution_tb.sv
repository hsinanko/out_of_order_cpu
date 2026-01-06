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
    always #5 clk = ~clk; // Clock generation

    O3O_CPU #(ADDR_WIDTH, DATA_WIDTH, REG_WIDTH, PHY_REGS, PHY_WIDTH, ROB_WIDTH, NUM_RS_ENTRIES) dut_cpu (
        .clk(clk),
        .rst(rst),
        .boot_pc(boot_pc),
        .done(done)
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


    logic [7:0]n_cycles;
    always@(posedge clk)begin
        if(rst) begin
            n_cycles <= 0;
        end
        else if(!done)begin
            n_cycles <= n_cycles + 1;
        end
        else begin
            $display("\n=========== Simulation ended ===========\n");
            $finish;
        end
    end
endmodule

