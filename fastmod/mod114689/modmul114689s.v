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
 * -- inA:  signed 17-bit integer in [-57344, 57344] or [].
 * -- inB:  signed 17-bit integer in [-57344, 57344] or [].
 * -- outC: signed 17-bit integer in [-57344, 57344] or [].
 *
 * Version Info:
 *    Nov.19,2021: 0.1.0 creation of the module.
 *                       //module design complete without critical
 *                       //path length control.
 *******************************************************************/

module modmul114689s (
  input                     clk,
  input                     rst,
  //input signed      [16:0]  inA,
  //input signed      [16:0]  inB,
  input signed      [32:0]  inZ,
  output reg signed [16:0]  outZ
) ;

  //reg signed        [32:0]  mZ;
  wire signed       [32:0]  mZ;

  reg               [13:0]  mZlow;
  reg                       mZsign;

  wire              [3:0]   mZpu_p00;
  wire              [3:0]   mZpu_p01;
  wire              [3:0]   mZpu_p02;
  wire              [3:0]   mZpu_p03;
  wire              [4:0]   mZpu_p10;
  wire              [4:0]   mZpu_p11;

  reg               [5:0]   mZpu;

  wire              [3:0]   mZp2u;

  wire              [2:0]   mZpC;
  wire              [2:0]   mZp3u;
  reg               [16:0]  mZp0;

  wire              [2:0]   mZn_p00_limb;
  wire              [3:0]   mZn_p00_head;
  wire              [15:0]  mZn_p00;
  wire              [2:0]   mZn_p01_limb;
  wire              [3:0]   mZn_p01_head;
  wire              [9:0]   mZn_p01;
  wire              [9:0]   mZn_p02_head;
  wire              [3:0]   mZn_p02_tail;
  wire              [13:0]  mZn_p02;
  reg               [15:0]  mZn_p10;
  wire              [3:0]   mZn_p11_head;
  wire              [9:0]   mZn_p11_tail;
  reg               [13:0]  mZn_p11;
  
  wire              [13:0]  mZn_p11a;

  reg               [15:0]  mZn0;

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

  assign mZpu_p00 = mZ[31:29] + mZ[28:26];
  assign mZpu_p01 = mZ[25:23] + mZ[22:20];
  assign mZpu_p02 = mZ[19:17] + mZ[16:14];
  assign mZpu_p03 = { 2'b0, mZ[32], 1'b0 };
  assign mZpu_p10 = mZpu_p00 + mZpu_p01;
  assign mZpu_p11 = mZpu_p02 + mZpu_p03;
  always @ ( posedge clk ) begin
    if(rst) begin
      mZpu <= 'd0;
      mZlow <= 'd0;
      mZsign <= 'b0;
    end else begin
      mZpu <= mZpu_p10 + mZpu_p11;
      mZlow <= mZ[13:0];
      mZsign <= mZ[32];
    end
  end

  assign mZp2u = mZpu[5:3] + mZpu[2:0];
  assign mZp3u = { 2'b0, mZp2u[3] } + mZp2u[2:0];
  assign mZpC  = mZpu[5:3] + { 2'b0, mZp2u[3] };

  always @ ( posedge clk ) begin
    if(rst) begin
      mZp0 <= 'd0;
    end else begin
      mZp0 <= { mZp3u, mZlow };
    end
  end

  assign mZn_p00_limb = mZpu_p00[2:0] + { 2'b0, mZpu_p00[3] };
  assign mZn_p00_head = mZ[31:29] + { 2'b0, mZpu_p00[3] };
  assign mZn_p00 = { mZn_p00_head, { 3 { mZn_p00_limb } }, mZpu_p00[2:0] };
  assign mZn_p01_limb = mZpu_p01[2:0] + { 2'b0, mZpu_p01[3] };
  assign mZn_p01_head = mZ[25:23] + { 2'b0, mZpu_p01[3] };
  assign mZn_p01 = { mZn_p01_head, mZn_p01_limb, mZpu_p01[2:0] };
  assign mZn_p02_head = { mZ[32], { 3 { 1'b0, mZ[32], mZ[32] } } };
  assign mZn_p02_tail = ( mZ[32] ? 4'b0111 : 4'b0 ) + { 1'b0, mZ[19:17] };
  assign mZn_p02 = { mZn_p02_head, mZn_p02_tail };
  assign mZn_p11_head = mZn_p02[13:10];
  assign mZn_p11_tail = mZn_p02[9:0] + mZn_p01;
  always @ ( posedge clk ) begin
    if(rst) begin
      mZn_p10 <= 'd0;
      mZn_p11 <= 'd0;
    end else begin
      mZn_p10 <= mZn_p00;
      mZn_p11 <= { mZn_p11_head, mZn_p11_tail };
    end
  end

  assign mZn_p11a[13] = mZn_p11[13];
  assign mZn_p11a[12:0] = mZn_p11[12:0] + { 10'b0, mZpC };

  always @ ( posedge clk ) begin
  //always @ (*) begin
    mZn0 <= mZn_p11a + mZn_p10;
    //mZn0 = mZn_p11a + mZn_p10;
  end

  assign mZpn = mZp0 - mZn0;
  
  /********** Deligent reduction to [-57344, 57344] **********/
  assign mQ = (mZpn > 57344) ? ('sd114689) : ('sd0);
  /************ Lazy Reduction to [] ************/
  //assign mQ = (??????) ? ('sd114689) : ('sd0);

  always @ ( posedge clk ) begin
    outZ <= mZpn - mQ;
  end

endmodule

