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
`include "register_interface/typedef.svh"

package sne_pkg;

	localparam ENGINES = `SLICES;
	localparam STREAMERS = 2;
	localparam CLUSTERS = `NGGROUPS;

	localparam SEQ_ADDR_WIDTH = 6;
	localparam FC_FIFO_DEPTH  = 10;
	localparam SYSTEM_CLOCK_OFFSET = 32'h00;
	localparam BUS_CLOCK_OFFSET = 32'h200;
	localparam ENGINE_CLOCK_OFFSET = 32'h300;

	typedef struct packed {
		logic          req;
		logic [31:0]   add;
		logic          wen;
		logic [31:0]   wdata;
		logic [3:0]    be;
	} tcdm_req_t;
	typedef struct packed {
		logic         gnt;
		logic         r_opc;
		logic [31:0]  r_rdata;
		logic         r_valid;
	}tcdm_rsp_t;

   typedef logic [31:0] addr_t;
	 typedef logic [31:0] data_t;
	 typedef logic [32/8-1:0] strb_t;
	 `REG_BUS_TYPEDEF_REQ(reg_req_t, addr_t, data_t, strb_t)
	 `REG_BUS_TYPEDEF_RSP(reg_rsp_t, data_t)
   
endpackage