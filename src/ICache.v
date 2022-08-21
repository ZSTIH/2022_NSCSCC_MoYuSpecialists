//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/07/03 10:11:28
// Design Name: 
// Module Name: ICache
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


module ICache (
    input   wire        clk, 
    input   wire        rst,

    // cpu
    input   wire        rreq_inst_cpu_i,    // read request from cpu
    input   wire[31 :0] vaddr_inst_cpu_i,   // virtual addr of inst from cpu
    input   wire[31 :0] paddr_inst_tlb_i,   //
    output  reg         valid_inst_cpu_o,   // data is ok
    output  wire        arready_inst_cpu_o, // addr is ok
    output  wire[31 :0] inst_cpu_o,         // inst to cpu
    output  wire        hit_inst_cpu_o,     // hit tag

    // mem
    input   wire[255:0] inst_mem_i,         // [32*-1:0] read inst block(8bank)from memory
    input   wire        valid_mem_i,        // valid tag, trigger read done
    output  wire        ren_inst_mem_o,     // read request to mem
    output  wire[31 :0] addr_inst_mem_o     // send read addr to memory
    
    // tlb
//    output wire inst_uncached
    // pc
    // output wire[31:0] ctrl_pc_o 
);

///////////////////////* initial definition *//////////////////////
reg [3:0]       current_state;
reg [3:0]       next_state;
localparam      IDLE = 4'h0,         // wait request and addr from cpu
                TAG_COMPARE = 4'h2,  // compare tag between addr and tagv ram
                ALLOCATE = 4'h4,     // read new block from mem by addr
                WRITE_BACK = 4'h8;   // write new block into cache and update(hit)

// read information from addr which is sent from cpu
// wire [31:0]paddr_inst_tlb_i = vaddr_inst_cpu_i;
 wire [19:  0]  cache_tag    = paddr_inst_tlb_i[31:12]; // physical tag
 wire [ 6:  0]  cache_index  = vaddr_inst_cpu_i[11: 5]; // vitual index
 wire [ 4:  0]  cache_offset = vaddr_inst_cpu_i[ 4: 0];

// TLB
// TLB tlb_icache(
//     .vaddr_cpu_i(vaddr_inst_cpu_i),
//     .paddr_cache_o(paddr_inst_tlb_i),
//     .uncached(inst_uncached)
// );

///////////////////////* Ram set *//////////////////////
/* TAGV Ram */
// Ram 128*21*2 as physcial memory ram, which is write with physical address
// 20bits TAG + 1bit Valid
// addr: index
wire [20:0] tagv_w0;
wire [20:0] tagv_w1;
wire [3: 0] wea_way0;
wire [3: 0] wea_way1;
/* TODO:connect with tagv_ram (directly link data part to physical address)  */
tagv_ram Tagv_ram0 (
              .clka     (clk                ),
              .ena      (1                  ),
              .wea      (wea_way0           ),
              .addra    (cache_index        ),
              .dina     ({1'b1,cache_tag}   ),
              .douta    (tagv_w0)           );
tagv_ram Tagv_ram1 (
              .clka     (clk                ),
              .ena      (1                  ),
              .wea      (wea_way1           ),
              .addra    (cache_index        ),
              .dina     ({1'b1,cache_tag}   ),
              .douta    (tagv_w1)           );
/* Hit judge */
// tag equal and valid
wire    hit_way0   = (tagv_w0[19:0]==cache_tag)&&(tagv_w0[20]);
wire    hit_way1   = (tagv_w1[19:0]==cache_tag)&&(tagv_w1[20]);
// hit only TAG_COMPARE HIT in spite of WRITE_BACK HIT
wire    hit        = (current_state == TAG_COMPARE/* ||current_state == WRITE_BACK */)&&(hit_way0||hit_way1);

assign  hit_inst_cpu_o = hit;

/* DATA Ram */
// Ram 128*32*16 as physical memory of data
// 8bank & 2way
// addr:index
// offset[4:2] point which bank is
/* TODO:connect with bank ram , way0~1 & bank0~7 */
//way0_bank n(0~7)
wire [31:0]cache_way0[0:7];
bank_ram Bank0_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*1-1:32*0]),.douta(cache_way0[0]));
bank_ram Bank1_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*2-1:32*1]),.douta(cache_way0[1]));
bank_ram Bank2_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*3-1:32*2]),.douta(cache_way0[2]));
bank_ram Bank3_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*4-1:32*3]),.douta(cache_way0[3]));
bank_ram Bank4_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*5-1:32*4]),.douta(cache_way0[4]));
bank_ram Bank5_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*6-1:32*5]),.douta(cache_way0[5]));
bank_ram Bank6_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*7-1:32*6]),.douta(cache_way0[6]));
bank_ram Bank7_way0(.clka(clk),.ena(1),.wea(wea_way0),.addra(cache_index),.dina(inst_from_mem[32*8-1:32*7]),.douta(cache_way0[7]));
//way1_bank n(0~7)
wire [31:0]cache_way1[0:7];
bank_ram Bank0_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*1-1:32*0]),.douta(cache_way1[0]));
bank_ram Bank1_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*2-1:32*1]),.douta(cache_way1[1]));
bank_ram Bank2_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*3-1:32*2]),.douta(cache_way1[2]));
bank_ram Bank3_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*4-1:32*3]),.douta(cache_way1[3]));
bank_ram Bank4_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*5-1:32*4]),.douta(cache_way1[4]));
bank_ram Bank5_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*6-1:32*5]),.douta(cache_way1[5]));
bank_ram Bank6_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*7-1:32*6]),.douta(cache_way1[6]));
bank_ram Bank7_way1(.clka(clk),.ena(1),.wea(wea_way1),.addra(cache_index),.dina(inst_from_mem[32*8-1:32*7]),.douta(cache_way1[7]));
/* Dirty : only use in DCache*/
// Ram Dirty: 1*128*2way
// addr:index
// wire dirty_way0;
// wire dirty_way1;
// wire dirty = (dirty_way0 || dirty_way1);

