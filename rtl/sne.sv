/* 
 * Alfio Di Mauro <adimauro@student.ethz.ch>
 * Arpan Suravi Prasad <prasadar@student.ethz.ch>
 *
 * Copyright (C) 2018-2022 ETH Zurich, University of Bologna
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

//--- top level wrapper for the gate netlist
module sne(

  input  logic               clk_i                 ,       
  input  logic               rst_ni                ,      
  input  logic               test_mode_i           ,      
  output logic [ 1:0]        evt_o                 ,
  input  logic [ 3:0]        evt_i                 , 

  output logic [ 1:0]        tcdm_req              ,    
  input  logic [ 1:0]        tcdm_gnt              ,    
  output logic [ 1:0][31:0]  tcdm_add              ,    
  output logic [ 1:0]        tcdm_wen              ,    
  output logic [ 1:0][3:0 ]  tcdm_be               ,     
  output logic [ 1:0][31:0]  tcdm_data             ,   
  input  logic [ 1:0][31:0]  tcdm_r_data           , 
  input  logic [ 1:0]        tcdm_r_valid          ,

  input  logic [31:0]        udma_stream_data_i    ,
  input  logic [ 1:0]        udma_stream_datasize_i,
  input  logic               udma_stream_valid_i   , 
  input  logic               udma_stream_sot_i     ,
  input  logic               udma_stream_eot_i     , 
  output logic               udma_stream_ready_o   , 

  input  logic               apb_slave_pwrite      , 
  input  logic               apb_slave_psel        ,
  input  logic               apb_slave_penable     ,
  input  logic [31:0]        apb_slave_paddr       ,
  input  logic [31:0]        apb_slave_pwdata      ,
  output logic [31:0]        apb_slave_prdata      ,
  output logic               apb_slave_pready      , 
  output logic               apb_slave_pslverr   

);

//--- sne_netlist
sne_top  #(

  .GROUP_NUMBER           (16                    ),          
  .NEURON_NUMBER          (64                    ),         
  .SLICE_NUMBER           (2                     ),          
  .STREAM_NUMBER          (2                     ),             
  .EXTERNAL_STREAM_NUMBER (1                     )

) i_sne_top (

  .clk_i                  (clk_i                 ),                 
  .rst_ni                 (rst_ni                ),                
  .evt_o                  (evt_o                 ),                 
  .evt_i                  ('0                    ),                 
  .test_mode_i            (test_mode_i           ),           
  
  .tcdm_req               (tcdm_req              ),              
  .tcdm_gnt               (tcdm_gnt              ),              
  .tcdm_add               (tcdm_add              ),              
  .tcdm_wen               (tcdm_wen              ),              
  .tcdm_be                (tcdm_be               ),               
  .tcdm_data              (tcdm_data             ),             
  .tcdm_r_data            (tcdm_r_data           ),           
  .tcdm_r_valid           (tcdm_r_valid          ),          

  .udma_stream_datasize_i (udma_stream_datasize_i),
  .udma_stream_data_i     (udma_stream_data_i    ),    
  .udma_stream_valid_i    (udma_stream_valid_i   ),   
  .udma_stream_sot_i      (udma_stream_sot_i     ),     
  .udma_stream_eot_i      (udma_stream_eot_i     ),     
  .udma_stream_ready_o    (udma_stream_ready_o   ),   

  .apb_slave_pwrite       (apb_slave_pwrite      ),      
  .apb_slave_psel         (apb_slave_psel        ),        
  .apb_slave_penable      (apb_slave_penable     ),     
  .apb_slave_paddr        ((apb_slave_paddr   - 32'h1A150000)),       
  .apb_slave_pwdata       (apb_slave_pwdata      ),      
  .apb_slave_prdata       (apb_slave_prdata      ),      
  .apb_slave_pready       (apb_slave_pready      ),      
  .apb_slave_pslverr      (apb_slave_pslverr     ) 

  );

endmodule // sne 

