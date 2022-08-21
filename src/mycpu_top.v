`include "defines.v"

module mycpu_top(
    input   [5:0]                       ext_int,

    input                               aclk,
    input                               aresetn,

    // ar
    output  [3:0]                       arid,
    output  [31:0]                      araddr,
    output  [7:0]                       arlen,
    output  [2:0]                       arsize,
    output  [1:0]                       arburst,
    output  [1:0]                       arlock,
    output  [3:0]                       arcache,
    output  [2:0]                       arprot,
    output                              arvalid,
    input                               arready,

    // r
    input   [3:0]                       rid,
    input   [31:0]                      rdata,
    input   [1:0]                       rresp,
    input                               rlast,
    input                               rvalid,
    output                              rready,

    // aw
    output  [3:0]                       awid,
    output  [31:0]                      awaddr,
    output  [7:0]                       awlen,
    output  [2:0]                       awsize,
    output  [1:0]                       awburst,
    output  [1:0]                       awlock,
    output  [3:0]                       awcache,
    output  [2:0]                       awprot,
    output                              awvalid,
    input                               awready,

    // w
    output  [3:0]                       wid,
    output  [31:0]                      wdata,
    output  [3:0]                       wstrb,
    output                              wlast,
    output                              wvalid,
    input                               wready,

    // b
    input   [3:0]                       bid,
    input   [1:0]                       bresp,
    input                               bvalid,
    output                              bready,

    output  [`InstAddrBus]              debug_wb_pc,
    output  [3:0]                       debug_wb_rf_wen,
    output  [`RegAddrBus]               debug_wb_rf_wnum,
    output  [`RegBus]                   debug_wb_rf_wdata
);
wire        cpu_cache_ireq;
wire        cpu_cache_iwr;
wire [1 :0] cpu_cache_isize;
wire [31:0] cpu_cache_iaddr;
wire [31:0] cpu_cache_iwdata;
wire [31:0] cpu_cache_irdata;
wire        cpu_cache_iaddrok;
wire        cpu_cache_idataok;

wire        axi_cache_arready;
wire        axi_cache_rvalid;
wire        axi_cache_rlast;
wire [31:0] axi_cache_rdata;
wire        axi_cache_arvalid;
wire [1: 0] axi_cache_rtype;
wire [31:0] axi_cache_raddr;
wire        axi_cache_rready;
wire        axi_cache_bvalid;
// inst sram-like
//wire inst_req;
//wire inst_wr;
//wire[1:0] inst_size;
//wire[31:0] inst_addr;
//wire[31:0] inst_wdata;
//wire[31:0] inst_rdata;
//wire inst_addr_ok;
//wire inst_data_ok;

// data sram-like
wire data_req;
wire data_wr;
wire[1:0] data_size;
wire[31:0] data_addr;
wire[31:0] data_wdata;
wire[31:0] data_rdata;
wire data_addr_ok;
wire data_data_ok;

wire[5:0] int;
wire timer_int;
assign int = {timer_int, ext_int[4:0]};

cpu_axi_interface u_cpu_axi_interface(
    .clk(aclk),
    .resetn(aresetn),
    
    .cache_arready(axi_cache_arready),
    .cache_rvalid(axi_cache_rvalid),
    .cache_rlast(axi_cache_rlast),
    .cache_rdata(axi_cache_rdata),
    .cache_rreq(axi_cache_arvalid),
    .cache_rtype(axi_cache_rtype),
    .cache_raddr(axi_cache_raddr),
    .cache_rready(axi_cache_rready),
    .cache_bvalid(axi_cache_bvalid),
    
//    .inst_req(inst_req),
//    .inst_wr(inst_wr),
//    .inst_size(inst_size),
//    .inst_addr(inst_addr),
//    .inst_wdata(inst_wdata),
//    .inst_rdata(inst_rdata),
//    .inst_addr_ok(inst_addr_ok),
//    .inst_data_ok(inst_data_ok),

    .data_req(data_req),
    .data_wr(data_wr),
    .data_size(data_size),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_addr_ok(data_addr_ok),
    .data_data_ok(data_data_ok),

    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

mycpu u_mycpu(
    .clk(aclk),
    .resetn(aresetn),
    .ext_int(int),
    .timer_int_o(timer_int),

    .inst_req(cpu_cache_ireq),
    .inst_wr(cpu_cache_iwr),
    .inst_size(cpu_cache_isize),
    .inst_addr(cpu_cache_iaddr),
    .inst_wdata(cpu_cache_iwdata),
    .inst_rdata(cpu_cache_irdata),
    .inst_addr_ok(cpu_cache_iaddrok),
    .inst_data_ok(cpu_cache_idataok),

    .data_req(data_req),
    .data_wr(data_wr),
    .data_size(data_size),
    .data_addr(data_addr),
    .data_wdata(data_wdata),
    .data_rdata(data_rdata),
    .data_addr_ok(data_addr_ok),
    .data_data_ok(data_data_ok),

    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wen(debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

Cache_top u_cache(
    .clk(aclk),
    .resetn(aresetn),
    
    .inst_cpu_req(cpu_cache_ireq),
    .inst_cpu_wr(cpu_cache_iwr),
    .inst_cpu_size(cpu_cache_isize),
    .inst_cpu_addr(cpu_cache_iaddr),
    .inst_cpu_wdata(cpu_cache_iwdata),
    .inst_cpu_rdata(cpu_cache_irdata),
    .inst_cpu_arready(cpu_cache_iaddrok),
    .inst_cpu_rready(cpu_cache_idataok),
    
//    .data_cpu_req(data_req),
//    .data_cpu_wr(data_wr),
//    .data_cpu_size(data_size),
//    .data_cpu_addr(data_addr),
//    .data_cpu_wdata(data_wdata),
//    .data_cpu_rdata(data_rdata),
//    .data_cpu_arready(data_addr_ok),
//    .data_cpu_rready(data_data_ok),
    
    .axi_arready(axi_cache_arready),
    .axi_rvalid(axi_cache_rvalid),
    .axi_rlast(axi_cache_rlast),
    .axi_rdata(axi_cache_rdata),
    
    .axi_rreq(axi_cache_arvalid),
    .axi_rtype(axi_cache_rtype),
    .axi_raddr(axi_cache_raddr),
    .axi_rready(axi_cache_rready),
    
//    .axi_wreq(awvalid),
//    .axi_wtype(awsize),
//    .axi_waddr(awaddr),
//    .axi_wstrb(wstrb),
//    .axi_wdata(wdata),
//    .axi_wready(wready),

    .bvalid(axi_cache_bvalid)
);

endmodule