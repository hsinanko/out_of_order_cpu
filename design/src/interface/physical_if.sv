interface physical_if #(parameter DATA_WIDTH = 32, PHY_WIDTH = 6)();
    // Read ports
    logic                 valid;
    logic [PHY_WIDTH-1:0] rs1_phy;
    logic [PHY_WIDTH-1:0] rs2_phy;
    logic [DATA_WIDTH-1:0] rs1_data;
    logic [DATA_WIDTH-1:0] rs2_data;
    
    modport source (
        output valid,
        output rs1_phy,
        output rs2_phy,
        input  rs1_data,
        input  rs2_data
    );

    modport sink (
        input valid,
        input rs1_phy,
        input rs2_phy,
        output rs1_data,
        output rs2_data
    );

endinterface : physical_if
