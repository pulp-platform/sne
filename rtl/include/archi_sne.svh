// 
// Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
// 
// Copyright (C) 2018-2020 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// 
//                http://solderpad.org/licenses/SHL-0.51. 
// 
// Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
// 

//--- don't touch!!!
`define GROUP_NUMBER              16
`define NEURON_NUMBER             64
`define SLICE_NUMBER              2
`define STREAM_NUMBER             2
`define EXTERNAL_STREAM_NUMBER    1
`define NEURON_REC_FIELD          64
`define GROUP_FIFO_DEPTH          6 //+ $clog2(`SLICE_NUMBER)
//---------------
`define XBAR_SLAVES               ((3*`SLICE_NUMBER)+`STREAM_NUMBER)

`define CFG_REG_OFFSET 32'h00000000
`define STA_REG_OFFSET 32'h00009fff
`define GPM_REG_OFFSET 32'h0000b000

`define ONLINE_REG_OFFSET 32'h00020000

`define FC_WEIGHT_OFFSET_1 1024
`define FC_WEIGHT_OFFSET_2 1024+13000

// `define SLOTS 16
`define COMMON_WEIGHT

//--- nuber of register in each section of the cfg reg file
`define SLC_CFG_REG_NUM 9
`define SLC_STA_REG_NUM 1
`define GRP_CFG_REG_NUM 5
`define GRP_STA_REG_NUM 0
`define STR_CFG_REG_NUM 9
`define STR_STA_REG_NUM 2
`define XBR_CFG_REG_NUM `XBAR_SLAVES
`define XBR_STA_REG_NUM 0
`define GTW_CFG_REG_NUM 1
`define GTW_STA_REG_NUM 0
`define ORC_CFG_REG_NUM 9
`define ORC_STA_REG_NUM 0

//--- base position of each module regs
`define BASE_CFG_REG_NGR                             (`SLC_CFG_REG_NUM*`SLICE_NUMBER)
`define BASE_STA_REG_NGR                             (`SLC_STA_REG_NUM*`SLICE_NUMBER)
`define BASE_CFG_REG_STR                             (`BASE_CFG_REG_NGR+(`SLICE_NUMBER*`GROUP_NUMBER*`GRP_CFG_REG_NUM))
`define BASE_STA_REG_STR                             (`BASE_STA_REG_NGR+(`SLICE_NUMBER*`GROUP_NUMBER*`GRP_STA_REG_NUM))
`define BASE_CFG_REG_XBR                             (`BASE_CFG_REG_STR+`STREAM_NUMBER*`STR_CFG_REG_NUM)
`define BASE_STA_REG_XBR                             (`BASE_STA_REG_STR+`STREAM_NUMBER*`STR_STA_REG_NUM)
`define BASE_CFG_REG_GTW                             (`BASE_CFG_REG_XBR+`XBR_CFG_REG_NUM)
`define BASE_STA_REG_GTW                             (`BASE_STA_REG_XBR+`XBR_STA_REG_NUM)
`define BASE_CFG_REG_ORC                             (`BASE_CFG_REG_GTW+`GTW_CFG_REG_NUM)
`define BASE_STA_REG_ORC                             (`BASE_STA_REG_GTW+`GTW_STA_REG_NUM)