/* LRU */
// use fake LRU replace algorithm, so set one LRU field(2way use together) 
// hit one, set another LRU
// miss, set chosen LRU
/* TODO: when miss, replace the way which is usually use*/
reg [127:0]LRU;
always@(posedge clk) begin
    if(!rst)    LRU <= 0;
    // update LRU after every inst output and valid_inst_cpu_o
    else if(valid_inst_cpu_o && hit_way0) begin
        // cache_index[6:0]=addr_inst_cpu_i[11:5]
                LRU[cache_index] <= 1; // set way1 to replace
    end else if(valid_inst_cpu_o && hit_way1) begin
                LRU[cache_index] <= 0; // way0
    end else    LRU <= LRU;
end


///////////////////////* state transformation *//////////////////////
// initial state set
always@(posedge clk) begin
    if(!rst) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// transformation
// IDLE-TAG_COMPARE-ALLOCATE-WRITE_BACK //
reg valid_from_mem;
always@(*) begin
    if(!rst)                            valid_from_mem = 0;
    else if(valid_mem_i==1)             valid_from_mem = 1;
    else if(current_state==WRITE_BACK)  valid_from_mem = 0;
end

always@(posedge clk) begin
    if(!rst) begin
        next_state <= IDLE;
    end else begin
        case(current_state) 
            // wait state
            IDLE: begin
                if(rreq_inst_cpu_i==1) next_state <= TAG_COMPARE;
//                else next_state <= IDLE;
            end

            // tag equal and valid , hit
            TAG_COMPARE: begin
                if(hit) next_state <= IDLE;
                else next_state <= ALLOCATE;
            end

            // read new block from mem
            ALLOCATE: begin
                if (valid_from_mem) next_state <= WRITE_BACK;
//                else next_state <= ALLOCATE; 
            end
            
            // send selected bank inst to inst_cpu_o and set hit
            // directly turn to IDLE
            WRITE_BACK: begin
                next_state <= IDLE;
            end
            default: next_state <= next_state;
        endcase
    end
end

///////////////////////* STATE ACTIVITIES *//////////////////////
// TAG_COMPARE:read inst from corresponding way and bank, compare tag
// select bank by offset[4:2]
// now: single shoot
// if double shoot:inst0~1 : way0~1 is supposed
wire [31:0]inst_way0 = cache_way0[cache_offset[4:2]];
wire [31:0]inst_way1 = cache_way1[cache_offset[4:2]];

// ALLOCATE: read mem, write cache
assign ren_inst_mem_o   = (current_state== ALLOCATE && ~hit && !valid_from_mem);
assign addr_inst_mem_o  = paddr_inst_tlb_i; /* send physical address to mem, if miss */

reg [255:0]inst_from_mem;
always@(posedge clk) begin
    if(!rst)inst_from_mem <= 0;
    else if(current_state==ALLOCATE) 
            inst_from_mem <= inst_mem_i;
    else    inst_from_mem <= inst_from_mem;
end
assign wea_way0=(current_state==WRITE_BACK && LRU[cache_index]==0)?4'hf:4'h0;
assign wea_way1=(current_state==WRITE_BACK && LRU[cache_index]==1)?4'hf:4'h0;

///////////////////////* OUTPUT *//////////////////////
assign inst_cpu_o = (current_state==TAG_COMPARE && hit_way0)?inst_way0:
                    (current_state==TAG_COMPARE && hit_way1)?inst_way1:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h0)?inst_from_mem[32*1-1:32*0]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h1)?inst_from_mem[32*2-1:32*1]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h2)?inst_from_mem[32*3-1:32*2]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h3)?inst_from_mem[32*4-1:32*3]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h4)?inst_from_mem[32*5-1:32*4]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h5)?inst_from_mem[32*6-1:32*5]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h6)?inst_from_mem[32*7-1:32*6]:
                    (current_state==WRITE_BACK && cache_offset[4:2]==3'h7)?inst_from_mem[32*8-1:32*7]:0;
//assign valid_inst_cpu_o = (current_state==TAG_COMPARE)&&hit;
reg do_req;
always@(posedge clk) begin
    if(!rst)    do_req <= 1'b0;
    else if(valid_inst_cpu_o&&current_state==IDLE)
                do_req <= 1'b0;
    else if(rreq_inst_cpu_i==1&&!do_req)
                do_req <= 1'b1;
end
always@(posedge clk) begin
    if(!rst) valid_inst_cpu_o <= 0;
    else     valid_inst_cpu_o <= (current_state==TAG_COMPARE&&do_req) && hit ? 1 :
                                 (current_state==WRITE_BACK&&do_req)         ? 1 : 0;
end
//assign valid_inst_cpu_o = (current_state==TAG_COMPARE)&&hit?1:
//                          (current_state==WRITE_BACK)?1:0;

assign arready_inst_cpu_o = !do_req;

endmodule