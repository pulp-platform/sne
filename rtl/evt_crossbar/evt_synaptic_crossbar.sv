// endmodule
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
module evt_synaptic_crossbar #(

    parameter  type T         = logic,
    parameter  SRC_PORTS      = 4,
    parameter  DST_PORTS      = 4,
    parameter  ARBITERS       = DST_PORTS,

    localparam INT_PORTS = DST_PORTS,
    localparam ARB_PORTS = 2*DST_PORTS,
    localparam MID_PORTS = INT_PORTS + ARB_PORTS/2,

    localparam DST0_ADDR_WIDTH = ((DST_PORTS + ARB_PORTS/2) > 1) ? $clog2(DST_PORTS + ARB_PORTS/2) : 1,
    localparam DST1_ADDR_WIDTH = ((MID_PORTS) > 1) ? $clog2(MID_PORTS) : 1
)(

    input logic clk_i,
    input logic rst_ni,

    input logic [(INT_PORTS + ARB_PORTS)-1:0][DST0_ADDR_WIDTH-1:0] cfg_stage0_i,
    input logic [(SRC_PORTS + ARB_PORTS/2)-1:0][DST1_ADDR_WIDTH-1:0] cfg_stage1_i,

    input logic [2*ARBITERS-1:0] fwd_barrier_i,
    input logic [2*ARBITERS-1:0] synch_en_i,

    //--- source event stream ports
    SNE_EVENT_STREAM.src    evt_stream_src[SRC_PORTS-1:0],

    //--- destination event stream ports
    SNE_EVENT_STREAM.dst    evt_stream_dst[DST_PORTS-1:0]
);


SNE_EVENT_STREAM evt_stream_in[DST_PORTS + ARB_PORTS/2 -1:0](.clk_i(clk_i));
SNE_EVENT_STREAM evt_stream_out[SRC_PORTS + ARB_PORTS/2 -1:0](.clk_i(clk_i));
SNE_EVENT_STREAM evt_stream_arbint[INT_PORTS + ARB_PORTS -1:0](.clk_i(clk_i));
SNE_EVENT_STREAM evt_stream_mid[MID_PORTS -1:0](.clk_i(clk_i));
SNE_EVENT_STREAM evt_stream_mid_fifo[MID_PORTS -1:0](.clk_i(clk_i));

for (genvar i = 0; i < DST_PORTS; i++) begin: streamin
    `SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_in[i],evt_stream_dst[i])
end: streamin

for (genvar i = 0; i < ARB_PORTS/2; i++) begin: streamrec
    `SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_in[DST_PORTS+i],evt_stream_out[SRC_PORTS+i])
end: streamrec

evt_crossbar #(.T(T), .SRC_PORTS(INT_PORTS + ARB_PORTS), .DST_PORTS(DST_PORTS + ARB_PORTS/2)) i_evt_crossbar_in (
    .clk_i              (clk_i              ),
    .rst_ni             (rst_ni             ),
    .connection_matrix_i(cfg_stage0_i       ), 
    .evt_stream_src     (evt_stream_arbint  ),
    .evt_stream_dst     (evt_stream_in      )
);

for (genvar i = 0; i < INT_PORTS; i++) begin: streammid
    `SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_mid[i],evt_stream_arbint[i])
end: streammid

SNE_EVENT_STREAM evt_stream_arbint_synch[INT_PORTS + ARB_PORTS -1:0](.clk_i(clk_i));

for (genvar i = 0; i < ARBITERS; i++) begin: arbarray

    evt_synchronizer #(.DATA_T(T), .N(2)) i_evt_synchronizer (
        .clk_i         (clk_i                                                       ),
        .rst_ni        (rst_ni                                                      ),
        .fwd_barrier_i (fwd_barrier_i[1+2*i:2*i]          ), 
        .synch_en_i    (synch_en_i[1+2*i:2*i]             ), 
        .evt_stream_dst(evt_stream_arbint[1 + (INT_PORTS+2*i):(INT_PORTS+2*i)]      ),
        .evt_stream_src(evt_stream_arbint_synch[1 + (INT_PORTS+2*i):(INT_PORTS+2*i)])
    );

    evt_arbiter #(.DATA_T(T), .N_INP(2)) i_evt_arbiter (
        .clk_i         (clk_i                                      ),
        .rst_ni        (rst_ni                                     ),
        .evt_stream_dst(evt_stream_arbint_synch[1 + (INT_PORTS+2*i):(INT_PORTS+2*i)] ),
        .evt_stream_src(evt_stream_mid[INT_PORTS + i]              )
    );
end: arbarray

for(genvar i=0; i<MID_PORTS; i++) begin : mid_fifo
    evt_fifo #(.T(T), .DEPTH(2)) i_evt_fifo(
        .clk_i (clk_i),
        .rst_ni(rst_ni),
        .testmode_i(1'b0),
        .clr_i     (1'b0),
        .dst_stream(evt_stream_mid[i]),
        .src_stream(evt_stream_mid_fifo[i])
    );
end : mid_fifo

evt_crossbar #(.T(T), .SRC_PORTS(SRC_PORTS + ARB_PORTS/2), .DST_PORTS(MID_PORTS)) i_evt_crossbar_out (
    .clk_i              (clk_i              ),
    .rst_ni             (rst_ni             ),
    .connection_matrix_i(cfg_stage1_i       ), 
    .evt_stream_src     (evt_stream_out     ),
    .evt_stream_dst     (evt_stream_mid_fifo)
);

for (genvar i = 0; i < SRC_PORTS; i++) begin: streamout
    `SNE_EVENT_STREAM_ASSIGN_DST_SRC(evt_stream_src[i],evt_stream_out[i])
end: streamout



endmodule