`include "defines.v"

module ex(
    input                               clk,
    input                               resetn,

    input   [`InstAddrBus]              pc_i,
    input   [`InstBus]                  inst,
    input   [`AluSelBus]                alusel_i,
    input   [`AluOpBus]                 aluop_i,
    input                               wen_i,
    input   [`RegAddrBus]               waddr_i,
    input   [`RegBus]                   rdata1_i,
    input   [`RegBus]                   rdata2_i,
    input   [`RegBus]                   link_addr_i,
    input                               is_in_delayslot_i,
    input   [`RegBus]                   exception_type_i,

    output  [`InstAddrBus]              pc_o,
    output  reg                         wen_o,
    output  [`RegAddrBus]               waddr_o,
    output  reg[`RegBus]                wdata,
    output                              is_in_delayslot_o,
    output  [`RegBus]                   exception_type_o,

    // handle load or store
    output  [`AluOpBus]                 aluop_o,
    output  [`DataAddrBus]              data_addr_o,
    output  reg                         data_req_o,
    output  reg                         data_wr_o,
    output  reg[`DataBus]               data_wdata_o,
    output  reg[1:0]                    data_size_o,
    input                               data_addr_ok_i,
    input                               data_data_ok_i,

    // from mem: handle hilo correlation
    input                               mem_hilo_wen,
    input   [`RegBus]                   mem_hi,
    input   [`RegBus]                   mem_lo,

    // from commit: handle hilo correlation
    input                               commit_hilo_wen,
    input   [`RegBus]                   commit_hi,
    input   [`RegBus]                   commit_lo,

    // from hilo_reg
    input   [`RegBus]                   hi_i,
    input   [`RegBus]                   lo_i,

    // to hilo_reg
    output  reg[`RegBus]                hi_o,
    output  reg[`RegBus]                lo_o,
    output  reg                         hilo_wen_o,

    // read or write cp0_reg
    input                               mem_cp0_reg_wen,
    input   [`RegBus]                   mem_cp0_reg_wdata,
    input   [`RegAddrBus]               mem_cp0_reg_waddr,
    input                               commit_cp0_reg_wen,
    input   [`RegBus]                   commit_cp0_reg_wdata,
    input   [`RegAddrBus]               commit_cp0_reg_waddr,
    input   [`RegBus]                   cp0_reg_rdata_i,
    output  reg[`RegAddrBus]            cp0_reg_raddr_o,
    output  reg                         cp0_reg_wen_o,
    output  reg[`RegBus]                cp0_reg_wdata_o,
    output  reg[`RegAddrBus]            cp0_reg_waddr_o,

    // communicate with div
    input   [`DoubleRegBus]             div_result_i,
    input                               div_ready_i,
    output  reg[`RegBus]                div_operand1_o,
    output  reg[`RegBus]                div_operand2_o,
    output  reg                         div_start_o,
    output  reg                         signed_div_o,

    input                               branch_flag_i,
    input   [`InstAddrBus]              branch_addr_i,
    output                              branch_flag_o,
    output  [`InstAddrBus]              branch_addr_o,

    input                               flush,
    output                              stall_req_from_ex
);

///////////////////////////////////////////////////////////////////////////////
/////////////////////////definition of regs and wires//////////////////////////
///////////////////////////////////////////////////////////////////////////////

reg exception_type_is_adel;
reg exception_type_is_ades;
reg ov_assert;
reg stall_req_for_div;
reg stall_req_for_load_or_store;
reg handle_load_or_store_flag;
reg[`RegBus] arithmetic_res;
reg[`RegBus] logic_res;
reg[`RegBus] shift_res;
reg[`RegBus] move_res;
reg[`DoubleRegBus] mult_res;
reg[`RegBus] HI;
reg[`RegBus] LO;
wire[`RegBus] mult_operand1;
wire[`RegBus] mult_operand2;
wire[`DoubleRegBus] hilo_temp;
wire[`RegBus] rdata2_mux;
wire[`RegBus] result_sum;
wire ov_sum;
wire rdata1_lt_rdata2;
wire ready_to_start_load_or_store;

