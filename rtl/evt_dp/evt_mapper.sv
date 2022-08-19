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
module evt_mapper 
import sne_evt_stream_pkg::config_engine_t;
import sne_evt_stream_pkg::uevent_t;
import sne_evt_stream_pkg::spike_t;
import sne_evt_stream_pkg::operation_t;
import sne_evt_stream_pkg::barrier_t;
import sne_evt_stream_pkg::EVT_TIME;
import sne_evt_stream_pkg::NEO;
import sne_evt_stream_pkg::CID_WIDTH;

#(

	parameter DP_GROUP = 16,
	parameter ENGINE_ID = 0

)(
	input config_engine_t config_i,
	input logic engine_rst_ni,
	input logic engine_clk_i, 
	input logic init_sequencer_i,
	SNE_EVENT_STREAM.dst evt_dp_memory_mapper_dst[DP_GROUP-1:0],
	SNE_EVENT_STREAM.src evt_dp_stream_mapper_src[DP_GROUP-1:0],
	SNE_EVENT_STREAM.dst evt_stream_time_dst
	
	
);

typedef enum logic [1:0] {
	INIT,
	RUN,
	EXECUTE
}state_position_t;
state_position_t state_d, state_q;
logic [DP_GROUP-1:0] ready_dst, all_ones;
logic [DP_GROUP-1:0] ready_dst_q;
logic [DP_GROUP-1:0][CID_WIDTH-1:0] cid;

assign all_ones = '1;

for(genvar i=0; i<DP_GROUP; i++) begin 
	always_comb begin 
		ready_dst[i] = evt_dp_stream_mapper_src[i].ready;
		evt_dp_stream_mapper_src[i].evt.synch.barrier_id= 0;
		evt_dp_stream_mapper_src[i].evt.synch.operation = NEO;
		evt_dp_stream_mapper_src[i].valid               = 0;
		evt_dp_memory_mapper_dst[i].ready               = 0;
		case(state_q)
			INIT : begin 
				evt_dp_stream_mapper_src[i].valid = evt_dp_memory_mapper_dst[i].valid;
				evt_dp_memory_mapper_dst[i].ready = evt_dp_stream_mapper_src[i].ready;
				evt_dp_stream_mapper_src[i].evt.spike.yid   = evt_dp_memory_mapper_dst[i].evt.spike.yid + config_i.reg2hw.cfg_filter_lbound_i[ENGINE_ID*DP_GROUP+i].yid;
				evt_dp_stream_mapper_src[i].evt.spike.xid   = evt_dp_memory_mapper_dst[i].evt.spike.xid + config_i.reg2hw.cfg_filter_lbound_i[ENGINE_ID*DP_GROUP+i].xid;
				evt_dp_stream_mapper_src[i].evt.spike.cid   = cid[i];
				evt_dp_stream_mapper_src[i].evt.spike.operation   = evt_dp_memory_mapper_dst[i].evt.spike.operation;
				evt_dp_stream_mapper_src[i].evt.spike.unused   = evt_dp_memory_mapper_dst[i].evt.spike.unused;
			end
			RUN : begin
				evt_dp_stream_mapper_src[i].evt.synch.barrier_id=evt_stream_time_dst.evt.timestamp.value;
				evt_dp_stream_mapper_src[i].evt.synch.operation = EVT_TIME;
				evt_dp_stream_mapper_src[i].valid               = 0;
				evt_dp_memory_mapper_dst[i].ready               = 0;
			end
			EXECUTE : begin 
				evt_dp_stream_mapper_src[i].evt.synch.barrier_id=evt_stream_time_dst.evt.timestamp.value;
				evt_dp_stream_mapper_src[i].evt.synch.operation = EVT_TIME;
				evt_dp_stream_mapper_src[i].valid               = 1'b1;
				evt_dp_memory_mapper_dst[i].ready               = 0;
			end 

		endcase
	end
end
for(genvar i=0; i<4; i++) begin 
	assign cid[i   ] = config_i.reg2hw.cfg_cid_i[ENGINE_ID].cid_3_0;
	assign cid[i+4 ] = config_i.reg2hw.cfg_cid_i[ENGINE_ID].cid_7_4;
	assign cid[i+8 ] = config_i.reg2hw.cfg_cid_i[ENGINE_ID].cid_11_8;
	assign cid[i+12] = config_i.reg2hw.cfg_cid_i[ENGINE_ID].cid_15_12;
end

always_comb begin 
	state_d = state_q;
	evt_stream_time_dst.ready = 1'b0;
	case(state_q)
		INIT : begin
			if(evt_stream_time_dst.valid & (ready_dst==all_ones) & init_sequencer_i) begin
				state_d = RUN; 
			end else begin 
				state_d = INIT;
			end 
			evt_stream_time_dst.ready = 0;
		end 
		RUN : begin 
			if(ready_dst==all_ones) begin 
				state_d = EXECUTE;
				evt_stream_time_dst.ready = 1'b0;
			end else begin 
				state_d = RUN;
				evt_stream_time_dst.ready = 1'b0;
			end
		end
		EXECUTE : begin 
			state_d = INIT;
			evt_stream_time_dst.ready = 1'b1;
		end 
		default : state_d = INIT;
	endcase
end

always_ff @(posedge engine_clk_i or negedge engine_rst_ni) begin : proc_
	if(~engine_rst_ni) begin
		state_q <= INIT;
	end else begin
		state_q <= state_d;
	end
end
endmodule