`include "defines.v"

module mem(
    input                                   resetn,

    input   [`InstAddrBus]                  pc_i,
    output  [`InstAddrBus]                  pc_o,

    input                                   wen_i,
    input   [`RegAddrBus]                   waddr_i,
    input   [`RegBus]                       wdata_i,
    input   [`AluOpBus]                     aluop_i,
    input   [`DataAddrBus]                  data_addr_i,
    input   [`DataBus]                      data_rdata_i,
    input                                   is_in_delayslot_i,
    input   [`RegBus]                       exception_type_i,

    output  reg                             wen_o,
    output  reg[`RegBus]                    wdata_o,
    output  [`RegAddrBus]                   waddr_o,

    // write hilo_reg
    input                                   hilo_wen_i,
    input   [`RegBus]                       hi_i,
    input   [`RegBus]                       lo_i,
    output                                  hilo_wen_o,
    output  [`RegBus]                       hi_o,
    output  [`RegBus]                       lo_o,

    // read or write cp0_reg
    input                                   cp0_reg_wen_i,
    input   [`RegBus]                       cp0_reg_wdata_i,
    input   [`RegAddrBus]                   cp0_reg_waddr_i,
    output                                  cp0_reg_wen_o,
    output  [`RegBus]                       cp0_reg_wdata_o,
    output  [`RegAddrBus]                   cp0_reg_waddr_o,
    input                                   commit_cp0_reg_wen,
    input   [`RegBus]                       commit_cp0_reg_wdata,
    input   [`RegAddrBus]                   commit_cp0_reg_waddr,
    input   [`RegBus]                       cp0_reg_status,
    input   [`RegBus]                       cp0_reg_epc,
    input   [`RegBus]                       cp0_reg_cause,
    input   [`RegBus]                       cp0_reg_ebase,
    output  reg[`RegBus]                    latest_cp0_reg_epc,
    output  reg[`RegBus]                    latest_cp0_reg_ebase,

    output                                  is_in_delayslot_o,
    output  reg[`RegBus]                    exception_type_o
);

reg [`RegBus] latest_cp0_reg_status;
reg [`RegBus] latest_cp0_reg_cause;

assign pc_o = pc_i;
assign waddr_o = waddr_i;
assign is_in_delayslot_o = is_in_delayslot_i;
assign hilo_wen_o = hilo_wen_i;
assign hi_o = hi_i;
assign lo_o = lo_i;
assign cp0_reg_wen_o = cp0_reg_wen_i;
assign cp0_reg_wdata_o = cp0_reg_wdata_i;
assign cp0_reg_waddr_o = cp0_reg_waddr_i;

