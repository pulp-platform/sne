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
module evt_streamer_ctrl 
import sne_evt_stream_pkg::EVT_SPIKE;
import sne_evt_stream_pkg::EVT_TIME;
import sne_evt_stream_pkg::spike_t;
import sne_evt_stream_pkg::EOP;
import sne_evt_stream_pkg::config_system_sw_t;
import sne_evt_stream_pkg::config_system_hw_t;
#( parameter STREAMER_ID = 0)(

  input  logic        system_clk_i          ,  
  input  logic        system_rst_ni         ,  
  input  logic        evt_i                 , 
  input  logic        power_gate            ,
  input  logic        power_sleep           ,         
  // tcdm master port           
  output logic        tcdm_req_o            ,
  input  logic        tcdm_gnt_i            ,
  output logic [31:0] tcdm_add_o            ,
  output logic        tcdm_wen_o            ,
  output logic [ 3:0] tcdm_be_o             ,
  output logic [31:0] tcdm_data_o           ,
  output logic        interrupt_o           ,
  input  logic [31:0] tcdm_r_data_i         ,
  input  logic        tcdm_r_valid_i        ,
  output logic [31:0] sta_main_status_o     ,
  //--- streamer main status/configuration register
  input config_system_sw_t config_i         ,
  // output config_system_hw_t config_o        ,
  //--- from the accelerator
  SNE_EVENT_STREAM.dst evt_stream_dst       , // incoming stream
  //--- to the accelerator
  SNE_EVENT_STREAM.src evt_stream_src         // outgoing stream
);
logic [31:0] cfg_main_ctrl_i       ;
//--- streamer status registers
logic [31:0] sta_trans_ptr_o       ;             
// //--- streamer configuration addresses
logic [31:0] cfg_out_stream_i      ;
logic [31:0] cfg_tcdm_start_addr_i ;
logic [31:0] cfg_tcdm_addr_step_i  ;
logic [31:0] cfg_tcdm_end_addr_i   ;
logic [31:0] cfg_tcdm_tran_size_i  ;
logic [31:0] cfg_sram_start_addr_i ;
logic [31:0] cfg_sram_addr_step_i  ;
logic [31:0] cfg_sram_end_addr_i   ;
//--- control signals declaration
logic        streamer_trigger_s         ;
logic        streamer_armed_s           ;
logic        streamer_op_s              ;
logic        streamer_transfer_end_s    ;
logic        streamer_tran_end_mode_s   ;
logic        streamer_ptr_sel_s         ;
logic        streamer_load_mem_s        ;
//--- datapath signal declaration
logic [31:0] tcdm_address_s             ;
logic [31:0] tcdm_transaction_counter_s ;
logic        address_r_step_en_s        ;
logic        address_w_step_en_s        ;
logic        address_rw_step_en_s       ;
logic [31:0] pause_data_s               ;
logic        end_addr_based_transfer_end_s;
logic        tran_size_based_transfer_end_s;
//--- fsm output signals
logic        streamer_raddr_step_en_s   ;
logic        streamer_waddr_step_en_s   ;
logic        streamer_tcdm_addr_init_s  ;
logic        pause_valid_s              ;
// FC layer signals
logic [9:0]  tran_count                 ;
//Context Switch Signals 
logic        cfg_context_fifo_init_i     ;
logic        cfg_context_fifo_flush_i    ;
logic        cfg_context_switch_mode_i   ;
logic [7:0]  cfg_context_switch_count_i  ;
logic        pop_next_context_address    ;
logic        push_enable, pop_enable     ;
logic        time_evt                    ;
logic        context_state_incr          ;
logic        end_operation_evt           ;
logic        end_context_switch          ;
logic        push_current_context_address;
logic        context_mode_valid          ;
logic [31:0] current_context_address     ;
logic [31:0] next_context_address        ;
logic [31:0] latch_tcdm_address_d, latch_tcdm_address_q;
logic [7:0]  context_state_d,      context_state_q     ;

