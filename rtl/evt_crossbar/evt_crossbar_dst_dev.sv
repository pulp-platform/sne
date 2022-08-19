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
module evt_crossbar_dst_dev #(

		parameter type T    = logic,
		parameter SRC_PORTS = 4

	)(

		input  T                     data_i ,
		input  logic                 valid_i,
		output logic                 ready_o,

		output T                     data_o ,
		output logic                 valid_o,
		input  logic [SRC_PORTS-1:0] ready_i,
		
		output logic                 valid_mask_clean_o,
		input  logic [SRC_PORTS-1:0] ready_dev_mask_i


	);

	logic [SRC_PORTS-1:0] ready_check;

	//--- propagate the ready upstream only if some downstream master can execute a transaction
	always_comb begin : proc_ready_output
		if(ready_dev_mask_i == {SRC_PORTS{1'b0}}) begin
			ready_check = {SRC_PORTS{1'b0}};
		end else begin
			for (int i = 0; i < SRC_PORTS; i++) begin
				if (ready_dev_mask_i[i]) begin
					if (ready_i[i]) begin
						ready_check[i] = 1'b1;
					end else begin
						ready_check[i] = 1'b0;
					end
				end else begin
					ready_check[i] = 1'b1;
				end
			end	
		end
	end

	assign ready_o            = (ready_check == {SRC_PORTS{1'b1}});
	assign valid_mask_clean_o = ready_o;
	assign valid_o            = valid_i;
	assign data_o             = data_i;

endmodule // evt_crossbar_dst_dev
