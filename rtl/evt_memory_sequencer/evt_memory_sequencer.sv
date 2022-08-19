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
`include "evt_neuron_defines.svh"
`include "evt_stream_macros.svh"

module evt_memory_sequencer
	import sne_evt_stream_pkg::*;
	import sne_pkg::*;
	#(
		parameter type T            = logic,
		parameter DP_GROUP          = 16,
		parameter ENGINE_ID         = 0,
		parameter STATE_WIDTH       = 16,
		localparam THRESHOLD        = 64
	)(
	input 	logic 					     engine_clk_i     ,
	input 	logic 					     engine_rst_ni    ,
	input 	logic 					     bus_clk_i        ,
	input 	logic 					     bus_rst_ni       ,
	input   logic 					     online_enable_i  ,
	input   config_engine_t              config_i         ,
	input 	timestamp_t                  global_time_i    ,
	input   logic                        power_gate       ,
	input   logic                        power_sleep      ,
	input 	logic   	[DP_GROUP-1:0]   group_clk_en_i   ,
	input 	state_t 	[DP_GROUP-1:0]   group_state_i    ,
	input   logic       [DP_GROUP-1:0]   group_spike_i    ,
	output 	state_t 	[DP_GROUP-1:0]   group_state_o    ,
	output 	weight_t 	[DP_GROUP-1:0]   group_weight_o   ,
	input   logic [$clog2(DP_GROUP)-1:0] online_group_id,
	input   logic                        time_stable_i    ,
	output  logic                        init_sequencer_o ,
	output  logic                        force_spike_op_o ,
	output  logic        [31:0        ]  online_data_o   ,
	SNE_EVENT_STREAM.dst  	             evt_dp_group_stream_dst,
	SNE_EVENT_STREAM.dst  	             evt_stream_memory_dst,
	SNE_EVENT_STREAM.dst  	             evt_stream_time_dst[2:0],
	SNE_EVENT_STREAM.src 	             evt_fifo_stream_src[DP_GROUP-1:0] 
);

localparam W = 9*WEIGHT_WIDTH; 

SNE_EVENT_STREAM evt_stream_memory_fifo_src (.clk_i(bus_clk_i));
SNE_EVENT_STREAM evt_stream_memory_kernel_src (.clk_i(bus_clk_i));

MEMORY_PORT #(.AW(SEQ_ADDR_WIDTH),.DW(STATE_WIDTH),.CW(1)) state_read[DP_GROUP-1:0]  (.clk(engine_clk_i));
MEMORY_PORT #(.AW(SEQ_ADDR_WIDTH),.DW(STATE_WIDTH),.CW(1)) state_write[DP_GROUP-1:0] (.clk(engine_clk_i));
MEMORY_PORT #(.AW(8),.DW(36*DP_GROUP),.CW(1))              kernel_read_src           (.clk(engine_clk_i));

logic [DP_GROUP-1:0]                    silence_neuron;
logic [YID_WIDTH+XID_WIDTH-1:0]          spike_id;

logic [DP_GROUP-1:0][WEIGHT_WIDTH-1:0]   gn_weight    ;
logic [DP_GROUP-1:0][WEIGHT_WIDTH-1:0]   fc_group_weight;

logic [DP_GROUP-1:0][SEQ_ADDR_WIDTH-1:0] fc_group_wr_addr, fc_group_rd_addr;
logic [DP_GROUP-1:0][SEQ_ADDR_WIDTH-1:0] opt_group_rd_addr, opt_group_wr_addr, opt_group_evt_addr;
logic [DP_GROUP-1:0] fc_group_wr_en, fc_group_rd_en, opt_group_wr_en;

logic [SEQ_ADDR_WIDTH-1:0] seq_raddr, seq_waddr;
logic seq_we, seq_re, seq_done, seq_ready, opt_ready, fc_ready;
logic seq_init, opt_init, fc_init;

logic [DP_GROUP-1:0][SEQ_ADDR_WIDTH-1:0] sequencer_addr;
logic [2:0] init_sequencer;
logic init;
logic fc_done;

logic [DP_GROUP-1:0] group_clk_en;

logic spike_grant_i;

assign init     = evt_dp_group_stream_dst.valid & spike_grant_i;

spike_t 	[DP_GROUP-1:0] evt_spike;

logic 	[DP_GROUP-1:0] evt_ready, evt_valid;

assign spike_id = evt_dp_group_stream_dst.evt & 16'hFFFF;

logic [$clog2(DP_GROUP)-1:0] online_group_id_q;

assign online_data_o = group_state_o[online_group_id_q];

