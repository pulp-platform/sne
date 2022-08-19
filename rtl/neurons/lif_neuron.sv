/* 
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
 *
 * Copyright (C) 2018-2019 ETH Zurich, University of Bologna
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
`include "evt_neuron_defines.svh"

module lif_neuron 
import sne_evt_stream_pkg::uevent_t;
    #(
    parameter SYN_WEIGHT_WIDTH = 4,
    // parameter ARITHM_WIDTH     = 8,
    // parameter STATE_WIDTH      = 16,
    parameter PARAM_WIDTH      = 32,
    parameter TIME_WIDTH       = 8,
    parameter VOLTAGE_WIDTH    = 8,
    localparam STATE_WIDTH      = TIME_WIDTH + VOLTAGE_WIDTH
)(

    input  logic [SYN_WEIGHT_WIDTH-1:0] syn_weight_i,
    input  logic [SYN_WEIGHT_WIDTH-1:0] syn_weight_scale_i,
    
    input  logic [PARAM_WIDTH-1:0     ] neuron_param_i,

    input  logic [STATE_WIDTH-1:0     ] neuron_state_i,
    output logic [STATE_WIDTH-1:0     ] neuron_state_o,
    // input  logic                        spike_i,
    input  logic [TIME_WIDTH-1:0    ]   time_i,
    input  logic                        enable_i,
    input  logic                        force_spike_op_i,

    SNE_EVENT_STREAM.dst      evt_dp_stream_filter_dst, 
    output logic                        spike_o
);
// localparam STATE_WIDTH = TIME_WIDTH + VOLTAGE_WIDTH;

logic [2:0                 ] spike_op_i;
logic                        mem_wipe_o;
//--- parameters to estract from the state
logic [STATE_WIDTH-1:0] mem_voltage_ps;
logic [TIME_WIDTH-1:0] timestamp_last_update_ps;

//--- parameters to extract from neuron config
logic [VOLTAGE_WIDTH-1:0] rest_voltage_s;
logic [VOLTAGE_WIDTH-1:0] reset_voltage_s;
logic [VOLTAGE_WIDTH-1:0] threshold_voltage_s;
logic [VOLTAGE_WIDTH-1:0] leakage_voltage_s;
logic                     leakage_en;
logic                     inh_evt;
logic                     subtract_th_en;

//--- next state values
logic [VOLTAGE_WIDTH-1:0] mem_voltage_ns;
logic [TIME_WIDTH-1:0] timestamp_last_update_ns;
logic [VOLTAGE_WIDTH-1:0] output_voltage_ns;



//--- datapath signals
logic [VOLTAGE_WIDTH-1:0] syn_voltage_s;
logic [VOLTAGE_WIDTH-1:0] post_leak_voltage_s;
logic [VOLTAGE_WIDTH-1:0] int_mem_voltage_s;
logic [VOLTAGE_WIDTH:0  ] updated_mem_voltage_s;
logic [VOLTAGE_WIDTH-1:0] spike_gen_voltage_s;

// logic [VOLTAGE_WIDTH-1:0] scaled_leakage_voltage_s;
logic [STATE_WIDTH-1-1:0] scaled_leakage_voltage_s;
logic [TIME_WIDTH-1:0] time_scaling_factor_s;

logic [VOLTAGE_WIDTH:0] sat_mem_voltage_s;


logic                    leak_direction_s;
logic                    overflow_detection_s;


logic integrate_s;
logic mem_wipe_s;
logic spike_i;
assign spike_op_i = force_spike_op_i? `SPIKE_OP:evt_dp_stream_filter_dst.evt.dp_data.dp_operation;
assign evt_dp_stream_filter_dst.ready = 1'b1;
assign spike_i    =  enable_i;
//--- extract state parameters 
assign mem_voltage_ps           = neuron_state_i[VOLTAGE_WIDTH-1:0          ];
assign timestamp_last_update_ps = neuron_state_i[STATE_WIDTH-1:VOLTAGE_WIDTH];

//--- extract config parameters 
assign rest_voltage_s           = neuron_param_i[7:0  ];
assign threshold_voltage_s      = neuron_param_i[15:8 ];
assign reset_voltage_s          = neuron_param_i[23:16];
assign leakage_voltage_s        = neuron_param_i[31:24];

assign leakage_en               = (leakage_voltage_s != 'b0); //1'b1;//neuron_param_i[32   ];
assign inh_evt                  = 1'b0;//neuron_param_i[33   ]; --> FIXME
assign subtract_th_en           = 1'b0;//neuron_param_i[34   ]; --> FIXME

localparam WEIGHT_PADDING = VOLTAGE_WIDTH - SYN_WEIGHT_WIDTH;


//--- M1
always_comb begin : proc_syn_voltage
    unique if(spike_i) begin
        syn_voltage_s = {{WEIGHT_PADDING{1'b0}},{syn_weight_i}} << syn_weight_scale_i;
    end else begin
        syn_voltage_s = {VOLTAGE_WIDTH{1'b0}};
    end
end

//--- C1
always_comb begin : proc_comp_leak_dir
    unique if((mem_voltage_ps) > (rest_voltage_s)) begin
        leak_direction_s = 1'b1;
    end else begin
        leak_direction_s = 1'b0;
    end
end

//--- AS3
always_comb begin : proc_time_scaling_factor
    unique if(spike_op_i == `SPIKE_OP) begin
        time_scaling_factor_s = time_i-timestamp_last_update_ps;
    end else begin
        time_scaling_factor_s = {TIME_WIDTH{1'b0}};
    end
    
end

//--- MUL1
always_comb begin : proc_upscale_leakage
    unique if(spike_op_i == `SPIKE_OP) begin
        scaled_leakage_voltage_s = leakage_voltage_s * time_scaling_factor_s;
    end else begin
        scaled_leakage_voltage_s = 0;
    end
end

//--- AS1
always_comb begin : proc_add_sub_leak
    unique if(leak_direction_s) begin
        if($signed($signed(mem_voltage_ps) - $signed(scaled_leakage_voltage_s)) > $signed(rest_voltage_s)) begin
            post_leak_voltage_s = mem_voltage_ps[VOLTAGE_WIDTH-1:0] - scaled_leakage_voltage_s[VOLTAGE_WIDTH-1:0];
        end else begin
            post_leak_voltage_s = rest_voltage_s;
        end
        
    end else begin
        if($signed($signed(mem_voltage_ps) + $signed(scaled_leakage_voltage_s)) < $signed(rest_voltage_s)) begin
            post_leak_voltage_s = mem_voltage_ps[VOLTAGE_WIDTH-1:0] + scaled_leakage_voltage_s[VOLTAGE_WIDTH-1:0];
        end else begin
            post_leak_voltage_s = rest_voltage_s;
        end
        
    end
end

//--- M2
always_comb begin : proc_leakage_enable
    unique if(leakage_en) begin
        int_mem_voltage_s = post_leak_voltage_s;
    end else begin
        int_mem_voltage_s = mem_voltage_ps[VOLTAGE_WIDTH-1:0];
    end
end

//--- AS2
always_comb begin : proc_add_sub_syn_evt
    unique if(inh_evt) begin
        updated_mem_voltage_s = int_mem_voltage_s - syn_voltage_s;
    end else begin
        updated_mem_voltage_s = int_mem_voltage_s + syn_voltage_s;
    end
    overflow_detection_s = updated_mem_voltage_s[VOLTAGE_WIDTH];
end

//--- M3
always_comb begin : proc_overflow_saturation
    unique if(inh_evt) begin
        sat_mem_voltage_s = {VOLTAGE_WIDTH{1'b0}};
    end else begin
        sat_mem_voltage_s = {VOLTAGE_WIDTH{1'b1}};
    end
end

//--- M4
always_comb begin : proc_pre_spike_mem_voltage_selection
    unique if(overflow_detection_s) begin
        spike_gen_voltage_s = sat_mem_voltage_s;
    end else begin
        spike_gen_voltage_s = updated_mem_voltage_s[VOLTAGE_WIDTH-1:0];
    end
end

//--- C5
always_comb begin : proc_spike_generation
    if(((spike_gen_voltage_s) > (threshold_voltage_s)) && ~mem_wipe_o && ~integrate_s) begin
        spike_o = 1'b1;
    end else begin
        spike_o = 1'b0;
    end
end

//---M5
always_comb begin : proc_output_voltage_selection
    unique if(spike_o) begin
        mem_voltage_ns = reset_voltage_s;
    end else begin
        mem_voltage_ns = updated_mem_voltage_s[VOLTAGE_WIDTH-1:0];
    end
end

//--- M6
always_comb begin : proc_output_cfg
    case (spike_op_i)
        `SPIKE_OP: begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_update_ns = time_i;
            integrate_s = 1'b0;
            mem_wipe_o = 1'b0;
        end 

        `INTEGRATE_OP: begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_update_ns = time_i;
            integrate_s = 1'b1;
            mem_wipe_o = 1'b0;
        end 

        `IDLE_OP: begin
            output_voltage_ns = mem_voltage_ps;
            timestamp_last_update_ns = timestamp_last_update_ps;
            integrate_s = 1'b0;
            mem_wipe_o = 1'b0;
        end 

        `RST_OP: begin
            output_voltage_ns = reset_voltage_s;
            timestamp_last_update_ns = {TIME_WIDTH{1'b0}};
            integrate_s = 1'b0;
            mem_wipe_o = 1'b1;
        end
    
        default begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_update_ns = time_i;
            integrate_s = 1'b0;
            mem_wipe_o = 1'b0;
        end
    endcase
end

//--- write back neuron state
assign neuron_state_o[VOLTAGE_WIDTH-1:0          ] = mem_wipe_o ? 'b0 : output_voltage_ns;
assign neuron_state_o[STATE_WIDTH-1:VOLTAGE_WIDTH] = mem_wipe_o ? 'b0 : timestamp_last_update_ns; 

endmodule