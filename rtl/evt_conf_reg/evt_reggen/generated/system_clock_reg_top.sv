// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Top module auto-generated by `reggen`

`include "common_cells/assertions.svh"

module system_clock_reg_top #(
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic
) (
  input clk_i,
  input rst_ni,

  // Below Register interface can be changed
  input  reg_req_t reg_req_i,
  output reg_rsp_t reg_rsp_o,
  // To HW
  output system_clock_reg_pkg::system_clock_reg2hw_t reg2hw, // Write
  input  system_clock_reg_pkg::system_clock_hw2reg_t hw2reg, // Read

  // Config
  input devmode_i // If 1, explicit error return for unmapped register access
);

  import system_clock_reg_pkg::* ;

  localparam int AW = 7;
  localparam int DW = 32;
  localparam int DBW = DW/8;                    // Byte Width

  // register signals
  logic           reg_we;
  logic           reg_re;
  logic [AW-1:0]  reg_addr;
  logic [DW-1:0]  reg_wdata;
  logic [DBW-1:0] reg_be;
  logic [DW-1:0]  reg_rdata;
  logic           reg_error;

  logic          addrmiss, wr_err;

  logic [DW-1:0] reg_rdata_next;

  reg_req_t reg_intf_req;
  reg_rsp_t reg_intf_rsp;

  assign reg_intf_req = reg_req_i;
  assign reg_rsp_o = reg_intf_rsp;

  assign reg_we = reg_intf_req.valid & reg_intf_req.write;
  assign reg_re = reg_intf_req.valid & ~reg_intf_req.write;
  assign reg_addr = reg_intf_req.addr;
  assign reg_wdata = reg_intf_req.wdata;
  assign reg_be = reg_intf_req.wstrb;
  assign reg_intf_rsp.rdata = reg_rdata;
  assign reg_intf_rsp.error = reg_error;
  assign reg_intf_rsp.ready = 1'b1;

  assign reg_rdata = reg_rdata_next ;
  assign reg_error = (devmode_i & addrmiss) | wr_err ;

  // Define SW related signals
  // Format: <reg>_<field>_{wd|we|qs}
  //        or <reg>_{wd|we|qs} if field == 1 or 0
  logic [31:0] cfg_main_ctrl_i_0_qs;
  logic [31:0] cfg_main_ctrl_i_0_wd;
  logic cfg_main_ctrl_i_0_we;
  logic [31:0] cfg_main_ctrl_i_1_qs;
  logic [31:0] cfg_main_ctrl_i_1_wd;
  logic cfg_main_ctrl_i_1_we;
  logic [31:0] cfg_out_stream_i_0_qs;
  logic [31:0] cfg_out_stream_i_0_wd;
  logic cfg_out_stream_i_0_we;
  logic [31:0] cfg_out_stream_i_1_qs;
  logic [31:0] cfg_out_stream_i_1_wd;
  logic cfg_out_stream_i_1_we;
  logic [31:0] cfg_tcdm_start_addr_i_0_qs;
  logic [31:0] cfg_tcdm_start_addr_i_0_wd;
  logic cfg_tcdm_start_addr_i_0_we;
  logic [31:0] cfg_tcdm_start_addr_i_1_qs;
  logic [31:0] cfg_tcdm_start_addr_i_1_wd;
  logic cfg_tcdm_start_addr_i_1_we;
  logic [31:0] cfg_tcdm_addr_step_i_0_qs;
  logic [31:0] cfg_tcdm_addr_step_i_0_wd;
  logic cfg_tcdm_addr_step_i_0_we;
  logic [31:0] cfg_tcdm_addr_step_i_1_qs;
  logic [31:0] cfg_tcdm_addr_step_i_1_wd;
  logic cfg_tcdm_addr_step_i_1_we;
  logic [31:0] cfg_tcdm_end_addr_i_0_qs;
  logic [31:0] cfg_tcdm_end_addr_i_0_wd;
  logic cfg_tcdm_end_addr_i_0_we;
  logic [31:0] cfg_tcdm_end_addr_i_1_qs;
  logic [31:0] cfg_tcdm_end_addr_i_1_wd;
  logic cfg_tcdm_end_addr_i_1_we;
  logic [31:0] cfg_tcdm_tran_size_i_0_qs;
  logic [31:0] cfg_tcdm_tran_size_i_0_wd;
  logic cfg_tcdm_tran_size_i_0_we;
  logic [31:0] cfg_tcdm_tran_size_i_1_qs;
  logic [31:0] cfg_tcdm_tran_size_i_1_wd;
  logic cfg_tcdm_tran_size_i_1_we;
  logic [31:0] cfg_sram_start_addr_i_0_qs;
  logic [31:0] cfg_sram_start_addr_i_0_wd;
  logic cfg_sram_start_addr_i_0_we;
  logic [31:0] cfg_sram_start_addr_i_1_qs;
  logic [31:0] cfg_sram_start_addr_i_1_wd;
  logic cfg_sram_start_addr_i_1_we;
  logic [31:0] cfg_sram_addr_step_i_0_qs;
  logic [31:0] cfg_sram_addr_step_i_0_wd;
  logic cfg_sram_addr_step_i_0_we;
  logic [31:0] cfg_sram_addr_step_i_1_qs;
  logic [31:0] cfg_sram_addr_step_i_1_wd;
  logic cfg_sram_addr_step_i_1_we;
  logic [31:0] cfg_sram_end_addr_i_0_qs;
  logic [31:0] cfg_sram_end_addr_i_0_wd;
  logic cfg_sram_end_addr_i_0_we;
  logic [31:0] cfg_sram_end_addr_i_1_qs;
  logic [31:0] cfg_sram_end_addr_i_1_wd;
  logic cfg_sram_end_addr_i_1_we;
  logic [31:0] sta_main_status_o_0_qs;
  logic [31:0] sta_main_status_o_1_qs;
  logic [7:0] cfg_fc_dimension_i_x_dim_qs;
  logic [7:0] cfg_fc_dimension_i_x_dim_wd;
  logic cfg_fc_dimension_i_x_dim_we;
  logic [7:0] cfg_fc_dimension_i_y_dim_qs;
  logic [7:0] cfg_fc_dimension_i_y_dim_wd;
  logic cfg_fc_dimension_i_y_dim_we;
  logic [31:0] cfg_fc_offset_i_qs;
  logic [31:0] cfg_fc_offset_i_wd;
  logic cfg_fc_offset_i_we;
  logic [31:0] sta_trans_ptr_o_0_qs;
  logic [31:0] sta_trans_ptr_o_1_qs;
  logic [31:0] cfg_fc_tran_size_i_0_qs;
  logic [31:0] cfg_fc_tran_size_i_0_wd;
  logic cfg_fc_tran_size_i_0_we;
  logic [31:0] cfg_fc_tran_size_i_1_qs;
  logic [31:0] cfg_fc_tran_size_i_1_wd;
  logic cfg_fc_tran_size_i_1_we;

  // Register instances

  // Subregister 0 of Multireg cfg_main_ctrl_i
  // R[cfg_main_ctrl_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_main_ctrl_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_main_ctrl_i_0_we),
    .wd     (cfg_main_ctrl_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_main_ctrl_i[0].q ),

    // to register interface (read)
    .qs     (cfg_main_ctrl_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_main_ctrl_i
  // R[cfg_main_ctrl_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_main_ctrl_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_main_ctrl_i_1_we),
    .wd     (cfg_main_ctrl_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_main_ctrl_i[1].q ),

    // to register interface (read)
    .qs     (cfg_main_ctrl_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_out_stream_i
  // R[cfg_out_stream_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_out_stream_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_out_stream_i_0_we),
    .wd     (cfg_out_stream_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_out_stream_i[0].q ),

    // to register interface (read)
    .qs     (cfg_out_stream_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_out_stream_i
  // R[cfg_out_stream_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_out_stream_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_out_stream_i_1_we),
    .wd     (cfg_out_stream_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_out_stream_i[1].q ),

    // to register interface (read)
    .qs     (cfg_out_stream_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_tcdm_start_addr_i
  // R[cfg_tcdm_start_addr_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_start_addr_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_start_addr_i_0_we),
    .wd     (cfg_tcdm_start_addr_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_start_addr_i[0].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_start_addr_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_tcdm_start_addr_i
  // R[cfg_tcdm_start_addr_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_start_addr_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_start_addr_i_1_we),
    .wd     (cfg_tcdm_start_addr_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_start_addr_i[1].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_start_addr_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_tcdm_addr_step_i
  // R[cfg_tcdm_addr_step_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_addr_step_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_addr_step_i_0_we),
    .wd     (cfg_tcdm_addr_step_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_addr_step_i[0].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_addr_step_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_tcdm_addr_step_i
  // R[cfg_tcdm_addr_step_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_addr_step_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_addr_step_i_1_we),
    .wd     (cfg_tcdm_addr_step_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_addr_step_i[1].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_addr_step_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_tcdm_end_addr_i
  // R[cfg_tcdm_end_addr_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_end_addr_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_end_addr_i_0_we),
    .wd     (cfg_tcdm_end_addr_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_end_addr_i[0].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_end_addr_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_tcdm_end_addr_i
  // R[cfg_tcdm_end_addr_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_end_addr_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_end_addr_i_1_we),
    .wd     (cfg_tcdm_end_addr_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_end_addr_i[1].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_end_addr_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_tcdm_tran_size_i
  // R[cfg_tcdm_tran_size_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_tran_size_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_tran_size_i_0_we),
    .wd     (cfg_tcdm_tran_size_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_tran_size_i[0].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_tran_size_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_tcdm_tran_size_i
  // R[cfg_tcdm_tran_size_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_tcdm_tran_size_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tcdm_tran_size_i_1_we),
    .wd     (cfg_tcdm_tran_size_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_tcdm_tran_size_i[1].q ),

    // to register interface (read)
    .qs     (cfg_tcdm_tran_size_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_sram_start_addr_i
  // R[cfg_sram_start_addr_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_sram_start_addr_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_sram_start_addr_i_0_we),
    .wd     (cfg_sram_start_addr_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_sram_start_addr_i[0].q ),

    // to register interface (read)
    .qs     (cfg_sram_start_addr_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_sram_start_addr_i
  // R[cfg_sram_start_addr_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_sram_start_addr_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_sram_start_addr_i_1_we),
    .wd     (cfg_sram_start_addr_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_sram_start_addr_i[1].q ),

    // to register interface (read)
    .qs     (cfg_sram_start_addr_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_sram_addr_step_i
  // R[cfg_sram_addr_step_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_sram_addr_step_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_sram_addr_step_i_0_we),
    .wd     (cfg_sram_addr_step_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_sram_addr_step_i[0].q ),

    // to register interface (read)
    .qs     (cfg_sram_addr_step_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_sram_addr_step_i
  // R[cfg_sram_addr_step_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_sram_addr_step_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_sram_addr_step_i_1_we),
    .wd     (cfg_sram_addr_step_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_sram_addr_step_i[1].q ),

    // to register interface (read)
    .qs     (cfg_sram_addr_step_i_1_qs)
  );



  // Subregister 0 of Multireg cfg_sram_end_addr_i
  // R[cfg_sram_end_addr_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_sram_end_addr_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_sram_end_addr_i_0_we),
    .wd     (cfg_sram_end_addr_i_0_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_sram_end_addr_i[0].q ),

    // to register interface (read)
    .qs     (cfg_sram_end_addr_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_sram_end_addr_i
  // R[cfg_sram_end_addr_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_sram_end_addr_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_sram_end_addr_i_1_we),
    .wd     (cfg_sram_end_addr_i_1_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_sram_end_addr_i[1].q ),

    // to register interface (read)
    .qs     (cfg_sram_end_addr_i_1_qs)
  );



  // Subregister 0 of Multireg sta_main_status_o
  // R[sta_main_status_o_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RO"),
    .RESVAL  (32'h0)
  ) u_sta_main_status_o_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.sta_main_status_o[0].de),
    .d      (hw2reg.sta_main_status_o[0].d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.sta_main_status_o[0].q ),

    // to register interface (read)
    .qs     (sta_main_status_o_0_qs)
  );

  // Subregister 1 of Multireg sta_main_status_o
  // R[sta_main_status_o_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RO"),
    .RESVAL  (32'h0)
  ) u_sta_main_status_o_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.sta_main_status_o[1].de),
    .d      (hw2reg.sta_main_status_o[1].d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.sta_main_status_o[1].q ),

    // to register interface (read)
    .qs     (sta_main_status_o_1_qs)
  );


  // R[cfg_fc_dimension_i]: V(False)

  //   F[x_dim]: 23:16
  prim_subreg #(
    .DW      (8),
    .SWACCESS("RW"),
    .RESVAL  (8'h0)
  ) u_cfg_fc_dimension_i_x_dim (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_fc_dimension_i_x_dim_we),
    .wd     (cfg_fc_dimension_i_x_dim_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_fc_dimension_i.x_dim.q ),

    // to register interface (read)
    .qs     (cfg_fc_dimension_i_x_dim_qs)
  );


  //   F[y_dim]: 31:24
  prim_subreg #(
    .DW      (8),
    .SWACCESS("RW"),
    .RESVAL  (8'h0)
  ) u_cfg_fc_dimension_i_y_dim (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_fc_dimension_i_y_dim_we),
    .wd     (cfg_fc_dimension_i_y_dim_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_fc_dimension_i.y_dim.q ),

    // to register interface (read)
    .qs     (cfg_fc_dimension_i_y_dim_qs)
  );


  // R[cfg_fc_offset_i]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_fc_offset_i (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_fc_offset_i_we),
    .wd     (cfg_fc_offset_i_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_fc_offset_i.q ),

    // to register interface (read)
    .qs     (cfg_fc_offset_i_qs)
  );



  // Subregister 0 of Multireg sta_trans_ptr_o
  // R[sta_trans_ptr_o_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RO"),
    .RESVAL  (32'h0)
  ) u_sta_trans_ptr_o_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.sta_trans_ptr_o[0].de),
    .d      (hw2reg.sta_trans_ptr_o[0].d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.sta_trans_ptr_o[0].q ),

    // to register interface (read)
    .qs     (sta_trans_ptr_o_0_qs)
  );

  // Subregister 1 of Multireg sta_trans_ptr_o
  // R[sta_trans_ptr_o_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RO"),
    .RESVAL  (32'h0)
  ) u_sta_trans_ptr_o_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.sta_trans_ptr_o[1].de),
    .d      (hw2reg.sta_trans_ptr_o[1].d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.sta_trans_ptr_o[1].q ),

    // to register interface (read)
    .qs     (sta_trans_ptr_o_1_qs)
  );



  // Subregister 0 of Multireg cfg_fc_tran_size_i
  // R[cfg_fc_tran_size_i_0]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_fc_tran_size_i_0 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_fc_tran_size_i_0_we),
    .wd     (cfg_fc_tran_size_i_0_wd),

    // from internal hardware
    .de     (hw2reg.cfg_fc_tran_size_i[0].de),
    .d      (hw2reg.cfg_fc_tran_size_i[0].d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_fc_tran_size_i[0].q ),

    // to register interface (read)
    .qs     (cfg_fc_tran_size_i_0_qs)
  );

  // Subregister 1 of Multireg cfg_fc_tran_size_i
  // R[cfg_fc_tran_size_i_1]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_cfg_fc_tran_size_i_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_fc_tran_size_i_1_we),
    .wd     (cfg_fc_tran_size_i_1_wd),

    // from internal hardware
    .de     (hw2reg.cfg_fc_tran_size_i[1].de),
    .d      (hw2reg.cfg_fc_tran_size_i[1].d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg_fc_tran_size_i[1].q ),

    // to register interface (read)
    .qs     (cfg_fc_tran_size_i_1_qs)
  );




  logic [25:0] addr_hit;
  always_comb begin
    addr_hit = '0;
    addr_hit[ 0] = (reg_addr == SYSTEM_CLOCK_CFG_MAIN_CTRL_I_0_OFFSET);
    addr_hit[ 1] = (reg_addr == SYSTEM_CLOCK_CFG_MAIN_CTRL_I_1_OFFSET);
    addr_hit[ 2] = (reg_addr == SYSTEM_CLOCK_CFG_OUT_STREAM_I_0_OFFSET);
    addr_hit[ 3] = (reg_addr == SYSTEM_CLOCK_CFG_OUT_STREAM_I_1_OFFSET);
    addr_hit[ 4] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_START_ADDR_I_0_OFFSET);
    addr_hit[ 5] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_START_ADDR_I_1_OFFSET);
    addr_hit[ 6] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_ADDR_STEP_I_0_OFFSET);
    addr_hit[ 7] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_ADDR_STEP_I_1_OFFSET);
    addr_hit[ 8] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_END_ADDR_I_0_OFFSET);
    addr_hit[ 9] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_END_ADDR_I_1_OFFSET);
    addr_hit[10] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_TRAN_SIZE_I_0_OFFSET);
    addr_hit[11] = (reg_addr == SYSTEM_CLOCK_CFG_TCDM_TRAN_SIZE_I_1_OFFSET);
    addr_hit[12] = (reg_addr == SYSTEM_CLOCK_CFG_SRAM_START_ADDR_I_0_OFFSET);
    addr_hit[13] = (reg_addr == SYSTEM_CLOCK_CFG_SRAM_START_ADDR_I_1_OFFSET);
    addr_hit[14] = (reg_addr == SYSTEM_CLOCK_CFG_SRAM_ADDR_STEP_I_0_OFFSET);
    addr_hit[15] = (reg_addr == SYSTEM_CLOCK_CFG_SRAM_ADDR_STEP_I_1_OFFSET);
    addr_hit[16] = (reg_addr == SYSTEM_CLOCK_CFG_SRAM_END_ADDR_I_0_OFFSET);
    addr_hit[17] = (reg_addr == SYSTEM_CLOCK_CFG_SRAM_END_ADDR_I_1_OFFSET);
    addr_hit[18] = (reg_addr == SYSTEM_CLOCK_STA_MAIN_STATUS_O_0_OFFSET);
    addr_hit[19] = (reg_addr == SYSTEM_CLOCK_STA_MAIN_STATUS_O_1_OFFSET);
    addr_hit[20] = (reg_addr == SYSTEM_CLOCK_CFG_FC_DIMENSION_I_OFFSET);
    addr_hit[21] = (reg_addr == SYSTEM_CLOCK_CFG_FC_OFFSET_I_OFFSET);
    addr_hit[22] = (reg_addr == SYSTEM_CLOCK_STA_TRANS_PTR_O_0_OFFSET);
    addr_hit[23] = (reg_addr == SYSTEM_CLOCK_STA_TRANS_PTR_O_1_OFFSET);
    addr_hit[24] = (reg_addr == SYSTEM_CLOCK_CFG_FC_TRAN_SIZE_I_0_OFFSET);
    addr_hit[25] = (reg_addr == SYSTEM_CLOCK_CFG_FC_TRAN_SIZE_I_1_OFFSET);
  end

  assign addrmiss = (reg_re || reg_we) ? ~|addr_hit : 1'b0 ;

  // Check sub-word write is permitted
  always_comb begin
    wr_err = 1'b0;
    if (addr_hit[ 0] && reg_we && (SYSTEM_CLOCK_PERMIT[ 0] != (SYSTEM_CLOCK_PERMIT[ 0] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 1] && reg_we && (SYSTEM_CLOCK_PERMIT[ 1] != (SYSTEM_CLOCK_PERMIT[ 1] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 2] && reg_we && (SYSTEM_CLOCK_PERMIT[ 2] != (SYSTEM_CLOCK_PERMIT[ 2] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 3] && reg_we && (SYSTEM_CLOCK_PERMIT[ 3] != (SYSTEM_CLOCK_PERMIT[ 3] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 4] && reg_we && (SYSTEM_CLOCK_PERMIT[ 4] != (SYSTEM_CLOCK_PERMIT[ 4] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 5] && reg_we && (SYSTEM_CLOCK_PERMIT[ 5] != (SYSTEM_CLOCK_PERMIT[ 5] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 6] && reg_we && (SYSTEM_CLOCK_PERMIT[ 6] != (SYSTEM_CLOCK_PERMIT[ 6] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 7] && reg_we && (SYSTEM_CLOCK_PERMIT[ 7] != (SYSTEM_CLOCK_PERMIT[ 7] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 8] && reg_we && (SYSTEM_CLOCK_PERMIT[ 8] != (SYSTEM_CLOCK_PERMIT[ 8] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[ 9] && reg_we && (SYSTEM_CLOCK_PERMIT[ 9] != (SYSTEM_CLOCK_PERMIT[ 9] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[10] && reg_we && (SYSTEM_CLOCK_PERMIT[10] != (SYSTEM_CLOCK_PERMIT[10] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[11] && reg_we && (SYSTEM_CLOCK_PERMIT[11] != (SYSTEM_CLOCK_PERMIT[11] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[12] && reg_we && (SYSTEM_CLOCK_PERMIT[12] != (SYSTEM_CLOCK_PERMIT[12] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[13] && reg_we && (SYSTEM_CLOCK_PERMIT[13] != (SYSTEM_CLOCK_PERMIT[13] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[14] && reg_we && (SYSTEM_CLOCK_PERMIT[14] != (SYSTEM_CLOCK_PERMIT[14] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[15] && reg_we && (SYSTEM_CLOCK_PERMIT[15] != (SYSTEM_CLOCK_PERMIT[15] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[16] && reg_we && (SYSTEM_CLOCK_PERMIT[16] != (SYSTEM_CLOCK_PERMIT[16] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[17] && reg_we && (SYSTEM_CLOCK_PERMIT[17] != (SYSTEM_CLOCK_PERMIT[17] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[18] && reg_we && (SYSTEM_CLOCK_PERMIT[18] != (SYSTEM_CLOCK_PERMIT[18] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[19] && reg_we && (SYSTEM_CLOCK_PERMIT[19] != (SYSTEM_CLOCK_PERMIT[19] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[20] && reg_we && (SYSTEM_CLOCK_PERMIT[20] != (SYSTEM_CLOCK_PERMIT[20] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[21] && reg_we && (SYSTEM_CLOCK_PERMIT[21] != (SYSTEM_CLOCK_PERMIT[21] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[22] && reg_we && (SYSTEM_CLOCK_PERMIT[22] != (SYSTEM_CLOCK_PERMIT[22] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[23] && reg_we && (SYSTEM_CLOCK_PERMIT[23] != (SYSTEM_CLOCK_PERMIT[23] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[24] && reg_we && (SYSTEM_CLOCK_PERMIT[24] != (SYSTEM_CLOCK_PERMIT[24] & reg_be))) wr_err = 1'b1 ;
    if (addr_hit[25] && reg_we && (SYSTEM_CLOCK_PERMIT[25] != (SYSTEM_CLOCK_PERMIT[25] & reg_be))) wr_err = 1'b1 ;
  end

  assign cfg_main_ctrl_i_0_we = addr_hit[0] & reg_we & ~wr_err;
  assign cfg_main_ctrl_i_0_wd = reg_wdata[31:0];

  assign cfg_main_ctrl_i_1_we = addr_hit[1] & reg_we & ~wr_err;
  assign cfg_main_ctrl_i_1_wd = reg_wdata[31:0];

  assign cfg_out_stream_i_0_we = addr_hit[2] & reg_we & ~wr_err;
  assign cfg_out_stream_i_0_wd = reg_wdata[31:0];

  assign cfg_out_stream_i_1_we = addr_hit[3] & reg_we & ~wr_err;
  assign cfg_out_stream_i_1_wd = reg_wdata[31:0];

  assign cfg_tcdm_start_addr_i_0_we = addr_hit[4] & reg_we & ~wr_err;
  assign cfg_tcdm_start_addr_i_0_wd = reg_wdata[31:0];

  assign cfg_tcdm_start_addr_i_1_we = addr_hit[5] & reg_we & ~wr_err;
  assign cfg_tcdm_start_addr_i_1_wd = reg_wdata[31:0];

  assign cfg_tcdm_addr_step_i_0_we = addr_hit[6] & reg_we & ~wr_err;
  assign cfg_tcdm_addr_step_i_0_wd = reg_wdata[31:0];

  assign cfg_tcdm_addr_step_i_1_we = addr_hit[7] & reg_we & ~wr_err;
  assign cfg_tcdm_addr_step_i_1_wd = reg_wdata[31:0];

  assign cfg_tcdm_end_addr_i_0_we = addr_hit[8] & reg_we & ~wr_err;
  assign cfg_tcdm_end_addr_i_0_wd = reg_wdata[31:0];

  assign cfg_tcdm_end_addr_i_1_we = addr_hit[9] & reg_we & ~wr_err;
  assign cfg_tcdm_end_addr_i_1_wd = reg_wdata[31:0];

  assign cfg_tcdm_tran_size_i_0_we = addr_hit[10] & reg_we & ~wr_err;
  assign cfg_tcdm_tran_size_i_0_wd = reg_wdata[31:0];

  assign cfg_tcdm_tran_size_i_1_we = addr_hit[11] & reg_we & ~wr_err;
  assign cfg_tcdm_tran_size_i_1_wd = reg_wdata[31:0];

  assign cfg_sram_start_addr_i_0_we = addr_hit[12] & reg_we & ~wr_err;
  assign cfg_sram_start_addr_i_0_wd = reg_wdata[31:0];

  assign cfg_sram_start_addr_i_1_we = addr_hit[13] & reg_we & ~wr_err;
  assign cfg_sram_start_addr_i_1_wd = reg_wdata[31:0];

  assign cfg_sram_addr_step_i_0_we = addr_hit[14] & reg_we & ~wr_err;
  assign cfg_sram_addr_step_i_0_wd = reg_wdata[31:0];

  assign cfg_sram_addr_step_i_1_we = addr_hit[15] & reg_we & ~wr_err;
  assign cfg_sram_addr_step_i_1_wd = reg_wdata[31:0];

  assign cfg_sram_end_addr_i_0_we = addr_hit[16] & reg_we & ~wr_err;
  assign cfg_sram_end_addr_i_0_wd = reg_wdata[31:0];

  assign cfg_sram_end_addr_i_1_we = addr_hit[17] & reg_we & ~wr_err;
  assign cfg_sram_end_addr_i_1_wd = reg_wdata[31:0];



  assign cfg_fc_dimension_i_x_dim_we = addr_hit[20] & reg_we & ~wr_err;
  assign cfg_fc_dimension_i_x_dim_wd = reg_wdata[23:16];

  assign cfg_fc_dimension_i_y_dim_we = addr_hit[20] & reg_we & ~wr_err;
  assign cfg_fc_dimension_i_y_dim_wd = reg_wdata[31:24];

  assign cfg_fc_offset_i_we = addr_hit[21] & reg_we & ~wr_err;
  assign cfg_fc_offset_i_wd = reg_wdata[31:0];



  assign cfg_fc_tran_size_i_0_we = addr_hit[24] & reg_we & ~wr_err;
  assign cfg_fc_tran_size_i_0_wd = reg_wdata[31:0];

  assign cfg_fc_tran_size_i_1_we = addr_hit[25] & reg_we & ~wr_err;
  assign cfg_fc_tran_size_i_1_wd = reg_wdata[31:0];

  // Read data return
  always_comb begin
    reg_rdata_next = '0;
    unique case (1'b1)
      addr_hit[0]: begin
        reg_rdata_next[31:0] = cfg_main_ctrl_i_0_qs;
      end

      addr_hit[1]: begin
        reg_rdata_next[31:0] = cfg_main_ctrl_i_1_qs;
      end

      addr_hit[2]: begin
        reg_rdata_next[31:0] = cfg_out_stream_i_0_qs;
      end

      addr_hit[3]: begin
        reg_rdata_next[31:0] = cfg_out_stream_i_1_qs;
      end

      addr_hit[4]: begin
        reg_rdata_next[31:0] = cfg_tcdm_start_addr_i_0_qs;
      end

      addr_hit[5]: begin
        reg_rdata_next[31:0] = cfg_tcdm_start_addr_i_1_qs;
      end

      addr_hit[6]: begin
        reg_rdata_next[31:0] = cfg_tcdm_addr_step_i_0_qs;
      end

      addr_hit[7]: begin
        reg_rdata_next[31:0] = cfg_tcdm_addr_step_i_1_qs;
      end

      addr_hit[8]: begin
        reg_rdata_next[31:0] = cfg_tcdm_end_addr_i_0_qs;
      end

      addr_hit[9]: begin
        reg_rdata_next[31:0] = cfg_tcdm_end_addr_i_1_qs;
      end

      addr_hit[10]: begin
        reg_rdata_next[31:0] = cfg_tcdm_tran_size_i_0_qs;
      end

      addr_hit[11]: begin
        reg_rdata_next[31:0] = cfg_tcdm_tran_size_i_1_qs;
      end

      addr_hit[12]: begin
        reg_rdata_next[31:0] = cfg_sram_start_addr_i_0_qs;
      end

      addr_hit[13]: begin
        reg_rdata_next[31:0] = cfg_sram_start_addr_i_1_qs;
      end

      addr_hit[14]: begin
        reg_rdata_next[31:0] = cfg_sram_addr_step_i_0_qs;
      end

      addr_hit[15]: begin
        reg_rdata_next[31:0] = cfg_sram_addr_step_i_1_qs;
      end

      addr_hit[16]: begin
        reg_rdata_next[31:0] = cfg_sram_end_addr_i_0_qs;
      end

      addr_hit[17]: begin
        reg_rdata_next[31:0] = cfg_sram_end_addr_i_1_qs;
      end

      addr_hit[18]: begin
        reg_rdata_next[31:0] = sta_main_status_o_0_qs;
      end

      addr_hit[19]: begin
        reg_rdata_next[31:0] = sta_main_status_o_1_qs;
      end

      addr_hit[20]: begin
        reg_rdata_next[23:16] = cfg_fc_dimension_i_x_dim_qs;
        reg_rdata_next[31:24] = cfg_fc_dimension_i_y_dim_qs;
      end

      addr_hit[21]: begin
        reg_rdata_next[31:0] = cfg_fc_offset_i_qs;
      end

      addr_hit[22]: begin
        reg_rdata_next[31:0] = sta_trans_ptr_o_0_qs;
      end

      addr_hit[23]: begin
        reg_rdata_next[31:0] = sta_trans_ptr_o_1_qs;
      end

      addr_hit[24]: begin
        reg_rdata_next[31:0] = cfg_fc_tran_size_i_0_qs;
      end

      addr_hit[25]: begin
        reg_rdata_next[31:0] = cfg_fc_tran_size_i_1_qs;
      end

      default: begin
        reg_rdata_next = '1;
      end
    endcase
  end

  // Assertions for Register Interface

  `ASSERT(en2addrHit, (reg_we || reg_re) |-> $onehot0(addr_hit))


endmodule