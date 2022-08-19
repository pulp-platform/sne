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

 //this moule is the only destination for streams directed to the engine
module evt_engine_router 

	import sne_evt_stream_pkg::EVT_IDLE      ;
	import sne_evt_stream_pkg::EVT_SPIKE     ;
	import sne_evt_stream_pkg::EVT_ACCUMULATE;
	import sne_evt_stream_pkg::EVT_WIPE      ;
	import sne_evt_stream_pkg::EVT_TIME      ;
	import sne_evt_stream_pkg::EVT_SYNCH     ;
	import sne_evt_stream_pkg::EVT_UPDATE    ;
	import sne_evt_stream_pkg::config_engine_t;
	#(	parameter ENGINE_ID = 0,
		parameter DP_GROUP  = 16
	)(

	input  logic              clk_i        ,  // Clock
	input  logic              rst_ni       ,  // Asynchronous reset active low
	input  config_engine_t    config_i     ,

	//--- destination event stream ports
	SNE_EVENT_STREAM.dst    evt_stream_engine_dst,

	//--- source event stream ports
	SNE_EVENT_STREAM.src    evt_stream_time_src  ,
	SNE_EVENT_STREAM.src    evt_stream_spike_src
	
);
	SNE_EVENT_STREAM evt_stream_engine_src (.clk_i(clk_i));
	SNE_EVENT_STREAM evt_continuous_time_src (.clk_i(clk_i));
	SNE_EVENT_STREAM evt_refresh_insert_src (.clk_i(clk_i));

	evt_time_inserter i_evt_time_insert(
		.clk_i              (clk_i),
		.rst_ni             (rst_ni),
		.enable_i           (config_i.reg2hw.cfg_error_i[ENGINE_ID].time_insert_enable),
		.evt_time_stream_dst(evt_stream_engine_dst),
		.evt_time_stream_src(evt_continuous_time_src)
	);

	evt_refresh_insert#(.REFRESH_RATE(256)) i_evt_refresh_insert(
		.clk_i              (clk_i),
		.rst_ni             (rst_ni),
		.enable_i           (config_i.reg2hw.cfg_error_i[ENGINE_ID].refresh_enable),
		.evt_time_stream_dst(evt_continuous_time_src),
		.evt_time_stream_src(evt_refresh_insert_src)
	);

	evt_spike_filter#(.ENGINE_ID(ENGINE_ID), .DP_GROUP(DP_GROUP)) i_evt_spike_filter(
		.clk_i              (clk_i),
		.rst_ni             (rst_ni),
		.config_i           (config_i),
		.enable_i           (config_i.reg2hw.cfg_error_i[ENGINE_ID].spike_filter_enable),
		.evt_time_stream_dst(evt_refresh_insert_src),
		.evt_time_stream_src(evt_stream_engine_src)
	);


	logic spike_s;
	logic time_s;
	logic error_s;

// map the stream "operation" field to FSM input signals
always_comb begin : proc_decode_input_op
	case (evt_stream_engine_src.evt.spike.operation)

		EVT_IDLE       : begin
			spike_s  = 1'b1;
			time_s   = 1'b0;
			error_s  = 1'b0;
		end

		EVT_SPIKE      : begin
			spike_s  = 1'b1;
			time_s   = 1'b0;
			error_s  = 1'b0;
		end

		EVT_ACCUMULATE : begin
			spike_s  = 1'b1;
			time_s   = 1'b0;
			error_s  = 1'b0;
		end

		EVT_WIPE       : begin
			spike_s  = 1'b1;
			time_s   = 1'b0;
			error_s  = 1'b0;
		end

		EVT_TIME       : begin
			spike_s  = 1'b0;
			time_s   = 1'b1;
			error_s  = 1'b0;
		end

		EVT_SYNCH      : begin
			spike_s  = 1'b0;
			time_s   = 1'b1;
			error_s  = 1'b0;
		end

		EVT_UPDATE    : begin
			spike_s  = 1'b1;
			time_s   = 1'b0;
			error_s  = 1'b0;
		end

		default        : begin
			spike_s  = 1'b0;
			time_s   = 1'b0;
			error_s  = 1'b1;
		end
	endcase
