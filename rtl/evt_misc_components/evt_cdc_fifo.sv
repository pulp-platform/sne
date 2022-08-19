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
 module evt_cdc_fifo  #(

        parameter type T                    = logic,
        parameter  int unsigned DEPTH       = 8, // depth can be arbitrary from 0 to 2**32
        localparam int unsigned LOG_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
    )(

    input  logic               src_clk_i,   // Clock
    input  logic               src_rst_ni,  // Asynchronous IDLE active low

    input  logic               dst_clk_i,   // Clock
    input  logic               dst_rst_ni,  // Asynchronous IDLE active low

    SNE_EVENT_STREAM.src       src_stream,
    SNE_EVENT_STREAM.dst       dst_stream
    
);


//--- this DC fifo need critical time constraints. 
//--- Refer to what indicated in cdc_fifo_2phase.sv
cdc_fifo_gray #(
    .T        ( T         ),
    .LOG_DEPTH( LOG_DEPTH )

    ) i_cdc_fifo_gray (

    .src_rst_ni ( dst_rst_ni       ),
    .src_clk_i  ( dst_clk_i        ),

    .src_data_i ( dst_stream.evt   ),
    .src_valid_i( dst_stream.valid ),
    .src_ready_o( dst_stream.ready ),

    .dst_rst_ni ( src_rst_ni       ),
    .dst_clk_i  ( src_clk_i        ),

    .dst_data_o ( src_stream.evt   ),
    .dst_valid_o( src_stream.valid ),
    .dst_ready_i( src_stream.ready )

);

endmodule // evt_fifo