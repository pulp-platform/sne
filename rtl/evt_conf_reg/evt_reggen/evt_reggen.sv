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
`include "register_interface/assign.svh"
`include "evt_stream_macros.svh"

module evt_reggen 
	import sne_evt_stream_pkg::*;
  import sne_pkg::*;
	#(parameter DP_GROUP=16,parameter BASE_ADDRESS = 32'h1E00_0000)
(
  	input  logic        						              system_clk_i          ,
  	input  logic        						              system_rst_ni         ,
    input  logic                                  bus_clk_i             ,
    input  logic                                  bus_rst_ni            ,
    input  logic                                  sne_engine_clk_i      ,
    input  logic                                  sne_engine_rst_ni     ,
  	input  logic                                  apb_slave_pwrite      , 
  	input  logic                                  apb_slave_psel        ,
  	input  logic                                  apb_slave_penable     ,
  	input  logic [31:0]                           apb_slave_paddr       ,
  	input  logic [31:0]                           apb_slave_pwdata      ,
  	output logic [31:0]                           apb_slave_prdata      ,
  	output logic                                  apb_slave_pready      , 
  	output logic                                  apb_slave_pslverr     ,
    output logic [$clog2(ENGINES)-1:0]            engine_id             ,
    output logic [$clog2(DP_GROUP)-1:0]           group_id              ,
  	output config_bus_t                           config_bus_i          ,
    output config_system_sw_t                     config_system_sw_o    ,
    input config_system_hw_t                      config_system_hw_i    ,
    input logic [ENGINES-1:0][31:0]               online_data_i         ,
    output config_engine_t                        config_engine_i                     
);



REG_BUS  #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) reg_o (.clk_i(system_clk_i));
// REG_BUS  #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) reg_src (.clk_i(sne_engine_clk_i));

apb_to_reg i_apb_to_reg(
  .clk_i    (  system_clk_i  ),
  .rst_ni   (  system_clk_i ),
  .penable_i(  apb_slave_penable  ),
  .pwrite_i (  apb_slave_pwrite   ),
  .paddr_i  (  apb_slave_paddr-BASE_ADDRESS),
  .psel_i   (  apb_slave_psel     ),
  .pwdata_i (  apb_slave_pwdata   ),
  .prdata_o (  apb_slave_prdata   ),
  .pready_o (  apb_slave_pready   ),
  .pslverr_o(  apb_slave_pslverr  ),
  .reg_o    (  reg_o      		  )
);

apb_req_t reg_engine_req, reg_system_req, reg_bus_req;
apb_rsp_t reg_engine_rsp, reg_system_rsp, reg_bus_rsp;

