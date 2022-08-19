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
module evt_engine 

	import sne_evt_stream_pkg::uevent_t;
	import sne_evt_stream_pkg::weight_t;
	import sne_evt_stream_pkg::parameter_t;
	import sne_evt_stream_pkg::state_t;
	import sne_evt_stream_pkg::timestamp_t;
	import sne_evt_stream_pkg::cid_t;
	import sne_evt_stream_pkg::config_engine_t;

#(
	parameter  ENGINE_ID   = 0 ,
	parameter DP_GROUP    = 16
)(

	input  logic                      bus_clk_i,
	input  logic                      bus_rst_ni,

	input  logic                      engine_clk_i        ,  
	input  logic                      engine_rst_ni       ,

	input  logic                      power_gate,
	input  logic                      power_sleep,

	input  config_engine_t            config_i            ,
	input  logic                      ack_error_i		  ,
	input  logic                      online_enable_i     ,
	input  logic [$clog2(DP_GROUP)-1:0] online_group_id   ,
	output logic [31:0]               online_data_o       ,          
	//--- destination event stream ports
	SNE_EVENT_STREAM.dst              evt_stream_dst      , 
	//--- source event stream ports
	SNE_EVENT_STREAM.src              evt_stream_src       
);

//sequencer
timestamp_t global_time_s;
cid_t     [DP_GROUP-1:0]  global_cid_s ;
logic init_addr_o;
logic gnt_output_spike_i ;
logic req_output_spike_o ;
logic req_input_spike_o  ;
logic gnt_input_spike_i  ;
logic gnt_input_weight_i ;
logic req_input_weights_o;
logic [31:0] fc_fifo_count_i;

// dp group
logic                      ext_group_clk_en_i;
logic                      region_force_en_i;
weight_t    [DP_GROUP-1:0] group_weights_i;
parameter_t [DP_GROUP-1:0] group_parameters_i;
state_t     [DP_GROUP-1:0] group_states_i;
state_t     [DP_GROUP-1:0] group_states_o;
logic       [DP_GROUP-1:0] spike_o;
logic       [DP_GROUP-1:0] group_clk_en_o;


SNE_EVENT_STREAM evt_stream_engine_src(.clk_i(engine_clk_i));
// SNE_EVENT_STREAM evt_stream_memory_src(.clk_i(engine_clk_i));

SNE_EVENT_STREAM evt_stream_memory_src(.clk_i(bus_clk_i));

// we rout the packets coming from the bus, dividing it in engine stream and memory stream
evt_global_router #(.T(uevent_t), .DEC_EL_FIFO_DEPTH(1)) i_evt_global_router (
	.bus_clk_i            (bus_clk_i            ),
	.bus_rst_ni           (bus_rst_ni           ),
	.engine_clk_i         (engine_clk_i         ),
	.engine_rst_ni        (engine_rst_ni        ),
	.ack_error_i          (ack_error_i          ),
	.evt_stream_dst       (evt_stream_dst       ),
	.evt_stream_engine_src(evt_stream_engine_src),
	.evt_stream_memory_src(evt_stream_memory_src)
);

// stream from the local router
SNE_EVENT_STREAM evt_stream_time_src(.clk_i(engine_clk_i));
SNE_EVENT_STREAM evt_stream_spike_src(.clk_i(engine_clk_i));

//strea, going to the memory subsystem
SNE_EVENT_STREAM evt_dp_group_mem_stream_src(.clk_i(engine_clk_i));

SNE_EVENT_STREAM evt_dp_stream_decoder_src(.clk_i(engine_clk_i));

//stream going to mapper for synchronization on time event
SNE_EVENT_STREAM evt_mapper_stream_time_src[3:0](.clk_i(engine_clk_i));

// divide the input stream directed to the engine into spikes and time streams
evt_engine_router#(.ENGINE_ID(ENGINE_ID), .DP_GROUP(DP_GROUP)) i_evt_engine_router(
	.clk_i                (engine_clk_i         ),
	.rst_ni               (engine_rst_ni        ),
	.config_i             (config_i             ),
	.evt_stream_engine_dst(evt_stream_engine_src),
	.evt_stream_time_src  (evt_stream_time_src  ),
	.evt_stream_spike_src (evt_stream_spike_src )
);
logic time_stable; //important that the time remains stable before any processing starts. Can be an issue in FC layer.
// time stream is sent to the time unit (ends here)
logic init_sequencer;
evt_time_unit #(.ENGINE_ID(ENGINE_ID))i_evt_time_unit (
	.clk_i              (engine_clk_i       ),
	.rst_ni             (engine_rst_ni      ),
	.config_i           (config_i           ),
	.hold_i             (             1'b0  ),
	.time_stable_o    	(time_stable        ),
	.global_time_o      (global_time_s      ),
	.evt_stream_time_dst(evt_stream_time_src),
	.evt_stream_time_src(evt_mapper_stream_time_src[3]),
	.evt_stream_time_engine_src(evt_mapper_stream_time_src[2:0])
);

// spike stream is converted into a data path stream
evt_decoder i_evt_decoder (
	.clk_i                       (engine_clk_i                ),
	.rst_ni                      (engine_rst_ni               ),
	.evt_spike_stream_decoder_dst(evt_stream_spike_src        ),
	.evt_dp_stream_decoder_src   (evt_dp_stream_decoder_src   ) 
);

