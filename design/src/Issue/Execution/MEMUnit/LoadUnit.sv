`timescale 1ns/1ps

module LoadUnit #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32, ROB_WIDTH = 5, PHY_WIDTH = 6)(
    input  logic                  isLoad,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [2:0]            funct3,
    input  logic [ROB_WIDTH-1:0]  rob_id,
    input  logic [PHY_WIDTH-1:0]  rd_phy,
    output logic [DATA_WIDTH-1:0] load_data,
    output logic                  load_valid,
    output logic [ADDR_WIDTH-1:0] load_raddr,
    output logic [ROB_WIDTH-1:0]  load_rob_id,
    output logic [PHY_WIDTH-1:0]  load_rd_phy
);

    logic [1:0] memory_index;
    assign memory_index = addr[1:0];

    assign mem_raddr = (isLoad) ? addr : '0;
    assign mem_rd_en = isLoad ? 1 : 0;
    // always_comb begin
    //     if(mem_rdata_valid) begin
    //         mem_raddr   = '0;
    //         mem_rd_en   = 0;
    //         case(funct3_internal)
    //             LB: load_data = {{24{mem_rdata[(memory_index << 3) +:8][7]}}, mem_rdata[(memory_index << 3) +:8]};
    //             LH: begin
    //                 if(memory_index[1])
    //                     load_data = {{16{mem_rdata[31]}}, mem_rdata[31:16]};
    //                 else
    //                     load_data = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
    //             end
    //             LW: load_data = mem_rdata;
    //             LBU: load_data = {24'b0, mem_rdata[(memory_index << 3) +:8]};
    //             LHU: begin
    //                 if(memory_index[1])
    //                     load_data = {16'b0, mem_rdata[31:16]};
    //                 else
    //                     load_data = {16'b0, mem_rdata[15:0]};
    //             end
    //             default: load_data = 0;
    //         endcase
    //     end
    //     else begin
    //         load_valid = 0;
    //     end
    // end

endmodule
