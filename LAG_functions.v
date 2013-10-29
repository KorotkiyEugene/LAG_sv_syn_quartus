
/* -------------------------------------------------------------------------------
 * (C)2007 Robert Mullins
 * Computer Architecture Group, Computer Laboratory
 * University of Cambridge, UK.
 * -------------------------------------------------------------------------------
 *
 * Misc. functions package
 * 
 *   - clogb2(x) - ceiling(log2(x))
 *   - oh2bin(x) - one-hot to binary encoder
 *   - max (x,y) - returns larger of x and y
 *   - min (x,y) - returns smaller of x and y
 *   - abs (x)   - absolute function
 */

function automatic integer abs (input integer x);
   begin
      if (x>=0) return (x); else return (-x);
   end
endfunction


function automatic integer min (input integer x, input integer y);
   begin
      min = (x<y) ? x : y;
   end
endfunction

function automatic integer max (input integer x, input integer y);
   begin
      max = (x>y) ? x : y;
   end
endfunction 

// A constant function to return ceil(logb2(x))
// Is this already present in the Systemverilog standard?
function automatic integer clogb2 (input integer depth);
   integer i,x;
   begin
      x=1;
      for (i = 0; 2**i < depth; i = i + 1)
	x = i + 1;

      clogb2=x;
   end
endfunction

