/* -------------------------------------------------------------------------------
 * (C)2012 Korotkyi Ievgen
 * National Technical University of Ukraine "Kiev Polytechnic Institute"
 * -------------------------------------------------------------------------------
 *
 *   *** NOT FOR SYNTHESIS ***
 * 
 * Traffic Sink
 * 
 * Collects incoming packets and produces statistics. 
 * 
 *  - check flit id's are sequential
 * 
 */
//`include "parameters.v"

`timescale 1 ps/ 1 ps

`include "types.v"
`include "LAG_functions.v"
`include "parameters.v"

module LAG_traffic_sink (flit_in, cntrl_out, rec_count, stats, clk, rst_n);
   
   parameter xdim = 4;
   parameter ydim = 4; 
   
   parameter xpos = 0;
   parameter ypos = 0;

   parameter warmup_packets = 100;
   parameter measurement_packets = 1000;

   parameter router_num_pls_on_exit = 1;
   
   input     flit_t [router_num_pls_on_exit-1:0] flit_in;
   output    chan_cntrl_t cntrl_out;
   output    sim_stats_t stats;
   input     clk, rst_n;
   output    integer rec_count;

   logic [7:0]   expected_flit_id [router_num_pls_on_exit-1:0];   //in test version our packets is only 255 flit length
   logic [15:0]  expected_packet_id[router_num_pls_on_exit-1:0];
   logic [15:0]  arrived_packet_id[router_num_pls_on_exit-1:0];
   
   logic [31:0]   head_injection_time [router_num_pls_on_exit-1:0];
   
   logic [31:0]   latency, sys_time;
   
   logic [31:0]   crc_computed [router_num_pls_on_exit-1:0];
   logic [31:0]   crc_received [router_num_pls_on_exit-1:0];
   
   integer   j, i;
   integer   error_count;
   
   genvar ch;
    
   
   for (ch=0; ch<router_num_pls; ch++) begin:flow_control
    always@(posedge clk) begin
      if (!rst_n) begin	   
        cntrl_out.credits[ch] <= 0;	 
      end else begin
        if (flit_in[ch].control.valid) begin
          if (ch < router_num_pls_on_exit) begin
            cntrl_out.credits[ch] <= 1;
          end else begin
            $display ("%m: Error: Flit Channel ID is out-of-range for exit from network!");
	          $display ("Channel ID = %1d (router_num_pls_on_exit=%1d)", ch, router_num_pls_on_exit);
	          $finish;
          end
        end else begin
          cntrl_out.credits[ch] <= 0;
        end
      end
    end   
   end

   
   always@(posedge clk) begin
      if (!rst_n) begin
	   
         rec_count=0;
      	 stats.total_latency=0;
      	 stats.total_hops=0;
      	 stats.max_hops=0;
      	 stats.min_hops=MAXINT;
      	 stats.max_latency=0;
      	 stats.min_latency=MAXINT;
      	 stats.measure_start=-1;
      	 stats.measure_end=-1;
      	 stats.flit_count=0;
      	 
      	 error_count = 0;
  	 
         for (j=0; j<router_num_pls_on_exit; j++) begin
      	    expected_flit_id[j]=1;
      	    expected_packet_id[j]=1;
      	    head_injection_time[j]='0;
      	    crc_computed[i] = '0;
      	    crc_received[i] = '0;
      	 end
      
      	 for (j=0; j<=100; j++) begin
      	    stats.lat_freq[j]=0;
      	 end
	 
	       sys_time = 0;
	 
      end else begin // if (!rst_n)
	 
        #3000 sys_time++;
	 
	   for (i=0; i<router_num_pls_on_exit; i++) begin
	 if (flit_in[i].control.valid) begin
      
      //
	    // check flits for each packet are received in order
	    //
	    
      if(~flit_in[i].control.head && expected_flit_id[i] != flit_in[i].data[7:0]) begin
        error_count++;
        $display("%m Error: flit out of sequence.");
        $display("-- Flit ID = %1d, Expected = %1d", flit_in[i].data[7:0], expected_flit_id[i]);                               
      end
      
      /*$display($time, " ----> Flit %d is received in x[%1d]y[%1d], ch=%1d", flit_in[i].data[7:0], xpos, ypos, i);
      $display("****************************************************************************"); */
	      
      if(expected_flit_id[i] > 1 && expected_flit_id[i] < 9) crc_computed[i] = crc32(flit_in[i].data, crc_computed[i]);
            
      if(expected_flit_id[i] == 1) begin
      
      if(~flit_in[i].control.head) begin
        error_count++;
        $display("%m Error: flit out of sequence. Expected 1st flit");
      end
      
      head_injection_time[i] = '0;
      
      expected_flit_id[i]++;
      
      end else if (expected_flit_id[i] == 2) begin
        arrived_packet_id[i][7:0] = flit_in[i].data[15:8];
        expected_flit_id[i]++;
        
      end else if (expected_flit_id[i] == 3) begin
        arrived_packet_id[i][15:8] = flit_in[i].data[15:8];
        
        if ((arrived_packet_id[i] > warmup_packets) && (stats.measure_start==-1))  stats.measure_start = sys_time - 2;
      
        expected_flit_id[i]++;
      end else if (expected_flit_id[i] == 4) begin
      
        if(xpos != flit_in[i].data[11:8] && ypos != flit_in[i].data[15:12] )begin
          error_count++;
          $display("Packet arrived at wrong destination");
        end
      
        expected_flit_id[i]++;
      end else if (expected_flit_id[i] == 5) begin
        head_injection_time[i][7:0] = flit_in[i].data[15:8];
      
        expected_flit_id[i]++;
      end else if (expected_flit_id[i] == 6) begin
        head_injection_time[i][15:8] = flit_in[i].data[15:8];
      
        expected_flit_id[i]++;
      end else if (expected_flit_id[i] == 7) begin
        head_injection_time[i][23:16] = flit_in[i].data[15:8];
      
        expected_flit_id[i]++;
      end else if (expected_flit_id[i] == 8) begin      
        head_injection_time[i][31:24] = flit_in[i].data[15:8];
        expected_flit_id[i]++;
      
      end else if (expected_flit_id[i] == 9) begin
        crc_received[i][7:0] = flit_in[i].data[15:8];
        expected_flit_id[i]++;
      
      end else if (expected_flit_id[i] == 10) begin
        crc_received[i][15:8] = flit_in[i].data[15:8];
        expected_flit_id[i]++;
      
      end else if (expected_flit_id[i] == 11) begin
        crc_received[i][23:16] = flit_in[i].data[15:8];
        expected_flit_id[i]++;
      
      end else if (expected_flit_id[i] == 12) begin   //last (tail) flit
        crc_received[i][31:24] = flit_in[i].data[15:8];
      
        if (crc_received[i] != crc_computed[i]) begin
          error_count++;
          
          $display("%m Error: checksum do not match");
          $display("--------> crc_computed = %h, crc_received = %h", crc_computed[i], crc_received[i]);
          $finish;
        end else begin
       
       /*$display($time, " ---------> Packet is received in x[%1d]y[%1d], ch=%1d", xpos, ypos, i);
       $display("****************************************************************************"); */
       
        end
        
       crc_computed[i] = '0;
       crc_received[i] = '0;
      
        expected_flit_id[i] = 1;
        expected_packet_id[i]++;
        
       //----------> count statistics
        
        if ((arrived_packet_id[i] > warmup_packets) &&
		   (arrived_packet_id[i] <= warmup_packets + measurement_packets)) begin

		  rec_count++;

		  // time last measurement packet was received
		  stats.measure_end = sys_time;
		  
		  //
		  // gather latency stats.
		  //
		  latency = sys_time - head_injection_time[i]; 
		  
      stats.total_latency = stats.total_latency + latency;

		  stats.min_latency = min (stats.min_latency, latency);
		  stats.max_latency = max (stats.max_latency, latency);
		  
		  //
		  // display progress estimate
		  //
		  if (rec_count%(measurement_packets/100)==0) 
		    $display ("%1d: %m: %1.2f%% complete (this packet's latency was %1d)", sys_time, 
			      $itor(rec_count*100)/$itor(measurement_packets),
			      latency);
		  
		  //
		  // bin latencies
		  //	
		  stats.lat_freq[min(latency, 100)]++;
	       end
	       
      end	    
	    
	    if(error_count) begin
	      $display("At least %1d errors occured during simulation", error_count);
	      $finish;
	    end
	    
	    // count all flits received in measurement period
      if (arrived_packet_id[i] <= warmup_packets + measurement_packets)
	      if (stats.measure_start!=-1) stats.flit_count++;

	    
	 end // if flit valid
	 end //for
      end  //if(!rst_n)
   end //always
   
endmodule
