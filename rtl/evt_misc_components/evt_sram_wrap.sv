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
module evt_sram_wrap
#(
    parameter DATA_WIDTH = 8,
    parameter NUM_WORDS  = 32,
    localparam ADDR_WIDTH = $clog2(NUM_WORDS)
)
(
    input  logic                                  clk_i,

    input logic               power_gate,
    input logic               power_sleep,
    // Read port
    input  logic                                  ReadEnable,
    input  logic [ADDR_WIDTH-1:0]                 ReadAddr,
    output logic [DATA_WIDTH-1:0]                 ReadData,


    // Write port
    input  logic                                  WriteEnable,
    input  logic [ADDR_WIDTH-1:0]                 WriteAddr,
    input  logic [DATA_WIDTH-1:0]                 WriteData
);

    logic req_i;
    logic we_i;
    logic [ADDR_WIDTH-1:0] addr_i;

assign req_i = ReadEnable || WriteEnable;
assign addr_i = WriteEnable ? WriteAddr : ReadAddr;

sne_sram #(

    .DATA_WIDTH( DATA_WIDTH ),
    .NUM_WORDS ( NUM_WORDS  )
    
    )i_sram (

    .clk_i  (clk_i              ),
    .power_gate(power_gate      ),
    .power_sleep(power_sleep    ),
    .req_i  (req_i              ),
    .we_i   (WriteEnable        ),
    .addr_i (addr_i             ),
    .wdata_i(WriteData          ),
    .be_i   ({DATA_WIDTH{1'b1}} ),
    .rdata_o(ReadData           )

);

endmodule : evt_sram_wrap