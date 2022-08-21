`include "defines.v"

module mycpu(

    input                       clk,
    input                       resetn,
    input   [5:0]               ext_int,
    output                      timer_int_o,

    output                      inst_req,
    output                      inst_wr,
    output  [1:0]               inst_size,
    output  [`InstAddrBus]      inst_addr,
    output  [`InstBus]          inst_wdata,
    input   [`InstBus]          inst_rdata,
    input                       inst_addr_ok,
    input                       inst_data_ok,

    output                      data_req,
    output                      data_wr,
    output  [1:0]               data_size,
    output  [`DataAddrBus]      data_addr,
    output  [`DataBus]          data_wdata,
    input   [`DataBus]          data_rdata,
    input                       data_addr_ok,
    input                       data_data_ok,

    output  [`InstAddrBus]      debug_wb_pc,
    output  [3:0]               debug_wb_rf_wen,
    output  [`RegAddrBus]       debug_wb_rf_wnum,
    output  [`RegBus]           debug_wb_rf_wdata

);

///////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////wires/////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

assign inst_wr = 1'b0;
assign inst_wdata = 32'd0;
assign inst_size = 2'b10;
wire inst_req_success = ((inst_req == `RequestEnable) && (inst_addr_ok == `AddrOK));

// connect pc_reg and InstBuffer
wire ibuffer_full;
wire[`InstAddrBus] pc;

// connect InstBuffer and id
wire[`InstBus] id_inst_i;
wire[`InstAddrBus] id_pc_i;
wire do_inst_flag;

// connect id and id_ex
wire[`InstBus] id_inst_o;
wire[`InstAddrBus] id_pc_o;
wire id_is_in_delayslot_i;
wire id_is_in_delayslot_o;
wire id_next_inst_in_delayslot_o;
wire id_wen_o;
wire[`RegAddrBus] id_waddr_o;
wire[`AluOpBus] id_aluop_o;
wire[`AluSelBus] id_alusel_o;
wire[`RegBus] id_rdata1_o;
wire[`RegBus] id_rdata2_o;
wire[`RegBus] id_link_addr_o;
wire[`RegBus] id_exception_type_o;
wire id_branch_flag_o;
wire[`RegBus] id_branch_addr_o;

// connect id_ex and ex
wire[`InstAddrBus] ex_pc_i;
wire[`InstBus] ex_inst_i;
wire[`AluSelBus] ex_alusel_i;
wire[`AluOpBus] ex_aluop_i;
wire ex_wen_i;
wire[`RegAddrBus] ex_waddr_i;
wire[`RegBus] ex_rdata1_i;
wire[`RegBus] ex_rdata2_i;
wire[`RegBus] ex_link_addr_i;
wire[`RegBus] ex_exception_type_i;
wire ex_is_in_delayslot_i;
wire ex_branch_flag_i;
wire[`RegBus] ex_branch_addr_i;

// connect ex and ex_mem
wire[`InstAddrBus] ex_pc_o;
wire ex_wen_o;
wire[`RegAddrBus] ex_waddr_o;
wire[`RegBus] ex_wdata_o;
wire ex_is_in_delayslot_o;
wire[`RegBus] ex_exception_type_o;
wire[`AluOpBus] ex_aluop_o;
wire[`RegBus] ex_data_addr_o;
wire[`RegBus] ex_hi_o;
wire[`RegBus] ex_lo_o;
wire ex_hilo_wen_o;
wire ex_cp0_reg_wen_o;
wire[`RegBus] ex_cp0_reg_wdata_o;
wire[`RegAddrBus] ex_cp0_reg_waddr_o;

// connect ex_mem and mem
wire[`InstAddrBus] mem_pc_i;
wire mem_wen_i;
wire[`RegAddrBus] mem_waddr_i;
wire[`RegBus] mem_wdata_i;
wire[`AluOpBus] mem_aluop_i;
wire[`RegBus] mem_data_addr_i;
wire[`DataBus] mem_data_rdata_i;
wire[`RegBus] mem_exception_type_i;
wire mem_is_in_delayslot_i;
wire mem_hilo_wen_i;
wire[`RegBus] mem_hi_i;
wire[`RegBus] mem_lo_i;
wire mem_cp0_reg_wen_i;
wire[`RegBus] mem_cp0_reg_wdata_i;
wire[`RegAddrBus] mem_cp0_reg_waddr_i;

