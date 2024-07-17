`include "params.v"

module rp857q5167encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd857;
      5'd1   : param_state_ct = 10'd429;
      5'd2   : param_state_ct = 10'd215;
      5'd3   : param_state_ct = 10'd107;
      5'd4   : param_state_ct = 10'd53;
      5'd5   : param_state_ct = 10'd27;
      5'd6   : param_state_ct = 10'd13;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd857;
      5'd1   : param_r_max = 10'd429;
      5'd2   : param_r_max = 10'd215;
      5'd3   : param_r_max = 10'd108;
      5'd4   : param_r_max = 10'd54;
      5'd5   : param_r_max = 10'd27;
      5'd6   : param_r_max = 10'd14;
      5'd7   : param_r_max = 10'd7;
      5'd8   : param_r_max = 10'd4;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd5167;
      5'd2   : param_m0 = 14'd408;
      5'd3   : param_m0 = 14'd651;
      5'd4   : param_m0 = 14'd1656;
      5'd5   : param_m0 = 14'd10713;
      5'd6   : param_m0 = 14'd1752;
      5'd7   : param_m0 = 14'd11991;
      5'd8   : param_m0 = 14'd2194;
      5'd9   : param_m0 = 14'd74;
      5'd10  : param_m0 = 14'd5476;
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
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd2;
      5'd8   : param_outs1 = 2'd2;
      5'd9   : param_outs1 = 2'd0;
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
      5'd6   : param_outsl = 3'd0;
      5'd7   : param_outsl = 3'd2;
      5'd8   : param_outsl = 3'd0;
      5'd9   : param_outsl = 3'd1;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp857q1723encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd857;
      5'd1   : param_state_ct = 10'd429;
      5'd2   : param_state_ct = 10'd215;
      5'd3   : param_state_ct = 10'd107;
      5'd4   : param_state_ct = 10'd53;
      5'd5   : param_state_ct = 10'd27;
      5'd6   : param_state_ct = 10'd13;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd857;
      5'd1   : param_r_max = 10'd429;
      5'd2   : param_r_max = 10'd215;
      5'd3   : param_r_max = 10'd108;
      5'd4   : param_r_max = 10'd54;
      5'd5   : param_r_max = 10'd27;
      5'd6   : param_r_max = 10'd14;
      5'd7   : param_r_max = 10'd7;
      5'd8   : param_r_max = 10'd4;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd1723;
      5'd2   : param_m0 = 14'd11597;
      5'd3   : param_m0 = 14'd2053;
      5'd4   : param_m0 = 14'd65;
      5'd5   : param_m0 = 14'd4225;
      5'd6   : param_m0 = 14'd273;
      5'd7   : param_m0 = 14'd292;
      5'd8   : param_m0 = 14'd334;
      5'd9   : param_m0 = 14'd436;
      5'd10  : param_m0 = 14'd743;
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
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd0;
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd1;
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
      5'd3   : param_outsl = 3'd0;
      5'd4   : param_outsl = 3'd1;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd0;
      5'd7   : param_outsl = 3'd1;
      5'd8   : param_outsl = 3'd0;
      5'd9   : param_outsl = 3'd1;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp857q5167decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd428;
  assign param_ro_max = 'd856;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd5;
      5'd3   : param_state_ct = 11'd13;
      5'd4   : param_state_ct = 11'd25;
      5'd5   : param_state_ct = 11'd53;
      5'd6   : param_state_ct = 11'd107;
      5'd7   : param_state_ct = 11'd213;
      5'd8   : param_state_ct = 11'd427;
      5'd9   : param_state_ct = 11'd856;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd427;
      5'd2   : param_ri_offset = 9'd425;
      5'd3   : param_ri_offset = 9'd422;
      5'd4   : param_ri_offset = 9'd415;
      5'd5   : param_ri_offset = 9'd402;
      5'd6   : param_ri_offset = 9'd375;
      5'd7   : param_ri_offset = 9'd321;
      5'd8   : param_ri_offset = 9'd214;
      5'd9   : param_ri_offset = 9'd0;
      default: param_ri_offset = 9'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 9'd0;
      5'd2   : param_ri_len = 9'd1;
      5'd3   : param_ri_len = 9'd2;
      5'd4   : param_ri_len = 9'd6;
      5'd5   : param_ri_len = 9'd12;
      5'd6   : param_ri_len = 9'd26;
      5'd7   : param_ri_len = 9'd53;
      5'd8   : param_ri_len = 9'd106;
      5'd9   : param_ri_len = 9'd213;
      5'd10  : param_ri_len = 9'd427;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1319;
      5'd2   : param_outoffset = 11'd1318;
      5'd3   : param_outoffset = 11'd1312;
      5'd4   : param_outoffset = 11'd1298;
      5'd5   : param_outoffset = 11'd1285;
      5'd6   : param_outoffset = 11'd1232;
      5'd7   : param_outoffset = 11'd1177;
      5'd8   : param_outoffset = 11'd1070;
      5'd9   : param_outoffset = 11'd856;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd0;
      5'd3   : param_outs1 = 2'd2;
      5'd4   : param_outs1 = 2'd2;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd2;
      5'd7   : param_outs1 = 2'd1;
      5'd8   : param_outs1 = 2'd1;
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
      5'd3   : param_outsl = 2'd3;
      5'd4   : param_outsl = 2'd2;
      5'd5   : param_outsl = 2'd3;
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
      5'd1   : param_m0 = 14'd5476;
      5'd2   : param_m0 = 14'd74;
      5'd3   : param_m0 = 14'd2194;
      5'd4   : param_m0 = 14'd11991;
      5'd5   : param_m0 = 14'd1752;
      5'd6   : param_m0 = 14'd10713;
      5'd7   : param_m0 = 14'd1656;
      5'd8   : param_m0 = 14'd651;
      5'd9   : param_m0 = 14'd408;
      5'd10  : param_m0 = 14'd5167;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd24510;
      5'd2   : param_m0inv = 27'd1813753;
      5'd3   : param_m0inv = 27'd61174;
      5'd4   : param_m0inv = 27'd11193;
      5'd5   : param_m0inv = 27'd76608;
      5'd6   : param_m0inv = 27'd12528;
      5'd7   : param_m0inv = 27'd81049;
      5'd8   : param_m0inv = 27'd206171;
      5'd9   : param_m0inv = 27'd328965;
      5'd10  : param_m0inv = 27'd25975;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd427;
      5'd2   : param_ro_offset = 9'd425;
      5'd3   : param_ro_offset = 9'd422;
      5'd4   : param_ro_offset = 9'd415;
      5'd5   : param_ro_offset = 9'd402;
      5'd6   : param_ro_offset = 9'd375;
      5'd7   : param_ro_offset = 9'd321;
      5'd8   : param_ro_offset = 9'd214;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

module rp857q1723decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd428;
  assign param_ro_max = 'd856;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd5;
      5'd3   : param_state_ct = 11'd13;
      5'd4   : param_state_ct = 11'd25;
      5'd5   : param_state_ct = 11'd53;
      5'd6   : param_state_ct = 11'd107;
      5'd7   : param_state_ct = 11'd213;
      5'd8   : param_state_ct = 11'd427;
      5'd9   : param_state_ct = 11'd856;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd427;
      5'd2   : param_ri_offset = 9'd425;
      5'd3   : param_ri_offset = 9'd422;
      5'd4   : param_ri_offset = 9'd415;
      5'd5   : param_ri_offset = 9'd402;
      5'd6   : param_ri_offset = 9'd375;
      5'd7   : param_ri_offset = 9'd321;
      5'd8   : param_ri_offset = 9'd214;
      5'd9   : param_ri_offset = 9'd0;
      default: param_ri_offset = 9'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
                   // note: no need to refer to R for 1st round.
      5'd1   : param_ri_len = 9'd0;
      5'd2   : param_ri_len = 9'd1;
      5'd3   : param_ri_len = 9'd2;
      5'd4   : param_ri_len = 9'd6;
      5'd5   : param_ri_len = 9'd12;
      5'd6   : param_ri_len = 9'd26;
      5'd7   : param_ri_len = 9'd53;
      5'd8   : param_ri_len = 9'd106;
      5'd9   : param_ri_len = 9'd213;
      5'd10  : param_ri_len = 9'd427;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1149;
      5'd2   : param_outoffset = 11'd1147;
      5'd3   : param_outoffset = 11'd1144;
      5'd4   : param_outoffset = 11'd1137;
      5'd5   : param_outoffset = 11'd1124;
      5'd6   : param_outoffset = 11'd1071;
      5'd7   : param_outoffset = 11'd1070;
      5'd8   : param_outoffset = 11'd856;
      5'd9   : param_outoffset = 11'd428;
      5'd10  : param_outoffset = 11'd0;
      default: param_outoffset = 11'd0;
    endcase
  end

  always @ (*) begin // Regular load bytes
    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4
      5'd1   : param_outs1 = 2'd2;
      5'd2   : param_outs1 = 2'd1;
      5'd3   : param_outs1 = 2'd1;
      5'd4   : param_outs1 = 2'd1;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd2;
      5'd7   : param_outs1 = 2'd0;
      5'd8   : param_outs1 = 2'd2;
      5'd9   : param_outs1 = 2'd2;
      5'd10  : param_outs1 = 2'd1;
      default: param_outs1 = 2'd0;
    endcase
  end

  assign param_small_r2 = 1'b0;
  assign param_small_r3 = 1'b0;
  always @ (*) begin // Last load bytes
    case(state_l)
      5'd1   : param_outsl = 2'd0;
      5'd2   : param_outsl = 2'd1;
      5'd3   : param_outsl = 2'd3;
      5'd4   : param_outsl = 2'd1;
      5'd5   : param_outsl = 2'd3;
      5'd6   : param_outsl = 2'd1;
      5'd7   : param_outsl = 2'd1;
      5'd8   : param_outsl = 2'd3;
      5'd9   : param_outsl = 2'd3;
      5'd10  : param_outsl = 2'd3;
      default: param_outsl = 2'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)
      5'd1   : param_m0 = 14'd743;
      5'd2   : param_m0 = 14'd436;
      5'd3   : param_m0 = 14'd334;
      5'd4   : param_m0 = 14'd292;
      5'd5   : param_m0 = 14'd273;
      5'd6   : param_m0 = 14'd4225;
      5'd7   : param_m0 = 14'd65;
      5'd8   : param_m0 = 14'd2053;
      5'd9   : param_m0 = 14'd11597;
      5'd10  : param_m0 = 14'd1723;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd180642;
      5'd2   : param_m0inv = 27'd307838;
      5'd3   : param_m0inv = 27'd401849;
      5'd4   : param_m0inv = 27'd459649;
      5'd5   : param_m0inv = 27'd491640;
      5'd6   : param_m0inv = 27'd31767;
      5'd7   : param_m0inv = 27'd2064888;
      5'd8   : param_m0inv = 27'd65376;
      5'd9   : param_m0inv = 27'd11573;
      5'd10  : param_m0inv = 27'd77897;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd427;
      5'd2   : param_ro_offset = 9'd425;
      5'd3   : param_ro_offset = 9'd422;
      5'd4   : param_ro_offset = 9'd415;
      5'd5   : param_ro_offset = 9'd402;
      5'd6   : param_ro_offset = 9'd375;
      5'd7   : param_ro_offset = 9'd321;
      5'd8   : param_ro_offset = 9'd214;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

