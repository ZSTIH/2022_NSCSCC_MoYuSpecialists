`include "defines.v"

module id(
    input                           resetn,

    input   [`InstBus]              inst_i,
    input   [`InstAddrBus]          pc_i,
    input                           do_inst_flag,
    output  [`InstBus]              inst_o,
    output  [`InstAddrBus]          pc_o,

    // communicate with regfile
	output  reg                    	ren1,
	output  reg                    	ren2,     
	output  reg[`RegAddrBus]       	raddr1,
	output  reg[`RegAddrBus]       	raddr2,
    input   [`RegBus]               rdata1_i,
    input   [`RegBus]               rdata2_i,

    // delayslot
    input                           is_in_delayslot_i,
    output  reg                     is_in_delayslot_o,
    output  reg                     next_inst_in_delayslot_o,

    // to ex
    output  reg                     wen,
    output  reg[`RegAddrBus]        waddr,
	output  reg[`AluOpBus]         	aluop,
	output  reg[`AluSelBus]        	alusel,
    output  reg[`RegBus]            rdata1_o,
    output  reg[`RegBus]            rdata2_o,
    output  reg[`RegBus]            link_addr_o,
    output  [`RegBus]               exception_type_o,

    // handle read-after-write correlation
    input                           ex_wen,
    input   [`RegAddrBus]           ex_waddr,
    input   [`RegBus]               ex_wdata,
    input                           mem_wen,
    input   [`RegAddrBus]           mem_waddr,
    input   [`RegBus]               mem_wdata,

    // handle load-use correlation
    input   [`AluOpBus]             ex_aluop,
    output                          stall_req_from_id,

    // branch information
    output                          branch_flag_o,
    output  reg[`RegBus]            branch_addr_o

);

assign inst_o = inst_i;
assign pc_o = pc_i;