always @(*) begin
    if (resetn == `RstEnable) begin
        wen_o = `ZeroWord;
        wdata_o = `ZeroWord;
    end else if (exception_type_i == `ZeroWord) begin
        wen_o = wen_i;
        wdata_o = wdata_i;
        case (aluop_i)
            `EXE_LW_OP: begin
                wdata_o = data_rdata_i;
            end
            `EXE_LB_OP: begin
                case (data_addr_i[1:0])
                    2'b00: begin
                        wdata_o = {{24{data_rdata_i[7]}}, data_rdata_i[7:0]};
                    end
                    2'b01: begin
                        wdata_o = {{24{data_rdata_i[15]}}, data_rdata_i[15:8]};
                    end
                    2'b10: begin
                        wdata_o = {{24{data_rdata_i[23]}}, data_rdata_i[23:16]};
                    end
                    2'b11: begin
                        wdata_o = {{24{data_rdata_i[31]}}, data_rdata_i[31:24]};
                    end
                    default: begin
                        wdata_o = `ZeroWord;
                    end
                endcase
            end
            `EXE_LBU_OP: begin
                case (data_addr_i[1:0])
                    2'b00: begin
                        wdata_o = {{24'd0}, data_rdata_i[7:0]};
                    end
                    2'b01: begin
                        wdata_o = {{24'd0}, data_rdata_i[15:8]};
                    end
                    2'b10: begin
                        wdata_o = {{24'd0}, data_rdata_i[23:16]};
                    end
                    2'b11: begin
                        wdata_o = {{24'd0}, data_rdata_i[31:24]};
                    end
                    default: begin
                        wdata_o = `ZeroWord;
                    end
                endcase
            end
            `EXE_LH_OP: begin
                case (data_addr_i[1:0])
                    2'b00: begin
                        wdata_o = {{16{data_rdata_i[15]}}, data_rdata_i[15:0]};
                    end
                    2'b10: begin
                        wdata_o = {{16{data_rdata_i[31]}}, data_rdata_i[31:16]};
                    end
                    default: begin
                        wdata_o = `ZeroWord;
                    end
                endcase
            end
            `EXE_LHU_OP: begin
                case (data_addr_i[1:0])
                    2'b00: begin
                        wdata_o = {{16'd0}, data_rdata_i[15:0]};
                    end
                    2'b10: begin
                        wdata_o = {{16'd0}, data_rdata_i[31:16]};
                    end
                    default: begin
                        wdata_o = `ZeroWord;
                    end
                endcase
            end
            default: begin
            end
        endcase
    end else begin
        wen_o = `WriteDisable;
        wdata_o = `ZeroWord;
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        exception_type_o = `ZeroWord;
    end else begin
        exception_type_o = `ZeroWord;
        if (pc_i != `ZeroWord) begin // the pipeline is not flushed or blocked
            if (exception_type_i[8] == 1'b1) begin
                // syscall
                exception_type_o = `EXECEPTION_SYS;
            end else if (exception_type_i[9] == 1'b1) begin
                // inst_valid
                exception_type_o = `EXECEPTION_INSTVALID;
            end else if (exception_type_i[10] == 1'b1) begin
                // ov
                exception_type_o = `EXECEPTION_OV;
            end else if (exception_type_i[11] == 1'b1) begin
                // break
                exception_type_o = `EXECEPTION_BREAK;
            end else if (exception_type_i[12] == 1'b1) begin
                // eret
                exception_type_o = `EXECEPTION_ERET;
            end else if (exception_type_i[13] == 1'b1) begin
                // ades
                exception_type_o = `EXECEPTION_ADES;
            end else if (exception_type_i[14] == 1'b1) begin
                // adel
                exception_type_o = `EXECEPTION_ADEL;
            end else if (((latest_cp0_reg_cause[15:8] & latest_cp0_reg_status[15:8]) != 8'd0) &&
                         ((latest_cp0_reg_status[1] == 1'b0) && (latest_cp0_reg_status[0] == 1'b1))) begin
                // interruption
                exception_type_o = `EXECEPTION_INT;
            end else begin
            end
        end else begin
        end
    end
end

///////////////////////////////////////////////////////////////////////////////
////////////////////////get the latest value of cp0_reg////////////////////////
//////////////////remember to add sel signal when adding PrId//////////////////
///////////////////////////////////////////////////////////////////////////////

always @(*) begin
    if (resetn == `RstEnable) begin
        latest_cp0_reg_status = `ZeroWord;
    end else if ((commit_cp0_reg_wen == `WriteEnable) && (commit_cp0_reg_waddr == `CP0_REG_STATUS)) begin
        latest_cp0_reg_status = commit_cp0_reg_wdata;
    end else begin
        latest_cp0_reg_status = cp0_reg_status;
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        latest_cp0_reg_epc = `ZeroWord;
    end else if ((commit_cp0_reg_wen == `WriteEnable) && (commit_cp0_reg_waddr == `CP0_REG_EPC)) begin
        latest_cp0_reg_epc = commit_cp0_reg_wdata;
    end else begin
        latest_cp0_reg_epc = cp0_reg_epc;
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        latest_cp0_reg_cause = `ZeroWord;
    end else if ((commit_cp0_reg_wen == `WriteEnable) && (commit_cp0_reg_waddr == `CP0_REG_CAUSE)) begin
        latest_cp0_reg_cause[9:8] = commit_cp0_reg_wdata[9:8];
        latest_cp0_reg_cause[22] = commit_cp0_reg_wdata[22];
        latest_cp0_reg_cause[23] = commit_cp0_reg_wdata[23];
    end else begin
        latest_cp0_reg_cause = cp0_reg_cause;
    end
end

always @(*) begin
    if (resetn == `RstEnable) begin
        latest_cp0_reg_ebase = `ZeroWord;
    end else if ((commit_cp0_reg_wen == `WriteEnable) && (commit_cp0_reg_waddr == `CP0_REG_EBASE)) begin
        latest_cp0_reg_ebase = commit_cp0_reg_wdata;
    end else begin
        latest_cp0_reg_ebase = cp0_reg_ebase;
    end
end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

endmodule