// connect mem and commit
wire[`InstAddrBus] mem_pc_o;
wire mem_wen_o;
wire[`RegAddrBus] mem_waddr_o;
wire[`RegBus] mem_wdata_o;
wire mem_hilo_wen_o;
wire[`RegBus] mem_hi_o;
wire[`RegBus] mem_lo_o;
wire mem_cp0_reg_wen_o;
wire[`RegBus] mem_cp0_reg_wdata_o;
wire[`RegAddrBus] mem_cp0_reg_waddr_o;

// input and output of ctrl
wire stall_req_from_ex;
wire stall_req_from_id;
wire[`RegBus] epc;
wire[`RegBus] latest_cp0_reg_epc;
wire[`RegBus] latest_cp0_reg_ebase;
wire flush;
wire [3:0] stall;

// input and output of regfile
wire rf_wen_i;
wire[`RegAddrBus] rf_waddr_i;
wire[`RegBus] rf_wdata_i;
wire rf_ren1_i;
wire[`RegAddrBus] rf_raddr1_i;
wire[`RegBus] rf_rdata1_o;
wire rf_ren2_i;
wire[`RegAddrBus] rf_raddr2_i;
wire[`RegBus] rf_rdata2_o;

// input and output of div
wire[`DoubleRegBus] div_result;
wire div_ready;
wire div_start;
wire signed_div;
wire[`RegBus] div_operand1;
wire[`RegBus] div_operand2;

// input and output of hilo_reg
wire[`RegBus] ex_hi_i;
wire[`RegBus] ex_lo_i;
wire commit_hilo_wen;
wire[`RegBus] commit_hi;
wire[`RegBus] commit_lo;

// input and output of cp0_reg
wire[`RegBus] ex_cp0_reg_rdata_i;
wire[`RegAddrBus] ex_cp0_reg_raddr_o;
wire commit_cp0_reg_wen_o;
wire[`RegBus] commit_cp0_reg_wdata_o;
wire[`RegAddrBus] commit_cp0_reg_waddr_o;
wire[`RegBus] mem_exception_type_o;
wire mem_is_in_delayslot_o;
wire[`RegBus] cp0_reg_badvaddr;
wire[`RegBus] cp0_reg_count;
wire[`RegBus] cp0_reg_compare;
wire[`RegBus] cp0_reg_status;
wire[`RegBus] cp0_reg_cause;
wire[`RegBus] cp0_reg_epc;
wire[`RegBus] cp0_reg_ebase;

// branch information
wire ex_branch_flag_o;
wire[`RegBus] ex_branch_addr_o;

