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
module evt_counter #(
	parameter signed LOWER_LIMIT = -1,
	parameter signed UPPER_LIMIT =  1
)(
	input 	logic clk_i,
	input 	logic rst_ni,

	input 	logic enable_i,
	input 	logic init_i,
	output 	logic done_o,
	output 	logic [1:0] count_o
);
	logic [2:0] count_d , count_q ; 
	logic done_d , done_q ;


	always_comb begin
		done_d  = 0;
		count_d = count_q;
		if(init_i) begin
			count_d = LOWER_LIMIT;
			done_d  = 1'b0; 
		end else begin 
			if(enable_i) begin 
				count_d = count_q + 1;
				done_d = 1'b0;
				if(count_q == UPPER_LIMIT) begin 
					count_d = LOWER_LIMIT;
					done_d  = 1'b1;
				end
			end else begin 
				count_d = count_q;
			end
		end
	end

	always_ff @(posedge clk_i or negedge rst_ni) begin : proc_count_q
		if(~rst_ni) begin
			count_q <= LOWER_LIMIT;
			done_q  <= 0;
		end else begin
			count_q <= count_d;
			done_q  <= done_d;
		end
	end

	assign count_o = count_q[1:0];
	assign done_o  = done_q;
endmodule 