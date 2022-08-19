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
`timescale 1ns / 1ps
module evt_opt_sequencer
    import sne_evt_stream_pkg::config_engine_t;

    #( 
    parameter STREAM_ADDR_WIDTH = 16,
    parameter KERNEL_SIZE = 3,
    parameter NEURON_GROUP = 16,
    parameter ENGINE_ID = 0,
    parameter DP_GROUP = 16,
    parameter SEQ_ADDR_WIDTH = 6)
    (
    input logic enable_i,
    input logic clk_i,
    input logic rst_ni,
    input logic init_i,
    input logic spike_evt_i, //
    input logic spike_grant_i,//
    input logic [STREAM_ADDR_WIDTH-1:0] spike_in_ID_i,//
    //Synch with time 
    input  logic   time_stable_i,
    output logic   init_sequencer_o,
    output logic done_o, //NC
    output logic ready_o,
    input   config_engine_t            config_i         ,
    output logic [3:0]                      count_o,
    output logic [NEURON_GROUP-1:0][SEQ_ADDR_WIDTH-1:0] wr_addr_group_o,
    output logic [NEURON_GROUP-1:0][SEQ_ADDR_WIDTH-1:0] rd_addr_group_o,
    output logic [NEURON_GROUP-1:0][SEQ_ADDR_WIDTH-1:0] wr_fifo_addr_o,
    output logic [NEURON_GROUP-1:0] wr_en_o,
    SNE_EVENT_STREAM.dst    evt_stream_time_dst
    );
    
    integer lower_s, upper_s;

    logic wr_en_d, wr_en_q, ready_d, ready_q;


    enum logic [1:0] {INIT,WAIT,RUN,STOP} state_d,state_q;
    
    assign ready_o  = ready_q;
    
    assign lower_s = -1;
    assign upper_s = 1;
    
    logic init_d, init_q, init;
    logic signed [STREAM_ADDR_WIDTH/2-1:0] rd_row_q,  rd_col_q;
    logic signed [STREAM_ADDR_WIDTH/2-1:0] wr_col_d, wr_col_q, wr_row_q, wr_row_d;
    always_ff@(posedge clk_i , negedge rst_ni) begin
        if(~rst_ni) begin
            wr_col_q <= -1;
            wr_row_q <= -1;
            wr_en_q  <= 0;
            state_q  <= INIT;
            // cnt_q    <= '0;
            ready_q  <= 0;
            // init_q   <= 0;
        end else begin
            wr_col_q <= wr_col_d;
            wr_row_q <= wr_row_d;
            wr_en_q  <= wr_en_d ;
            state_q  <= state_d;
            // cnt_q    <= cnt_d;
            ready_q  <= ready_d;
            // init_q   <= init_d;
        end
    end
    logic enable_row, enable_col;
    logic done_row , done_col;
    logic init_row, init_col;
    logic [1:0] count_row, count_col;
    evt_counter i_row_count(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .enable_i(enable_row),
        .init_i(init_row),
        .done_o(done_row),
        .count_o(count_row)
        );
    evt_counter i_col_count(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .enable_i(enable_col),
        .init_i(init_col),
        .done_o(done_col),
        .count_o(count_col)
        );
    // assign init_d = (~init_q) & init_i;
    always_comb begin 
        if(spike_grant_i) begin
            wr_row_d = rd_row_q;
            wr_col_d = rd_col_q; 
        end else begin 
            wr_row_d = wr_row_q;
            wr_col_d = wr_col_q;
        end
        state_d = state_q ; 
        evt_stream_time_dst.ready = 0;
        init_sequencer_o          = 0;
        case (state_q)
            INIT : begin
                if(init_i) begin
                    state_d = WAIT; 
                end else begin 
                    state_d = INIT;
                end 
                init    = 1;
                wr_en_d = 0;
                enable_col = 0;
                enable_row = 0;
                ready_d    = 0;
                evt_stream_time_dst.ready = 1;
                init_sequencer_o          = 1;
            end
            WAIT : begin
                if(time_stable_i) begin
                    state_d = RUN; 
                end else begin 
                    state_d = INIT;
                end 
                init    = 1;
                wr_en_d = 0;
                enable_col = 0;
                enable_row = 0;
                ready_d    = 0;
                evt_stream_time_dst.ready = 1;
                init_sequencer_o          = 1;
            end
            RUN : begin
                init = 0;
                if(spike_grant_i & (count_row==upper_s) & (count_col==upper_s)) begin 
                    state_d = STOP;
                end else begin
                    state_d = RUN;
                end 
                ready_d    = 0;
                wr_en_d    = spike_grant_i & spike_evt_i & enable_i & (~(done_row & done_col)); 
                enable_col = (enable_i & (spike_grant_i) & spike_evt_i) ;
                enable_row = (enable_i & (spike_grant_i) & spike_evt_i) & (count_col==upper_s) ;
            end
            STOP : begin 
                init = 0;
                if(ready_q & spike_grant_i) begin
                    state_d = INIT;
                    ready_d = 1'b0; 
                end else begin 
                    state_d = STOP;
                    ready_d = 1'b1; 
                end
                wr_en_d = 0;
                enable_col = 0;
                enable_row = 0;
            end 
        
            default : begin
                init = 0;
                ready_d = 1'b0; 
                wr_en_d = 0;
                enable_col = 0;
                enable_row = 0;
                state_d    = INIT;
            end
        endcase
        init_row   = init;
        init_col   = init;
    end
    
    assign rd_row_q  = $signed(count_row);
    assign rd_col_q  = $signed(count_col); 
    assign done_o    = done_row & done_col;


    logic [STREAM_ADDR_WIDTH/2-1:0] spike_row_s, spike_col_s;
    logic [NEURON_GROUP-1:0][STREAM_ADDR_WIDTH/2-1:0] wr_row_group_s, wr_col_group_s;
    logic [NEURON_GROUP-1:0][STREAM_ADDR_WIDTH/2-1:0] rd_row_group_s, rd_col_group_s;


    assign spike_row_s = spike_in_ID_i[STREAM_ADDR_WIDTH-1:STREAM_ADDR_WIDTH/2];
    assign spike_col_s = spike_in_ID_i[STREAM_ADDR_WIDTH/2-1:0];


    assign count_o = ($signed(count_row)+1)*3 + ($signed(count_col)+1) ;

generate
    genvar i;
    for(i=0; i<NEURON_GROUP; i++) begin
        assign wr_row_group_s[i] = spike_row_s + wr_row_q - config_i.reg2hw.cfg_filter_lbound_i[ENGINE_ID*DP_GROUP+i].yid;
        assign wr_col_group_s[i] = spike_col_s + wr_col_q - config_i.reg2hw.cfg_filter_lbound_i[ENGINE_ID*DP_GROUP+i].xid;

        assign wr_fifo_addr_o[i] = {wr_row_group_s[i][SEQ_ADDR_WIDTH/2-1:0] ,wr_col_group_s[i][SEQ_ADDR_WIDTH/2-1:0]} ;

        assign rd_row_group_s[i] = spike_row_s + rd_row_q - config_i.reg2hw.cfg_filter_lbound_i[ENGINE_ID*DP_GROUP+i].yid;
        assign rd_col_group_s[i] = spike_col_s + rd_col_q - config_i.reg2hw.cfg_filter_lbound_i[ENGINE_ID*DP_GROUP+i].xid;

        assign wr_addr_group_o[i] = {wr_row_group_s[i][SEQ_ADDR_WIDTH/2-1:0],wr_col_group_s[i][SEQ_ADDR_WIDTH/2-1:1],(wr_row_group_s[i][0] ^ wr_col_group_s[i][0])};

        assign rd_addr_group_o[i] = {rd_row_group_s[i][SEQ_ADDR_WIDTH/2-1:0],rd_col_group_s[i][SEQ_ADDR_WIDTH/2-1:1],((rd_row_group_s[i][0] ^ rd_col_group_s[i][0]))};

        assign wr_en_o[i]         = wr_en_q || (done_col & done_row);
    end
  
endgenerate 

endmodule
