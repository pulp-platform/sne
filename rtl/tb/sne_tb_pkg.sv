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
package sne_tb_pkg;
	import sne_pkg::*;
	import engine_clock_reg_pkg::*;
	import bus_clock_reg_pkg::*;
	import system_clock_reg_pkg::*;
	`include "archi_sne.svh"

	`define  XBAR_MASTER_NODE(n)              n
	`define  UNCONNECTED                      `SLICE_NUMBER+`STREAM_NUMBER+`EXTERNAL_STREAM_NUMBER

	typedef struct {
		logic [31:0] paddr;
		logic [31:0] pwdata;
		logic        pwrite;
		logic        psel;
		logic        penable;
		logic [31:0] prdata;
		logic        pready;
		logic        pslverr;
	} APB_BUS_t;

	typedef struct {

		logic [7:0][31:0] master;

	} XBAR_CFG_t;

	task automatic APB_WRITE(
		
		input logic [31:0] addr, 
		input logic [31:0] data, 
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);
		
		APB_BUS.penable  = '0;
		APB_BUS.pwdata   = '0;
		APB_BUS.paddr    = '0;
		APB_BUS.pwrite   = '0;
		APB_BUS.psel     = '0;
		@(posedge clk_i);
		APB_BUS.penable  = 1'b0;
		APB_BUS.pwdata   = data;
		APB_BUS.paddr    = addr;
		APB_BUS.pwrite   = 1'b1;
		APB_BUS.psel     = 1'b1;
		@(posedge clk_i);
		APB_BUS.penable  = 1'b1;
		wait(APB_BUS.pready);
		@(posedge clk_i);
		APB_BUS.paddr = 0;
		APB_BUS.pwdata = 0;
		APB_BUS.pwrite = 0;
		APB_BUS.psel = 0;
		APB_BUS.penable = 0;
		`ifdef PRINT
			$display("---------[t=%0t] [APB-WRITE: 0b%32b (0x%8h) @addr 0x%5h] ---------",$time,data,data,addr);
		`endif
	endtask : APB_WRITE

	task automatic APB_READ(
		
		input  logic [31:0] addr, 
		output logic [31:0] data, 
		ref    logic        clk_i, 
		ref    APB_BUS_t    APB_BUS);
		
		APB_BUS.penable  = '0;
		APB_BUS.pwdata   = '0;
		APB_BUS.paddr    = '0;
		APB_BUS.pwrite   = '0;
		APB_BUS.psel     = '0;
		@(posedge clk_i);
		APB_BUS.penable  = 1'b0;
		APB_BUS.pwdata   = '0;
		APB_BUS.paddr    = addr;
		APB_BUS.pwrite   = 1'b0;
		APB_BUS.psel     = 1'b0;
		@(posedge clk_i);
		APB_BUS.psel     = 1'b1;
		@(posedge clk_i);
		APB_BUS.penable  = 1'b1;
		@(posedge clk_i);
		wait(APB_BUS.pready);
		@(posedge clk_i);
		data = APB_BUS.prdata;
		@(posedge clk_i);
		APB_BUS.paddr = 0;
		APB_BUS.pwdata = 0;
		APB_BUS.pwrite = 0;
		APB_BUS.psel = 0;
		APB_BUS.penable = 0;
		//@(posedge clk_i);
		`ifdef PRINT
			$display("---------[t=%0t] [APB-READ: 0b%32b (0x%8h) @addr 0x%5h] ---------",$time,data,data,addr);
		`endif
	endtask : APB_READ

	task automatic hal_sne_xbar_load_slice(

		input int          slice,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

	for (int i = 0; i < `XBAR_SLAVES; i++) begin
		APB_WRITE(`XBAR_SLAVE_NODE(i), `XBAR_MASTER_NODE(`UNCONNECTED),clk_i,APB_BUS );
	end

	APB_WRITE(`XBAR_SLAVE_NODE(slice*3+1), `XBAR_MASTER_NODE(`SLICE_NUMBER),clk_i,APB_BUS );
	APB_WRITE(`XBAR_SLAVE_NODE(slice*3+2), `XBAR_MASTER_NODE(`SLICE_NUMBER+1),clk_i,APB_BUS );

	$display("--------- [XBAR: SLICE %0d] ---------",slice);

	endtask : hal_sne_xbar_load_slice

	task automatic hal_sne_init_streamer(

		input int          slice,
		input int          streamer,
		input int          l2saddr , 
		input int          l2step  , 
		input int          l0saddr , 
		input int          l0step  , 
		input int          transize, 
		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;
		logic [31:0] seq_reg_val;

		APB_WRITE(SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET+(streamer)*4      ,0     ,clk_i,APB_BUS);      
		APB_WRITE(SYSTEM_CLOCK_CFG_TCDM_START_ADDR_I_0_OFFSET+(streamer)*4,l2saddr     ,clk_i,APB_BUS);
		APB_WRITE(SYSTEM_CLOCK_CFG_TCDM_ADDR_STEP_I_0_OFFSET+(streamer)*4 ,l2step      ,clk_i,APB_BUS); 
		APB_WRITE(SYSTEM_CLOCK_CFG_TCDM_END_ADDR_I_0_OFFSET+(streamer)*4  ,32'h00000000,clk_i,APB_BUS);  
		APB_WRITE(SYSTEM_CLOCK_CFG_TCDM_TRAN_SIZE_I_0_OFFSET+(streamer)*4 ,transize    ,clk_i,APB_BUS); 
		APB_WRITE(SYSTEM_CLOCK_CFG_SRAM_START_ADDR_I_0_OFFSET+(streamer)*4,l0saddr     ,clk_i,APB_BUS);
		APB_WRITE(SYSTEM_CLOCK_CFG_SRAM_ADDR_STEP_I_0_OFFSET+(streamer)*4 ,l0step      ,clk_i,APB_BUS); 
		APB_WRITE(SYSTEM_CLOCK_CFG_SRAM_END_ADDR_I_0_OFFSET+(streamer)*4  ,32'h00000000,clk_i,APB_BUS); 

		// $display("--------- [STREAMER_INIT: MODE %0d] ---------",mode);
	
	endtask : hal_sne_init_streamer

	task automatic hal_sne_arbitrate_streamer(
		input int          streamer,
		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;

		APB_READ(`STR_OUT_STREAM_CFG(streamer),reg_val,clk_i,APB_BUS);
		reg_val = reg_val | (1'b1 << 4);
		APB_WRITE(`STR_OUT_STREAM_CFG(streamer),reg_val,clk_i,APB_BUS);    
		$display("--------- [STREAMER_OUT: ARBITRATE] ---------");

	endtask : hal_sne_arbitrate_streamer

	task automatic hal_sne_trigger_streamer(
		input int          streamer,
		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;

		APB_READ(`STR_MAIN_CTRL_CFG(streamer),reg_val,clk_i,APB_BUS);
		reg_val = reg_val & ~(1'b1 << 1);
		APB_WRITE(`STR_MAIN_CTRL_CFG(streamer),reg_val,clk_i,APB_BUS);    
		reg_val = reg_val | (1'b1 << 1);
		APB_WRITE(`STR_MAIN_CTRL_CFG(streamer),reg_val,clk_i,APB_BUS);  
		$display("--------- [STREAMER_TRIGGER: TRIGGER] ---------");
	
	endtask : hal_sne_trigger_streamer

	task automatic hal_sne_trigger_streamer_external(
		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;
		APB_READ(`UDMA_GATEWAY_MAIN_CFG,reg_val,clk_i,APB_BUS);
		reg_val = reg_val | (1'b1 << 15);
		APB_WRITE(`UDMA_GATEWAY_MAIN_CFG,reg_val,clk_i,APB_BUS);    
		$display("--------- [EXTERNAL_STREAMER_TRIGGER: TRIGGER] ---------");
	
	endtask : hal_sne_trigger_streamer_external

	task automatic hal_sne_init_sequencer(
		input int          slice,
		input int          saddr    ,
		input int          eaddr    ,
		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

	    logic [31:0] seq_reg_val;

		// APB_READ(`SEQ_MODE_CFG(slice),seq_reg_val,clk_i,APB_BUS);
		// seq_reg_val = seq_reg_val & ~(1'b1 << 5); //disable weights load on the sequencer
		// seq_reg_val = seq_reg_val & ~(1'b1 << 4); //make sure trigger is not enabled
		// seq_reg_val = seq_reg_val |  (1'b1 << 0); //put it in `ENABLE mode
		// APB_WRITE(`SEQ_MODE_CFG(slice),seq_reg_val,clk_i,APB_BUS);

		// APB_WRITE(`SEQ_INIT_ADDR_CFG(slice) ,saddr       ,clk_i,APB_BUS );  
		APB_WRITE(ENGINE_CLOCK_CFG_ADDR_STEP_I_0_OFFSET+slice*4 ,32'h00000001,clk_i,APB_BUS );  
		APB_WRITE(ENGINE_CLOCK_CFG_ADDR_START_I_0_OFFSET+slice*4,saddr       ,clk_i,APB_BUS ); 
		APB_WRITE(ENGINE_CLOCK_CFG_ADDR_END_I_0_OFFSET+4*slice,eaddr       ,clk_i,APB_BUS );   
		// APB_WRITE(`SEQ_MODE_CFG(slice)      ,32'h00000007,clk_i,APB_BUS ); 
	
	endtask : hal_sne_init_sequencer

	task automatic hal_sne_enable_loopback(
		input int          slice,
		input int          th_addr    ,
		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

	    logic [31:0] seq_reg_val;

		APB_READ(`SEQ_MAIN_CFG(slice),seq_reg_val,clk_i,APB_BUS);
		seq_reg_val = seq_reg_val | (1'b1 << 15); //enable loopback in the router
		seq_reg_val = seq_reg_val | (th_addr[15:0] << 16); //enable loopback in the router
		APB_WRITE(`SEQ_MAIN_CFG(slice),seq_reg_val,clk_i,APB_BUS);
	
	endtask : hal_sne_enable_loopback

	task automatic hal_sne_xbar_simulate_external(
		input int          slice,
 		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		for (int i = 0; i < `XBAR_SLAVES; i++) begin
			APB_WRITE(`XBAR_SLAVE_NODE(i), `XBAR_MASTER_NODE(`UNCONNECTED),clk_i,APB_BUS );
		end

		APB_WRITE(`XBAR_SLAVE_NODE(slice*3),`XBAR_MASTER_NODE(`SLICE_NUMBER + `STREAM_NUMBER),clk_i,APB_BUS  ); //---- attach to the external streamer 
		APB_WRITE(`XBAR_SLAVE_NODE(`SLICE_NUMBER*3+`STREAM_NUMBER-1), `XBAR_MASTER_NODE(slice),clk_i,APB_BUS );

	endtask : hal_sne_xbar_simulate_external

	task automatic hal_sne_xbar_simulate(
		input int          slice,
 		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		for (int i = 0; i < `XBAR_SLAVES; i++) begin
			APB_WRITE(`XBAR_SLAVE_NODE(i), `XBAR_MASTER_NODE(`UNCONNECTED),clk_i,APB_BUS );
		end

		APB_WRITE(`XBAR_SLAVE_NODE(slice*3),`XBAR_MASTER_NODE(`SLICE_NUMBER),clk_i,APB_BUS );
		APB_WRITE(`XBAR_SLAVE_NODE(`SLICE_NUMBER*3+`STREAM_NUMBER-1), `XBAR_MASTER_NODE(slice),clk_i,APB_BUS );

	endtask : hal_sne_xbar_simulate

	task automatic hal_sne_xbar_broadcast(
 		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		for (int i = 0; i < `XBAR_SLAVES; i++) begin
			APB_WRITE(`XBAR_SLAVE_NODE(i), `XBAR_MASTER_NODE(`UNCONNECTED),clk_i,APB_BUS );
		end
		for (int i = 0; i < `SLICE_NUMBER; i++) begin
			APB_WRITE(`XBAR_SLAVE_NODE(i*3),`XBAR_MASTER_NODE(`SLICE_NUMBER),clk_i,APB_BUS );
		end
	endtask : hal_sne_xbar_broadcast

	task automatic hal_sne_oracle_set_observer(
		input int          observer,
		input int          address,
 		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		APB_WRITE(`ORACLE_OBS_ADDR_CFG(observer),address,clk_i,APB_BUS );
	endtask : hal_sne_oracle_set_observer

	task automatic hal_sne_oracle_run_prediction(
 		ref   logic        clk_i   , 
		ref   APB_BUS_t    APB_BUS);

		APB_WRITE(`ORACLE_OBS_MAIN_CFG,32'h00000001,clk_i,APB_BUS );
		APB_WRITE(`ORACLE_OBS_MAIN_CFG,32'h00000000,clk_i,APB_BUS );
	endtask : hal_sne_oracle_run_prediction

	task automatic hal_sne_set_filter(
		input int          slice,
		input int          group,
		input int          left,
		input int          right,
		input int          filter,
		input int          bottom,
		input int          top,
		input int          xoffset,
		input int          yoffset,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

	    logic [31:0] reg_val;
	    logic [31:0] lbound;
	    logic [31:0] ubound;
	    logic [31:0] offsets;

	    int address_offset ;

	    lbound = (left) | (bottom<<16);
	    ubound = (right) | (top<<16);

	    offsets = (xoffset << 1) | (yoffset << 4) | (filter);
	    address_offset = 4*(slice*(CLUSTERS)+group);

	    APB_WRITE(ENGINE_CLOCK_CFG_FILTER_MAIN_I_0_OFFSET+address_offset, offsets, clk_i, APB_BUS);
		APB_WRITE(ENGINE_CLOCK_CFG_FILTER_LBOUND_I_0_OFFSET+address_offset, lbound, clk_i, APB_BUS);
		APB_WRITE(ENGINE_CLOCK_CFG_FILTER_UBOUND_I_0_OFFSET+address_offset, ubound, clk_i, APB_BUS);
	
	endtask : hal_sne_set_filter

	task automatic hal_sne_reset_neurons(
		input int          slice,
		input int          group,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;

		reg_val = 0;
		reg_val = reg_val | (1'b1 << 0);
		reg_val = reg_val | (1'b1 << 4);
		reg_val = reg_val | (1'b1 << 5);

		APB_WRITE(`NG_FILTER_MAIN_CFG(slice,group), reg_val, clk_i, APB_BUS);

		reg_val = 0;
		reg_val = reg_val | (1'b1 << 0); 
		APB_WRITE(`LIF_MAIN_CFG(slice),reg_val,clk_i, APB_BUS);
	
	endtask : hal_sne_reset_neurons

	task automatic hal_sne_start_sequencers_single(
		input int          slice,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

	logic [31:0] seq_reg_val;
	seq_reg_val = 0;
	seq_reg_val = seq_reg_val | (4'b1010 << 0); //put it in `SEQ mode
	APB_WRITE(`SEQ_MODE_CFG(slice),seq_reg_val,clk_i,APB_BUS);  

	endtask : hal_sne_start_sequencers_single

	task automatic hal_sne_start_sequencers(
		input int          slice,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

	logic [31:0] seq_reg_val;
	seq_reg_val = 0;
	seq_reg_val = seq_reg_val | (2'b11 << 0); //put it in `SEQ mode
	APB_WRITE(`SEQ_MODE_CFG(slice),seq_reg_val,clk_i,APB_BUS);  

	endtask : hal_sne_start_sequencers

	task automatic hal_sne_stop_sequencers(
		input int          slice,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

	logic [31:0] seq_reg_val;
	seq_reg_val = 0;
	seq_reg_val = seq_reg_val & ~(2'b11 << 0); //put it in `SEQ mode
	APB_WRITE(`SEQ_MODE_CFG(slice),seq_reg_val,clk_i,APB_BUS);  

	endtask : hal_sne_stop_sequencers

	task automatic hal_sne_release_neurons(
		input int 		   integrate,
		input int          slice,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;
		reg_val = 0;
		reg_val = reg_val | (integrate << 1); 
		reg_val = reg_val & ~(1'b1 << 0); 
		APB_WRITE(`LIF_MAIN_CFG(slice),reg_val,clk_i,APB_BUS);  
	
	endtask : hal_sne_release_neurons

	task automatic hal_sne_apply_thresholds(
		input int          slice,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);

		logic [31:0] reg_val;
		APB_READ(`LIF_MAIN_CFG(slice),reg_val,clk_i,APB_BUS);
		reg_val = reg_val & ~(1'b1 << 1); 
		APB_WRITE(`LIF_MAIN_CFG(slice),reg_val,clk_i,APB_BUS);  
	
	endtask : hal_sne_apply_thresholds

	task automatic hal_sne_cg_slice(
		input int          slice,
		input int          cge,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);
		logic [31:0] reg_val;
		APB_READ(`GPM_SLICE_CKG,reg_val,clk_i,APB_BUS);
		if(cge == 1) begin
			reg_val = reg_val | (1'b1 << slice); 
		end else begin
			reg_val = reg_val & ~(1'b1 << slice); 
		end
		APB_WRITE(`GPM_SLICE_CKG,reg_val,clk_i,APB_BUS);  

		$display("--------- [CG: SLICE %0d, @%0x] ---------",slice,`GPM_SLICE_CKG);
	endtask : hal_sne_cg_slice

	task automatic hal_sne_cg_arbiter(
		input int          cge,
		ref   logic        clk_i, 
		ref   APB_BUS_t    APB_BUS);
		logic [31:0] reg_val;
		APB_READ(`GPM_MAIN_CKG,reg_val,clk_i,APB_BUS);
		if(cge == 1) begin
			reg_val = reg_val | (1'b1 << 0); 
		end else begin
			reg_val = reg_val & ~(1'b1 << 0); 
		end
		APB_WRITE(`GPM_MAIN_CKG,reg_val,clk_i,APB_BUS);  
	endtask : hal_sne_cg_arbiter

endpackage

