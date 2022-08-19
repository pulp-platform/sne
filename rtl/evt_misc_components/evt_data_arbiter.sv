/* 
 * Arpan Suravi Prasad <prasadar@student.ethz.ch>
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

/*
This module can be enabled using module_enable_i in the FC layer. 
This requires the following:
-----------------------------
Engine header (length=1)
Time  Event 
Weight header
-----------------------------
WEIGHTS
The number of slices that will share the weight is given by the enable_i signal. 
enable_status_q is used to track the slice enabled for the weight sharing. This is bit shifted and
 wrap around according to the enable_i signal with the help enable_stored_q which stores the history of all the enable_status_q. 
 enable_status_q is set to 1 as soon as the first transaction of the weight shared to all the slices. 
 Then the end of the weight sharing is done when the count for the slice_transaction reaches the threshold and enable_stored_q matches with enable_i

*/

`include "evt_stream_macros.svh"
module evt_data_arbiter 
import sne_evt_stream_pkg::uevent_t ;
import sne_evt_stream_pkg::DST_MEMORY ;
import sne_evt_stream_pkg::DST_ENGINE ;
import sne_evt_stream_pkg::EVT_TIME ;
import sne_evt_stream_pkg::EVT_SPIKE ;
import sne_evt_stream_pkg::EVT_SYNCH ;
import sne_evt_stream_pkg::EVT_WIPE ;
import sne_evt_stream_pkg::EOP ;
#(
	parameter SLICE_NUMBER = 8,
	parameter THRESHOLD = 64
)(
	input logic clk_i,
	input logic rst_ni,
	input logic [(SLICE_NUMBER)-1:0] enable_i,//assumption consecutive slices are enabled.
	input logic module_enable_i              ,
	// input uevent_t evt_header,
	// input uevent_t evt_time  ,
	SNE_EVENT_STREAM.dst 		evt_weight_stream_dst,
	SNE_EVENT_STREAM.src 		evt_weight_stream_src[SLICE_NUMBER-1:0]
);


logic [SLICE_NUMBER-1:0        ] valid_mask;
logic [(SLICE_NUMBER)-1:0] enable_status_d, enable_status_q;// current slice enable
logic [(SLICE_NUMBER)-1:0] enable_stored_d, enable_stored_q;// all the slices those were enabled

logic [$clog2(THRESHOLD)+1-1:0             ] slice_transaction_count_d, slice_transaction_count_q;
logic [$clog2(THRESHOLD*SLICE_NUMBER)+1-1:0] event_transaction_count_d, event_transaction_count_q;

logic arbitration_finished_d, arbitration_finished_q, valid_transaction;

typedef enum logic [2:0] {
	RESET,
	SEND_ENGINE_HEADER,
	WAIT_FOR_SPIKE_EVT,
	SEND_TIME_BARRIER,
	SEND_ENGINE_BARRIER,
	SEND_WEIGHT_HEADER,
	ARBITRATE
	// END
}state_position_t;

state_position_t state_d, state_q;

SNE_EVENT_STREAM evt_weight_stream_tmp_dst (.clk_i(clk_i));

evt_stream_dynamic_fork #(.N_OUP(SLICE_NUMBER)) i_evt_stream_dynamic_fork (

	.clk_i         (clk_i),
	.rst_ni        (rst_ni),
	.sel_i         (valid_mask),
	.sel_valid_i   (1'b1),
	.sel_ready_o   (),
	.evt_stream_dst(evt_weight_stream_tmp_dst),
	.evt_stream_src(evt_weight_stream_src)
);
logic spike_evt ;

assign spike_evt = evt_weight_stream_dst.valid & module_enable_i & (evt_weight_stream_dst.evt.spike.operation == EVT_SPIKE);

always_comb begin
	state_d = state_q;
	case(state_q) 
		RESET: begin 
			if(evt_weight_stream_dst.valid & module_enable_i) begin 
				state_d = SEND_ENGINE_HEADER;
			end else begin 
				state_d = RESET;
			end 
		end
		SEND_ENGINE_HEADER: begin 
			if(valid_transaction) begin
				state_d = WAIT_FOR_SPIKE_EVT;
			end else begin 
				state_d = SEND_ENGINE_HEADER;
			end 
		end 
		WAIT_FOR_SPIKE_EVT : begin
			if(spike_evt) begin
				state_d = SEND_TIME_BARRIER; 
			end else begin 
				state_d = WAIT_FOR_SPIKE_EVT;
			end  
		end
		SEND_TIME_BARRIER : begin
			if(valid_transaction) begin 
				state_d = SEND_ENGINE_BARRIER;
			end else begin 
				state_d = SEND_TIME_BARRIER;
			end 
		end
		SEND_ENGINE_BARRIER : begin
			if(valid_transaction) begin 
				state_d = SEND_WEIGHT_HEADER;
			end else begin 
				state_d = SEND_ENGINE_BARRIER;
			end 
		end
		SEND_WEIGHT_HEADER : begin
			if(valid_transaction) begin 
				state_d = ARBITRATE;
			end else begin 
				state_d = SEND_WEIGHT_HEADER;
			end 
		end
		ARBITRATE : begin 
			if(arbitration_finished_q) begin
				state_d = RESET; 
			end else begin
				state_d = ARBITRATE; 
			end
		end
		default : state_d = RESET;
	endcase 
end

// assign enable_stored_d = (enable_status_q) | enable_stored_q;
assign valid_transaction = evt_weight_stream_tmp_dst.valid & evt_weight_stream_tmp_dst.ready;

always_comb begin

	enable_stored_d = enable_stored_q;
	enable_status_d = enable_status_q;
	event_transaction_count_d = event_transaction_count_q;
	slice_transaction_count_d = slice_transaction_count_q;
	arbitration_finished_d    = 0;
	valid_mask                = enable_i;
	`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_weight_stream_tmp_dst,evt_weight_stream_dst);
	case(state_q) 
		
		RESET : begin 
			enable_status_d = 0;
			valid_mask      = enable_i;
			if(module_enable_i) begin
				`C_SNE_EVENT_STREAM_PAUSE_DST_SRC(evt_weight_stream_tmp_dst,evt_weight_stream_dst);
			end else begin 
				`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_weight_stream_tmp_dst,evt_weight_stream_dst);
			end
			slice_transaction_count_d = 0;
			slice_transaction_count_d = 0;
		end  
		SEND_ENGINE_HEADER : begin 
			valid_mask      = enable_i;
			enable_status_d = 1;
			evt_weight_stream_tmp_dst.evt.header.option = 0;
			evt_weight_stream_tmp_dst.evt.header.gdst = DST_ENGINE;
			evt_weight_stream_tmp_dst.evt.header.length = 16'hFFFF;
			evt_weight_stream_tmp_dst.valid = 1'b1;
			evt_weight_stream_dst.ready = 1'b0; 
		end 
		WAIT_FOR_SPIKE_EVT : begin 
			enable_status_d = 1;
			if(spike_evt)
				valid_mask = 0;
			else 
				valid_mask = enable_i;
			`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_weight_stream_tmp_dst,evt_weight_stream_dst);
		end
		SEND_TIME_BARRIER : begin 
			valid_mask      = enable_i;
			enable_status_d = 1;
			evt_weight_stream_tmp_dst.evt.spike.operation = EVT_SYNCH;
			evt_weight_stream_tmp_dst.evt.spike.unused = 0;
			evt_weight_stream_tmp_dst.evt.spike.cid = 0;
			evt_weight_stream_tmp_dst.evt.spike.yid = 0;
			evt_weight_stream_tmp_dst.evt.spike.xid = 0;
			evt_weight_stream_tmp_dst.valid = 1'b1;
			evt_weight_stream_dst.ready = 1'b0; 
		end
		SEND_ENGINE_BARRIER : begin
			valid_mask      = enable_i;
			enable_status_d = 1;
			evt_weight_stream_tmp_dst.evt.spike.operation = EOP;
			evt_weight_stream_tmp_dst.valid = 1'b1;
			evt_weight_stream_dst.ready = 1'b0; 
		end

		SEND_WEIGHT_HEADER : begin 
			valid_mask      = enable_i;
			enable_status_d = 1;
			evt_weight_stream_tmp_dst.evt.header.option = 0;
			evt_weight_stream_tmp_dst.evt.header.gdst   = DST_MEMORY;
			evt_weight_stream_tmp_dst.evt.header.ldst   = 0;
			evt_weight_stream_tmp_dst.evt.header.length = 128;
			evt_weight_stream_tmp_dst.valid = 1'b1;
			evt_weight_stream_dst.ready = 1'b0;	
		end

		ARBITRATE : begin
			
			enable_stored_d = (enable_status_q) | enable_stored_q;
			valid_mask = enable_status_q;
			slice_transaction_count_d = (valid_mask==1) ?  slice_transaction_count_q + valid_transaction : slice_transaction_count_q;
			
			if(valid_transaction) begin
				event_transaction_count_d = event_transaction_count_q+1; 
			end

			if(event_transaction_count_q[0] & valid_transaction) begin
				if(enable_stored_q==enable_i) begin 
					enable_status_d = 1;
					enable_stored_d = 1;
					arbitration_finished_d = (slice_transaction_count_q>=THRESHOLD-1);// to take into account only if one slice is enabled. 
				end else begin 
					enable_status_d = enable_status_q << 1;
					enable_stored_d = (enable_status_q) | enable_stored_q;
				end
			end
			if(arbitration_finished_q) begin
				`C_SNE_EVENT_STREAM_PAUSE_DST_SRC(evt_weight_stream_tmp_dst,evt_weight_stream_dst);
			end else begin
				`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_weight_stream_tmp_dst,evt_weight_stream_dst);
			end
		end

	endcase 
end

always_ff @(posedge clk_i or negedge rst_ni) begin : proc_enable_status_q
	if(~rst_ni) begin
		state_q         <= RESET;
		enable_status_q <= 0;
		enable_stored_q <= 0;
		event_transaction_count_q <= 0;
		slice_transaction_count_q <= 0;
		arbitration_finished_q    <= 0;
	end else begin
		state_q         <= state_d;
		enable_status_q <= enable_status_d;
		enable_stored_q <= enable_stored_d;
		event_transaction_count_q <= event_transaction_count_d;
		slice_transaction_count_q <= slice_transaction_count_d;
		arbitration_finished_q    <= arbitration_finished_d;
	end
end

endmodule