//FC layer signals
logic        spike_evt                           ;
logic        end_fc                              ;
logic        cfg_fc_mode_i                       ;
logic        weight_fetch_fc_d, weight_fetch_fc_q;
logic [31:0] return_fc_addr_d, return_fc_addr_q  ;
logic [31:0] return_fc_cnt_d,  return_fc_cnt_q   ;
logic [15:0] cfg_fc_tran_size_i,cfg_weight_count_i;
logic [31:0] cfg_fc_offset_i                     ;
logic [31:0] cfg_fc_dimension_i                  ;
logic [31:0] spike_decoded_address               ;
logic [7:0]  cfg_x_dimension, cfg_y_dimension    ;
spike_t      spike_id_d, spike_id_q              ;
logic        weight_fetch_end, update_weight_addr;

logic        cfg_store_check                     ;
logic        cfg_set_interrupt                   ;
logic [3:0]  cfg_interrupt_compare_value         ;                   

//--- control signal binding
assign cfg_main_ctrl_i            = config_i.reg2hw.cfg_main_ctrl_i[STREAMER_ID];
assign cfg_out_stream_i           = config_i.reg2hw.cfg_out_stream_i[STREAMER_ID];
assign cfg_tcdm_end_addr_i        = config_i.reg2hw.cfg_tcdm_end_addr_i[STREAMER_ID];
assign cfg_sram_end_addr_i        = config_i.reg2hw.cfg_sram_end_addr_i[STREAMER_ID];
assign cfg_sram_addr_step_i       = config_i.reg2hw.cfg_sram_addr_step_i[STREAMER_ID];
assign cfg_tcdm_tran_size_i       = config_i.reg2hw.cfg_tcdm_tran_size_i[STREAMER_ID];//dont use parameters rather ports
assign cfg_tcdm_addr_step_i       = config_i.reg2hw.cfg_tcdm_addr_step_i[STREAMER_ID];
assign cfg_tcdm_start_addr_i      = config_i.reg2hw.cfg_tcdm_start_addr_i[STREAMER_ID];
assign cfg_sram_start_addr_i      = config_i.reg2hw.cfg_sram_start_addr_i[STREAMER_ID];
assign cfg_fc_tran_size_i         = config_i.reg2hw.cfg_fc_tran_size_i[STREAMER_ID][31:16];
assign cfg_weight_count_i         = config_i.reg2hw.cfg_fc_tran_size_i[STREAMER_ID][15:0];
assign cfg_fc_offset_i            = config_i.reg2hw.cfg_fc_offset_i;
assign cfg_x_dimension            = config_i.reg2hw.cfg_fc_dimension_i.x_dim;
assign cfg_y_dimension            = config_i.reg2hw.cfg_fc_dimension_i.y_dim;

assign streamer_armed_s           = cfg_main_ctrl_i[0];
assign streamer_trigger_s         = cfg_main_ctrl_i[8] ? evt_i : cfg_main_ctrl_i[1]; //--- triggers the transaction, can be overrided by external event if enabled
assign streamer_op_s              = cfg_main_ctrl_i[2]; //--- '1' : load                |  '0' : store
assign streamer_tran_end_mode_s   = cfg_main_ctrl_i[3]; //--- '0' : transaction size    |  '1' : end address
assign streamer_ptr_sel_s         = cfg_main_ctrl_i[4]; //--- '0' : transaction counter |  '1' : tcdm address
assign streamer_load_mem_s        = cfg_main_ctrl_i[5];
assign cfg_context_fifo_init_i    = cfg_main_ctrl_i[9];
assign cfg_context_switch_mode_i  = cfg_main_ctrl_i[6];
assign cfg_fc_mode_i              = cfg_main_ctrl_i[7];
assign cfg_context_switch_count_i = cfg_main_ctrl_i[17:10];//number of context switch states
assign cfg_context_fifo_flush_i   = cfg_main_ctrl_i[18]; 
assign cfg_set_interrupt          = cfg_main_ctrl_i[19];
assign cfg_store_check            = cfg_main_ctrl_i[20];
assign cfg_interrupt_compare_value= cfg_main_ctrl_i[24:21];

assign spike_decoded_address    = ((spike_id_q.cid * cfg_y_dimension * cfg_x_dimension + spike_id_q.yid * cfg_x_dimension + spike_id_q.xid)*cfg_weight_count_i + cfg_fc_offset_i)*4; 
//--- streamer controller (FSM)