wire[5:0] op = inst_i[31:26];
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0];
wire[4:0] op4 = inst_i[20:16];
reg[`RegBus] imm;
reg branch_flag;

wire[`InstAddrBus] pc_plus_4 = pc_i + 4;
wire[`InstAddrBus] pc_plus_8 = pc_i + 8;
wire[`RegBus] imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
wire stall_req_for_rdata1_load_correlation;
wire stall_req_for_rdata2_load_correlation;
wire pre_inst_is_load = ((ex_aluop == `EXE_LW_OP) ||
                         (ex_aluop == `EXE_LB_OP) ||
                         (ex_aluop == `EXE_LBU_OP) ||
                         (ex_aluop == `EXE_LH_OP) ||
                         (ex_aluop == `EXE_LHU_OP)) ? 1'b1 : 1'b0;
wire inst_input_valid = (inst_i !== 32'hXXXXXXXX);

reg exception_type_is_adel;
reg exception_type_is_eret;
reg exception_type_is_break;
reg inst_valid;
reg exception_type_is_syscall;
// exception_type_o[14]: adel
// exception_type_o[13]: ades
// exception_type_o[12]: eret
// exception_type_o[11]: break
// exception_type_o[10]: ov
// exception_type_o[9]: inst_valid
// exception_type_o[8]: syscall
// exception_type_o[7~0]: external interruption
assign exception_type_o = {17'b0, exception_type_is_adel, 1'b0, exception_type_is_eret,
                           exception_type_is_break, 1'b0, (inst_valid && inst_input_valid), exception_type_is_syscall, 8'b0};
assign stall_req_from_id = stall_req_for_rdata1_load_correlation || stall_req_for_rdata2_load_correlation;
assign stall_req_for_rdata1_load_correlation = (pre_inst_is_load == 1'b1) && (ex_waddr == raddr1) && (ren1 == `ReadEnable);
assign stall_req_for_rdata2_load_correlation = (pre_inst_is_load == 1'b1) && (ex_waddr == raddr2) && (ren2 == `ReadEnable);
assign branch_flag_o = branch_flag && (~stall_req_from_id);

always @(*) begin
    if (resetn == `RstEnable) begin
        ren1 = `ReadDisable;
        ren2 = `ReadDisable;
        raddr1 = `ZeroRegAddr;
        raddr2 = `ZeroRegAddr;
        aluop = `EXE_NOP_OP;
        alusel = `EXE_RES_NOP;
        wen = `WriteDisable;
        waddr = `ZeroRegAddr;
        imm = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_flag = `NoBranch;
        branch_addr_o = `ZeroWord;
        exception_type_is_adel = `False_v;
        exception_type_is_eret = `False_v;
        exception_type_is_break = `False_v;
        inst_valid = `InstValid;
        exception_type_is_syscall = `False_v;
        next_inst_in_delayslot_o = `NotInDelaySlot;
    end else if (pc_i[1:0] != 2'b00) begin
        ren1 = `ReadDisable;
        ren2 = `ReadDisable;
        raddr1 = `ZeroRegAddr;
        raddr2 = `ZeroRegAddr;
        aluop = `EXE_NOP_OP;
        alusel = `EXE_RES_NOP;
        wen = `WriteDisable;
        waddr = `ZeroRegAddr;
        imm = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_flag = `NoBranch;
        branch_addr_o = `ZeroWord;
        exception_type_is_adel = `True_v;
        exception_type_is_eret = `False_v;
        exception_type_is_break = `False_v;
        inst_valid = `InstValid;
        exception_type_is_syscall = `False_v;
        next_inst_in_delayslot_o = `NotInDelaySlot;
    end else if (do_inst_flag == `False_v) begin
        ren1 = `ReadDisable;
        ren2 = `ReadDisable;
        raddr1 = `ZeroRegAddr;
        raddr2 = `ZeroRegAddr;
        aluop = `EXE_NOP_OP;
        alusel = `EXE_RES_NOP;
        wen = `WriteDisable;
        waddr = `ZeroRegAddr;
        imm = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_flag = `NoBranch;
        branch_addr_o = `ZeroWord;
        exception_type_is_adel = `False_v;
        exception_type_is_eret = `False_v;
        exception_type_is_break = `False_v;
        inst_valid = `InstValid;
        exception_type_is_syscall = `False_v;
        next_inst_in_delayslot_o = `NotInDelaySlot;
    end else begin
        ren1 = `ReadDisable;
        ren2 = `ReadDisable;
        raddr1 = inst_i[25:21];
        raddr2 = inst_i[20:16];
        aluop = `EXE_NOP_OP;
        alusel = `EXE_RES_NOP;
        wen = `WriteDisable;
        waddr = inst_i[15:11];
        imm = `ZeroWord;
        link_addr_o = `ZeroWord;
        branch_flag = `NoBranch;
        branch_addr_o = `ZeroWord;
        exception_type_is_adel = `False_v;
        exception_type_is_eret = `False_v;
        exception_type_is_break = `False_v;
        inst_valid = `InstInvalid;
        exception_type_is_syscall = `False_v;
        next_inst_in_delayslot_o = `NotInDelaySlot;
        case(op)
            `EXE_SPECIAL_INST: begin
                if (op2 == 5'b00000) begin
                    case (op3)
                        `EXE_ADD: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_ADD_OP;
                            alusel = `EXE_RES_ARITHMETIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_ADDU: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_ADDU_OP;
                            alusel = `EXE_RES_ARITHMETIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SUB: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SUB_OP;
                            alusel = `EXE_RES_ARITHMETIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SUBU: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SUBU_OP;
                            alusel = `EXE_RES_ARITHMETIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_MULT: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_MULT_OP;
                            wen = `WriteDisable;
                            inst_valid = `InstValid;
                        end
                        `EXE_MULTU: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_MULTU_OP;
                            wen = `WriteDisable;
                            inst_valid = `InstValid;
                        end
                        `EXE_DIV: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_DIV_OP;
                            wen = `WriteDisable;
                            inst_valid = `InstValid;
                        end
                        `EXE_DIVU: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_DIVU_OP;
                            wen = `WriteDisable;
                            inst_valid = `InstValid;
                        end
                        `EXE_JR: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadDisable;
                            aluop = `EXE_JR_OP;
                            alusel = `EXE_RES_JUMP_BRANCH;
                            wen = `WriteDisable;
                            link_addr_o = `ZeroWord;
                            branch_flag = `Branch;
                            branch_addr_o = rdata1_o;
                            inst_valid = `InstValid;
                            next_inst_in_delayslot_o = `InDelaySlot;
                        end
                        `EXE_OR: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_OR_OP;
                            alusel = `EXE_RES_LOGIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_AND: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_AND_OP;
                            alusel = `EXE_RES_LOGIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_NOR: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_NOR_OP;
                            alusel = `EXE_RES_LOGIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SLLV: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SLL_OP;
                            alusel = `EXE_RES_SHIFT;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SRLV: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SRL_OP;
                            alusel = `EXE_RES_SHIFT;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SRAV: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SRA_OP;
                            alusel = `EXE_RES_SHIFT;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_MFHI: begin
                            ren1 = `ReadDisable;
                            ren2 = `ReadDisable;
                            aluop = `EXE_MFHI_OP;
                            alusel = `EXE_RES_MOVE;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_MFLO: begin
                            ren1 = `ReadDisable;
                            ren2 = `ReadDisable;
                            aluop = `EXE_MFLO_OP;
                            alusel = `EXE_RES_MOVE;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_MTHI: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadDisable;
                            aluop = `EXE_MTHI_OP;
                            wen = `WriteDisable;
                            inst_valid = `InstValid;
                        end
                        `EXE_MTLO: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadDisable;
                            aluop = `EXE_MTLO_OP;
                            wen = `WriteDisable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SLT: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SLT_OP;
                            alusel = `EXE_RES_ARITHMETIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_SLTU: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_SLTU_OP;
                            alusel = `EXE_RES_ARITHMETIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_XOR: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadEnable;
                            aluop = `EXE_XOR_OP;
                            alusel = `EXE_RES_LOGIC;
                            wen = `WriteEnable;
                            inst_valid = `InstValid;
                        end
                        `EXE_JALR: begin
                            ren1 = `ReadEnable;
                            ren2 = `ReadDisable;
                            aluop = `EXE_JALR_OP;
                            alusel = `EXE_RES_JUMP_BRANCH;
                            wen = `WriteEnable;
                            waddr = inst_i[15:11];
                            link_addr_o = pc_plus_8;
                            branch_flag = `Branch;
                            branch_addr_o = rdata1_o;
                            inst_valid = `InstValid;
                            next_inst_in_delayslot_o = `InDelaySlot;
                        end
                        default: begin
                        end
                    endcase
                end else begin
                end
                case (op3)
                    `EXE_SYSCALL: begin
                        ren1 = `ReadDisable;
                        ren2 = `ReadDisable;
                        aluop = `EXE_SYSCALL_OP;
                        alusel = `EXE_RES_NOP;
                        wen = `WriteDisable;
                        inst_valid = `InstValid;
                        exception_type_is_syscall = `True_v;
                    end
                    `EXE_BREAK: begin
                        ren1 = `ReadDisable;
                        ren2 = `ReadDisable;
                        aluop = `EXE_BREAK_OP;
                        alusel = `EXE_RES_NOP;
                        wen = `WriteDisable;
                        inst_valid = `InstValid;
                        exception_type_is_break = `True_v;
                    end
                    default: begin
                    end
                endcase
            end
            `EXE_ADDI: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_ADDI_OP;
                alusel = `EXE_RES_ARITHMETIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_ADDIU: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_ADDIU_OP;
                alusel = `EXE_RES_ARITHMETIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_LUI: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_OR_OP;
                alusel = `EXE_RES_LOGIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {inst_i[15:0], 16'h0};
                inst_valid = `InstValid;
            end
            `EXE_SLTI: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_SLT_OP;
                alusel = `EXE_RES_ARITHMETIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_SLTIU: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_SLTU_OP;
                alusel = `EXE_RES_ARITHMETIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {{16{inst_i[15]}}, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_LW: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_LW_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                inst_valid = `InstValid;
            end
            `EXE_LB: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_LB_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                inst_valid = `InstValid;
            end
            `EXE_LBU: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_LBU_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                inst_valid = `InstValid;
            end
            `EXE_LH: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_LH_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                inst_valid = `InstValid;
            end
            `EXE_LHU: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_LHU_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                inst_valid = `InstValid;
            end
            `EXE_BEQ: begin
                ren1 = `ReadEnable;
                ren2 = `ReadEnable;
                aluop = `EXE_BEQ_OP;
                alusel = `EXE_RES_JUMP_BRANCH;
                wen = `WriteDisable;
                if (rdata1_o == rdata2_o) begin
                    branch_flag = `Branch;
                    branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                end
                inst_valid = `InstValid;
                next_inst_in_delayslot_o = `InDelaySlot;
            end
            `EXE_BGTZ: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_BGTZ_OP;
                alusel = `EXE_RES_JUMP_BRANCH;
                wen = `WriteDisable;
                if ((rdata1_o[31] == 1'b0) && (rdata1_o != `ZeroWord)) begin
                    branch_flag = `Branch;
                    branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                end
                inst_valid = `InstValid;
                next_inst_in_delayslot_o = `InDelaySlot;
            end
            `EXE_BLEZ: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_BLEZ_OP;
                alusel = `EXE_RES_JUMP_BRANCH;
                wen = `WriteDisable;
                if ((rdata1_o[31] == 1'b1) || (rdata1_o == `ZeroWord)) begin
                    branch_flag = `Branch;
                    branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                end
                inst_valid = `InstValid;
                next_inst_in_delayslot_o = `InDelaySlot;
            end
            `EXE_BNE: begin
                ren1 = `ReadEnable;
                ren2 = `ReadEnable;
                aluop = `EXE_BLEZ_OP;
                alusel = `EXE_RES_JUMP_BRANCH;
                wen = `WriteDisable;
                if (rdata1_o != rdata2_o) begin
                    branch_flag = `Branch;
                    branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                end
                inst_valid = `InstValid;
                next_inst_in_delayslot_o = `InDelaySlot;
            end
            `EXE_J: begin
                ren1 = `ReadDisable;
                ren2 = `ReadDisable;
                aluop = `EXE_J_OP;
                alusel = `EXE_RES_JUMP_BRANCH;
                wen = `WriteDisable;
                link_addr_o = `ZeroWord;
                branch_flag = `Branch;
                branch_addr_o = {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                inst_valid = `InstValid;
                next_inst_in_delayslot_o = `InDelaySlot;
            end
            `EXE_JAL: begin
                ren1 = `ReadDisable;
                ren2 = `ReadDisable;
                aluop = `EXE_JAL_OP;
                alusel = `EXE_RES_JUMP_BRANCH;
                wen = `WriteEnable;
                waddr = 5'b11111;
                link_addr_o = pc_plus_8;
                branch_flag = `Branch;
                branch_addr_o = {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                inst_valid = `InstValid;
                next_inst_in_delayslot_o = `InDelaySlot;
            end
            `EXE_ORI: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_OR_OP;
                alusel = `EXE_RES_LOGIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {16'h0, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_XORI: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_XOR_OP;
                alusel = `EXE_RES_LOGIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {16'h0, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_ANDI: begin
                ren1 = `ReadEnable;
                ren2 = `ReadDisable;
                aluop = `EXE_AND_OP;
                alusel = `EXE_RES_LOGIC;
                wen = `WriteEnable;
                waddr = inst_i[20:16];
                imm = {16'h0, inst_i[15:0]};
                inst_valid = `InstValid;
            end
            `EXE_SW: begin
                ren1 = `ReadEnable;
                ren2 = `ReadEnable;
                aluop = `EXE_SW_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteDisable;
                inst_valid = `InstValid;
            end
            `EXE_SB: begin
                ren1 = `ReadEnable;
                ren2 = `ReadEnable;
                aluop = `EXE_SB_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteDisable;
                inst_valid = `InstValid;
            end
            `EXE_SH: begin
                ren1 = `ReadEnable;
                ren2 = `ReadEnable;
                aluop = `EXE_SH_OP;
                alusel = `EXE_RES_LOAD_STORE;
                wen = `WriteDisable;
                inst_valid = `InstValid;
            end
            `EXE_SPECIAL2_INST: begin
                case (op3)
                    `EXE_MUL: begin
                        ren1 = `ReadEnable;
                        ren2 = `ReadEnable;
                        aluop = `EXE_MUL_OP;
                        alusel = `EXE_RES_MUL;
                        wen = `WriteEnable;
                        inst_valid = `InstValid;
                    end
                    default: begin
                    end
                endcase
            end
            `EXE_REGIMM_INST: begin
                case (op4)
                    `EXE_BGEZ: begin
                        ren1 = `ReadEnable;
                        ren2 = `ReadDisable;
                        aluop = `EXE_BGEZ_OP;
                        alusel = `EXE_RES_JUMP_BRANCH;
                        wen = `WriteDisable;
                        if (rdata1_o[31] == 1'b0) begin
                            branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                            branch_flag = `Branch;
                        end
                        inst_valid = `InstValid;
                        next_inst_in_delayslot_o = `InDelaySlot;
                    end
                    `EXE_BGEZAL: begin
                        ren1 = `ReadEnable;
                        ren2 = `ReadDisable;
                        aluop = `EXE_BGEZAL_OP;
                        alusel = `EXE_RES_JUMP_BRANCH;
                        wen = `WriteEnable;
                        waddr = 5'b11111;
                        link_addr_o = pc_plus_8;
                        if (rdata1_o[31] == 1'b0) begin
                            branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                            branch_flag = `Branch;
                        end
                        inst_valid = `InstValid;
                        next_inst_in_delayslot_o = `InDelaySlot;
                    end
                    `EXE_BLTZ: begin
                        ren1 = `ReadEnable;
                        ren2 = `ReadDisable;
                        aluop = `EXE_BLTZ_OP;
                        alusel = `EXE_RES_JUMP_BRANCH;
                        wen = `WriteDisable;
                        if (rdata1_o[31] == 1'b1) begin
                            branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                            branch_flag = `Branch;
                        end
                        inst_valid = `InstValid;
                        next_inst_in_delayslot_o = `InDelaySlot;
                    end
                    `EXE_BLTZAL: begin
                        ren1 = `ReadEnable;
                        ren2 = `ReadDisable;
                        aluop = `EXE_BLTZAL_OP;
                        alusel = `EXE_RES_JUMP_BRANCH;
                        wen = `WriteEnable;
                        waddr = 5'b11111;
                        link_addr_o = pc_plus_8;
                        if (rdata1_o[31] == 1'b1) begin
                            branch_addr_o = pc_plus_4 + imm_sll2_signedext;
                            branch_flag = `Branch;
                        end
                        inst_valid = `InstValid;
                        next_inst_in_delayslot_o = `InDelaySlot;
                    end
                    default: begin
                    end
                endcase
            end
            default: begin
            end
        endcase
        if (inst_i[31:21] == 11'd0) begin
            case (op3)
                `EXE_SLL: begin
                    ren1 = `ReadDisable;
                    ren2 = `ReadEnable;
                    aluop = `EXE_SLL_OP;
                    alusel = `EXE_RES_SHIFT;
                    wen = `WriteEnable;
                    waddr = inst_i[15:11];
                    imm[4:0] = inst_i[10:6];
                    inst_valid = `InstValid;
                end
                `EXE_SRL: begin
                    ren1 = `ReadDisable;
                    ren2 = `ReadEnable;
                    aluop = `EXE_SRL_OP;
                    alusel = `EXE_RES_SHIFT;
                    wen = `WriteEnable;
                    waddr = inst_i[15:11];
                    imm[4:0] = inst_i[10:6];
                    inst_valid = `InstValid;
                end
                `EXE_SRA: begin
                    ren1 = `ReadDisable;
                    ren2 = `ReadEnable;
                    aluop = `EXE_SRA_OP;
                    alusel = `EXE_RES_SHIFT;
                    wen = `WriteEnable;
                    waddr = inst_i[15:11];
                    imm[4:0] = inst_i[10:6];
                    inst_valid = `InstValid;
                end
                default: begin
                end
            endcase
        end else if ((inst_i[31:21] == 11'b01000000000) &&
                     (inst_i[10:0] == 8'b00000000)) begin
            ren1 = `ReadDisable;
            ren2 = `ReadDisable;
            raddr1 = inst_i[20:16];
            aluop = `EXE_MFC0_OP;
            alusel = `EXE_RES_MOVE;
            wen = `WriteEnable;
            waddr = inst_i[20:16];
            inst_valid = `InstValid;
        end else if ((inst_i[31:21] == 11'b01000000100) &&
                     (inst_i[10:3] == 8'b00000000)) begin
            ren1 = `ReadEnable;
            ren2 = `ReadDisable;
            raddr1 = inst_i[20:16];
            aluop = `EXE_MTC0_OP;
            wen = `WriteDisable;
            inst_valid = `InstValid;
        end else if (inst_i == `EXE_ERET) begin
            ren1 = `ReadDisable;
            ren2 = `ReadDisable;
            aluop = `EXE_ERET_OP;
            wen = `WriteDisable;
            inst_valid = `InstValid;
            exception_type_is_eret = `True_v;
        end else begin
        end
    end
end

always @(*) begin
    if (resetn == `RstEnable)                                                                   rdata1_o = `ZeroWord;
    else if ((ren1 == `ReadEnable) && (ex_wen == `WriteEnable) && (ex_waddr == raddr1))         rdata1_o = ex_wdata;
    else if ((ren1 == `ReadEnable) && (mem_wen == `WriteEnable) && (mem_waddr == raddr1))       rdata1_o = mem_wdata;
    else if (ren1 == `ReadEnable)                                                               rdata1_o = rdata1_i;
    else if (ren1 == `ReadDisable)                                                              rdata1_o = imm;
    else                                                                                        rdata1_o = `ZeroWord;
end

always @(*) begin
    if (resetn == `RstEnable)                                                                   rdata2_o = `ZeroWord;
    else if ((ren2 == `ReadEnable) && (ex_wen == `WriteEnable) && (ex_waddr == raddr2))         rdata2_o = ex_wdata;
    else if ((ren2 == `ReadEnable) && (mem_wen == `WriteEnable) && (mem_waddr == raddr2))       rdata2_o = mem_wdata;
    else if (ren2 == `ReadEnable)                                                               rdata2_o = rdata2_i;
    else if (ren2 == `ReadDisable)                                                              rdata2_o = imm;
    else                                                                                        rdata2_o = `ZeroWord;
end

always @(*) begin
    if (resetn == `RstEnable) begin
        is_in_delayslot_o = `NotInDelaySlot;
    end else begin
        is_in_delayslot_o = is_in_delayslot_i;
    end
end

endmodule