for(genvar i=0 ; i<DP_GROUP; i++) begin: floating_kernel
	floating_kernel #(
		.NEURON_ID_WIDTH(XID_WIDTH+YID_WIDTH),
		.WEIGHTS_WIDTH  (WEIGHT_WIDTH       ),
		.GROUP_ID       (ENGINE_ID*DP_GROUP+i),
		.SEQ_ADDR_WIDTH (SEQ_ADDR_WIDTH     )
		)i_floating_kernel (
		.clk_i 				(engine_clk_i 					),
		.rst_ni 			(engine_rst_ni					),
		.clk_en_i 			(group_clk_en[i] 				),
		.sequencer_addr_i	(sequencer_addr[i]   			),
		.config_i           (config_i                       ),
		.neuron_addr_i      (spike_id                       ),
		.floating_kernel_i	(kernel_read_src.data[(i+1)*W-1:i*W]),
		.silence_neuron_o   (silence_neuron[i]				),
		.gn_weight_o        (gn_weight[i]					)
	);
	assign evt_spike[i].operation = EVT_SPIKE;
	assign evt_spike[i].unused    = 0;
	assign evt_spike[i].cid    	  = global_time_i;
	assign evt_ready[i]           = evt_fifo_stream_src[i].ready;
	always_comb begin
		group_state_o[i]      = state_read[i].data;
		state_write[i].data   = group_state_i[i];
		group_clk_en[i]       = group_clk_en_i[i];
		if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].online) begin
			state_read[i].addr   = config_i.online_addr[SEQ_ADDR_WIDTH-1:0];
			state_read[i].enable = 1'b1;
			state_write[i].addr  = '0;
			state_write[i].enable= 1'b0;
			evt_spike[i].yid = '0;
		    evt_spike[i].xid = '0;
		    evt_valid[i]     = '0;
		    group_weight_o[i] = 0; 
		    group_clk_en[i]   = online_enable_i ? (i==online_group_id):0;
		end else begin
			if((evt_dp_group_stream_dst.evt.dp_data.dp_operation==`RST_OP)|(evt_dp_group_stream_dst.evt.dp_data.dp_operation==`UPDATE_OP)) begin
				state_read[i].addr   = seq_raddr;
				state_read[i].enable = seq_re;
				state_write[i].addr   = seq_waddr;
				state_write[i].enable = seq_we;
				evt_spike[i].yid = seq_waddr[SEQ_ADDR_WIDTH-1:SEQ_ADDR_WIDTH/2];
			    evt_spike[i].xid = seq_waddr[SEQ_ADDR_WIDTH/2-1:0];
			    evt_valid[i]     = (seq_we & group_spike_i[i]);
			    group_weight_o[i] = 0; 
			    // force_spike_op_o  = 0;
			end else begin 
				if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==`FC) begin 
					state_read[i].addr    = fc_group_rd_addr[i];
					state_read[i].enable  = fc_group_rd_en[i];
					state_write[i].addr   = fc_group_wr_addr[i];
					state_write[i].enable = fc_group_wr_en[i];
					evt_spike[i].yid = fc_group_wr_addr[i][SEQ_ADDR_WIDTH-1:SEQ_ADDR_WIDTH/2];
					evt_spike[i].xid = fc_group_wr_addr[i][SEQ_ADDR_WIDTH/2-1:0];
					evt_valid[i]     = (fc_group_wr_en[i]& group_spike_i[i]);
					group_weight_o[i]   = fc_group_weight[i];
					// force_spike_op_o    = 1;
				end else if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==`OPT_CONV) begin 
					state_read[i].addr   = opt_group_rd_addr[i];
					state_read[i].enable  = 1'b1 ;
					state_write[i].addr   =opt_group_wr_addr[i];
					state_write[i].enable =opt_group_wr_en[i];
					evt_spike[i].yid = opt_group_evt_addr[i][SEQ_ADDR_WIDTH-1:SEQ_ADDR_WIDTH/2];
					evt_spike[i].xid = opt_group_evt_addr[i][SEQ_ADDR_WIDTH/2-1:0];
					evt_valid[i]     = opt_group_wr_en[i] & ((silence_neuron[i]))& group_spike_i[i];
					// force_spike_op_o  = 0;
					group_weight_o[i] = gn_weight[i]; 
				end else begin 
					state_read[i].addr   = seq_raddr;
					state_read[i].enable = seq_re;
					state_write[i].addr   = seq_waddr;
					state_write[i].enable = seq_we;
					evt_spike[i].yid = seq_waddr[SEQ_ADDR_WIDTH-1:SEQ_ADDR_WIDTH/2];
					evt_spike[i].xid = seq_waddr[SEQ_ADDR_WIDTH/2-1:0];
					evt_valid[i]     = seq_we & ((silence_neuron[i]))& group_spike_i[i];
					group_weight_o[i] = gn_weight[i]; 
					// force_spike_op_o  = 0;
				end
			end
		end
	end 
	assign sequencer_addr[i]    = {evt_fifo_stream_src[i].evt.spike.yid[SEQ_ADDR_WIDTH/2-1:0],evt_fifo_stream_src[i].evt.spike.xid[SEQ_ADDR_WIDTH/2-1:0]};