logic store_end_d, store_end_q;


always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_interrupt_o
  if(~system_rst_ni) begin
    interrupt_o <= 0;
  end else begin
    if(cfg_set_interrupt) begin
      if(cfg_interrupt_compare_value==sta_main_status_o[3:0]) begin 
        interrupt_o <= 1'b1;
      end else begin 
        interrupt_o <= 1'b0;
      end 
    end else begin 
      interrupt_o <= 1'b0;
    end 
  end
end

enum logic [3:0] {

  RESET       ,
  IDLE        ,
  LOAD        ,
  STREAM_IN   ,
  STREAM_PAUSE,
  STORE       ,
  STREAM_OUT  ,
  TRANSFER_END,
  FIFO_INIT   ,
  PUSH_CURRENT_STATE,
  POP_NEXT_STATE,
  FC_STORE_CURRENT_STATE,
  FC_TRANSFER_END

} PS, NS;

always_ff @(posedge system_clk_i or negedge  system_rst_ni) begin : proc_PS
  if(~system_rst_ni) begin
    PS <= RESET;
  end else begin
    PS <= NS;
  end
end

always_comb begin : proc_NS
  case (PS)
    RESET    : begin
      if(streamer_armed_s) begin
        NS = IDLE;
      end else begin
        NS = RESET;
      end
    end

    IDLE     : begin
      if(streamer_trigger_s) begin
        if(streamer_op_s) begin
          NS = LOAD;
        end else begin
          NS = STORE;
        end
      end else begin
        NS = IDLE;
      end
    end

    LOAD     : begin
      if(cfg_context_fifo_init_i) begin 
        NS = FIFO_INIT;
      end else begin 
        NS = STREAM_IN;
      end
    end
    FIFO_INIT : begin 
      if(streamer_transfer_end_s) begin
        NS = TRANSFER_END; 
      end else begin 
        NS = FIFO_INIT;
      end 
    end 
    STREAM_IN: begin
      if(streamer_transfer_end_s && (weight_fetch_fc_q) && (evt_stream_src.ready)) begin 
        NS = FC_TRANSFER_END;
      end else if(streamer_transfer_end_s && (evt_stream_src.ready) & (~weight_fetch_fc_q)) begin 
        NS = TRANSFER_END;
      end else if((time_evt|end_operation_evt) && (evt_stream_src.ready) && (~weight_fetch_fc_q)) begin
        NS = POP_NEXT_STATE;
      end else if(spike_evt & (~weight_fetch_fc_q) && (evt_stream_src.ready)) begin
        NS = FC_STORE_CURRENT_STATE;
      end else if (tcdm_r_valid_i && ~evt_stream_src.ready) begin
        NS = STREAM_PAUSE;
      end else begin
        if(streamer_transfer_end_s) begin
          NS = TRANSFER_END;
        end else begin
          NS = STREAM_IN;
        end
      end
    end

    FC_STORE_CURRENT_STATE : begin
      NS = STREAM_IN; 
    end

    FC_TRANSFER_END : begin 
      NS = STREAM_IN;
    end 

    POP_NEXT_STATE : begin 
      NS = PUSH_CURRENT_STATE;
    end

    PUSH_CURRENT_STATE : begin 
      if(streamer_transfer_end_s) begin
        NS = TRANSFER_END; 
      end else begin
        NS = STREAM_IN; 
      end
    end 

    STREAM_PAUSE: begin
      if (evt_stream_src.ready) begin
        if(streamer_transfer_end_s && (weight_fetch_fc_q)) begin 
          NS = FC_TRANSFER_END;
        end else if(streamer_transfer_end_s & (~weight_fetch_fc_q)) begin
          NS = TRANSFER_END;
        end else if((time_evt|end_operation_evt) && (~weight_fetch_fc_q))begin
          NS = POP_NEXT_STATE;
        end else if(spike_evt & (~weight_fetch_fc_q) && (evt_stream_src.ready)) begin
          NS = FC_STORE_CURRENT_STATE;
        end else begin 
          NS = STREAM_IN;
        end 
      end else begin
        NS = STREAM_PAUSE;
      end
    end

    STORE    : begin
      NS = STREAM_OUT;
    end

    STREAM_OUT : begin
      if(streamer_transfer_end_s) begin
        NS = TRANSFER_END;
      end else begin
        NS = STREAM_OUT;
      end
    end

    TRANSFER_END: begin
      if(streamer_trigger_s) begin
        NS = TRANSFER_END;
      end else begin
        NS = IDLE;
      end
    end
  
    default  : begin
      NS = IDLE;
    end
  endcase
