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
interface APB_BUS_test #(
    parameter int unsigned APB_ADDR_WIDTH = 32,
    parameter int unsigned APB_DATA_WIDTH = 32
);

    logic                      clk;
    logic [APB_ADDR_WIDTH-1:0] paddr;
    logic [APB_DATA_WIDTH-1:0] pwdata;
    logic                      pwrite;
    logic                      psel;
    logic                      penable;
    logic [APB_DATA_WIDTH-1:0] prdata;
    logic                      pready;
    logic                      pslverr;


    // Master Side
    modport Master (
        output paddr,  pwdata,  pwrite, psel,  penable,
        input  prdata,          pready,        pslverr, clk
    );

    // Slave Side
    modport Slave (
        input   paddr,  pwdata,  pwrite, psel,  penable,
        output  prdata,          pready,        pslverr, clk
    );

    /// The interface as an output (issuing requests, initiator, master).
    modport out (
        output paddr,  pwdata,  pwrite, psel,  penable,
        input  prdata,          pready,        pslverr, clk
    );

    /// The interface as an input (accepting requests, target, slave)
    modport in (
        input   paddr,  pwdata,  pwrite, psel,  penable,
        output  prdata,          pready,        pslverr, clk
    );


endinterface

// █████╗ ██████╗ ██████╗          ██████╗ ███████╗███╗   ██╗███████╗██████╗ ██╗ ██████╗     ████████╗██████╗  █████╗ ███╗   ██╗███████╗ █████╗  ██████╗████████╗██╗ ██████╗ ███╗   ██╗
//██╔══██╗██╔══██╗██╔══██╗        ██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔══██╗██║██╔════╝     ╚══██╔══╝██╔══██╗██╔══██╗████╗  ██║██╔════╝██╔══██╗██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║
//███████║██████╔╝██████╔╝        ██║  ███╗█████╗  ██╔██╗ ██║█████╗  ██████╔╝██║██║             ██║   ██████╔╝███████║██╔██╗ ██║███████╗███████║██║        ██║   ██║██║   ██║██╔██╗ ██║
//██╔══██║██╔═══╝ ██╔══██╗        ██║   ██║██╔══╝  ██║╚██╗██║██╔══╝  ██╔══██╗██║██║             ██║   ██╔══██╗██╔══██║██║╚██╗██║╚════██║██╔══██║██║        ██║   ██║██║   ██║██║╚██╗██║
//██║  ██║██║     ██████╔╝███████╗╚██████╔╝███████╗██║ ╚████║███████╗██║  ██║██║╚██████╗███████╗██║   ██║  ██║██║  ██║██║ ╚████║███████║██║  ██║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║
//╚═╝  ╚═╝╚═╝     ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝ ╚═════╝╚══════╝╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
class apb_generic_transaction;
	rand logic [31:0] apb_data   ;
	logic [31:0] apb_addr   ;
	int          trans_ID   ;
	int          trans_type ;

	function void pre_randomize();
	    //$display("--------- [Trans] pre_randomize ------");
	    //$display("--------- events on ch %0d down to 0",`N_CHANNELS-1);
	    //for (int i = 0; i < `BUF_DEPTH; i++) begin
	      //$display("\t event %0d  = %b",i,event_sequence[i]);
	    //end
	    //$display("-----------------------------------------");
	endfunction

	//postrandomize function, displaying randomized values of items 
	function void post_randomize();
	    //$display("--------- [Trans] post_randomize ------");
	    //$display("--------- events on ch %0d down to 0",`N_CHANNELS-1);
	    //for (int i = 0; i < `BUF_DEPTH; i++) begin
	      //$display("\t event %0d  = %b",i,event_sequence[i]);
	    //end
	    //$display("-----------------------------------------");
	endfunction
	
	//deep copy method
	function apb_generic_transaction do_copy();
	  apb_generic_transaction trans;
	  trans            = new();
	  trans.apb_data   = this.apb_data;
	  trans.apb_addr   = this.apb_addr;
	  trans.trans_ID   = this.trans_ID;
	  trans.trans_type = this.trans_type;
	  return trans;
	endfunction

	function void uniquify(int ID,int TYPE);
	  this.trans_ID = ID;
	  this.trans_type = TYPE;
	endfunction : uniquify

