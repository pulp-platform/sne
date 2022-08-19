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
module evt_neuron_dp 

    import sne_evt_stream_pkg::weight_t;
    import sne_evt_stream_pkg::parameter_t;
    import sne_evt_stream_pkg::state_t;
    import sne_evt_stream_pkg::timestamp_t;
    import sne_evt_stream_pkg::config_engine_t;

    (

    // enable signal from the filter
    input  logic          enable_i,

    // weights from the memory subsuystem
    input  weight_t       syn_weight_i,
    input  logic [3:0]    syn_weight_scale_i,
    
    // timestamp from the time unit
    input  timestamp_t    time_i,

    input  logic          force_spike_op_i,

    // state and parameters from the mem subsystem
    input  state_t        neuron_state_i,
    // input  parameter_t    neuron_param_i,
    input  config_engine_t config_i,
    output state_t        neuron_state_o,

    //--- destination data path stream port
    SNE_EVENT_STREAM.dst  evt_dp_group_stream_dst,

    // output spike
    output logic          spike_o
);

alif_neuron i_alif_neuron (
    .enable_i                (enable_i),
    .config_i                (config_i),
    .syn_weight_i            (syn_weight_i),
    .syn_weight_scale_i      (syn_weight_scale_i),
    // .neuron_param_i          (neuron_param_i),
    .neuron_state_i          (neuron_state_i),
    .neuron_state_o          (neuron_state_o),
    .time_i                  (time_i[7:0]),
    .force_spike_op_i        (force_spike_op_i),
    .evt_dp_stream_filter_dst(evt_dp_group_stream_dst),
    .spike_o                 (spike_o)
);
endmodule : evt_neuron_dp