end

always_comb begin : proc_outputs
  
  pop_enable           = 0                   ;
  push_enable          = 0                   ;
  context_state_incr   = 0                   ;
  update_weight_addr   = 0                   ;
  context_state_d      = context_state_q     ;
  return_fc_addr_d     = return_fc_addr_q    ;
  latch_tcdm_address_d = latch_tcdm_address_q;
  weight_fetch_fc_d    = weight_fetch_fc_q   ;
  return_fc_cnt_d      = return_fc_cnt_q     ;
  spike_id_d           = spike_id_q          ;
  weight_fetch_end     = 0                   ;

  case (PS)
    RESET       : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000000;
     end

    IDLE        : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000002;
    end

    LOAD        : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b1;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000000;
    end

    STREAM_IN   : begin
      streamer_raddr_step_en_s  = 1'b1;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b1;
      pause_valid_s             = 1'b0;
      spike_id_d                = evt_stream_src.evt;
      latch_tcdm_address_d      = tcdm_address_s;
      //sta_main_status_o = 32'h00000010;
    end

    FIFO_INIT   : begin
      streamer_raddr_step_en_s  = 1'b1;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b1;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000010;
    end

    POP_NEXT_STATE : begin 
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      // pop_enable                = 1'b1;
      push_enable               = 1'b1;
    end 

    PUSH_CURRENT_STATE : begin 
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      pop_enable                = 1'b1;
      // push_enable               = 1'b1;
      context_state_incr        = 1'b1;
    end 

    FC_STORE_CURRENT_STATE : begin 
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      weight_fetch_fc_d         = 1'b1;
      update_weight_addr        = 1'b1;
      return_fc_addr_d          = latch_tcdm_address_q;
      return_fc_cnt_d           = tcdm_transaction_counter_s;
    end 

    FC_TRANSFER_END : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      weight_fetch_end          = 1'b1;
      weight_fetch_fc_d         = 1'b0; 
    end 

    STREAM_PAUSE   : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b1;
      pause_valid_s             = 1'b1;
      spike_id_d                = evt_stream_src.evt;
      latch_tcdm_address_d      = tcdm_address_s;
      //sta_main_status_o = 32'h00000010;
    end

    STORE       : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b1;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000000;
    end

    STREAM_OUT  : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b1;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000020;
    end

    TRANSFER_END:begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000001;
    end

    default     : begin
      streamer_raddr_step_en_s  = 1'b0;
      streamer_waddr_step_en_s  = 1'b0;
      streamer_tcdm_addr_init_s = 1'b0;
      tcdm_wen_o                = 1'b0;
      pause_valid_s             = 1'b0;
      //sta_main_status_o = 32'h00000000;
    end
  endcase
end

//--- request is asserted both during reading and writing of the TCDM memory
//--- request generation condition: during tcdm writing, forward the ready signal as request, otherwise, during reading forward the valid signal as request--reading to initialize the context_switch fifo as well as the cdc fifo.
assign tcdm_req_o                     = (evt_stream_src.ready && streamer_raddr_step_en_s) || (evt_stream_dst.valid && streamer_waddr_step_en_s) || (cfg_context_fifo_init_i && streamer_raddr_step_en_s);

//--- during tcdm writing, after the request is placed by the src valid signal, we use the TCDM grant as ready for the src fifo
assign evt_stream_dst.ready           = tcdm_gnt_i && streamer_waddr_step_en_s;