// debug signals
wire[`InstAddrBus] commit_pc;
assign debug_wb_pc = commit_pc;
assign debug_wb_rf_wen = (rf_wen_i == 1) ? (4'hf) : (4'h0);
assign debug_wb_rf_wnum = rf_waddr_i;
assign debug_wb_rf_wdata = rf_wdata_i;

// virtual and actual addr transfer
assign inst_addr = ((pc[31:28] == 4'h8) ||
                    (pc[31:28] == 4'h9) ||
                    (pc[31:28] == 4'ha) ||
                    (pc[31:28] == 4'hb)) ?
                    (pc & 32'h1fffffff) : pc;
assign data_addr = ((ex_data_addr_o[31:28] == 4'h8) ||
                    (ex_data_addr_o[31:28] == 4'h9) ||
                    (ex_data_addr_o[31:28] == 4'ha) ||
                    (ex_data_addr_o[31:28] == 4'hb)) ?
                    (ex_data_addr_o & 32'h1fffffff) : ex_data_addr_o;

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
////////////////////////////////////modules////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

ctrl u_ctrl(
    .resetn(resetn),
    .stall_req_from_ex(stall_req_from_ex),
    .stall_req_from_id(stall_req_from_id),
    .exception_type_i(mem_exception_type_o),
    .latest_cp0_reg_epc(latest_cp0_reg_epc),
    .latest_cp0_reg_ebase(latest_cp0_reg_ebase),

    .epc(epc),
    .flush(flush),
    .stall(stall)
);

pc_reg u_pc_reg(
    .clk(clk),
    .resetn(resetn),
    .flush(flush),
    .epc(epc),
    .ibuffer_full(ibuffer_full),
    .inst_addr_ok(inst_addr_ok),
    .inst_req_success(inst_req_success),
    .branch_flag(ex_branch_flag_o),
    .branch_addr(ex_branch_addr_o),

    .inst_req(inst_req),
    .pc(pc)
);

InstBuffer u_InstBuffer(
    .clk(clk),
    .resetn(resetn),
    .flush(flush),
    .inst_i(inst_rdata),
    .pc_i(pc),
    .inst_data_ok(inst_data_ok),
    .inst_req_success(inst_req_success),
    .stall_i(stall[0]),
    .branch_flag(ex_branch_flag_o),

    .inst_o(id_inst_i),
    .pc_o(id_pc_i),
    .do_inst_flag(do_inst_flag),
    .ibuffer_full(ibuffer_full)
);

id u_id(
    .resetn(resetn),

    .inst_i(id_inst_i),
    .pc_i(id_pc_i),
    .do_inst_flag(do_inst_flag),
    .inst_o(id_inst_o),
    .pc_o(id_pc_o),

    .ren1(rf_ren1_i),
    .ren2(rf_ren2_i),
    .raddr1(rf_raddr1_i),
    .raddr2(rf_raddr2_i),
    .rdata1_i(rf_rdata1_o),
    .rdata2_i(rf_rdata2_o),

    .is_in_delayslot_i(id_is_in_delayslot_i),
    .is_in_delayslot_o(id_is_in_delayslot_o),
    .next_inst_in_delayslot_o(id_next_inst_in_delayslot_o),

    .wen(id_wen_o),
    .waddr(id_waddr_o),
    .aluop(id_aluop_o),
    .alusel(id_alusel_o),
    .rdata1_o(id_rdata1_o),
    .rdata2_o(id_rdata2_o),
    .link_addr_o(id_link_addr_o),
    .exception_type_o(id_exception_type_o),

    .ex_wen(ex_wen_o),
    .ex_waddr(ex_waddr_o),
    .ex_wdata(ex_wdata_o),
    .mem_wen(mem_wen_o),
    .mem_waddr(mem_waddr_o),
    .mem_wdata(mem_wdata_o),

    .ex_aluop(ex_aluop_o),
    .stall_req_from_id(stall_req_from_id),

    .branch_flag_o(id_branch_flag_o),
    .branch_addr_o(id_branch_addr_o)
);

id_ex u_id_ex(
    .clk(clk),
    .resetn(resetn),

    .do_inst_flag(do_inst_flag),

    .pc_i(id_pc_o),
    .inst_i(id_inst_o),
    .alusel_i(id_alusel_o),
    .aluop_i(id_aluop_o),
    .wen_i(id_wen_o),
    .waddr_i(id_waddr_o),
    .rdata1_i(id_rdata1_o),
    .rdata2_i(id_rdata2_o),
    .link_addr_i(id_link_addr_o),
    .exception_type_i(id_exception_type_o),
    .is_in_delayslot_i(id_is_in_delayslot_o),
    .next_inst_in_delayslot_i(id_next_inst_in_delayslot_o),
    
    .pc_o(ex_pc_i),
    .inst_o(ex_inst_i),
    .alusel_o(ex_alusel_i),
    .aluop_o(ex_aluop_i),
    .wen_o(ex_wen_i),
    .waddr_o(ex_waddr_i),
    .rdata1_o(ex_rdata1_i),
    .rdata2_o(ex_rdata2_i),
    .link_addr_o(ex_link_addr_i),
    .exception_type_o(ex_exception_type_i),
    .is_in_delayslot_o(ex_is_in_delayslot_i),
    .next_inst_in_delayslot_o(id_is_in_delayslot_i),

    .branch_flag_i(id_branch_flag_o),
    .branch_addr_i(id_branch_addr_o),
    .branch_flag_o(ex_branch_flag_i),
    .branch_addr_o(ex_branch_addr_i),

    .flush(flush),
    .stall_i(stall)
);

ex u_ex(
    .clk(clk),
    .resetn(resetn),

    .pc_i(ex_pc_i),
    .inst(ex_inst_i),
    .alusel_i(ex_alusel_i),
    .aluop_i(ex_aluop_i),
    .wen_i(ex_wen_i),
    .waddr_i(ex_waddr_i),
    .rdata1_i(ex_rdata1_i),
    .rdata2_i(ex_rdata2_i),
    .link_addr_i(ex_link_addr_i),
    .is_in_delayslot_i(ex_is_in_delayslot_i),
    .exception_type_i(ex_exception_type_i),

    .pc_o(ex_pc_o),
    .wen_o(ex_wen_o),
    .waddr_o(ex_waddr_o),
    .wdata(ex_wdata_o),
    .is_in_delayslot_o(ex_is_in_delayslot_o),
    .exception_type_o(ex_exception_type_o),

    .aluop_o(ex_aluop_o),
    .data_addr_o(ex_data_addr_o),
    .data_req_o(data_req),
    .data_wr_o(data_wr),
    .data_wdata_o(data_wdata),
    .data_size_o(data_size),
    .data_addr_ok_i(data_addr_ok),
    .data_data_ok_i(data_data_ok),

    .mem_hilo_wen(mem_hilo_wen_o),
    .mem_hi(mem_hi_o),
    .mem_lo(mem_lo_o),

    .commit_hilo_wen(commit_hilo_wen),
    .commit_hi(commit_hi),
    .commit_lo(commit_lo),

    .hi_i(ex_hi_i),
    .lo_i(ex_lo_i),

    .hi_o(ex_hi_o),
    .lo_o(ex_lo_o),
    .hilo_wen_o(ex_hilo_wen_o),

    .mem_cp0_reg_wen(mem_cp0_reg_wen_o),
    .mem_cp0_reg_wdata(mem_cp0_reg_wdata_o),
    .mem_cp0_reg_waddr(mem_cp0_reg_waddr_o),
    .commit_cp0_reg_wen(commit_cp0_reg_wen_o),
    .commit_cp0_reg_wdata(commit_cp0_reg_wdata_o),
    .commit_cp0_reg_waddr(commit_cp0_reg_waddr_o),
    .cp0_reg_rdata_i(ex_cp0_reg_rdata_i),
    .cp0_reg_raddr_o(ex_cp0_reg_raddr_o),
    .cp0_reg_wen_o(ex_cp0_reg_wen_o),
    .cp0_reg_wdata_o(ex_cp0_reg_wdata_o),
    .cp0_reg_waddr_o(ex_cp0_reg_waddr_o),

    .div_result_i(div_result),
    .div_ready_i(div_ready),
    .div_operand1_o(div_operand1),
    .div_operand2_o(div_operand2),
    .div_start_o(div_start),
    .signed_div_o(signed_div),

    .branch_flag_i(ex_branch_flag_i),
    .branch_addr_i(ex_branch_addr_i),
    .branch_flag_o(ex_branch_flag_o),
    .branch_addr_o(ex_branch_addr_o),

    .flush(flush),
    .stall_req_from_ex(stall_req_from_ex)
);

ex_mem u_ex_mem(
    .clk(clk),
    .resetn(resetn),

    .pc_i(ex_pc_o),
    .pc_o(mem_pc_i),

    .wen_i(ex_wen_o),
    .waddr_i(ex_waddr_o),
    .wdata_i(ex_wdata_o),
    .aluop_i(ex_aluop_o),
    .data_addr_i(ex_data_addr_o),

    .wen_o(mem_wen_i),
    .waddr_o(mem_waddr_i),
    .wdata_o(mem_wdata_i),
    .aluop_o(mem_aluop_i),
    .data_addr_o(mem_data_addr_i),

    .hilo_wen_i(ex_hilo_wen_o),
    .hi_i(ex_hi_o),
    .lo_i(ex_lo_o),
    .hilo_wen_o(mem_hilo_wen_i),
    .hi_o(mem_hi_i),
    .lo_o(mem_lo_i),

    .cp0_reg_wen_i(ex_cp0_reg_wen_o),
    .cp0_reg_wdata_i(ex_cp0_reg_wdata_o),
    .cp0_reg_waddr_i(ex_cp0_reg_waddr_o),
    .cp0_reg_wen_o(mem_cp0_reg_wen_i),
    .cp0_reg_wdata_o(mem_cp0_reg_wdata_i),
    .cp0_reg_waddr_o(mem_cp0_reg_waddr_i),

    .exception_type_i(ex_exception_type_o),
    .exception_type_o(mem_exception_type_i),

    .is_in_delayslot_i(ex_is_in_delayslot_o),
    .is_in_delayslot_o(mem_is_in_delayslot_i),

    .data_rdata_i(data_rdata),
    .data_rdata_o(mem_data_rdata_i),

    .flush(flush),
    .stall_i(stall)
);

mem u_mem(
    .resetn(resetn),

    .pc_i(mem_pc_i),
    .pc_o(mem_pc_o),

    .wen_i(mem_wen_i),
    .waddr_i(mem_waddr_i),
    .wdata_i(mem_wdata_i),
    .aluop_i(mem_aluop_i),
    .data_addr_i(mem_data_addr_i),
    .data_rdata_i(mem_data_rdata_i),
    .is_in_delayslot_i(mem_is_in_delayslot_i),
    .exception_type_i(mem_exception_type_i),

    .wen_o(mem_wen_o),
    .waddr_o(mem_waddr_o),
    .wdata_o(mem_wdata_o),

    .hilo_wen_i(mem_hilo_wen_i),
    .hi_i(mem_hi_i),
    .lo_i(mem_lo_i),
    .hilo_wen_o(mem_hilo_wen_o),
    .hi_o(mem_hi_o),
    .lo_o(mem_lo_o),

    .cp0_reg_wen_i(mem_cp0_reg_wen_i),
    .cp0_reg_wdata_i(mem_cp0_reg_wdata_i),
    .cp0_reg_waddr_i(mem_cp0_reg_waddr_i),
    .cp0_reg_wen_o(mem_cp0_reg_wen_o),
    .cp0_reg_wdata_o(mem_cp0_reg_wdata_o),
    .cp0_reg_waddr_o(mem_cp0_reg_waddr_o),
    .commit_cp0_reg_wen(commit_cp0_reg_wen_o),
    .commit_cp0_reg_wdata(commit_cp0_reg_wdata_o),
    .commit_cp0_reg_waddr(commit_cp0_reg_waddr_o),
    .cp0_reg_status(cp0_reg_status),
    .cp0_reg_epc(cp0_reg_epc),
    .cp0_reg_cause(cp0_reg_cause),
    .cp0_reg_ebase(cp0_reg_ebase),
    .latest_cp0_reg_epc(latest_cp0_reg_epc),
    .latest_cp0_reg_ebase(latest_cp0_reg_ebase),

    .is_in_delayslot_o(mem_is_in_delayslot_o),
    .exception_type_o(mem_exception_type_o)
);

commit u_commit(
    .clk(clk),
    .resetn(resetn),

    .pc_i(mem_pc_o),
    .wen_i(mem_wen_o),
    .waddr_i(mem_waddr_o),
    .wdata_i(mem_wdata_o),
    .hilo_wen_i(mem_hilo_wen_o),
    .hi_i(mem_hi_o),
    .lo_i(mem_lo_o),
    .cp0_reg_wen_i(mem_cp0_reg_wen_o),
    .cp0_reg_wdata_i(mem_cp0_reg_wdata_o),
    .cp0_reg_waddr_i(mem_cp0_reg_waddr_o),


    .pc_o(commit_pc),
    .wen_o(rf_wen_i),
    .waddr_o(rf_waddr_i),
    .wdata_o(rf_wdata_i),
    .hilo_wen_o(commit_hilo_wen),
    .hi_o(commit_hi),
    .lo_o(commit_lo),
    .cp0_reg_wen_o(commit_cp0_reg_wen_o),
    .cp0_reg_wdata_o(commit_cp0_reg_wdata_o),
    .cp0_reg_waddr_o(commit_cp0_reg_waddr_o),

    .flush(flush),
    .stall_i(stall[3])
);

regfile u_regfile(
    .clk(clk),
    .resetn(resetn),

    .wen(rf_wen_i),
    .waddr(rf_waddr_i),
    .wdata(rf_wdata_i),

    .ren1(rf_ren1_i),
    .raddr1(rf_raddr1_i),
    .rdata1(rf_rdata1_o),

    .ren2(rf_ren2_i),
    .raddr2(rf_raddr2_i),
    .rdata2(rf_rdata2_o)
);

div u_div(
    .clk(clk),
    .resetn(resetn),

    .signed_div_i(signed_div),
    .operand1_i(div_operand1),
    .operand2_i(div_operand2),
    .start_i(div_start),
    .annul_i(flush),

    .result_o(div_result),
    .ready_o(div_ready)
);

hilo_reg u_hilo_reg(
    .clk(clk),
    .resetn(resetn),

    .wen(commit_hilo_wen),
    .hi_i(commit_hi),
    .lo_i(commit_lo),

    .hi_o(ex_hi_i),
    .lo_o(ex_lo_i)
);

cp0_reg u_cp0_reg(
    .clk(clk),
    .resetn(resetn),

    .wen_i(commit_cp0_reg_wen_o),
    .waddr_i(commit_cp0_reg_waddr_o),
    .raddr_i(ex_cp0_reg_raddr_o),
    .data_i(commit_cp0_reg_wdata_o),
    .data_o(ex_cp0_reg_rdata_i),

    .exception_type_i(mem_exception_type_o),
    .int_i(ext_int),
    .current_inst_addr_i(mem_pc_o),
    .mem_data_addr_i(mem_data_addr_i),
    .is_in_delayslot_i(mem_is_in_delayslot_o),

    .badvaddr_o(cp0_reg_badvaddr),
    .count_o(cp0_reg_count),
    .compare_o(cp0_reg_compare),
    .status_o(cp0_reg_status),
    .cause_o(cp0_reg_cause),
    .epc_o(cp0_reg_epc),
    .ebase_o(cp0_reg_ebase),

    .timer_int_o(timer_int_o)
);

endmodule