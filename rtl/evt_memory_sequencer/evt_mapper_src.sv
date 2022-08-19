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
module evt_mapper_src
import sne_evt_stream_pkg::spike_t;
 #(parameter DP_GROUP=16)
	
(
	input 	logic 						engine_clk_i,
	input 	logic 						engine_rst_ni,
	output  logic                      	spike_grant_o,
	input   logic 	[DP_GROUP-1:0]      evt_valid,
	input   logic 	[DP_GROUP-1:0]      evt_ready,
	input   spike_t [DP_GROUP-1:0]      evt_spike,
	SNE_EVENT_STREAM.src 	 evt_fifo_stream_src[DP_GROUP-1:0]

);
spike_t [DP_GROUP-1:0] evt_spike_d,evt_spike_q;
logic   [DP_GROUP-1:0] evt_valid_d,evt_valid_q;

logic waiting, all_ready;

typedef enum logic [1:0] {
		RUN,
		PAUSE,
		RESUME,
		READY
	}state_position_t;

state_position_t state_d, state_q;

spike_t [DP_GROUP-1:0] event_src;
logic 	[DP_GROUP-1:0] valid_src, ready_dst ;
assign spike_grant_o = (ready_dst=={DP_GROUP{1'b1}});
assign all_ready = (evt_ready=={DP_GROUP{1'b1}});
always_comb begin 
	case(state_q)
		RUN : begin
			if(all_ready)
				state_d = RUN;
			else 
				state_d = PAUSE; 
		end  
		PAUSE : begin 
			if(all_ready)
				state_d = RESUME;
			else 
				state_d = PAUSE;
		end
		RESUME : begin
			if(all_ready)
				state_d = RUN;
			else 
				state_d = PAUSE; 
		end
		READY : begin
			if(all_ready)
				state_d = RUN;
			else 
				state_d = PAUSE; 
		end
	endcase
end

always_comb begin 
	case(state_q)
		RUN : begin
			valid_src = evt_valid;
			event_src = evt_spike;
			ready_dst = evt_ready;
			waiting = 0;
		end  
		PAUSE : begin 
			valid_src = evt_valid_q;
			event_src = evt_spike_q;
			ready_dst = 0;
			waiting   = 1;
		end
		RESUME : begin
			valid_src = 0;
			event_src = 0;
			ready_dst = 0;
			waiting   = 0;
		end
		READY : begin
			valid_src = 0;
			event_src = 0;
			ready_dst = '1;
			waiting   = 0;
		end
	endcase
end

always_comb begin
	if(waiting) begin
		evt_spike_d = evt_spike_q;
		evt_valid_d = evt_valid_q & (~(evt_ready)); 
	end else begin 
		evt_spike_d = evt_spike;
		evt_valid_d = evt_valid & (~(evt_ready));
	end 
end

always_ff @(posedge engine_clk_i or negedge engine_rst_ni) begin : proc_
	if(~engine_rst_ni) begin
		evt_spike_q <= 0;
		evt_valid_q <= 0;
		state_q     <= RUN;
	end else begin
		evt_spike_q <= evt_spike_d;
		evt_valid_q <= evt_valid_d;
		state_q     <= state_d;
	end
end

for(genvar i =0; i<DP_GROUP; i++) begin
	assign  evt_fifo_stream_src[i].evt.spike = event_src[i];
	assign  evt_fifo_stream_src[i].valid     = valid_src[i];
end


endmodule : evt_mapper_src