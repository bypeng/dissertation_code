`timescale 1ns/100ps

/*******************************************************************
 * Testbench for Signed Modular Multiplication with Prime Q = 7681
 *
 * Author: Bo-Yuan Peng
 *
 * Description:
 * This is a verilog module testing signed modular multiplication
 *             outC == inA * inB (mod^{+-} 7681)
 * 
 *                                      Diligent          Lazy
 * -- inA:  signed 13-bit integer in [-3840, 3840] or [-3584, 4095].
 * -- inB:  signed 13-bit integer in [-3840, 3840] or [-3584, 4095].
 * -- outC: signed 13-bit integer in [-3840, 3840] or [-3584, 4095].
 *
 * Version Info:
 *    Mar.19,2021: 0.0.1 creation of the module.
 *    Mar.31.2021: 0.1.0 module design complete without critical
 *                       path length control.
 *******************************************************************/

module modmul7681s_tb;

  parameter primeQ = 14'sd7681;
  localparam pQhalf = (primeQ - 1) / 2;
  localparam CLKPRD_HALF = 5;
  localparam CLKPRD = CLKPRD_HALF * 2;

  /* clock setting */
  reg clk;
  initial begin
    clk=1;
  end
  always #CLKPRD_HALF clk<=~clk;

  /* vcd file setting */
  initial begin
    $fsdbDumpfile("modmul7681s_tb.fsdb");
    $fsdbDumpvars;
  end

  reg signed  [12:0]  inA;
  reg signed  [12:0]  inB;
  wire signed [12:0]  outC;

  reg  signed [24:0]  mZ_ref3;
  reg  signed [24:0]  mZ_ref2;
  reg  signed [24:0]  mZ_ref1;
  reg  signed [24:0]  mZ_ref;
  wire signed [12:0]  outC_ref;
  wire signed [13:0]  out2C_ref;

  integer             MAX_C;
  integer             MIN_C;

  wire equal;
  wire equalp;
  wire equal0;
  wire equaln;

  always @ ( posedge clk ) begin
    mZ_ref  <= mZ_ref1;
    mZ_ref1 <= mZ_ref2;
    mZ_ref2 <= mZ_ref3;
    mZ_ref3 <= inA * inB;
  end
  //assign mZ_ref = inA * inB;

  assign out2C_ref = mZ_ref % primeQ;
  assign outC_ref = (out2C_ref >  pQhalf) ? (out2C_ref - primeQ) :
                    (out2C_ref < -pQhalf) ? (out2C_ref + primeQ) :
                                             out2C_ref[12:0];

  assign equalp = ((outC - primeQ) == outC_ref);
  assign equal0 = ( outC == outC_ref);
  assign equaln = ((outC + primeQ) == outC_ref);

  assign equal = equalp | equal0 | equaln;

  initial begin
    MAX_C = -4096;
    MIN_C = 8191;
    #(CLKPRD_HALF);

    while(1) begin
      if(MAX_C < outC) MAX_C = outC;
      if(MIN_C > outC) MIN_C = outC;

      #(CLKPRD);
    end
  end

  initial begin
    inA = 'sd0;
    inB = 'sd0;

    #(CLKPRD_HALF);
    #(CLKPRD);

    for(inA = -pQhalf; inA <= pQhalf ; inA = inA + 'sd1) begin
    //for(inA = -(pQhalf >> 5); inA <= (pQhalf >> 5) ; inA = inA + 'sd1) begin
      for(inB = -pQhalf; inB <= pQhalf; inB = inB + 'sd1) begin
    //  for(inB = -(pQhalf >> 5); inB <= (pQhalf >> 5); inB = inB + 'sd1) begin
        #(CLKPRD);
      end
    end

    #(2*CLKPRD);

    $display("MAX(C) = %d\n", MAX_C);
    $display("MIN(C) = %d\n", MIN_C);

    $finish;
  end

  modmul7681s mm0 (
    .clk(clk),
    .inA(inA),
    .inB(inB),
    .outC(outC)
  ) ;

endmodule