`REG_BUS_ASSIGN_TO_REQ(reg_bus_req.req, reg_o );
`REG_BUS_ASSIGN_TO_REQ(reg_system_req.req, reg_o);
`REG_BUS_ASSIGN_TO_REQ(reg_engine_req.req, reg_o);

typedef enum logic [1:0] {
  WAIT,
  READ_WRITE,
  SEND,
  STOP
}state_t;

state_t state_ip_d, state_ip_q;
// assign reg_engine_rsp.ready = 1'b1;
// assign reg_system_rsp.ready = 1'b1;
// assign reg_bus_rsp.ready    = 1'b1;
logic error, ready;
logic [DATA_WIDTH-1:0] rdata;

logic [2:0] request_demux, request_demux_d,request_demux_q;//0-engine,1-bus,2-system
assign request_demux[2] = (reg_o.addr>=SYSTEM_CLOCK_OFFSET && reg_o.addr<BUS_CLOCK_OFFSET); 
assign request_demux[1] = (reg_o.addr>=BUS_CLOCK_OFFSET    && reg_o.addr<ENGINE_CLOCK_OFFSET); 
assign request_demux[0] = (reg_o.addr>=ENGINE_CLOCK_OFFSET); 

always_comb begin
  // if(state_ip_q==READ_WRITE)
   unique case(request_demux_q)
    3'b001 : begin
      rdata = reg_engine_rsp.rsp.rdata;
      ready = reg_engine_rsp.valid; 
      error = reg_engine_rsp.valid ? reg_engine_rsp.rsp.error : 0; 
    end 
    3'b010 : begin 
      rdata = reg_bus_rsp.rsp.rdata;
      ready = reg_bus_rsp.valid; 
      error = reg_bus_rsp.valid ? reg_bus_rsp.rsp.error : 0;
    end
    3'b100 : begin 
      rdata = reg_system_rsp.rsp.rdata;
      ready = reg_system_rsp.valid; 
      error = reg_system_rsp.valid ? reg_system_rsp.rsp.error : 0;
    end 
    default : begin 
      rdata = 0;
      ready = 0; 
      error = 0;
    end
   endcase
end

always_comb begin
  state_ip_d = state_ip_q;
  // reg_bus_rsp.ready    = 1'b0;
  // reg_system_rsp.ready = 1'b0;
  // reg_engine_rsp.ready = 1'b0;
  case(state_ip_q)
    WAIT : begin
      if(reg_o.valid) begin
        state_ip_d = READ_WRITE; 
      end  
    end
    READ_WRITE : begin 
      if(ready) begin 
        state_ip_d = SEND;
      end
      // reg_bus_rsp.ready    = 1'b1;
      // reg_system_rsp.ready = 1'b1;
      // reg_engine_rsp.ready = 1'b1;
    end 
    SEND : 
      state_ip_d = WAIT;
    default: state_ip_d = WAIT;
  endcase 
end

always_comb begin
  request_demux_d = request_demux_q;
  reg_o.rdata = 0;
  reg_o.ready = 0; 
  reg_o.error = 0;
  case (state_ip_q)
    WAIT : begin 
      reg_bus_req.valid    = (reg_o.valid)&& request_demux[1];
      reg_system_req.valid = (reg_o.valid)&& request_demux[2];
      reg_engine_req.valid = (reg_o.valid)&& request_demux[0];
      request_demux_d      = request_demux;
    end
    READ_WRITE : begin
      reg_bus_req.valid    = 0;
      reg_system_req.valid = 0;
      reg_engine_req.valid = 0;
      reg_o.rdata = rdata;
      reg_o.ready = ready; 
      reg_o.error = error;
    end
    SEND : begin
      reg_bus_req.valid    = 0;
      reg_system_req.valid = 0;
      reg_engine_req.valid = 0;
    end
    default : begin
      reg_bus_req.valid    = 0;
      reg_system_req.valid = 0;
      reg_engine_req.valid = 0;
    end 
   endcase 
end

always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_
  if(~system_rst_ni) begin
     state_ip_q <= WAIT;
     request_demux_q <= 0;
  end else begin
     state_ip_q <= state_ip_d;
     request_demux_q <= request_demux_d;
  end
end

evt_reggen_engine_cdc i_evt_reggen_engine_cdc(
  .src_clk_i  (system_clk_i     ),    // Clock
  .src_rst_ni (system_rst_ni    ), // Clock Enable
  .dst_clk_i  (sne_engine_clk_i ),  // Asynchronous reset active low
  .dst_rst_ni (sne_engine_rst_ni),
  .config_engine_i(config_engine_i),
  .online_data_i(online_data_i  ),
  .engine_id  (engine_id        ),
  .group_id   (group_id         ),
  .reg_src_req(reg_engine_req   ),
  .reg_src_rsp(reg_engine_rsp   )
);

evt_reggen_bus_cdc i_evt_reggen_bus_cdc(
  .src_clk_i  (system_clk_i     ),    // Clock
  .src_rst_ni (system_rst_ni    ), // Clock Enable
  .dst_clk_i  (bus_clk_i ),  // Asynchronous reset active low
  .dst_rst_ni (bus_rst_ni),
  .config_bus_i(config_bus_i    ),
  .reg_src_req(reg_bus_req   ),
  .reg_src_rsp(reg_bus_rsp   )
);

evt_reggen_system_cdc i_evt_reggen_system_cdc(
  .src_clk_i  (system_clk_i     ),    // Clock
  .src_rst_ni (system_rst_ni    ), // Clock Enable
  .dst_clk_i  (system_clk_i ),  // Asynchronous reset active low
  .dst_rst_ni (system_rst_ni),
  .config_system_sw_o(config_system_sw_o),
  .config_system_hw_i(config_system_hw_i),
  .reg_src_req(reg_system_req   ),
  .reg_src_rsp(reg_system_rsp   )
);

endmodule