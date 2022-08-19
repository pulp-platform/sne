/* 
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
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
module evt_status_memory 
	import sne_evt_stream_pkg::*;
	import sne_pkg::*;
	#(

	parameter NEURONS_ADDR_WIDTH = 12,
	parameter STATE_DATA_WIDTH   = 16,
	parameter NEURON_GROUP       = 16 ,
	parameter SRAM_STATUS        = 1 

	)(

	input  logic                                    clk_i               ,
	input  logic                                    rst_ni              ,


	input  logic                                    power_gate          ,
	input  logic                                    power_sleep         ,
	
	input  logic                                    test_en_i           , 
	input  logic [NEURON_GROUP-1:0]                 group_clk_en_i      ,

	MEMORY_PORT.read_dst 							state_read[NEURON_GROUP-1:0],
	MEMORY_PORT.write_dst 							state_write[NEURON_GROUP-1:0] 		
	
);
	typedef logic [STATE_DATA_WIDTH-1:0] state_t;

	state_t [NEURON_GROUP-1:0]   state_ReadData_odd_s;
	state_t [NEURON_GROUP-1:0]   state_ReadData_even_s;

	state_t [NEURON_GROUP-1:0]  state_WriteData_s;

	logic [NEURON_GROUP-1:0] 						 state_ReadData_output_select;

	logic [NEURON_GROUP-1:0]                         state_even_ReadEnable_q ;
	logic [NEURON_GROUP-1:0]                         state_odd_ReadEnable_q  ;

	logic [NEURON_GROUP-1:0]                  		 group_clk_s;


	logic [NEURON_GROUP-1:0]                         state_odd_ReadEnable_s  ;
	
	logic [NEURON_GROUP-1:0][NEURONS_ADDR_WIDTH-2:0] state_odd_ReadAddr_s    ;
	state_t [NEURON_GROUP-1:0]   state_odd_ReadData_s    ;  

	logic [NEURON_GROUP-1:0]                         state_even_ReadEnable_s ;
	
	logic [NEURON_GROUP-1:0][NEURONS_ADDR_WIDTH-2:0] state_even_ReadAddr_s   ;
	state_t [NEURON_GROUP-1:0]   state_even_ReadData_s   ;                                     
	// Write port
	logic [NEURON_GROUP-1:0]                         state_odd_WriteEnable_s ;
	logic [NEURON_GROUP-1:0][NEURONS_ADDR_WIDTH-2:0] state_odd_WriteAddr_s   ;
	state_t [NEURON_GROUP-1:0]   state_odd_WriteData_s   ;

	logic [NEURON_GROUP-1:0]                         state_even_WriteEnable_s;
	logic [NEURON_GROUP-1:0][NEURONS_ADDR_WIDTH-2:0] state_even_WriteAddr_s  ;
	state_t [NEURON_GROUP-1:0]  state_even_WriteData_s  ; 

	logic [NEURON_GROUP-1:0][NEURONS_ADDR_WIDTH-2:0] state_Readaddr_shifted_s;

	

	generate
		genvar j;
		for(j=0; j<NEURON_GROUP;j++)begin 
			always_ff @(posedge clk_i or negedge rst_ni) begin : proc_align_state_write
				if(~rst_ni) begin
					// for (int i = 0; i < NEURON_GROUP; i++) begin
					state_ReadData_output_select[j] <= 0;
					state_odd_ReadEnable_q[j]		<= 0;
					state_even_ReadEnable_q[j]		<= 0;
					// end
				end else begin
					// for (int i = 0; i < NEURON_GROUP; i++) begin
					state_ReadData_output_select[j] <= state_read[j].addr[0];
					state_odd_ReadEnable_q[j]		<= state_odd_ReadEnable_s[j];
					state_even_ReadEnable_q[j]		<= state_even_ReadEnable_s[j];
				// end
				end
			end

			always_comb begin
					state_odd_ReadEnable_s[j]   = state_read[j].enable && state_read[j].addr[0] && (~(state_write[j].enable && state_write[j].addr[0]));
					state_odd_ReadAddr_s[j]     = state_read[j].addr[NEURONS_ADDR_WIDTH-1:1];
					// state_odd_ReadData_s[i]     = state_ReadData_odd_s[i];
					state_even_ReadEnable_s[j]  = state_read[j].enable && ~state_read[j].addr[0] && (~(state_write[j].enable && ~state_write[j].addr[0]));
					state_even_ReadAddr_s[j]    = state_read[j].addr[NEURONS_ADDR_WIDTH-1:1];
					// state_even_ReadData_s[i]    = state_ReadData_even_s[i];
					state_odd_WriteEnable_s[j]  = state_write[j].enable && state_write[j].addr[0];
					state_odd_WriteAddr_s[j]    = state_write[j].addr[NEURONS_ADDR_WIDTH-1:1];
					state_odd_WriteData_s[j]    = state_write[j].data;
					state_even_WriteEnable_s[j] = state_write[j].enable && ~state_write[j].addr[0];
					state_even_WriteAddr_s[j]   = state_write[j].addr[NEURONS_ADDR_WIDTH-1:1];
					state_even_WriteData_s[j]   = state_write[j].data;
			end
		end
	endgenerate

	generate
		genvar i;
		// genvar j;

		for (i = 0; i < NEURON_GROUP; i++) begin: state_mem

			tc_clk_gating i_status_clock_gating (
				.clk_i                    ( clk_i        		         ), 
				.en_i                     ( group_clk_en_i[i]            ), 
				.test_en_i                ( test_en_i                    ), 
				.clk_o                    ( group_clk_s[i]               )
			);
			

			if(SRAM_STATUS) begin

				//--- neuron status memory
				evt_sram_wrap #(
					.NUM_WORDS (2**(NEURONS_ADDR_WIDTH-1)), 
					.DATA_WIDTH(STATE_DATA_WIDTH)

					) i_state_sram_o (

					.clk_i        ( group_clk_s[i]           ),

					.power_gate ( power_gate                 ),
					.power_sleep( power_sleep                ),
				           
					.ReadEnable ( state_odd_ReadEnable_s[i]  ),
					.ReadAddr   ( state_odd_ReadAddr_s[i]    ),
					.ReadData   ( state_ReadData_odd_s[i]    ),	 

					.WriteEnable( state_odd_WriteEnable_s[i] ),
					.WriteAddr  ( state_odd_WriteAddr_s[i]   ),                	    
					.WriteData  ( state_odd_WriteData_s[i]   )
				);

				evt_sram_wrap #(
					.NUM_WORDS (2**(NEURONS_ADDR_WIDTH-1)), 
					.DATA_WIDTH(STATE_DATA_WIDTH)

					) i_state_sram_e (

					.clk_i        ( group_clk_s[i]           ),

					.power_gate ( power_gate                 ),
					.power_sleep( power_sleep                ),
				           
					.ReadEnable ( state_even_ReadEnable_s[i] ),
					.ReadAddr   ( state_even_ReadAddr_s[i]   ),
					.ReadData   ( state_ReadData_even_s[i]   ),	 

					.WriteEnable( state_even_WriteEnable_s[i]),
					.WriteAddr  ( state_even_WriteAddr_s[i]  ),
					.WriteData  ( state_even_WriteData_s[i]  )
				);

			end else begin

				//--- neuron status memory
				register_file_1r_1w #(
					.ADDR_WIDTH(NEURONS_ADDR_WIDTH-1), 
					.DATA_WIDTH(STATE_DATA_WIDTH)

					) i_state_scm_o (

					.clk        ( group_clk_s[i]             ),
				           
					.ReadEnable ( state_odd_ReadEnable_s[i]  ),
					.ReadAddr   ( state_odd_ReadAddr_s[i]    ),
					.ReadData   ( state_ReadData_odd_s[i]    ),	 

					.WriteEnable( state_odd_WriteEnable_s[i] ),
					.WriteAddr  ( state_odd_WriteAddr_s[i]   ),                	    
					.WriteData  ( state_odd_WriteData_s[i]   )
				);

				register_file_1r_1w #(
					.ADDR_WIDTH(NEURONS_ADDR_WIDTH-1), 
					.DATA_WIDTH(STATE_DATA_WIDTH)

					) i_state_scm_e (

					.clk        ( group_clk_s[i]             ),
				           
					.ReadEnable ( state_even_ReadEnable_s[i] ),
					.ReadAddr   ( state_even_ReadAddr_s[i]   ),
					.ReadData   ( state_ReadData_even_s[i]   ),	 

					.WriteEnable( state_even_WriteEnable_s[i]),
					.WriteAddr  ( state_even_WriteAddr_s[i]  ),
					.WriteData  ( state_even_WriteData_s[i]  )
				);
			end
			
			assign state_read[i].data = state_ReadData_output_select[i] ? state_ReadData_odd_s[i] : state_ReadData_even_s[i];

			end: state_mem

	endgenerate


endmodule