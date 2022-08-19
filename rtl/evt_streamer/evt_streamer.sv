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

module evt_streamer 
  import sne_evt_stream_pkg::config_system_sw_t;
  import sne_evt_stream_pkg::config_system_hw_t;
  #(

  parameter type T             = logic,
  parameter STREAMER_ID        = 0,
  parameter EVT_SRC_FIFO_DEPTH = 8,
  parameter EVT_DST_FIFO_DEPTH = 8

  )(

  input logic              system_clk_i       ,  
  input logic              system_rst_ni      ,  
  input logic              sne_clk_i          ,  
  input logic              sne_rst_ni         ,  
  input logic              evt_i              , 
  input logic              power_gate         ,
  input logic              power_sleep        ,
  // tcdm master port           
  output logic             tcdm_req_o         ,
  input  logic             tcdm_gnt_i         ,
  output logic [31:0]      tcdm_add_o         ,
  output logic             tcdm_wen_o         ,
  output logic [ 3:0]      tcdm_be_o          ,
  output logic [31:0]      tcdm_data_o        ,
  input  logic [31:0]      tcdm_r_data_i      ,
  input  logic             tcdm_r_valid_i     ,
  input  config_system_sw_t config_system_sw_i,
  output logic [31:0]      sta_main_status_o  ,
  output logic             interrupt_o        ,
  //--- stream going to the accelerator
  SNE_EVENT_STREAM.src    evt_stream_src      ,
  //--- stream coming from the accelerator
  SNE_EVENT_STREAM.dst    evt_stream_dst

);

SNE_EVENT_STREAM tcdm_to_sne_stream(.clk_i(system_clk_i));
SNE_EVENT_STREAM sne_to_tcdm_stream(.clk_i(system_clk_i));

/* programmable streamer controller, it behaves as a DMA. 
transfers can be programmed in both directions, this module 
is data agnostic, as it simply transfers events (uevent_t) 
from the TCDM to the SNE or vice versa. */
evt_streamer_ctrl  #( .STREAMER_ID(STREAMER_ID)) i_evt_streamer_ctrl
(
  .system_clk_i          ( system_clk_i          ),     
  .system_rst_ni         ( system_rst_ni         ),   
  .evt_i                 ( evt_i                 ), 
  .interrupt_o           ( interrupt_o           ),
  .config_i              ( config_system_sw_i    ),
  .power_gate            ( power_gate            ),
  .power_sleep           ( power_sleep           ),
  .tcdm_req_o            ( tcdm_req_o            ),       
  .tcdm_gnt_i            ( tcdm_gnt_i            ),       
  .tcdm_add_o            ( tcdm_add_o            ),       
  .tcdm_wen_o            ( tcdm_wen_o            ),       
  .tcdm_be_o             ( tcdm_be_o             ),        
  .tcdm_data_o           ( tcdm_data_o           ),      
  .tcdm_r_data_i         ( tcdm_r_data_i         ),    
  .tcdm_r_valid_i        ( tcdm_r_valid_i        ),  
  .sta_main_status_o     ( sta_main_status_o     ), 
  .evt_stream_dst        ( sne_to_tcdm_stream    ),
  .evt_stream_src        ( tcdm_to_sne_stream    )
);

//--- source dual clock evt fifo, stream coming from the TCDM and going to the SNE
evt_cdc_fifo #(.T(T),.DEPTH(EVT_SRC_FIFO_DEPTH)) i_evt_cdc_src_fifo (
  .src_clk_i ( sne_clk_i          ),
  .src_rst_ni( sne_rst_ni         ),
  .dst_clk_i ( system_clk_i       ),
  .dst_rst_ni( system_rst_ni      ),
  .src_stream( evt_stream_src     ),
  .dst_stream( tcdm_to_sne_stream )
);

//--- destination dual clock event fifo, stream coming from the SNE and going to the TCDM
evt_cdc_fifo #(.T(T),.DEPTH(EVT_DST_FIFO_DEPTH)) i_evt_cdc_dst_fifo (
  .src_clk_i ( system_clk_i       ),
  .src_rst_ni( system_rst_ni      ),
  .dst_clk_i ( sne_clk_i          ),
  .dst_rst_ni( sne_rst_ni         ),
  .src_stream( sne_to_tcdm_stream ),
  .dst_stream( evt_stream_dst     )
);

endmodule : evt_streamer