//--- during TCDM reading, we forward tcdm data valid as event dst fifo valid, the valid is masked to be active only during reading phase 
assign evt_stream_src.valid           = context_mode_valid & (tcdm_r_valid_i && streamer_raddr_step_en_s || pause_valid_s) & (~cfg_context_fifo_init_i); //--- in case we need to stop, keep asserting the valid

//--- data to write to the TCDM are taken from the src event fifo
assign tcdm_add_o                     = tcdm_address_s    ;
assign tcdm_data_o                    = evt_stream_dst.evt;
assign tcdm_be_o                      = 4'b1111           ; //--- we always perform word aligned TCDM access

//--- data read from the TCDM are pushed into the src event fifo
assign evt_stream_src.evt             = pause_valid_s ? pause_data_s : tcdm_r_data_i; //--- in case we need to stop, freeze the data

//--- enable the increment of the TCDM address during reading when dst event fifo is not full and a transaction finished
assign address_r_step_en_s            = tcdm_gnt_i && streamer_raddr_step_en_s;//evt_stream_dst.ready && evt_stream_dst.valid;

//--- enable the increment of the TCDM address during writing when  
assign address_w_step_en_s            = tcdm_gnt_i && streamer_waddr_step_en_s;//evt_stream_src.valid && evt_stream_src.ready;

//--- global condition for address increment (both for reading and writing)
assign address_rw_step_en_s           = address_w_step_en_s || address_r_step_en_s; 

//--- criteria for transaction end detection
assign end_addr_based_transfer_end_s  = (tcdm_address_s >= (cfg_tcdm_end_addr_i)) && streamer_tran_end_mode_s             ; //--- end transaction when end address is reached
assign tran_size_based_transfer_end_s = ((weight_fetch_fc_q && (tcdm_transaction_counter_s == cfg_fc_tran_size_i))||((tcdm_transaction_counter_s == cfg_tcdm_tran_size_i)))&& ~streamer_tran_end_mode_s ; //--- end transaction when transaction size is reached
assign streamer_transfer_end_s        = (end_addr_based_transfer_end_s || tran_size_based_transfer_end_s || end_context_switch ||end_fc||store_end_q); //--- global condition
assign sta_trans_ptr_o                = streamer_ptr_sel_s ? tcdm_address_s : tcdm_transaction_counter_s                  ; //--- expose either the address or the iteration on the status reg

always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_tcdm_address_s
  if(~system_rst_ni) begin
    tcdm_address_s             <= 0;
    tcdm_transaction_counter_s <= 0;
  end else begin
    if(push_enable) begin 
      tcdm_address_s             <= next_context_address      ;
      tcdm_transaction_counter_s <= tcdm_transaction_counter_s;
    end else if(update_weight_addr) begin 
      tcdm_address_s             <= spike_decoded_address     ;
      tcdm_transaction_counter_s <= 0                         ;
    end else if(weight_fetch_end) begin 
      tcdm_address_s             <= return_fc_addr_q          ;
      tcdm_transaction_counter_s <= return_fc_cnt_q           ;
    end else if(address_rw_step_en_s) begin
      tcdm_address_s             <= tcdm_address_s + cfg_tcdm_addr_step_i;
      tcdm_transaction_counter_s <= tcdm_transaction_counter_s + 1'b1    ;
    end else if(streamer_tcdm_addr_init_s) begin
      tcdm_address_s             <= (cfg_tcdm_start_addr_i)              ; 
      tcdm_transaction_counter_s <= 0                                    ;
    end
  end
end

//--- handle last data during src fifo saturation
always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_emergency_store
  if(~system_rst_ni) begin
    pause_data_s <= 0;
  end else if ( tcdm_r_valid_i && streamer_raddr_step_en_s ) begin
    pause_data_s <= tcdm_r_data_i;
  end
end

