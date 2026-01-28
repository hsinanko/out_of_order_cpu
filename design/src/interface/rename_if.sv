interface rename_if #(parameter ARCH_REGS = 32, PHY_WIDTH = 6);

    logic valid;
    logic [4:0] rs1_arch;
    logic [4:0] rs2_arch;
    logic [4:0] rd_arch;
    logic [PHY_WIDTH-1:0] rs1_phy;;
    logic [PHY_WIDTH-1:0] rs2_phy;
    logic [PHY_WIDTH-1:0] rd_phy;

    logic [PHY_WIDTH-1:0] rd_phy_new;

    modport rat_source (
        output valid,
        output rs1_arch,
        output rs2_arch,
        output rd_arch,
        input  rs1_phy,
        input  rs2_phy,
        input  rd_phy
    );

    modport rat_sink (
        input  valid,
        input  rs1_arch,
        input  rs2_arch,
        input  rd_arch,
        output rs1_phy,
        output rs2_phy,
        output rd_phy
    );

    modport freelist_source(
        output valid,
        input rd_phy_new
    );

    modport freelist_sink(
        input valid,
        output rd_phy_new
    );

endinterface : rename_if