endclass : apb_generic_transaction


// ██████╗ ███████╗███╗   ██╗███████╗██████╗  █████╗ ████████╗ ██████╗ ██████╗ 
//██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗
//██║  ███╗█████╗  ██╔██╗ ██║█████╗  ██████╔╝███████║   ██║   ██║   ██║██████╔╝
//██║   ██║██╔══╝  ██║╚██╗██║██╔══╝  ██╔══██╗██╔══██║   ██║   ██║   ██║██╔══██╗
//╚██████╔╝███████╗██║ ╚████║███████╗██║  ██║██║  ██║   ██║   ╚██████╔╝██║  ██║
// ╚═════╝ ╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝                                                                           
class generator;
  
  //declaring transaction class 
  rand apb_generic_transaction trans,tr;
  
  //repeat count, to specify number of items to generate
  int  repeat_count;
  int  tr_int_ID;
  int  tr_int_TYPE;
  
  //mailbox, to generate and send the packet to driver
  mailbox gen2driv;
  
  //event
  event ended;
  
  //constructor
  function new(mailbox gen2driv,event ended);
    //getting the mailbox handle from env, in order to share the transaction packet between the generator and driver, the same mailbox is shared between both.
    this.gen2driv = gen2driv;
    this.ended    = ended;
    trans = new();
  endfunction

  task generate_weights();
  	tr_int_ID = 0;
  	tr_int_TYPE = 0;
  	$display("--------- [GENERATOR] generate_weights start ------");
  	repeat(repeat_count) begin
		trans.uniquify(tr_int_ID,tr_int_TYPE);
		if( !trans.randomize() ) $fatal("Gen:: trans randomization failed");
    trans.apb_addr = tr_int_ID;      
		tr = trans.do_copy();
		gen2driv.put(tr);
		tr_int_ID++;
		->ended;
  	end
  	$display("--------- [GENERATOR] generate_weights end ------");
  endtask : generate_weights

  task clean_status();
  	tr_int_ID = 0;
  	tr_int_TYPE = 0;

  	repeat(repeat_count) begin
  	trans.uniquify(tr_int_ID,tr_int_TYPE);
  	if( !trans.randomize() ) $fatal("Gen:: trans randomization failed");      
  	tr = trans.do_copy();
  	gen2driv.put(tr);
  	tr_int_ID++;
  	->ended;
  	end
  endtask : clean_status

  task set_parametrs();
  	tr_int_ID = 0;
  	tr_int_TYPE = 0;

  	repeat(repeat_count) begin
  	trans.uniquify(tr_int_ID,tr_int_TYPE);
  	if( !trans.randomize() ) $fatal("Gen:: trans randomization failed");      
  	tr = trans.do_copy();
  	gen2driv.put(tr);
  	tr_int_ID++;
  	->ended;
  	end
  endtask : set_parametrs
  
endclass


//██████╗ ██████╗ ██╗██╗   ██╗███████╗██████╗ 
//██╔══██╗██╔══██╗██║██║   ██║██╔════╝██╔══██╗
//██║  ██║██████╔╝██║██║   ██║█████╗  ██████╔╝
//██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
//██████╔╝██║  ██║██║ ╚████╔╝ ███████╗██║  ██║
//╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
//gets the packet from generator and drive the transaction paket items into interface (interface is connected to DUT, so the items driven into interface signal will get driven in to DUT) 
`define DRIV_IF apb_vif
`define MON_IF apb_vif