end

enum logic [3:0] {

	RESET,
	FETCH_EVT,
	PROCESS_SPIKE,
	UPDATE_TIME,
	DONE,
	ERROR

}PS,NS;

always_ff @(posedge clk_i or negedge rst_ni) begin : proc_PS
	if(~rst_ni) begin
		PS <= RESET;
	end else begin
		PS <= NS;
	end
end

always_comb begin : proc_NS
	NS = PS;
	case (PS)

		RESET         : begin
			if (evt_stream_engine_src.valid) begin
				NS = FETCH_EVT;
			end else begin
				NS = RESET;
			end
		end

		// determine the type of operation
		FETCH_EVT     : begin
			if (evt_stream_engine_src.valid) begin
				unique if (spike_s) begin
					NS = PROCESS_SPIKE;
				end else if (time_s) begin
					NS = UPDATE_TIME;
				end else begin
					NS = ERROR;
				end
			end else begin
				NS = FETCH_EVT;
			end
		end

		PROCESS_SPIKE : begin
			if (evt_stream_spike_src.ready) begin
				NS = DONE;
			end else begin
				NS = PROCESS_SPIKE;
			end
		end

		UPDATE_TIME   : begin
			if (evt_stream_time_src.ready) begin
				NS = DONE;
			end else begin
				NS = UPDATE_TIME;
			end
		end

		DONE          : begin
			NS = FETCH_EVT;
		end

		ERROR         : begin
			NS = RESET;
		end

		default : NS = RESET/* default */;
	endcase
end

always_comb begin : proc_outputs
	case (PS)

		RESET         : begin
			evt_stream_time_src.valid   = 1'b0;
			evt_stream_spike_src.valid  = 1'b0;
			evt_stream_engine_src.ready = 1'b0;
			evt_stream_time_src.evt     = 0;
			evt_stream_spike_src.evt    = 0;
		end

		FETCH_EVT     : begin
			evt_stream_time_src.valid   = 1'b0;
			evt_stream_spike_src.valid  = 1'b0;
			evt_stream_engine_src.ready = 1'b0;
			evt_stream_time_src.evt     = 0;
			evt_stream_spike_src.evt    = 0;
		end

		PROCESS_SPIKE : begin
			evt_stream_time_src.valid   = 1'b0;
			evt_stream_spike_src.valid  = 1'b1;
			evt_stream_engine_src.ready = 1'b0;
			evt_stream_time_src.evt     = 0;
			evt_stream_spike_src.evt    = evt_stream_engine_src.evt;
		end

		UPDATE_TIME   : begin
			evt_stream_time_src.valid   = 1'b1;
			evt_stream_spike_src.valid  = 1'b0;
			evt_stream_engine_src.ready = 1'b0;
			evt_stream_time_src.evt     = evt_stream_engine_src.evt;
			evt_stream_spike_src.evt    = 0;
		end

		DONE          : begin
			evt_stream_time_src.valid   = 1'b0;
			evt_stream_spike_src.valid  = 1'b0;
			evt_stream_engine_src.ready = 1'b1;
			evt_stream_time_src.evt     = 0;
			evt_stream_spike_src.evt    = 0;
		end

		ERROR         : begin
			evt_stream_time_src.valid   = 1'b0;
			evt_stream_spike_src.valid  = 1'b0;
			evt_stream_engine_src.ready = 1'b1;
			evt_stream_time_src.evt     = 0;
			evt_stream_spike_src.evt    = 0;
		end

		default       : begin
			evt_stream_time_src.valid   = 1'b0;
			evt_stream_spike_src.valid  = 1'b0;
			evt_stream_engine_src.ready = 1'b0;
			evt_stream_time_src.evt     = 0;
			evt_stream_spike_src.evt    = 0;
		end 
	endcase
end

endmodule