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
package sne_evt_stream_pkg;
	// import sne_reg_pkg::sne_reg2hw_t;
	// import sne_reg_pkg::sne_hw2reg_t;
	import sne_pkg::ENGINES;
	import bus_clock_reg_pkg::bus_clock_reg2hw_t;
	import bus_clock_reg_pkg::bus_clock_hw2reg_t;
	import engine_clock_reg_pkg::engine_clock_reg2hw_t;
	import engine_clock_reg_pkg::engine_clock_hw2reg_t;
	import system_clock_reg_pkg::system_clock_reg2hw_t;
	import system_clock_reg_pkg::system_clock_hw2reg_t;

	typedef struct packed {
		bus_clock_reg2hw_t reg2hw;
		bus_clock_hw2reg_t hw2reg;
	} config_bus_t;

	typedef struct packed {
		engine_clock_reg2hw_t reg2hw;
		engine_clock_hw2reg_t hw2reg;
		logic [31:0] online_addr;
		// logic [ENGINES-1:0][31:0] online_data;
		logic [ENGINES*32-1:0] online_data;
	} config_engine_t;

	typedef struct packed {
		system_clock_reg2hw_t reg2hw;
		// system_clock_hw2reg_t hw2reg;
	} config_system_sw_t;

	typedef struct packed {
		// system_clock_reg2hw_t reg2hw;
		system_clock_hw2reg_t hw2reg;
	} config_system_hw_t;

	// this package must be imported only by the top level module, types can be propagated downstream by passing them as parameters
	// to downstream modules.

	// Here we create a union event type, as some module is agnostic to the event type, and some other will need to check it
	// we decide internal parallelism is 32 bits

	localparam EVENT_WIDTH = 32;
	localparam OP_WIDTH    = 4;

	// we create several structures dividing the the event bits in different ways, the general event type is
	typedef struct packed {
		logic [EVENT_WIDTH-1:0] bits;
	} event_t;

	// define the possible operation performed when an event is received
	typedef enum logic [OP_WIDTH-1:0] {
		EVT_IDLE       = 1,
		EVT_SPIKE      = 2,
		EVT_ACCUMULATE = 3,
		EVT_WIPE       = 4,
		EVT_TIME       = 5,
		EVT_PKT_END    = 6,
		EVT_SYNCH      = 7,
		EVT_UPDATE     = 8, //helpful in refresh
		// BARRIER_EVT    = 7,
		EOP            = 9, // end of opeartion, engine packet tail
		NEO            = 0  // Not an Event Operation
	} operation_t;

	// define the spike event type, the struct is packed, therefore we will fill all the bits to have the operation field always aligned to MSB
	localparam XID_WIDTH = 8;
	localparam YID_WIDTH = 8;
	localparam CID_WIDTH = 8;
	localparam UNUSED_SPIKE_BITS = EVENT_WIDTH - OP_WIDTH - XID_WIDTH - YID_WIDTH - CID_WIDTH;

	typedef logic [CID_WIDTH-1:0] cid_t;
	typedef logic [YID_WIDTH-1:0] yid_t;
	typedef logic [XID_WIDTH-1:0] xid_t;

	typedef struct packed {

	  operation_t                   operation;
	  logic [UNUSED_SPIKE_BITS-1:0] unused   ;
	  cid_t                         cid      ;
	  yid_t                         yid      ;
	  xid_t                         xid      ;

	} spike_t;

	// define the time event
	localparam TIME_WIDTH = EVENT_WIDTH-OP_WIDTH;

	typedef logic [TIME_WIDTH-1:0] timestamp_t;

	typedef struct packed {
		operation_t operation;
		timestamp_t value;
	} time_t;

	typedef struct packed {
		operation_t operation;
		logic [EVENT_WIDTH-OP_WIDTH-1:0] barrier_id;
	} barrier_t;
	// define the possible commands sent to the neuron dp
	typedef enum logic [OP_WIDTH-1:0] {
		IDLE_OP       = 0,
		SPIKE_OP      = 1,
		INTEGRATE_OP  = 4,
		RST_OP        = 5,
		UPDATE_OP     = 6
	} neuron_dp_op_t;

	// data/command sent to the neuron group
	typedef struct packed {

	  neuron_dp_op_t                dp_operation;
	  logic [UNUSED_SPIKE_BITS-1:0] unused ;
	  cid_t                         cid    ;
	  yid_t                         yid    ;
	  xid_t                         xid    ;

	} dp_data_t;

	// global destination targets, this information is contained in the packet header
	typedef enum logic [3:0] {
		DST_ENGINE = 0,
		DST_MEMORY = 1,
		DST_EXTERNAL = 2
	} mUDP_gdst_t;

	// local destination target (custom)
	typedef logic [7:0] mUDP_ldst_t;

	// header type, used to data redirection
	typedef struct packed {
		logic       [ 3:0] option; // arbitrary option (can be used to recognize a header word in the stream)
		mUDP_gdst_t        gdst  ; // global destination
		mUDP_ldst_t        ldst  ; // local destination
		logic       [15:0] length; // packet length
	} mUDP_header_t;

	// weights type
	localparam WEIGHT_WIDTH = 4;

	typedef logic [3:0] weight_t;

	typedef struct packed {
		weight_t [EVENT_WIDTH/WEIGHT_WIDTH-1:0] w;
	} weights_t;

	// now create a union to overlap all the fields and interpret a single event in different ways depending on the context
	typedef union packed {
		event_t       data      ; // return the entire event including the operation
		spike_t       spike     ; // interpret field as spike event
		dp_data_t     dp_data   ; // interpret fields as data for the data path
		time_t        timestamp ; // interpret fields as time event
		weights_t     weights   ; // interpret fields as weights
		mUDP_header_t header    ; // interpret fields as packet header
		barrier_t     synch     ;
	} uevent_t;


	// neuron types, they must fit in a 32 bits word
	// neuron parameters related types
	typedef logic [7:0] vmem_t;
	typedef logic [7:0] avth_t;
	typedef logic [7:0] tlupd_t;
	typedef logic [7:0] tlspk_t;

	typedef struct packed {
		vmem_t  vmem ;
		avth_t  avth ;
		tlupd_t tlupd;
		tlspk_t tlspk;
	} alif_state_t;

	typedef struct packed {
		tlupd_t tlupd;
		vmem_t  vmem ;
	} lif_state_t;

	// used in case we have multiple tipe of neurons
	typedef union packed {
		alif_state_t state;
	} state_t;

	// neuron parameters related types
	typedef logic [7:0] vrest_t;
	typedef logic [7:0] vth_t;
	typedef logic [7:0] tref_t;
	typedef logic [3:0] davth_t;
	typedef logic [3:0] tscale_t;

	typedef struct packed {
		vrest_t  vrest ;
		vth_t    vth   ;
		tref_t   tref  ;
		davth_t  davth ;
		tscale_t tscale;
	} alif_parameter_t;

	// used in case we have multiple tipe of neurons
	typedef union packed {
		alif_parameter_t neuron_parameter;
	} parameter_t;

	localparam ADDR_WIDTH            = 32;
	localparam DATA_WIDTH            = 32;
	typedef logic [DATA_WIDTH-1:0] data_t;
	typedef logic [ADDR_WIDTH-1:0] addr_t;
	typedef logic [DATA_WIDTH/8-1:0] strb_t;

	typedef struct packed{
		addr_t addr;
		data_t wdata;
		strb_t wstrb;
		logic  write;
		logic  valid;
	}apb_input_t;

	typedef struct packed{
		logic valid;
		logic ready;
		apb_input_t req;
	} apb_req_t;

	typedef struct packed{
		// addr_t addr;
		data_t rdata;
		logic  error;
		logic  ready;
	}apb_output_t;
	typedef struct packed{
		logic valid;
		logic ready;
		apb_output_t rsp;
	} apb_rsp_t;


endpackage