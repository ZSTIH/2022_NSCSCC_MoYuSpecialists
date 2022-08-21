`include "defines.v"

module ctrl(
    input                           resetn,
    input                           stall_req_from_ex,
    input                           stall_req_from_id,
    input   [`RegBus]               exception_type_i,
    input   [`RegBus]               latest_cp0_reg_epc,
    input   [`RegBus]               latest_cp0_reg_ebase,

    output  reg[`RegBus]            epc,
    output  reg                     flush,
    output  reg[3:0]                stall
);

// stall[0]: InstBuffer
// stall[1]: id_ex
// stall[2]: ex_mem
// stall[3]: commit
always @(*) begin
    if (resetn == `RstEnable) begin
        stall = 4'b0000;
        flush = `FlushDisable;
        epc = `ZeroWord;
    end else if (exception_type_i != `ZeroWord) begin
        stall = 4'b0000;
        flush = `FlushEnable;
        case (exception_type_i)
            `EXECEPTION_INT, `EXECEPTION_ADEL, `EXECEPTION_ADES, `EXECEPTION_SYS,
            `EXECEPTION_BREAK, `EXECEPTION_INSTVALID, `EXECEPTION_OV: epc = latest_cp0_reg_ebase;
            `EXECEPTION_ERET: epc = latest_cp0_reg_epc;
            default: epc = `ZeroWord;
        endcase
    end else if (stall_req_from_ex == `Stop) begin
        stall = 4'b0111;
        flush = `FlushDisable;
        epc = `ZeroWord;
    end else if (stall_req_from_id == `Stop) begin
        stall = 4'b0011;
        flush = `FlushDisable;
        epc = `ZeroWord;
    end else begin
        stall = 4'b0000;
        flush = `FlushDisable;
        epc = `ZeroWord;
    end
end

endmodule