class driver;
  
  //used to count the number of transactions
  int no_transactions;
  
  //creating virtual interface handle
  virtual APB_BUS_test apb_vif;
  
  //creating mailbox handle
  mailbox gen2driv;
  mailbox drv2scbd;

  //event
  event new_tran;
  
  //constructor
  function new(virtual APB_BUS_test apb_vif,mailbox gen2driv,event new_tran);
    //getting the interface
    this.apb_vif = apb_vif;

    this.drv2scbd = drv2scbd;
    this.gen2driv = gen2driv;
    this.new_tran = new_tran;
  endfunction
  
  //Reset task, Reset the Interface signals to default/initial values
  task reset;
    //wait(!apb_vif.reset);
    $display("--------- [DRIVER] Reset Started ---------");
    //`DRIV_IF.req_array           <= 0;
    //`DRIV_IF.data_bit_array      <= 0;
    //`DRIV_IF.new_transaction     <= 0;  
    apb_vif.penable  = 1'b0;
    apb_vif.pwdata   = 0;
    apb_vif.paddr    = 0;
    apb_vif.pwrite   = 1'b0;
    apb_vif.psel     = 1'b0;
    $display("--------- [DRIVER] Reset Ended ---------");
    //wait(apb_vif.reset);
  endtask
  
  //drivers the transaction items to interface signals
  task drv;
      apb_generic_transaction trans;
      apb_generic_transaction tr;

      //`DRIV_IF.req_array           <= 'b0;
      //`DRIV_IF.data_bit_array      <= 'b0;
      //`DRIV_IF.new_transaction     <= 'b0;
      //$display("--------- [DRIVER] drive Start ---------");
      gen2driv.get(trans);
      tr = trans.do_copy();

      //--- this is necessary to not issue more than 8 events before reading the buffers
      //--- it's not yet the real operating condition, monitor must be changed accordingly if this time is reduced
      //#1000ns;

      $display("--------- [DRIVER-TRANSFER: %0d] ---------",no_transactions);
      //apb_vif.penable  = 1'b0;
      //apb_vif.pwdata   = 0;
      //apb_vif.paddr    = 0;
      //apb_vif.pwrite   = 1'b0;
      //apb_vif.psel     = 1'b0;
      //@(posedge apb_vif.clk);
      apb_vif.penable  = 1'b0;
      apb_vif.pwdata   = trans.apb_data;
      apb_vif.paddr    = trans.apb_addr + 32'h00020000;
      apb_vif.pwrite   = 1'b1;
      apb_vif.psel     = 1'b1;
      @(posedge apb_vif.clk);
      apb_vif.penable  = 1'b1;
      @(posedge apb_vif.clk);
      while(~apb_vif.pready);
      apb_vif.paddr = 0;
      apb_vif.pwdata = 0;
      apb_vif.pwrite = 0;
      apb_vif.psel = 0;
      apb_vif.penable = 0;

      //for (int e = 0; e < `BUF_DEPTH; e++) begin
//
      //  for (int i = 0; i < `N_CHANNELS; i++) begin
      //    trans.timestamps[e][i] = $urandom_range(`MIN_DISTRIB_SPIKE_TIME,`MIN_INTERSPIKE_TIME);
      //    trans.timestamps_end[e][i] = trans.timestamps[e][i] + $urandom_range(`MIN_REQ_TIME,`MAX_REQ_TIME);
      //  end
//
      //  `DRIV_IF.data_bit_array <= trans.event_sequence[e];
      //  `ifdef PRINT_BITS
      //    $display("\tDRV_DATA_BITS = %b \t",trans.event_sequence[e]);
      //  `endif
//
      //  //distribute events in time
      //  for (int t = 0; t < `MIN_INTERSPIKE_TIME+`MAX_REQ_TIME+1; t++) begin
      //    for (int k = 0; k < `N_CHANNELS; k++) begin
      //      if(trans.timestamps[e][k] == t) begin
      //        `DRIV_IF.req_array[k] <= 1'b1; //set the request on channel k
      //      end
//
      //      if(trans.timestamps_end[e][k] == t) begin
      //        `DRIV_IF.req_array[k] <= 1'b0; //set the request on channel k
      //      end
      //    end
      //    #1ns; //this serves as time unit, keep it consistent with the define
      //  end
