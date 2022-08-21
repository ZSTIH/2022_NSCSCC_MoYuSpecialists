`include "defines.v"

module id_ex(
    input                                   clk,
    input                                   resetn,

    input                                   do_inst_flag,

    input   [`InstAddrBus]                  pc_i,
    input   [`InstBus]                      inst_i,
    input   [`AluSelBus]                    alusel_i,
    input   [`AluOpBus]                     aluop_i,
    input                                   wen_i,
    input   [`RegAddrBus]                   waddr_i,
    input   [`RegBus]                       rdata1_i,
    input   [`RegBus]                       rdata2_i,
    input   [`RegBus]                       link_addr_i,
    input   [`RegBus]                       exception_type_i,
    input                                   is_in_delayslot_i,
    input                                   next_inst_in_delayslot_i,

    output  reg[`InstAddrBus]               pc_o,
    output  reg[`InstBus]                   inst_o,
    output  reg[`AluSelBus]                 alusel_o,
    output  reg[`AluOpBus]                  aluop_o,
    output  reg                             wen_o,
    output  reg[`RegAddrBus]                waddr_o,
    output  reg[`RegBus]                    rdata1_o,
    output  reg[`RegBus]                    rdata2_o,
    output  reg[`RegBus]                    link_addr_o,
    output  reg[`RegBus]                    exception_type_o,
    output  reg                             is_in_delayslot_o,
    output  reg                             next_inst_in_delayslot_o,

    input                                   branch_flag_i,
    input   [`InstAddrBus]                  branch_addr_i,
    output                                  branch_flag_o,
    output  reg[`InstAddrBus]               branch_addr_o,

    input                                   flush,
    input   [3:0]                           stall_i
);

reg watch_branch_flag;
assign branch_flag_o = watch_branch_flag && do_inst_flag;

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        pc_o <= `ZeroWord;
        inst_o <= `ZeroWord;
        alusel_o <= `EXE_RES_NOP;
        aluop_o <= `EXE_NOP_OP;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        rdata1_o <= `ZeroWord;
        rdata2_o <= `ZeroWord;
        link_addr_o <= `ZeroWord;
        exception_type_o <= `ZeroWord;
        is_in_delayslot_o <= `NotInDelaySlot;
    end else if (flush == `FlushEnable) begin
        pc_o <= `ZeroWord;
        inst_o <= `ZeroWord;
        alusel_o <= `EXE_RES_NOP;
        aluop_o <= `EXE_NOP_OP;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        rdata1_o <= `ZeroWord;
        rdata2_o <= `ZeroWord;
        link_addr_o <= `ZeroWord;
        exception_type_o <= `ZeroWord;
        is_in_delayslot_o <= `NotInDelaySlot;
    end else if ((stall_i[1] == `Stop) && (stall_i[2] == `NoStop)) begin
        pc_o <= `ZeroWord;
        inst_o <= `ZeroWord;
        alusel_o <= `EXE_RES_NOP;
        aluop_o <= `EXE_NOP_OP;
        wen_o <= `WriteDisable;
        waddr_o <= `ZeroRegAddr;
        rdata1_o <= `ZeroWord;
        rdata2_o <= `ZeroWord;
        link_addr_o <= `ZeroWord;
        exception_type_o <= `ZeroWord;
        is_in_delayslot_o <= `NotInDelaySlot;
    end else if (stall_i[1] == `NoStop) begin
        pc_o <= pc_i;
        inst_o <= inst_i;
        alusel_o <= alusel_i;
        aluop_o <= aluop_i;
        wen_o <= wen_i;
        waddr_o <= waddr_i;
        rdata1_o <= rdata1_i;
        rdata2_o <= rdata2_i;
        link_addr_o <= link_addr_i;
        exception_type_o <= exception_type_i;
        is_in_delayslot_o <= is_in_delayslot_i;
    end
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                               next_inst_in_delayslot_o <= `NotInDelaySlot;
    else if (flush == `FlushEnable)                         next_inst_in_delayslot_o <= `NotInDelaySlot;
    else if (next_inst_in_delayslot_i == `InDelaySlot)      next_inst_in_delayslot_o <= `InDelaySlot;
    else if (do_inst_flag == `True_v)                       next_inst_in_delayslot_o <= `NotInDelaySlot;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                               watch_branch_flag <= `False_v;
    else if (flush == `FlushEnable)                         watch_branch_flag <= `False_v;
    else if (branch_flag_i && (stall_i[1] == `NoStop))      watch_branch_flag <= `True_v;
    else if (do_inst_flag == `True_v)                       watch_branch_flag <= `False_v;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                               branch_addr_o <= `ZeroWord;
    else if (flush == `FlushEnable)                         branch_addr_o <= `ZeroWord;
    else if (branch_flag_i)                                 branch_addr_o <= branch_addr_i;
    else if (do_inst_flag == `True_v)                       branch_addr_o <= `ZeroWord;
end

endmodule