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
module evt_reggen_engine_cdc 
  import engine_clock_reg_pkg::ENGINE_CLOCK_WIN1_OFFSET; 
  import sne_evt_stream_pkg::*; 
  import sne_pkg::*;
(
  input logic src_clk_i,    // Clock
  input logic src_rst_ni, // Clock Enable
  input logic dst_clk_i,  // Asynchronous reset active low
  input logic dst_rst_ni,
  input logic [ENGINES-1:0][31:0] online_data_i,
  output logic [$clog2(ENGINES)-1:0] engine_id,
  output logic [$clog2(CLUSTERS)-1:0] group_id,
  output config_engine_t config_engine_i,
  input apb_req_t reg_src_req,
  output apb_rsp_t reg_src_rsp
);

typedef enum logic [0:0] {
  WAIT,
  READ_WRITE
  // SEND,
  // STOP
}state_t;

// state_t state_ip_d, state_ip_q;
state_t state_op_d, state_op_q;

apb_req_t reg_dst_req, reg_bus_req;
apb_rsp_t reg_dst_rsp, reg_bus_rsp;
apb_input_t win_req;
apb_output_t win_rsp;

cdc_fifo_2phase #(
    .T        ( apb_input_t         ),
    .LOG_DEPTH( 1 )

    ) i_cdc_fifo_req_2phase (
    
    .src_rst_ni ( src_rst_ni    ),
    .src_clk_i  ( src_clk_i   ),

    .src_data_i ( reg_src_req.req   ),
    .src_valid_i( reg_src_req.valid ),
    .src_ready_o(                   ),

    .dst_rst_ni ( dst_rst_ni ),
    .dst_clk_i  ( dst_clk_i  ),

    .dst_data_o ( reg_dst_req.req   ),
    .dst_valid_o( reg_dst_req.valid ),
    .dst_ready_i( reg_dst_req.ready )

);

cdc_fifo_2phase #(
    .T        ( apb_output_t         ),
    .LOG_DEPTH( 1 )

    ) i_cdc_fifo_rsp_2phase (

    .src_rst_ni ( dst_rst_ni ),
    .src_clk_i  ( dst_clk_i  ),

    .src_data_i ( reg_dst_rsp.rsp),
    .src_valid_i( reg_dst_rsp.valid),
    .src_ready_o( reg_dst_rsp.ready),
    
    .dst_rst_ni ( src_rst_ni    ),
    .dst_clk_i  ( src_clk_i     ),
    
    .dst_data_o ( reg_src_rsp.rsp   ),
    .dst_valid_o( reg_src_rsp.valid ),
    .dst_ready_i( 1'b1              )

);
// assign reg_src_rsp.ready = 1'b1;
always_comb begin
  state_op_d = state_op_q;
  case (state_op_q)
    WAIT : begin
      if(reg_dst_req.valid) begin
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
apb_input_t reg_intf_req;
always_comb begin
  // reg_intf_req = reg_src_req.req;
  reg_intf_req.wdata = reg_dst_req.req.wdata;
  reg_intf_req.wstrb = reg_dst_req.req.wstrb;
  reg_intf_req.write = reg_dst_req.req.write;
  reg_intf_req.addr =  reg_dst_req.req.addr;
  case (state_op_q)
    WAIT : begin
      reg_dst_req.ready = 1'b0;
      reg_intf_req.valid = 1'b0;
      reg_dst_rsp.valid = 1'b0;
    end
    READ_WRITE : begin
      reg_dst_req.ready = 1'b1;
      reg_intf_req.valid = reg_dst_req.valid;
      reg_dst_rsp.valid = 1'b1;
    end
   endcase 
end

logic [$clog2(ENGINES)-1:0] engine_id_q;
always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin : proc_state_q
  if(~dst_rst_ni) begin
    state_op_q <= WAIT;
    engine_id_q<= 0;
  end else begin
    state_op_q <= state_op_d;
    engine_id_q<= engine_id;
  end
end

always_comb begin
  if(ENGINES>1) begin
    engine_id = config_engine_i.online_addr[$clog2(ENGINES)+$clog2(CLUSTERS)+(SEQ_ADDR_WIDTH)-1:$clog2(CLUSTERS)+(SEQ_ADDR_WIDTH)];
    group_id  = config_engine_i.online_addr[$clog2(CLUSTERS)+(SEQ_ADDR_WIDTH)-1:(SEQ_ADDR_WIDTH)                                 ];
  end else begin 
    engine_id = config_engine_i.online_addr[$clog2(CLUSTERS)+(SEQ_ADDR_WIDTH)];
    group_id  = config_engine_i.online_addr[$clog2(CLUSTERS)+(SEQ_ADDR_WIDTH)-1:(SEQ_ADDR_WIDTH)                                 ];
  end
end

assign config_engine_i.online_addr = (win_req.addr-ENGINE_CLOCK_WIN1_OFFSET);
assign win_rsp.rdata = online_data_i[engine_id_q];
assign win_rsp.ready = 1'b1;
assign win_rsp.error = 1'b0; 

engine_clock_reg_top #(
  .reg_req_t ( apb_input_t ),
  .reg_rsp_t ( apb_output_t )
  )i_engine_clock_reg_top(
    .clk_i     	( dst_clk_i      ),
    .rst_ni    	( dst_rst_ni      ),
    .reg_req_i 	( reg_intf_req),
    .reg_rsp_o 	( reg_dst_rsp.rsp),
    .devmode_i 	( 1'b1              ),
    .reg_req_win_o( win_req        	),
    .reg_rsp_win_i( win_rsp        	),
    .reg2hw    	( config_engine_i.reg2hw   ),
    .hw2reg    	( config_engine_i.hw2reg   )
  );

endmodule