//
      //end

      //drv2scbd.put(tr);
      //#1ns;
      ->new_tran;
      no_transactions++;
      //$display("--------- [DRIVER] drive end ---------");
  endtask
  
  //
  task main;
    forever begin
      fork
        //Thread-1: Waiting for reset
        //begin
          //wait(!apb_vif.reset);
        //end
        //Thread-2: Calling drive task
        begin
          forever
            drv();
        end

      join_any

      disable fork;
    end
  endtask
  
endclass



//███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗ 
//████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗
//██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝
//██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗
//██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║
//╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
class monitor;
  
  //creating virtual interface handle
  virtual APB_BUS_test apb_vif;
  
  //creating mailbox handle
  mailbox mon2scb;
  event new_tran;

  int no_transactions;
  int no_evts;
  
  //constructor
  function new(virtual APB_BUS_test apb_vif,mailbox mon2scb,event new_tran);
    //getting the interface
    this.apb_vif = apb_vif;
    //getting the mailbox handles from  environment 
    this.mon2scb = mon2scb;
    this.new_tran = new_tran;
  endfunction
  
  //Samples the interface signal and send the sample packet to scoreboard
  task mon;


    //logic [`N_CHANNELS-1:0] ch_flag;
    //logic  [`BUF_DEPTH-1:0][`N_CHANNELS-1:0] mon_event_sequence;


    apb_generic_transaction trans;
    trans = new();

    //for (int i = 0; i < `BUF_DEPTH; i++) begin
//
    //  //for (int l = 0; l < `N_CHANNELS; l++) begin
    //  ch_flag = 'b0;
    //  //end
    //  no_evts = 0;
//
    //  while (no_evts < `N_CHANNELS-1) begin
    //    for (int k = 0; k < `N_CHANNELS; k++) begin
    //      mon_event_sequence[i][k] = `MON_IF.data_bit_array[k];
    //      if(`MON_IF.req_array[k] == 1'b1) begin
    //        if(ch_flag[k] == 0) begin
    //          no_evts++;
    //          //$display("new req on ch %d",k);
    //          ch_flag[k] = 1'b1;
    //        end
    //      end
    //    end
    //    #10ps;    
    //  end    
    //end

    //--- before pushing a new transaction wait that the driver has finished
    wait(new_tran.triggered);

    $display("--------- [MONITOR-TRANSFER: %0d] ---------",no_transactions);
    //for (int m = 0; m < `BUF_DEPTH; m++) begin
    //  `ifdef PRINT_BITS
    //    $display("\tMON_DATA_BITS = %b \t",mon_event_sequence[m]);
    //  `endif
    //  trans.event_sequence[m] = mon_event_sequence[m];
    //  trans.uniquify(no_transactions,0);
    //end
    no_transactions++;
    //$display("trans id = %d",trans.trans_ID);
    //$display("-----------------------------------------");
    mon2scb.put(trans);
    #1ns;

  endtask

  task main;
    forever begin
      fork
        //Thread-1: Waiting for reset
        //begin
          //wait(!apb_vif.reset);
        //end
        //Thread-2: Calling drive task
        begin
            mon();
        end

      join_any

      disable fork;
    end
  endtask
  
endclass


