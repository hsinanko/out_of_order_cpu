`timescale 1ns/1ps

module StoreUnit #(ADDR_WIDTH = 32, DATA_WIDTH = 32, ROB_WIDTH = 5)(
    input  logic isStore,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data,
    input  logic [2:0]funct3,  
    input  logic [ROB_WIDTH-1:0] rob_id,   
    output logic [ADDR_WIDTH-1:0] store_waddr, // store --> to memory
    output logic [DATA_WIDTH-1:0] store_wdata, // store
    output logic [ROB_WIDTH-1:0] store_rob_id,
    output logic                 store_valid
);
    
    logic [1:0]memory_index;
    assign memory_index = addr[1:0];

    integer i;
    always_comb begin
        if(isStore)begin  // Store
            store_valid  = 1;
            store_waddr  = addr; // to store queue
            store_rob_id = rob_id;
            case(funct3)
                SB: store_wdata  = (data[memory_index] << (memory_index << 3));
                SH:begin
                    if(memory_index[1])
                        store_wdata = {data[31:16], 16'h0000};
                    else
                        store_wdata = {16'h0000, data[15:0]};
                end
                SW: store_wdata = data;
            endcase 
        end
        else begin
            store_waddr  = 0;
            store_wdata  = 0;
            store_valid  = 0;
        end

    end
endmodule 
