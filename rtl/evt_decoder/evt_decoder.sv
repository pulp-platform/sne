/* 
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
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

// this module binds the general event type carried by the spike stream to neuron DP data and operation
`include "evt_stream_macros.svh"
module evt_decoder 

	// allowed events
	import sne_evt_stream_pkg::EVT_IDLE      ;      
	import sne_evt_stream_pkg::EVT_SPIKE     ;     
	import sne_evt_stream_pkg::EVT_ACCUMULATE;
	import sne_evt_stream_pkg::EVT_WIPE      ;
	import sne_evt_stream_pkg::EVT_UPDATE    ;       

	// neuron dp operations
	import sne_evt_stream_pkg::IDLE_OP       ;
	import sne_evt_stream_pkg::SPIKE_OP      ;
	import sne_evt_stream_pkg::INTEGRATE_OP  ;
	import sne_evt_stream_pkg::RST_OP        ;
	import sne_evt_stream_pkg::UPDATE_OP     ;        

	(

	input  logic                  clk_i        ,  // Clock
	input  logic                  rst_ni       ,  // Asynchronous reset active low

	//--- destination event stream ports
	SNE_EVENT_STREAM.dst          evt_spike_stream_decoder_dst,

	//--- source data path stream ports
	SNE_EVENT_STREAM.src          evt_dp_stream_decoder_src 
	
);

// assign with a macro the dp stream fields, and replace only the operation field with the proper neuron dp op
always_comb begin : proc_decode_operation
	case (evt_spike_stream_decoder_dst.evt.spike.operation)

		EVT_IDLE       : begin
			`SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(evt_dp_stream_decoder_src,evt_spike_stream_decoder_dst,IDLE_OP)
		end

		EVT_SPIKE      : begin
			`SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(evt_dp_stream_decoder_src,evt_spike_stream_decoder_dst,SPIKE_OP)
		end

		EVT_ACCUMULATE : begin
			`SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(evt_dp_stream_decoder_src,evt_spike_stream_decoder_dst,INTEGRATE_OP)
		end

		EVT_WIPE       : begin
			`SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(evt_dp_stream_decoder_src,evt_spike_stream_decoder_dst,RST_OP)
		end

		EVT_UPDATE       : begin
			`SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(evt_dp_stream_decoder_src,evt_spike_stream_decoder_dst,UPDATE_OP)
		end

		default        : begin
			`SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(evt_dp_stream_decoder_src,evt_spike_stream_decoder_dst,IDLE_OP)
		end
	endcase
end

endmodule