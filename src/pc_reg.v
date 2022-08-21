`include "defines.v"

module pc_reg(
    input                           clk,
    input                           resetn,
    input                           flush,
    input   [`InstAddrBus]          epc,
    input                           ibuffer_full,
    input                           inst_addr_ok,
    input                           inst_req_success,
    input                           branch_flag,
    input   [`InstAddrBus]          branch_addr,

    output  reg                     inst_req,
    output  reg[`InstAddrBus]       pc
);

reg[`InstAddrBus] npc;
always @(*) begin
    if (resetn == `RstEnable)                       npc = `InitialPC;
    else if (flush == `FlushEnable)                 npc = epc;
    else if (branch_flag)                           npc = branch_addr;
    else if (ibuffer_full == 1'b1)                  npc = pc;
    else if (inst_req_success == 1'b1)              npc = pc + 4;
    else                                            npc = pc;
end

always @(posedge clk) pc <= npc;

always @(posedge clk) begin
    if (resetn == `RstEnable)                       inst_req <= `RequestDisable;
    else if (flush == `FlushEnable)                 inst_req <= `RequestDisable;
    else if (ibuffer_full == 1'b1)                  inst_req <= `RequestDisable;
    else if (inst_req_success == 1'b1)              inst_req <= `RequestDisable;
    else if (inst_addr_ok == `AddrOK)               inst_req <= `RequestEnable;
end

endmodule