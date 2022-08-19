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
 
`include "evt_stream_macros.svh"

module sne_complex 
	import sne_pkg::*;  
	import sne_evt_stream_pkg::*;
#(
	parameter BASE_ADDRESS = 32'h0
)(

	input                  logic        system_clk_i  ,
	input                  logic        system_rst_ni ,

	input                  logic        sne_interco_clk_i  ,
	input                  logic        sne_interco_rst_ni ,

	input                  logic        sne_engine_clk_i  ,
	input                  logic        sne_engine_rst_ni ,

	output                 logic        interrupt_o       , 

	input                  logic        power_gate,
	input                  logic        power_sleep,

	input  logic [STREAMERS-1:0]        evt_i         ,      

	output logic [STREAMERS-1:0]        tcdm_req_o    ,
	input  logic [STREAMERS-1:0]        tcdm_gnt_i    ,
	output logic [STREAMERS-1:0] [31:0] tcdm_add_o    ,
	output logic [STREAMERS-1:0]        tcdm_wen_o    ,
	output logic [STREAMERS-1:0]  [3:0] tcdm_be_o     ,
	output logic [STREAMERS-1:0] [31:0] tcdm_data_o   ,
	input  logic [STREAMERS-1:0] [31:0] tcdm_r_data_i ,
	input  logic [STREAMERS-1:0]        tcdm_r_valid_i,

  //--- APB peripheral bus
  	input  logic                        apb_slave_pwrite      , 
  	input  logic                        apb_slave_psel        ,
  	input  logic                        apb_slave_penable     ,
  	input  logic [31:0]                 apb_slave_paddr       ,
  	input  logic [31:0]                 apb_slave_pwdata      ,
  	output logic [31:0]                 apb_slave_prdata      ,
  	output logic                        apb_slave_pready      , 
  	output logic                        apb_slave_pslverr   
	
);

localparam CROSSBAR_SRC_PORT = 16;
localparam CROSSBAR_DST_PORT = 16;
localparam CROSSBAR_ARB_PORT = 2*CROSSBAR_DST_PORT;
localparam CROSSBAR_INT_PORT = CROSSBAR_DST_PORT;
localparam CROSSBAR_MID_PORT = CROSSBAR_INT_PORT + (CROSSBAR_ARB_PORT/2);
logic [(CROSSBAR_INT_PORT+CROSSBAR_ARB_PORT)-1:0][((CROSSBAR_DST_PORT + (CROSSBAR_DST_PORT/2)) > 1) ? $clog2(CROSSBAR_DST_PORT + (CROSSBAR_DST_PORT/2))-1 :0:0] cfg_stage0_i;
logic [(CROSSBAR_SRC_PORT+(CROSSBAR_ARB_PORT/2))-1:0][((CROSSBAR_MID_PORT) > 1) ? $clog2(CROSSBAR_MID_PORT)-1 :0:0] cfg_stage1_i;


config_bus_t                    config_bus_i          ;
config_engine_t                 config_engine_i       ;
config_system_sw_t              config_system_sw_o    ;
config_system_hw_t              config_system_hw_i    ;

logic [STREAMERS-1:0][31:0    ] sta_main_status_o     ;
logic [2*CROSSBAR_DST_PORT-1:0] fwd_barrier_i         ;
logic [2*CROSSBAR_DST_PORT-1:0] synch_en_i            ;
logic [ENGINES-1:0][31:0      ] online_data           ;      
logic [$clog2(ENGINES)-1:0    ] online_engine_id      ;
logic [$clog2(CLUSTERS)-1:0   ] online_group_id       ;
logic [ENGINES-1:0            ] online_engine_enable_i;

logic [1:0]                     interrupt             ;

SNE_EVENT_STREAM evt_stream_crossbar_out[CROSSBAR_SRC_PORT-1:0](.clk_i(sne_interco_clk_i));
SNE_EVENT_STREAM evt_stream_crossbar_in[CROSSBAR_DST_PORT-1:0](.clk_i(sne_interco_clk_i));//additional unconnected master

for (genvar i = 0; i < STREAMERS; i++) begin: streamer
	evt_streamer #(.T(uevent_t), .EVT_SRC_FIFO_DEPTH(4), .EVT_DST_FIFO_DEPTH(4), .STREAMER_ID(i)) i_evt_streamer (

		.system_clk_i         ( system_clk_i               ),
		.system_rst_ni        ( system_rst_ni              ),
		.sne_clk_i            ( sne_interco_clk_i          ),
		.sne_rst_ni           ( sne_interco_rst_ni         ),
		.evt_i                ( evt_i[i]                   ),
		.tcdm_req_o           ( tcdm_req_o[i]              ),
		.tcdm_gnt_i           ( tcdm_gnt_i[i]              ),
		.tcdm_add_o           ( tcdm_add_o[i][31:0]        ),
		.tcdm_wen_o           ( tcdm_wen_o[i]              ),
		.tcdm_be_o            ( tcdm_be_o[i][3:0]          ),
		.tcdm_data_o          ( tcdm_data_o[i][31:0]       ),
		.tcdm_r_data_i        ( tcdm_r_data_i[i][31:0]     ),
		.tcdm_r_valid_i       ( tcdm_r_valid_i[i]          ),
		.sta_main_status_o    ( sta_main_status_o[i][31:0] ),
		.power_gate           ( power_gate                 ),
		.power_sleep          ( power_sleep                ),
		.interrupt_o          ( interrupt[i]               ),
		.config_system_sw_i   ( config_system_sw_o         ),
		.evt_stream_src       ( evt_stream_crossbar_in[i]  ),
		.evt_stream_dst       ( evt_stream_crossbar_out[i] )

	);
	assign config_system_hw_i.hw2reg.sta_main_status_o[i].d = sta_main_status_o[i][31:0];
	assign config_system_hw_i.hw2reg.sta_main_status_o[i].de = 1'b1;
end: streamer

for(genvar j=0; j<8; j++) begin : proc_xbar_cfg_stage_0_register 
	assign cfg_stage0_i[j*6+0] = config_bus_i.reg2hw.cfg_xbar_stage_0[j].cfg_0;
	assign cfg_stage0_i[j*6+1] = config_bus_i.reg2hw.cfg_xbar_stage_0[j].cfg_1;
	assign cfg_stage0_i[j*6+2] = config_bus_i.reg2hw.cfg_xbar_stage_0[j].cfg_2;
	assign cfg_stage0_i[j*6+3] = config_bus_i.reg2hw.cfg_xbar_stage_0[j].cfg_3;
	assign cfg_stage0_i[j*6+4] = config_bus_i.reg2hw.cfg_xbar_stage_0[j].cfg_4;
	assign cfg_stage0_i[j*6+5] = config_bus_i.reg2hw.cfg_xbar_stage_0[j].cfg_5;
end 

for(genvar j=0; j<5; j++) begin : proc_xbar_cfg_stage_1_register 
	assign cfg_stage1_i[j*6+0] = config_bus_i.reg2hw.cfg_xbar_stage_1[j].cfg_0;
	assign cfg_stage1_i[j*6+1] = config_bus_i.reg2hw.cfg_xbar_stage_1[j].cfg_1;
	assign cfg_stage1_i[j*6+2] = config_bus_i.reg2hw.cfg_xbar_stage_1[j].cfg_2;
	assign cfg_stage1_i[j*6+3] = config_bus_i.reg2hw.cfg_xbar_stage_1[j].cfg_3;
	assign cfg_stage1_i[j*6+4] = config_bus_i.reg2hw.cfg_xbar_stage_1[j].cfg_4;
	assign cfg_stage1_i[j*6+5] = config_bus_i.reg2hw.cfg_xbar_stage_1[j].cfg_5;
end 
assign cfg_stage1_i[30] = config_bus_i.reg2hw.cfg_xbar_stage_1[5].cfg_0;
assign cfg_stage1_i[31] = config_bus_i.reg2hw.cfg_xbar_stage_1[5].cfg_1;

assign fwd_barrier_i = config_bus_i.reg2hw.cfg_xbar_barrier_i;
assign synch_en_i    = config_bus_i.reg2hw.cfg_xbar_synch_i;

assign interrupt_o = interrupt[1];

evt_synaptic_crossbar #(.T(uevent_t), .SRC_PORTS(CROSSBAR_SRC_PORT), .DST_PORTS(CROSSBAR_DST_PORT)) i_evt_synaptic_crossbar (
	.clk_i         (sne_interco_clk_i  ),
	.rst_ni        (sne_interco_rst_ni ),
	.cfg_stage0_i  (cfg_stage0_i  ),
	.cfg_stage1_i  (cfg_stage1_i  ),
	.fwd_barrier_i (fwd_barrier_i),
	.synch_en_i    (synch_en_i),
	.evt_stream_src(evt_stream_crossbar_out),
	.evt_stream_dst(evt_stream_crossbar_in)
);

assign evt_stream_crossbar_in[CROSSBAR_DST_PORT-1].valid = 0; 

SNE_EVENT_STREAM evt_data_aribter_src[ENGINES-1:0](.clk_i(sne_interco_clk_i));
SNE_EVENT_STREAM evt_stream_engine_dst[ENGINES-1:0](.clk_i(sne_interco_clk_i));

evt_data_arbiter #(.SLICE_NUMBER(ENGINES), .THRESHOLD(128)) i_evt_data_arbiter(
	.clk_i                (sne_interco_clk_i),
	.rst_ni               (sne_interco_rst_ni),
	.enable_i             (config_bus_i.reg2hw.cfg_complex_i.slice_enable),
	.module_enable_i      (config_bus_i.reg2hw.cfg_complex_i.fc_enable   ),
	.evt_weight_stream_dst(evt_stream_crossbar_out[CROSSBAR_DST_PORT-1]),
	.evt_weight_stream_src(evt_data_aribter_src)
);

evt_stream_selector #(.SLICE_NUMBER(ENGINES)) i_evt_stream_selector(
	.clk_i 				    (sne_interco_clk_i),
	.rst_ni                 (sne_interco_rst_ni),
	.enable_i               (config_bus_i.reg2hw.cfg_complex_i.select_stream),
	.evt_stream_arbiter_dst (evt_data_aribter_src),
	.evt_stream_crossbar_dst(evt_stream_crossbar_out[STREAMERS+ENGINES-1:STREAMERS]),
	.evt_stream_engine_src  (evt_stream_engine_dst)
);

for (genvar i = 0; i < ENGINES; i++) begin : evt_engine
	evt_engine #(.DP_GROUP(CLUSTERS), .ENGINE_ID(i)) i_evt_engine (
		.bus_clk_i            (sne_interco_clk_i                      ),
		.bus_rst_ni           (sne_interco_rst_ni                     ),
		.engine_clk_i         (sne_engine_clk_i                       ),
		.engine_rst_ni        (sne_engine_rst_ni                      ),
		.config_i             (config_engine_i                        ),
		.online_data_o        (online_data[i][31:0]                   ),
		.online_enable_i      (online_engine_id==i                    ),
		.online_group_id      (online_group_id                        ),
		.power_gate           (1'b0                                   ),
		.power_sleep          (1'b0                                   ),
		.ack_error_i          (config_bus_i.reg2hw.cfg_complex_i.ack_err[i]),
		.evt_stream_dst       (evt_stream_engine_dst[i]               ),
		.evt_stream_src       (evt_stream_crossbar_in[ STREAMERS + i] )
	);
end : evt_engine

evt_reggen  #(.DP_GROUP(CLUSTERS),.BASE_ADDRESS(BASE_ADDRESS)) i_evt_reggen
(
	.system_clk_i     (system_clk_i      ),
	.system_rst_ni    (system_rst_ni     ),
	.bus_clk_i        (sne_interco_clk_i ),
	.bus_rst_ni       (sne_interco_rst_ni),
	.sne_engine_clk_i (sne_engine_clk_i  ),
	.sne_engine_rst_ni(sne_engine_rst_ni ),
	.apb_slave_pwrite (apb_slave_pwrite  ), 
  	.apb_slave_psel   (apb_slave_psel    ),
  	.apb_slave_penable(apb_slave_penable ),
  	.apb_slave_paddr  (apb_slave_paddr   ),
  	.apb_slave_pwdata (apb_slave_pwdata  ),
  	.apb_slave_prdata (apb_slave_prdata  ),
  	.apb_slave_pready (apb_slave_pready  ), 
  	.apb_slave_pslverr(apb_slave_pslverr ),
  	.online_data_i    (online_data       ),
  	.engine_id        (online_engine_id  ),
  	.group_id         (online_group_id   ),
  	.config_engine_i  (config_engine_i   ),
  	.config_bus_i     (config_bus_i      ),
  	.config_system_hw_i(config_system_hw_i),
  	.config_system_sw_o(config_system_sw_o)
);

endmodule