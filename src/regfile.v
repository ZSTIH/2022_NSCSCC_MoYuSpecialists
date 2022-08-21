`include "defines.v"

module regfile(

    input                           clk,
    input                           resetn,

    // write
    input                           wen,
    input   [`RegAddrBus]           waddr,
    input   [`RegBus]               wdata,

    // read1
    input                           ren1,
    input   [`RegAddrBus]           raddr1,
    output  reg[`RegBus]            rdata1,

    // read2
    input                           ren2,
    input   [`RegAddrBus]           raddr2,
    output  reg[`RegBus]            rdata2

);

    reg[`RegBus]    regs[0:`RegNum-1];

    always @(posedge clk) begin
        if (resetn == `RstDisable) begin
            if ((wen == `WriteEnable) && (waddr != `RegNumLog2'd0)) begin
                regs[waddr] <= wdata;
            end
        end
    end

    always @(*) begin
        if (resetn == `RstEnable) begin
            rdata1 = `ZeroWord;
        end else if (raddr1 == `RegNumLog2'd0) begin
            rdata1 = `ZeroWord;
        end else if ((raddr1 == waddr) && (wen == `WriteEnable) && (ren1 == `ReadEnable)) begin
            rdata1 = wdata;
        end else if (ren1 == `ReadEnable) begin
            rdata1 = regs[raddr1];
        end else begin
            rdata1 = `ZeroWord;
        end
    end

    always @(*) begin
        if (resetn == `RstEnable) begin
            rdata2 = `ZeroWord;
        end else if (raddr2 == `RegNumLog2'd0) begin
            rdata2 = `ZeroWord;
        end else if ((raddr2 == waddr) && (wen == `WriteEnable) && (ren2 == `ReadEnable)) begin
            rdata2 = wdata;
        end else if (ren2 == `ReadEnable) begin
            rdata2 = regs[raddr2];
        end else begin
            rdata2 = `ZeroWord;
        end
    end

endmodule