////██████╗ ███████╗ █████╗ ██████╗ ███████╗██████╗ 
////██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
////██████╔╝█████╗  ███████║██║  ██║█████╗  ██████╔╝
////██╔══██╗██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
////██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
////╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
//`define READ_IF output_vif
//class reader;
//  
//  //used to count the number of transactions
//  int no_transactions;
//  
//  //creating virtual interface handle
//  virtual output_trans_intf output_vif;
//  
//  //creating mailbox handle
//  mailbox read2scbd;
//  event new_tran;
//  
//  //constructor
//  function new(virtual output_trans_intf output_vif,mailbox read2scbd,event new_tran);
//    //getting the interface
//    this.output_vif = output_vif;
//    //getting the mailbox handles from  environment 
//    this.read2scbd = read2scbd;
//    this.new_tran = new_tran;
//  endfunction
//  
//  //Reset task, Reset the Interface signals to default/initial values
//  task reset;
//    wait(!output_vif.reset);
//    $display("--------- [READER] Reset Started ---------");
//    `READ_IF.udma_ready           <= 0;
//    `READ_IF.read                 <= 1'b0;
//    //`READ_IF.data_bit_array     <= 0;
//    wait(output_vif.reset);
//    $display("--------- [READER] Reset Ended ---------");
//  endtask
//  
//  //drivers the transaction items to interface signals
//  task read;
//
//      int no_words;
//      transaction trans;
//      trans = new();
//
//      wait(new_tran.triggered);
//
//      
//      `READ_IF.read                 <= 1'b1;
//      #20ns
//      `READ_IF.read                 <= 1'b0;
//      #20ns;
//      `READ_IF.udma_ready           <= 1'b1;
//      $display("--------- [READER-TRANSFER: %0d] ---------",no_transactions);
//
//      no_words = 0;
//
//      while ((no_words < (`UDMA_TR_HD_SIZE +`UDMA_TR_PL_SIZE)) || `READ_IF.udma_valid) begin
//        if(`READ_IF.udma_valid && `READ_IF.udma_ready) begin
//
//          trans.udma_data[no_words] = `READ_IF.udma_data;
//
//          @(posedge `READ_IF.clk);
//
//          //$display("UDMA-DATA %0d: %b",no_words,trans.udma_data[no_words]);
//
//          `ifdef PRINT_BITS
//            $display("%d UDMA-DATA: %d",no_words,`READ_IF.udma_data);
//            //$display("-----------------------------------------");
//          `endif
//          no_words++;
//        end
//        #1ns;
//      end
//      #5ns;
//      `READ_IF.udma_ready           <= 1'b0;
//      trans.uniquify(no_transactions,1);
//      read2scbd.put(trans);
//      no_transactions++;
//  endtask
//  
//  //
//  task main;
//    forever begin
//      fork
//        //Thread-1: Waiting for reset
//        begin
//          wait(!output_vif.reset);
//        end
//        //Thread-2: Calling drive task
//        begin
//          forever
//            read();
//        end
//      join_any
//      disable fork;
//    end
//  endtask
//        
//endclass



//███████╗ ██████╗ ██████╗ ██████╗ ███████╗██████╗  ██████╗  █████╗ ██████╗ ██████╗ 
//██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗
//███████╗██║     ██║   ██║██████╔╝█████╗  ██████╔╝██║   ██║███████║██████╔╝██║  ██║
//╚════██║██║     ██║   ██║██╔══██╗██╔══╝  ██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║
//███████║╚██████╗╚██████╔╝██║  ██║███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝
//╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ 
class scoreboard;
    
  //creating mailbox handle
  mailbox mon2scb;
  mailbox read2scbd;
  mailbox drv2scbd;
   
  //used to count the number of transactions
  int no_transactions;
   
   
  //constructor
  function new(mailbox mon2scb,mailbox read2scbd, mailbox drv2scbd);
    //getting the mailbox handles from  environment
    this.mon2scb = mon2scb;
    this.read2scbd = read2scbd;
    this.drv2scbd = drv2scbd;
    //foreach(mem[i]) mem[i] = 8'hFF;
  endfunction
   

  task main;

  endtask

  //stores wdata and compare rdata with stored data
  //task simple_check;
  //  transaction trans_in;
  //  transaction trans_out;
//
  //  logic [`N_CHANNELS-1:0][`BUF_DEPTH-1:0] encoded_events_p;
  //  logic [`N_CHANNELS-1:0][`BUF_DEPTH-1:0] encoded_events_n;
//
  //  logic [1:0][15:0] read_events_temp;
//
  //  logic [`BUF_DEPTH-1:0] buf_ud_single_ch;
  //  logic [`BUF_DEPTH-1:0] buf_du_single_ch;
//
  //  int c;
  //  logic [`BUF_DEPTH-1:0] results;
  //  int pos_evt_miss;
  //  int neg_evt_miss;
  //  int base_addr_pos;
  //  int base_addr_neg;
  //  logic evt_correct;
  //  logic no_evt;
//
  //  forever begin
  //    #50;
  //    mon2scb.get(trans_in);
  //    read2scbd.get(trans_out);