end: floating_kernel
// endgenerate

always_comb begin 
	if((evt_dp_group_stream_dst.evt.dp_data.dp_operation==`RST_OP)|(evt_dp_group_stream_dst.evt.dp_data.dp_operation==`UPDATE_OP)) begin
		evt_dp_group_stream_dst.ready    = seq_ready & spike_grant_i;
		seq_init                         = init;
	    fc_init                          = 0;
	    opt_init                         = 0;
	    force_spike_op_o                 = 0;
	    kernel_read_src.addr             = evt_dp_group_stream_dst.evt.dp_data.cid;
	    init_sequencer_o                 = init_sequencer[1];
	end else begin 
		if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==`FC) begin 
			evt_dp_group_stream_dst.ready    = fc_ready & spike_grant_i;
			fc_init                          = init;
			seq_init                         = 0;
	    	opt_init                         = 0;
	    	force_spike_op_o                 = 1'b1;
	    	kernel_read_src.addr             = evt_dp_group_stream_dst.evt.dp_data.cid;
	    	init_sequencer_o                 = init_sequencer[0];
		end else if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==`OPT_CONV) begin 
			evt_dp_group_stream_dst.ready    = opt_ready & spike_grant_i;
			opt_init                         = init;
			seq_init                         = 0;
	    	fc_init                          = 0;
	    	force_spike_op_o                 = 0;
	    	kernel_read_src.addr             = evt_dp_group_stream_dst.evt.dp_data.cid;
	    	init_sequencer_o                 = init_sequencer[2];
		end else if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer==`DEFAULT) begin 
			evt_dp_group_stream_dst.ready    = seq_ready & spike_grant_i;
			seq_init                         = init;
	    	fc_init                          = 0;
	    	opt_init                         = 0;
	    	force_spike_op_o                 = 0;
	    	kernel_read_src.addr             = evt_dp_group_stream_dst.evt.dp_data.cid;
	    	init_sequencer_o                 = init_sequencer[1];
		end else begin
			evt_dp_group_stream_dst.ready    = seq_ready & spike_grant_i;
			seq_init                         = init;
	    	fc_init                          = 0;
	    	opt_init                         = 0;
	    	force_spike_op_o                 = 0;
	    	kernel_read_src.addr             = evt_dp_group_stream_dst.evt.dp_data.cid;
	    	init_sequencer_o                 = init_sequencer[1];
		end 
	end
end

// redirect data towards the memory_kernel or towards the memory_fifo
always_comb begin : proc_memory_stream_demux
	evt_stream_memory_fifo_src.evt     = evt_stream_memory_dst.evt;
	evt_stream_memory_kernel_src.evt   = evt_stream_memory_dst.evt;
	if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].layer == `FC ) begin
		evt_stream_memory_fifo_src.valid   = evt_stream_memory_dst.valid;
		evt_stream_memory_dst.ready        = evt_stream_memory_fifo_src.ready;
		evt_stream_memory_kernel_src.valid = 0;
	end else begin 
		evt_stream_memory_fifo_src.valid   = 0;
		evt_stream_memory_dst.ready        = evt_stream_memory_kernel_src.ready;
		evt_stream_memory_kernel_src.valid = evt_stream_memory_dst.valid;
	end	 
end


always_ff @(posedge engine_clk_i or negedge engine_rst_ni) begin : proc_online_group_id_q
	if(~engine_rst_ni) begin
		online_group_id_q <= 0;
	end else begin
		online_group_id_q <= online_group_id;
	end
end