// one hot to binary encoder (careful not to produce priority encoder!)
function automatic integer oh2bin (input integer oh);
   
   integer unsigned i,j;
   begin
      oh2bin='0;
      for (i=0; i<5; i++) begin
	 for (j=0; j<32; j++) begin
	    if ((1'b1 << i)&j) begin
	       oh2bin[i] = oh2bin[i] | oh[j] ;
	    end
	 end
      end
   end
endfunction // oh2bin

function [31:0] crc32;

    input [15:0] Data;
    input [31:0] crc;
    reg [15:0] d;
    reg [31:0] c;
    reg [31:0] newcrc;
  begin
    d = Data;
    c = crc;

    newcrc[0] = d[12] ^ d[10] ^ d[9] ^ d[6] ^ d[0] ^ c[16] ^ c[22] ^ c[25] ^ c[26] ^ c[28];
    newcrc[1] = d[13] ^ d[12] ^ d[11] ^ d[9] ^ d[7] ^ d[6] ^ d[1] ^ d[0] ^ c[16] ^ c[17] ^ c[22] ^ c[23] ^ c[25] ^ c[27] ^ c[28] ^ c[29];
    newcrc[2] = d[14] ^ d[13] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[2] ^ d[1] ^ d[0] ^ c[16] ^ c[17] ^ c[18] ^ c[22] ^ c[23] ^ c[24] ^ c[25] ^ c[29] ^ c[30];
    newcrc[3] = d[15] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[3] ^ d[2] ^ d[1] ^ c[17] ^ c[18] ^ c[19] ^ c[23] ^ c[24] ^ c[25] ^ c[26] ^ c[30] ^ c[31];
    newcrc[4] = d[15] ^ d[12] ^ d[11] ^ d[8] ^ d[6] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ c[16] ^ c[18] ^ c[19] ^ c[20] ^ c[22] ^ c[24] ^ c[27] ^ c[28] ^ c[31];
    newcrc[5] = d[13] ^ d[10] ^ d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[1] ^ d[0] ^ c[16] ^ c[17] ^ c[19] ^ c[20] ^ c[21] ^ c[22] ^ c[23] ^ c[26] ^ c[29];
    newcrc[6] = d[14] ^ d[11] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ c[17] ^ c[18] ^ c[20] ^ c[21] ^ c[22] ^ c[23] ^ c[24] ^ c[27] ^ c[30];
    newcrc[7] = d[15] ^ d[10] ^ d[8] ^ d[7] ^ d[5] ^ d[3] ^ d[2] ^ d[0] ^ c[16] ^ c[18] ^ c[19] ^ c[21] ^ c[23] ^ c[24] ^ c[26] ^ c[31];
    newcrc[8] = d[12] ^ d[11] ^ d[10] ^ d[8] ^ d[4] ^ d[3] ^ d[1] ^ d[0] ^ c[16] ^ c[17] ^ c[19] ^ c[20] ^ c[24] ^ c[26] ^ c[27] ^ c[28];
    newcrc[9] = d[13] ^ d[12] ^ d[11] ^ d[9] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ c[17] ^ c[18] ^ c[20] ^ c[21] ^ c[25] ^ c[27] ^ c[28] ^ c[29];
    newcrc[10] = d[14] ^ d[13] ^ d[9] ^ d[5] ^ d[3] ^ d[2] ^ d[0] ^ c[16] ^ c[18] ^ c[19] ^ c[21] ^ c[25] ^ c[29] ^ c[30];
    newcrc[11] = d[15] ^ d[14] ^ d[12] ^ d[9] ^ d[4] ^ d[3] ^ d[1] ^ d[0] ^ c[16] ^ c[17] ^ c[19] ^ c[20] ^ c[25] ^ c[28] ^ c[30] ^ c[31];
    newcrc[12] = d[15] ^ d[13] ^ d[12] ^ d[9] ^ d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ d[0] ^ c[16] ^ c[17] ^ c[18] ^ c[20] ^ c[21] ^ c[22] ^ c[25] ^ c[28] ^ c[29] ^ c[31];
    newcrc[13] = d[14] ^ d[13] ^ d[10] ^ d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[2] ^ d[1] ^ c[17] ^ c[18] ^ c[19] ^ c[21] ^ c[22] ^ c[23] ^ c[26] ^ c[29] ^ c[30];
    newcrc[14] = d[15] ^ d[14] ^ d[11] ^ d[8] ^ d[7] ^ d[6] ^ d[4] ^ d[3] ^ d[2] ^ c[18] ^ c[19] ^ c[20] ^ c[22] ^ c[23] ^ c[24] ^ c[27] ^ c[30] ^ c[31];
    newcrc[15] = d[15] ^ d[12] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[4] ^ d[3] ^ c[19] ^ c[20] ^ c[21] ^ c[23] ^ c[24] ^ c[25] ^ c[28] ^ c[31];
    newcrc[16] = d[13] ^ d[12] ^ d[8] ^ d[5] ^ d[4] ^ d[0] ^ c[0] ^ c[16] ^ c[20] ^ c[21] ^ c[24] ^ c[28] ^ c[29];
    newcrc[17] = d[14] ^ d[13] ^ d[9] ^ d[6] ^ d[5] ^ d[1] ^ c[1] ^ c[17] ^ c[21] ^ c[22] ^ c[25] ^ c[29] ^ c[30];
    newcrc[18] = d[15] ^ d[14] ^ d[10] ^ d[7] ^ d[6] ^ d[2] ^ c[2] ^ c[18] ^ c[22] ^ c[23] ^ c[26] ^ c[30] ^ c[31];
    newcrc[19] = d[15] ^ d[11] ^ d[8] ^ d[7] ^ d[3] ^ c[3] ^ c[19] ^ c[23] ^ c[24] ^ c[27] ^ c[31];
    newcrc[20] = d[12] ^ d[9] ^ d[8] ^ d[4] ^ c[4] ^ c[20] ^ c[24] ^ c[25] ^ c[28];
    newcrc[21] = d[13] ^ d[10] ^ d[9] ^ d[5] ^ c[5] ^ c[21] ^ c[25] ^ c[26] ^ c[29];
    newcrc[22] = d[14] ^ d[12] ^ d[11] ^ d[9] ^ d[0] ^ c[6] ^ c[16] ^ c[25] ^ c[27] ^ c[28] ^ c[30];
    newcrc[23] = d[15] ^ d[13] ^ d[9] ^ d[6] ^ d[1] ^ d[0] ^ c[7] ^ c[16] ^ c[17] ^ c[22] ^ c[25] ^ c[29] ^ c[31];
    newcrc[24] = d[14] ^ d[10] ^ d[7] ^ d[2] ^ d[1] ^ c[8] ^ c[17] ^ c[18] ^ c[23] ^ c[26] ^ c[30];
    newcrc[25] = d[15] ^ d[11] ^ d[8] ^ d[3] ^ d[2] ^ c[9] ^ c[18] ^ c[19] ^ c[24] ^ c[27] ^ c[31];
    newcrc[26] = d[10] ^ d[6] ^ d[4] ^ d[3] ^ d[0] ^ c[10] ^ c[16] ^ c[19] ^ c[20] ^ c[22] ^ c[26];
    newcrc[27] = d[11] ^ d[7] ^ d[5] ^ d[4] ^ d[1] ^ c[11] ^ c[17] ^ c[20] ^ c[21] ^ c[23] ^ c[27];
    newcrc[28] = d[12] ^ d[8] ^ d[6] ^ d[5] ^ d[2] ^ c[12] ^ c[18] ^ c[21] ^ c[22] ^ c[24] ^ c[28];
    newcrc[29] = d[13] ^ d[9] ^ d[7] ^ d[6] ^ d[3] ^ c[13] ^ c[19] ^ c[22] ^ c[23] ^ c[25] ^ c[29];
    newcrc[30] = d[14] ^ d[10] ^ d[8] ^ d[7] ^ d[4] ^ c[14] ^ c[20] ^ c[23] ^ c[24] ^ c[26] ^ c[30];
    newcrc[31] = d[15] ^ d[11] ^ d[9] ^ d[8] ^ d[5] ^ c[15] ^ c[21] ^ c[24] ^ c[25] ^ c[27] ^ c[31];
    crc32 = newcrc;
  end
endfunction

