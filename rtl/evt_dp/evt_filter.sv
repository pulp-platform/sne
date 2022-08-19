/* 
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
 *
 * Copyright (C) 2018-2020 ETH Zurich, University of Bologna
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
module evt_filter 
	import sne_evt_stream_pkg::config_engine_t;
	#(
	// parameter ENGINE_ID = 0,
	parameter GROUP_ID  = 0,
	parameter DP_GROUP  = 0
	)(

	input  logic         engine_clk_i        ,  // Clock
	input  logic         engine_rst_ni       ,  // Asynchronous reset active low
	input  config_engine_t      config_i            ,
	input  logic         force_en_i          ,
	output logic         group_enable_o      ,

	//--- destination data path stream ports
	SNE_EVENT_STREAM.dst evt_dp_stream_filter_dst,

	//--- source data path stream ports
	SNE_EVENT_STREAM.src evt_dp_stream_filter_src 
	
);

logic in_cropped_region_s;
logic in_top_bottom_range_s;
logic in_left_right_range_s;

logic [31:0]  cfg_filter_ubound_i ;
logic [31:0]  cfg_filter_lbound_i ;
logic [31:0]  cfg_filter_main_i   ;  

assign cfg_filter_ubound_i = config_i.reg2hw.cfg_filter_ubound_i[GROUP_ID];
assign cfg_filter_lbound_i = config_i.reg2hw.cfg_filter_lbound_i[GROUP_ID];
assign cfg_filter_main_i   = config_i.reg2hw.cfg_filter_main_i[GROUP_ID].filter_en;

//--- 2D input cropping
assign in_left_right_range_s = (evt_dp_stream_filter_dst.evt.dp_data.xid >= config_i.reg2hw.cfg_filter_lbound_i[GROUP_ID].xid) && (evt_dp_stream_filter_dst.evt.dp_data.xid <= config_i.reg2hw.cfg_filter_ubound_i[GROUP_ID].xid);
assign in_top_bottom_range_s = (evt_dp_stream_filter_dst.evt.dp_data.yid >= config_i.reg2hw.cfg_filter_lbound_i[GROUP_ID].yid) && (evt_dp_stream_filter_dst.evt.dp_data.yid <= config_i.reg2hw.cfg_filter_ubound_i[GROUP_ID].yid);

assign in_cropped_region_s   = in_left_right_range_s && in_top_bottom_range_s;
assign group_enable_o        = in_cropped_region_s || force_en_i;

always_comb begin : proc_ID_filter
	if(cfg_filter_main_i[0]) begin
		if(in_cropped_region_s | force_en_i) begin
			// let the event flow (apply modulo 8 operation to addresses)
			`SNE_DP_STREAM_PROPAGATE_DST_SRC(evt_dp_stream_filter_src,evt_dp_stream_filter_dst)
		end else begin
			// consume the event without propagating it
			`SNE_DP_STREAM_ABSORBE_DST_SRC(evt_dp_stream_filter_src,evt_dp_stream_filter_dst)
		end
	end else begin
		// consume the event without propagating it
		`SNE_DP_STREAM_ABSORBE_DST_SRC(evt_dp_stream_filter_src,evt_dp_stream_filter_dst)
	end
end

endmodule