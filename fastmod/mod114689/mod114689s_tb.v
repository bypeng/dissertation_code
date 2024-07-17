`timescale 1ns/100ps

module mod114689s_tb;

    parameter HALFCLK = 5;

    /* clock setting */
    reg clk;
        initial begin
        clk=1;
    end
    always #(HALFCLK) clk<=~clk;

    /* vcd file setting */
    initial begin
        $fsdbDumpfile("mod114689s_tb.fsdb");
        $fsdbDumpvars;
        #10000000000;
        $finish;
    end

    wire [1023:0] equals;

    wire equal_all;
    assign equal_all = &equals;

    genvar prefix;
    generate
        for(prefix = 'd0; prefix < 'd1024; prefix = prefix + 'd1) begin : tester
            reg rst;

            reg [22:0] postfix;

            wire signed [32:0] inZ;
            wire signed [16:0] outZ;

            wire signed [17:0]  outZ_ref;
            wire signed [17:0]  outZ_ref_c;
            reg         [17:0]  outZ_ref_c_r0;
            reg         [17:0]  outZ_ref_c_r1;
            reg         [17:0]  outZ_ref_c_r2;

            assign inZ = { prefix[9:0], postfix };

            assign outZ_ref = inZ % 18'sd114689;
            assign outZ_ref_c = (outZ_ref > 18'sd57344) ? (outZ_ref - 18'sd114689) :
                                (outZ_ref < -18'sd57344) ? (outZ_ref + 18'sd114689) : outZ_ref;
            
            always @ (posedge clk) begin
              outZ_ref_c_r0 <= outZ_ref_c;
              outZ_ref_c_r1 <= outZ_ref_c_r0;
              outZ_ref_c_r2 <= outZ_ref_c_r1;
            end

            wire equal;
            wire equalp;
            wire equal0;
            wire equaln;

            assign equalp = ( { outZ[16], outZ } - 18'sd114689 == outZ_ref_c_r2 );
            assign equal0 = ( { outZ[16], outZ }               == outZ_ref_c_r2 );
            assign equaln = ( { outZ[16], outZ } + 18'sd114689 == outZ_ref_c_r2 );

            assign equal = equalp | equal0 | equaln;

            assign equals[prefix] = equal;

            integer index;
            initial begin

                rst = 1'b0;
                #(2*HALFCLK);
                rst = 1'b1;
                #(2*HALFCLK);
                rst = 1'b0;

                for (index = 'h0; index <= 'h7fffff; index = index + 'h1) begin
                //for (index = 'h0; index <= 'hffff; index = index + 'h1) begin
                //for (index = 'h7b0000; index <= 'h7fffff; index = index + 'h1) begin

                    if (!(index & 'hfff) && (prefix == 0)) $display("index == %x", index);

                    postfix = index;
                    #(8*HALFCLK);
                end

                $finish;
            end 

            modmul114689s mod_inst ( .clk(clk), .rst(rst), .inZ(inZ), .outZ(outZ) );
        end // tester
    endgenerate

    always @ (posedge clk) begin
      if(!equal_all) begin
        $display("WARNING! equals fails at %t!", $realtime);
      end
    end

endmodule

