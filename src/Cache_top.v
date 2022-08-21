`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/07/12 09:29:06
// Design Name: 
// Module Name: Cache_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Cache_top(
        input   wire clk,  
        input   wire resetn,
        
        /* cpu */
        // inst
        input   wire        inst_cpu_req,            // read inst signal from cpu, valid
        input   wire        inst_cpu_wr,             // inst always be read
        input   wire[1  :0] inst_cpu_size,           // inst always be 4byte
        input   wire[31 :0] inst_cpu_addr,           // read inst addr from cpu
        input   wire[31 :0] inst_cpu_wdata,
        output  wire[31 :0] inst_cpu_rdata,          // inst to cpu
        output  wire        inst_cpu_arready,        // INST_OK:address is ready to read
        output  wire        inst_cpu_rready,         // DATA_OK:can be read by cpu: icache:inst_cache_rready OR uncached:inst_mem_rready
//        output  wire inst_cpu_hit,                    // hit cache signal from cache
        // data
//        input   wire        data_cpu_req,
//        input   wire        data_cpu_wr,
//        input   wire[1  :0] data_cpu_size,
//        input   wire[31 :0] data_cpu_addr,
//        input   wire[31 :0] data_cpu_wdata,
//        output  wire[31 :0] data_cpu_rdata,
//        output  wire        data_cpu_arready,
//        output  wire        data_cpu_rready,
        /* axi */
        // read
        input   wire        axi_arready,       // judge if read-requst can be received
        input   wire        axi_rvalid,        // from cpu_top:rvalid--cpu_rvalid
        input   wire[1  :0] axi_rlast,         // last data
        input   wire[31 :0] axi_rdata,         // inst need to be read from mem by axi
        output  reg         axi_rreq,          // read request to axi
        output  wire[1  :0] axi_rtype,         // read size
        output  wire[31 :0] axi_raddr,         // read addr to axi£¨the first addr)
        output  wire        axi_rready,        // read done
        // write
//        output  wire        axi_wreq,          // data write request to axi
//        output  wire[1  :0] axi_wtype,         // write size
//        output  wire[31 :0] axi_waddr,         // data write addr
//        output  wire[3  :0] axi_wstrb,         // write byte mask(write only avalaible:000,001,010
//        output  wire[127:0] axi_wdata,         // write data
//        input   wire        axi_wready,        // data which write is valid to axi
        // b
        input   wire        bvalid
    );
////////////////* STATE SET *///////////////
reg[3:0]    current_state;
reg[3:0]    next_state;
localparam  IDLE            = 4'h0,      // wait request and addr from cpu OR done task
            READ_IUNCACHED  = 4'h2,      // iuncached, need to skip cache, directly read from mem
            READ_ICACHE     = 4'h4;      // vist icache to read inst
////////////////* INITIAL SET *///////////////
//addr
reg        do_req;
reg        do_req_or; // req is inst or data;1:data,0:inst
// reg        do_wr_r;
reg [1 :0] do_size_r;
reg [31:0] do_addr_r;
// reg [31:0] do_wdata_r;
// wire       data_back;

always @(posedge clk)
begin
    do_req     <= !resetn                                   ? 1'b0 :
                  (inst_cpu_req/*||data_cpu_req*/)&&!do_req ? 1'b1 :
                  data_back                                 ? 1'b0 : do_req;
    do_req_or  <= !resetn ? 1'b0 :
                  /*!do_req ? data_cpu_req :*/ do_req_or;
    // do_wr_r    <= /*data_cpu_req&&data_cpu_arready ? data_cpu_wr :*/
    //               inst_cpu_req&&inst_cpu_arready ? inst_cpu_wr : do_wr_r;
    do_size_r  <= /*data_cpu_req&&data_cpu_arready ? data_cpu_size :*/
                  inst_cpu_req&&inst_cpu_arready ? inst_cpu_size : do_size_r;
    // do_addr_r  <= /*data_cpu_req&&data_cpu_arready ? data_cpu_addr :*/
                //   inst_cpu_req&&inst_cpu_arready ? inst_cpu_addr : do_addr_r;
    // do_wdata_r <= /*data_cpu_req&&data_cpu_arready ? data_cpu_wdata :*/
                //   inst_cpu_req&&inst_cpu_arready ? inst_cpu_wdata :do_wdata_r;
end
////////////////* ICACHE */////////////////
// TLB
//reg  [31 :0]    inst_tlb_vaddr;
//wire [31:0]     inst_cache_praddr;
// check uncached first, if uncached, read skip cache;
wire            inst_uncached;          // mark whether it is uncached or not

reg  [2  :0]    inst_read_count;        // count inst bank read from memory

reg             inst_cache_rreq;        // read request sent to cache(while cached)
reg  [31 :0]    inst_cache_addr;
wire [31 :0]    inst_cache_praddr;      // physical addr , transform from tlb

wire            inst_cache_rvalid;      // data is available
wire            inst_cache_arready;     // addr is ok
wire [31 :0]    inst_cache_rdata;       // inst read from cache

reg  [255:0]    inst_mem_rdata;         // read data from mem
reg             inst_mem_rready;        // memory read done, including 8 banks

wire            inst_mem_rreq;          // read request sent to mem
wire [31 :0]    inst_mem_raddr;         // read addr sent to mem

assign inst_cache_praddr = (inst_cache_addr[31:28]==4'h8)||(inst_cache_addr[31:28]==4'h9)||
                           (inst_cache_addr[31:28]==4'ha)||(inst_cache_addr[31:28]==4'hb)?
                            inst_cache_addr & 32'h1fff_ffff:inst_cache_addr;
assign inst_uncached     = (inst_cpu_addr[31:28]==4'ha)||(inst_cpu_addr[31:28]==4'hb) ? 1:0;

always@(posedge clk) begin
//    inst_tlb_vaddr  <= inst_cpu_req&&inst_cpu_arready ? inst_cpu_addr : inst_tlb_vaddr;
    inst_cache_rreq <= inst_uncached                  ? 1'b0 : inst_cpu_req; // req is inst or data;1:data,0:inst
    inst_cache_addr <= inst_uncached                  ? 1'b0 : 
                       inst_cpu_req&&inst_cpu_arready ? inst_cpu_addr : inst_cache_addr;
end
always@(posedge clk)begin
    if(!resetn)  inst_mem_rdata  <= 256'b0;
    else if(current_state==IDLE)    inst_mem_rdata  <= 256'b0;
    else if(axi_rvalid) begin
        case(inst_read_count)
            3'h0:inst_mem_rdata[32*1-1:32*0] <= axi_rdata;
            3'h1:inst_mem_rdata[32*2-1:32*1] <= axi_rdata;
            3'h2:inst_mem_rdata[32*3-1:32*2] <= axi_rdata;
            3'h3:inst_mem_rdata[32*4-1:32*3] <= axi_rdata;
            3'h4:inst_mem_rdata[32*5-1:32*4] <= axi_rdata;
            3'h5:inst_mem_rdata[32*6-1:32*5] <= axi_rdata;
            3'h6:inst_mem_rdata[32*7-1:32*6] <= axi_rdata;
            3'h7:inst_mem_rdata[32*8-1:32*7] <= axi_rdata;
        endcase
    end
end
always@(posedge clk)begin
    if      (!resetn)   inst_mem_rready <= 0;
    else if (current_state==READ_ICACHE&&inst_read_count==3'h7&&axi_rvalid)  
//    else if (current_state==READ_ICACHE&&inst_read_count==3'h7&&data_back)  
                        inst_mem_rready <= 1;
    else if (current_state==READ_IUNCACHED&&axi_rvalid)               
                        inst_mem_rready <= 1;
    else                inst_mem_rready <= 0;
end

//---axi
reg addr_rcv;
//reg wdata_rcv;


// when data is ok(rready) and available(rvalid)
assign data_back = !resetn  ? 1'b0 :
                   (current_state==IDLE) && addr_rcv && (axi_rvalid&&axi_rready||bvalid)        ? 1'b1 :
                   inst_cache_rvalid                                                            ? 1'b1 : 1'b0;
                   
always @(posedge clk) begin
    addr_rcv    <= !resetn                                  ? 1'b0 :
                   inst_mem_rreq&&axi_arready && axi_rvalid ? 1'b1 :
                   data_back                                ? 1'b0 : addr_rcv;
end

////////////////* STATE TRANSMISSION */////////////
// initial state set
always@(posedge clk) begin
    if(!resetn) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end
//state transmission
always@(posedge clk)begin
    if(!resetn)  next_state <= IDLE;
    else begin
        case(current_state)
            IDLE:begin
                if(inst_cpu_req && inst_uncached)           next_state<=READ_IUNCACHED;
                else if(inst_cpu_req && ~inst_uncached)     next_state<=READ_ICACHE;
            end
            // need read new block from memory by sram
            READ_IUNCACHED:
                if(axi_rvalid)                        next_state<=IDLE;
            READ_ICACHE:begin
                if(axi_rvalid&&inst_read_count==3'h7) next_state<=IDLE;
                else if(inst_cache_rvalid)            next_state<=IDLE;
            end
        endcase
    end
end
////////////////* READ SRAM&AXI *///////////////////
always@(posedge clk)begin
    if      (!resetn)               inst_read_count <= 0;
    else if (current_state==IDLE)   inst_read_count <= 0;
    else if (axi_rvalid&&axi_rreq)  inst_read_count <= inst_read_count + 1;
    else                            inst_read_count <= inst_read_count;
end

//////////////* OUTPUT SIGNAL *///////////////
assign inst_cpu_rdata   = inst_uncached ? inst_mem_rdata[31:0]:inst_cache_rdata[31:0];
assign inst_cpu_arready = !do_req /* && (current_state == IDLE)&& !data_cpu_req*/;
assign inst_cpu_rready  = do_req && !do_req_or && data_back/* && (current_state == IDLE)*/;
//assign data_cpu_rdata   = 0;
//assign data_cpu_arready = !do_req;
//assign data_cpu_rready = do_req&& do_req_or&&data_back;
//assign axi_rreq         = (current_state==IDLE)             ? 1'b0 : 
//                          (current_state == READ_IUNCACHED) ? 1'b1 :
//                          (current_state == READ_ICACHE)    ? inst_mem_rreq : axi_rreq;
always@(*) begin
    axi_rreq         = (current_state == IDLE)           ? 1'b0 : 
                       (current_state == READ_IUNCACHED) ? 1'b1 :
                       (current_state == READ_ICACHE)    ? inst_mem_rreq : axi_rreq;
end
assign axi_rtype        = do_size_r; // 4byte

assign axi_raddr        = (current_state == READ_IUNCACHED&&axi_rreq) ? inst_cache_praddr:
                          (current_state == READ_ICACHE&&axi_rreq)    ? {inst_cache_praddr[31:5],inst_read_count,2'b00} : 0;// find addr by byte
assign axi_rready       = 1'b1;
////////////////* CACHE BODY *//////////////////

//TLB tlb_icache(
//     .vaddr_cpu_i   (inst_tlb_vaddr      ),
//     .paddr_cache_o (inst_cache_praddr  ),
//     .uncached      (inst_uncached      )
// );
// ICache
ICache ICache0(
    .clk                (clk                ),
    .rst                (resetn             ),
    // cpu
    .rreq_inst_cpu_i    (inst_cache_rreq    ),
    .vaddr_inst_cpu_i   (inst_cache_addr    ),
    .paddr_inst_tlb_i   (inst_cache_praddr  ),
    .valid_inst_cpu_o   (inst_cache_rvalid  ),
    .arready_inst_cpu_o (inst_cache_arready ),
    .inst_cpu_o         (inst_cache_rdata   ),
    .hit_inst_cpu_o     (inst_cache_hit     ),
    // mem
    .inst_mem_i         (inst_mem_rdata     ),
    .valid_mem_i        (inst_mem_rready    ),
    .ren_inst_mem_o     (inst_mem_rreq      ),
    .addr_inst_mem_o    (inst_mem_raddr     )
    // tlb
//    .inst_uncached(inst_uncached)
);
endmodule