evt_weight_fifo #(
	.T         (T             ), 
	.DP_GROUP  (DP_GROUP      ), 
	.ADDR_WIDTH(SEQ_ADDR_WIDTH+1),
	.DEC_EL_FIFO_DEPTH(FC_FIFO_DEPTH),
	// .THRESHOLD         
	.THRESHOLD (THRESHOLD     )
	) i_evt_weight_fifo(
	.bus_clk_i            (bus_clk_i				 ),
	.bus_rst_ni           (bus_rst_ni				 ),
	.engine_clk_i         (engine_clk_i				 ),
	.spike_evt_i          (evt_dp_group_stream_dst.evt),
	.engine_rst_ni        (engine_rst_ni			 ),
	.init_i               (fc_init                   ),
	.time_stable_i        (time_stable_i             ),
	.init_sequencer_o     (init_sequencer[0]         ),
	.spike_grant_i        (spike_grant_i             ),
	.done_o               (fc_done					 ),
	.ready_o              (fc_ready                  ),
	.group_rd_addr_o      (fc_group_rd_addr			 ),
	.group_wr_addr_o      (fc_group_wr_addr			 ),
	.group_rd_en_o        (fc_group_rd_en			 ),
	.group_wr_en_o        (fc_group_wr_en			 ),
	.group_weight_o       (fc_group_weight 			 ),
	.evt_stream_memory_dst(evt_stream_memory_fifo_src),
	.evt_stream_time_dst  (evt_stream_time_dst[0]    )
	);
evt_memory_subsystem #(
	.T(T),
	.ENGINE_ID       (ENGINE_ID),
	.DP_GROUP        (DP_GROUP),
	.STATE_DATA_WIDTH(STATE_WIDTH)
	)i_evt_memory_subsystem(
	.bus_clk_i   	(bus_clk_i					 ),
	.bus_rst_ni  	(bus_rst_ni					 ),
	.config_i       (config_i                    ),
	.power_gate     (power_gate                  ),
	.power_sleep    (power_sleep                 ),
	.engine_clk_i	(engine_clk_i				 ),
	.engine_rst_ni	(engine_rst_ni				 ),
	.group_clk_en_i	(group_clk_en 				 ),
	.kernel_read_dst(kernel_read_src             ),
	.state_read     (state_read[DP_GROUP-1:0]    ),
	.state_write    (state_write[DP_GROUP-1:0]   ),
	.evt_stream_memory_dst(evt_stream_memory_kernel_src)
	);
	
evt_sequencer #(
	.ADDR_WIDTH(SEQ_ADDR_WIDTH), .ENGINE_ID(ENGINE_ID)
	)i_evt_sequencer (
	.clk_i 		  (engine_clk_i  ),
	.rst_ni       (engine_rst_ni ),
	.init_i       (seq_init      ),
	.spike_grant_i(spike_grant_i ),
	.config_i     (config_i      ),
	.time_stable_i(time_stable_i             ),
	.init_sequencer_o(init_sequencer[1]       ),
	.mem_waddr_o  (seq_waddr     ),
	.mem_we_o     (seq_we        ),
	.mem_raddr_o  (seq_raddr     ),
	.mem_re_o     (seq_re        ),
	.ready_o      (seq_ready     ),
	.done_o       (seq_done      ),
	.evt_stream_time_dst  (evt_stream_time_dst[1]    )
	);

evt_opt_sequencer #(
	.STREAM_ADDR_WIDTH(XID_WIDTH+YID_WIDTH),
	.NEURON_GROUP     (DP_GROUP),
	.ENGINE_ID        (ENGINE_ID),
	.DP_GROUP         (DP_GROUP),
	.SEQ_ADDR_WIDTH   (SEQ_ADDR_WIDTH)
	) i_evt_opt_sequencer(
	.enable_i 	  (1'b1           ),
	.clk_i 		  (engine_clk_i       ),
	.rst_ni 	  (engine_rst_ni      ),
	.init_i       (opt_init           ),
	.config_i     (config_i           ),
	.time_stable_i        (time_stable_i             ),
	.init_sequencer_o     (init_sequencer[2]       ),
	.done_o             (),
	.count_o            (),
	.spike_grant_i(spike_grant_i      ),
	.spike_evt_i  (1'b1               ),
	.spike_in_ID_i(spike_id           ),
	.ready_o      (opt_ready          ),
	.wr_en_o 	  (opt_group_wr_en    ),
	.wr_addr_group_o(opt_group_wr_addr),
	.rd_addr_group_o(opt_group_rd_addr),
	.wr_fifo_addr_o(opt_group_evt_addr),
	.evt_stream_time_dst  (evt_stream_time_dst[2]    )
	);
	
evt_mapper_src #(
	.DP_GROUP(DP_GROUP)
	) i_evt_mapper_src(
	.engine_clk_i(engine_clk_i),
	.engine_rst_ni(engine_rst_ni),
	.spike_grant_o(spike_grant_i),
	.evt_valid(evt_valid),
	.evt_ready(evt_ready),
	.evt_spike(evt_spike),
	.evt_fifo_stream_src(evt_fifo_stream_src)
	);
endmodule : evt_memory_sequencer