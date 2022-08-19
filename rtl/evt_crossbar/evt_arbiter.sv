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
 
 // this module MUST NOT be used to arbitrate streams belonging to two different packets,
 // as it does not detect the packet header, and will mix the payload
module evt_arbiter #(

	parameter type      DATA_T = logic,   // Vivado requires a default value for type parameters.
	parameter integer   N_INP = -1,       // Synopsys DC requires a default value for parameters.
	parameter           ARBITER = "rr"    // "rr" or "prio"

	)(

	input  logic         clk_i                      ,  
	input  logic         rst_ni                     ,  

	SNE_EVENT_STREAM.dst evt_stream_dst[N_INP-1:0]  , // incoming stream
	SNE_EVENT_STREAM.src evt_stream_src               // outgoing stream
	
);

DATA_T [N_INP-1:0] inp_data_s ;
logic  [N_INP-1:0] inp_valid_s;
logic  [N_INP-1:0] inp_ready_s;

// we unpack the interface
for (genvar i = 0; i < N_INP; i++) begin
	assign inp_data_s[i]  = evt_stream_dst[i].evt;
	assign inp_valid_s[i] = evt_stream_dst[i].valid;
	assign evt_stream_dst[i].ready = inp_ready_s[i];
end

stream_arbiter #(

	.DATA_T ( DATA_T  ), 
	.N_INP  ( N_INP   ), 
	.ARBITER( ARBITER )

	) i_stream_arbiter (

	.clk_i      ( clk_i                ),
	.rst_ni     ( rst_ni               ),

	.inp_data_i ( inp_data_s           ),
	.inp_valid_i( inp_valid_s          ),
	.inp_ready_o( inp_ready_s          ),

	.oup_data_o ( evt_stream_src.evt   ),
	.oup_valid_o( evt_stream_src.valid ),
	.oup_ready_i( evt_stream_src.ready )
);

endmodule