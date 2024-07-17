/*******************************************************************
 * Signed Modular Multiplication with Prime Q = 163841
 *
 * Author: Bo-Yuan Peng
 *
 * Description:
 * This is a verilog module doing signed modular multiplication
 *                 outC == inA * inB (mod^{+-} 163841)
 * 
 *                                   Diligent                 Lazy
 * -- inA:  signed 18-bit integer in [-81920  , 81920  ] or [].
 * -- inB:  signed 18-bit integer in [-81920  , 81920  ] or [].
 * -- inZ:  signed 35-bit integer in [-81920^2, 81920^2] or [].
 * -- outC: signed 18-bit integer in [-81920  , 81920  ] or [].
 *
 * Version Info:
 *    Oct. 7,2022: 0.1.0 reation of the module.
 *                       module design complete without critical
 *                       path length control.
 *******************************************************************/

module modmul163841s (
  input                     clk,
  input                     rst,
  //input signed      [17:0]  inA,
  //input signed      [17:0]  inB,
  input signed      [34:0]  inZ,
  output reg signed [17:0]  outZ
) ;

  //reg signed        [34:0]  mZ;
  wire signed       [34:0]  mZ;

  wire              [3:0]   mZptoken;
  wire              [3:0]   mZntoken;

  wire              [3:0]   mZpuu;
  wire              [5:0]   mZpu;
  wire              [5:0]   mZnu;
  wire              [13:0]  mZpl_p0;
  wire              [11:0]  mZnl_p00;
  wire              [4:0]   mZnl_p01;
  wire              [11:0]  mZnl_p0;
  wire              [14:0]  mZnl_p1;

  reg               [13:0]  mZpl;
  reg               [14:0]  mZnl;
  reg               [6:0]   mZpnu;
  reg                       mZ33_1;

  wire              [2:0]   mZn2u;
  wire              [4:0]   mZpn2u;
  wire              [14:0]  mZn2l;

  wire              [13:0]  mZp2l_33T;
  wire              [4:0]   mZp3u;
  wire              [13:0]  mZp2l_33F;

  reg               [17:0]  mZp_33T;
  reg               [17:0]  mZn_33T;
  reg               [17:0]  mZp_33F;
  reg               [14:0]  mZn_33F;
  reg                       mZ33_2;

  wire signed       [18:0]  mZpn_33T;
  wire signed       [17:0]  mZpn_33T_pQ;
  wire signed       [17:0]  mZpn_33T_nQ;
  wire                      mZpn_33T_G;
  wire signed       [18:0]  mZpn_33F;
  wire signed       [17:0]  mZpn_33F_nQ;
  wire                      mZpn_33F_G;

  wire signed       [17:0]  outZ_33T;
  wire signed       [17:0]  outZ_33F;

  assign mZ = inZ;
  //always @ ( posedge clk ) begin
  //  if(rst) begin
  //    mZ <= 'sd0;
  //  end else begin
  //    //mZ <= inA * inB;
  //    mZ <= inZ;
  //  end
  //end

  assign mZptoken = ( { 2'b0, mZ[20:19] } + { 2'b0, mZ[24:23] } ) + ( { 2'b0, mZ[28:27] } + { 2'b0, mZ[32:31] } ) ;
  assign mZntoken = ( { 2'b0, mZ[18:17] } + { 2'b0, mZ[22:21] } ) + ( { 2'b0, mZ[26:25] } + { 2'b0, mZ[30:29] } ) ;

  assign mZpuu    = mZptoken + { 2'b0, mZ[16:15] };
  assign mZpu     = { mZpuu, mZ[14:13] };
  assign mZnu     = { mZntoken, mZ[32], mZ[32] };

  assign mZpl_p0  = { 1'b0, mZ[12:0] } + { 1'b0, mZ[34], mZ[34], 2'b0, mZ[34], mZ[34], 2'b0, mZ[34], mZ[34], 2'b0, mZ[34] };
  assign mZnl_p00 = { 1'b0, mZ[31:21] } + { 4'b0, mZ[32:25] };
  assign mZnl_p01 = { 1'b0, mZ[32:29] } + { 3'b0, mZptoken[3:2] };
  assign mZnl_p0  = mZnl_p00 + { 7'b0, mZnl_p01 };
  assign mZnl_p1  = { mZnl_p0, mZptoken[1:0], 1'b0 } + { 1'b0, mZnl_p0, mZptoken[1:0] };
 
  always @ ( posedge clk ) begin
    if(rst) begin
      mZpl   <= 'd0;
      mZnl   <= 'd0;
      mZpnu  <= 'd0;
      mZ33_1 <= 'b0;
    end else begin
      mZpl   <= mZpl_p0;
      mZnl   <= mZnl_p1 + mZntoken;
      mZpnu  <= { 1'b0, mZpu } - { 1'b0, mZnu };
      mZ33_1 <= mZ[33];
    end
  end

  assign mZn2u     = { 1'b0, mZpnu[5:4] } + { 2'b0, mZpnu[6] };
  assign mZpn2u    = { 1'b0, mZpnu[3:0] } - { mZn2u, 2'b0 };
  assign mZn2l     = mZnl + { 13'b0, mZpnu[5:4] };

  assign mZp2l_33T = mZpl + { 12'b0, mZpnu[6], mZpnu[6] };
  assign mZp3u     = { 1'b0, mZpn2u[3:0] } + { 2'b0, mZpn2u[4], 2'b0 };
  assign mZp2l_33F = mZp2l_33T + { 13'b0, mZpn2u[4] };
 
  always @ ( posedge clk ) begin
    if(rst) begin
      mZp_33T <= 'd0;
      mZn_33T <= 'd0;
      mZp_33F <= 'd0;
      mZn_33F <= 'd0;
      mZ33_2  <= 'b0;
    end else begin
      mZp_33T <= { 1'b0, mZpn2u[3:0], 13'b0 } + { 4'b0, mZp2l_33T } ;
      mZn_33T <= { mZpn2u[4], 2'b0, mZn2l } ;
      mZp_33F <= { mZp3u, 13'b0 } + { 4'b0, mZp2l_33F } ;
      mZn_33F <= mZn2l;
      mZ33_2  <= mZ33_1;
    end
  end

  assign mZpn_33T    = { 1'b0, mZp_33T } - { 1'b0, mZn_33T } ;
  assign mZpn_33T_pQ = mZpn_33T + 'sd78644;
  assign mZpn_33T_nQ = mZpn_33T - 'sd85197;
  assign mZpn_33T_G  = (mZpn_33T > 'sd3276);
  assign outZ_33T    = mZpn_33T_G ? mZpn_33T_nQ : mZpn_33T_pQ ;

  assign mZpn_33F    = { 1'b0, mZp_33F } - { 4'b0, mZn_33F } ;
  assign mZpn_33F_nQ = mZpn_33F - 'sd163841;
  assign mZpn_33F_G  = (mZpn_33F > 'sd81920);
  assign outZ_33F    = mZpn_33F_G ? mZpn_33F_nQ : mZpn_33F[17:0] ;

  always @ ( posedge clk ) begin
    outZ <= mZ33_2 ? outZ_33T : outZ_33F;
  end

endmodule