//--- macro to use for accessing the registers    
`define SEQ_MODE_CFG(slice)                          (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+0)*4)
`define SEQ_MAIN_CFG(slice)                          (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+1)*4)
`define SEQ_ADDR_CFG(slice)                          (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+2)*4)
`define SEQ_INIT_ADDR_CFG(slice)                     (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+3)*4)
`define SEQ_ADDR_STEP_CFG(slice)                     (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+4)*4)
`define SEQ_ADDR_START_CFG(slice)                    (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+5)*4)
`define SEQ_ADDR_END_CFG(slice)                      (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+6)*4)    
`define DEC_IN_ADDR_CFG(slice)                       (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+7)*4)
`define LIF_MAIN_CFG(slice)                          (`CFG_REG_OFFSET+(slice*(`SLC_CFG_REG_NUM)+8)*4)

`define NG_ROUTER_OUT_ADDR_CFG(slice,neuron_group)   (`CFG_REG_OFFSET+(`BASE_CFG_REG_NGR+(slice*`GROUP_NUMBER*`GRP_CFG_REG_NUM)+neuron_group*`GRP_CFG_REG_NUM+0)*4)
`define NG_LIF_WEIGHT_PARAM_CFG(slice,neuron_group)  (`CFG_REG_OFFSET+(`BASE_CFG_REG_NGR+(slice*`GROUP_NUMBER*`GRP_CFG_REG_NUM)+neuron_group*`GRP_CFG_REG_NUM+1)*4)
`define NG_FILTER_UBOUND_CFG(slice,neuron_group)     (`CFG_REG_OFFSET+(`BASE_CFG_REG_NGR+(slice*`GROUP_NUMBER*`GRP_CFG_REG_NUM)+neuron_group*`GRP_CFG_REG_NUM+2)*4)
`define NG_FILTER_LBOUND_CFG(slice,neuron_group)     (`CFG_REG_OFFSET+(`BASE_CFG_REG_NGR+(slice*`GROUP_NUMBER*`GRP_CFG_REG_NUM)+neuron_group*`GRP_CFG_REG_NUM+3)*4)
`define NG_FILTER_MAIN_CFG(slice,neuron_group)       (`CFG_REG_OFFSET+(`BASE_CFG_REG_NGR+(slice*`GROUP_NUMBER*`GRP_CFG_REG_NUM)+neuron_group*`GRP_CFG_REG_NUM+4)*4)

`define STR_MAIN_CTRL_CFG(streamer)                  (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+0)*4)
`define STR_OUT_STREAM_CFG(streamer)                 (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+1)*4)
`define STR_TCDM_START_ADDR_CFG(streamer)            (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+2)*4)
`define STR_TCDM_ADDR_STEP_CFG(streamer)             (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+3)*4)
`define STR_TCDM_END_ADDR_CFG(streamer)              (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+4)*4)
`define STR_TCDM_TRAN_SIZE_CFG(streamer)             (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+5)*4)
`define STR_SRAM_START_ADDR_CFG(streamer)            (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+6)*4)
`define STR_SRAM_ADDR_STEP_CFG(streamer)             (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+7)*4)
`define STR_SRAM_END_ADDR_CFG(streamer)              (`CFG_REG_OFFSET+(`BASE_CFG_REG_STR+streamer*`STR_CFG_REG_NUM+8)*4)

`define XBAR_SLAVE_NODE(slave)                       (`CFG_REG_OFFSET+(`BASE_CFG_REG_XBR+slave)*4)
`define UDMA_GATEWAY_MAIN_CFG                        (`CFG_REG_OFFSET+(`BASE_CFG_REG_GTW)*4)

`define ORACLE_OBS_MAIN_CFG                          (`CFG_REG_OFFSET+(`BASE_CFG_REG_ORC+1)*4)
`define ORACLE_OBS_ADDR_CFG(observer)                (`CFG_REG_OFFSET+(`BASE_CFG_REG_ORC+observer+2)*4)

//--- global power management registers
`define BASE_CLKG_SLC                                (0)

`define GPM_SLICE_CKG                                (`GPM_REG_OFFSET+(`BASE_CLKG_SLC+0)*4)
`define GPM_MAIN_CKG                                 (`GPM_REG_OFFSET+(`BASE_CLKG_SLC+1)*4)  //--- careful bit 8 is used as a main clock gating fro cfg registers
`define ONLINE_LEARNING_CFG                          (`ONLINE_REG_OFFSET+(0)*4)
`define ONLINE_LEARNING_VAL                          (`ONLINE_REG_OFFSET+(1)*4)

