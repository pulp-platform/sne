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
module evt_refresh_insert 
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
	parameter REFRESH_RATE = 256, //time beyond 256 cycle is refreshed  send 8 then it calculates 2^8
 	localparam BIT_WIDTH   = $clog2(REFRESH_RATE)
)(
	input logic                     clk_i,
	input logic                     rst_ni,
	// input config_engine_t           config_i,
	input logic                     enable_i,

	SNE_EVENT_STREAM.dst 			evt_time_stream_dst,
	SNE_EVENT_STREAM.src 			evt_time_stream_src
);

typedef enum logic [1:0] {
	INIT,
	REFRESH_INSERT,
	ALLOW_NEW_EVT
}state_position_t;
state_position_t state_d, state_q;

logic       time_all_zeros;
spike_t     update_evt;

assign time_all_zeros = (evt_time_stream_dst.valid & (evt_time_stream_dst.evt.timestamp.operation==EVT_TIME) & (evt_time_stream_dst.evt.timestamp.value[7:0]==0)) & (evt_time_stream_dst.evt.timestamp.value[27:8]!=0);
assign update_evt = {EVT_UPDATE,{(EVENT_WIDTH-OP_WIDTH){1'b0}}}; 

always_comb begin
  state_d = state_q;
  `C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
  case(state_q)
  	INIT : begin 
  	  if(time_all_zeros & enable_i) begin 
  	  	`C_SNE_EVENT_STREAM_PAUSE_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
  	  	state_d = REFRESH_INSERT;
  	  end else begin 
  	  	`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
  	  	state_d = INIT;
  	  end
  	end 
  	REFRESH_INSERT : begin 
  		evt_time_stream_src.valid = 1'b1;
  		evt_time_stream_src.evt   = update_evt;
      evt_time_stream_dst.ready = 1'b0;
  	  if(evt_time_stream_src.ready) begin
  	  	state_d = ALLOW_NEW_EVT;
  	  end else begin 
  	  	state_d = REFRESH_INSERT;
  	  end 
  	end
  	ALLOW_NEW_EVT : begin 
  		`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
  		if(evt_time_stream_src.ready & evt_time_stream_src.valid)
  			state_d = INIT;
  		else 
  			state_d = ALLOW_NEW_EVT;
  	end 
  	default : state_d = INIT;
  endcase
end 
always_ff @(posedge clk_i or negedge rst_ni) begin : proc_state_q
  if(~rst_ni) begin
    state_q <= INIT;
  end else begin
    state_q <= state_d;
  end
end
endmodule : evt_refresh_insert