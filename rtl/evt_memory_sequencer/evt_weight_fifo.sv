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
 `include "evt_stream_macros.svh"
module evt_weight_fifo 	
	import sne_evt_stream_pkg::DST_ENGINE ;
	import sne_evt_stream_pkg::DST_MEMORY ;
	import sne_evt_stream_pkg::WEIGHT_WIDTH ;
	import sne_evt_stream_pkg::uevent_t ;
	import sne_evt_stream_pkg::EVT_SYNCH; 

	#(

	parameter type T            = sne_evt_stream_pkg::uevent_t,
	parameter DEC_EL_FIFO_DEPTH = 10 ,
	parameter DP_GROUP          = 16,
	parameter ADDR_WIDTH        = 7,
	parameter THRESHOLD         = 64//5

	)(
		
	input  logic   bus_clk_i ,
	input  logic   bus_rst_ni,
	input  logic   init_i    ,

	input  logic   engine_clk_i,
	input  logic   engine_rst_ni, 
	input  uevent_t spike_evt_i,
  //Synch with time 
	input  logic   time_stable_i,
	output logic   init_sequencer_o,
 //
	input  logic   spike_grant_i,

	// output logic   weight_req_o,
	output logic   done_o,
	output logic   ready_o,

	output logic [DP_GROUP-1:0][ADDR_WIDTH-2:0] group_rd_addr_o,
	output logic [DP_GROUP-1:0][ADDR_WIDTH-2:0] group_wr_addr_o,
	output logic [DP_GROUP-1:0]				    group_rd_en_o,
	output logic [DP_GROUP-1:0] 	 			group_wr_en_o,
	output logic [DP_GROUP-1:0][WEIGHT_WIDTH-1:0] group_weight_o,
	SNE_EVENT_STREAM.dst    evt_stream_memory_dst,
	SNE_EVENT_STREAM.dst    evt_stream_time_dst
);
SNE_EVENT_STREAM evt_stream_memory_fork_src[1:0](.clk_i(bus_clk_i));
SNE_EVENT_STREAM evt_memory_weight_fifo[1:0]	(.clk_i(engine_clk_i));

typedef enum logic [2:0] {
	INIT,
	RESUME,
	RUN,
	STOP,
	WAIT
}state_position_t;

logic  status_d  , status_q  ;
logic  wr_en_d   , wr_en_q   ;
logic  rd_en_d   , rd_en_q   ;
logic  ready_d   , ready_q   ;//ready signal for receiving ip spikes
logic  done_d    , done_q    ;

logic  [ADDR_WIDTH-1:0] wr_addr_d, wr_addr_q;
logic  [ADDR_WIDTH-1:0] rd_addr_d, rd_addr_q;
logic  [DP_GROUP*WEIGHT_WIDTH-1:0] weight_d, weight_q;

assign ready_o = ready_q;


generate 
	genvar i;
	for(i=0; i<DP_GROUP; i++) begin
		always_comb begin
			group_rd_addr_o[i] = rd_addr_q;
			group_wr_addr_o[i] = wr_addr_q;
			group_rd_en_o[i]   = rd_en_q;
			group_wr_en_o[i]   = wr_en_q; 
			group_weight_o[i]  = weight_q[(i+1)*WEIGHT_WIDTH-1:i*WEIGHT_WIDTH];
		end
	end
endgenerate

/////////////////////////////////IP PORT ///////////////////////////////////////////////////////////////

evt_cdc_fifo #(

		.T    ( T                  ),
		.DEPTH( DEC_EL_FIFO_DEPTH  )

	) i_evt_cdc_memory_fifo_left (

		.src_clk_i ( engine_clk_i                 ),
		.src_rst_ni( engine_rst_ni                ),
		.src_stream( evt_memory_weight_fifo[1]    ),

		.dst_clk_i ( bus_clk_i                    ),
		.dst_rst_ni( bus_rst_ni                   ),
		.dst_stream( evt_stream_memory_fork_src[1])

);

evt_cdc_fifo #(

		.T    ( T                  ),
		.DEPTH( DEC_EL_FIFO_DEPTH  )

	) i_evt_cdc_memory_fifo_right (

		.src_clk_i ( engine_clk_i                 ),
		.src_rst_ni( engine_rst_ni                ),
		.src_stream( evt_memory_weight_fifo[0]    ),

		.dst_clk_i ( bus_clk_i                    ),
		.dst_rst_ni( bus_rst_ni                   ),
		.dst_stream( evt_stream_memory_fork_src[0])

);

state_position_t state_ip_port_d, state_ip_port_q;
logic ready_ip_port_d, ready_ip_port_q;
logic [$clog2(2*THRESHOLD):0] count_ip_port_d, count_ip_port_q;

always_comb begin : ip_port_state_transition 
	state_ip_port_d = state_ip_port_q;
	case(state_ip_port_q) 
		INIT : begin
			if(evt_stream_memory_dst.valid) begin
				state_ip_port_d = RESUME;
			end else begin 
				state_ip_port_d = INIT;
			end 
		end
		RESUME : begin
			state_ip_port_d = RUN;
		end
		RUN : begin 
			if(count_ip_port_q==(2*THRESHOLD+1)) begin 
				state_ip_port_d = INIT;
			end else begin 
				state_ip_port_d = RUN;
			end
		end
		default : begin 
			state_ip_port_d = INIT;
		end
	endcase // state_ip_q
end : ip_port_state_transition

always_comb begin : ip_port_control_signals
	count_ip_port_d = count_ip_port_q;
	status_d = status_q;
	case(state_ip_port_q) 
		INIT : begin
			ready_ip_port_d = 1'b0;
			status_d        = 1'b0;
			count_ip_port_d = '0;
		end 
		RESUME : begin
			ready_ip_port_d = 1'b1; 
		end 
		RUN : begin 
			ready_ip_port_d = 1'b1;
			if(evt_stream_memory_dst.ready & evt_stream_memory_dst.valid) begin
				status_d = ~status_q; 
				count_ip_port_d = count_ip_port_q + 1;
			end else begin 
				status_d = status_q;
			end
		end
		default: begin 
			
			ready_ip_port_d = 1'b0;
			status_d        = 1'b0;
			count_ip_port_d = '0;
		end 
	endcase
end : ip_port_control_signals

assign evt_stream_memory_fork_src[1].valid = ready_ip_port_q & status_q & evt_stream_memory_dst.valid & (count_ip_port_q != 0); //make valid active alternately and ignore the header
assign evt_stream_memory_fork_src[0].valid = ready_ip_port_q & (~status_q) & evt_stream_memory_dst.valid & (count_ip_port_q != 0);
assign evt_stream_memory_fork_src[1].evt   = evt_stream_memory_dst.evt;
assign evt_stream_memory_fork_src[0].evt   = evt_stream_memory_dst.evt;
assign evt_stream_memory_dst.ready         = ready_ip_port_q & ((evt_stream_memory_fork_src[1].ready & status_q)||(evt_stream_memory_fork_src[0].ready& (~status_q)));
always_ff @(posedge bus_clk_i or negedge bus_rst_ni) begin : proc_
	if(~bus_rst_ni) begin
		state_ip_port_q <= INIT;
		ready_ip_port_q <= 0;
		status_q        <= 0;
		count_ip_port_q <= 0;
		// ready_q         <= 0;
	end else begin
		state_ip_port_q <= state_ip_port_d;
		ready_ip_port_q <= ready_ip_port_d;
		status_q        <= status_d       ;
		count_ip_port_q <= count_ip_port_d; 
	end
end

///////////////////////////////////////////////OP PORT////////////////////////////////////////////////////////////////////////////
state_position_t state_op_port_d, state_op_port_q;
logic ready_op_port_d, ready_op_port_q;

always_comb begin
	state_op_port_d = state_op_port_q;
	case(state_op_port_q) 
		INIT: begin
			if(evt_stream_time_dst.valid & (evt_stream_time_dst.evt.synch.operation == EVT_SYNCH))
				state_op_port_d = WAIT;
			else 
				state_op_port_d = INIT;
		end
		WAIT: begin
			if((evt_memory_weight_fifo[1].valid ||evt_memory_weight_fifo[0].valid))//wait for the time to be updated
				state_op_port_d = RESUME ; 
		end
		RESUME: begin
				state_op_port_d = RUN ; 
		end
		RUN : begin 
			if(done_q) 
				state_op_port_d = STOP;
			else 
				state_op_port_d = RUN;
		end 
		STOP : begin 
			if(ready_q) begin
				state_op_port_d = INIT; 
			end else begin 
				state_op_port_d = STOP;
			end
		end
		default: state_op_port_d = INIT;
	endcase // state_q
end


always_comb begin 
	evt_memory_weight_fifo[0].ready = ready_op_port_q & spike_grant_i;
	evt_memory_weight_fifo[1].ready = ready_op_port_q & spike_grant_i;
	evt_stream_time_dst.ready = 1'b0;
	init_sequencer_o          = 1'b0;
	wr_addr_d                 = wr_addr_q;
	rd_addr_d                 = rd_addr_q;
	ready_d                   = ready_q;
	ready_op_port_d           = ready_op_port_q;
	weight_d                  = weight_q;
	wr_en_d                   = wr_en_q;
	rd_en_d                   = rd_en_q;
	done_d                    = done_q;

	case(state_op_port_q)
		INIT: begin
			ready_op_port_d = 1'b0; 
			ready_d    = 1'b0;
			wr_addr_d  = '0;
			rd_addr_d  = '0;
			wr_en_d    = 1'b0;
			rd_en_d    = 1'b0;
			done_d     = 1'b0;
			evt_stream_time_dst.ready = 1'b1;
			init_sequencer_o          = 1'b1;
		end
		WAIT: begin
			ready_op_port_d = 1'b0; 
			ready_d    = 1'b0;
			wr_addr_d  = '0;
			rd_addr_d  = '0;
			wr_en_d    = 1'b0;
			rd_en_d    = 1'b0;
			done_d     = 1'b0;
		end
		RESUME: begin
			ready_op_port_d = 1'b0;
			wr_addr_d  = '0;
			ready_d    = 1'b0;
			rd_addr_d  = '0;
			wr_en_d    = 1'b0;
			rd_en_d    = 1'b1;
			done_d     = 1'b0;
			init_sequencer_o          = 1'b0;  
			evt_stream_time_dst.ready = 1'b0;
		end
		RUN: begin
			done_d = 0;
			rd_en_d = 1'b1;
			if(evt_memory_weight_fifo[1].valid & evt_memory_weight_fifo[0].valid & ready_op_port_q & spike_grant_i) begin //VALID HANDSHAKE
				rd_addr_d = rd_addr_q + 1;
				wr_addr_d = rd_addr_q;
				wr_en_d   = 1'b1;
				ready_op_port_d = 1'b0;
				weight_d  = {evt_memory_weight_fifo[1].evt, evt_memory_weight_fifo[0].evt};
			end else if(evt_memory_weight_fifo[1].valid & evt_memory_weight_fifo[0].valid & (~ready_op_port_q) & spike_grant_i) begin 
				rd_addr_d = rd_addr_q;
				wr_addr_d = wr_addr_q;
				wr_en_d   = 1'b0;
				ready_op_port_d = spike_grant_i;
				weight_d  = weight_q;
			end else begin//no valid data 
				rd_addr_d = rd_addr_q;
				wr_addr_d = wr_addr_q;
				wr_en_d   = 1'b0;
				ready_op_port_d = 1'b0;
				weight_d  = weight_q;
			end

			if((wr_addr_q==(THRESHOLD-1)) & wr_en_q) begin
				rd_addr_d = 0;
				wr_addr_d = 0;
				rd_en_d   = 0;
				done_d    = 1;
				ready_op_port_d = 0;
				wr_en_d   = 1'b0; 
			end
		end

		STOP : begin
			if(ready_q) begin
				ready_d = 1'b0;
			end else begin 
				ready_d = 1'b1;
			end 
			ready_op_port_d = 1'b0;
			wr_addr_d  = '0;
			rd_addr_d  = '0;
			wr_en_d    = 1'b0;
			rd_en_d    = 1'b1;
			done_d     = 1'b0;  
			evt_memory_weight_fifo[0].ready = 0;
			evt_memory_weight_fifo[1].ready = 0;
		end
	endcase
end

always_ff @(posedge engine_clk_i or negedge engine_rst_ni) begin : proc_memory_op
	if(~engine_rst_ni) begin
		state_op_port_q <= INIT;
		ready_op_port_q <= 0;
		wr_addr_q  <= '0;
		rd_addr_q  <= '0;
		wr_en_q    <= 1'b0;
		rd_en_q    <= 1'b0;
		done_q     <= 1'b0;
		ready_q    <= 1'b0;
		weight_q   <= '0;
	end else begin
		state_op_port_q <= state_op_port_d;
		wr_addr_q  <= wr_addr_d;
		rd_addr_q  <= rd_addr_d;
		wr_en_q    <= wr_en_d;
		rd_en_q    <= rd_en_d;
		done_q     <= done_d;
		ready_q    <= ready_d;
		ready_op_port_q <= ready_op_port_d;
		weight_q <= weight_d;
	end
end

assign done_o   = done_q;

endmodule : evt_weight_fifo