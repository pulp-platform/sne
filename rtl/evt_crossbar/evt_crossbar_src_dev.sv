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
module evt_crossbar_src_dev #(

	    parameter type T      = logic,
		parameter DST_PORTS   = 4,
		localparam ADDR_WIDTH = (DST_PORTS > 1) ? $clog2(DST_PORTS) : 1

	)(

		input  logic clk_i,
		input  logic rst_ni, 

		//--- input synchronous protocol
		input  T     [DST_PORTS-1:0] data_i,
		input  logic [DST_PORTS-1:0] valid_i,
		output logic                 ready_o,

		//--- output synchronous protocol
		output T                     data_o,
		output logic                 valid_o,
		input  logic                 ready_i,

		//--- master connection address
		input  logic [ADDR_WIDTH-1:0] addr_i,
		input  logic [ DST_PORTS-1:0] valid_mask_clean_i

	);

	logic valid_mask_s;

	always_ff @(posedge clk_i or negedge rst_ni) begin : proc_
		if(~rst_ni) begin
			valid_mask_s <= 1'b0;
		end else if ((ready_i && valid_i[addr_i]) && ~valid_mask_clean_i[addr_i]) begin
			valid_mask_s <= 1'b1;
		end else if (valid_mask_clean_i[addr_i] && valid_mask_s) begin //--- unmask it only if it was masked
			valid_mask_s <= 1'b0;
		end 
	end

	//--- output mux
	assign data_o  = data_i[addr_i] ;
	assign valid_o = valid_i[addr_i] && ~valid_mask_s; //--- mask the output valid if the input ready is asserted (avoid issuing the same date multiple times to downstream pipeline)
	assign ready_o = ready_i || valid_mask_s         ; //--- hold the ready until all the slaves assert the ready, and clean it with the global ready (avoid violating the protocol)

endmodule // evt_crossbar_src_dev
