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
module evt_fork #(

	parameter int unsigned N_OUP  = 0      // Synopsys DC requires a default value for parameters.

	)(

	input logic          clk_i                    , // Clock
	input logic          rst_ni                   , // Asynchronous reset active low

	SNE_EVENT_STREAM.dst evt_stream_dst           , // incoming stream
	SNE_EVENT_STREAM.src evt_stream_src[N_OUP-1:0]  // outgoing stream
	
);

	logic  [N_OUP-1:0] oup_valid;
	logic  [N_OUP-1:0] oup_ready;

	// we unpack the interface
	for (genvar i = 0; i < N_OUP; i++) begin
		assign evt_stream_src[i].valid = oup_valid[i];
		assign evt_stream_src[i].evt   = evt_stream_dst.evt;
		assign oup_ready[i]            = evt_stream_src[i].ready;
	end

stream_fork #(.N_OUP(N_OUP)) i_stream_fork (

	.clk_i  (clk_i  ),
	.rst_ni (rst_ni ),

	.valid_i(evt_stream_dst.valid),
	.ready_o(evt_stream_dst.ready),

	.valid_o(oup_valid),
	.ready_i(oup_ready)
);



endmodule