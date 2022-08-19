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

//--- addr gen modes
`ifndef ENABLE
	`define ENABLE 4'b0001
`endif

`ifndef SEQ
	`define SEQ    4'b0011
`endif

`ifndef BYP
	`define BYP    4'b0101
`endif

`ifndef INIT
	`define INIT   4'b0111
`endif

`ifndef PAUSE
	`define PAUSE  4'b1001
`endif

`ifndef SINGLE
    `define SINGLE  4'b1010
`endif

//------LAYERS----------
`ifndef DEFAULT
    `define DEFAULT  2'b00
`endif
`ifndef CONV
    `define CONV  2'b01
`endif
`ifndef OPT_CONV
    `define OPT_CONV  2'b01
`endif
`ifndef FC
    `define FC    2'b10
`endif
//-----------------------


//--- APB bus memory addresses
`ifndef APB_PARAM_MEM_ADDR_START
	`define APB_PARAM_MEM_ADDR_START   32'h00010000
`endif
`ifndef APB_PARAM_MEM_ADDR_END
	`define APB_PARAM_MEM_ADDR_END     32'h000100FF
`endif

`ifndef APB_STATUS_MEM_ADDR_START
	`define APB_STATUS_MEM_ADDR_START  32'h00010100
`endif
`ifndef APB_STATUS_MEM_ADDR_END
	`define APB_STATUS_MEM_ADDR_END    32'h000101FF
`endif

`ifndef APB_WEIGHT_MEM_ADDR_START
	`define APB_WEIGHT_MEM_ADDR_START  32'h00000000
`endif
`ifndef APB_WEIGHT_MEM_ADDR_END
	`define APB_WEIGHT_MEM_ADDR_END  32'h0000FFFF
`endif

`ifndef APB_CFG_REGS_ADDR_START
	`define APB_CFG_REGS_ADDR_START  32'h00020000
`endif
`ifndef APB_CFG_REGS_ADDR_END
	`define APB_CFG_REGS_ADDR_END  32'h00030000
`endif

//--- XBAR port numbering
`ifndef MASTER_port_0
    `define MASTER_port_0 0;
`endif
`ifndef MASTER_port_1
    `define MASTER_port_1 1;
`endif
`ifndef MASTER_port_2
    `define MASTER_port_2 2;
`endif
`ifndef MASTER_port_3
    `define MASTER_port_3 3;
`endif
`ifndef MASTER_port_4
    `define MASTER_port_4 4;
`endif
`ifndef MASTER_port_5
    `define MASTER_port_5 5;
`endif
`ifndef MASTER_port_6
    `define MASTER_port_6 6;
`endif
`ifndef MASTER_port_7
    `define MASTER_port_7 7;
`endif
`ifndef MASTER_port_8
    `define MASTER_port_8 8;
`endif
`ifndef MASTER_port_9
    `define MASTER_port_9 9;
`endif
`ifndef MASTER_port_10
    `define MASTER_port_10 10;
`endif
`ifndef MASTER_port_11
    `define MASTER_port_11 11;
`endif
`ifndef MASTER_port_12
    `define MASTER_port_12 12;
`endif
`ifndef MASTER_port_13
    `define MASTER_port_13 13;
`endif
`ifndef MASTER_port_14
    `define MASTER_port_14 14;
`endif
`ifndef MASTER_port_15
    `define MASTER_port_15 15;
`endif

//---------------------------------------- input spike types from the memory
`ifndef NO_EVT
    `define NO_EVT 4'b0000
`endif

`ifndef SPIKE_EVT
    `define SPIKE_EVT 4'b0001
`endif

`ifndef WEIGHT_UPDT_EVT
    `define WEIGHT_UPDT_EVT 4'b0010
`endif

`ifndef ACCUMULATE_EVT
    `define ACCUMULATE_EVT 4'b0011
`endif

`ifndef WIPE_EVT
    `define WIPE_EVT 4'b0100
`endif

`ifndef TIME_EVT
    `define TIME_EVT 4'b0101
`endif

`ifndef CHANGE_WEIGHT_EVT
    `define CHANGE_WEIGHT_EVT 4'b0111
`endif

`ifndef PKT_END_EVT
    `define PKT_END_EVT 4'b1111
`endif

//---------------------------------------- LIF operations
`ifndef IDLE_OP
    `define IDLE_OP 3'b000
`endif

`ifndef SPIKE_OP
    `define SPIKE_OP 3'b001
`endif

`ifndef WEIGHTS_LD_OP
    `define WEIGHTS_LD_OP 3'b010
`endif

`ifndef TIME_STEP_OP
    `define TIME_STEP_OP 3'b011
`endif

`ifndef INTEGRATE_OP
    `define INTEGRATE_OP 3'b100
`endif

`ifndef UPDATE_OP
    `define UPDATE_OP 3'b110
`endif

`ifndef RST_OP
    `define RST_OP 3'b101
`endif
