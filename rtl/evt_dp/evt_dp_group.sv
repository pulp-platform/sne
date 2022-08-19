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
`include "evt_stream_macros.svh"
module evt_dp_group 

	import sne_evt_stream_pkg::uevent_t;
	import sne_evt_stream_pkg::weight_t;
	import sne_evt_stream_pkg::parameter_t;
	import sne_evt_stream_pkg::state_t;
	import sne_evt_stream_pkg::timestamp_t;

	import sne_evt_stream_pkg::cid_t;
	import sne_evt_stream_pkg::yid_t;
	import sne_evt_stream_pkg::xid_t;
	import sne_evt_stream_pkg::RST_OP;
	import sne_evt_stream_pkg::UPDATE_OP;
	import sne_evt_stream_pkg::config_engine_t;

	// import mem_sys_pkg::*;

	#(

	parameter DP_GROUP  = 16,
	parameter ENGINE_ID = 0,
	parameter STATE_WIDTH = 16

	)(

	input  logic                       engine_clk_i        ,  // Clock
	input  logic                       engine_rst_ni       ,  // Asynchronous reset active low
	input  logic                       test_en_i           ,  
	input  logic                       ext_group_clk_en_i  ,
	input  logic                       region_force_en_i   ,
	input  logic                       force_spike_op_i    ,
	// signals from the memory subsystem (states, parameters,weights)
	input   weight_t     [DP_GROUP-1:0] group_weights_i     , 
	// input  parameter_t  [DP_GROUP-1:0] group_parameters_i  ,
	input   state_t      [DP_GROUP-1:0] group_states_i      ,
	output  state_t      [DP_GROUP-1:0] group_states_o     ,
	//--- source data path stream ports directed to the memory subsystem
	SNE_EVENT_STREAM.src               evt_dp_group_mem_stream_src,
	// signal from the time unit
	input  timestamp_t                 global_time_i       ,
	//--- destination data path stream ports coming from the local router
	SNE_EVENT_STREAM.dst               evt_dp_group_stream_dst,
	// output spikes
	output logic        [DP_GROUP-1:0] spike_o,
	output logic        [DP_GROUP-1:0] group_clk_en_o,
	input  config_engine_t                    config_i
	
);

	logic [DP_GROUP-1:0]   int_group_en_s;
	logic [DP_GROUP-1:0]   group_clk_en_s;
	logic [DP_GROUP-1:0]   group_clk_s;

	//fork the input stream into DP_GROUP parallel streams
	SNE_EVENT_STREAM evt_dp_stream_fork_src[DP_GROUP:0](.clk_i(engine_clk_i)); // the additional port is used to expose spike info to the memory subsystem
	SNE_EVENT_STREAM evt_dp_stream_filter_src[DP_GROUP-1:0](.clk_i(engine_clk_i));
	SNE_EVENT_STREAM evt_dp_stream_neuron_src[DP_GROUP-1:0](.clk_i(engine_clk_i));

	logic force_en_s;
	assign force_en_s = (evt_dp_group_stream_dst.evt.dp_data.dp_operation==RST_OP) ||(evt_dp_group_stream_dst.evt.dp_data.dp_operation==UPDATE_OP) ||(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==2'b10);

	// fork the input stream in a separate stream for the neuron data paths
	// expose an additional stream to the memory subsystem
	// synchronize the operation of the DP and the memory as all the downstream modules must grant (with the ready) the transaction to assert the input ready
	evt_fork #(
		.N_OUP(DP_GROUP+1) // the additional port is used to expose spike info to the memory subsystem
	) i_evt_fork (
		.clk_i         (engine_clk_i              ),
		.rst_ni        (engine_rst_ni             ),
		.evt_stream_dst(evt_dp_group_stream_dst   ),
		.evt_stream_src(evt_dp_stream_fork_src    )
	);

	// expose one of the forked dp streams to the memory subsystem to retrieve the correct weight
	`SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_dp_group_mem_stream_src,evt_dp_stream_fork_src[DP_GROUP])

	// instantiate DP_GROUP neuron group modules
	for (genvar i = 0; i < DP_GROUP; i++) begin: group
		// group clock can be selectively ungated internally (filters), or externally (by the decoder)
		assign group_clk_en_s[i] = int_group_en_s[i] || ext_group_clk_en_i; 
		assign group_clk_en_o[i] = int_group_en_s[i];
		// clock gate the neuron groups
		tc_clk_gating i_group_dp_clock_gating (
			.clk_i                    ( engine_clk_i                 ), 
			.en_i                     ( group_clk_en_s[i]            ), 
			.test_en_i                ( test_en_i                    ), 
			.clk_o                    ( group_clk_s[i]               )
		);

		// neuron group event filtering module 
		evt_filter #(.GROUP_ID(ENGINE_ID*DP_GROUP+i),.DP_GROUP(DP_GROUP)) i_evt_filter(
			.engine_clk_i             ( engine_clk_i                 ),
			.engine_rst_ni            ( engine_rst_ni                ),
			.config_i                 ( config_i                     ),
			.force_en_i               ( force_en_s                   ),
			.group_enable_o           ( int_group_en_s[i]            ),
			.evt_dp_stream_filter_dst ( evt_dp_stream_fork_src[i]    ), 
			.evt_dp_stream_filter_src ( evt_dp_stream_filter_src[i]  )  // neuron should accept a stream
		);

		// neurons
		evt_neuron_dp i_lif_neuron (
			//signals from the weights memory
			.syn_weight_i            ( group_weights_i[i]          ),
			.syn_weight_scale_i      ( 4'h2                        ),
			.config_i                ( config_i                    ),
			//signals from/to the state memory
			.neuron_state_i          ( group_states_i[i]           ),
			.neuron_state_o          ( group_states_o[i]           ), 
			.force_spike_op_i        ( force_spike_op_i            ),
			// signals form the time unit (global time reference)
			.time_i                  ( global_time_i               ),
			//input data path stream
			.enable_i                ( int_group_en_s[i]           ),
			// input/output data path stream/spikes
			.evt_dp_group_stream_dst ( evt_dp_stream_filter_src[i] ), 
			.spike_o                 ( spike_o[i]                  )
		);

	end: group



endmodule