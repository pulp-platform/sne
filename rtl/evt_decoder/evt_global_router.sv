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
module evt_global_router

	import sne_evt_stream_pkg::DST_ENGINE ;
	import sne_evt_stream_pkg::DST_MEMORY ;
	import sne_evt_stream_pkg::EOP ;

	#(

	parameter type T            = logic,
	parameter DEC_EL_FIFO_DEPTH = 2 

	)(

	input  logic              bus_clk_i           ,  // Clock
	input  logic              bus_rst_ni          ,  // Asynchronous reset active low

	input  logic              engine_clk_i        ,  // Clock
	input  logic              engine_rst_ni       ,  // Asynchronous reset active low

	input  logic              ack_error_i         , 

	//--- destination event stream ports
	SNE_EVENT_STREAM.dst    evt_stream_dst        ,

	//--- source event stream ports
	SNE_EVENT_STREAM.src    evt_stream_engine_src  ,
	SNE_EVENT_STREAM.src    evt_stream_memory_src

);

	SNE_EVENT_STREAM evt_stream_engine_int(.clk_i(bus_clk_i));

T            evt_pkt_header_q;
logic [15:0] evt_pkt_ptr_q;
logic        store_header_s;
logic        evt_pkt_end_s;
logic        evt_pkt_muxed_ready;
logic        valid_transaction_s;
logic        dst_error_s;
logic        any_error_s;
logic        route_data_s;
logic        packet_tail_s;

enum logic [3:0] {
	
	RESET,
	OPEN_PKT,
	VERIFY_HEADER,
	ROUTE,
	CLOSE_PKT,
	ERROR

}PS,NS;

always_ff @(posedge bus_clk_i or negedge bus_rst_ni) begin : proc_PS
	if(~bus_rst_ni) begin
		PS <= RESET;
	end else begin
		PS <= NS;
	end
end

always_comb begin : proc_NS
	case (PS)
		RESET     : begin
			if (evt_stream_dst.valid) begin
				NS = OPEN_PKT;
			end else begin
				NS = RESET;
			end
		end

		OPEN_PKT  : begin
			NS = VERIFY_HEADER;
		end

		VERIFY_HEADER: begin
			if (~any_error_s) begin
				NS = ROUTE;
			end else begin
				NS = ERROR;
			end
		end

		ROUTE     : begin
			if (evt_pkt_end_s) begin
				NS = CLOSE_PKT;
			end else begin
				NS = ROUTE;
			end
		end

		CLOSE_PKT : begin
			NS = RESET;
		end

		ERROR     : begin
			if (ack_error_i) begin
				NS = RESET;
			end else begin
				NS = ERROR;
			end
		end
		default : NS = ERROR;
	endcase
end

always_comb begin : proc_OUT
	case (PS)
		RESET     : begin
			store_header_s          = 1'b0;
			evt_stream_dst.ready = 1'b0;
			route_data_s            = 1'b0;
		end

		OPEN_PKT  : begin
			store_header_s          = 1'b1;
			evt_stream_dst.ready = 1'b0;
			route_data_s            = 1'b0;
		end

		VERIFY_HEADER  : begin
			store_header_s          = 1'b0;
			evt_stream_dst.ready = 1'b0;
			route_data_s            = 1'b0;
		end

		ROUTE     : begin
			store_header_s          = 1'b0;
			evt_stream_dst.ready = evt_pkt_muxed_ready;
			route_data_s            = 1'b1;
		end

		CLOSE_PKT : begin
			store_header_s          = 1'b0;
			evt_stream_dst.ready = 1'b0;
			route_data_s            = 1'b0;
		end

		ERROR     : begin
			store_header_s          = 1'b0;
			evt_stream_dst.ready = 1'b0;
			route_data_s            = 1'b0;
		end

		default   : begin
			store_header_s          = 1'b0;
			evt_stream_dst.ready = 1'b0;
			route_data_s            = 1'b0;
		end
	endcase
end

always_comb begin : proc_ROUTE
	case (evt_pkt_header_q.header.gdst)

		DST_ENGINE: begin
			packet_tail_s       = (evt_stream_dst.valid & evt_stream_dst.evt.spike.operation == EOP);
			evt_stream_engine_int.valid  = evt_stream_dst.valid && route_data_s && (~packet_tail_s);
			evt_stream_engine_int.evt    = evt_stream_dst.evt;
			evt_stream_memory_src.valid  = 1'b0;
			evt_stream_memory_src.evt    = 32'h00000000;
			evt_pkt_muxed_ready          = evt_stream_engine_int.ready || packet_tail_s;
			dst_error_s                  = 1'b0;
		end

		DST_MEMORY: begin
			evt_stream_engine_int.valid  = 1'b0;
			evt_stream_engine_int.evt    = 32'h00000000;
			evt_stream_memory_src.valid  = evt_stream_dst.valid && route_data_s;
			evt_stream_memory_src.evt    = evt_stream_dst.evt;
			evt_pkt_muxed_ready          = evt_stream_memory_src.ready;
			dst_error_s                  = 1'b0;
			packet_tail_s                = 1'b0;
		end

		default  : begin
			evt_stream_engine_int.valid  = 1'b0;
			evt_stream_engine_int.evt    = 32'h00000000;
			evt_stream_memory_src.valid  = 1'b0;
			evt_stream_memory_src.evt    = 32'h00000000;
			evt_pkt_muxed_ready          = 1'b0;
			dst_error_s                  = 1'b1;
			packet_tail_s                = 1'b1;
		end
	endcase
end

assign any_error_s = dst_error_s;

// register to store the packed header
always_ff @(posedge bus_clk_i or negedge bus_rst_ni) begin : proc_evt_pkt_header_q
	if(~bus_rst_ni) begin
		evt_pkt_header_q <= 0;
	end else if (store_header_s) begin
		evt_pkt_header_q <= evt_stream_dst.evt;
	end 
end


logic valid_engine_tran_s;

assign valid_engine_tran_s = evt_stream_engine_int.valid && evt_stream_engine_int.ready;

logic valid_memory_tran_s;

assign valid_memory_tran_s = evt_stream_memory_src.valid && evt_stream_memory_src.ready;

assign valid_transaction_s = (valid_engine_tran_s || valid_memory_tran_s) && ~store_header_s && route_data_s;


assign evt_pkt_end_s = (valid_transaction_s && (evt_pkt_ptr_q >= evt_pkt_header_q.header.length)) | packet_tail_s;

// counter to track the packet words. Increment the counter every time a new word of the packed is transmitted
always_ff @(posedge bus_clk_i or negedge bus_rst_ni) begin : proc_evt_pkt_ptr_q
	if(~bus_rst_ni) begin
		evt_pkt_ptr_q <= 0;
	end else if (valid_transaction_s) begin
		evt_pkt_ptr_q <= evt_pkt_ptr_q + 1'b1;
	end else if (store_header_s) begin
		evt_pkt_ptr_q <= 1'b0;
	end
end


//--- dual clock event fifo, engine stream crossing the clock domain going from bus_clk to engine_clock 
evt_cdc_fifo #(

		.T    ( T                  ),
		.DEPTH( DEC_EL_FIFO_DEPTH  )

	) i_evt_cdc_decode_que (

		.dst_clk_i ( bus_clk_i                ),
		.dst_rst_ni( bus_rst_ni               ),
		.dst_stream( evt_stream_engine_int    ),

		.src_clk_i ( engine_clk_i             ),
		.src_rst_ni( engine_rst_ni            ),
		.src_stream( evt_stream_engine_src    )
);

endmodule