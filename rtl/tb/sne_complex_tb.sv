/* 
 * Alfio Di Mauro <adimauro@student.ethz.ch>
 * Arpan Suravi Prasad <prasadar@student.ethz.ch>
 *
 * Copyright (C) 2018-2022 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 *
 *                http://solderpad.org/licenses/SHL-0.51. 
 *
 * Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */
`define GROUP(n) n
`define SLICE(n) n
`define STREAMER(n) n
`define SEQUENCER(n) n
`define NETLIST_NAME(n,g,s,l,k) sne_top_GROUP_NUMBER``g``_NEURON_NUMBER``n``_SLICE_NUMBER``s``_LAYER``l_SLOTS``k
`define XBAR_CONN(F,E,D,C,B,A) (A << 2) | (B << 7) | (C << 12) | (D << 17) | (E << 22) | (F << 27)

timeunit 1ns;
timeprecision 1ps;

module sne_complex_tb;

  import sne_evt_stream_pkg::*; 
  import sne_pkg::*;
  import sne_tb_pkg::*;
  import engine_clock_reg_pkg::*;
  import bus_clock_reg_pkg::*;
  import system_clock_reg_pkg::*;

logic        system_clk_i  ;
logic        system_rst_ni ;

logic        sne_interco_clk_i  ;
logic        sne_interco_rst_ni ;

logic        sne_engine_clk_i  ;
logic        sne_engine_rst_ni ;

logic    [STREAMERS-1:0]     evt_i         ;      

logic [STREAMERS-1:0]         tcdm_req_o    ;
logic [STREAMERS-1:0]         tcdm_gnt_i    ;
logic [STREAMERS-1:0]  [31:0] tcdm_add_o    ;
logic [STREAMERS-1:0]         tcdm_wen_o    ;
logic [STREAMERS-1:0]   [3:0] tcdm_be_o     ;
logic [STREAMERS-1:0]  [31:0] tcdm_data_o   ;
logic [STREAMERS-1:0]  [31:0] tcdm_r_data_i ;
logic [STREAMERS-1:0]         tcdm_r_valid_i;


  //--- APB peripheral bus
logic                                  apb_slave_pwrite      ; 
logic                                  apb_slave_psel        ;
logic                                  apb_slave_penable     ;
logic [31:0]                           apb_slave_paddr       ;
logic [31:0]                           apb_slave_pwdata      ;
logic [31:0]                           apb_slave_prdata      ;
logic                                  apb_slave_pready      ; 
logic                                  apb_slave_pslverr     ;

// logic                                  clk_i;

localparam time CLK_PERIOD_SYSTEM      = 50ns;
localparam time CLK_PERIOD_ENGINE   = 100ns;
localparam time CLK_PERIOD_INTERCO   = 200ns;
localparam time APPL_DELAY          = 0ns;
localparam time ACQ_DELAY           = 30ns;
localparam unsigned RST_CLK_CYCLES  = 10;
localparam unsigned TOT_CHECKS      = 100;
localparam APB_ADDR_WIDTH = 32;
localparam APB_DATA_WIDTH = 32;

tcdm_model #(

  .MP            ( STREAMERS),
  .MEMORY_SIZE   ( 8192*256),
  .BASE_ADDR     ( 0     ),
  .PROB_STALL    ( 0.7   )

) TCDM (

  .clk_i         ( system_clk_i   ),
  .randomize_i   ( 1'b0           ),
  .enable_i      ( 1'b1           ),
  .stallable_i   ( 1'b1           ),

  .tcdm_req_i    ( tcdm_req_o     ),
  .tcdm_gnt_o    ( tcdm_gnt_i     ),
  .tcdm_add_i    ( tcdm_add_o     ),
  .tcdm_wen_i    ( tcdm_wen_o     ),
  .tcdm_be_i     ( tcdm_be_o      ),
  .tcdm_data_i   ( tcdm_data_o    ),
  .tcdm_r_data_o ( tcdm_r_data_i  ),
  .tcdm_r_valid_o( tcdm_r_valid_i )

);

clk_rst_gen #(
    .CLK_PERIOD     (CLK_PERIOD_SYSTEM),
    .RST_CLK_CYCLES (RST_CLK_CYCLES)
) i_clk_rst_gen_bus_clk (
    .clk_o  (system_clk_i),
    .rst_no (system_rst_ni)
);
clk_rst_gen #(
    .CLK_PERIOD     (CLK_PERIOD_INTERCO),
    .RST_CLK_CYCLES (RST_CLK_CYCLES)
) i_clk_rst_gen_interco_clk (
    .clk_o  (sne_interco_clk_i),
    .rst_no (sne_interco_rst_ni)
);
clk_rst_gen #(
    .CLK_PERIOD     (CLK_PERIOD_ENGINE),
    .RST_CLK_CYCLES (RST_CLK_CYCLES)
) i_clk_rst_gen_engine_clk (
    .clk_o  (sne_engine_clk_i),
    .rst_no (sne_engine_rst_ni)
);

