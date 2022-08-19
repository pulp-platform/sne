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
module evt_kernel_memory_wrapper
	import sne_evt_stream_pkg::config_engine_t;
	import sne_evt_stream_pkg::uevent_t;
	import sne_evt_stream_pkg::spike_t;
	#(
		 parameter DP_GROUP = 16,
		 parameter type T = sne_evt_stream_pkg::uevent_t,
		 parameter ENGINE_ID = 0,
		 parameter DEC_EL_FIFO_DEPTH = 6
	)(
		input 	config_engine_t	config_i            ,
		input   logic           bus_clk_i           ,
		input   logic           bus_rst_ni          ,
		input   logic           kernel_clk_en_i     ,
		input 	logic 			engine_clk_i        ,
		input 	logic 			engine_rst_ni       ,
		MEMORY_PORT.read_dst 	kernel_read_dst     ,
		SNE_EVENT_STREAM.dst    evt_stream_memory_dst
	);

	SNE_EVENT_STREAM evt_stream_memory_src	(.clk_i(engine_clk_i));
	evt_cdc_fifo #(

		.T    ( T                  ),
		.DEPTH( DEC_EL_FIFO_DEPTH  )

	) i_evt_cdc_memory_fifo_left (

		.src_clk_i ( engine_clk_i                 ),
		.src_rst_ni( engine_rst_ni                ),
		.src_stream( evt_stream_memory_src        ),

		.dst_clk_i ( bus_clk_i                    ),
		.dst_rst_ni( bus_rst_ni                   ),
		.dst_stream( evt_stream_memory_dst        )

);
	logic [8:0] wr_addr_d, wr_addr_q;
	logic [31:0] wr_data_d, wr_data_q;
	logic        wr_en_d, wr_en_q;
	logic [1:0] mode_d, mode_q;

	typedef enum logic {INIT, RUN} state_t;
	state_t state_d, state_q;

	always_comb begin
		case(state_q)
			INIT : begin 
				if(evt_stream_memory_src.valid) begin
					state_d = RUN; 
				end else begin 
					state_d = INIT;
				end
			end 
			RUN : begin 
				if((wr_addr_q[7:0]==(config_i.reg2hw.cfg_slice_i[ENGINE_ID].channel+(config_i.reg2hw.cfg_slice_i[ENGINE_ID].channel>>3)))&wr_en_q) begin 
					state_d = INIT;
				end else begin 
					state_d = RUN;
				end
			end
		endcase 
	end

	always_comb begin 
		case(state_q)
			INIT : begin
				wr_en_d = 0;
				wr_addr_d = 0;
				wr_data_d = 0;
				mode_d    = 0; 
			end 
			RUN : begin
				wr_en_d = wr_en_q;
				wr_addr_d = wr_addr_q;
				wr_data_d = wr_data_q;
				mode_d    = mode_q; 
				if(evt_stream_memory_src.valid) begin
					wr_en_d   = 1'b1;
					wr_addr_d = wr_addr_q + 1;
					wr_data_d = evt_stream_memory_src.evt.weights;
					if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].kernel_reset) 
						wr_addr_d = 0; 
				end else begin
					wr_en_d   = 1'b0;
					wr_addr_d = wr_addr_q;
					wr_data_d = '0;
					if(config_i.reg2hw.cfg_slice_i[ENGINE_ID].kernel_reset) 
						wr_addr_d = 0;
				end
				if(wr_addr_q >= config_i.reg2hw.cfg_slice_i[ENGINE_ID].channel) begin 
					mode_d = 2'b10;
				end else begin
					mode_d = 2'b01;  
				end
			end
		endcase
	end
	assign evt_stream_memory_src.ready = 1'b1;


	always_ff @(posedge engine_clk_i or negedge engine_rst_ni) begin 
		if(~engine_rst_ni) begin
			wr_en_q   <= 1'b0;
			wr_data_q <= 0;
			wr_addr_q <= 0;
			mode_q    <= 0;
			state_q   <= INIT;
		end else begin
			wr_en_q   <= wr_en_d;
			wr_data_q <= wr_data_d;
			wr_addr_q <= wr_addr_d;
			mode_q    <= mode_d;
			state_q   <= state_d;
		end
	end


	MEMORY_PORT #(.AW(8), .DW(32), .CW(1))    weights_write  (.clk(engine_clk_i))         ;
    MEMORY_PORT #(.AW(8), .DW(36*DP_GROUP), .CW(1)) weights_read (.clk(engine_clk_i))        ;

    assign weights_read.addr = kernel_read_dst.addr;
    assign weights_read.enable   = kernel_read_dst.enable;
    assign kernel_read_dst.data = weights_read.data;
    assign weights_write.addr= (mode_q==2'b10) ? (wr_addr_q-config_i.reg2hw.cfg_slice_i[ENGINE_ID].channel-1):(wr_addr_q-1);
    assign weights_write.enable  = wr_en_q;
    assign weights_write.data= wr_data_q;


    evt_kernel_memory #(.NEURON_GROUP  (DP_GROUP), .CHANNEL_NUMBER(64)
    	) i_weights_kernel (
    	.clk_i        (engine_clk_i),
    	.rst_ni       (engine_rst_ni),
    	.mode_i       (mode_q),
    	.sel_i        (config_i.reg2hw.cfg_slice_i[ENGINE_ID].sel),
    	.weights_read (weights_read),
    	.weights_write(weights_write)
    	);

endmodule : evt_kernel_memory_wrapper