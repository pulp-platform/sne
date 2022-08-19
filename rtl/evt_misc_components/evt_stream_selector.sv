/* 
 * Alfio Di Mauro <adimauro@student.ethz.ch>
 * Arpan Suravi Prasad <prasadar@student.ethz.ch>
 *
 * Copyright (C) 2018-2022 ETH Zurich, University of Bologna
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
module evt_stream_selector #(
	parameter SLICE_NUMBER = 8
)(
	input logic                    clk_i,
	input logic                    rst_ni,
	input logic [SLICE_NUMBER-1:0] enable_i,
	SNE_EVENT_STREAM.dst           evt_stream_arbiter_dst[SLICE_NUMBER-1:0],
	SNE_EVENT_STREAM.dst           evt_stream_crossbar_dst[SLICE_NUMBER-1:0],
	SNE_EVENT_STREAM.src           evt_stream_engine_src[SLICE_NUMBER-1:0]
);

for(genvar i=0; i<SLICE_NUMBER; i++) begin
  always_comb begin
  	if(enable_i[i]) begin
  	  evt_stream_crossbar_dst[i].ready = 1'b1;
  	  `C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_engine_src[i],evt_stream_arbiter_dst[i]); 
  	end else begin 
  	  evt_stream_arbiter_dst[i].ready = 1'b1;
  	  `C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_engine_src[i],evt_stream_crossbar_dst[i]); 
  	end  
  end 
end 
endmodule