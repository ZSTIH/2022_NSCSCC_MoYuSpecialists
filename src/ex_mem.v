`include "defines.v"

module ex_mem(
    input                                   clk,
    input                                   resetn,

    input   [`InstAddrBus]                  pc_i,
    output  reg[`InstAddrBus]               pc_o,

    input                                   wen_i,
    input   [`RegAddrBus]                   waddr_i,
    input   [`RegBus]                       wdata_i,
    input   [`AluOpBus]                     aluop_i,
    input   [`DataAddrBus]                  data_addr_i,

    output  reg                             wen_o,
    output  reg[`RegAddrBus]                waddr_o,
    output  reg[`RegBus]                    wdata_o,
    output  reg[`AluOpBus]                  aluop_o,
    output  reg[`DataAddrBus]               data_addr_o,

    // write hilo_reg
    input                                   hilo_wen_i,
    input   [`RegBus]                       hi_i,
    input   [`RegBus]                       lo_i,
    output  reg                             hilo_wen_o,
    output  reg[`RegBus]                    hi_o,
    output  reg[`RegBus]                    lo_o,

    // write cp0_reg
    input                                   cp0_reg_wen_i,
    input   [`RegBus]                       cp0_reg_wdata_i,
    input   [`RegAddrBus]                   cp0_reg_waddr_i,
    output  reg                             cp0_reg_wen_o,
    output  reg[`RegBus]                    cp0_reg_wdata_o,
    output  reg[`RegAddrBus]                cp0_reg_waddr_o,

    // exception_type
    input   [`RegBus]                       exception_type_i,
    output  reg[`RegBus]                    exception_type_o,

    // delayslot
    input                                   is_in_delayslot_i,
    output  reg                             is_in_delayslot_o,

    input   [`RegBus]                       data_rdata_i,
    output  reg[`RegBus]                    data_rdata_o,

    input                                   flush,
    input   [3:0]                           stall_i
);

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        pc_o <= `ZeroWord;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        wdata_o <= `ZeroWord;
        aluop_o <= `EXE_NOP_OP;
        data_addr_o <= `ZeroWord;
        data_rdata_o <= `ZeroWord;
        hilo_wen_o <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        cp0_reg_wen_o <= `WriteDisable;
        cp0_reg_wdata_o <= `ZeroWord;
        cp0_reg_waddr_o <= `ZeroRegAddr;
        exception_type_o <= `ZeroWord;
        is_in_delayslot_o <= `NotInDelaySlot;
    end else if (flush == `FlushEnable) begin
        pc_o <= `ZeroWord;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        wdata_o <= `ZeroWord;
        aluop_o <= `EXE_NOP_OP;
        data_addr_o <= `ZeroWord;
        data_rdata_o <= `ZeroWord;
        hilo_wen_o <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        cp0_reg_wen_o <= `WriteDisable;
        cp0_reg_wdata_o <= `ZeroWord;
        cp0_reg_waddr_o <= `ZeroRegAddr;
        exception_type_o <= `ZeroWord;
        is_in_delayslot_o <= `NotInDelaySlot;
    end else if ((stall_i[2] == `Stop) && (stall_i[3] == `NoStop)) begin
        pc_o <= `ZeroWord;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        wdata_o <= `ZeroWord;
        aluop_o <= `EXE_NOP_OP;
        data_addr_o <= `ZeroWord;
        data_rdata_o <= `ZeroWord;
        hilo_wen_o <= `WriteDisable;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        cp0_reg_wen_o <= `WriteDisable;
        cp0_reg_wdata_o <= `ZeroWord;
        cp0_reg_waddr_o <= `ZeroRegAddr;
        exception_type_o <= `ZeroWord;
        is_in_delayslot_o <= `NotInDelaySlot;
    end else if (stall_i[2] == `NoStop) begin
        pc_o <= pc_i;
        wen_o <= wen_i;
        waddr_o <= waddr_i;
        wdata_o <= wdata_i;
        aluop_o <= aluop_i;
        data_addr_o <= data_addr_i;
        data_rdata_o <= data_rdata_i;
        hilo_wen_o <= hilo_wen_i;
        hi_o <= hi_i;
        lo_o <= lo_i;
        cp0_reg_wen_o <= cp0_reg_wen_i;
        cp0_reg_wdata_o <= cp0_reg_wdata_i;
        cp0_reg_waddr_o <= cp0_reg_waddr_i;
        exception_type_o <= exception_type_i;
        is_in_delayslot_o <= is_in_delayslot_i;
    end
end

endmodule