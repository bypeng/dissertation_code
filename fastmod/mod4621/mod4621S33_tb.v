`timescale 1ns/100ps

module mod4621S33_tb;

  parameter HALFCLK = 5;

  /* clock setting */
  reg clk;
    initial begin
    clk=1;
  end
  always #(HALFCLK) clk<=~clk;

  /* vcd file setting */
  initial begin
    $fsdbDumpfile("mod4621S33_tb.fsdb");
    $fsdbDumpvars;
    #10000000000;
    $finish;
  end

  wire [255:0] equals;

  wire equal_all;
  assign equal = &equals;

  genvar prefix;
  generate
    for(prefix = 'd0; prefix < 'd256; prefix = prefix + 'd1) begin : tester
      reg rst;

      reg [24: 0] postfix;
      wire signed [32: 0] inZ;
      wire signed [12: 0] outZ;
      wire signed [13: 0]  outZ_ref;
      wire signed [13: 0]  outZ_ref_c;
      reg signed  [13: 0]  outZ_ref_c_r0;
      reg signed  [13: 0]  outZ_ref_c_r1;
      reg signed  [13: 0]  outZ_ref_c_r2;

      assign inZ = { prefix[7:0], postfix };

      assign outZ_ref = inZ % 14'sd4621;
      assign outZ_ref_c = (outZ_ref >  14'sd2310) ? (outZ_ref - 14'sd4621) :
                          (outZ_ref < -14'sd2310) ? (outZ_ref + 14'sd4621) : outZ_ref;

      always @ (posedge clk) begin
        outZ_ref_c_r0 <= outZ_ref_c;
        outZ_ref_c_r1 <= outZ_ref_c_r0;
        outZ_ref_c_r2 <= outZ_ref_c_r1;
      end

      wire equal;
      wire equalp;
      wire equal0;
      wire equaln;

      assign equalp = ( { 1'b0, outZ } - 14'sd4621  == outZ_ref_c_r2 );
      assign equal0 = ( {{ 1'b0, outZ }}               == outZ_ref_c_r2 );
      assign equaln = ( { 1'b0, outZ } + 14'sd4621  == outZ_ref_c_r2 );

      //assign equal = equalp | equal0 | equaln;
      assign equal = equal0;

      assign equals[prefix] = equal;

      integer index;
      initial begin

        rst = 1'b0;
        #(2*HALFCLK);
        rst = 1'b1;
        #(2*HALFCLK);
        rst = 1'b0;

        for (index = 'h0; index <= 'h1ffffff; index = index + 'h1) begin

            if (!(index & 'hffff) && (prefix == 0)) $display("index == %x", index);

            postfix = index;
            #(8*HALFCLK);
        end

        $finish;
      end 

      mod4621S33 mod_inst ( .clk(clk), .Reset(rst), .In(inZ), .Out(outZ) );
    end // tester
  endgenerate

  always @ (posedge clk) begin
    if(!equal_all) begin
      $display("WARNING! equals = %t!", $realtime);
      $display("equals = %X", equals);
      #(16*HALFCLK);
      $finish;
    end
  end

endmodule

