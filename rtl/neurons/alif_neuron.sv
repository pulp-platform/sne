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

module alif_neuron 
import sne_evt_stream_pkg::uevent_t;
import sne_evt_stream_pkg::config_engine_t;
#(
    parameter SYN_WEIGHT_WIDTH = 4,
    parameter ARITHM_WIDTH     = 8,
    parameter STATE_WIDTH      = 32,
    parameter PARAM_WIDTH      = 32
)(

    input  logic [SYN_WEIGHT_WIDTH-1:0] syn_weight_i,
    input  logic [SYN_WEIGHT_WIDTH-1:0] syn_weight_scale_i,
    input  logic                        enable_i,
    input  config_engine_t              config_i,
    input  logic [ARITHM_WIDTH-1:0    ] time_i,
    input  logic [STATE_WIDTH-1:0     ] neuron_state_i,
    input  logic                        force_spike_op_i,

    SNE_EVENT_STREAM.dst      evt_dp_stream_filter_dst, 
    output logic [STATE_WIDTH-1:0     ] neuron_state_o,
    output logic                        spike_o
);

logic [2:0                 ] spike_op_i;
logic                        mem_wipe_o;
//--- present state
logic signed [ARITHM_WIDTH-1:0] mem_voltage_ps;
logic signed [ARITHM_WIDTH-1:0] adaptive_th_ps;
logic        [ARITHM_WIDTH-1:0] timestamp_last_update_ps;
logic        [ARITHM_WIDTH-1:0] timestamp_last_spike_ps;

//--- next state 
logic signed [ARITHM_WIDTH-1:0] mem_voltage_ns;
logic signed [ARITHM_WIDTH-1:0] adaptive_th_ns;
logic        [ARITHM_WIDTH-1:0] timestamp_last_update_ns;
logic        [ARITHM_WIDTH-1:0] timestamp_last_spike_ns;


//--- parameters to extract from neuron config
logic        [ARITHM_WIDTH-1:0] refractory_time_s;
logic signed [ARITHM_WIDTH-1:0] rest_voltage_s;
logic signed [ARITHM_WIDTH-1:0] threshold_voltage_s;
//logic        [ARITHM_WIDTH-1:0] leakage_voltage_s;
logic signed [ARITHM_WIDTH-1:0] adaptive_th_s;
logic                           leakage_en;
logic        [             3:0] scale_factor;

//--- datapath signals
logic signed [ARITHM_WIDTH-1:0] syn_voltage_s;
logic signed [ARITHM_WIDTH-1:0] post_leak_voltage_s;
logic signed [ARITHM_WIDTH-1:0] int_mem_voltage_s;
logic signed [ARITHM_WIDTH:0  ] updated_mem_voltage_s; //--- +1b because we check overflow on this value
logic signed [ARITHM_WIDTH-1:0] spike_gen_voltage_s;
logic signed [ARITHM_WIDTH-1:0] sat_mem_voltage_s;
logic        [ARITHM_WIDTH-1:0] time_scaling_factor_s;
logic        [ARITHM_WIDTH-1:0] time_scaling_factor_temp_s;
logic        [31:0] lut_scaling_factor_temp_s;
logic signed [ARITHM_WIDTH-1:0] output_voltage_ns;
logic                           in_refractory_window_s;
logic        [ARITHM_WIDTH-1:0] delta_spike_time_s;

logic spike_i;
logic prevent_spike_s;
logic prevent_leakage_s;