wire[`RegBus] match_position;
wire[7:0] match_string;

assign pc_o = pc_i;
assign waddr_o = waddr_i;
assign aluop_o = aluop_i;
assign is_in_delayslot_o = is_in_delayslot_i;
assign branch_flag_o = branch_flag_i;
assign branch_addr_o = branch_addr_i;
assign data_addr_o = rdata1_i + {{16{inst[15]}}, inst[15:0]};
assign exception_type_o = {exception_type_i[31:15],
                           exception_type_is_adel,
                           exception_type_is_ades,
                           exception_type_i[12:11],
                           ov_assert,
                           exception_type_i[9:8], 8'd0};
assign mult_operand1 = (((aluop_i == `EXE_MULT_OP)) &&
                        (rdata1_i[31] == 1'b1)) ? (~rdata1_i + 1) : rdata1_i;
assign mult_operand2 = (((aluop_i == `EXE_MULT_OP)) &&
                        (rdata2_i[31] == 1'b1)) ? (~rdata2_i + 1) : rdata2_i;
assign hilo_temp = mult_operand1 * mult_operand2;
assign rdata2_mux = ((aluop_i == `EXE_SUBU_OP) ||
                     (aluop_i == `EXE_SUB_OP) ||
                     (aluop_i == `EXE_SLT_OP)) ? ((~rdata2_i) + 1) : rdata2_i;
assign result_sum = rdata1_i + rdata2_mux;
assign ov_sum = ((!rdata1_i[31] && !rdata2_mux[31]) && result_sum[31]) ||
                ((rdata1_i[31] && rdata2_mux[31]) && !result_sum[31]);
assign rdata1_lt_rdata2 = ((aluop_i == `EXE_SLT_OP)) ? 
                          ((rdata1_i[31] && !rdata2_i[31]) ||
                           (!rdata1_i[31] && !rdata2_i[31] && result_sum[31]) ||
                           (rdata1_i[31] && rdata2_i[31] && result_sum[31])) :
                           (rdata1_i < rdata2_i);
assign stall_req_from_ex = (stall_req_for_div || stall_req_for_load_or_store);
assign ready_to_start_load_or_store = (alusel_i == `EXE_RES_LOAD_STORE) &&
                                      (exception_type_o == `ZeroWord) &&
                                      (handle_load_or_store_flag == `False_v);
assign match_string = rdata1_i[7:0];
assign match_position = (rdata2_i[7:0] == match_string) ? 32'd0 :
                        (rdata2_i[8:1] == match_string) ? 32'd1 :
                        (rdata2_i[9:2] == match_string) ? 32'd2 :
                        (rdata2_i[10:3] == match_string) ? 32'd3 :
                        (rdata2_i[11:4] == match_string) ? 32'd4 :
                        (rdata2_i[12:5] == match_string) ? 32'd5 :
                        (rdata2_i[13:6] == match_string) ? 32'd6 :
                        (rdata2_i[14:7] == match_string) ? 32'd7 :
                        (rdata2_i[15:8] == match_string) ? 32'd8 :
                        (rdata2_i[16:9] == match_string) ? 32'd9 :
                        (rdata2_i[17:10] == match_string) ? 32'd10 :
                        (rdata2_i[18:11] == match_string) ? 32'd11 :
                        (rdata2_i[19:12] == match_string) ? 32'd12 :
                        (rdata2_i[20:13] == match_string) ? 32'd13 :
                        (rdata2_i[21:14] == match_string) ? 32'd14 :
                        (rdata2_i[22:15] == match_string) ? 32'd15 :
                        (rdata2_i[23:16] == match_string) ? 32'd16 :
                        (rdata2_i[24:17] == match_string) ? 32'd17 :
                        (rdata2_i[25:18] == match_string) ? 32'd18 :
                        (rdata2_i[26:19] == match_string) ? 32'd19 :
                        (rdata2_i[27:20] == match_string) ? 32'd20 :
                        (rdata2_i[28:21] == match_string) ? 32'd21 :
                        (rdata2_i[29:22] == match_string) ? 32'd22 :
                        (rdata2_i[30:23] == match_string) ? 32'd23 :
                        (rdata2_i[31:24] == match_string) ? 32'd24 :
                        32'hffffffff;

///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////handle hilo_reg and cp0_reg/////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////

// the newest value of hilo_reg
always @(*) begin
    if (resetn == `RstEnable) begin
        {HI, LO} = {`ZeroWord, `ZeroWord};
    end else if (mem_hilo_wen == `WriteEnable) begin
        {HI, LO} = {mem_hi, mem_lo};
    end else if (commit_hilo_wen == `WriteEnable) begin
        {HI, LO} = {commit_hi, commit_lo};
    end else begin
        {HI, LO} = {hi_i, lo_i};
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        hilo_wen_o = `WriteDisable;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
    end else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
        hilo_wen_o = `WriteEnable;
        hi_o = mult_res[63:32];
        lo_o = mult_res[31:0];
    end else if ((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP)) begin
        hilo_wen_o = `WriteEnable;
        hi_o = div_result_i[63:32];
        lo_o = div_result_i[31:0];
    end else if (aluop_i == `EXE_MTHI_OP) begin
        hilo_wen_o = `WriteEnable;
        hi_o = rdata1_i;
        lo_o = LO;
    end else if (aluop_i == `EXE_MTLO_OP) begin
        hilo_wen_o = `WriteEnable;
        hi_o = HI;
        lo_o = rdata1_i;
    end else begin
        hilo_wen_o = `WriteDisable;
        hi_o = `ZeroWord;
        lo_o = `ZeroWord;
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        cp0_reg_wen_o = `WriteDisable;
        cp0_reg_waddr_o = `ZeroRegAddr;
        cp0_reg_wdata_o = `ZeroWord;
    end else if (aluop_i == `EXE_MTC0_OP) begin
        cp0_reg_wen_o = `WriteEnable;
        cp0_reg_waddr_o = inst[15:11];
        cp0_reg_wdata_o = rdata1_i;
    end else begin
        cp0_reg_wen_o = `WriteDisable;
        cp0_reg_waddr_o = `ZeroRegAddr;
        cp0_reg_wdata_o = `ZeroWord;
    end
end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

always @(*) begin
    if (resetn == `RstEnable) begin
        arithmetic_res = `ZeroWord;
    end else begin
        case (aluop_i)
            `EXE_SLT_OP, `EXE_SLTU_OP: begin
                arithmetic_res = rdata1_lt_rdata2;
            end
            `EXE_ADD_OP, `EXE_ADDIU_OP, `EXE_ADDI_OP, `EXE_ADDU_OP: begin
                arithmetic_res = result_sum;
            end
            `EXE_SUB_OP, `EXE_SUBU_OP: begin
                arithmetic_res = result_sum;
            end
            `EXE_MATCH_OP: begin
                arithmetic_res = match_position;
            end
            default: begin
                arithmetic_res = `ZeroWord;
            end
        endcase
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        logic_res = `ZeroWord;
    end else begin
        case (aluop_i)
            `EXE_OR_OP: begin
                logic_res = rdata1_i | rdata2_i;
            end
            `EXE_AND_OP: begin
                logic_res = rdata1_i & rdata2_i;
            end
            `EXE_NOR_OP: begin
                logic_res = ~(rdata1_i | rdata2_i);
            end
            `EXE_XOR_OP: begin
                logic_res = rdata1_i ^ rdata2_i;
            end
            default: begin
                logic_res = `ZeroWord;
            end
        endcase
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        shift_res = `ZeroWord;
    end else begin
        case (aluop_i)
            `EXE_SLL_OP: begin
                shift_res = rdata2_i << rdata1_i[4:0];
            end
            `EXE_SRL_OP: begin
                shift_res = rdata2_i >> rdata1_i[4:0];
            end
            `EXE_SRA_OP: begin
                shift_res = ({32{rdata2_i[31]}} << (6'd32 - {1'b0, rdata1_i[4:0]})) |
                            (rdata2_i >> rdata1_i[4:0]);
            end
            default: begin
                shift_res = `ZeroWord;
            end
        endcase
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        move_res = `ZeroWord;
    end else begin
        move_res = `ZeroWord;
        case (aluop_i)
            `EXE_MFHI_OP: begin
                move_res = HI;
            end
            `EXE_MFLO_OP: begin
                move_res = LO;
            end
            `EXE_MFC0_OP: begin
                cp0_reg_raddr_o = inst[15:11];
                move_res = cp0_reg_rdata_i;
                if ((mem_cp0_reg_wen == `WriteEnable) && (mem_cp0_reg_waddr == inst[15:11])) begin
                    move_res = mem_cp0_reg_wdata;
                end else if ((commit_cp0_reg_wen == `WriteEnable) && (commit_cp0_reg_waddr == inst[15:11])) begin
                    move_res = commit_cp0_reg_wdata;
                end else begin
                end
            end
            default: begin
            end
        endcase
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        mult_res = {`ZeroWord, `ZeroWord};
    end else if ((aluop_i == `EXE_MULT_OP)) begin
        if ((rdata1_i[31] ^ rdata2_i[31]) == 1'b1) begin
            mult_res = ~hilo_temp + 1;
        end else begin
            mult_res = hilo_temp;
        end
    end else begin
        mult_res = hilo_temp;
    end
end

always @(*) begin

    if (((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
        wen_o = `WriteDisable;
        ov_assert = 1'b1;
    end else begin
        wen_o = wen_i;
        ov_assert = 1'b0;
    end

    case (alusel_i)
        `EXE_RES_ARITHMETIC: begin
            wdata = arithmetic_res;
        end
        `EXE_RES_LOGIC: begin
            wdata = logic_res;
        end
        `EXE_RES_JUMP_BRANCH: begin
            wdata = link_addr_i;
        end
        `EXE_RES_SHIFT: begin
            wdata = shift_res;
        end
        `EXE_RES_MOVE: begin
            wdata = move_res;
        end
        `EXE_RES_MUL: begin
            wdata = mult_res[31:0];
        end
        default: begin
            wdata = `ZeroWord;
        end
    endcase

end

always @(*) begin
    if (resetn == `RstEnable) begin
        stall_req_for_div = `NoStop;
        div_operand1_o = `ZeroWord;
        div_operand2_o = `ZeroWord;
        div_start_o = `DivStop;
        signed_div_o = 1'b0;
    end else begin
        stall_req_for_div = `NoStop;
        div_operand1_o = `ZeroWord;
        div_operand2_o = `ZeroWord;
        div_start_o = `DivStop;
        signed_div_o = 1'b0;
        case (aluop_i)
            `EXE_DIV_OP: begin
                if (div_ready_i == `DivResultNotReady) begin
                    stall_req_for_div = `Stop;
                    div_operand1_o = rdata1_i;
                    div_operand2_o = rdata2_i;
                    div_start_o = `DivStart;
                    signed_div_o = 1'b1;
                end else if (div_ready_i == `DivResultReady) begin
                    stall_req_for_div = `NoStop;
                    div_operand1_o = rdata1_i;
                    div_operand2_o = rdata2_i;
                    div_start_o = `DivStop;
                    signed_div_o = 1'b1;
                end else begin
                    stall_req_for_div = `NoStop;
                    div_operand1_o = `ZeroWord;
                    div_operand2_o = `ZeroWord;
                    div_start_o = `DivStop;
                    signed_div_o = 1'b0;
                end
            end
            `EXE_DIVU_OP: begin
                if (div_ready_i == `DivResultNotReady) begin
                    stall_req_for_div = `Stop;
                    div_operand1_o = rdata1_i;
                    div_operand2_o = rdata2_i;
                    div_start_o = `DivStart;
                    signed_div_o = 1'b0;
                end else if (div_ready_i == `DivResultReady) begin
                    stall_req_for_div = `NoStop;
                    div_operand1_o = rdata1_i;
                    div_operand2_o = rdata2_i;
                    div_start_o = `DivStop;
                    signed_div_o = 1'b0;
                end else begin
                    stall_req_for_div = `NoStop;
                    div_operand1_o = `ZeroWord;
                    div_operand2_o = `ZeroWord;
                    div_start_o = `DivStop;
                    signed_div_o = 1'b0;
                end
            end
            default: begin
            end
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
/////////////////////////////handle load or store//////////////////////////////
///////////////////////////////////////////////////////////////////////////////

always @(*) begin
    if (resetn == `RstEnable) begin
        data_wr_o = 1'b0;
        data_wdata_o = `ZeroWord;
        data_size_o = 2'b10;
    end else begin
        data_wr_o = 1'b0;
        data_wdata_o = `ZeroWord;
        data_size_o = 2'b10;
        case (aluop_i)
            `EXE_SW_OP: begin
                data_wr_o = 1'b1;
                data_wdata_o = rdata2_i;
            end
            `EXE_SB_OP: begin
                data_wr_o = 1'b1;
                data_wdata_o = {rdata2_i[7:0], rdata2_i[7:0], rdata2_i[7:0], rdata2_i[7:0]};
                data_size_o = 2'b00;
            end
            `EXE_SH_OP: begin
                data_wr_o = 1'b1;
                data_wdata_o = {rdata2_i[15:0], rdata2_i[15:0]};
                data_size_o = 2'b01;
            end
            `EXE_LW_OP: begin
                data_wr_o = 1'b0;
            end
            `EXE_LB_OP: begin
                data_wr_o = 1'b0;
                data_size_o = 2'b00;
            end
            `EXE_LBU_OP: begin
                data_wr_o = 1'b0;
                data_size_o = 2'b00;
            end
            `EXE_LH_OP: begin
                data_wr_o = 1'b0;
                data_size_o = 2'b01;
            end
            `EXE_LHU_OP: begin
                data_wr_o = 1'b0;
                data_size_o = 2'b01;
            end
            default: begin
            end
        endcase
    end
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                               handle_load_or_store_flag <= `False_v;
    else if (ready_to_start_load_or_store)                                  handle_load_or_store_flag <= `True_v;
    else if (data_data_ok_i)                                                handle_load_or_store_flag <= `False_v;
end

always @(posedge clk) begin
    if (resetn == `RstEnable)                                               data_req_o <= `RequestDisable;
    else if (data_req_o == `RequestEnable)                                  data_req_o <= `RequestDisable;
    else if (handle_load_or_store_flag && data_addr_ok_i)                   data_req_o <= `RequestEnable;
    else                                                                    data_req_o <= `RequestDisable;
end

always @(*) begin
    if (resetn == `RstEnable)                                               stall_req_for_load_or_store = `NoStop;
    else if (ready_to_start_load_or_store)                                  stall_req_for_load_or_store = `Stop;
    else if (handle_load_or_store_flag && (~data_data_ok_i))                stall_req_for_load_or_store = `Stop;
    else                                                                    stall_req_for_load_or_store = `NoStop;
end

always @(*) begin
    if (resetn == `RstEnable) begin
        exception_type_is_ades = `False_v;
    end else begin
        case (aluop_i)
            `EXE_SW_OP: begin
                if (data_addr_o[1:0] != 2'b00) begin
                    exception_type_is_ades = `True_v;
                end else begin
                    exception_type_is_ades = `False_v;
                end
            end
            `EXE_SH_OP: begin
                if (data_addr_o[0] != 1'b0) begin
                    exception_type_is_ades = `True_v;
                end else begin
                    exception_type_is_ades = `False_v;
                end
            end
            default: begin
                exception_type_is_ades = `False_v;
            end
        endcase
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        exception_type_is_adel = `False_v;
    end else if (exception_type_i[14] == `True_v) begin
        exception_type_is_adel = `True_v;
    end else begin
        case (aluop_i)
            `EXE_LW_OP: begin
                if (data_addr_o[1:0] != 2'b00) begin
                    exception_type_is_adel = `True_v;
                end else begin
                    exception_type_is_adel = `False_v;
                end
            end
            `EXE_LH_OP, `EXE_LHU_OP: begin
                if (data_addr_o[0] != 1'b0) begin
                    exception_type_is_adel = `True_v;
                end else begin
                    exception_type_is_adel = `False_v;
                end
            end
            default: begin
                exception_type_is_adel = `False_v;
            end
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

endmodule