//
  //    pos_evt_miss = 0;
  //    neg_evt_miss = 0;
//
  //    c= 0;
//
  //    $display("--------- [SCOREBD-TRANSFER: Tr in = %0d, Tr out = %0d ] ---------",trans_in.trans_ID,trans_out.trans_ID);
//
  //    $display("Packet integrity check ---------------------------------");
  //    for (int h = 0; h < `UDMA_TR_HD_SIZE; h++) begin
  //      $display("Header %0d = %0d, \t cmd %0d = %b",h,trans_out.udma_data[h][31:5],h,trans_out.udma_data[h][4:1]);
  //    end
//
  //    //--- single event on all channels
  //    for (int i = 0; i < `BUF_DEPTH; i++) begin
  //      for (int l = 0; l < `N_CHANNELS; l++) begin
//
  //        encoded_events_p[l][`BUF_DEPTH-1-i] = trans_in.event_sequence[i][l];
  //        encoded_events_n[l][`BUF_DEPTH-1-i] = ~trans_in.event_sequence[i][l];
//
  //      end
  //    end
//
  //    //--- this check works only if the buffer is filled with exactly 8 events (asynch sh reg filled untill the last bit)
//
  //    for (int p = 0; p < `N_CHANNELS*2*`CRU_EVT_DUMP/32; p++) begin
  //      `ifdef PRINT_PAYLOAD_TEST
  //        $display("payload line %0d = %b",p,trans_out.udma_data[p +    `UDMA_TR_HD_SIZE]);
  //      `endif
  //      
//
  //      for (int i = 0; i < 16/`BUF_DEPTH; i++) begin
  //        base_addr_pos = i*`BUF_DEPTH;
  //        base_addr_neg = i*`BUF_DEPTH + 16;
//
  //        for (int j = 0; j < `BUF_DEPTH; j++) begin
  //          //$display("buf_ud_single_ch[%0d] = udma_line[%0d]",j,base_addr + j);
  //          buf_ud_single_ch[j] = trans_out.udma_data[p + `UDMA_TR_HD_SIZE][base_addr_pos + j];
  //        end
//
  //        `ifdef PRINT_PAYLOAD_TEST
  //          
  //          $display("Channel %0d ----------------------------------",(16/`BUF_DEPTH)*p+i); 
  //        `endif
  //        if(encoded_events_p[(16/`BUF_DEPTH)*p+i] == buf_ud_single_ch) begin
  //          //$display("Pos evts match");
  //        end else begin
  //          $error("Pos event miss");
  //          pos_evt_miss++;
  //        end
//
  //        `ifdef PRINT_PAYLOAD_TEST            
  //          $display("Encoded events pos = %b",encoded_events_p[(16/`BUF_DEPTH)*p+i]);  
  //          $display("Sampled events pos = %b",buf_ud_single_ch);
  //        `endif
//
//
  //        for (int j = 0; j < `BUF_DEPTH; j++) begin
  //          //$display("buf_ud_single_ch[%0d] = udma_line[%0d]",j,base_addr + j);
  //          buf_du_single_ch[j] = trans_out.udma_data[p + `UDMA_TR_HD_SIZE][base_addr_neg + j];
  //        end
 //
  //        if(encoded_events_n[(16/`BUF_DEPTH)*p+i] == buf_du_single_ch) begin
  //          //$display("Neg evts match");
  //        end else begin
  //          $error("Neg event miss");
  //          neg_evt_miss++;
  //        end
  //        `ifdef PRINT_PAYLOAD_TEST
  //          $display("Encoded events neg = %b",encoded_events_n[(16/`BUF_DEPTH)*p+i]);  
  //          $display("Sampled events neg = %b",buf_du_single_ch);
  //        `endif
  //      end
//
  //    end
//
  //    $display("Payload = %0d 32bit words",`N_CHANNELS*2*`CRU_EVT_DUMP/32);
