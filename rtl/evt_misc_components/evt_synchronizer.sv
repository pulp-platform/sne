/* 
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
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
`include "evt_stream_macros.svh"
module evt_synchronizer #(

	parameter type      DATA_T = logic,   // Vivado requires a default value for type parameters.
	parameter           N = -1

	)(

	input  logic         clk_i                      ,  
	input  logic         rst_ni                     ,  

	input  logic [N-1:0] fwd_barrier_i              ,
	input  logic [N-1:0] synch_en_i                 ,  

	SNE_EVENT_STREAM.dst evt_stream_dst[N-1:0] , // incoming stream
	SNE_EVENT_STREAM.src evt_stream_src[N-1:0]   // outgoing stream
	
);

import sne_evt_stream_pkg::EVT_TIME; 

logic [N-1:0] barrier;
logic [N-1:0] status_d,status_q;


typedef enum logic [0:0] {
	NO_BARRIER,
	// SYNCH,
	FWD_BARRIER
	// DONE
}state_position_t;
state_position_t state_d, state_q;

for (genvar i = 0; i < N; i++) begin
	
	assign barrier[i] = (evt_stream_dst[i].evt.synch.operation == EVT_TIME) && evt_stream_dst[i].valid; // check the presence of the barrier on the same cycle it arrives
	always_comb begin 
		status_d[i] = status_q[i];
		case(state_q)
			NO_BARRIER: begin
				if(~barrier[i]||(~synch_en_i[i])) begin//no barrier or synchronization not necessary on the channel. 
					`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_src[i],evt_stream_dst[i]);
				end  else begin 
					`C_SNE_EVENT_STREAM_PAUSE_DST_SRC(evt_stream_src[i],evt_stream_dst[i]);
				end 
				status_d[i] = 0;
			end 
			FWD_BARRIER : begin 
				if(status_q[i]) begin
					`C_SNE_EVENT_STREAM_PAUSE_DST_SRC(evt_stream_src[i],evt_stream_dst[i]); 
					status_d[i] = 1'b1 & synch_en_i[i]; 
				end else begin
					status_d[i] = evt_stream_src[i].ready; 
					if(fwd_barrier_i[i]) begin 
						`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_src[i],evt_stream_dst[i]);
					end else if(~synch_en_i[i])begin 
						`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_src[i],evt_stream_dst[i]);
						status_d[i] = 1'b0;
					end else begin 
						`C_SNE_EVENT_STREAM_ABSORBE_DST_SRC(evt_stream_src[i],evt_stream_dst[i]);
						status_d[i] = 1'b1;
					end 
				end 
			end 
		endcase
	end 	
end 


always_comb begin
	state_d = state_q;
	case(state_q)
		NO_BARRIER : begin
			if((barrier != 0) & (synch_en_i !=0) & (barrier == synch_en_i)) begin//there is a barrier and also needs synchronization 
				state_d = FWD_BARRIER; 
			end else begin 
				state_d = NO_BARRIER;
			end 
		end 
		FWD_BARRIER : begin 
			if((status_q & fwd_barrier_i) == fwd_barrier_i) begin
				state_d = NO_BARRIER; 
			end else begin 
				state_d = FWD_BARRIER;
			end
		end
		default : begin 
			state_d = NO_BARRIER;
		end
	endcase 
end


always_ff @(posedge clk_i or negedge rst_ni) begin : proc_synch
	if(~rst_ni) begin
		status_q <= 0;
		state_q  <= NO_BARRIER;
	end else begin
		status_q <= status_d;
		state_q  <= state_d;
	end
end


endmodule