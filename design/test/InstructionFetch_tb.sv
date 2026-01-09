`include "../src/InstructionFetch.sv"
`timescale 1ns / 1ps

module InstructionFetch_Test;

    // Testbench code would go here to instantiate the InstructionFetch module,
    // apply test vectors, and check outputs.
    // Since the request is to compare with the provided snippet,
    // we will leave this section empty for now.

    logic clk; 
    logic rst;
    logic isJump;
    logic [31:0] jump_address;
    logic [31:0] instruction_addr_0;
    logic [31:0] instruction_addr_1;
    logic [31:0] instruction_0; 
    logic [31:0] instruction_1; 
    logic [1:0] valid;
    logic [3:0] n_cycles;
    logic [31:0] start_addr;
    InstructionFetch #(32, 32) dut (
        .clk(clk),
        .rst(rst),
        .isJump(isJump),
        .start_addr(start_addr),
        .jump_address(jump_address),
        .instruction_addr_0(instruction_addr_0),
        .instruction_addr_1(instruction_addr_1), // unused in this test
        .instruction_0(instruction_0),
        .instruction_1(instruction_1), // unused in this test
        .valid(valid) // unused in this test
    );

    initial begin
        $dumpfile("InstructionFetch_Test.vcd");
        $dumpvars(0, InstructionFetch_Test);
    end

    initial begin
        // Testbench initialization and stimulus code
        clk = 0;
        rst = 1;
        isJump = 0;
        jump_address = 0;
        start_addr = 0;
        $display(" ========= Simulation started =========");
        #10; rst = 0;    
    end

    always #5 clk = ~clk; // Clock generation

    always @(posedge clk or posedge rst)begin
        if(rst) n_cycles <= 0;
        else n_cycles <= n_cycles + 1;
        else begin
            $display(" ========= Simulation ended =========");
            $finish;
        end
    end

    always @(negedge clk or posedge rst) begin
        if(valid != 2'b00 && !rst) begin
            display_state();
        end
    end

    task automatic display_state();
        $display("Cycle: %0d | PC: %2d | Instr Addr 0: %0d | Instr 0: %h | Valid: %b", 
                 n_cycles, dut.pc, instruction_addr_0, instruction_0, valid);
    endtask

    
endmodule
