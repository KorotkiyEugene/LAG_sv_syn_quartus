/* -------------------------------------------------------------------------------
 * (C)2012 Korotkyi Ievgen
 * National Technical University of Ukraine "Kiev Polytechnic Institute"
 * -------------------------------------------------------------------------------
 *
 *  *** NOT FOR SYNTHESIS ***
 * 
 * Random Packet Source for Open-Loop Measurement (see Dally/Towles p.450 and p.488)
 * 
 * - The injection time appended to packets is independent of activity in the network.
 *
 * - The random packet injection process is not paused while a packet is written to the
 *   input FIFO (which may take a number of cycles). If a new packet is generated 
 *   during this time it is copied to the FIFO as soon as possible.
 * 
 */

`timescale 1 ps/ 1 ps

`include "types.v"
`include "LAG_fifo_.v"
`include "LAG_route_.v"
`include "LAG_functions.v"

module LAG_random_traffic_source(flit_out, network_ready, clk, rst_n);

   parameter nv = 4; // number of virtual-channels available on entry to network
   
   parameter xdim = 4; // mesh network size
   parameter ydim = 4;
   parameter xpos = 0; // random source is connected to which router in mesh?
   parameter ypos = 0;
   parameter packet_length = 3;
   parameter rate = 0.1234; // flit injection rate (flits/cycle/random source)

   //
   // set flit priority prior to injection
   //
   // 1. by flit id (e.g. head lowest priority, tail highest)
   // 2. by journey length
   // 3....
   //
   parameter priority_switch_alloc_byflitid = 0;
   parameter priority_switch_alloc_byjourneylength = 0;
   // add the following parameter to 'flit_priority' field, if packet is a single flit packet
   parameter priority_singleflitpacketboost = 0;
   
   parameter fixed_length = 1;
   
   // if packetAB=1, a mixture of two packet lengths is generated
   //    packets of type A: length=packetA_length, probability = packetA_prob
   //    packets of type B: length=packetB_length, probability = 1-packetA_prob
   parameter packetAB = 0;
   parameter packetA_length = 1;
   parameter packetA_prob = 0.67;
   parameter packetB_length = 5;
   parameter packetB_prob = (1-packetA_prob);
   parameter packetAB_av_length = ((packetA_length*packetA_prob)+(packetB_length*packetB_prob));
   parameter pAB = 10000*rate/packetAB_av_length;

   parameter p = (packetAB) ? pAB : (10000*rate/packet_length);
   
   parameter flit_count_width = 8; //clogb2(packet_length + 1);
   parameter inject_count_width = 16;

//   parameter p = 10000*rate/packet_length;

   output flit_t flit_out;
   input [nv-1:0] network_ready;
   input clk, rst_n;

//==========
   
   integer seed;
    
   flit_t flit_out_; 
    
   logic [flit_count_width - 1:0] flit_count; //in test version we decide use 8 bit flit count
   logic [inject_count_width - 1:0] inject_count;
   logic [31:0] sys_time, i_time, i_time_tmp;
   
   logic   fifo_ready;
   
   logic   push, pop;
   flit_t data_in, data_out, routed, d;
   fifov_flags_t fifo_flags;
   logic   fifo_empty;
   
   integer xdest, ydest;

   integer injecting_packet;

   integer flits_buffered, flits_sent;

   integer length, len_sum, r;

   integer current_pl, blocked;
   
   logic [31:0] crc;
     
   //
   // FIFO connected to network input 
   //
   LAG_fifo_v_ #(.size(2+packet_length*4))
     source_fifo
       (.push(push),
	// dequeue if network was ready and fifo had a flit
	.pop(!fifo_flags.empty && network_ready[current_pl]),  
	.data_in(data_in), 
	.data_out(data_out),
	.flags(fifo_flags), .clk, .rst_n);
   
   LAG_route_ rfn (.flit_in(data_out), .flit_out(routed), .clk, .rst_n);
   
   always_comb
     begin
  if (data_out.control.head) begin  
	  flit_out_ = routed;
	end else begin
    flit_out_ = data_out;
  end  
  
	//flit_out_.control.valid = network_ready[current_pl] && !fifo_flags.empty;
     end
     
     
   always @(flit_out_) begin 
      flit_out.data <= #3000 flit_out_.data;
      flit_out.control.head <= #3000 flit_out_.control.head;
      flit_out.control.tail <= #3000 flit_out_.control.tail;
   end
   
   always @(fifo_flags.empty) begin
       fifo_empty <= #3000 fifo_flags.empty;
   end
   
   always @(network_ready[current_pl] or fifo_empty) begin
      flit_out.control.valid <= network_ready[current_pl] && !fifo_empty;  
   end
   
   //
   // Generate and Inject Packets at Random Intervals to Random Destinations
   //
   always@(posedge clk) begin
      if (!rst_n) begin

   i_time_tmp = 0;

	 current_pl=0;
	 
	 flits_buffered=0;
	 flits_sent=0;
	 
	 injecting_packet=0;
	 sys_time=0;
	 i_time=0;
	 inject_count=0;
	 flit_count=0;

	 fifo_ready=1;

	 push=0;
	 
	 crc = '0;
	 
      end else begin

	 if (network_ready[current_pl]===1'bx) begin
	    $write ("Error: network_ready=%b", network_ready[current_pl]);
	    $finish;
	 end

	 if (!fifo_flags.empty && network_ready[current_pl]) flits_sent++;
	 if (push) flits_buffered++;
	 
	 //
	 // start buffering next flit when there is room in FIFO
	 //
	 if ( ( flits_buffered - flits_sent ) <= packet_length ) begin
	    fifo_ready = 1;
	 end

	 if (fifo_ready) begin
	    while ((i_time!=sys_time)&&(injecting_packet==0)) begin
	       
	       // **********************************************************
	       // Random Injection Process
	       // **********************************************************
	       // (1 and 10000 are possible random values)
	       if ($dist_uniform(seed, 1, 10000)<= p) begin
		  injecting_packet++;
	       end
	       
	       i_time++;

	    end // while (!injecting_packet && (i_time!=sys_time))
	 end

	 if (injecting_packet && !fifo_ready) begin
	    assert (flit_count==0) else $fatal;
	 end
	 
	 if (fifo_ready && injecting_packet) begin

	    // random source continues as we buffer flits in FIFO 
	    if ($dist_uniform(seed, 1, 10000)<=p) begin
	       injecting_packet++;
	    end
	    i_time++;
	    
	    flit_count++;
	    
	    push<=1'b1;

	    //
	    // Send Head Flit
	    //
	      
	    if (flit_count == 1) begin
	     
	       d = '0;
	       crc = '0;
	       
	       inject_count++;
	       
	       i_time_tmp = i_time;
	       
	       //
	       // set random displacement to random destination
	       //
	       xdest = $dist_uniform (seed, 0, xdim-1);
	       ydest = $dist_uniform (seed, 0, ydim-1);
	       while ((xpos==xdest)&&(ypos==ydest)) begin
		  // don't send to self...
		  xdest = $dist_uniform (seed, 0, xdim-1);
		  ydest = $dist_uniform (seed, 0, ydim-1);
	       end
	       
	       d.data[router_radix + `X_ADDR_BITS : router_radix] = x_displ_t'(xdest-xpos);
	       d.data[router_radix + `X_ADDR_BITS + `Y_ADDR_BITS + 1 : router_radix + `X_ADDR_BITS + 1] = y_displ_t'(ydest-ypos);
	       d.control.head = 1'b1;
	       
	    end else if(flit_count == 2) begin
	    
        d.control.head = 1'b0;
        
        d.data[7:0] = flit_count;//flit number
        d.data[15:8] = inject_count[7:0]; //low 8 bits of packet number
      
      end else if(flit_count == 3) begin
	    
        d.data[7:0] = flit_count;//flit number
        d.data[15:8] = inject_count[15:8]; //high 8 bits of packet number
        
	    end else if(flit_count == 4) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[11:8] = xdest[3:0];  //x destination address
        d.data[15:12] = ydest[3:0]; //y destination address
        
	    end else if(flit_count == 5) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = i_time_tmp[7:0]; //low 8 bits of ingection time
        
	    end else if(flit_count == 6) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = i_time_tmp[15:8]; 
        
	    end else if(flit_count == 7) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = i_time_tmp[23:16]; 
        
	    end else if(flit_count == 8) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = i_time_tmp[31:24];
        
	    end else if(flit_count == 9) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = crc[7:0];
        
	    end else if(flit_count == 10) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = crc[15:8];
        
	    end else if(flit_count == 11) begin
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = crc[23:16];
        
	    end else if(flit_count == 12) begin
	    
	      //tail flit
	    
	      d.data[7:0] = flit_count;//flit number
        d.data[15:8] = crc[31:24];
        
        d.control.tail = 1'b1;
	       
	      injecting_packet--;	       
	      flit_count=0; 
	      
	      fifo_ready = 0;
	      
	      /*$display($time, " ---------> Packet injected into fifo");
	      $display("Packet destined from x[%1d]y[%1d] to x[%1d]y[%1d]", xpos, ypos, xdest, ydest);
	      $display("****************************************************************************");   */
	      
	    end
	    
	    /*$display($time, " -----> Flit %1d is injected into fifo", flit_count);
	    $display("Flit destined from x[%1d]y[%1d] to x[%1d]y[%1d]", xpos, ypos, xdest, ydest);
	    $display("****************************************************************************");  */
	    
	    if(flit_count < 9 && flit_count > 1) crc = crc32(d.data, crc);
	    
	 end else begin // if (injecting_packet)
	    push <= 1'b0;
	 end
	 
	 sys_time++;
	 
	 data_in <= d;
	 
      end // else: !if(!rst_n)
   end

   initial begin
      // we don't want any traffic sources to have the same 
      // random number seed!
      seed = xpos*50+ypos;
      len_sum=0;
      r= $dist_uniform(seed, 1, 10000);
      r= $dist_uniform(seed, 1, 10000);

      if ((xpos==0)&&(ypos==0)) begin
	 if (packetAB) begin
	    $display ("-- Random Traffic Source with two packet lengths:");
	    $display ("-- Packet Length A = %1d, with probability %1.2f", packetA_length, packetA_prob);
	    $display ("-- Packet Length B = %1d, with probability %1.2f", packetB_length, packetB_prob);
	 end
      end
   end
   
endmodule // LAG_random_source
