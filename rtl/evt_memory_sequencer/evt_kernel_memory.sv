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
module onehot(

	input logic [1:0] select_i,
	output logic [3:0] select_o
);
	always_comb begin
		case(select_i) 
			2'b00 : select_o = 4'b0001;
			2'b01 : select_o = 4'b0010;
			2'b10 : select_o = 4'b0100;
			2'b11 : select_o = 4'b1000;
		endcase 
	end
endmodule

module evt_kernel_memory
	#(

    parameter CHANNEL_NUMBER     = 64,
    parameter DATA_WIDTH		 = 32,
    parameter SRAM_STATUS        = 1,
    localparam ADDR_WIDTH    	 = $clog2(CHANNEL_NUMBER)+2,
    parameter NEURON_GROUP       = 16         

    )( 	
    input logic                                 clk_i               , // Clock
    input logic                                 rst_ni              , // Asynchronous reset active low

    input logic [1:0]	                        mode_i              ,
    input logic [1:0]	                        sel_i               ,

    MEMORY_PORT.read_dst                        weights_read        ,
    MEMORY_PORT.write_dst                       weights_write       

);
	
	logic 	[4:0] 				WriteEnable ;
	logic 	[4:0][	7:0		] 	WriteAddr 	;
	logic 	[4:0][	31:0	] 	WriteData 	; 

	logic 	[4:0] 				ReadEnable 	;
	logic 	[4:0][	7:0		] 	ReadAddr 	;
	logic 	[4:0][	31:0	] 	ReadData 	; 

	logic   [3:0]               ReadEnable_onehot 	;
	logic   [3:0]               WriteEnable_onehot 	;

	logic   [3:0][	3:0		]	Weight_buffer_0		;
	logic   [3:0][	35:0	]	Weight_buffer_9		;

	logic	[NEURON_GROUP*36-1:0			]	floating_kernel 	;

	logic [2:0] select_q;
	logic [1:0] config_sel_q;


	onehot i_write_onehot(
		.select_i(	WriteAddr[0][1:0]	),
		.select_o(	WriteEnable_onehot  )
		);
	
	onehot i_read_onehot(
		.select_i(	ReadAddr[0][1:0]   	),
		.select_o(	ReadEnable_onehot   )
		);

	always_comb begin 
		if( weights_write.enable ) begin
			if(	mode_i 	== 	2'b01 ) begin 
				WriteEnable[0] 	= 	1'b0   				;
				ReadEnable  	= 	5'b00000         	;
				WriteEnable[3:0]=	WriteEnable_onehot  ;
			end else if( mode_i == 2'b10 ) begin 
				WriteEnable = 5'b10000		;
				ReadEnable  = 5'b00000		;
			end
		end else begin 
			WriteEnable = 5'b00000;
			ReadEnable  = 5'b11111;
		end
	end

	generate
		genvar i;
		
		for (i = 0; i < 5; i++) begin: weight_mem
			
			assign WriteAddr[i] = 	weights_write.addr; 
			assign WriteData[i] = 	weights_write.data; 
			assign ReadAddr[i] 	= 	weights_read.addr; 
			
			if ( i< 4 ) begin
				if(SRAM_STATUS) begin

					//--- neuron status memory
					evt_sram_wrap #(
						.NUM_WORDS 	(CHANNEL_NUMBER  ), 
						.DATA_WIDTH ( DATA_WIDTH )

						) i_weight_sram_o (

						.clk_i      ( clk_i			 ),
					           
						.ReadEnable ( ReadEnable[i]  ),
						.ReadAddr   ( ReadAddr[i][ADDR_WIDTH-1:2]),
						.ReadData   ( ReadData[i]    ),	 

						.WriteEnable( WriteEnable[i] ),
						.WriteAddr  ( WriteAddr[i][ADDR_WIDTH-1:2]),                	    
						.WriteData  ( WriteData[i]   )
					);

				end else begin

					//--- neuron status memory
					register_file_1r_1w #(
						.NUM_WORDS 	(CHANNEL_NUMBER  ), 
						.DATA_WIDTH ( DATA_WIDTH )

						) i_weight_scm_o (

						.clk_i      ( clk_i			 ),
					           
						.ReadEnable ( ReadEnable[i]  ),
						.ReadAddr   ( ReadAddr[i][ADDR_WIDTH-1:2]),
						.ReadData   ( ReadData[i]    ),	 

						.WriteEnable( WriteEnable[i] ),
						.WriteAddr  ( WriteAddr[i][ADDR_WIDTH-1:2]),                	    
						.WriteData  ( WriteData[i]   )
					);
				end
			end else begin
				if(SRAM_STATUS) begin

					//--- neuron status memory
					evt_sram_wrap #(
						.NUM_WORDS 	(CHANNEL_NUMBER/2), 
						.DATA_WIDTH (DATA_WIDTH )

						) i_weight_sram_o (

						.clk_i      ( clk_i			 ),
					           
						.ReadEnable ( ReadEnable[i]  ),
						.ReadAddr   ( ReadAddr[i][ADDR_WIDTH-1:3]),
						.ReadData   ( ReadData[i]    ),	 

						.WriteEnable( WriteEnable[i] ),
						.WriteAddr  ( WriteAddr[i][ADDR_WIDTH-4:0]),                	    
						.WriteData  ( WriteData[i]   )
					);

				end else begin

					//--- neuron status memory
					register_file_1r_1w #(
						.NUM_WORDS 	(CHANNEL_NUMBER/2), 
						.DATA_WIDTH (DATA_WIDTH 	)

						) i_weight_scm_o (

						.clk_i      ( clk_i			 ),
					           
						.ReadEnable ( ReadEnable[i]  ),
						.ReadAddr   ( ReadAddr[i][ADDR_WIDTH-1:3]),
						.ReadData   ( ReadData[i]    ),	 

						.WriteEnable( WriteEnable[i] ),
						.WriteAddr  ( WriteAddr[i][ADDR_WIDTH-3:0]),                	    
						.WriteData  ( WriteData[i]   )
					);
				end
			end 
			
		end: weight_mem

	endgenerate

	always_comb begin
		if(select_q[2]) begin 
			Weight_buffer_0[0] = ReadData[4][15:12];
			Weight_buffer_0[1] = ReadData[4][11:8];
			Weight_buffer_0[2] = ReadData[4][7:4];
			Weight_buffer_0[3] = ReadData[4][3:0];
		end else begin 
			Weight_buffer_0[0] = ReadData[4][31:28];
			Weight_buffer_0[1] = ReadData[4][27:24];
			Weight_buffer_0[2] = ReadData[4][23:20];
			Weight_buffer_0[3] = ReadData[4][19:16];
		end
		Weight_buffer_9[0] = {ReadData[0],Weight_buffer_0[0]};
		Weight_buffer_9[1] = {ReadData[1],Weight_buffer_0[1]};
		Weight_buffer_9[2] = {ReadData[2],Weight_buffer_0[2]};
		Weight_buffer_9[3] = {ReadData[3],Weight_buffer_0[3]};



		case (config_sel_q) 
			2'b01 : begin
						floating_kernel = {{(NEURON_GROUP/4){Weight_buffer_9[3]}},{(NEURON_GROUP/4){Weight_buffer_9[2]}},{(NEURON_GROUP/4){Weight_buffer_9[1]}},{(NEURON_GROUP/4){Weight_buffer_9[0]}}};
					end 
			2'b10 : begin
						floating_kernel = {{(NEURON_GROUP/2){Weight_buffer_9[2+select_q[0]]}},{(NEURON_GROUP/2){Weight_buffer_9[select_q[0]]}}}; 
					end
			2'b11 : begin
						floating_kernel = {(NEURON_GROUP/1){Weight_buffer_9[select_q[1:0]]}};
					end
			default : begin 
						floating_kernel = {(NEURON_GROUP/1){Weight_buffer_9[select_q[1:0]]}};
					end
		endcase
	end

	
	always_ff @(posedge clk_i or negedge rst_ni) begin : proc_weights_read_valid
		if(~rst_ni) begin
			select_q           <= 0;
			config_sel_q       <= 0;
		end else begin
			select_q           <= ReadAddr[4][2:0];
			config_sel_q       <= sel_i;
		end
	end
	assign weights_read.data 	= floating_kernel ;

endmodule 

