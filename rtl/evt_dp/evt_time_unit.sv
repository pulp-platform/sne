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
`include "evt_neuron_defines.svh"
`include "evt_stream_macros.svh"

module evt_time_unit 

	import sne_evt_stream_pkg::timestamp_t;
	import sne_evt_stream_pkg::EVT_SYNCH; 
	import sne_evt_stream_pkg::EVT_TIME; 
	import sne_evt_stream_pkg::config_engine_t;
	#(parameter ENGINE_ID=0)

(

	input  logic            clk_i        ,  // Clock
	input  logic            rst_ni       ,  // Asynchronous reset active low

	input  config_engine_t  config_i     ,

	input  logic            hold_i       ,
	output timestamp_t      global_time_o,
	output logic            time_stable_o,

	//--- source event stream ports
	SNE_EVENT_STREAM.dst    evt_stream_time_dst,
	SNE_EVENT_STREAM.src    evt_stream_time_src,
	SNE_EVENT_STREAM.src    evt_stream_time_engine_src[2:0]
	
);
SNE_EVENT_STREAM evt_stream_time_temp_dst (.clk_i(clk_i));
SNE_EVENT_STREAM evt_stream_time_fork_src[4:0](.clk_i(clk_i));

logic [4:0] valid_mask;

evt_stream_dynamic_fork #(.N_OUP(5)) i_evt_stream_dynamic_fork (
	.clk_i         (clk_i),
	.rst_ni        (rst_ni),
	.sel_i         (valid_mask),
	.sel_valid_i   (1'b1),
	.sel_ready_o   (),
	.evt_stream_dst(evt_stream_time_temp_dst),
	.evt_stream_src(evt_stream_time_fork_src)
);
// register the incoming time value
always_ff @(posedge clk_i or negedge rst_ni) begin : proc_global_time_o
	if(~rst_ni) begin
		global_time_o <= 0;
	end else if (evt_stream_time_temp_dst.valid & evt_stream_time_temp_dst.ready & (evt_stream_time_dst.evt.synch.operation == EVT_TIME)) begin
		global_time_o <= evt_stream_time_fork_src[1].evt.timestamp.value;
	end
end

// assume the timestamp can be changed when not doing other operations
assign evt_stream_time_fork_src[1].ready = ~hold_i;
`SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_time_src,evt_stream_time_fork_src[0]);
`SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_time_engine_src[2],evt_stream_time_fork_src[2]);
`SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_time_engine_src[1],evt_stream_time_fork_src[3]);
`SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_time_engine_src[0],evt_stream_time_fork_src[4]);

logic time_stable_d, time_stable_q;

always_comb begin
	valid_mask = 5'b11111;
	`C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_time_temp_dst,evt_stream_time_dst);
	if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==`FC) begin
		if(evt_stream_time_dst.valid & (evt_stream_time_dst.evt.synch.operation == EVT_SYNCH)) begin 
			valid_mask = 5'b10000;
		end else if(evt_stream_time_dst.valid & (evt_stream_time_dst.evt.synch.operation != EVT_SYNCH))begin 
			valid_mask    = 5'b11111;
		end 
	end else begin 
		valid_mask    = 5'b11111;
	end
	time_stable_d = evt_stream_time_dst.valid ? (evt_stream_time_dst.valid & evt_stream_time_dst.ready) : time_stable_q;
end

always_ff @(posedge clk_i or negedge rst_ni) begin : proc_time_stable_o
	if(~rst_ni) begin
		time_stable_q <= 0;
	end else begin
		time_stable_q <= time_stable_d;
	end
end

assign time_stable_o = time_stable_q;
endmodule