/* -------------------------------------------------------------------------------
 * (C)2012 Korotkyi Ievgen
 * National Technical University of Ukraine "Kiev Polytechnic Institute"
 * -------------------------------------------------------------------------------
 *
 * Uniform random traffic testbench
 * 
 * Instantiates network and random traffic sources
 * 
 */

`timescale 1 ps/ 1 ps

`include "types.v"
`include "LAG_functions.v"
`include "parameters.v"

module LAG_test_random ();

   //`include "parameters.v"

   parameter CLOCK_PERIOD = 8_000;

   flit_t [network_x-1:0][network_y-1:0] flit_in_;
   flit_t [network_x-1:0][network_y-1:0][router_num_pls_on_exit-1:0] flit_out_;
   logic [network_x-1:0][network_y-1:0][router_num_pls_on_entry-1:0] input_full_flag_;
   chan_cntrl_t [network_x-1:0][network_y-1:0] cntrl_in_;
   
   logic    [network_x*network_y*$bits(chan_cntrl_t) - 1 : 0] cntrl_in; 
   logic    [network_x*network_y*$bits(flit_t) - 1 : 0] flit_in;
   logic    [network_x*network_y*router_num_pls_on_exit*$bits(flit_t) - 1 : 0] flit_out;
   logic    [network_x*network_y*router_num_pls_on_entry - 1 : 0] input_full_flag;
   
   integer rec_count [network_x-1:0][network_y-1:0];
   sim_stats_t stats [network_x-1:0][network_y-1:0];

   real    av_lat[network_x-1:0][network_y-1:0];
   
   genvar  x,y,c;
   integer i,j,k;
   integer sys_time, total_packets, total_hops, min_latency, max_latency, total_latency;
   integer min_hops, max_hops;
   integer total_rec_count;

   integer total_lat_for_hop_count [(network_x+network_y):0];
   integer total_packets_with_hop_count[(network_x+network_y):0];
   integer hc_total_packets, hc_total_latency;
   
   integer lat_freq[100:0];
   
   logic clk, rst_n;
   
   generate
   
   for (y=0; y<network_y; y=y+1) begin:ycg
      for (x=0; x<network_x; x=x+1) begin:xcg
   
       assign flit_in[$bits(flit_t)*(x*network_y + y + 1) - 1 : $bits(flit_t)*(x*network_y + y)] = flit_in_[x][y];
       
       for (c=0; c<router_num_pls_on_exit; c++) begin:network_out_to_sink
        assign flit_out_[x][y][c] = flit_out[$bits(flit_t)*(x*network_y*router_num_pls_on_exit + y*router_num_pls_on_exit + c + 1) - 1 : $bits(flit_t)*(x*network_y*router_num_pls_on_exit + y*router_num_pls_on_exit + c)];
       end
       
       assign cntrl_in[$bits(chan_cntrl_t)*(x*network_y + y + 1) - 1 : $bits(chan_cntrl_t)*(x*network_y + y)] = cntrl_in_[x][y]; 
       assign input_full_flag_[x][y] = input_full_flag[router_num_pls_on_entry*(x*network_y + y + 1) - 1 : router_num_pls_on_entry*(x*network_y + y)];
      
      end
   end
   
   endgenerate
   
   
   // clock generator
   /*initial begin
      clk=0;
   end
   always #(CLOCK_PERIOD/2) clk = ~clk;    */
   
    initial begin
      clk <= 0;
      forever #(CLOCK_PERIOD/2) clk <= ~clk;
    end 

   always@(posedge clk) begin
      if (!rst_n) begin
	 sys_time=0;
      end else begin
	 sys_time++;
      end

      /*
      for (i=0; i<xdim; i++) begin
	 for (j=0; j<network_y; j++) begin
	    $write ("%b", input_full_flag[i][j]);
	 end
      end
      $display ("");
       */
   end
   
   // ########################
   // Network
   // ########################

   LAG_mesh_network network (flit_in, flit_out,
	                           input_full_flag,
	                           cntrl_in,
	                           clk, rst_n);
   
   // ########################
   // Traffic Sources
   // ########################
   generate
      for (x=0; x<network_x; x++) begin:xl
	 for (y=0; y<network_y; y++) begin:yl

	    LAG_random_traffic_source #(.nv(router_num_pls_on_entry), 
				       .xdim(network_x), .ydim(network_y), .xpos(x), .ypos(y),
				       .packet_length(sim_packet_length),
				       .rate(sim_injection_rate)
				       )
	      traf_src (.flit_out(flit_in_[x][y]), 
			.network_ready(~input_full_flag_[x][y]), 
			.clk, .rst_n);
	 end
      end
   endgenerate

   // ########################
   // Traffic Sinks
   // ########################
   generate
      for (x=0; x<network_x; x++) begin:xl2
	 for (y=0; y<network_y; y++) begin:yl2

	    LAG_traffic_sink #(.xdim(network_x), .ydim(network_y), .xpos(x), .ypos(y),
			      .warmup_packets(sim_warmup_packets), .measurement_packets(sim_measurement_packets),
			      .router_num_pls_on_exit(router_num_pls_on_exit))
	      traf_sink (.flit_in(flit_out_[x][y]), 
			 .cntrl_out(cntrl_in_[x][y]), 
			 .rec_count(rec_count[x][y]), 
			 .stats(stats[x][y]), 
			 .clk, .rst_n);
	    
	 end
      end
   endgenerate


   //
   // All measurement packets must be received before we end the simulation
   // (this includes a drain phase)
   //
   always@(posedge clk) begin
      total_rec_count=0;
      for (i=0; i<network_x; i++) begin
	 for (j=0; j<network_y; j++) begin
	    total_rec_count=total_rec_count+rec_count[i][j];
	 end
      end
   end
   
   initial begin
      
      `ifdef DUMPTRACE      
        $dumpfile ("wave.pld");
        $dumpvars (4);
      `endif      

      $display ("*******************************************************");
      $display ("* Wormhole NoC with LAG - Uniform Random Traffic Test *");
      $display ("*******************************************************");

      total_hops=0;
      total_latency=0;
      
      //
      // reset
      //
      rst_n=0;
      // reset
      repeat(20) @(negedge clk);
      
      rst_n=1;

      $display ("-- Reset Complete");
      $display ("-- Entering warmup phase (%1d packets per node)", sim_warmup_packets);

      
      // #################################################################
      // wait for all traffic sinks to rec. all measurement packets
      // #################################################################
      wait (total_rec_count==sim_measurement_packets*network_x*network_y);
      
      $display ("** Simulation End **\n");

      total_packets = sim_measurement_packets*network_x*network_y;

      min_latency=stats[0][0].min_latency;
      max_latency=stats[0][0].max_latency;
      min_hops=stats[0][0].min_hops;
      max_hops=stats[0][0].max_hops;

      for (i=0; i<network_x; i++) begin
	 for (j=0; j<network_y; j++) begin
	    av_lat[i][j] = $itor(stats[i][j].total_latency)/$itor(rec_count[i][j]);
	    
	    total_latency = total_latency + stats[i][j].total_latency;
	    
	    total_hops=total_hops+stats[i][j].total_hops;

	    min_latency = min(min_latency, stats[i][j].min_latency);
	    max_latency = max(max_latency, stats[i][j].max_latency);

	 end
      end


      
      for (k=0; k<=100; k++) lat_freq[k]=0;
      
      for (i=0; i<network_x; i++) begin
	 for (j=0; j<network_y; j++) begin	    
	    for (k=0; k<=100; k++) begin
	       lat_freq[k]=lat_freq[k]+stats[i][j].lat_freq[k];
	    end
	 end
      end

      $display ("***********************************************************************************");
      $display ("-- Channel Latency = %1d", channel_latency);
      $display ("***********************************************************************************");
      $display ("-- Packet Length   = %1d", sim_packet_length);
      $display ("-- Injection Rate  = %1.4f (flits/cycle/node)", sim_injection_rate);
      $display ("-- Average Latency = %1.2f (cycles)", $itor(total_latency)/$itor(total_packets));
      $display ("-- Min. Latency    = %1d, Max. Latency = %1d", min_latency, max_latency);
      $display ("-- Average no. of hops taken by packet = %1.2f hops (min=%1d, max=%1d)", 
		$itor(total_hops)/$itor(total_packets), min_hops, max_hops);
      $display ("***********************************************************************************");

      $display ("\n");
      $display ("Average Latencies for packets rec'd at nodes [x,y] and (no. of packets received)");
      for (i=0; i<network_x; i++) begin
	 for (j=0; j<network_y;j++) $write ("%1.2f (%1d)\t", av_lat[i][j], rec_count[i][j]);
	 $display ("");
      end

      $display ("Flits/cycle received at each node: (should approx. injection rate)");
      for (i=0; i<network_x; i++) begin
	 for (j=0; j<network_y; j++) begin
	    $write ("%1.2f\t", $itor(stats[i][j].flit_count)/$itor(stats[i][j].measure_end-stats[i][j].measure_start));
	 end
	 $display ("");
      end
      
      $display ("");
      $display ("Distribution of packet latencies: ");
      $display ("Latency : Frequency (as percentage of total)");
      $display ("-------------------");
      for (k=0; k<100; k++) begin
	 $display ("%1d %1.2f", k, $itor(lat_freq[k]*100)/$itor(total_packets));
      end
      $display ("100+ %1.2f", $itor(lat_freq[k]*100)/$itor(total_packets));
      
      $finish;
   end
   
endmodule // LAG_test_random
