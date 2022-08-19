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
module evt_time_inserter //to be placed at the streamer for global time reference
import sne_evt_stream_pkg::time_t;
import sne_evt_stream_pkg::timestamp_t;
import sne_evt_stream_pkg::EVT_TIME;
(
	input logic                                 clk_i,
	input logic                                rst_ni,
	input logic                              enable_i,//enable during engine operations.
	SNE_EVENT_STREAM.dst 		evt_time_stream_dst,
	SNE_EVENT_STREAM.src 		evt_time_stream_src
);

typedef enum logic [0:0] {
	INIT,
	TIME_INSERT
}state_position_t;
state_position_t state_d, state_q;

logic time_not_contiguous, valid_transaction, repeated_time;
logic handle_zero_status_d,handle_zero_status_q;

timestamp_t curr_time_d, curr_time_q; 
timestamp_t next_time_d, next_time_q; 
time_t evt;
assign evt.operation = EVT_TIME;
assign evt.value = curr_time_q+1;
assign time_not_contiguous = (evt_time_stream_dst.evt.timestamp.operation==EVT_TIME) & (evt_time_stream_dst.evt.timestamp.value>curr_time_q+1) & (evt_time_stream_dst.valid);

always_comb begin
	state_d = state_q;
	next_time_d = next_time_q;
	curr_time_d = curr_time_q;

	if((evt_time_stream_dst.evt.timestamp.operation==EVT_TIME) & (evt_time_stream_dst.evt.timestamp.value==0) & (evt_time_stream_dst.valid) & (~(handle_zero_status_q))) begin 
		repeated_time = 0;
		if(evt_time_stream_src.ready)
			handle_zero_status_d = 1;
		else 
			handle_zero_status_d = handle_zero_status_q;
	end else begin
		repeated_time = (evt_time_stream_dst.evt.timestamp.operation==EVT_TIME) & (evt_time_stream_dst.evt.timestamp.value==curr_time_q) & (evt_time_stream_dst.valid);
		handle_zero_status_d = handle_zero_status_q;
	end

	case(state_q)
		INIT : begin
			if(time_not_contiguous & enable_i) begin 
				state_d = TIME_INSERT;
				`C_SNE_EVENT_STREAM_PAUSE_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
				next_time_d = evt_time_stream_dst.evt.timestamp.value;
			end else if(repeated_time & enable_i) begin 
				`C_SNE_EVENT_STREAM_ABSORBE_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
				state_d = INIT;
			end else begin 
				state_d = INIT;
				`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
				if((evt_time_stream_dst.evt.timestamp.operation==EVT_TIME) & evt_time_stream_dst.valid & evt_time_stream_dst.ready)
					curr_time_d = evt_time_stream_dst.evt.timestamp.value;
			end 
			valid_transaction = evt_time_stream_src.ready;
		end 
		TIME_INSERT : begin 
			if(curr_time_q+1 <= next_time_q) begin 
				state_d = TIME_INSERT;
				valid_transaction = evt_time_stream_src.ready;
				curr_time_d = curr_time_q + valid_transaction;
				`C_SNE_EVENT_STREAM_CHANGE_DATA_SRC(evt_time_stream_src, evt);
				evt_time_stream_dst.ready = 1'b0;
			end else begin 
				state_d = INIT;
				`C_SNE_EVENT_STREAM_ABSORBE_DST_SRC(evt_time_stream_src,evt_time_stream_dst);
			end
		end
		default : state_d = INIT;
	endcase
end
always_ff @(posedge clk_i or negedge rst_ni) begin : proc_state_q
	if(~rst_ni) begin
		state_q <= INIT;
		next_time_q <= 0;
		curr_time_q <= 0;
		handle_zero_status_q <= 0;
	end else begin
		state_q <= state_d;
		next_time_q <= next_time_d;
		curr_time_q <= curr_time_d;
		handle_zero_status_q <= handle_zero_status_d;
	end
end
endmodule
