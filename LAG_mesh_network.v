/* -------------------------------------------------------------------------------
 * (C)2012 Korotkyi Ievgen
 * National Technical University of Ukraine "Kiev Polytechnic Institute"
 * -------------------------------------------------------------------------------
 * 
 * Mesh Network 
 * 
 */

`include "types.v"
`include "parameters.v"

module LAG_mesh_network (din, dout,
			input_full_flag,
			cntrl_in, 
			clk, rst_n);
   
   parameter XS=network_x;
   parameter YS=network_y;
   parameter NT=router_radix;
   parameter NPL=router_num_pls;
   
//   parameter channel_latency = 0; // number of registers in router to router link or channel

   input     clk, rst_n;
   input     [XS*YS*$bits(chan_cntrl_t) - 1 : 0] cntrl_in; 
   input     [XS*YS*$bits(flit_t) - 1 : 0] din;
   output    [XS*YS*router_num_pls_on_exit*$bits(flit_t) - 1 : 0] dout;
   output    [XS*YS*router_num_pls_on_entry - 1 : 0] input_full_flag;
   
   // network connections
   flit_t	 i_flit_in   [XS-1:0][YS-1:0][NT-1:0][NPL-1:0];
   flit_t	 i_flit_in_  [XS-1:0][YS-1:0][NT-1:0][NPL-1:0];  
   flit_t	 i_flit_out  [XS-1:0][YS-1:0][NT-1:0][NPL-1:0];
   flit_t	 i_flit_out_ [XS-1:0][YS-1:0][NT-1:0][NPL-1:0];

   flit_t	 terminator [NPL-1:0];
   
   chan_cntrl_t  i_cntrl_in  [XS-1:0][YS-1:0][NT-1:0];
   chan_cntrl_t  i_cntrl_out [XS-1:0][YS-1:0][NT-1:0];
   
   reg 		 clk_g [XS-1:0][YS-1:0];

   genvar 	 x,y,p,c;
   
   // *********************************************************
   // implement router-level clock gating if requested
   // *********************************************************
   //
   generate
   for (y=0; y<YS; y=y+1) begin:ycg
      for (x=0; x<XS; x=x+1) begin:xcg
	 //
	 // no router level clock gating, router clock = global clock
         //
   	 always@(clk) begin
	    clk_g[x][y]<=clk;
	 end

      end // block: xcg
   end // block: ycg
   endgenerate
   // *********************************************************

   generate
   for (y=0; y<YS; y=y+1) begin:yl
      for (x=0; x<XS; x=x+1) begin:xl

	 //
	 // make network connections
	 //
	 
	 // tile port - external interface
	 always_comb
	   begin
	 i_flit_in[x][y][`TILE] = terminator;
     i_flit_in[x][y][`TILE][0] = din[$bits(flit_t)*(x*YS + y + 1) - 1 : $bits(flit_t)*(x*YS + y)]; ; 
     end

	 assign i_cntrl_in[x][y][`TILE] = cntrl_in[$bits(chan_cntrl_t)*(x*YS + y + 1) - 1 : $bits(chan_cntrl_t)*(x*YS + y)];

   for (c=0; c<router_num_pls_on_exit; c++) begin:network_out_to_sink
	   assign dout[$bits(flit_t)*(x*YS*router_num_pls_on_exit + y*router_num_pls_on_exit + c + 1) - 1 : $bits(flit_t)*(x*YS*router_num_pls_on_exit + y*router_num_pls_on_exit + c)] = i_flit_out[x][y][`TILE][c];
   end
   
	 // north port
	 if (y==0) begin
	    assign i_flit_in[x][y][`NORTH]  = terminator; 
	    assign i_cntrl_in[x][y][`NORTH] = '0; 
	 end else begin	    
	    assign i_flit_in[x][y][`NORTH]  = i_flit_out[x][y-1][`SOUTH];
	    assign i_cntrl_in[x][y][`NORTH] = i_cntrl_out[x][y-1][`SOUTH];
	 end

	 // east port
	 if (x==XS-1) begin
	    assign i_flit_in[x][y][`EAST]   = terminator; 
	    assign i_cntrl_in[x][y][`EAST]  = '0; 
	 end else begin
	    assign i_flit_in[x][y][`EAST]   = i_flit_out[x+1][y][`WEST];
	    assign i_cntrl_in[x][y][`EAST]  = i_cntrl_out[x+1][y][`WEST];
	 end

	 // south port
	 if (y==YS-1) begin
	    assign i_flit_in[x][y][`SOUTH]  = terminator;
	    assign i_cntrl_in[x][y][`SOUTH] = '0;
	 end else begin
	    assign i_flit_in[x][y][`SOUTH]  = i_flit_out[x][y+1][`NORTH];
	    assign i_cntrl_in[x][y][`SOUTH] = i_cntrl_out[x][y+1][`NORTH];
	 end

	 // west port
	 if (x==0) begin
	    assign i_flit_in[x][y][`WEST]   = terminator;
	    assign i_cntrl_in[x][y][`WEST]  = '0;
	 end else begin
	    assign i_flit_in[x][y][`WEST]   = i_flit_out[x-1][y][`EAST];
	    assign i_cntrl_in[x][y][`WEST]  = i_cntrl_out[x-1][y][`EAST];
	 end

	 for (p=0; p<NT; p++) begin:prts
	   for (c=0; c<NPL; c++) begin:channels2
      always_comb
	      begin
		    i_flit_in_[x][y][p][c] = i_flit_in[x][y][p][c];
     end
    end
     
	 end
	 
	 // ###################################
	 // Channel (link) between routers -    ** NOT FROM ROUTER TO TILE **
	 // ###################################
	 // i_flit_out_ -> CHANNEL -> i_flit_out
	 //
	 /*for (p=0; p<NT; p++) begin:prts2
	   
     assign i_flit_out[x][y][p]=i_flit_out_[x][y][p];
	 
   end*/
  
    for (p=0; p<NT; p++) begin:prts2
	    if (p==`TILE) begin
	       // router to tile is a local connection
	       assign i_flit_out[x][y][p]=i_flit_out_[x][y][p];
	    end else begin
	       LAG_pipelined_channel #(.nPC(NPL), .stages(channel_latency)) channel 
		 (.data_in(i_flit_out_[x][y][p]), 
		  .data_out(i_flit_out[x][y][p]), .clk, .rst_n);
	    end
	  end
	 
	 // ###################################
	 // Router
	 // ###################################
	 // # parameters for router are read from parameters.v
	 LAG_router #(
                  .buf_len(router_buf_len),
        			    .network_x(network_x),
        			    .network_y(network_y),
        			    .NT(router_radix), 
        			    .NPL(router_num_pls),
        			    .alloc_stages(router_alloc_stages),
        			    .router_num_pls_on_entry(router_num_pls_on_entry),
        			    .router_num_pls_on_exit(router_num_pls_on_exit)
   ) node 
	   (i_flit_in_[x][y], 
	    i_flit_out_[x][y], 
	    i_cntrl_in[x][y], 
	    i_cntrl_out[x][y],
	    input_full_flag[router_num_pls_on_entry*(x*YS + y + 1) - 1 : router_num_pls_on_entry*(x*YS + y)], 
	    clk_g[x][y], 
	    rst_n);

   end //x
   end //y
   endgenerate     
      
endmodule 
