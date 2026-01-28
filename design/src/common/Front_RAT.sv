`timescale 1ns/1ps

module Front_RAT #(parameter ARCH_REGS = 32, PHY_WIDTH = 6)(
    input  logic clk,
    input  logic rst,
    input  logic flush,
    input  logic done,
    rename_if.rat_sink rat_0_bus,
    rename_if.rat_sink rat_1_bus,
    rename_if.freelist_sink freelist_0_bus,
    rename_if.freelist_sink freelist_1_bus,
    // ======== from BACK_RAT =======================
    // BACK_RAT will handle commit updates
    input  logic [PHY_WIDTH*ARCH_REGS-1:0]back_rat,
    // ======== for debugging output =================
    output logic [PHY_WIDTH*ARCH_REGS-1:0]front_rat_out
);

    // Register Alias Table (RAT)
    logic [PHY_WIDTH-1:0] FRONT_RAT [0:ARCH_REGS-1];
    logic [PHY_WIDTH-1:0] rat_tmp [0:ARCH_REGS-1];

    // For debugging: output FRONT_RAT contents
    genvar j;
    generate
        for (j = 0; j < ARCH_REGS; j = j + 1) begin : gen_front_rat_out
            assign front_rat_out[(j+1)*PHY_WIDTH-1 -: PHY_WIDTH] = FRONT_RAT[j];
        end
    endgenerate


    always_latch begin
        rat_0_bus.rs1_phy = FRONT_RAT[rat_0_bus.rs1_arch];
        rat_0_bus.rs2_phy = FRONT_RAT[rat_0_bus.rs2_arch];
        rat_0_bus.rd_phy  = FRONT_RAT[rat_0_bus.rd_arch];
        rat_1_bus.rs1_phy = (rat_0_bus.valid && rat_1_bus.rs1_arch == rat_0_bus.rd_arch) ? freelist_0_bus.rd_phy_new : FRONT_RAT[rat_1_bus.rs1_arch];
        rat_1_bus.rs2_phy = (rat_0_bus.valid && rat_1_bus.rs2_arch == rat_0_bus.rd_arch) ? freelist_0_bus.rd_phy_new : FRONT_RAT[rat_1_bus.rs2_arch];
        rat_1_bus.rd_phy  = (rat_0_bus.valid && rat_1_bus.rd_arch == rat_0_bus.rd_arch)  ? freelist_0_bus.rd_phy_new : FRONT_RAT[rat_1_bus.rd_arch];
    end



    integer i;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < ARCH_REGS; i++)
                FRONT_RAT[i] <= i;
        end 
        else if(flush)begin
            // On flush, restore RAT from BACK_RAT
            for (i = 0; i < ARCH_REGS; i++) begin
                FRONT_RAT[i] <= back_rat[i*PHY_WIDTH +: PHY_WIDTH];
            end
        end
        else if(done)begin
            for (i = 0; i < ARCH_REGS; i++) begin
                FRONT_RAT[i] <= back_rat[i*PHY_WIDTH +: PHY_WIDTH];
            end
        end
        else begin
            // Update RAT for first instruction
            if (rat_0_bus.valid) begin
                FRONT_RAT[rat_0_bus.rd_arch] <= freelist_0_bus.rd_phy_new;
            end
            // Update RAT for second instruction
            if (rat_1_bus.valid) begin
                FRONT_RAT[rat_1_bus.rd_arch] <= freelist_1_bus.rd_phy_new;
            end
        end


    end


    // Output mapped physical register

    // Second instruction outputs


    // For debugging: dump RAT contents at each clock cycle
    integer           mcd;
       
    always_ff @(negedge clk) begin
        mcd = $fopen("../test/build/Front_RAT.txt","w");

        for (i=0; i< ARCH_REGS; i=i+1) begin
            $fdisplay(mcd,"%2d %3d", i, FRONT_RAT[i]);
        end
        $fclose(mcd);
        //$display("Front_RAT contents dumped to Front_RAT file at time %0t", $time);
    end

endmodule
