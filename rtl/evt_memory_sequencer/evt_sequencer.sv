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
module evt_sequencer
	import sne_evt_stream_pkg::config_engine_t;
	#(

	parameter ADDR_WIDTH = 6,
	parameter ENGINE_ID  = 0

	)(

	input  logic                  clk_i                ,   
	input  logic                  rst_ni               , 
	input  logic                  init_i               ,
	input  logic                  spike_grant_i        ,

	config_engine_t				  config_i             ,

	input  logic   				  time_stable_i        ,
	output logic   				  init_sequencer_o     ,

	// signals going to the memory subsystem
	output logic [ADDR_WIDTH-1:0] mem_waddr_o          ,
	output logic                  mem_we_o             ,
	output logic [ADDR_WIDTH-1:0] mem_raddr_o          ,
	output logic                  mem_re_o             ,
	output logic                  ready_o              ,
	output logic                  done_o               ,
	SNE_EVENT_STREAM.dst    	  evt_stream_time_dst
);
	logic [ADDR_WIDTH+1-1:0] rd_addr_d, rd_addr_q ;
	logic [ADDR_WIDTH+1-1:0] wr_addr_d, wr_addr_q ;

	logic  ready_d, ready_q, done_d, done_q     ;
	logic  rd_en_d, rd_en_q, wr_en_d, wr_en_q   ;
	logic [ADDR_WIDTH-1:0] cfg_addr_step_i      ;
	logic [ADDR_WIDTH-1:0] cfg_addr_start_i     ;
	logic [ADDR_WIDTH-1:0] cfg_addr_end_i       ;


	typedef enum logic [2:0] {
		INIT,
		RESUME,
		WAIT,
		RUN,
		STOP
	}state_position_t;

	state_position_t state_d, state_q;

	assign cfg_addr_start_i = config_i.reg2hw.cfg_addr_start_i[ENGINE_ID];
	assign cfg_addr_step_i  = config_i.reg2hw.cfg_addr_step_i[ENGINE_ID] ;
	assign cfg_addr_end_i   = config_i.reg2hw.cfg_addr_end_i[ENGINE_ID]  ;

	always_comb begin : PROC_NS
		state_d = state_q;
		case(state_q) 
			INIT: begin
				if(init_i)
					state_d = WAIT;
				else 
					state_d = INIT;
			end
			WAIT: begin
				if(time_stable_i)
					state_d = RESUME;
				else 
					state_d = WAIT;
			end
			RESUME: begin
				state_d = RUN ; 
			end
			RUN : begin 
				if(done_q) 
					state_d = STOP;
				else 
					state_d = RUN;
			end 
			STOP : begin
				if(ready_q & spike_grant_i) 
					state_d = INIT;
				else
					state_d = STOP; 
			end
			default : state_d = INIT;
		endcase // state_q
	end

	always_comb begin : PROC_OUT
		evt_stream_time_dst.ready = 0;
        init_sequencer_o          = 0;
        done_d    = 1'b0;
		rd_addr_d = '0;
		wr_addr_d = '0;
		rd_en_d   = 1'b0;
		wr_en_d   = 1'b0;
		ready_d   = 1'b0;
		case(state_q)
			INIT: begin
				done_d    = 1'b0;
				rd_addr_d = '0;
				wr_addr_d = '0;
				rd_en_d   = 1'b0;
				wr_en_d   = 1'b0;
				ready_d   = 1'b0;
				evt_stream_time_dst.ready = 1;
                init_sequencer_o          = 1;
			end
			WAIT: begin
				done_d    = 1'b0;
				rd_addr_d = '0;
				wr_addr_d = '0;
				rd_en_d   = 1'b0;
				wr_en_d   = 1'b0;
				ready_d   = 1'b0;
				evt_stream_time_dst.ready = 1;
                init_sequencer_o          = 1;
			end
			RESUME: begin
				done_d    = 1'b0;
				rd_addr_d = cfg_addr_start_i;
				wr_addr_d = '0;
				rd_en_d   = 1'b1;
				wr_en_d   = 1'b0;
				ready_d   = 1'b0;
			end 
			RUN: begin
				wr_addr_d = rd_addr_q;
				rd_addr_d = rd_addr_q;
				rd_en_d   = 1'b1     ;
				ready_d   = 1'b0     ;
				if(spike_grant_i) begin
					if(rd_addr_q + cfg_addr_step_i > cfg_addr_end_i) begin
						rd_addr_d = cfg_addr_start_i;
						done_d  = 1'b1;
						// ready_d = 1'b1;
					end else begin
						rd_addr_d = rd_addr_q + cfg_addr_step_i;
						done_d    = 1'b0; 
					end 
					wr_en_d   = 1'b1;
					if(wr_addr_q>=cfg_addr_end_i)
						wr_en_d = 1'b0;
				end else begin 
					rd_addr_d = rd_addr_q;
					done_d    = done_q;   
					wr_en_d   = 1'b0;
				end 
			end
			STOP :  begin 
				done_d    = 1'b0;
				rd_addr_d = '0;
				wr_addr_d = '0;
				rd_en_d   = 1'b0;
				wr_en_d   = 1'b0;
				ready_d   = 1'b1;
			end
		endcase 
	end

	always_ff @(posedge clk_i or negedge rst_ni) begin : proc_address
		if(~rst_ni) begin
			rd_addr_q <= 0;
			wr_addr_q <= 0;
			done_q    <= 0;
			rd_en_q   <= 0;
			wr_en_q   <= 0;
			ready_q   <= 1'b0;
			state_q   <= INIT;
		end else begin
			rd_addr_q <= rd_addr_d;
			wr_addr_q <= wr_addr_d;
			done_q    <= done_d;
			ready_q   <= ready_d;
			rd_en_q   <= rd_en_d;
			wr_en_q   <= wr_en_d;
			state_q   <= state_d;	
		end
	end

	assign mem_re_o    = rd_en_q;
	assign mem_raddr_o = rd_addr_q;
	assign mem_we_o    = wr_en_q;
	assign mem_waddr_o = wr_addr_q;
	assign done_o      = done_q;
	assign ready_o     = ready_q;
endmodule