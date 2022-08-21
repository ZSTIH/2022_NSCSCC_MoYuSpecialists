`include "defines.v"

module cp0_reg(
    input                           clk,
    input                           resetn,

    input                           wen_i,
    input   [`RegAddrBus]           waddr_i,
    input   [`RegAddrBus]           raddr_i,
    input   [`RegBus]               data_i,
    output  reg[`RegBus]            data_o,

    input   [`RegBus]               exception_type_i,
    input   [5:0]                   int_i,
    input   [`RegBus]               current_inst_addr_i,
    input   [`RegBus]               mem_data_addr_i,
    input                           is_in_delayslot_i,

    output  reg[`RegBus]            badvaddr_o,
    output  reg[`RegBus]            count_o,
    output  reg[`RegBus]            compare_o,
    output  reg[`RegBus]            status_o,
    output  reg[`RegBus]            cause_o,
    output  reg[`RegBus]            epc_o,
    output  reg[`RegBus]            ebase_o,
    // output  reg[`RegBus]            config_o,
    // output  reg[`RegBus]            prid_o,

    output  reg                     timer_int_o
);

// generate a clock signal with a cycle twice as long as the previous one
reg clk_double;

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        clk_double <= 1'b0;
        badvaddr_o <= `ZeroWord;
        count_o <= `ZeroWord;
        compare_o <= `ZeroWord;
        status_o <= `CP0_REG_STATUS_RESET_VALUE;
        cause_o <= `ZeroWord;
        epc_o <= `ZeroWord;
        ebase_o <= `ExceptionInitialPC;
        timer_int_o <= `InterruptNotAssert;
    end else begin

        clk_double <= ~clk_double;
        if (clk_double) count_o <= count_o + 1;
        cause_o[15:10] <= int_i;
        cause_o[30] <= timer_int_o;

        if ((compare_o != `ZeroWord) && (count_o == compare_o)) timer_int_o <= `InterruptAssert;

////////////////////////////////// attention //////////////////////////////////
//////////////////remember to add sel signal when adding PrId//////////////////
///////////////////////////////////////////////////////////////////////////////

        if (wen_i == `WriteEnable) begin
            case (waddr_i)
                `CP0_REG_COUNT: begin
                    clk_double <= 1'b0;
                    count_o <= data_i;
                end
                `CP0_REG_COMPARE: begin
                    compare_o <= data_i;
                    timer_int_o <= `InterruptNotAssert;
                end
                `CP0_REG_STATUS: begin
                    status_o[15:8] <= data_i[15:8];
                    status_o[1:0] <= data_i[1:0];
                end
                `CP0_REG_CAUSE: begin
                    cause_o[9:8] <= data_i[9:8];
                end
                `CP0_REG_EPC: begin
                    epc_o <= data_i;
                end
                `CP0_REG_EBASE: begin
                    ebase_o <= data_i;
                end
                default: begin
                end
            endcase
        end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

        case (exception_type_i)
            `EXECEPTION_INT: begin
                // interruption
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd0;
            end
            `EXECEPTION_ADEL: begin
                // adel
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd4;
                if (current_inst_addr_i[1:0] != 2'b00) badvaddr_o <= current_inst_addr_i;
                else badvaddr_o <= mem_data_addr_i;
            end
            `EXECEPTION_ADES: begin
                // ades
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd5;
                badvaddr_o <= mem_data_addr_i;
            end
            `EXECEPTION_SYS: begin
                // syscall
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd8;
            end
            `EXECEPTION_BREAK: begin
                // break
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd9;
            end
            `EXECEPTION_INSTVALID: begin
                // inst_valid
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd10;
            end
            `EXECEPTION_OV: begin
                // ov
                if (status_o[1] == 1'b0) begin
                    if (is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1] <= 1'b1;
                cause_o[6:2] <= 5'd12;
            end
            `EXECEPTION_ERET: begin
                // eret
                status_o[1] <= 1'b0;
            end
            default: begin
            end
        endcase

    end
end

////////////////////////////////// attention //////////////////////////////////
//////////////////remember to add sel signal when adding PrId//////////////////
///////////////////////////////////////////////////////////////////////////////

always @(*) begin
    if (resetn == `RstEnable) begin
        data_o = `ZeroWord;
    end else begin
        case (raddr_i)
            `CP0_REG_BADVADDR: begin
                data_o = badvaddr_o;
            end
            `CP0_REG_COUNT: begin
                data_o = count_o;
            end
            `CP0_REG_COMPARE: begin
                data_o = compare_o;
            end
            `CP0_REG_STATUS: begin
                data_o = status_o;
            end
            `CP0_REG_CAUSE: begin
                data_o = cause_o;
            end
            `CP0_REG_EPC: begin
                data_o = epc_o;
            end
            `CP0_REG_EBASE: begin
                data_o = ebase_o;
            end
            default: begin
                data_o = `ZeroWord;
            end
        endcase
    end
end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

endmodule