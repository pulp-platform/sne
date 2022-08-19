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
interface SNE_EVENT_STREAM ( input logic clk_i );

	import sne_evt_stream_pkg::uevent_t;

	logic ready;
	logic valid;
	uevent_t evt;

	modport dst (input  valid, evt, output ready); // event destination
	modport src (output valid, evt, input  ready);        // event source

	property SNE_EVENT_STREAM_consistent_data_change;
		@(posedge clk_i)(($past(valid) && ~$past(ready)) |-> (evt.data.bits == $past(evt.data.bits)));
	endproperty;

  	property SNE_EVENT_STREAM_legit_valid_deassert;
    	@(posedge clk_i)(($past(valid) && ~valid) |-> $past(valid) && $past(ready));
  	endproperty;

	consistent_data_change:   assert property(SNE_EVENT_STREAM_consistent_data_change)
    	else $error("ASSERTION FAILURE: consistent_data_change");

	legit_valid_deassert: assert property(SNE_EVENT_STREAM_legit_valid_deassert)
   		else $error("ASSERTION FAILURE: legit_valid_deassert");

endinterface


interface MEMORY_PORT #(parameter AW = 32, parameter DW = 32, parameter CW=1)(

	input logic clk

	);

	logic [DW-1:0] data;
	logic [AW-1:0] addr;
	logic [CW-1:0] enable;
	logic          valid;

    modport read_src  (output  addr, enable, input data);
    modport read_dst  (input  addr, enable, output data);
    modport write_src (output  addr, enable, data);
    modport write_dst (input  addr, enable, data);

endinterface