`include "params.v"

module rp1277q7879encode_param ( state_max, state_l, state_e, state_s,
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

  assign state_max = 5'd11;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
      5'd0   : param_state_ct = 11'd1277;
      5'd1   : param_state_ct = 11'd639;
      5'd2   : param_state_ct = 11'd319;
      5'd3   : param_state_ct = 11'd159;
      5'd4   : param_state_ct = 11'd79;
      5'd5   : param_state_ct = 11'd39;
      5'd6   : param_state_ct = 11'd19;
      5'd7   : param_state_ct = 11'd9;
      5'd8   : param_state_ct = 11'd7;
      5'd9   : param_state_ct = 11'd5;
      5'd10  : param_state_ct = 11'd2;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 11'd1277;
      5'd1   : param_r_max = 11'd639;
      5'd2   : param_r_max = 11'd320;
      5'd3   : param_r_max = 11'd160;
      5'd4   : param_r_max = 11'd80;
      5'd5   : param_r_max = 11'd40;
      5'd6   : param_r_max = 11'd20;
      5'd7   : param_r_max = 11'd10;
      5'd8   : param_r_max = 11'd5;
      5'd9   : param_r_max = 11'd3;
      5'd10  : param_r_max = 11'd2;
      default: param_r_max = 11'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd7879;
      5'd2   : param_m0 = 14'd948;
      5'd3   : param_m0 = 14'd3511;
      5'd4   : param_m0 = 14'd189;
      5'd5   : param_m0 = 14'd140;
      5'd6   : param_m0 = 14'd77;
      5'd7   : param_m0 = 14'd5929;
      5'd8   : param_m0 = 14'd537;
      5'd9   : param_m0 = 14'd1127;
      5'd10  : param_m0 = 14'd4962;
      5'd11  : param_m0 = 14'd376;
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
      5'd4   : param_outs1 = 2'd1;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd0;
      5'd7   : param_outs1 = 2'd2;
      5'd8   : param_outs1 = 2'd1;
      5'd9   : param_outs1 = 2'd1;
      5'd10  : param_outs1 = 2'd2;
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
      5'd4   : param_outsl = 3'd1;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd0;
      5'd7   : param_outsl = 3'd2;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd0;
      5'd10  : param_outsl = 3'd0;
      5'd11  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp1277q2627encode_param ( state_max, state_l, state_e, state_s,
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

  assign state_max = 5'd11;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
      5'd0   : param_state_ct = 11'd1277;
      5'd1   : param_state_ct = 11'd639;
      5'd2   : param_state_ct = 11'd319;
      5'd3   : param_state_ct = 11'd159;
      5'd4   : param_state_ct = 11'd79;
      5'd5   : param_state_ct = 11'd39;
      5'd6   : param_state_ct = 11'd19;
      5'd7   : param_state_ct = 11'd9;
      5'd8   : param_state_ct = 11'd7;
      5'd9   : param_state_ct = 11'd5;
      5'd10  : param_state_ct = 11'd3;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 11'd1277;
      5'd1   : param_r_max = 11'd639;
      5'd2   : param_r_max = 11'd320;
      5'd3   : param_r_max = 11'd160;
      5'd4   : param_r_max = 11'd80;
      5'd5   : param_r_max = 11'd40;
      5'd6   : param_r_max = 11'd20;
      5'd7   : param_r_max = 11'd10;
      5'd8   : param_r_max = 11'd5;
      5'd9   : param_r_max = 11'd3;
      5'd10  : param_r_max = 11'd2;
      default: param_r_max = 11'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd2627;
      5'd2   : param_m0 = 14'd106;
      5'd3   : param_m0 = 14'd11236;
      5'd4   : param_m0 = 14'd1927;
      5'd5   : param_m0 = 14'd14506;
      5'd6   : param_m0 = 14'd3211;
      5'd7   : param_m0 = 14'd158;
      5'd8   : param_m0 = 14'd98;
      5'd9   : param_m0 = 14'd9604;
      5'd10  : param_m0 = 14'd1408;
      5'd11  : param_m0 = 14'd7744;
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
      5'd6   : param_outs1 = 2'd2;
      5'd7   : param_outs1 = 2'd1;
      5'd8   : param_outs1 = 2'd0;
      5'd9   : param_outs1 = 2'd2;
      5'd10  : param_outs1 = 2'd1;
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
      5'd4   : param_outsl = 3'd1;
      5'd5   : param_outsl = 3'd2;
      5'd6   : param_outsl = 3'd1;
      5'd7   : param_outsl = 3'd1;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd0;
      5'd10  : param_outsl = 3'd0;
      5'd11  : param_outsl = 3'd4;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp1277q7879decode_param ( state_l, state_e, state_s,
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

  assign state_max = 5'd11;
  assign param_r_max = 'd638;
  assign param_ro_max = 'd1276;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 12'd7;
      5'd1   : param_state_ct = 12'd4;
      5'd2   : param_state_ct = 12'd5;
      5'd3   : param_state_ct = 12'd9;
      5'd4   : param_state_ct = 12'd19;
      5'd5   : param_state_ct = 12'd39;
      5'd6   : param_state_ct = 12'd79;
      5'd7   : param_state_ct = 12'd159;
      5'd8   : param_state_ct = 12'd319;
      5'd9   : param_state_ct = 12'd637;
      5'd10  : param_state_ct = 12'd1276;
      default: param_state_ct = 12'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 10'd0;
      5'd1   : param_ri_offset = 10'd637;
      5'd2   : param_ri_offset = 10'd636;
      5'd3   : param_ri_offset = 10'd634;
      5'd4   : param_ri_offset = 10'd629;
      5'd5   : param_ri_offset = 10'd619;
      5'd6   : param_ri_offset = 10'd599;
      5'd7   : param_ri_offset = 10'd559;
      5'd8   : param_ri_offset = 10'd479;
      5'd9   : param_ri_offset = 10'd319;
      5'd10  : param_ri_offset = 10'd0;
      default: param_ri_offset = 10'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 10'd0;
      5'd2   : param_ri_len = 10'd0;
      5'd3   : param_ri_len = 10'd1;
      5'd4   : param_ri_len = 10'd4;
      5'd5   : param_ri_len = 10'd9;
      5'd6   : param_ri_len = 10'd19;
      5'd7   : param_ri_len = 10'd39;
      5'd8   : param_ri_len = 10'd79;
      5'd9   : param_ri_len = 10'd159;
      5'd10  : param_ri_len = 10'd318;
      5'd11  : param_ri_len = 10'd637;
      default: param_ri_len = 10'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 12'd2064;
      5'd2   : param_outoffset = 12'd2062;
      5'd3   : param_outoffset = 12'd2060;
      5'd4   : param_outoffset = 12'd2055;
      5'd5   : param_outoffset = 12'd2035;
      5'd6   : param_outoffset = 12'd2035;
      5'd7   : param_outoffset = 12'd1995;
      5'd8   : param_outoffset = 12'd1915;
      5'd9   : param_outoffset = 12'd1595;
      5'd10  : param_outoffset = 12'd1276;
      5'd11  : param_outoffset = 12'd0;
      default: param_outoffset = 12'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd2;
      5'd3   : param_outs1 = 2'd1;
      5'd4   : param_outs1 = 2'd1;
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd0;
      5'd7   : param_outs1 = 2'd1;
      5'd8   : param_outs1 = 2'd1;
      5'd9   : param_outs1 = 2'd2;
      5'd10  : param_outs1 = 2'd1;
      5'd11  : param_outs1 = 2'd2;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b1;
  assign param_small_r3 = 1'b1;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd3;
      5'd3   : param_outsl = 2'd3;
      5'd4   : param_outsl = 2'd1;
      5'd5   : param_outsl = 2'd2;
      5'd6   : param_outsl = 2'd0;
      5'd7   : param_outsl = 2'd1;
      5'd8   : param_outsl = 2'd1;
      5'd9   : param_outsl = 2'd2;
      5'd10  : param_outsl = 2'd3;
      5'd11  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd376;
      5'd2   : param_m0 = 14'd4962;
      5'd3   : param_m0 = 14'd1127;
      5'd4   : param_m0 = 14'd537;
      5'd5   : param_m0 = 14'd5929;
      5'd6   : param_m0 = 14'd77;
      5'd7   : param_m0 = 14'd140;
      5'd8   : param_m0 = 14'd189;
      5'd9   : param_m0 = 14'd3511;
      5'd10  : param_m0 = 14'd948;
      5'd11  : param_m0 = 14'd7879;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd356962;
      5'd2   : param_m0inv = 27'd27049;
      5'd3   : param_m0inv = 27'd119092;
      5'd4   : param_m0inv = 27'd249939;
      5'd5   : param_m0inv = 27'd22637;
      5'd6   : param_m0inv = 27'd1743087;
      5'd7   : param_m0inv = 27'd958698;
      5'd8   : param_m0inv = 27'd710146;
      5'd9   : param_m0inv = 27'd38227;
      5'd10  : param_m0inv = 27'd141579;
      5'd11  : param_m0inv = 27'd17034;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 10'd637;
      5'd2   : param_ro_offset = 10'd636;
      5'd3   : param_ro_offset = 10'd634;
      5'd4   : param_ro_offset = 10'd629;
      5'd5   : param_ro_offset = 10'd619;
      5'd6   : param_ro_offset = 10'd599;
      5'd7   : param_ro_offset = 10'd559;
      5'd8   : param_ro_offset = 10'd479;
      5'd9   : param_ro_offset = 10'd319;
      5'd10  : param_ro_offset = 10'd0;
      5'd11  : param_ro_offset = 10'd0;
      default: param_ro_offset = 10'd0;
    endcase
  end

endmodule

module rp1277q2627decode_param ( state_l, state_e, state_s,
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

  assign state_max = 5'd11;
  assign param_r_max = 'd638;
  assign param_ro_max = 'd1276;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 12'd8;
      5'd1   : param_state_ct = 12'd4;
      5'd2   : param_state_ct = 12'd5;
      5'd3   : param_state_ct = 12'd9;
      5'd4   : param_state_ct = 12'd19;
      5'd5   : param_state_ct = 12'd39;
      5'd6   : param_state_ct = 12'd79;
      5'd7   : param_state_ct = 12'd159;
      5'd8   : param_state_ct = 12'd319;
      5'd9   : param_state_ct = 12'd637;
      5'd10  : param_state_ct = 12'd1276;
      default: param_state_ct = 12'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 10'd0;
      5'd1   : param_ri_offset = 10'd637;
      5'd2   : param_ri_offset = 10'd636;
      5'd3   : param_ri_offset = 10'd634;
      5'd4   : param_ri_offset = 10'd629;
      5'd5   : param_ri_offset = 10'd619;
      5'd6   : param_ri_offset = 10'd599;
      5'd7   : param_ri_offset = 10'd559;
      5'd8   : param_ri_offset = 10'd479;
      5'd9   : param_ri_offset = 10'd319;
      5'd10  : param_ri_offset = 10'd0;
      default: param_ri_offset = 10'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 10'd0;
      5'd2   : param_ri_len = 10'd0;
      5'd3   : param_ri_len = 10'd1;
      5'd4   : param_ri_len = 10'd4;
      5'd5   : param_ri_len = 10'd9;
      5'd6   : param_ri_len = 10'd19;
      5'd7   : param_ri_len = 10'd39;
      5'd8   : param_ri_len = 10'd79;
      5'd9   : param_ri_len = 10'd159;
      5'd10  : param_ri_len = 10'd318;
      5'd11  : param_ri_len = 10'd637;
      default: param_ri_len = 10'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 12'd1811;
      5'd2   : param_outoffset = 12'd1810;
      5'd3   : param_outoffset = 12'd1806;
      5'd4   : param_outoffset = 12'd1805;
      5'd5   : param_outoffset = 12'd1795;
      5'd6   : param_outoffset = 12'd1756;
      5'd7   : param_outoffset = 12'd1676;
      5'd8   : param_outoffset = 12'd1596;
      5'd9   : param_outoffset = 12'd1276;
      5'd10  : param_outoffset = 12'd1276;
      5'd11  : param_outoffset = 12'd0;
      default: param_outoffset = 12'd0;
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
      5'd7   : param_outs1 = 2'd2;
      5'd8   : param_outs1 = 2'd1;
      5'd9   : param_outs1 = 2'd2;
      5'd10  : param_outs1 = 2'd0;
      5'd11  : param_outs1 = 2'd2;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b1;
  assign param_small_r3 = 1'b1;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd3;
      5'd3   : param_outsl = 2'd3;
      5'd4   : param_outsl = 2'd1;
      5'd5   : param_outsl = 2'd1;
      5'd6   : param_outsl = 2'd1;
      5'd7   : param_outsl = 2'd2;
      5'd8   : param_outsl = 2'd1;
      5'd9   : param_outsl = 2'd2;
      5'd10  : param_outsl = 2'd3;
      5'd11  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd7744;
      5'd2   : param_m0 = 14'd1408;
      5'd3   : param_m0 = 14'd9604;
      5'd4   : param_m0 = 14'd98;
      5'd5   : param_m0 = 14'd158;
      5'd6   : param_m0 = 14'd3211;
      5'd7   : param_m0 = 14'd14506;
      5'd8   : param_m0 = 14'd1927;
      5'd9   : param_m0 = 14'd11236;
      5'd10  : param_m0 = 14'd106;
      5'd11  : param_m0 = 14'd2627;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd17331;
      5'd2   : param_m0inv = 27'd95325;
      5'd3   : param_m0inv = 27'd13975;
      5'd4   : param_m0inv = 27'd1369568;
      5'd5   : param_m0inv = 27'd849479;
      5'd6   : param_m0inv = 27'd41799;
      5'd7   : param_m0inv = 27'd9252;
      5'd8   : param_m0inv = 27'd69651;
      5'd9   : param_m0inv = 27'd11945;
      5'd10  : param_m0inv = 27'd1266204;
      5'd11  : param_m0inv = 27'd51091;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 10'd637;
      5'd2   : param_ro_offset = 10'd636;
      5'd3   : param_ro_offset = 10'd634;
      5'd4   : param_ro_offset = 10'd629;
      5'd5   : param_ro_offset = 10'd619;
      5'd6   : param_ro_offset = 10'd599;
      5'd7   : param_ro_offset = 10'd559;
      5'd8   : param_ro_offset = 10'd479;
      5'd9   : param_ro_offset = 10'd319;
      5'd10  : param_ro_offset = 10'd0;
      5'd11  : param_ro_offset = 10'd0;
      default: param_ro_offset = 10'd0;
    endcase
  end

endmodule

