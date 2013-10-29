
/* -------------------------------------------------------------------------------
 * (C)2007 Robert Mullins
 * Computer Architecture Group, Computer Laboratory
 * University of Cambridge, UK.
 * -------------------------------------------------------------------------------
 * 
 * Type definitions
 * 
 * 'flit_t' gets defined here
 * 
 */

//
// `defines are read from defines.v (generated from configuration file)
//

`ifndef __TYPES_V__
`define __TYPES_V__

`include "defines.v"
`include "parameters.v"

`timescale 1ps/1ps

typedef logic [router_radix-1:0] output_port_t;
typedef logic [router_num_pls-1:0] pl_t;
typedef logic [channel_data_width-1:0] data_t;

// could save one bit here
typedef logic signed [`X_ADDR_BITS:0] x_displ_t;
typedef logic signed [`Y_ADDR_BITS:0] y_displ_t;

typedef struct packed 
	{
	 pl_t credits;

	 } chan_cntrl_t;

typedef struct packed
	{
	 logic measure;        // 1 - include in statistics? (else 0 - warmup or drain phase)
	 integer flit_id;      // sequential flit id.
	 integer packet_id;    // sequential (for a particular source node) packet id.
	 integer inject_time;  // time flit entered source FIFO
	 
	 integer hops;         // no. of routers flit traverses on journey
	 
	 integer xdest, ydest; // final destination
	 integer xsrc, ysrc;   // where was packet sent from
	 
	 } debug_flit_t;

typedef struct packed
	{
	 logic valid;	   
	 logic tail;
   logic head;	 
	 } control_flit_t;
   
typedef struct packed
	{
	 data_t data;
	 control_flit_t control;
`ifdef DEBUG
	 debug_flit_t debug;
`endif
	 } flit_t;

typedef flit_t fifo_elements_t;


// port ids for 5 port router (input or output)
`define port5id_north 5'b00001
`define port5id_east  5'b00010
`define port5id_south 5'b00100
`define port5id_west  5'b01000
`define port5id_tile  5'b10000

`define NORTH 0
`define EAST  1
`define SOUTH 2
`define WEST  3
`define TILE  4

// arrays of struct with real numbers are not supported by SystemVerilog?
   
typedef struct packed
  {
    integer total_latency;
    integer total_hops;
    integer min_latency, max_latency;
    integer min_hops, max_hops;

   // start and end of measurement period
    integer measure_start, measure_end, flit_count; 
   
   // record frequency of different packet latencies
    logic [100:0][31:0] lat_freq;
   
   } sim_stats_t;

parameter MAXINT = 2^32-1;

`endif