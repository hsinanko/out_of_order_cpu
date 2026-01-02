`timescale 1ns/1ps
import parameter_pkg::*;

module MEMUnit #(ADDR_WIDTH = 32, DATA_WIDTH = 32)(
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data,
    input  logic [4:0]funct3,
    input  logic isLoad,          
    input  logic isStore,
    output logic [4:0]mem_funct3,        // load --> to memory
    output logic mem_read_en,            // load --> to memory
    output logic [ADDR_WIDTH-1:0] raddr, // load/store --> to memory
    output logic [DATA_WIDTH-1:0] wdata, // store
    output logic [ADDR_WIDTH-1:0] waddr,  // store
    output logic wdata_valid             // store
);
    
    logic [1:0]memory_index;
    assign memory_index = addr[1:0];

    integer i;
    always_comb begin
        if(isStore)begin  // Store
            wdata_valid = 1;
            waddr  = addr; // to store queue
            case(funct3)
                SB: wdata  = (data[memory_index] << (memory_index << 3));
                SH:begin
                    if(memory_index[1])
                        wdata = {data[31:16], 16'h0000};
                    else
                        wdata = {16'h0000, data[15:0]};
                end
                SW: wdata = data;
            endcase 
        end
        else begin
            wdata_valid = 0;
            waddr       = 0;
            wdata       = 0;
        end

        if(isLoad)begin  // Load
            raddr       = addr; // to load queue
            mem_funct3  = funct3;
            mem_read_en = 1;
        end
        else begin
            mem_read_en = 0;
            raddr       = 0;

            mem_funct3  = 0;
        end
    end



endmodule 
