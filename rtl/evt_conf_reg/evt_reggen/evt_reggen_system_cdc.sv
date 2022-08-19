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
module evt_reggen_system_cdc 
  import sne_evt_stream_pkg::config_system_sw_t;
  import sne_evt_stream_pkg::config_system_hw_t;
  import sne_evt_stream_pkg::apb_req_t;
  import sne_evt_stream_pkg::apb_rsp_t; 
  import sne_evt_stream_pkg::apb_input_t;
  import sne_evt_stream_pkg::apb_output_t; 
(
  input src_clk_i,    // Clock
  input src_rst_ni, // Clock Enable
  input dst_clk_i,  // Asynchronous reset active low
  input dst_rst_ni,
  output config_system_sw_t config_system_sw_o,
  input config_system_hw_t config_system_hw_i,
  input apb_req_t reg_src_req,
  output apb_rsp_t reg_src_rsp
);

typedef enum logic [0:0] {
  WAIT,
  READ_WRITE
}state_t;

// state_t state_ip_d, state_ip_q;
state_t state_op_d, state_op_q;
always_comb begin
  state_op_d = state_op_q;
  case (state_op_q)
    WAIT : begin
      if(reg_src_req.valid) begin
         state_op_d = READ_WRITE;
      end else begin 
        state_op_d = WAIT;
      end 
    end
    READ_WRITE : begin 
      state_op_d = WAIT;
    end
    default : state_op_d = WAIT;
   endcase 
end
apb_input_t reg_intf_req_d,reg_intf_req_q, reg_intf_req;
always_comb begin
  // reg_intf_req = reg_src_req.req;
  reg_intf_req_d.wdata = reg_src_req.req.wdata;
  reg_intf_req_d.wstrb = reg_src_req.req.wstrb;
  reg_intf_req_d.write = reg_src_req.req.write;
  reg_intf_req_d.addr =  reg_src_req.req.addr;
  reg_intf_req_d.valid =  reg_src_req.valid;

  reg_intf_req.wdata = reg_src_req.req.wdata;
  reg_intf_req.wstrb = reg_src_req.req.wstrb;
  reg_intf_req.write = reg_src_req.req.write;
  reg_intf_req.addr =  reg_src_req.req.addr;
  reg_intf_req.valid =  reg_src_req.valid;
  case (state_op_q)
    WAIT : begin
      reg_intf_req.valid = 1'b0;
      reg_src_rsp.valid = 1'b0;
      reg_intf_req_d.wdata = reg_src_req.req.wdata;
      reg_intf_req_d.wstrb = reg_src_req.req.wstrb;
      reg_intf_req_d.write = reg_src_req.req.write;
      reg_intf_req_d.addr =  reg_src_req.req.addr;
      reg_intf_req_d.valid =  reg_src_req.valid;
    end
    READ_WRITE : begin
      reg_src_rsp.valid = 1'b1;
      reg_intf_req.wdata = reg_intf_req_q.wdata;
      reg_intf_req.wstrb = reg_intf_req_q.wstrb;
      reg_intf_req.write = reg_intf_req_q.write;
      reg_intf_req.addr =  reg_intf_req_q.addr;
      reg_intf_req.valid = reg_intf_req_q.valid;
    end
   endcase 
end


always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin : proc_state_q
  if(~dst_rst_ni) begin
    state_op_q <= WAIT;
    reg_intf_req_q.wdata = 0;
    reg_intf_req_q.wstrb = 0;
    reg_intf_req_q.write = 0;
    reg_intf_req_q.addr  = 0;
    reg_intf_req_q.valid = 0;
  end else begin
    state_op_q <= state_op_d;
    reg_intf_req_q.wdata = reg_intf_req_d.wdata;
    reg_intf_req_q.wstrb = reg_intf_req_d.wstrb;
    reg_intf_req_q.write = reg_intf_req_d.write;
    reg_intf_req_q.addr  = reg_intf_req_d.addr;
    reg_intf_req_q.valid = reg_intf_req_d.valid;
  end
end

system_clock_reg_top #(
  .reg_req_t ( apb_input_t ),
  .reg_rsp_t ( apb_output_t )
  )i_bus_clock_reg_top(
    .clk_i     	( dst_clk_i      ),
    .rst_ni    	( dst_rst_ni      ),
    .reg_req_i 	( reg_intf_req),
    .reg_rsp_o 	( reg_src_rsp.rsp),
    .devmode_i 	( 1'b1              ),
    .reg2hw    	( config_system_sw_o.reg2hw),
    .hw2reg    	( config_system_hw_i.hw2reg)
  );

endmodule