assign global_cid_s = '0;
logic force_spike_op_i;

SNE_EVENT_STREAM evt_gp_memory_to_mapper_dst[DP_GROUP-1:0](.clk_i(engine_clk_i));
SNE_EVENT_STREAM evt_fifo_stream_src [DP_GROUP-1:0](.clk_i(engine_clk_i));

evt_memory_sequencer#(.T(uevent_t),.DP_GROUP(DP_GROUP),.ENGINE_ID(ENGINE_ID),
	.STATE_WIDTH(32))i_memory_sequencer(
	.engine_clk_i           (engine_clk_i),
	.engine_rst_ni          (engine_rst_ni),
	.bus_clk_i              (bus_clk_i),
	.bus_rst_ni             (bus_rst_ni),
	.config_i               (config_i),//to be mapped
	.global_time_i          (global_time_s),//REMOVE just for debug
	.group_clk_en_i         (group_clk_en_o),
	.group_state_i          (group_states_o),
	.group_state_o          (group_states_i),
	.group_weight_o         (group_weights_i),
	.time_stable_i          (time_stable    ),
	.init_sequencer_o       (init_sequencer ),
	.online_data_o          (online_data_o  ),
	.online_enable_i        (online_enable_i),
	.online_group_id        (online_group_id),
	.power_gate             (power_gate     ),
	.power_sleep            (power_sleep    ),
	.evt_stream_time_dst    (evt_mapper_stream_time_src[2:0]),
	.evt_dp_group_stream_dst(evt_dp_group_mem_stream_src),
	.evt_stream_memory_dst  (evt_stream_memory_src),
	.evt_fifo_stream_src    (evt_fifo_stream_src),
	.force_spike_op_o       (force_spike_op_i ),
	.group_spike_i          (spike_o            )
);
// here we instantiate the real DP
evt_dp_group #(.DP_GROUP(DP_GROUP),.ENGINE_ID(ENGINE_ID),
	.STATE_WIDTH(32)) i_evt_dp_group (

	.engine_clk_i               (engine_clk_i               ),
	.engine_rst_ni              (engine_rst_ni              ),
	.test_en_i                  (1'b0                       ),
	.config_i                   (config_i                   ),
	.force_spike_op_i           (force_spike_op_i           ),
	.ext_group_clk_en_i         (1'b1                       ),
	.region_force_en_i          (1'b0                       ),
	.group_weights_i            (group_weights_i            ),
	.group_states_i             (group_states_i             ),
	.group_states_o             (group_states_o             ),
	.evt_dp_group_stream_dst    (evt_dp_stream_decoder_src  ), 
	.evt_dp_group_mem_stream_src(evt_dp_group_mem_stream_src), 
	.global_time_i              (global_time_s              ),
	.group_clk_en_o 			(group_clk_en_o             ),
	.spike_o                    (spike_o                    )
);

// here we need to collect the spikes, and assign a proper address (output neuron)
SNE_EVENT_STREAM evt_gp_mapper_stream[DP_GROUP-1:0](.clk_i(engine_clk_i));

// here we are going to instantiate the mapper
evt_mapper #(.DP_GROUP(DP_GROUP),.ENGINE_ID(ENGINE_ID)) i_evt_mapper (
	.engine_clk_i            (engine_clk_i               ),
	.engine_rst_ni           (engine_rst_ni              ),                   
	.config_i                (config_i                   ),
	.init_sequencer_i        (init_sequencer             ),
	.evt_dp_memory_mapper_dst(evt_fifo_stream_src        ),
	.evt_dp_stream_mapper_src(evt_gp_mapper_stream       ),
	.evt_stream_time_dst     (evt_mapper_stream_time_src[3] )
);
// here we need to buffer output streames in CDC fifos
SNE_EVENT_STREAM evt_gp_fifo_stream_src[DP_GROUP-1:0](.clk_i(bus_clk_i));
SNE_EVENT_STREAM evt_synch_stream_dst[DP_GROUP-1:0](.clk_i(bus_clk_i));

for (genvar i = 0; i < DP_GROUP; i++) begin: fifo
	evt_cdc_fifo #(.T(uevent_t), .DEPTH(4)) i_evt_cdc_fifo (
		.dst_clk_i (engine_clk_i ),
		.dst_rst_ni(engine_rst_ni),
		.dst_stream(evt_gp_mapper_stream[i]),
		.src_clk_i (bus_clk_i ),
		.src_rst_ni(bus_rst_ni),
		.src_stream(evt_synch_stream_dst[i])
	);
end: fifo

evt_synchronizer #(.N(DP_GROUP)) i_evt_synchronizer (
	.clk_i 			(bus_clk_i             ),
	.rst_ni 		(bus_rst_ni            ),
	.fwd_barrier_i 	(16'h0001              ),
	.synch_en_i    	(16'hFFFF              ),
	.evt_stream_dst (evt_synch_stream_dst  ),
	.evt_stream_src (evt_gp_fifo_stream_src)
); 
// here we can arbitrate to join everything in a single output stream
evt_arbiter #(.DATA_T(uevent_t), .N_INP(DP_GROUP)) i_evt_arbiter (
	.clk_i         (bus_clk_i             ),
	.rst_ni        (bus_rst_ni            ),
	.evt_stream_dst(evt_gp_fifo_stream_src),
	.evt_stream_src(evt_stream_src        )
);

endmodule