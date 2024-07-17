/*******************************************************************
 * Signed Modular Multiplication with Prime Q = 114689
 *
 * Author: Bo-Yuan Peng
 *
 * Description:
 * This is a verilog module doing signed modular multiplication
 *                 outC == inA * inB (mod^{+-} 114689)
 * 
 *                                      Diligent          Lazy
 * -- inA:  signed 17-bit integer in [-60416, 60416] or [].
 * -- inB:  signed 17-bit integer in [-60416, 60416] or [].
 * -- outC: signed 17-bit integer in [-60416, 60416] or [].
 *
 * Version Info:
 *    Nov.19,2021: 0.1.0 creation of the module.
 *                       //module design complete without critical
 *                       //path length control.
 *******************************************************************/

module modmul120833s (
  input                     clk,
  input                     rst,
  //input signed      [16:0]  inA,
  //input signed      [16:0]  inB,
  input signed      [32:0]  inZ,
  output reg signed [16:0]  outZ
) ;

  //reg signed        [32:0]  mZ;
  wire signed       [32:0]  mZ;

  reg               [10:0]  mZlow;
  reg                       mZsign;

  wire              [6:0]   mZpu_p00;
  wire              [6:0]   mZpu_p01;
  wire              [6:0]   mZpu_p02;
  wire              [6:0]   mZpu_p03;
  wire              [7:0]   mZpu_p10;
  wire              [7:0]   mZpu_p11;

  reg               [8:0]   mZpu;

  wire              [3:0]   mZp2u_p0;
  wire              [6:0]   mZp2u;

  wire              [3:0]   mZpC;
  wire              [5:0]   mZp3u;
  reg               [16:0]  mZp0;

  wire              [14:0]  mZn_p00;
  wire              [11:0]  mZn_p01;
  wire              [9:0]   mZn_p02;
  wire              [6:0]   mZn_p03;
  reg               [14:0]  mZn_p10;
  reg               [12:0]  mZn_p11;
  
  wire              [14:0]  mZn_p10a;

  reg               [14:0]  mZn0;

  wire signed       [17:0]  mZpn;
  wire signed       [17:0]  mQ;

  assign mZ = inZ;
  //always @ ( posedge clk ) begin
  //  if(rst) begin
  //    mZ <= 'sd0;
  //  end else begin
  //    //mZ <= inA * inB;
  //    mZ <= inZ;
  //  end
  //end

  assign mZpu_p00 = mZ[22:17] + mZ[16:11];
  assign mZpu_p01 = { mZ[27:25], mZ[27:25] } + { mZ[25:23], mZ[26], mZ[24:23] };
  assign mZpu_p02 = { mZ[24:21], mZ[27:26] } + { mZ[20:17], mZ[22:21] };
  assign mZpu_p03 = { mZ[28], 1'b0, mZ[27], mZ[31], 2'b0 } + { mZ[32:29], mZ[30:29] };
  assign mZpu_p10 = mZpu_p00 + mZpu_p01;
  assign mZpu_p11 = mZpu_p02 + mZpu_p03;
  always @ ( posedge clk ) begin
    if(rst) begin
      mZpu <= 'd0;
      mZlow <= 'd0;
      mZsign <= 'b0;
    end else begin
      mZpu <= mZpu_p10 + mZpu_p11;
      mZlow <= mZ[10:0];
      mZsign <= mZ[32];
    end
  end

  assign mZp2u_p0 = mZpu[8:6] + { 2'b0, mZpu[8] };
  assign mZp2u = { mZp2u_p0, mZpu[7:6] } + mZpu[5:0];
  assign mZp3u = { 4'b0, mZp2u[6], 1'b0, mZp2u[6] } + mZp2u[5:0];
  assign mZpC  = mZpu[8:6] + { 2'b0, mZp2u[6] };

  always @ ( posedge clk ) begin
    if(rst) begin
      mZp0 <= 'd0;
    end else begin
      mZp0 <= { mZp3u, mZlow };
    end
  end

  assign mZn_p00[14:4] = { mZ[32], 1'b0, { 3 {mZ[32]} }, 1'b0, mZ[32], 2'b0, mZ[32], 1'b0 };
  assign mZn_p00[3:0] = ( mZ[32] ? 4'b0111 : 4'b0 ) + { 1'b0, mZ[31:29] };
  assign mZn_p01 = mZ[27:17] + mZ[31:21];
  assign mZn_p02 = mZ[31:23] + { 2'b0, mZ[31:25] };
  assign mZn_p03 = mZ[31:26] + { 2'b0, mZ[31:28] };
  always @ ( posedge clk ) begin
    if(rst) begin
      mZn_p10 <= 'd0;
      mZn_p11 <= 'd0;
    end else begin
      mZn_p10[14:7] <= mZn_p00[14:7];
      mZn_p10[6:0] <= mZn_p00[6:0] + mZn_p03;
      mZn_p11 <= mZn_p01 + mZn_p02;
    end
  end

  assign mZn_p10a[14:8] = mZn_p10[14:8];
  assign mZn_p10a[7:0] = mZn_p10[7:0] + { 4'b0, mZpC };

  always @ ( posedge clk ) begin
  //always @ (*) begin
    mZn0 <= mZn_p10a + mZn_p11;
    //mZn0 = mZn_p10a + mZn_p11;
  end

  assign mZpn = mZp0 - mZn0;
  
  /********** Deligent reduction to [-60416, 60416] **********/
  assign mQ = (mZpn > 60416) ? ('sd120833) : ('sd0);
  /************ Lazy Reduction to [] ************/
  //assign mQ = (??????) ? ('sd120833) : ('sd0);

  always @ ( posedge clk ) begin
    outZ <= mZpn - mQ;
  end

endmodule