assign spike_op_i = force_spike_op_i? `SPIKE_OP:evt_dp_stream_filter_dst.evt.dp_data.dp_operation;
assign evt_dp_stream_filter_dst.ready = 1'b1;
assign spike_i = enable_i;

//--- extract state parameters 
assign mem_voltage_ps           = $signed(neuron_state_i[31:24]);
assign timestamp_last_update_ps = neuron_state_i[15:8];
assign timestamp_last_spike_ps  = neuron_state_i[7:0];
assign adaptive_th_ps = neuron_state_i[23:16];


//--- extract config parameters 
assign rest_voltage_s           = config_i.reg2hw.cfg_parameter_i.vrest;
assign threshold_voltage_s      = config_i.reg2hw.cfg_parameter_i.vth;
assign refractory_time_s        = config_i.reg2hw.cfg_parameter_i.tref;
assign leakage_en               = 1'b1;//neuron_param_i[32   ];
assign adaptive_th_s            = config_i.reg2hw.cfg_parameter_i.davth;
assign scale_factor             = config_i.reg2hw.cfg_parameter_i.tscale;


//--- M1
always_comb begin : proc_syn_voltage
    unique if(spike_i) begin
        syn_voltage_s = $signed(syn_weight_i) <<< syn_weight_scale_i;
    end else begin
        syn_voltage_s = $signed(0);
    end
end

//--- AS3
always_comb begin : proc_time_scaling_factor
    unique if((spike_op_i == `SPIKE_OP) || (spike_op_i == `UPDATE_OP)) begin
        time_scaling_factor_s = time_i-timestamp_last_update_ps;
    end else begin
        time_scaling_factor_s = 0;
    end 
end

always_comb begin : proc_ref_window
    delta_spike_time_s = time_i-timestamp_last_spike_ps;
    if (delta_spike_time_s < refractory_time_s) begin
        in_refractory_window_s = 1'b1;
    end else begin
        in_refractory_window_s = 1'b0;
    end

end

//------------------------------------------------------------------- LUT exp approx

logic signed [8:0] lut_value_s;
logic        [4:0] lut_scale_factor_s;
logic        [4:0] lut_idx_s;
logic signed [9:0] exp_scaling_factor;

LUT exp_lut (

    .lut_idx_i  (lut_idx_s),
    .lut_value_o(lut_value_s)

);

logic signed [8:0] th_lut_value_s;
logic        [4:0] th_lut_scale_factor_s;
logic        [4:0] th_lut_idx_s;
logic signed [9:0] th_exp_scaling_factor;

LUT exp_lut_th (

    .lut_idx_i  (th_lut_idx_s),
    .lut_value_o(th_lut_value_s)

);

logic signed [9+ARITHM_WIDTH:0] scaled_mem_voltage_ps_s;
logic signed [ARITHM_WIDTH-1:0] base_mem_voltage_ps_s;


// MUL_EXP
always_comb begin : proc_exp_scaling_membrane

    if (prevent_leakage_s) begin
        lut_idx_s = 0;
        lut_scale_factor_s = 0;
        exp_scaling_factor = 0;
        scaled_mem_voltage_ps_s = 0;
        base_mem_voltage_ps_s = mem_voltage_ps;
        post_leak_voltage_s = mem_voltage_ps;

    end else begin
        time_scaling_factor_temp_s = time_scaling_factor_s<<scale_factor;
        lut_idx_s          = time_scaling_factor_temp_s[4:0]; //--- truncate to 31
        // lut_scale_factor_s = (time_scaling_factor_s      << scale_factor) >> 5; 
        lut_scaling_factor_temp_s = ((time_scaling_factor_s      << scale_factor) >> 5); 
        if(lut_scaling_factor_temp_s>31)
            lut_scale_factor_s = 31;
        else
            lut_scale_factor_s = lut_scaling_factor_temp_s[4:0] ;//--- divide by 32
        exp_scaling_factor = lut_value_s >>> lut_scale_factor_s;

        scaled_mem_voltage_ps_s = $signed(mem_voltage_ps) * $signed(exp_scaling_factor);
        base_mem_voltage_ps_s = (scaled_mem_voltage_ps_s >>> 8); //--- divide by 255 as LUT scale up by 255, and extend the sign

        if (scaled_mem_voltage_ps_s > $signed(0)) begin
            if (base_mem_voltage_ps_s >= rest_voltage_s) begin
                post_leak_voltage_s = base_mem_voltage_ps_s; 
            end else begin
                post_leak_voltage_s = rest_voltage_s;
            end
        end else begin
            if (base_mem_voltage_ps_s <= rest_voltage_s) begin
                post_leak_voltage_s = base_mem_voltage_ps_s; 
            end else begin
                post_leak_voltage_s = rest_voltage_s;
            end
        end
    end
end

logic signed [9+ARITHM_WIDTH:0] scaled_adaptive_th_ps_s;
logic signed [ARITHM_WIDTH-1:0] base_adaptive_th_ps_s;

// MUL_EXP
always_comb begin : proc_exp_scaling_th

    if (prevent_leakage_s) begin


        scaled_adaptive_th_ps_s = 0;
        base_adaptive_th_ps_s = adaptive_th_ps;
        th_lut_scale_factor_s = 0; //--- divide by 8
        th_lut_idx_s          = 0; //--- truncate to 8
        th_exp_scaling_factor = 0;

    end else begin
        th_lut_scale_factor_s = time_scaling_factor_s >> 5; //--- divide by 8
        th_lut_idx_s          = time_scaling_factor_s[4:0]; //--- truncate to 8
        th_exp_scaling_factor = th_lut_value_s >>> th_lut_scale_factor_s;

        scaled_adaptive_th_ps_s = $signed(adaptive_th_ps) * $signed(th_exp_scaling_factor);
        base_adaptive_th_ps_s = (scaled_adaptive_th_ps_s >>> 8);

    end
end

//---------------------------------------------------------------------

//--- M2
always_comb begin : proc_leakage_enable
    unique if(leakage_en) begin
        int_mem_voltage_s = post_leak_voltage_s;
    end else begin
        int_mem_voltage_s = mem_voltage_ps;
    end
end

//--- AS2
always_comb begin : proc_add_sub_syn_evt

    updated_mem_voltage_s = int_mem_voltage_s + syn_voltage_s;

    if (updated_mem_voltage_s > $signed(0)) begin
        if (updated_mem_voltage_s > $signed(2**(ARITHM_WIDTH-1) - 1)) begin
            sat_mem_voltage_s = $signed(2**(ARITHM_WIDTH-1) - 1);
        end else begin
            sat_mem_voltage_s = updated_mem_voltage_s;
        end
    end else begin
        if (updated_mem_voltage_s < $signed(-(2**ARITHM_WIDTH-1))) begin
            sat_mem_voltage_s = $signed(-(2**ARITHM_WIDTH-1));
        end else begin
            sat_mem_voltage_s = updated_mem_voltage_s;
        end
    end

    spike_gen_voltage_s = sat_mem_voltage_s;

end

logic [7:0] time_spike_s;
logic [ARITHM_WIDTH-1:0] global_th_s;

//--- C5
always_comb begin : proc_spike_generation_th_adaptation
    if((spike_gen_voltage_s > (threshold_voltage_s + base_adaptive_th_ps_s)) && ~mem_wipe_o && ~prevent_spike_s && ~in_refractory_window_s) begin
        spike_o = 1'b1;
        time_spike_s = time_i;
        global_th_s = base_adaptive_th_ps_s + adaptive_th_s;

        if (global_th_s > $signed(0)) begin
            if (global_th_s > $signed(2**(ARITHM_WIDTH-1) - 1)) begin
                adaptive_th_ns = $signed(2**(ARITHM_WIDTH-1) - 1);
            end else begin
                adaptive_th_ns = global_th_s;
            end
        end else begin
            if (global_th_s < $signed(-(2**ARITHM_WIDTH-1))) begin
                adaptive_th_ns = $signed(-(2**ARITHM_WIDTH-1));
            end else begin
                adaptive_th_ns = global_th_s;
            end
        end

    end else begin
        spike_o = 1'b0;
        global_th_s = base_adaptive_th_ps_s;
        time_spike_s = timestamp_last_spike_ps;
        adaptive_th_ns = global_th_s;
    end
end

//---M5
always_comb begin : proc_output_voltage_selection
    unique if(spike_o) begin
        mem_voltage_ns = sat_mem_voltage_s - $signed(threshold_voltage_s);
    end else begin
        mem_voltage_ns = sat_mem_voltage_s;
    end
end

logic signed [ARITHM_WIDTH-1:0] adaptive_th_temp_ns;
//--- M6
always_comb begin : proc_output_cfg
    case (spike_op_i)
        `SPIKE_OP: begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_spike_ns  = time_spike_s;
            timestamp_last_update_ns = time_i;
            prevent_spike_s = 1'b0;
            mem_wipe_o = 1'b0;
            prevent_leakage_s = 1'b0;
            adaptive_th_temp_ns = adaptive_th_ns;
        end 

        `UPDATE_OP: begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_spike_ns  = timestamp_last_spike_ps;
            timestamp_last_update_ns = time_i;
            prevent_spike_s = 1'b1;
            mem_wipe_o = 1'b0;
            prevent_leakage_s = 1'b0;
            adaptive_th_temp_ns = adaptive_th_ns;
        end

        `INTEGRATE_OP: begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_spike_ns  = timestamp_last_spike_ps;
            timestamp_last_update_ns = time_i;
            prevent_spike_s = 1'b1;
            mem_wipe_o = 1'b0;
            prevent_leakage_s = 1'b1;
            adaptive_th_temp_ns = adaptive_th_ns;
        end 

        `IDLE_OP: begin
            output_voltage_ns = mem_voltage_ps;
            timestamp_last_spike_ns  = timestamp_last_spike_ps;
            timestamp_last_update_ns = timestamp_last_update_ps;
            prevent_spike_s = 1'b1;
            mem_wipe_o = 1'b0;
            prevent_leakage_s = 1'b1;
            adaptive_th_temp_ns = adaptive_th_ns;
        end 

        `RST_OP: begin
            output_voltage_ns = rest_voltage_s;
            timestamp_last_spike_ns  = timestamp_last_spike_ps;
            timestamp_last_update_ns = {ARITHM_WIDTH{1'b0}};
            prevent_spike_s = 1'b0;
            mem_wipe_o = 1'b1;
            prevent_leakage_s = 1'b0;
            adaptive_th_temp_ns = adaptive_th_ns;
        end
        //  `SKIP_OP: begin
        //     output_voltage_ns = neuron_state_i[7:0];
        //     timestamp_last_spike_ns  = neuron_state_i[15:8];
        //     timestamp_last_update_ns = neuron_state_i[23:16];
        //     prevent_spike_s = 1'b1;
        //     mem_wipe_o = 1'b0;
        //     prevent_leakage_s = 1'b1;
        //     adaptive_th_temp_ns = neuron_state_i[31:24];
        // end 
        default begin
            output_voltage_ns = mem_voltage_ns;
            timestamp_last_spike_ns  = timestamp_last_spike_ps;
            timestamp_last_update_ns = time_i;
            prevent_spike_s = 1'b0;
            mem_wipe_o = 1'b0;
            prevent_leakage_s = 1'b0;
            adaptive_th_temp_ns = neuron_state_i[31:24];
        end
    endcase
end

//--- write back neuron state

assign neuron_state_o[31:24] = mem_wipe_o ? 'b0 : output_voltage_ns;
assign neuron_state_o[15:8] = mem_wipe_o ? 'b0 : timestamp_last_update_ns;   
assign neuron_state_o[7:0] = mem_wipe_o ? 'b0 : timestamp_last_spike_ns; 
assign neuron_state_o[23:16] = mem_wipe_o ? 'b0 : adaptive_th_ns;

//     always_comb begin
//         if(syn_weight_i>0) begin 
//             neuron_state_o[7:0] = mem_wipe_o ? 'b0 : output_voltage_ns;
//             neuron_state_o[15:8] = mem_wipe_o ? 'b0 :timestamp_last_update_ns;   
//             neuron_state_o[23:16] = mem_wipe_o ? 'b0 : timestamp_last_spike_ns; 
//             neuron_state_o[31:24] = mem_wipe_o ? 'b0 : adaptive_th_ns;
//         end else begin 
//             neuron_state_o = neuron_state_i;
//         end 
//     end 
endmodule


//--- LUT implementing the Exponential decay (approximated with power of 2)
module LUT (
    input logic [4:0] lut_idx_i,    
    output logic [8:0] lut_value_o 
);

always_comb begin : proc_LUT
    case (lut_idx_i)
        5'b00000:  lut_value_o = $signed(238);
        5'b00001:  lut_value_o = $signed(234);
        5'b00010:  lut_value_o = $signed(229);
        5'b00011:  lut_value_o = $signed(225);
        5'b00100:  lut_value_o = $signed(221);
        5'b00101:  lut_value_o = $signed(216);
        5'b00110:  lut_value_o = $signed(212);
        5'b00111:  lut_value_o = $signed(208);
        5'b01000:  lut_value_o = $signed(204);
        5'b01001:  lut_value_o = $signed(200);
        5'b01010:  lut_value_o = $signed(197);
        5'b01011:  lut_value_o = $signed(193);
        5'b01100:  lut_value_o = $signed(189);
        5'b01101:  lut_value_o = $signed(186);
        5'b01110:  lut_value_o = $signed(182);
        5'b01111:  lut_value_o = $signed(179);
        5'b10000:  lut_value_o = $signed(175);
        5'b10001:  lut_value_o = $signed(172);
        5'b10010:  lut_value_o = $signed(168);
        5'b10011:  lut_value_o = $signed(165);
        5'b10100:  lut_value_o = $signed(162);
        5'b10101:  lut_value_o = $signed(159);
        5'b10110:  lut_value_o = $signed(156);
        5'b10111:  lut_value_o = $signed(153);
        5'b11000:  lut_value_o = $signed(150);
        5'b11001:  lut_value_o = $signed(147);
        5'b11010:  lut_value_o = $signed(144);
        5'b11011:  lut_value_o = $signed(142);
        5'b11100:  lut_value_o = $signed(139);
        5'b11101:  lut_value_o = $signed(136);
        5'b11110:  lut_value_o = $signed(134);
        5'b11111:  lut_value_o = $signed(131);
        // 5'b00000:  lut_value_o = $signed(256);
        // 5'b00001:  lut_value_o = $signed(250);
        // 5'b00010:  lut_value_o = $signed(245);
        // 5'b00011:  lut_value_o = $signed(240);
        // 5'b00100:  lut_value_o = $signed(234);
        // 5'b00101:  lut_value_o = $signed(229);
        // 5'b00110:  lut_value_o = $signed(225);
        // 5'b00111:  lut_value_o = $signed(220);
        // 5'b01000:  lut_value_o = $signed(215);
        // 5'b01001:  lut_value_o = $signed(211);
        // 5'b01010:  lut_value_o = $signed(206);
        // 5'b01011:  lut_value_o = $signed(202);
        // 5'b01100:  lut_value_o = $signed(197);
        // 5'b01101:  lut_value_o = $signed(193);
        // 5'b01110:  lut_value_o = $signed(189);
        // 5'b01111:  lut_value_o = $signed(185);
        // 5'b10000:  lut_value_o = $signed(181);
        // 5'b10001:  lut_value_o = $signed(177);
        // 5'b10010:  lut_value_o = $signed(173);
        // 5'b10011:  lut_value_o = $signed(170);
        // 5'b10100:  lut_value_o = $signed(166);
        // 5'b10101:  lut_value_o = $signed(163);
        // 5'b10110:  lut_value_o = $signed(159);
        // 5'b10111:  lut_value_o = $signed(156);
        // 5'b11000:  lut_value_o = $signed(152);
        // 5'b11001:  lut_value_o = $signed(149);
        // 5'b11010:  lut_value_o = $signed(146);
        // 5'b11011:  lut_value_o = $signed(143);
        // 5'b11100:  lut_value_o = $signed(140);
        // 5'b11101:  lut_value_o = $signed(137);
        // 5'b11110:  lut_value_o = $signed(134);
        // 5'b11111:  lut_value_o = $signed(131);
        default :  lut_value_o = $signed(  0);
    endcase
end

endmodule


// module LUT(
//     input logic [4:0] lut_idx_i,    
//     output logic [8:0] lut_value_o 
// );
//     lut_value_o = ((2<<11)+(lut_idx_i*lut_idx_i)-(lut_idx_i<<7))>>4;
// endmodule
