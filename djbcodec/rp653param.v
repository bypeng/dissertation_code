`include "params.v"

module rp653q4621encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd653;
      5'd1   : param_state_ct = 10'd327;
      5'd2   : param_state_ct = 10'd163;
      5'd3   : param_state_ct = 10'd81;
      5'd4   : param_state_ct = 10'd41;
      5'd5   : param_state_ct = 10'd21;
      5'd6   : param_state_ct = 10'd11;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd653;
      5'd1   : param_r_max = 10'd327;
      5'd2   : param_r_max = 10'd164;
      5'd3   : param_r_max = 10'd82;
      5'd4   : param_r_max = 10'd41;
      5'd5   : param_r_max = 10'd21;
      5'd6   : param_r_max = 10'd11;
      5'd7   : param_r_max = 10'd6;
      5'd8   : param_r_max = 10'd3;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd4621;
      5'd2   : param_m0 = 14'd326;
      5'd3   : param_m0 = 14'd416;
      5'd4   : param_m0 = 14'd676;
      5'd5   : param_m0 = 14'd1786;
      5'd6   : param_m0 = 14'd12461;
      5'd7   : param_m0 = 14'd2370;
      5'd8   : param_m0 = 14'd86;
      5'd9   : param_m0 = 14'd7396;
      5'd10  : param_m0 = 14'd835;
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
      5'd3   : param_outs1 = 2'd1;
      5'd4   : param_outs1 = 2'd1;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd2;
      5'd7   : param_outs1 = 2'd2;
      5'd8   : param_outs1 = 2'd0;
      5'd9   : param_outs1 = 2'd2;
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
      5'd3   : param_outsl = 3'd1;
      5'd4   : param_outsl = 3'd2;
      5'd5   : param_outsl = 3'd0;
      5'd6   : param_outsl = 3'd0;
      5'd7   : param_outsl = 3'd0;
      5'd8   : param_outsl = 3'd0;
      5'd9   : param_outsl = 3'd0;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp653q1541encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd653;
      5'd1   : param_state_ct = 10'd327;
      5'd2   : param_state_ct = 10'd163;
      5'd3   : param_state_ct = 10'd81;
      5'd4   : param_state_ct = 10'd41;
      5'd5   : param_state_ct = 10'd21;
      5'd6   : param_state_ct = 10'd11;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd653;
      5'd1   : param_r_max = 10'd327;
      5'd2   : param_r_max = 10'd164;
      5'd3   : param_r_max = 10'd82;
      5'd4   : param_r_max = 10'd41;
      5'd5   : param_r_max = 10'd21;
      5'd6   : param_r_max = 10'd11;
      5'd7   : param_r_max = 10'd6;
      5'd8   : param_r_max = 10'd3;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd1541;
      5'd2   : param_m0 = 14'd9277;
      5'd3   : param_m0 = 14'd1314;
      5'd4   : param_m0 = 14'd6745;
      5'd5   : param_m0 = 14'd695;
      5'd6   : param_m0 = 14'd1887;
      5'd7   : param_m0 = 14'd13910;
      5'd8   : param_m0 = 14'd2953;
      5'd9   : param_m0 = 14'd134;
      5'd10  : param_m0 = 14'd71;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // Regular output bytes count for each round.
    case(state_e)  // Note: It is the special case for the round of |R| <= 2.
                   // 2 bytes outputed then set to 2.
                   // 1 byte outputed then set to 1.
                   // 0 bytes outputed then set to 0.
      5'd1   : param_outs1 = 2'd1;
      5'd2   : param_outs1 = 2'd2;
      5'd3   : param_outs1 = 2'd1;
      5'd4   : param_outs1 = 2'd2;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd2;
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
      5'd3   : param_outsl = 3'd1;
      5'd4   : param_outsl = 3'd2;
      5'd5   : param_outsl = 3'd0;
      5'd6   : param_outsl = 3'd0;
      5'd7   : param_outsl = 3'd0;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd0;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp653q4621decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd326;
  assign param_ro_max = 'd652;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd5;
      5'd3   : param_state_ct = 11'd9;
      5'd4   : param_state_ct = 11'd19;
      5'd5   : param_state_ct = 11'd39;
      5'd6   : param_state_ct = 11'd81;
      5'd7   : param_state_ct = 11'd163;
      5'd8   : param_state_ct = 11'd325;
      5'd9   : param_state_ct = 11'd652;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd325;
      5'd2   : param_ri_offset = 9'd324;
      5'd3   : param_ri_offset = 9'd321;
      5'd4   : param_ri_offset = 9'd316;
      5'd5   : param_ri_offset = 9'd306;
      5'd6   : param_ri_offset = 9'd286;
      5'd7   : param_ri_offset = 9'd245;
      5'd8   : param_ri_offset = 9'd163;
      5'd9   : param_ri_offset = 9'd0;
      default: param_ri_offset = 9'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 9'd0;
      5'd2   : param_ri_len = 9'd0;
      5'd3   : param_ri_len = 9'd2;
      5'd4   : param_ri_len = 9'd4;
      5'd5   : param_ri_len = 9'd9;
      5'd6   : param_ri_len = 9'd19;
      5'd7   : param_ri_len = 9'd40;
      5'd8   : param_ri_len = 9'd81;
      5'd9   : param_ri_len = 9'd162;
      5'd10  : param_ri_len = 9'd325;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd991;
      5'd2   : param_outoffset = 11'd989;
      5'd3   : param_outoffset = 11'd989;
      5'd4   : param_outoffset = 11'd979;
      5'd5   : param_outoffset = 11'd959;
      5'd6   : param_outoffset = 11'd939;
      5'd7   : param_outoffset = 11'd897;
      5'd8   : param_outoffset = 11'd815;
      5'd9   : param_outoffset = 11'd652;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd2;
      5'd3   : param_outs1 = 2'd0;
      5'd4   : param_outs1 = 2'd2;
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd1;
      5'd8   : param_outs1 = 2'd1;
      5'd9   : param_outs1 = 2'd1;
      5'd10  : param_outs1 = 2'd2;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b1;
  assign param_small_r3 = 1'b0;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd3;
      5'd3   : param_outsl = 2'd0;
      5'd4   : param_outsl = 2'd3;
      5'd5   : param_outsl = 2'd3;
      5'd6   : param_outsl = 2'd3;
      5'd7   : param_outsl = 2'd2;
      5'd8   : param_outsl = 2'd1;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd835;
      5'd2   : param_m0 = 14'd7396;
      5'd3   : param_m0 = 14'd86;
      5'd4   : param_m0 = 14'd2370;
      5'd5   : param_m0 = 14'd12461;
      5'd6   : param_m0 = 14'd1786;
      5'd7   : param_m0 = 14'd676;
      5'd8   : param_m0 = 14'd416;
      5'd9   : param_m0 = 14'd326;
      5'd10  : param_m0 = 14'd4621;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd160739;
      5'd2   : param_m0inv = 27'd18147;
      5'd3   : param_m0inv = 27'd1560671;
      5'd4   : param_m0inv = 27'd56631;
      5'd5   : param_m0inv = 27'd10771;
      5'd6   : param_m0inv = 27'd75149;
      5'd7   : param_m0inv = 27'd198546;
      5'd8   : param_m0inv = 27'd322638;
      5'd9   : param_m0inv = 27'd411710;
      5'd10  : param_m0inv = 27'd29045;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd325;
      5'd2   : param_ro_offset = 9'd324;
      5'd3   : param_ro_offset = 9'd321;
      5'd4   : param_ro_offset = 9'd316;
      5'd5   : param_ro_offset = 9'd306;
      5'd6   : param_ro_offset = 9'd286;
      5'd7   : param_ro_offset = 9'd245;
      5'd8   : param_ro_offset = 9'd163;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

module rp653q1541decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd326;
  assign param_ro_max = 'd652;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd5;
      5'd3   : param_state_ct = 11'd9;
      5'd4   : param_state_ct = 11'd19;
      5'd5   : param_state_ct = 11'd39;
      5'd6   : param_state_ct = 11'd81;
      5'd7   : param_state_ct = 11'd163;
      5'd8   : param_state_ct = 11'd325;
      5'd9   : param_state_ct = 11'd652;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd325;
      5'd2   : param_ri_offset = 9'd324;
      5'd3   : param_ri_offset = 9'd321;
      5'd4   : param_ri_offset = 9'd316;
      5'd5   : param_ri_offset = 9'd306;
      5'd6   : param_ri_offset = 9'd286;
      5'd7   : param_ri_offset = 9'd245;
      5'd8   : param_ri_offset = 9'd163;
      5'd9   : param_ri_offset = 9'd0;
      default: param_ri_offset = 9'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 9'd0;
      5'd2   : param_ri_len = 9'd0;
      5'd3   : param_ri_len = 9'd2;
      5'd4   : param_ri_len = 9'd4;
      5'd5   : param_ri_len = 9'd9;
      5'd6   : param_ri_len = 9'd19;
      5'd7   : param_ri_len = 9'd40;
      5'd8   : param_ri_len = 9'd81;
      5'd9   : param_ri_len = 9'd162;
      5'd10  : param_ri_len = 9'd325;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd862;
      5'd2   : param_outoffset = 11'd861;
      5'd3   : param_outoffset = 11'd856;
      5'd4   : param_outoffset = 11'd846;
      5'd5   : param_outoffset = 11'd836;
      5'd6   : param_outoffset = 11'd816;
      5'd7   : param_outoffset = 11'd734;
      5'd8   : param_outoffset = 11'd652;
      5'd9   : param_outoffset = 11'd326;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd1;
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd2;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd2;
      5'd8   : param_outs1 = 2'd1;
      5'd9   : param_outs1 = 2'd2;
      5'd10  : param_outs1 = 2'd1;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b1;
  assign param_small_r3 = 1'b0;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd3;
      5'd3   : param_outsl = 2'd1;
      5'd4   : param_outsl = 2'd3;
      5'd5   : param_outsl = 2'd3;
      5'd6   : param_outsl = 2'd3;
      5'd7   : param_outsl = 2'd2;
      5'd8   : param_outsl = 2'd1;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd71;
      5'd2   : param_m0 = 14'd134;
      5'd3   : param_m0 = 14'd2953;
      5'd4   : param_m0 = 14'd13910;
      5'd5   : param_m0 = 14'd1887;
      5'd6   : param_m0 = 14'd695;
      5'd7   : param_m0 = 14'd6745;
      5'd8   : param_m0 = 14'd1314;
      5'd9   : param_m0 = 14'd9277;
      5'd10  : param_m0 = 14'd1541;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd1890390;
      5'd2   : param_m0inv = 27'd1001624;
      5'd3   : param_m0inv = 27'd45451;
      5'd4   : param_m0inv = 27'd9649;
      5'd5   : param_m0inv = 27'd71127;
      5'd6   : param_m0inv = 27'd193119;
      5'd7   : param_m0inv = 27'd19898;
      5'd8   : param_m0inv = 27'd102144;
      5'd9   : param_m0inv = 27'd14467;
      5'd10  : param_m0inv = 27'd87097;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd325;
      5'd2   : param_ro_offset = 9'd324;
      5'd3   : param_ro_offset = 9'd321;
      5'd4   : param_ro_offset = 9'd316;
      5'd5   : param_ro_offset = 9'd306;
      5'd6   : param_ro_offset = 9'd286;
      5'd7   : param_ro_offset = 9'd245;
      5'd8   : param_ro_offset = 9'd163;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

