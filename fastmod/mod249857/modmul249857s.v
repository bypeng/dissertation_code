/*******************************************************************
 * Signed Modular Multiplication with Prime Q = 249857
 *
 * Author: Bo-Yuan Peng
 *
 * Description:
 * This is a verilog module doing signed modular multiplication
 *                 outC == inA * inB (mod^{+-} 249857)
 * 
 *                                   Diligent                 Lazy
 * -- inA:  signed 18-bit integer in [-124928  , 124928  ] or [].
 * -- inB:  signed 18-bit integer in [-124928  , 124928  ] or [].
 * -- inZ:  signed 35-bit integer in [-124928^2, 124928^2] or [].
 * -- outC: signed 18-bit integer in [-124928  , 124928  ] or [].
 *
 * Version Info:
 *    Oct. 4,2022: 0.1.0 reation of the module.
 *                       module design complete without critical
 *                       path length control.
 *******************************************************************/

module modmul249857s (
  input                     clk,
  input                     rst,
  //input signed      [17:0]  inA,
  //input signed      [17:0]  inB,
  input signed      [34:0]  inZ,
  output reg signed [17:0]  outZ
) ;

  //reg signed        [34:0]  mZ;
  wire signed       [34:0]  mZ;

  wire              [6:0]   mZpu_p0;
  reg               [6:0]   mZpu_p1a;
  wire              [5:0]   mZpu_p1b;
  wire              [6:0]   mZpu_p1;
  wire              [7:0]   mZpu;
  reg               [5:0]   mZnu_p0;
  wire              [6:0]   mZnu;

  wire              [12:0]  mZnl_p0;
  wire              [1:0]   mZnl_p1ll;
  wire              [7:0]   mZnl_p1l;
  wire              [9:0]   mZnl_p1;

  reg               [12:0]  mZpl;
  reg               [13:0]  mZnl;
  reg               [8:0]   mZpnu;

  wire              [6:0]   mZp2u;
  wire              [5:0]   mZp3u;

  wire              [2:0]   mZn3l_p0a;
  wire                      mZn3l_p0a_b2P;
  wire                      mZn3l_p0a_b2N;
  wire              [15:0]  mZn3l_p0;

  reg               [17:0]  mZp;
  reg               [15:0]  mZn;

  wire signed       [18:0]  mZpn;
  wire signed       [18:0]  mZpnQ;

  assign mZ = inZ;
  //always @ ( posedge clk ) begin
  //  if(rst) begin
  //    mZ <= 'sd0;
  //  end else begin
  //    //mZ <= inA * inB;
  //    mZ <= inZ;
  //  end
  //end

  assign mZpu_p0 = { 1'b0, mZ[17:12] } + { 1'b0, mZ[26:24], mZ[26:24] };
  always @ (*) begin
    case({ mZ[34], mZ[30], mZ[28], mZ[27] })
      4'h0:    mZpu_p1a = 7'd0;
      4'h1:    mZpu_p1a = 7'd11;
      4'h2:    mZpu_p1a = 7'd22;
      4'h3:    mZpu_p1a = 7'd33;
      4'h4:    mZpu_p1a = 7'd26;
      4'h5:    mZpu_p1a = 7'd37;
      4'h6:    mZpu_p1a = 7'd48;
      4'h7:    mZpu_p1a = 7'd59;

      4'h8:    mZpu_p1a = 7'd12;
      4'h9:    mZpu_p1a = 7'd23;
      4'ha:    mZpu_p1a = 7'd34;
      4'hb:    mZpu_p1a = 7'd45;

      4'hc:    mZpu_p1a = 7'd38;
      4'hd:    mZpu_p1a = 7'd49;
      4'he:    mZpu_p1a = 7'd60;
      default: mZpu_p1a = 7'd71;
    endcase
  end
  assign mZpu_p1b = { 1'b0, mZ[21:18], 1'b0} + { 2'b0, mZ[21:18] };
  assign mZpu_p1 = mZpu_p1a + { 1'b0, mZpu_p1b };
  assign mZpu = { 1'b0, mZpu_p0 } + { 1'b0, mZpu_p1 };

  always @ (*) begin
    case({ mZ[29], mZ[23], mZ[22] })
      4'h0:    mZnu_p0 = 6'd0;
      4'h1:    mZnu_p0 = 6'd13;
      4'h2:    mZnu_p0 = 6'd26;
      4'h3:    mZnu_p0 = 6'd39;
      4'h4:    mZnu_p0 = 6'd17;
      4'h5:    mZnu_p0 = 6'd30;
      4'h6:    mZnu_p0 = 6'd43;
      default: mZnu_p0 = 6'd56;
    endcase
  end
  assign mZnu = { 1'b0, mZ[33:31], mZ[33:31] } + { 1'b0, mZnu_p0 };

  assign mZnl_p0 = { 1'b0, mZ[29:18] } + { 1'b0, mZ[33:22] };
  assign mZnl_p1ll = { 1'b0, mZ[34] } + { 1'b0, mZ[29] } ;
  assign mZnl_p1l = ( { 1'b0, mZ[33:27] } + { 1'b0, mZ[34], mZ[34], 1'b0, mZ[34], 1'b0, mZnl_p1ll } ) + ( { 4'b0, mZ[33:30] } + { 5'b0, mZ[33:31] } );
  assign mZnl_p1 = { mZ[34], mZ[34], mZnl_p1l };

  always @ ( posedge clk ) begin
    if(rst) begin
      mZpl <= 'd0;
      mZnl <= 'd0;
      mZpnu <= 'd0;
    end else begin
      mZpl    = { 3'b0, mZ[33:24] } + { 1'b0, mZ[11:0] };
      mZnl    = { 1'b0, mZnl_p0 } + { 4'b0, mZnl_p1 };
      mZpnu <= { 1'b0, mZpu } - { 2'b0, mZnu };
    end
  end

  assign mZp2u         = { 1'b0, mZpnu[5:0] } + ( { 4'b0, mZpnu[7:6], mZpl[12] } + { 5'b0, mZpnu[7:6] } );
  assign mZp3u         = mZp2u[5:0] + { 4'b0, mZp2u[6], mZp2u[6] };

  assign mZn3l_p0a     = { 1'b0, mZpnu[7:6] } + { 2'b0, mZp2u[6] };
  assign mZn3l_p0a_b2P = (   mZn3l_p0a[2]  && mZpnu[8] );
  assign mZn3l_p0a_b2N = ( (~mZn3l_p0a[2]) && mZpnu[8] );
  assign mZn3l_p0      = { mZpnu[8], mZn3l_p0a_b2P, { 12 { mZn3l_p0a_b2N } }, mZn3l_p0a[1:0] };

  always @ ( posedge clk ) begin
    if(rst) begin
      mZp <= 'd0;
      mZn <= 'd0;
    end else begin
      mZp <= { mZp3u, mZpl[11:0] };
      mZn <= mZn3l_p0 + { 2'b0, mZnl };
    end
  end

  assign mZpn = { 1'b0, mZp } - { 3'b0, mZn } ;
  
  /********** Deligent reduction to [-124928, 124928] **********/
  assign mZpnQ = mZpn - 'sd249857;
  assign mZpn_G = (mZpn > 'sd124928);
  /************ Lazy Reduction to [] ************/
  //assign mQ = (??????) ? ('sd7681) : ('sd0);

  always @ ( posedge clk ) begin
    outZ <= mZpn_G ? mZpnQ : mZpn;
  end

endmodule

