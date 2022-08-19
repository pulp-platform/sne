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

`ifndef _EVT_STREAM_MACROS
    `define _EVT_STREAM_MACROS

//--- this macro MUST be used every time two "SNE_EVENT_STREAM" interfaces need to be connected
`define SNE_EVENT_STREAM_ASSIGN_DST_SRC(lhs, rhs) \
    assign lhs.valid  = rhs.valid;                \
    assign lhs.evt    = rhs.evt;                  \
    assign rhs.ready  = lhs.ready;

`define SNE_EVENT_STREAM_PAUSE_DST_SRC(lhs, rhs, ready) \
    assign lhs.valid  = rhs.valid;                \
    assign lhs.evt    = rhs.evt;                  \
    assign rhs.ready  = lhs.ready && ready;

`define SNE_EVENT_STREAM_ABSORBE_DST_SRC(lhs, rhs) \
    assign lhs.valid  = 1'b0;                     \
    assign lhs.evt    = 0;                        \
    assign rhs.ready  = 1'b1;

`define SNE_EVENT_STREAM_ABSORBE_AND_PAUSE_DST_SRC(lhs, rhs,ready) \
    assign lhs.valid  = 1'b0;                     \
    assign lhs.evt    = 0;                        \
    assign rhs.ready  = 1'b1 && ready;

`define SNE_EVENT_STREAM_CHANGE_DATA_DST_SRC(lhs, rhs, evt) \
    assign lhs.valid  = rhs.valid;                     \
    assign lhs.evt    = evt;                        \
    assign rhs.ready  = lhs.ready;
`define SNE_EVENT_STREAM_CHANGE_DATA_SRC(lhs, evt) \
    assign lhs.valid  = 1;                     \
    assign lhs.evt    = evt;                        

// same defines, to be used in always 
`define C_SNE_EVENT_STREAM_ASSIGN_DST_SRC(lhs, rhs) \
    lhs.valid  = rhs.valid;                \
    lhs.evt    = rhs.evt;                  \
    rhs.ready  = lhs.ready;

`define C_SNE_EVENT_STREAM_PAUSE_DST_SRC(lhs, rhs) \
    lhs.valid  = 1'b0;                \
    lhs.evt    = rhs.evt;                  \
    rhs.ready  = 1'b0;

`define C_SNE_EVENT_STREAM_ABSORBE_DST_SRC(lhs, rhs) \
    lhs.valid  = 1'b0;                     \
    lhs.evt    = 0;                        \
    rhs.ready  = 1'b1;

`define C_SNE_EVENT_STREAM_ABSORBE_AND_PAUSE_DST_SRC(lhs, rhs) \
    lhs.valid  = 1'b0;                     \
    lhs.evt    = 0;                        \
    rhs.ready  = 1'b0;
`define C_SNE_EVENT_STREAM_CHANGE_DATA_SRC(lhs, evt) \
    lhs.valid  = 1;                     \
    lhs.evt    = evt; 

//--- this macro MUST be used every time two "SNE_DP_STREAM" interfaces need to be connected
`define SNE_DP_STREAM_PROPAGATE_DST_SRC(lhs, rhs)    \
     lhs.valid  = rhs.valid;                \
     lhs.evt    = rhs.evt;                  \
     rhs.ready  = lhs.ready;

//--- this macro MUST be used every time two "SNE_EVENT_STREAM" interfaces need to be connected
`define SNE_DP_STREAM_ABSORBE_DST_SRC(lhs, rhs)   \
     lhs.valid  = 1'b0;                     \
     lhs.evt    = 0;                        \
     rhs.ready  = 1'b1;
                  
`define SNE_EVENT_STREAM_TO_8x8DP_ASSIGN(dp_stream, event_stream, dp_op)       \
     dp_stream.valid                    = event_stream.valid;            \
     dp_stream.evt.dp_data.dp_operation = dp_op;                         \
     dp_stream.evt.dp_data.unused       = event_stream.evt.spike.unused; \
     dp_stream.evt.dp_data.cid          = event_stream.evt.spike.cid;    \
     dp_stream.evt.dp_data.yid          = event_stream.evt.spike.yid & 8'b11111111;    \
     dp_stream.evt.dp_data.xid          = event_stream.evt.spike.xid & 8'b11111111;    \
     event_stream.ready                 = dp_stream.ready;

`define REG_BUS_ASSIGN_TO_REQ_OFFSET(lhs, rhs, OFFSET) \
  assign lhs = '{                       \
    addr: rhs.addr-OFFSET,              \
    write: rhs.write,                   \
    wdata: rhs.wdata,                   \
    wstrb: rhs.wstrb,                   \
    valid: rhs.valid                    \
  };

`endif