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
module evt_crossbar #(

	parameter  type T         = logic,
	parameter  SRC_PORTS      = 8,
	parameter  DST_PORTS      = 8,
	localparam DST_ADDR_WIDTH = (DST_PORTS > 1) ? $clog2(DST_PORTS) : 1

	)(

    input logic clk_i,
    input logic rst_ni,

	input logic [SRC_PORTS-1:0][DST_ADDR_WIDTH-1:0] connection_matrix_i,

	//--- source event stream ports
	SNE_EVENT_STREAM.src    evt_stream_src[SRC_PORTS-1:0],

	//--- destination event stream ports
	SNE_EVENT_STREAM.dst    evt_stream_dst[DST_PORTS-1:0]
	
);

	T        [DST_PORTS-1:0]                data_dst_out;
	logic    [DST_PORTS-1:0]                valid_dst_out;
	logic    [DST_PORTS-1:0]                valid_mask_clean;
	logic    [DST_PORTS-1:0][SRC_PORTS-1:0] ready_dev_mask;

	logic    [SRC_PORTS-1:0]                ready_dev;

	//--- generate DST_PORTS destination nodes. They collect incoming streams
	for (genvar i = 0; i < DST_PORTS; i++) begin : i_evt_crossbar_dst_dev

			evt_crossbar_dst_dev #(

			.T        ( T          ),
			.SRC_PORTS( SRC_PORTS  )

			)i_evt_crossbar_dst_dev(

			.data_i              ( evt_stream_dst[i].evt  ),
			.valid_i             ( evt_stream_dst[i].valid ),
			.ready_o             ( evt_stream_dst[i].ready ),

			.data_o              ( data_dst_out[i]         ),
			.valid_o             ( valid_dst_out[i]        ),
			.ready_i             ( ready_dev               ),

			.ready_dev_mask_i    ( ready_dev_mask[i]       ),
			.valid_mask_clean_o  ( valid_mask_clean[i]     )
			          
			); 
	end : i_evt_crossbar_dst_dev

	/* generate SRC_PORTS source nodes. They select one destination source and stream it out
	multiple source nodes can be attached to the same destination device, the crossbar can act
	as a multiplexer, a transaction is considered as "complete" when all source devices provide 
	the ready signal to the related destination devices; it can last multiple cycles */
	for (genvar j = 0; j < SRC_PORTS; j++) begin : i_evt_crossbar_src_dev
		evt_crossbar_src_dev#(

		.T        ( T         ),
		.DST_PORTS( DST_PORTS )

		)i_evt_crossbar_src_dev(

		.clk_i              ( clk_i                   ),
		.rst_ni             ( rst_ni                  ),

		.data_i             ( data_dst_out            ),
		.valid_i            ( valid_dst_out           ),
		.ready_o            ( ready_dev[j]            ),

		.ready_i            ( evt_stream_src[j].ready ),
		.data_o             ( evt_stream_src[j].evt  ),
		.valid_o            ( evt_stream_src[j].valid ),
		
		.valid_mask_clean_i ( valid_mask_clean        ),
		.addr_i             ( connection_matrix_i[j]  )

		);
	end : i_evt_crossbar_src_dev

	//--- tell to each master what slave "ready" signals to sense to generate the master "ready" signal
	always_comb begin : proc_mask_gen
		for (logic [DST_PORTS-1:0] m = 0; m < DST_PORTS; m++) begin
			for (logic [SRC_PORTS-1:0] s = 0; s < SRC_PORTS; s++) begin
				if((connection_matrix_i[s] == m)) begin
					ready_dev_mask[m][s] = 1'b1;
				end else begin
					ready_dev_mask[m][s] = 1'b0;
				end
				 
			end
		end
	end

endmodule // DATA_XBAR
