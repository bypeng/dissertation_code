`include "params.v"

module rp1013q7177encode_param ( state_max, state_l, state_e, state_s,
                                param_state_ct, param_r_max,
                                param_m0, param_outs1, param_outsl
) ; 

  output      [4:0]               state_max;

  input       [4:0]               state_l;
  input       [4:0]               state_e;
  input       [4:0]               state_s;
  output reg  [`RP_DEPTH-1:0]     param_state_ct;
  output reg  [`RP_DEPTH-1:0]     param_r_max;
  output reg  [`RP_D_SIZE-1:0]    param_m0;
  output reg  [1:0]               param_outs1;
  output reg  [2:0]               param_outsl;

  assign state_max = 5'd10;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
      5'd0   : param_state_ct = 10'd1013;
      5'd1   : param_state_ct = 10'd507;
      5'd2   : param_state_ct = 10'd253;
      5'd3   : param_state_ct = 10'd127;
      5'd4   : param_state_ct = 10'd63;
      5'd5   : param_state_ct = 10'd31;
      5'd6   : param_state_ct = 10'd15;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd1013;
      5'd1   : param_r_max = 10'd507;
      5'd2   : param_r_max = 10'd254;
      5'd3   : param_r_max = 10'd127;
      5'd4   : param_r_max = 10'd64;
      5'd5   : param_r_max = 10'd32;
      5'd6   : param_r_max = 10'd16;
      5'd7   : param_r_max = 10'd8;
      5'd8   : param_r_max = 10'd4;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd7177;
      5'd2   : param_m0 = 14'd786;
      5'd3   : param_m0 = 14'd2414;
      5'd4   : param_m0 = 14'd89;
      5'd5   : param_m0 = 14'd7921;
      5'd6   : param_m0 = 14'd958;
      5'd7   : param_m0 = 14'd3586;
      5'd8   : param_m0 = 14'd197;
      5'd9   : param_m0 = 14'd152;
      5'd10  : param_m0 = 14'd91;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // Regular output bytes count for each round.
    case(state_e)  // Note: It is the special case for the round of |R| <= 2.
                   // 2 bytes outputed then set to 2.
                   // 1 byte outputed then set to 1.
                   // 0 bytes outputed then set to 0.
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd1;
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd0;
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd2;
      5'd8   : param_outs1 = 2'd1;
      5'd9   : param_outs1 = 2'd1;
      default: param_outs1 = 2'd0;
    endcase
  end

  always @ (*) begin // The last-pair output bytes count for each round.
    case(state_e)  // Note: It is the special case for the round of |R| <= 2.
                   // 2 bytes outputed then set to 2.
                   // 1 byte outputed then set to 1.
                   // 0 bytes outputed then set to 0.
                   // Note: output them all in the last round.
                   // Eg. In 761-4591 case: 4 bytes.
      5'd1   : param_outsl = 3'd0;
      5'd2   : param_outsl = 3'd0;
      5'd3   : param_outsl = 3'd2;
      5'd4   : param_outsl = 3'd0;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd2;
      5'd7   : param_outsl = 3'd1;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd1;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp1013q2393encode_param ( state_max, state_l, state_e, state_s,
                                param_state_ct, param_r_max,
                                param_m0, param_outs1, param_outsl
) ; 

  output      [4:0]               state_max;

  input       [4:0]               state_l;
  input       [4:0]               state_e;
  input       [4:0]               state_s;
  output reg  [`RP_DEPTH-1:0]     param_state_ct;
  output reg  [`RP_DEPTH-1:0]     param_r_max;
  output reg  [`RP_D_SIZE-1:0]    param_m0;
  output reg  [1:0]               param_outs1;
  output reg  [2:0]               param_outsl;

  assign state_max = 5'd10;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
      5'd0   : param_state_ct = 10'd1013;
      5'd1   : param_state_ct = 10'd507;
      5'd2   : param_state_ct = 10'd253;
      5'd3   : param_state_ct = 10'd127;
      5'd4   : param_state_ct = 10'd63;
      5'd5   : param_state_ct = 10'd31;
      5'd6   : param_state_ct = 10'd15;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd3;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd1013;
      5'd1   : param_r_max = 10'd507;
      5'd2   : param_r_max = 10'd254;
      5'd3   : param_r_max = 10'd127;
      5'd4   : param_r_max = 10'd64;
      5'd5   : param_r_max = 10'd32;
      5'd6   : param_r_max = 10'd16;
      5'd7   : param_r_max = 10'd8;
      5'd8   : param_r_max = 10'd4;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd2393;
      5'd2   : param_m0 = 14'd88;
      5'd3   : param_m0 = 14'd7744;
      5'd4   : param_m0 = 14'd916;
      5'd5   : param_m0 = 14'd3278;
      5'd6   : param_m0 = 14'd164;
      5'd7   : param_m0 = 14'd106;
      5'd8   : param_m0 = 14'd11236;
      5'd9   : param_m0 = 14'd1927;
      5'd10  : param_m0 = 14'd14506;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // Regular output bytes count for each round.
    case(state_e)  // Note: It is the special case for the round of |R| <= 2.
                   // 2 bytes outputed then set to 2.
                   // 1 byte outputed then set to 1.
                   // 0 bytes outputed then set to 0.
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd0;
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd1;
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd0;
      5'd8   : param_outs1 = 2'd2;
      5'd9   : param_outs1 = 2'd1;
      default: param_outs1 = 2'd0;
    endcase
  end

  always @ (*) begin // The last-pair output bytes count for each round.
    case(state_e)  // Note: It is the special case for the round of |R| <= 2.
                   // 2 bytes outputed then set to 2.
                   // 1 byte outputed then set to 1.
                   // 0 bytes outputed then set to 0.
                   // Note: output them all in the last round.
                   // Eg. In 761-4591 case: 4 bytes.
      5'd1   : param_outsl = 3'd0;
      5'd2   : param_outsl = 3'd0;
      5'd3   : param_outsl = 3'd2;
      5'd4   : param_outsl = 3'd0;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd1;
      5'd7   : param_outsl = 3'd1;
      5'd8   : param_outsl = 3'd2;
      5'd9   : param_outsl = 3'd1;
      5'd10  : param_outsl = 3'd4;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp1013q7177decode_param ( state_l, state_e, state_s,
                                state_max, param_r_max, param_ro_max, param_small_r2, param_small_r3,
                                param_state_ct, param_ri_offset, param_ri_len,
                                param_outoffset, param_outs1, param_outsl, 
                                param_m0, param_m0inv,
                                param_ro_offset
) ; 

  input       [4:0]               state_l;
  input       [4:0]               state_e;
  input       [4:0]               state_s;

  output      [4:0]               state_max;
  output      [`RP_DEPTH-2:0]     param_r_max;
  output      [`RP_DEPTH-1:0]     param_ro_max;
  output                          param_small_r2;
  output                          param_small_r3;

  output reg  [`RP_DEPTH:0]       param_state_ct;
  output reg  [`RP_DEPTH-2:0]     param_ri_offset;
  output reg  [`RP_DEPTH-2:0]     param_ri_len;
  output reg  [`OUT_DEPTH-1:0]    param_outoffset;
  output reg  [1:0]               param_outs1;
  output reg  [1:0]               param_outsl;
  output reg  [`RP_D_SIZE-1:0]    param_m0;
  output reg  [`RP_INV_SIZE-1:0]  param_m0inv;
  output reg  [`RP_DEPTH-2:0]     param_ro_offset;

  assign state_max = 5'd10;
  assign param_r_max = 'd506;
  assign param_ro_max = 'd1012;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd7;
      5'd3   : param_state_ct = 11'd15;
      5'd4   : param_state_ct = 11'd31;
      5'd5   : param_state_ct = 11'd63;
      5'd6   : param_state_ct = 11'd125;
      5'd7   : param_state_ct = 11'd253;
      5'd8   : param_state_ct = 11'd505;
      5'd9   : param_state_ct = 11'd1012;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd505;
      5'd2   : param_ri_offset = 9'd503;
      5'd3   : param_ri_offset = 9'd499;
      5'd4   : param_ri_offset = 9'd491;
      5'd5   : param_ri_offset = 9'd475;
      5'd6   : param_ri_offset = 9'd443;
      5'd7   : param_ri_offset = 9'd380;
      5'd8   : param_ri_offset = 9'd253;
      5'd9   : param_ri_offset = 9'd0;
      default: param_ri_offset = 9'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 9'd0;
      5'd2   : param_ri_len = 9'd1;
      5'd3   : param_ri_len = 9'd3;
      5'd4   : param_ri_len = 9'd7;
      5'd5   : param_ri_len = 9'd15;
      5'd6   : param_ri_len = 9'd31;
      5'd7   : param_ri_len = 9'd62;
      5'd8   : param_ri_len = 9'd126;
      5'd9   : param_ri_len = 9'd252;
      5'd10  : param_ri_len = 9'd505;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1620;
      5'd2   : param_outoffset = 11'd1618;
      5'd3   : param_outoffset = 11'd1614;
      5'd4   : param_outoffset = 11'd1599;
      5'd5   : param_outoffset = 11'd1582;
      5'd6   : param_outoffset = 11'd1519;
      5'd7   : param_outoffset = 11'd1519;
      5'd8   : param_outoffset = 11'd1265;
      5'd9   : param_outoffset = 11'd1012;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd1;
      5'd3   : param_outs1 = 2'd1;
      5'd4   : param_outs1 = 2'd2;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd2;
      5'd7   : param_outs1 = 2'd0;
      5'd8   : param_outs1 = 2'd2;
      5'd9   : param_outs1 = 2'd1;
      5'd10  : param_outs1 = 2'd2;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b0;
  assign param_small_r3 = 1'b0;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd1;
      5'd3   : param_outsl = 2'd1;
      5'd4   : param_outsl = 2'd1;
      5'd5   : param_outsl = 2'd2;
      5'd6   : param_outsl = 2'd1;
      5'd7   : param_outsl = 2'd3;
      5'd8   : param_outsl = 2'd2;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd91;
      5'd2   : param_m0 = 14'd152;
      5'd3   : param_m0 = 14'd197;
      5'd4   : param_m0 = 14'd3586;
      5'd5   : param_m0 = 14'd958;
      5'd6   : param_m0 = 14'd7921;
      5'd7   : param_m0 = 14'd89;
      5'd8   : param_m0 = 14'd2414;
      5'd9   : param_m0 = 14'd786;
      5'd10  : param_m0 = 14'd7177;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd1474920;
      5'd2   : param_m0inv = 27'd883011;
      5'd3   : param_m0inv = 27'd681308;
      5'd4   : param_m0inv = 27'd37428;
      5'd5   : param_m0inv = 27'd140102;
      5'd6   : param_m0inv = 27'd16944;
      5'd7   : param_m0inv = 27'd1508064;
      5'd8   : param_m0inv = 27'd55599;
      5'd9   : param_m0inv = 27'd170760;
      5'd10  : param_m0inv = 27'd18701;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd505;
      5'd2   : param_ro_offset = 9'd503;
      5'd3   : param_ro_offset = 9'd499;
      5'd4   : param_ro_offset = 9'd491;
      5'd5   : param_ro_offset = 9'd475;
      5'd6   : param_ro_offset = 9'd443;
      5'd7   : param_ro_offset = 9'd380;
      5'd8   : param_ro_offset = 9'd253;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

