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
module evt_fifo #(

    parameter type T              = logic , // Vivado requires a default value for type parameters.
    parameter  int unsigned DEPTH = 8 // depth can be arbitrary from 0 to 2**32

) (

    input  logic         clk_i,          // Clock
    input  logic         rst_ni,         // Asynchronous active-low reset
    input  logic         clr_i,          // Synchronous clear
    input  logic         testmode_i,     // Test mode to bypass clock gating
    SNE_EVENT_STREAM.src src_stream,
    SNE_EVENT_STREAM.dst dst_stream

);

    logic   fifo_empty,
            fifo_full;

    fifo_v2 #(

        .FALL_THROUGH   ( 1'b0                           ),
        .DATA_WIDTH     ( 32                             ),
        .DEPTH          ( DEPTH                          ),
        .dtype          ( T                              )

    ) i_fifo (

        .clk_i          ( clk_i                          ),
        .rst_ni         ( rst_ni                         ),
        .flush_i        ( clr_i                          ),
        .testmode_i     ( testmode_i                     ),
        .full_o         ( fifo_full                      ),
        .empty_o        ( fifo_empty                     ),
        .alm_full_o     (                                ),
        .alm_empty_o    (                                ),
        .data_i         ( dst_stream.evt                 ),
        .push_i         ( dst_stream.valid & ~fifo_full  ),
        .data_o         ( src_stream.evt                 ),
        .pop_i          ( src_stream.ready & ~fifo_empty )

    );

    assign dst_stream.ready = ~fifo_full;
    assign src_stream.valid = ~fifo_empty;

endmodule