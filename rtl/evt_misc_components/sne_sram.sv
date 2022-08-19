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

`ifdef TARGET_TEST

  module sne_sram #(

    parameter DATA_WIDTH = 8,
    parameter NUM_WORDS  = 32,
    localparam ADDR_WIDTH = $clog2(NUM_WORDS)


    )(

     input  logic                          clk_i,
     input  logic                     power_gate,
     input  logic                    power_sleep,
     input  logic                          req_i,
     input  logic                          we_i,
     input  logic [ADDR_WIDTH-1:0]         addr_i,
     input  logic [DATA_WIDTH-1:0]         wdata_i,
     input  logic [DATA_WIDTH-1:0]         be_i,
     output logic [DATA_WIDTH-1:0]         rdata_o

  );


    logic [DATA_WIDTH-1:0] ram [NUM_WORDS-1:0];
    logic [ADDR_WIDTH-1:0] raddr_q;

    // 1. randomize array
    // 2. randomize output when no request is active
    always_ff @(posedge clk_i) begin
        if (req_i) begin
            if (!we_i)
                raddr_q <= addr_i;
            else
            for (int i = 0; i < DATA_WIDTH; i++)
                if (be_i[i]) ram[addr_i][i] <= wdata_i[i];
        end
    end

    assign rdata_o = ram[raddr_q];

`else

    

`endif    
endmodule

