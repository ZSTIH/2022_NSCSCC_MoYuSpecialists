`include "defines.v"

module InstBuffer(
    input                           clk,
    input                           resetn,
    input                           flush,
    input   [`InstBus]              inst_i,
    input   [`InstAddrBus]          pc_i,
    input                           inst_data_ok,
    input                           inst_req_success,
    input                           stall_i,
    input                           branch_flag,

    output  reg[`InstBus]           inst_o,
    output  reg[`InstAddrBus]       pc_o,
    output  reg                     do_inst_flag,
    output                          ibuffer_full
);

reg[`InstBus] FIFO_data[`InstBufferSize:0];
reg[`InstAddrBus] FIFO_addr[`InstBufferSize:0];
reg[`InstBufferSize:0] FIFO_valid;
reg[`InstBufferAddrBus] head;
reg[`InstBufferAddrBus] tail;
reg[`InstBus] req_addr;
reg flush_for_branch;
reg flush_for_exception;
wire[`SignedInstBufferAddrBus] head_negative = ~{1'b0, head} + 1;
wire[`SignedInstBufferAddrBus] tail_minus_head = {1'b0, tail} + head_negative;
wire[`SignedInstBufferAddrBus] tail_minus_head_plus = tail_minus_head + `InstBufferSize + 1;
wire[`InstBufferAddrBus] ibuffer_num = (tail_minus_head[6] == 0) ?
                                       (tail_minus_head[5:0]) :
                                       (tail_minus_head_plus[5:0]);
assign ibuffer_full = (ibuffer_num == `InstBufferSize);
assign ibuffer_empty = (ibuffer_num == 0);
wire[`InstBufferAddrBus] new_tail = (tail == `InstBufferSize) ? `ZeroInstBufferAddr : (tail + 1);
wire[`InstBufferAddrBus] new_head = (head == `InstBufferSize) ? `ZeroInstBufferAddr : (head + 1);
wire send_inst_to_id_flag = ((stall_i == `NoStop) && (ibuffer_empty == 1'b0) && (branch_flag == `NoBranch) && (FIFO_valid[new_head] == 1'b1));

always @(posedge clk) begin
    if (resetn == `RstEnable)                                           head <= `ZeroInstBufferAddr;
    else if (flush == `FlushEnable)                                     head <= `ZeroInstBufferAddr;
    else if (flush_for_exception)                                       head <= `ZeroInstBufferAddr;
    else if (branch_flag == `Branch)                                    head <= `ZeroInstBufferAddr;
    else if (flush_for_branch)                                          head <= `ZeroInstBufferAddr;
    else if (send_inst_to_id_flag)                                      head <= new_head;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                           tail <= `ZeroInstBufferAddr;
    else if (flush == `FlushEnable)                                     tail <= `ZeroInstBufferAddr;
    else if (flush_for_exception)                                       tail <= `ZeroInstBufferAddr;
    else if (branch_flag == `Branch)                                    tail <= `ZeroInstBufferAddr;
    else if (flush_for_branch)                                          tail <= `ZeroInstBufferAddr;
    else if (inst_data_ok == `DataOK)                                   tail <= new_tail;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                           FIFO_valid <= `InstBufferSizePlus1'd0;
    else if (flush == `FlushEnable)                                     FIFO_valid <= `InstBufferSizePlus1'd0;
    else if (flush_for_exception)                                       FIFO_valid <= `InstBufferSizePlus1'd0;
    else if (branch_flag == `Branch)                                    FIFO_valid <= `InstBufferSizePlus1'd0;
    else if (flush_for_branch)                                          FIFO_valid <= `InstBufferSizePlus1'd0;
    else if (inst_data_ok == `DataOK)                                   FIFO_valid[new_tail] <= `True_v;
    else if (send_inst_to_id_flag)                                      FIFO_valid[new_head] <= `False_v;
end

always @(posedge clk) begin
    if (inst_data_ok == `DataOK)                                        FIFO_addr[new_tail] <= req_addr;
end

always @(posedge clk) begin
    if (inst_data_ok == `DataOK)                                        FIFO_data[new_tail] <= inst_i;
end

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        inst_o <= `ZeroWord;
        pc_o <= `ZeroWord;
        do_inst_flag <= 1'b0;
    end else if (flush == `FlushEnable || flush_for_exception) begin
        inst_o <= `ZeroWord;
        pc_o <= `ZeroWord;
        do_inst_flag <= 1'b0;
    end else if (send_inst_to_id_flag) begin
        inst_o <= FIFO_data[new_head];
        pc_o <= FIFO_addr[new_head];
        do_inst_flag <= 1'b1;
    end else if ((do_inst_flag == 1'b1) && (stall_i == `Stop)) begin
        // last issue failed
        inst_o <= inst_o;
        pc_o <= pc_o;
        do_inst_flag <= do_inst_flag;
    end else begin
        inst_o <= `ZeroWord;
        pc_o <= `ZeroWord;
        do_inst_flag <= 1'b0;
    end
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                           req_addr <= `ZeroWord;
    else if (inst_req_success)                                          req_addr <= pc_i;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                           flush_for_exception <= `FlushDisable;
    else if (flush == `FlushEnable)                                     flush_for_exception <= `FlushEnable;
    else if (inst_req_success)                                          flush_for_exception <= `FlushDisable;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                           flush_for_branch <= `FlushDisable;
    else if (branch_flag)                                               flush_for_branch <= `FlushEnable;
    else if (inst_req_success)                                          flush_for_branch <= `FlushDisable;
end

endmodule