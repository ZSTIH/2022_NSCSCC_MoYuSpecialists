`include "defines.v"

module div(
    input                               clk,
    input                               resetn,

    input                               signed_div_i,
    input   [`RegBus]                   operand1_i,
    input   [`RegBus]                   operand2_i,
    input                               start_i,
    input                               annul_i,

    output  reg[`DoubleRegBus]          result_o,
    output  reg                         ready_o
);

wire[32:0] div_temp;
reg[64:0] dividend;
reg[5:0] cnt;
reg[1:0] state;
reg[31:0] divisor;

assign div_temp = {1'b0, dividend[63:32]} - {1'b0, divisor};

always @(posedge clk) begin
    if (resetn == `RstEnable) begin
        state <= `DivFree;
        ready_o <= `DivResultNotReady;
        result_o <= {`ZeroWord, `ZeroWord};
    end else begin
        case (state)
            `DivFree: begin
                if ((start_i == `DivStart) && (annul_i == `FlushDisable)) begin
                    if (operand2_i == `ZeroWord) begin
                        state <= `DivByZero;
                    end else begin
                        state <= `DivOn;
                        cnt <= 6'b000000;
                        dividend[63:33] <= 31'b0;
                        dividend[0] <= 1'b0;
                        if ((signed_div_i == 1'b1) && (operand1_i[31] == 1'b1)) begin
                            dividend[32:1] <= ~operand1_i + 1;
                        end else begin
                            dividend[32:1] <= operand1_i;
                        end
                        if ((signed_div_i == 1'b1) && (operand2_i[31] == 1'b1)) begin
                            divisor <= ~operand2_i + 1;
                        end else begin
                            divisor <= operand2_i;
                        end
                    end
                end else begin
                    ready_o <= `DivResultNotReady;
                    result_o <= {`ZeroWord, `ZeroWord};
                end
            end
            `DivByZero: begin
                dividend <= {`ZeroWord, `ZeroWord};
                state <= `DivEnd;
            end
            `DivOn: begin
                if (annul_i == `FlushDisable) begin
                    if (cnt != 6'b100000) begin
                        if (div_temp[32] == 1'b1) begin
                            dividend <= {dividend[63:0], 1'b0};
                        end else begin
                            dividend <= {div_temp[31:0], dividend[31:0], 1'b1};
                        end
                        cnt <= cnt + 1;
                    end else begin
                        if ((signed_div_i == 1'b1) && ((operand1_i[31] ^ operand2_i[31]) == 1'b1)) begin
                            dividend[31:0] <= (~dividend[31:0] + 1);
                        end
                        if ((signed_div_i == 1'b1) && ((operand1_i[31] ^ dividend[64]) == 1'b1)) begin
                            dividend[64:33] <= (~dividend[64:33] + 1);
                        end
                        state <= `DivEnd;
                        cnt <= 6'b000000;
                    end
                end else begin
                    state <= `DivFree;
                end
            end
            `DivEnd: begin
                result_o <= {dividend[64:33], dividend[31:0]};
                ready_o <= `DivResultReady;
                if (start_i == `DivStop) begin
                    state <= `DivFree;
                    ready_o <= `DivResultNotReady;
                    result_o <= {`ZeroWord, `ZeroWord};
                end
            end
        endcase
    end
end

endmodule