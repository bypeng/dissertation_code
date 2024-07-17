`include "params.v"

module rp761q4591encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd761;
      5'd1   : param_state_ct = 10'd381;
      5'd2   : param_state_ct = 10'd191;
      5'd3   : param_state_ct = 10'd95;
      5'd4   : param_state_ct = 10'd47;
      5'd5   : param_state_ct = 10'd23;
      5'd6   : param_state_ct = 10'd11;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd3;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd761;
      5'd1   : param_r_max = 10'd381;
      5'd2   : param_r_max = 10'd191;
      5'd3   : param_r_max = 10'd96;
      5'd4   : param_r_max = 10'd48;
      5'd5   : param_r_max = 10'd24;
      5'd6   : param_r_max = 10'd12;
      5'd7   : param_r_max = 10'd6;
      5'd8   : param_r_max = 10'd3;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd4591;
      5'd2   : param_m0 = 14'd322;
      5'd3   : param_m0 = 14'd406;
      5'd4   : param_m0 = 14'd644;
      5'd5   : param_m0 = 14'd1621;
      5'd6   : param_m0 = 14'd10265;
      5'd7   : param_m0 = 14'd1608;
      5'd8   : param_m0 = 14'd10101;
      5'd9   : param_m0 = 14'd1557;
      5'd10  : param_m0 = 14'd9470;
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
      5'd7   : param_outs1 = 2'd1;
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
      5'd3   : param_outsl = 3'd0;
      5'd4   : param_outsl = 3'd1;
      5'd5   : param_outsl = 3'd2;
      5'd6   : param_outsl = 3'd1;
      5'd7   : param_outsl = 3'd2;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd0;
      5'd10  : param_outsl = 3'd4;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp761q1531encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd761;
      5'd1   : param_state_ct = 10'd381;
      5'd2   : param_state_ct = 10'd191;
      5'd3   : param_state_ct = 10'd95;
      5'd4   : param_state_ct = 10'd47;
      5'd5   : param_state_ct = 10'd23;
      5'd6   : param_state_ct = 10'd11;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd761;
      5'd1   : param_r_max = 10'd381;
      5'd2   : param_r_max = 10'd191;
      5'd3   : param_r_max = 10'd96;
      5'd4   : param_r_max = 10'd48;
      5'd5   : param_r_max = 10'd24;
      5'd6   : param_r_max = 10'd12;
      5'd7   : param_r_max = 10'd6;
      5'd8   : param_r_max = 10'd3;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd1531;
      5'd2   : param_m0 = 14'd9157;
      5'd3   : param_m0 = 14'd1280;
      5'd4   : param_m0 = 14'd6400;
      5'd5   : param_m0 = 14'd625;
      5'd6   : param_m0 = 14'd1526;
      5'd7   : param_m0 = 14'd9097;
      5'd8   : param_m0 = 14'd1263;
      5'd9   : param_m0 = 14'd6232;
      5'd10  : param_m0 = 14'd593;
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
      5'd8   : param_outs1 = 2'd1;
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
      5'd3   : param_outsl = 3'd0;
      5'd4   : param_outsl = 3'd2;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd1;
      5'd7   : param_outsl = 3'd2;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd0;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp761q4591decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd380;
  assign param_ro_max = 'd760;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd8;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd5;
      5'd3   : param_state_ct = 11'd11;
      5'd4   : param_state_ct = 11'd23;
      5'd5   : param_state_ct = 11'd47;
      5'd6   : param_state_ct = 11'd95;
      5'd7   : param_state_ct = 11'd189;
      5'd8   : param_state_ct = 11'd379;
      5'd9   : param_state_ct = 11'd760;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd379;
      5'd2   : param_ri_offset = 9'd378;
      5'd3   : param_ri_offset = 9'd375;
      5'd4   : param_ri_offset = 9'd369;
      5'd5   : param_ri_offset = 9'd357;
      5'd6   : param_ri_offset = 9'd333;
      5'd7   : param_ri_offset = 9'd285;
      5'd8   : param_ri_offset = 9'd190;
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
      5'd4   : param_ri_len = 9'd5;
      5'd5   : param_ri_len = 9'd11;
      5'd6   : param_ri_len = 9'd23;
      5'd7   : param_ri_len = 9'd47;
      5'd8   : param_ri_len = 9'd94;
      5'd9   : param_ri_len = 9'd189;
      5'd10  : param_ri_len = 9'd379;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1154;
      5'd2   : param_outoffset = 11'd1153;
      5'd3   : param_outoffset = 11'd1148;
      5'd4   : param_outoffset = 11'd1141;
      5'd5   : param_outoffset = 11'd1118;
      5'd6   : param_outoffset = 11'd1093;
      5'd7   : param_outoffset = 11'd1045;
      5'd8   : param_outoffset = 11'd950;
      5'd9   : param_outoffset = 11'd760;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd3;
      5'd2   : param_outs1 = 2'd1;
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd1;
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
      5'd3   : param_outsl = 2'd1;
      5'd4   : param_outsl = 2'd2;
      5'd5   : param_outsl = 2'd1;
      5'd6   : param_outsl = 2'd2;
      5'd7   : param_outsl = 2'd1;
      5'd8   : param_outsl = 2'd3;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd9470;
      5'd2   : param_m0 = 14'd1557;
      5'd3   : param_m0 = 14'd10101;
      5'd4   : param_m0 = 14'd1608;
      5'd5   : param_m0 = 14'd10265;
      5'd6   : param_m0 = 14'd1621;
      5'd7   : param_m0 = 14'd644;
      5'd8   : param_m0 = 14'd406;
      5'd9   : param_m0 = 14'd322;
      5'd10  : param_m0 = 14'd4591;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd14172;
      5'd2   : param_m0inv = 27'd86202;
      5'd3   : param_m0inv = 27'd13287;
      5'd4   : param_m0inv = 27'd83468;
      5'd5   : param_m0inv = 27'd13075;
      5'd6   : param_m0inv = 27'd82799;
      5'd7   : param_m0inv = 27'd208412;
      5'd8   : param_m0inv = 27'd330585;
      5'd9   : param_m0inv = 27'd416825;
      5'd10  : param_m0inv = 27'd29234;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd379;
      5'd2   : param_ro_offset = 9'd378;
      5'd3   : param_ro_offset = 9'd375;
      5'd4   : param_ro_offset = 9'd369;
      5'd5   : param_ro_offset = 9'd357;
      5'd6   : param_ro_offset = 9'd333;
      5'd7   : param_ro_offset = 9'd285;
      5'd8   : param_ro_offset = 9'd190;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

module rp761q1531decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd380;
  assign param_ro_max = 'd760;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd5;
      5'd3   : param_state_ct = 11'd11;
      5'd4   : param_state_ct = 11'd23;
      5'd5   : param_state_ct = 11'd47;
      5'd6   : param_state_ct = 11'd95;
      5'd7   : param_state_ct = 11'd189;
      5'd8   : param_state_ct = 11'd379;
      5'd9   : param_state_ct = 11'd760;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd379;
      5'd2   : param_ri_offset = 9'd378;
      5'd3   : param_ri_offset = 9'd375;
      5'd4   : param_ri_offset = 9'd369;
      5'd5   : param_ri_offset = 9'd357;
      5'd6   : param_ri_offset = 9'd333;
      5'd7   : param_ri_offset = 9'd285;
      5'd8   : param_ri_offset = 9'd190;
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
      5'd4   : param_ri_len = 9'd5;
      5'd5   : param_ri_len = 9'd11;
      5'd6   : param_ri_len = 9'd23;
      5'd7   : param_ri_len = 9'd47;
      5'd8   : param_ri_len = 9'd94;
      5'd9   : param_ri_len = 9'd189;
      5'd10  : param_ri_len = 9'd379;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1004;
      5'd2   : param_outoffset = 11'd1002;
      5'd3   : param_outoffset = 11'd999;
      5'd4   : param_outoffset = 11'd987;
      5'd5   : param_outoffset = 11'd975;
      5'd6   : param_outoffset = 11'd951;
      5'd7   : param_outoffset = 11'd855;
      5'd8   : param_outoffset = 11'd760;
      5'd9   : param_outoffset = 11'd380;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd2;
      5'd3   : param_outs1 = 2'd1;
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
      5'd4   : param_outsl = 2'd2;
      5'd5   : param_outsl = 2'd1;
      5'd6   : param_outsl = 2'd1;
      5'd7   : param_outsl = 2'd2;
      5'd8   : param_outsl = 2'd3;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd593;
      5'd2   : param_m0 = 14'd6232;
      5'd3   : param_m0 = 14'd1263;
      5'd4   : param_m0 = 14'd9097;
      5'd5   : param_m0 = 14'd1526;
      5'd6   : param_m0 = 14'd625;
      5'd7   : param_m0 = 14'd6400;
      5'd8   : param_m0 = 14'd1280;
      5'd9   : param_m0 = 14'd9157;
      5'd10  : param_m0 = 14'd1531;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd226336;
      5'd2   : param_m0inv = 27'd21536;
      5'd3   : param_m0inv = 27'd106268;
      5'd4   : param_m0inv = 27'd14754;
      5'd5   : param_m0inv = 27'd87953;
      5'd6   : param_m0inv = 27'd214748;
      5'd7   : param_m0inv = 27'd20971;
      5'd8   : param_m0inv = 27'd104857;
      5'd9   : param_m0inv = 27'd14657;
      5'd10  : param_m0inv = 27'd87666;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd379;
      5'd2   : param_ro_offset = 9'd378;
      5'd3   : param_ro_offset = 9'd375;
      5'd4   : param_ro_offset = 9'd369;
      5'd5   : param_ro_offset = 9'd357;
      5'd6   : param_ro_offset = 9'd333;
      5'd7   : param_ro_offset = 9'd285;
      5'd8   : param_ro_offset = 9'd190;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

