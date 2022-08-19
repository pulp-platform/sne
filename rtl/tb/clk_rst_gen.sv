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
module rst_gen #(
    parameter integer RST_CLK_CYCLES
) (
    input  logic clk_i,     // Reference clock
    input  logic rst_ni,    // External active-low reset
    output logic rst_o,     // Active-high reset output
    output logic rst_no     // Active-low reset output
);

    // Define signals.
    logic [$clog2(RST_CLK_CYCLES+1)-1:0]    cnt_d,          cnt_q;
    logic                                   rst_d,          rst_q;

    // Increment counter until the configured number of clock cycles is reached.
    always_comb begin
        cnt_d = cnt_q;
        if (cnt_q < RST_CLK_CYCLES) begin
            cnt_d += 1;
        end
    end

    // Deassert reset after the configured number of clock cycles is reached.
    assign rst_d = (cnt_q >= RST_CLK_CYCLES) ? 1'b0 : 1'b1;

    // Drive reset outputs directly from register
    assign rst_o    = rst_q;
    assign rst_no   = ~rst_q;

    // Infer rising-edge-triggered synchronous-(re)set FFs for the counter and reset register.
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            cnt_q <= '0;
            rst_q <= 1'b1;
        end else begin
            cnt_q <= cnt_d;
            rst_q <= rst_d;
        end
    end

    // Define initial values for FFs on the FPGA.
    initial begin
        cnt_q = '0;
        rst_q = 1'b1;
    end

endmodule


module clk_rst_gen #(
    parameter time      CLK_PERIOD,
    parameter unsigned  RST_CLK_CYCLES
) (
    output logic clk_o,
    output logic rst_no
);

    timeunit 1ns;
    timeprecision 10ps;

    logic clk;

    // Clock Generation
    initial begin
        clk = 1'b0;
    end
    always begin
        #(CLK_PERIOD/2);
        clk = ~clk;
    end
    assign clk_o = clk;

    // Reset Generation
    rst_gen #(
        .RST_CLK_CYCLES (RST_CLK_CYCLES)
    ) i_rst_gen (
        .clk_i  (clk),
        .rst_ni (1'b1),
        .rst_o  (),
        .rst_no (rst_no)
    );

endmodule