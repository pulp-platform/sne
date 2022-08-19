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
module evt_spike_filter 

import sne_evt_stream_pkg::time_t;
import sne_evt_stream_pkg::spike_t;
import sne_evt_stream_pkg::timestamp_t;
import sne_evt_stream_pkg::EVT_TIME;
import sne_evt_stream_pkg::EVT_SPIKE;
import sne_evt_stream_pkg::EVT_UPDATE;
import sne_evt_stream_pkg::EVENT_WIDTH;
import sne_evt_stream_pkg::OP_WIDTH;
import sne_evt_stream_pkg::config_engine_t;

#(
	parameter ENGINE_ID    = 0,
	parameter DP_GROUP     = 16
)(
	
	input logic                     clk_i,
	input logic                     rst_ni,
	input config_engine_t           config_i,
	input logic                     enable_i,

	SNE_EVENT_STREAM.dst 			evt_time_stream_dst,
	SNE_EVENT_STREAM.src 			evt_time_stream_src

);

typedef enum logic [1:0] {
	INIT,
	TIME_INSERT,
	NEURON_UPDATE_INSERT,
	REFRESH_TIME
}state_position_t;
state_position_t state_d, state_q;


logic       in_left_right_range_s, in_top_bottom_range_s;
logic       spike_in_receptive, curr_spike_valid;
logic       handle_zero_status_d,handle_zero_status_q;

logic [7:0] group_id_low_x , group_id_low_y;
logic [7:0] group_id_high_x, group_id_high_y;

assign group_id_low_x = ENGINE_ID*DP_GROUP + config_i.reg2hw.cfg_slice_i[ENGINE_ID].group_id_low_x;
assign group_id_low_y = ENGINE_ID*DP_GROUP + config_i.reg2hw.cfg_slice_i[ENGINE_ID].group_id_low_y;
assign group_id_high_x= ENGINE_ID*DP_GROUP + config_i.reg2hw.cfg_slice_i[ENGINE_ID].group_id_high_x;
assign group_id_high_y= ENGINE_ID*DP_GROUP + config_i.reg2hw.cfg_slice_i[ENGINE_ID].group_id_high_y;

assign curr_spike_valid= evt_time_stream_dst.valid & (evt_time_stream_dst.evt.spike.operation==EVT_SPIKE);

assign in_left_right_range_s = (evt_time_stream_dst.evt.spike.xid >= config_i.reg2hw.cfg_filter_lbound_i[group_id_low_x].xid) && (evt_time_stream_dst.evt.spike.xid <= config_i.reg2hw.cfg_filter_ubound_i[group_id_high_x].xid);
assign in_top_bottom_range_s = (evt_time_stream_dst.evt.spike.yid >= config_i.reg2hw.cfg_filter_lbound_i[group_id_low_y].yid) && (evt_time_stream_dst.evt.spike.yid <= config_i.reg2hw.cfg_filter_ubound_i[group_id_high_y].yid);
assign spike_in_receptive    = in_left_right_range_s & in_top_bottom_range_s;


always_comb begin
	if(enable_i) begin
		if(spike_in_receptive) begin
			`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_time_stream_src,evt_time_stream_dst); 
		end else begin
			`C_SNE_EVENT_STREAM_ABSORBE_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
		end
	end else begin 
		`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
	end 
end
endmodule