module rp1013q2393decode_param ( state_l, state_e, state_s,
                                state_max, param_r_max, param_ro_max, param_small_r2, param_small_r3,
                                param_state_ct, param_ri_offset, param_ri_len,
                                param_outoffset, param_outs1, param_outsl, 
                                param_m0, param_m0inv,
                                param_ro_offset
) ; 

  input       [4:0]               state_l;
  input       [4:0]               state_e;
  input       [4:0]               state_s;

  output      [4:0]               state_max;
  output      [`RP_DEPTH-2:0]     param_r_max;
  output      [`RP_DEPTH-1:0]     param_ro_max;
  output                          param_small_r2;
  output                          param_small_r3;

  output reg  [`RP_DEPTH:0]       param_state_ct;
  output reg  [`RP_DEPTH-2:0]     param_ri_offset;
  output reg  [`RP_DEPTH-2:0]     param_ri_len;
  output reg  [`OUT_DEPTH-1:0]    param_outoffset;
  output reg  [1:0]               param_outs1;
  output reg  [1:0]               param_outsl;
  output reg  [`RP_D_SIZE-1:0]    param_m0;
  output reg  [`RP_INV_SIZE-1:0]  param_m0inv;
  output reg  [`RP_DEPTH-2:0]     param_ro_offset;

  assign state_max = 5'd10;
  assign param_r_max = 'd506;
  assign param_ro_max = 'd1012;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd8;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd7;
      5'd3   : param_state_ct = 11'd15;
      5'd4   : param_state_ct = 11'd31;
      5'd5   : param_state_ct = 11'd63;
      5'd6   : param_state_ct = 11'd125;
      5'd7   : param_state_ct = 11'd253;
      5'd8   : param_state_ct = 11'd505;
      5'd9   : param_state_ct = 11'd1012;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd505;
      5'd2   : param_ri_offset = 9'd503;
      5'd3   : param_ri_offset = 9'd499;
      5'd4   : param_ri_offset = 9'd491;
      5'd5   : param_ri_offset = 9'd475;
      5'd6   : param_ri_offset = 9'd443;
      5'd7   : param_ri_offset = 9'd380;
      5'd8   : param_ri_offset = 9'd253;
      5'd9   : param_ri_offset = 9'd0;
      default: param_ri_offset = 9'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 9'd0;
      5'd2   : param_ri_len = 9'd1;
      5'd3   : param_ri_len = 9'd3;
      5'd4   : param_ri_len = 9'd7;
      5'd5   : param_ri_len = 9'd15;
      5'd6   : param_ri_len = 9'd31;
      5'd7   : param_ri_len = 9'd62;
      5'd8   : param_ri_len = 9'd126;
      5'd9   : param_ri_len = 9'd252;
      5'd10  : param_ri_len = 9'd505;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1419;
      5'd2   : param_outoffset = 11'd1417;
      5'd3   : param_outoffset = 11'd1409;
      5'd4   : param_outoffset = 11'd1408;
      5'd5   : param_outoffset = 11'd1392;
      5'd6   : param_outoffset = 11'd1329;
      5'd7   : param_outoffset = 11'd1266;
      5'd8   : param_outoffset = 11'd1012;
      5'd9   : param_outoffset = 11'd1012;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd3;
      5'd2   : param_outs1 = 2'd1;
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd0;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd2;
      5'd7   : param_outs1 = 2'd1;
      5'd8   : param_outs1 = 2'd2;
      5'd9   : param_outs1 = 2'd0;
      5'd10  : param_outs1 = 2'd2;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b0;
  assign param_small_r3 = 1'b0;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd1;
      5'd3   : param_outsl = 2'd2;
      5'd4   : param_outsl = 2'd1;
      5'd5   : param_outsl = 2'd1;
      5'd6   : param_outsl = 2'd1;
      5'd7   : param_outsl = 2'd3;
      5'd8   : param_outsl = 2'd2;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd14506;
      5'd2   : param_m0 = 14'd1927;
      5'd3   : param_m0 = 14'd11236;
      5'd4   : param_m0 = 14'd106;
      5'd5   : param_m0 = 14'd164;
      5'd6   : param_m0 = 14'd3278;
      5'd7   : param_m0 = 14'd916;
      5'd8   : param_m0 = 14'd7744;
      5'd9   : param_m0 = 14'd88;
      5'd10  : param_m0 = 14'd2393;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd9252;
      5'd2   : param_m0inv = 27'd69651;
      5'd3   : param_m0inv = 27'd11945;
      5'd4   : param_m0inv = 27'd1266204;
      5'd5   : param_m0inv = 27'd818400;
      5'd6   : param_m0inv = 27'd40945;
      5'd7   : param_m0inv = 27'd146525;
      5'd8   : param_m0inv = 27'd17331;
      5'd9   : param_m0inv = 27'd1525201;
      5'd10  : param_m0inv = 27'd56087;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd505;
      5'd2   : param_ro_offset = 9'd503;
      5'd3   : param_ro_offset = 9'd499;
      5'd4   : param_ro_offset = 9'd491;
      5'd5   : param_ro_offset = 9'd475;
      5'd6   : param_ro_offset = 9'd443;
      5'd7   : param_ro_offset = 9'd380;
      5'd8   : param_ro_offset = 9'd253;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

