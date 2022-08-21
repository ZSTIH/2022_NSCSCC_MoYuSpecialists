`include "defines.v"

module hilo_reg(
    input                               clk,
    input                               resetn,

    input                               wen,
    input   [`RegBus]                   hi_i,
    input   [`RegBus]                   lo_i,

    output  reg[`RegBus]                hi_o,
    output  reg[`RegBus]                lo_o
);

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
    end else if (wen == `WriteEnable) begin
        hi_o <= hi_i;
        lo_o <= lo_i;
    end
end

endmodule