APB_BUS  #(.APB_ADDR_WIDTH(APB_ADDR_WIDTH), .APB_DATA_WIDTH(APB_DATA_WIDTH)) apb_slave();
APB_BUS_t APB_BUS_s;
assign #0.5ns apb_slave.paddr   = APB_BUS_s.paddr  ;
assign #0.5ns apb_slave.pwdata  = APB_BUS_s.pwdata ;
assign #0.5ns apb_slave.pwrite  = APB_BUS_s.pwrite ;
assign #0.5ns apb_slave.psel    = APB_BUS_s.psel   ;
assign #0.5ns apb_slave.penable = APB_BUS_s.penable;
assign APB_BUS_s.prdata  = apb_slave.prdata ;
assign APB_BUS_s.pready  = apb_slave.pready ;
assign APB_BUS_s.pslverr = apb_slave.pslverr;
logic [31:0] read_data;
int fd_crops; 
int fd_offsets; 
int status;
int online_read;
int fd;
initial begin
wait(sne_engine_rst_ni);
wait(system_rst_ni);
wait(sne_interco_rst_ni);
#10ns;
$readmemh("l2_stim_sne.txt",sne_complex_tb.TCDM.memory);

if(`LAYER==2) begin 
  fd_crops = $fopen("crops_fc.txt","r");
  fd_offsets = $fopen("offsets_fc.txt","r");
end else begin 
  fd_crops = $fopen("crops.txt","r");
  fd_offsets = $fopen("offsets.txt","r");
end

for (int i = 0; i < CLUSTERS; i++) begin

  logic [7:0] x0,y0,xc,yc;
  logic [7:0] xo,yo;

  status = $fscanf(fd_crops,"%d %d %d %d",x0,xc,y0,yc); 
  status = $fscanf(fd_offsets,"%d %d",xo,yo); 
  $display("%d %d %d %d",x0,xc,y0,yc);
  for (int j = 0; j < ENGINES; j++) begin
    if(j == 0) begin
      hal_sne_set_filter(`SLICE(j),`GROUP(i),x0,xc-1'b1,1'b1,y0,yc-1'b1,xo,yo,system_clk_i,APB_BUS_s);
    end else begin
      hal_sne_set_filter(`SLICE(j),`GROUP(i),x0,xc-1'b1,1'b1,y0,yc-1'b1,xo,yo,system_clk_i,APB_BUS_s);
    end
  end
end

for(int i = 0; i<ENGINES; i++) begin 
  hal_sne_init_sequencer(`SEQUENCER(i),0,63 ,system_clk_i,APB_BUS_s);
  APB_WRITE(ENGINE_CLOCK_CFG_CID_I_0_OFFSET+4*i,(((i*4+0)<<24)+((i*4+1)<<16)+((i*4+2)<<8)+((i*4+3)<<0)),system_clk_i,APB_BUS_s);
  APB_WRITE(ENGINE_CLOCK_CFG_SLICE_I_0_OFFSET+4*i,32'h0800+`LAYER,system_clk_i,APB_BUS_s); 
  APB_WRITE(ENGINE_CLOCK_CFG_ERROR_I_0_OFFSET+4*i,32'h06,system_clk_i,APB_BUS_s);
end 

APB_WRITE(ENGINE_CLOCK_CFG_PARAMETER_I_OFFSET,32'h44024000,system_clk_i,APB_BUS_s);

if(`LAYER==0 | `LAYER==1) begin
  // config_xbar_stage0
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_0_OFFSET, `XBAR_CONN(0,1,15,15,15,15), system_clk_i, APB_BUS_s); 
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_1_OFFSET, `XBAR_CONN(15,15,15,15,15,15), system_clk_i, APB_BUS_s);  
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_2_OFFSET, 32'h7bdef10c, system_clk_i, APB_BUS_s);

  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_3_OFFSET, 32'h214c7424, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_4_OFFSET, 32'h84653a54, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_5_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_6_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_7_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);

  // config_xbar_stage1
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_0_OFFSET, 32'h7d800000, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_1_OFFSET, 32'h000007bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_2_OFFSET, 32'h7bdef844, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_3_OFFSET, 32'h94e957bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_4_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_5_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);

  //config barrier and synch 
  APB_WRITE(BUS_CLOCK_CFG_XBAR_BARRIER_I_OFFSET, 32'h00001555, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_SYNCH_I_OFFSET, 32'h3FFF, system_clk_i, APB_BUS_s);

  APB_WRITE(BUS_CLOCK_CFG_COMPLEX_I_OFFSET,32'h4,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(0),0,4,0,1,321,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'h07,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(1),32'h927C0,4,0,1,32'hFFFF,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET+4,32'hE03,system_clk_i,APB_BUS_s);
  #1000us;
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'h04,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(0),322*4,4,0,1,3,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'hE07,system_clk_i,APB_BUS_s);
  #50us;
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'h04,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(0),331*4,4,0,1,32'hFFFF,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'hC47,system_clk_i,APB_BUS_s);
end else begin

  // config_xbar_stage0
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_0_OFFSET, 32'h0044f7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_1_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_2_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_3_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_4_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_5_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_6_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_0_7_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);

  // config_xbar_stage1
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_0_OFFSET, 32'h789ef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_1_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_2_OFFSET, 32'h7bde07bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_3_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_4_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_STAGE_1_5_OFFSET, 32'h7bdef7bc, system_clk_i, APB_BUS_s);

  //config barrier and synch 
  APB_WRITE(BUS_CLOCK_CFG_XBAR_BARRIER_I_OFFSET, 32'h0000000, system_clk_i, APB_BUS_s);
  APB_WRITE(BUS_CLOCK_CFG_XBAR_SYNCH_I_OFFSET, 32'h0000, system_clk_i, APB_BUS_s);

  APB_WRITE(BUS_CLOCK_CFG_COMPLEX_I_OFFSET,32'h01ff0100,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'h04,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(0),169*4,4,0,1,3,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'hE07,system_clk_i,APB_BUS_s);
  #50us;
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'h04,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(0),0,4,0,1,32'hFFFF,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_FC_OFFSET_I_OFFSET,272,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_FC_TRAN_SIZE_I_0_OFFSET,32'h00800080,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_FC_DIMENSION_I_OFFSET,32'h20200000,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET,32'hCC7,system_clk_i,APB_BUS_s);
  hal_sne_init_streamer(`SLICE(0), `STREAMER(1),32'h927C0,4,0,1,32'hFFFF,system_clk_i,APB_BUS_s);
  APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET+4,32'hE03,system_clk_i,APB_BUS_s); 
end 

#20000us;
$writememh("output.txt", sne_complex_tb.TCDM.memory);

#100us;
$display("Online read value=%x",online_read);
$finish;
end

sne_complex i_sne_complex(
.system_clk_i(system_clk_i),
.system_rst_ni(system_rst_ni),
.sne_interco_clk_i(sne_interco_clk_i),
.sne_interco_rst_ni(sne_interco_rst_ni),
.sne_engine_clk_i(sne_engine_clk_i),
.sne_engine_rst_ni(sne_engine_rst_ni),
.evt_i(2'b00),
.power_gate(1'b0),
.power_sleep(1'b0),
.tcdm_req_o(tcdm_req_o),
.tcdm_gnt_i(tcdm_gnt_i),
.tcdm_add_o(tcdm_add_o),
.tcdm_wen_o(tcdm_wen_o),
.tcdm_be_o(tcdm_be_o),
.tcdm_data_o(tcdm_data_o),
.tcdm_r_data_i(tcdm_r_data_i),
.tcdm_r_valid_i(tcdm_r_valid_i),
.apb_slave_pwrite(apb_slave.pwrite),
.apb_slave_psel(apb_slave.psel),
.apb_slave_penable(apb_slave.penable),
.apb_slave_paddr(apb_slave.paddr),
.apb_slave_pwdata(apb_slave.pwdata),
.apb_slave_prdata(apb_slave.prdata),
.apb_slave_pready(apb_slave.pready),
.apb_slave_pslverr(apb_slave.pslverr)
);
endmodule