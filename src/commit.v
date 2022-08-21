`include "defines.v"

module commit(
    input                               clk,
    input                               resetn,

    input   [`InstAddrBus]              pc_i,
    input                               wen_i,
    input   [`RegAddrBus]               waddr_i,
    input   [`RegBus]                   wdata_i,
    input                               hilo_wen_i,
    input   [`RegBus]                   hi_i,
    input   [`RegBus]                   lo_i,
    input                               cp0_reg_wen_i,
    input   [`RegBus]                   cp0_reg_wdata_i,
    input   [`RegAddrBus]               cp0_reg_waddr_i,

    output  reg[`InstAddrBus]           pc_o,
    output  reg                         wen_o,
    output  reg[`RegAddrBus]            waddr_o,
    output  reg[`RegBus]                wdata_o,
    output  reg                         hilo_wen_o,
    output  reg[`RegBus]                hi_o,
    output  reg[`RegBus]                lo_o,
    output  reg                         cp0_reg_wen_o,
    output  reg[`RegBus]                cp0_reg_wdata_o,
    output  reg[`RegAddrBus]            cp0_reg_waddr_o,

    input                               flush,
    input                               stall_i
);

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        pc_o <= `ZeroWord;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        wdata_o <= `ZeroWord;
        hilo_wen_o <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        cp0_reg_wen_o <= `WriteDisable;
        cp0_reg_wdata_o <= `ZeroWord;
        cp0_reg_waddr_o <= `ZeroRegAddr;
    end else if (flush == `FlushEnable) begin
        pc_o <= `ZeroWord;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        wdata_o <= `ZeroWord;
        hilo_wen_o <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        cp0_reg_wen_o <= `WriteDisable;
        cp0_reg_wdata_o <= `ZeroWord;
        cp0_reg_waddr_o <= `ZeroRegAddr;
    end else if (stall_i == `NoStop) begin
        pc_o <= pc_i;
        wen_o <= wen_i;
        waddr_o <= waddr_i;
        wdata_o <= wdata_i;
        hilo_wen_o <= hilo_wen_i;
        hi_o <= hi_i;
        lo_o <= lo_i;
        cp0_reg_wen_o <= cp0_reg_wen_i;
        cp0_reg_wdata_o <= cp0_reg_wdata_i;
        cp0_reg_waddr_o <= cp0_reg_waddr_i;
    end
end

endmodule