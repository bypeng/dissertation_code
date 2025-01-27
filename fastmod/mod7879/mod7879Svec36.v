module mod7879Svec36 (
    input       [35:0] z_in,
    output      [11:0] p0,
    output reg  [12:0] p1,
    output reg  [11:0] p2,
    output reg  [12:0] p3,
    output reg  [11:0] n0,
    output reg  [12:0] n1
) ;

    assign p0 = z_in[11:0];

    always @ (*) begin
        case({ z_in[35], z_in[28], z_in[25], z_in[23], z_in[17] })
            5'h00: p1 = 13'd0;
            5'h01: p1 = 13'd5008;
            5'h02: p1 = 13'd5352;
            5'h03: p1 = 13'd2481;
            5'h04: p1 = 13'd5650;
            5'h05: p1 = 13'd2779;
            5'h06: p1 = 13'd3123;
            5'h07: p1 = 13'd252;
            5'h08: p1 = 13'd5805;
            5'h09: p1 = 13'd2934;
            5'h0a: p1 = 13'd3278;
            5'h0b: p1 = 13'd407;
            5'h0c: p1 = 13'd3576;
            5'h0d: p1 = 13'd705;
            5'h0e: p1 = 13'd1049;
            5'h0f: p1 = 13'd6057;
            5'h10: p1 = 13'd5465;
            5'h11: p1 = 13'd2594;
            5'h12: p1 = 13'd2938;
            5'h13: p1 = 13'd67;
            5'h14: p1 = 13'd3236;
            5'h15: p1 = 13'd365;
            5'h16: p1 = 13'd709;
            5'h17: p1 = 13'd5717;
            5'h18: p1 = 13'd3391;
            5'h19: p1 = 13'd520;
            5'h1a: p1 = 13'd864;
            5'h1b: p1 = 13'd5872;
            5'h1c: p1 = 13'd1162;
            5'h1d: p1 = 13'd6170;
            5'h1e: p1 = 13'd6514;
            5'h1f: p1 = 13'd3643;
        endcase
    end

    always @ (*) begin
        case({ z_in[34], z_in[20], z_in[15], z_in[14], z_in[13] })
            5'h00: p2 = 12'd0;
            5'h01: p2 = 12'd313;
            5'h02: p2 = 12'd626;
            5'h03: p2 = 12'd939;
            5'h04: p2 = 12'd1252;
            5'h05: p2 = 12'd1565;
            5'h06: p2 = 12'd1878;
            5'h07: p2 = 12'd2191;
            5'h08: p2 = 12'd669;
            5'h09: p2 = 12'd982;
            5'h0a: p2 = 12'd1295;
            5'h0b: p2 = 12'd1608;
            5'h0c: p2 = 12'd1921;
            5'h0d: p2 = 12'd2234;
            5'h0e: p2 = 12'd2547;
            5'h0f: p2 = 12'd2860;
            5'h10: p2 = 12'd1207;
            5'h11: p2 = 12'd1520;
            5'h12: p2 = 12'd1833;
            5'h13: p2 = 12'd2146;
            5'h14: p2 = 12'd2459;
            5'h15: p2 = 12'd2772;
            5'h16: p2 = 12'd3085;
            5'h17: p2 = 12'd3398;
            5'h18: p2 = 12'd1876;
            5'h19: p2 = 12'd2189;
            5'h1a: p2 = 12'd2502;
            5'h1b: p2 = 12'd2815;
            5'h1c: p2 = 12'd3128;
            5'h1d: p2 = 12'd3441;
            5'h1e: p2 = 12'd3754;
            5'h1f: p2 = 12'd4067;
        endcase
    end

    always @ (*) begin
        case({ z_in[24], z_in[22], z_in[21], z_in[18], z_in[16] })
            5'h00: p3 = 13'd0;
            5'h01: p3 = 13'd2504;
            5'h02: p3 = 13'd2137;
            5'h03: p3 = 13'd4641;
            5'h04: p3 = 13'd1338;
            5'h05: p3 = 13'd3842;
            5'h06: p3 = 13'd3475;
            5'h07: p3 = 13'd5979;
            5'h08: p3 = 13'd2676;
            5'h09: p3 = 13'd5180;
            5'h0a: p3 = 13'd4813;
            5'h0b: p3 = 13'd7317;
            5'h0c: p3 = 13'd4014;
            5'h0d: p3 = 13'd6518;
            5'h0e: p3 = 13'd6151;
            5'h0f: p3 = 13'd776;
            5'h10: p3 = 13'd2825;
            5'h11: p3 = 13'd5329;
            5'h12: p3 = 13'd4962;
            5'h13: p3 = 13'd7466;
            5'h14: p3 = 13'd4163;
            5'h15: p3 = 13'd6667;
            5'h16: p3 = 13'd6300;
            5'h17: p3 = 13'd925;
            5'h18: p3 = 13'd5501;
            5'h19: p3 = 13'd126;
            5'h1a: p3 = 13'd7638;
            5'h1b: p3 = 13'd2263;
            5'h1c: p3 = 13'd6839;
            5'h1d: p3 = 13'd1464;
            5'h1e: p3 = 13'd1097;
            5'h1f: p3 = 13'd3601;
        endcase
    end

    always @ (*) begin
        case({ z_in[32], z_in[31], z_in[30], z_in[27] })
            4'h0: n0 = 12'd0;
            4'h1: n0 = 12'd1037;
            4'h2: n0 = 12'd417;
            4'h3: n0 = 12'd1454;
            4'h4: n0 = 12'd834;
            4'h5: n0 = 12'd1871;
            4'h6: n0 = 12'd1251;
            4'h7: n0 = 12'd2288;
            4'h8: n0 = 12'd1668;
            4'h9: n0 = 12'd2705;
            4'ha: n0 = 12'd2085;
            4'hb: n0 = 12'd3122;
            4'hc: n0 = 12'd2502;
            4'hd: n0 = 12'd3539;
            4'he: n0 = 12'd2919;
            4'hf: n0 = 12'd3956;
        endcase
    end

    always @ (*) begin
        case({ z_in[33], z_in[29], z_in[26], z_in[19], z_in[12] })
            5'h00: n1 = 13'd0;
            5'h01: n1 = 13'd3783;
            5'h02: n1 = 13'd3605;
            5'h03: n1 = 13'd7388;
            5'h04: n1 = 13'd4458;
            5'h05: n1 = 13'd362;
            5'h06: n1 = 13'd184;
            5'h07: n1 = 13'd3967;
            5'h08: n1 = 13'd4148;
            5'h09: n1 = 13'd52;
            5'h0a: n1 = 13'd7753;
            5'h0b: n1 = 13'd3657;
            5'h0c: n1 = 13'd727;
            5'h0d: n1 = 13'd4510;
            5'h0e: n1 = 13'd4332;
            5'h0f: n1 = 13'd236;
            5'h10: n1 = 13'd3336;
            5'h11: n1 = 13'd7119;
            5'h12: n1 = 13'd6941;
            5'h13: n1 = 13'd2845;
            5'h14: n1 = 13'd7794;
            5'h15: n1 = 13'd3698;
            5'h16: n1 = 13'd3520;
            5'h17: n1 = 13'd7303;
            5'h18: n1 = 13'd7484;
            5'h19: n1 = 13'd3388;
            5'h1a: n1 = 13'd3210;
            5'h1b: n1 = 13'd6993;
            5'h1c: n1 = 13'd4063;
            5'h1d: n1 = 13'd7846;
            5'h1e: n1 = 13'd7668;
            5'h1f: n1 = 13'd3572;
        endcase
    end

endmodule