//
  //    if((pos_evt_miss==0) && (neg_evt_miss == 0)) begin
  //      $info("*********** TEST CASE PASS ************");
  //    end else begin
  //      $error("*********** TEST CASE FAIL ************");
  //    end
  //
  //    $display("-----------------------------------------"); 
//
  //  end
  //endtask
   
endclass


//███████╗███╗   ██╗██╗   ██╗██╗██████╗  ██████╗ ███╗   ██╗███╗   ███╗███████╗███╗   ██╗████████╗
//██╔════╝████╗  ██║██║   ██║██║██╔══██╗██╔═══██╗████╗  ██║████╗ ████║██╔════╝████╗  ██║╚══██╔══╝
//█████╗  ██╔██╗ ██║██║   ██║██║██████╔╝██║   ██║██╔██╗ ██║██╔████╔██║█████╗  ██╔██╗ ██║   ██║   
//██╔══╝  ██║╚██╗██║╚██╗ ██╔╝██║██╔══██╗██║   ██║██║╚██╗██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║   ██║   
//███████╗██║ ╚████║ ╚████╔╝ ██║██║  ██║╚██████╔╝██║ ╚████║██║ ╚═╝ ██║███████╗██║ ╚████║   ██║   
//╚══════╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   
class environment;
  
  //generator and driver instance
  generator  gen;
  driver     driv;
  monitor    mon;
  //reader     rdr;
  scoreboard scb;
  
  //mailbox handle's
  mailbox gen2driv;
  mailbox mon2scb;
  mailbox read2scbd;
  
  //event for synchronization between generator and test
  event gen_ended;
  event new_tran;
  
  //virtual interface
  virtual APB_BUS_test apb_vif;
  virtual APB_BUS_test output_vif;
  
  //constructor
  function new(virtual APB_BUS_test apb_vif,virtual APB_BUS_test output_vif);
    //get the interface from test
    this.apb_vif = apb_vif;
    this.output_vif = output_vif;
    
    //creating the mailbox (Same handle will be shared across generator and driver)
    gen2driv = new();
    mon2scb  = new();
    read2scbd = new();
    //drv2scbd = new();
    
    //creating generator and driver
    gen  = new(gen2driv,gen_ended);
    driv = new(apb_vif,gen2driv,new_tran);
    mon  = new(apb_vif,mon2scb,new_tran);
    //rdr  = new(output_vif,read2scbd,new_tran);
    //scb  = new(mon2scb,read2scbd,drv2scbd);
  endfunction
  
  //
  task pre_test();
    fork
    gen.generate_weights();
    driv.reset();
    //rdr.reset();
    join_any
  endtask
  
  task test();
    fork 
    
    driv.main();
    //rdr.main();
    mon.main();
    //scb.simple_check();      
    join_any
  endtask
  
  task post_test();
    wait(gen_ended.triggered);
    wait(gen.repeat_count == driv.no_transactions);
    //wait(gen.repeat_count == scb.no_transactions);
  endtask  
  
  //run task
  task run;
    pre_test();
    #50us;
    test();
    post_test();
    $finish;
  endtask
  
endclass
//
//
//██████╗ ██████╗  ██████╗  ██████╗ ██████╗  █████╗ ███╗   ███╗
//██╔══██╗██╔══██╗██╔═══██╗██╔════╝ ██╔══██╗██╔══██╗████╗ ████║
//██████╔╝██████╔╝██║   ██║██║  ███╗██████╔╝███████║██╔████╔██║
//██╔═══╝ ██╔══██╗██║   ██║██║   ██║██╔══██╗██╔══██║██║╚██╔╝██║
//██║     ██║  ██║╚██████╔╝╚██████╔╝██║  ██║██║  ██║██║ ╚═╝ ██║
//╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
program test(APB_BUS_test intf,APB_BUS_test out_intf);
  
  //declaring environment instance
  environment env;
  
  initial begin
    //creating environment
    env = new(intf,out_intf);
    
    //setting the repeat count of generator as 4, means to generate 4 packets
    env.gen.repeat_count = 256;
    
    //calling run of env, it interns calls generator and driver main tasks.
    env.run();
  end
endprogram