module mod5167Svec34 (
    input       [33:0] z_in,
    output      [11:0] p0,
    output reg  [11:0] p1,
    output      [11:0] n0,
    output reg  [12:0] n1,
    output reg  [11:0] n2,
    output reg  [12:0] n3
) ;

    reg         [ 6:0] n0_M;

    assign p0 = z_in[11:0];

    always @ (*) begin
        case({ z_in[32], z_in[16], z_in[15] })
            3'h0: p1 = 12'd0;
            3'h1: p1 = 12'd1766;
            3'h2: p1 = 12'd3532;
            3'h3: p1 = 12'd131;
            3'h4: p1 = 12'd1886;
            3'h5: p1 = 12'd3652;
            3'h6: p1 = 12'd251;
            3'h7: p1 = 12'd2017;
        endcase
    end

    always @ (*) begin
        //case({ z_in[29], z_in[28], z_in[27], z_in[26], z_in[25], z_in[24] })
        //    6'h00: n0 = 12'd0;
        //    6'h01: n0 = 12'd33;
        //    6'h02: n0 = 12'd66;
        //    6'h03: n0 = 12'd99;
        //    6'h04: n0 = 12'd132;
        //    6'h05: n0 = 12'd165;
        //    6'h06: n0 = 12'd198;
        //    6'h07: n0 = 12'd231;
        //    6'h08: n0 = 12'd264;
        //    6'h09: n0 = 12'd297;
        //    6'h0a: n0 = 12'd330;
        //    6'h0b: n0 = 12'd363;
        //    6'h0c: n0 = 12'd396;
        //    6'h0d: n0 = 12'd429;
        //    6'h0e: n0 = 12'd462;
        //    6'h0f: n0 = 12'd495;
        //    6'h10: n0 = 12'd528;
        //    6'h11: n0 = 12'd561;
        //    6'h12: n0 = 12'd594;
        //    6'h13: n0 = 12'd627;
        //    6'h14: n0 = 12'd660;
        //    6'h15: n0 = 12'd693;
        //    6'h16: n0 = 12'd726;
        //    6'h17: n0 = 12'd759;
        //    6'h18: n0 = 12'd792;
        //    6'h19: n0 = 12'd825;
        //    6'h1a: n0 = 12'd858;
        //    6'h1b: n0 = 12'd891;
        //    6'h1c: n0 = 12'd924;
        //    6'h1d: n0 = 12'd957;
        //    6'h1e: n0 = 12'd990;
        //    6'h1f: n0 = 12'd1023;
        //    6'h20: n0 = 12'd1056;
        //    6'h21: n0 = 12'd1089;
        //    6'h22: n0 = 12'd1122;
        //    6'h23: n0 = 12'd1155;
        //    6'h24: n0 = 12'd1188;
        //    6'h25: n0 = 12'd1221;
        //    6'h26: n0 = 12'd1254;
        //    6'h27: n0 = 12'd1287;
        //    6'h28: n0 = 12'd1320;
        //    6'h29: n0 = 12'd1353;
        //    6'h2a: n0 = 12'd1386;
        //    6'h2b: n0 = 12'd1419;
        //    6'h2c: n0 = 12'd1452;
        //    6'h2d: n0 = 12'd1485;
        //    6'h2e: n0 = 12'd1518;
        //    6'h2f: n0 = 12'd1551;
        //    6'h30: n0 = 12'd1584;
        //    6'h31: n0 = 12'd1617;
        //    6'h32: n0 = 12'd1650;
        //    6'h33: n0 = 12'd1683;
        //    6'h34: n0 = 12'd1716;
        //    6'h35: n0 = 12'd1749;
        //    6'h36: n0 = 12'd1782;
        //    6'h37: n0 = 12'd1815;
        //    6'h38: n0 = 12'd1848;
        //    6'h39: n0 = 12'd1881;
        //    6'h3a: n0 = 12'd1914;
        //    6'h3b: n0 = 12'd1947;
        //    6'h3c: n0 = 12'd1980;
        //    6'h3d: n0 = 12'd2013;
        //    6'h3e: n0 = 12'd2046;
        //    6'h3f: n0 = 12'd2079;
        //endcase
        n0_M = { 1'b0, z_in[29:24] } + { 6'b0, z_in[29] };
    end
    assign n0 = { n0_M, z_in[28:24] };

    always @ (*) begin
        case({ z_in[30], z_in[23], z_in[19], z_in[18], z_in[13] })
            5'h00: n1 = 13'd0;
            5'h01: n1 = 13'd2142;
            5'h02: n1 = 13'd1373;
            5'h03: n1 = 13'd3515;
            5'h04: n1 = 13'd2746;
            5'h05: n1 = 13'd4888;
            5'h06: n1 = 13'd4119;
            5'h07: n1 = 13'd1094;
            5'h08: n1 = 13'd2600;
            5'h09: n1 = 13'd4742;
            5'h0a: n1 = 13'd3973;
            5'h0b: n1 = 13'd948;
            5'h0c: n1 = 13'd179;
            5'h0d: n1 = 13'd2321;
            5'h0e: n1 = 13'd1552;
            5'h0f: n1 = 13'd3694;
            5'h10: n1 = 13'd2112;
            5'h11: n1 = 13'd4254;
            5'h12: n1 = 13'd3485;
            5'h13: n1 = 13'd460;
            5'h14: n1 = 13'd4858;
            5'h15: n1 = 13'd1833;
            5'h16: n1 = 13'd1064;
            5'h17: n1 = 13'd3206;
            5'h18: n1 = 13'd4712;
            5'h19: n1 = 13'd1687;
            5'h1a: n1 = 13'd918;
            5'h1b: n1 = 13'd3060;
            5'h1c: n1 = 13'd2291;
            5'h1d: n1 = 13'd4433;
            5'h1e: n1 = 13'd3664;
            5'h1f: n1 = 13'd639;
        endcase
    end

    always @ (*) begin
        case({ z_in[22], z_in[21], z_in[20], z_in[12] })
            4'h0: n2 = 12'd0;
            4'h1: n2 = 12'd1071;
            4'h2: n2 = 12'd325;
            4'h3: n2 = 12'd1396;
            4'h4: n2 = 12'd650;
            4'h5: n2 = 12'd1721;
            4'h6: n2 = 12'd975;
            4'h7: n2 = 12'd2046;
            4'h8: n2 = 12'd1300;
            4'h9: n2 = 12'd2371;
            4'ha: n2 = 12'd1625;
            4'hb: n2 = 12'd2696;
            4'hc: n2 = 12'd1950;
            4'hd: n2 = 12'd3021;
            4'he: n2 = 12'd2275;
            4'hf: n2 = 12'd3346;
        endcase
    end

    always @ (*) begin
        case({ z_in[33], z_in[31], z_in[17], z_in[14] })
            4'h0: n3 = 13'd0;
            4'h1: n3 = 13'd4284;
            4'h2: n3 = 13'd3270;
            4'h3: n3 = 13'd2387;
            4'h4: n3 = 13'd4224;
            4'h5: n3 = 13'd3341;
            4'h6: n3 = 13'd2327;
            4'h7: n3 = 13'd1444;
            4'h8: n3 = 13'd3772;
            4'h9: n3 = 13'd2889;
            4'ha: n3 = 13'd1875;
            4'hb: n3 = 13'd992;
            4'hc: n3 = 13'd2829;
            4'hd: n3 = 13'd1946;
            4'he: n3 = 13'd932;
            4'hf: n3 = 13'd49;
        endcase
    end

endmodule