//--- report streamer status
assign sta_main_status_o = {27'b000000000000000000000000000,streamer_transfer_end_s,PS};

//--- Context state 
always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_context_state
  if(~system_rst_ni) begin
    context_state_q <= 0;
  end else if ( context_state_incr ) begin
    if(context_state_q==cfg_context_switch_count_i) begin
      context_state_q <= 0; 
    end else begin 
      context_state_q <= context_state_d + 1;
    end
  end
end

always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_latch_tcdm_addres_q
  if(~system_rst_ni) begin
    latch_tcdm_address_q <= 0;
    spike_id_q           <= 0;
    return_fc_addr_q     <= 0;
    return_fc_cnt_q      <= 0;
    weight_fetch_fc_q    <= 0;
  end else begin
    spike_id_q           <= spike_id_d;
    latch_tcdm_address_q <= latch_tcdm_address_d;
    return_fc_addr_q     <= return_fc_addr_d;
    return_fc_cnt_q      <= return_fc_cnt_d;
    weight_fetch_fc_q    <= weight_fetch_fc_d;
  end
end

memory_wrapped_fifo #(.DEPTH(256), .DATA_WIDTH(32)) i_context_switch_fifo(
  .clk_i      ( system_clk_i                ),
  .rst_ni     ( system_rst_ni               ),
  .flush_i    ( cfg_context_fifo_flush_i    ),
  .testmode_i ( 1'b0                        ),
  .power_sleep( power_sleep                 ),
  .power_gate ( power_gate                  ),
  .full_o     (                             ),
  .empty_o    (                             ),
  .usage_o    (                             ),
  .data_i     ( current_context_address     ),
  .push_i     ( push_current_context_address),
  .data_o     ( next_context_address        ),
  .pop_i      ( pop_next_context_address    )
);

always_comb begin : proc_fifo_init
  if(cfg_context_fifo_init_i) begin
    current_context_address      =  evt_stream_src.evt;
    push_current_context_address =  ((tcdm_r_valid_i && streamer_raddr_step_en_s) || pause_valid_s);
    pop_next_context_address     =  0;
  end else begin 
    current_context_address      = latch_tcdm_address_q;
    push_current_context_address = push_enable;
    pop_next_context_address     = pop_enable;
  end 
end

always_comb begin : proc_time_evt
  if(pause_valid_s) begin 
    time_evt          = (pause_data_s[31:28]==EVT_TIME) & (cfg_context_switch_mode_i); 
    end_operation_evt = (pause_data_s[31:28]==EOP) & (cfg_context_switch_mode_i);
    spike_evt         = (pause_data_s[31:28]==EVT_SPIKE) & (cfg_fc_mode_i);
  end else begin
    time_evt          = tcdm_r_valid_i & (tcdm_r_data_i[31:28]==EVT_TIME) & (cfg_context_switch_mode_i); 
    end_operation_evt = tcdm_r_valid_i & (tcdm_r_data_i[31:28]==EOP);
    spike_evt         = tcdm_r_valid_i & (tcdm_r_data_i[31:28]==EVT_SPIKE) & (cfg_fc_mode_i);
  end 
end 

always_comb begin 
  if(cfg_context_switch_mode_i) begin 
    if((time_evt|end_operation_evt) & (context_state_q !=cfg_context_switch_count_i) & (~weight_fetch_fc_q)) begin
      context_mode_valid = 1'b0; 
    end else begin
      context_mode_valid = 1'b1;
    end
  end else begin 
    context_mode_valid = 1'b1;
  end
end

// assign config_o.hw2reg.sta_main_status_o[STREAMER_ID] = sta_main_status_o;
// assign end_operation_evt = tcdm_r_valid_i & (tcdm_r_data_i[31:28]==EOP);
assign end_context_switch= cfg_context_switch_mode_i & end_operation_evt & (context_state_q==cfg_context_switch_count_i) & (~weight_fetch_fc_q); 
assign end_fc            = cfg_fc_mode_i             & end_operation_evt & (~weight_fetch_fc_q) & (~cfg_context_switch_mode_i);

always_comb begin
  if(evt_stream_dst.valid & (evt_stream_dst.evt==cfg_out_stream_i) & (streamer_op_s==1'b0) & cfg_store_check) begin 
    store_end_d = 1'b1;
  end else begin 
    store_end_d = 1'b0;
  end
end 

always_ff @(posedge system_clk_i or negedge system_rst_ni) begin : proc_transaction_end
  if(~system_rst_ni) begin
    store_end_q <= 0;
  end else begin
    store_end_q <= store_end_d;
  end
end

endmodule : evt_streamer_ctrl