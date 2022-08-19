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
module evt_memory_subsystem 
	import sne_evt_stream_pkg::*; 
	import sne_pkg::*;
#( 	parameter DP_GROUP = 16,
	parameter type T,
	parameter ENGINE_ID,
   	parameter STATE_DATA_WIDTH = 32
   	)(  
	input logic 			   engine_clk_i		    ,
	input logic 			   engine_rst_ni		,

	input logic                power_gate           ,
	input logic                power_sleep          ,

	input config_engine_t      config_i             ,

	input logic                bus_clk_i            ,
	input logic                bus_rst_ni           ,

	input logic [DP_GROUP-1:0] group_clk_en_i       ,
	MEMORY_PORT.read_dst 	kernel_read_dst		    ,
	MEMORY_PORT.read_dst 	state_read[DP_GROUP-1:0],
	MEMORY_PORT.write_dst 	state_write[DP_GROUP-1:0], 
	SNE_EVENT_STREAM.dst    evt_stream_memory_dst   
);
	evt_status_memory#(

		.NEURONS_ADDR_WIDTH	(	SEQ_ADDR_WIDTH	    ),
		.STATE_DATA_WIDTH   (	STATE_DATA_WIDTH	),
		.NEURON_GROUP       (   DP_GROUP            )
		
		) i_status_memory	(
		
		.clk_i            	(	engine_clk_i		),
		.rst_ni				(	engine_rst_ni		),
		.group_clk_en_i 	(	group_clk_en_i 		),
		.power_gate         (   power_gate          ),
		.power_sleep        (   power_sleep         ),
		.test_en_i			(	1'b0				),
		.state_read 		(	state_read[DP_GROUP-1:0]),
		.state_write 		(	state_write[DP_GROUP-1:0])
		
		);

	evt_kernel_memory_wrapper #(
		.T(T), .DP_GROUP(DP_GROUP), .ENGINE_ID(ENGINE_ID)
		
		) evt_kernel_memory	(
		.bus_clk_i          (   bus_clk_i           ),
		.bus_rst_ni         (   bus_rst_ni          ),
		.engine_clk_i       (	engine_clk_i		),
		.engine_rst_ni		(	engine_rst_ni		),
		.config_i          	(	config_i    		),
		.kernel_read_dst   	(	kernel_read_dst		),
		.evt_stream_memory_dst(evt_stream_memory_dst)
		);

endmodule