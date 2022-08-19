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
module floating_kernel 
    import sne_evt_stream_pkg::config_engine_t;
    #(

    parameter SEQ_ADDR_WIDTH     = 8,
    parameter NEURON_ID_WIDTH    = 8,
    parameter WEIGHTS_WIDTH      = 4,
    parameter KERNEL_SIZE        = 3,
    parameter WEIGHTS_NUMBER     = KERNEL_SIZE*KERNEL_SIZE,
    parameter GROUP_ID           = 0

    )(

    input logic                           clk_i                , // Clock
    input logic                           clk_en_i             , // Clock Enable
    input logic                           rst_ni               , // Asynchronous reset active low
    input config_engine_t                 config_i             ,
    input logic [SEQ_ADDR_WIDTH-1:0 ]     sequencer_addr_i     ,
    input logic [NEURON_ID_WIDTH-1:0]     neuron_addr_i        ,
    input logic [WEIGHTS_NUMBER*WEIGHTS_WIDTH-1:0] floating_kernel_i,
    output logic                          silence_neuron_o     ,
    output logic [WEIGHTS_WIDTH-1:0]      gn_weight_o 
    
);

    //--- address calculation
    logic [2:0] xi,yi;
    logic [2:0] xr,yr;
    logic [2:0] xk,yk;


    logic [2:0]                     kernel_offset_x_i    ;
    logic [2:0]                     kernel_offset_y_i    ;

    assign kernel_offset_y_i = config_i.reg2hw.cfg_filter_main_i[GROUP_ID].y_offset;
    assign kernel_offset_x_i = config_i.reg2hw.cfg_filter_main_i[GROUP_ID].x_offset;
    
    always_comb begin : proc_input_addr
        xi = clk_en_i ? neuron_addr_i[NEURON_ID_WIDTH/2-1:0] : 3'b000;
        yi = clk_en_i ? neuron_addr_i[NEURON_ID_WIDTH-1:NEURON_ID_WIDTH/2] : 3'b000;

        xr = clk_en_i ? sequencer_addr_i[SEQ_ADDR_WIDTH/2-1:0] : 3'b000;
        yr = clk_en_i ? sequencer_addr_i[SEQ_ADDR_WIDTH-1:SEQ_ADDR_WIDTH/2] : 3'b000;
    end

    always_comb begin : proc_silence_neuron
        if ((xr == 3'b000) || (yr == 3'b000) || (xr == 3'b111) || (yr == 3'b111)) begin
           silence_neuron_o = 1'b0;
        end else begin
            silence_neuron_o = 1'b1;
        end
    end

    logic [WEIGHTS_NUMBER-1:0] weight_addr_s;

    logic [WEIGHTS_NUMBER-1:0][WEIGHTS_WIDTH-1:0] weight_s;

    generate
        genvar j;
        for(j=0; j<WEIGHTS_NUMBER;j++) 
            assign weight_s[j] = floating_kernel_i[(j+1)*WEIGHTS_WIDTH-1:j*WEIGHTS_WIDTH];
    endgenerate

    always_comb begin : proc_kernel_relative_address
        xk = (xi - xr + 1 + kernel_offset_x_i);
        yk = (yi - yr + 1 + kernel_offset_y_i);

        weight_addr_s = xk+yk*KERNEL_SIZE;

        if((xk<3) && (xk>=0) && (yk<3) && (yk>=0)) begin
           gn_weight_o = weight_s[weight_addr_s];
        end else begin
            gn_weight_o = {WEIGHTS_WIDTH{1'b0}};
        end
    end


endmodule
