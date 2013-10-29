/* -------------------------------------------------------------------------------
 * (C)2012 Korotkyi Ievgen
 * National Technical University of Ukraine "Kiev Polytechnic Institute"
 * -------------------------------------------------------------------------------
 * 
 * PL router
 * 
 */

module LAG_router (i_flit_in, i_flit_out,
		     i_cntrl_in, i_cntrl_out,
		     i_input_full_flag, 
		     clk, rst_n);

   `include "LAG_functions.v"
   
   parameter network_x = 4;
   parameter network_y = 4;
   
   parameter buf_len = 4;
   parameter NT=5;
   parameter NPL=4;
   
   parameter alloc_stages = 1;

   // numbers of virtual-channels on entry/exit to network?
   parameter router_num_pls_on_entry = 1;
   parameter router_num_pls_on_exit = 1;

   //
   // PL Allocation
   //
   parameter plalloc_unrestricted=0;

   //
   // PL Selection
   //
   parameter plselect_bydestinationnode = 0;
   parameter plselect_leastfullbuffer = 0;
   parameter plselect_arbstateupdate = 0;   
   parameter plselect_usepacketmask = 0;    
   parameter plselect_onlywhenempty = 0;
   
   //
   // Prioritised Communications
   //

   // prioritise switch allocation by position of flit in packet (head=0, tail=N)
   parameter priority_switch_alloc_byflitid=0;
   
   // prioritise switch allocation based on flit.control.flit_priority
   parameter priority_flit_dynamic_switch_alloc=0;
   // prioritise pl allocation based on flit.control.flit_priority
   parameter priority_flit_dynamic_pl_alloc=0;
   // size of flit.control.flit_priority field (in bits)
   parameter priority_flit_bits=4;
   //
   // prioritise_network_traffic = 0 - no modifications to flit_priority are made by the router
   // prioritise_network_traffic = 1 - router sets flit_priority to 1 on exit, traffic in network has
   //                                  priority over newly injected traffic
   // prioritise_network_traffic = 2 - flit_priority is increased at each router as the flit exists
   //                                  flit_priority is determined by its current hop count
   //                                  (be careful to ensure enough priority bits are available)
   //                                  Upto a limit of 'priority_flit_limit'   
   parameter priority_network_traffic=0;
   parameter priority_flit_limit=4;

//==================================================================

   // FIFO rec. data from tile/core is full?
   output  [router_num_pls_on_entry-1:0] i_input_full_flag;
   // link data and control
   input   flit_t i_flit_in [NT-1:0][NPL-1:0];
   output  flit_t i_flit_out [NT-1:0][NPL-1:0];
   input   chan_cntrl_t i_cntrl_in [NT-1:0];
   output  chan_cntrl_t i_cntrl_out [NT-1:0];
   input   clk, rst_n;
    
   logic [NT-1:0][NPL-1:0] x_pl_status;
   
   logic [NT-1:0][NPL-1:0] x_push;
   logic [NT-1:0][NPL-1:0] x_pop;
   
   flit_t x_flit_xbarin [NT-1:0][NPL-1:0];
   flit_t x_flit_xbarout [NT-1:0][NPL-1:0];
   
   flit_t x_flit_xbarin_ [NT*NPL-1:0];
   flit_t x_flit_xbarout_ [NT*NPL-1:0];
   
   flit_t routed [NT-1:0][NPL-1:0];
   
   logic [NT-1:0][NPL-1:0] flits_out_tail; 
   logic [NT-1:0][NPL-1:0] flits_out_valid;    //for any output channel of each output port

   fifov_flags_t x_flags [NT-1:0][NPL-1:0];
   logic [NPL-1:0] 	  x_allocated_pl [NT-1:0][NPL-1:0];
   logic [NT-1:0][NPL-1:0] x_allocated_pl_valid;   
   logic [NT-1:0][NPL-1:0][NPL-1:0] x_pl_new;
   logic [NT-1:0][NPL-1:0] 	  x_pl_new_valid;
   output_port_t x_output_port [NT-1:0][NPL-1:0];
   output_port_t x_output_port_reg [NT-1:0][NPL-1:0];
  
   pl_t [NT-1:0] x_free_pl;                             //??? delete
   logic [NT*NPL-1:0][NT*NPL-1:0] xbar_select; 
   logic [NT-1:0][NPL-1:0] pl_request;             // PL request from each input PL
   logic [NT-1:0] 	 pl_allocated_at_output;            // ??? delete
   logic [NT-1:0][NPL-1:0] allocated_pl_blocked;  
   
   logic [NT-1:0][NPL-1:0]   output_used; // output channel used on this cycle?
   logic [NT-1:0][NPL-1:0][NT-1:0][NPL-1:0]   output_used_;
 
   flit_t flit_buffer_out [NT-1:0][NPL-1:0];
   
   //
   // unrestricted PL free pool/allocation
   //
   logic [NT-1:0][NPL-1:0] pl_alloc_status;         // which output PLs are free to be allocated
   logic [NT-1:0][NPL-1:0] pl_allocated;            // indicates which PLs were allocated on this clock cycle
   
   //
   logic [NT-1:0][NPL-1:0] 	  pl_empty;        // is downstream FIFO associated with PL empty?
   
   genvar 		  i,j,k,l;

   integer db_out_used, db_in_popped, p,v;
   
   // *******************************************************************************
   // output ports
   // *******************************************************************************
   generate
   for (i=0; i<NT; i++) begin:output_ports1

      //
      // Flow Control 
      //
      LAG_pl_fc_out #(.num_pls(NPL),
		     .init_credits(buf_len))
	fcout (.flits_valid(flits_out_valid[i]),
	       .channel_cntrl_in(i_cntrl_in[i]),
	       .pl_status(x_pl_status[i]),
	       .pl_empty(pl_empty[i]), 
	       .clk, .rst_n);   
	       
      //      
      // Free PL pools 
      //
      
      if (i==`TILE) begin
	 //
	 // may have less than a full complement of PLs on exit from network
	 //
	 LAG_pl_free_pool #(.num_pls_local(router_num_pls_on_exit), 
			   .num_pls_global(NPL),
			   .fifo_free_pool(!plalloc_unrestricted),
			   .only_allocate_pl_when_empty(plselect_onlywhenempty)) plfreepool
	   (.flits_tail(flits_out_tail[i]), 
	    .flits_valid(flits_out_valid[i]),
	    // Unrestricted free pool
	    .pl_alloc_status(pl_alloc_status[i]),
	    .pl_allocated(pl_allocated[i]),
	    .pl_empty(pl_empty[i]),
	    //
	    .clk, .rst_n);
      end else begin
	 LAG_pl_free_pool #(.num_pls_local(NPL),
			   .num_pls_global(NPL),
			   .fifo_free_pool(!plalloc_unrestricted),
			   .only_allocate_pl_when_empty(plselect_onlywhenempty)) plfreepool
	   (.flits_tail(flits_out_tail[i]), 
	    .flits_valid(flits_out_valid[i]),
	    // Unrestricted free pool
	    .pl_alloc_status(pl_alloc_status[i]),
	    .pl_allocated(pl_allocated[i]),
	    .pl_empty(pl_empty[i]),
	    //
	    .clk, .rst_n);
      end // else: !if(i==`TILE)
      
      
      for (j=0; j<NPL; j++) begin:output_channels2
      
        assign flits_out_tail[i][j] = x_flit_xbarout[i][j].control.tail;
        assign flits_out_valid[i][j] = x_flit_xbarout[i][j].control.valid;//output_used[i][j];
        
      end
      
     assign i_cntrl_out[i].credits = x_pop[i];
     
      always@(posedge clk) begin
	 if (!rst_n) begin
	    //i_cntrl_out[i].credits <= '0;
	 end else begin
	    //
	    // ensure 'credit' is registered before it is sent to the upstream router
	    //

	    // send credit corresponding to flit sent from this input port
	    //i_cntrl_out[i].credits <= x_pop[i];    
	 end
      end
    
    end 
      
   endgenerate
   
      
   // *******************************************************************************
   // input ports (pl buffers and PL registers)
   // *******************************************************************************

   generate
      for (i=0; i<router_num_pls_on_entry; i++) begin:plsx
	       assign i_input_full_flag[i] = x_flags[`TILE][i].full; // TILE input FIFO[i] is full?	       
      end

      
      for (i=0; i<NT; i++) begin:input_ports

	 // should support .nv and .num_pls (e.g. for tile input that may only
	 // support a single input PL)
	 
	 // input port 'i'
	 LAG_pl_input_port #(.num_pls(NPL), 
			    .buffer_length(buf_len)) inport
	   (.push(x_push[i]), 
	    .pop(x_pop[i]), 
	    .data_in(i_flit_in[i]), 
	    .data_out(flit_buffer_out[i]),
	    .flags(x_flags[i]), 
	    .allocated_pl(x_allocated_pl[i]), 
	    .allocated_pl_valid(x_allocated_pl_valid[i]), 
	    .pl_new(x_pl_new[i]), 
	    .pl_new_valid(x_pl_new_valid[i]),
	    .clk, .rst_n);
      
      //
      // output port fields and flit priorities
      // flit priorities come from flit.control.flit_priority (if required)
      //
      for (j=0; j<NPL; j++) begin:allpls2

	      LAG_route rfn (.flit_in(flit_buffer_out[i][j]), .flit_out(routed[i][j]), .clk, .rst_n);
        
        assign x_push[i][j] = i_flit_in[i][j].control.valid;
        
        //assign x_flit_xbarin[i][j] = flit_buffer_out[i][j].control.head ? routed[i][j] : flit_buffer_out[i][j];
	      assign x_output_port[i][j] = flit_buffer_out[i][j].control.head ? flit_buffer_out[i][j].data[router_radix-1:0] : x_output_port_reg[i][j];
	      //first ROUTER_RADIX bits in head's flit data cell contains output port for this packet
	 
        if (priority_flit_dynamic_switch_alloc) begin
          //assign req_priority[i][j] = flit_buffer_out[i][j].control.flit_priority;
        end
	    
      end
      
      for (j=0; j<NPL; j++) begin:allpls3
        always@(posedge clk) begin
	        if (!rst_n) begin
	          x_output_port_reg[i][j] <= '0;
	        end else if (flit_buffer_out[i][j].control.head) begin

	           x_output_port_reg[i][j] <= flit_buffer_out[i][j].data[router_radix-1:0];  
	         end
        end
      end

      //
      // Virtual-Channel allocation requests
      // 
      for (j=0; j<NPL; j++) begin:reqs
	    //
	    // VIRTUAL-CHANNEL ALLOCATION REQUESTS
	    //
        assign pl_request[i][j]= (LAG_route_valid_input_pl(i,j)) ? 
				  !x_flags[i][j].empty & !x_allocated_pl_valid[i][j] : 1'b0;
	 
	      assign x_pop[i][j] = !x_flags[i][j].empty & x_allocated_pl_valid[i][j] & ~allocated_pl_blocked[i][j];

      end // block: reqs
      
      
      for (j=0; j<NPL; j++) begin:flit_to_out_valid
        always_comb begin
          x_flit_xbarin[i][j] = flit_buffer_out[i][j].control.head ? routed[i][j] : flit_buffer_out[i][j];
        
          x_flit_xbarin[i][j].control.valid = x_pop[i][j];
        end
      end
      
   end // block: input_ports
      
   
      //
      // if single-cycle we need to consider newly allocated
      // virtual-channels too when determining if PLs are blocked
      //
      LAG_pl_status #(.np(NT), .nv(NPL)) vstat (.output_port(x_output_port),  
                                              .allocated_pl(x_allocated_pl),
                                              .allocated_pl_valid(x_allocated_pl_valid),
	                                            .pl_status(x_pl_status), 
                                              .pl_blocked(allocated_pl_blocked));
   
      
   endgenerate

   // ----------------------------------------------------------------------
   // virtual-channel allocation logic
   // ----------------------------------------------------------------------
   LAG_pl_allocator #(.buf_len(buf_len), .np(NT), .nv(NPL), .xs(network_x), .ys(network_y), 
         .alloc_stages(alloc_stages))
     plalloc
       (.req(pl_request),
	.output_port(x_output_port),
	.pl_new(x_pl_new),
	.pl_new_valid(x_pl_new_valid),
	// unrestricted PL pool
	.pl_allocated(pl_allocated),
	.pl_alloc_status(pl_alloc_status), 
	.clk, .rst_n);

  generate
    for (i=0; i<NT; i++) begin: out_ports_xbar_select
      for (j=0; j<NPL; j++) begin: out_channels_xbar_select
        for (k=0; k<NT; k++) begin: in_ports_xbar_select
          for (l=0; l<NPL; l++) begin: in_channels_xbar_select
            assign xbar_select[i*NPL+j][k*NPL+l] = x_output_port[k][l][i] & x_allocated_pl[k][l][j]; //& x_allocated_pl_valid[k][l];        
                                                                                 //может быть узкое место, поскольку работаем с
                                                                                 //x_allocated_pl, который обновляется на след.
                                                                                 //такте после выделения. Соответственно,
                                                                                 //на том такте, когда происходит выделение,
                                                                                 //xbar_select не будет установлен
          end
        end
      end
    end  
  endgenerate
    
  generate
    for (i=0; i<NT; i++) begin: in_ports_xbar
      for (j=0; j<NPL; j++) begin: in_channels_xbar
        assign x_flit_xbarin_[i*NPL+j] = x_flit_xbarin[i][j];
      end
    end  
  endgenerate  
  
  generate
    for (i=0; i<NT; i++) begin: out_ports_xbar
      for (j=0; j<NPL; j++) begin: out_channels_xbar
        assign x_flit_xbarout[i][j] = x_flit_xbarout_[i*NPL+j];
      end
    end  
  endgenerate   
   // ----------------------------------------------------------------------
   // crossbar
   // ----------------------------------------------------------------------

	 LAG_crossbar_oh_select #(.n(NT*NPL)) myxbar 
	   (x_flit_xbarin_, xbar_select, x_flit_xbarout_); 
   
   
   // ----------------------------------------------------------------------
   // output port logic
   // ----------------------------------------------------------------------
   generate
   for (i=0; i<NT; i++) begin:outports
      for (j=0; j<NPL; j++) begin:outchannels
      
/*	     for (k=0; k<NT; k++) begin: in_ports_output_used
          for (l=0; l<NPL; l++) begin: in_channels_output_used
             
           assign output_used_[i][j][k][l] =  (x_output_port[k][l][i] &  x_allocated_pl[k][l][j] & x_allocated_pl_valid[k][l] & x_pop[k][l] & !x_pl_status[i][j]) ;
                                         //проверить, можно ли убрать слагаемое x_allocated_pl_valid (походу можно)	        
                   
          end
       end*/
       
     // assign output_used[i][j] = |output_used_[i][j];
       
       assign i_flit_out[i][j] = x_flit_xbarout[i][j];
      /*always_comb 
        begin
           i_flit_out[i][j]=x_flit_xbarout[i][j];
        
           i_flit_out[i][j].control.valid = output_used[i][j];
	     end*/
	
   end //block: outchannels
   end // block: outports
   endgenerate 

   // synopsys translate_off
   /*  -----------------------------------------------------------------------------------
    *  assert (only unallocated PLs are allocated to waiting packets)
    *  -----------------------------------------------------------------------------------
    */
   always@(posedge clk) begin
      if (!rst_n) begin
      end else begin
            
	 for (p=0; p<NT; p++) begin
	    for (v=0; v<NPL; v++) begin   
	       if (x_pl_new_valid[p][v]) begin
		  // check x_pl_new is free to be allocated
		  if (plalloc_unrestricted) begin
		     if (!pl_alloc_status[oh2bin(x_output_port[p][v])][oh2bin(x_pl_new[p][v])]) begin
			$display ("%m: Error: Newly allocated PL is already allocated to another packet");
                        $display ("Input port=%1d, PL=%1d", p,v);
			$display ("Requesting Output Port %b (%1d)", x_output_port[p][v],
				  oh2bin(x_output_port[p][v]));
			$display ("PL requested  %b ", pl_requested[p][v]);
			$display ("x_pl_new      %b ", x_pl_new[p][v]);
			$finish;
		     end
		  end
	       end
	    end
	 end
      end
   end  
   // synopsys translate_on

   
   // synopsys translate_off
   /*  -----------------------------------------------------------------------------------
    *  assert (no. of flits leaving router == no. of flits dequeued from input FIFOs)
    *  -----------------------------------------------------------------------------------
    */
   always@(posedge clk) begin
      if (!rst_n) begin
      end else begin
	 db_out_used = 0;
	 db_in_popped = 0;
	 // count number of outputs used.
	 for (p=0; p<NT; p++) begin             //p symbolize output channel (dim. is NT*NPL)
	    for (v=0; v<NPL; v++) begin
        if (output_used[p][v]) 
          db_out_used++;
      end  
	 end
	 // count number of flits removed from input fifos
	 for (p=0; p<NT; p++) begin
	    for (v=0; v<NPL; v++) begin
	       if (x_pop[p][v]) begin db_in_popped++;
	       //$display ("[%d][%d] popped;", p,v);
	       //if (output_used[p][v]) $stop;  
	      // if (flits_out_valid[p][v]) $stop;
	       //if (flits_out_tail[p][v]) $stop;
	       //if (flits_out_valid[p][v] & flits_out_tail[p][v]) $stop;
         end
      end
	 end
	        
/*	 if (db_out_used!=db_in_popped) begin
	    $display ("%m: Error: more flits sent on output than dequeued from input FIFOs!");
      $display ("db_out_used=%d, db_in_popped=%d", db_out_used, db_in_popped);
	    	 for (p=0; p<NT; p++) begin
	    for (v=0; v<NPL; v++) begin
	       if (x_pop[p][v])
	       $display ("[%d][%d] popped;", p,v);
      end
	 end  
      $display ("-------------------------------------------------");
	    $display ("Output Used=%b", output_used);
	    $display ("-------------------------------------------------");
	    $stop;
//	    $finish;
	 end // if (db_out_used!=db_in_popped)*/
      end
   end // always@ (posedge clk) 
      
   // synopsys translate_on
   
endmodule // simple_router
