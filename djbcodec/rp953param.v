`include "params.v"

module rp953q6343encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd953;
      5'd1   : param_state_ct = 10'd477;
      5'd2   : param_state_ct = 10'd239;
      5'd3   : param_state_ct = 10'd119;
      5'd4   : param_state_ct = 10'd59;
      5'd5   : param_state_ct = 10'd29;
      5'd6   : param_state_ct = 10'd15;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd953;
      5'd1   : param_r_max = 10'd477;
      5'd2   : param_r_max = 10'd239;
      5'd3   : param_r_max = 10'd120;
      5'd4   : param_r_max = 10'd60;
      5'd5   : param_r_max = 10'd30;
      5'd6   : param_r_max = 10'd15;
      5'd7   : param_r_max = 10'd8;
      5'd8   : param_r_max = 10'd4;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd6343;
      5'd2   : param_m0 = 14'd614;
      5'd3   : param_m0 = 14'd1473;
      5'd4   : param_m0 = 14'd8476;
      5'd5   : param_m0 = 14'd1097;
      5'd6   : param_m0 = 14'd4701;
      5'd7   : param_m0 = 14'd338;
      5'd8   : param_m0 = 14'd447;
      5'd9   : param_m0 = 14'd781;
      5'd10  : param_m0 = 14'd2383;
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
      5'd4   : param_outs1 = 2'd2;
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd2;
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
      5'd4   : param_outsl = 3'd2;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd2;
      5'd7   : param_outsl = 3'd0;
      5'd8   : param_outsl = 3'd1;
      5'd9   : param_outsl = 3'd1;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp953q2115encode_param ( state_max, state_l, state_e, state_s,
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
      5'd0   : param_state_ct = 10'd953;
      5'd1   : param_state_ct = 10'd477;
      5'd2   : param_state_ct = 10'd239;
      5'd3   : param_state_ct = 10'd119;
      5'd4   : param_state_ct = 10'd59;
      5'd5   : param_state_ct = 10'd29;
      5'd6   : param_state_ct = 10'd15;
      5'd7   : param_state_ct = 10'd7;
      5'd8   : param_state_ct = 10'd5;
      5'd9   : param_state_ct = 10'd2;
      default: param_state_ct = 10'd0;
    endcase
  end

  always @ (*) begin // length of R array for each round.
    case(state_l)
      5'd0   : param_r_max = 10'd953;
      5'd1   : param_r_max = 10'd477;
      5'd2   : param_r_max = 10'd239;
      5'd3   : param_r_max = 10'd120;
      5'd4   : param_r_max = 10'd60;
      5'd5   : param_r_max = 10'd30;
      5'd6   : param_r_max = 10'd15;
      5'd7   : param_r_max = 10'd8;
      5'd8   : param_r_max = 10'd4;
      5'd9   : param_r_max = 10'd2;
      default: param_r_max = 10'd0;
    endcase
  end

  always @ (*) begin // M0 for each round.
    case(state_e)  // Note: In the last round, M will be forgot.
      5'd1   : param_m0 = 14'd2115;
      5'd2   : param_m0 = 14'd69;
      5'd3   : param_m0 = 14'd4761;
      5'd4   : param_m0 = 14'd346;
      5'd5   : param_m0 = 14'd468;
      5'd6   : param_m0 = 14'd856;
      5'd7   : param_m0 = 14'd2863;
      5'd8   : param_m0 = 14'd126;
      5'd9   : param_m0 = 14'd15876;
      5'd10  : param_m0 = 14'd3846;
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
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd1;
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
      5'd3   : param_outsl = 3'd0;
      5'd4   : param_outsl = 3'd1;
      5'd5   : param_outsl = 3'd1;
      5'd6   : param_outsl = 3'd2;
      5'd7   : param_outsl = 3'd0;
      5'd8   : param_outsl = 3'd0;
      5'd9   : param_outsl = 3'd2;
      5'd10  : param_outsl = 3'd3;
      default: param_outsl = 3'd0;
    endcase
  end

endmodule

module rp953q6343decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd476;
  assign param_ro_max = 'd952;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd7;
      5'd3   : param_state_ct = 11'd13;
      5'd4   : param_state_ct = 11'd29;
      5'd5   : param_state_ct = 11'd59;
      5'd6   : param_state_ct = 11'd119;
      5'd7   : param_state_ct = 11'd237;
      5'd8   : param_state_ct = 11'd475;
      5'd9   : param_state_ct = 11'd952;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd475;
      5'd2   : param_ri_offset = 9'd473;
      5'd3   : param_ri_offset = 9'd469;
      5'd4   : param_ri_offset = 9'd462;
      5'd5   : param_ri_offset = 9'd447;
      5'd6   : param_ri_offset = 9'd417;
      5'd7   : param_ri_offset = 9'd357;
      5'd8   : param_ri_offset = 9'd238;
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
      5'd4   : param_ri_len = 9'd6;
      5'd5   : param_ri_len = 9'd14;
      5'd6   : param_ri_len = 9'd29;
      5'd7   : param_ri_len = 9'd59;
      5'd8   : param_ri_len = 9'd118;
      5'd9   : param_ri_len = 9'd237;
      5'd10  : param_ri_len = 9'd475;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1502;
      5'd2   : param_outoffset = 11'd1500;
      5'd3   : param_outoffset = 11'd1496;
      5'd4   : param_outoffset = 11'd1489;
      5'd5   : param_outoffset = 11'd1459;
      5'd6   : param_outoffset = 11'd1429;
      5'd7   : param_outoffset = 11'd1309;
      5'd8   : param_outoffset = 11'd1190;
      5'd9   : param_outoffset = 11'd952;
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
      5'd5   : param_outs1 = 2'd2;
      5'd6   : param_outs1 = 2'd1;
      5'd7   : param_outs1 = 2'd2;
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
      5'd3   : param_outsl = 2'd1;
      5'd4   : param_outsl = 2'd3;
      5'd5   : param_outsl = 2'd2;
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
      5'd1   : param_m0 = 14'd2383;
      5'd2   : param_m0 = 14'd781;
      5'd3   : param_m0 = 14'd447;
      5'd4   : param_m0 = 14'd338;
      5'd5   : param_m0 = 14'd4701;
      5'd6   : param_m0 = 14'd1097;
      5'd7   : param_m0 = 14'd8476;
      5'd8   : param_m0 = 14'd1473;
      5'd9   : param_m0 = 14'd614;
      5'd10  : param_m0 = 14'd6343;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd56323;
      5'd2   : param_m0inv = 27'd171853;
      5'd3   : param_m0inv = 27'd300263;
      5'd4   : param_m0inv = 27'd397093;
      5'd5   : param_m0inv = 27'd28550;
      5'd6   : param_m0inv = 27'd122349;
      5'd7   : param_m0inv = 27'd15835;
      5'd8   : param_m0inv = 27'd91118;
      5'd9   : param_m0inv = 27'd218595;
      5'd10  : param_m0inv = 27'd21159;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd475;
      5'd2   : param_ro_offset = 9'd473;
      5'd3   : param_ro_offset = 9'd469;
      5'd4   : param_ro_offset = 9'd462;
      5'd5   : param_ro_offset = 9'd447;
      5'd6   : param_ro_offset = 9'd417;
      5'd7   : param_ro_offset = 9'd357;
      5'd8   : param_ro_offset = 9'd238;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

module rp953q2115decode_param ( state_l, state_e, state_s,
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
  assign param_r_max = 'd476;
  assign param_ro_max = 'd952;

  always @ (*) begin // state counters.
    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.
                   // note: initial round +1
      5'd0   : param_state_ct = 11'd7;
      5'd1   : param_state_ct = 11'd4;
      5'd2   : param_state_ct = 11'd7;
      5'd3   : param_state_ct = 11'd13;
      5'd4   : param_state_ct = 11'd29;
      5'd5   : param_state_ct = 11'd59;
      5'd6   : param_state_ct = 11'd119;
      5'd7   : param_state_ct = 11'd237;
      5'd8   : param_state_ct = 11'd475;
      5'd9   : param_state_ct = 11'd952;
      default: param_state_ct = 11'd0;
    endcase
  end

  always @ (*) begin // R array offset. The last entry of R array for
    case(state_l)  // each round should be aligned at the last.
      5'd0   : param_ri_offset = 9'd0;
      5'd1   : param_ri_offset = 9'd475;
      5'd2   : param_ri_offset = 9'd473;
      5'd3   : param_ri_offset = 9'd469;
      5'd4   : param_ri_offset = 9'd462;
      5'd5   : param_ri_offset = 9'd447;
      5'd6   : param_ri_offset = 9'd417;
      5'd7   : param_ri_offset = 9'd357;
      5'd8   : param_ri_offset = 9'd238;
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
      5'd4   : param_ri_len = 9'd6;
      5'd5   : param_ri_len = 9'd14;
      5'd6   : param_ri_len = 9'd29;
      5'd7   : param_ri_len = 9'd59;
      5'd8   : param_ri_len = 9'd118;
      5'd9   : param_ri_len = 9'd237;
      5'd10  : param_ri_len = 9'd475;
      default: param_ri_len = 9'd0;
    endcase
  end

  always @ (*) begin // Compressed bytes offset.
    case(state_l)  // Indicating the first byte for each round.
      5'd1   : param_outoffset = 11'd1314;
      5'd2   : param_outoffset = 11'd1310;
      5'd3   : param_outoffset = 11'd1310;
      5'd4   : param_outoffset = 11'd1296;
      5'd5   : param_outoffset = 11'd1280;
      5'd6   : param_outoffset = 11'd1250;
      5'd7   : param_outoffset = 11'd1190;
      5'd8   : param_outoffset = 11'd952;
      5'd9   : param_outoffset = 11'd952;
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
      5'd5   : param_outs1 = 2'd1;
      5'd6   : param_outs1 = 2'd1;
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
      5'd2   : param_outsl = 2'd2;
      5'd3   : param_outsl = 2'd0;
      5'd4   : param_outsl = 2'd3;
      5'd5   : param_outsl = 2'd2;
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
      5'd1   : param_m0 = 14'd3846;
      5'd2   : param_m0 = 14'd15876;
      5'd3   : param_m0 = 14'd126;
      5'd4   : param_m0 = 14'd2863;
      5'd5   : param_m0 = 14'd856;
      5'd6   : param_m0 = 14'd468;
      5'd7   : param_m0 = 14'd346;
      5'd8   : param_m0 = 14'd4761;
      5'd9   : param_m0 = 14'd69;
      5'd10  : param_m0 = 14'd2115;
      default: param_m0 = 14'd1;
    endcase
  end

  always @ (*) begin // M0^(-1) for each round.
    case(state_e)
      5'd1   : param_m0inv = 27'd34898;
      5'd2   : param_m0inv = 27'd8454;
      5'd3   : param_m0inv = 27'd1065220;
      5'd4   : param_m0inv = 27'd46880;
      5'd5   : param_m0inv = 27'd156796;
      5'd6   : param_m0inv = 27'd286790;
      5'd7   : param_m0inv = 27'd387912;
      5'd8   : param_m0inv = 27'd28191;
      5'd9   : param_m0inv = 27'd1945184;
      5'd10  : param_m0inv = 27'd63459;
      default: param_m0inv = 27'd1;
    endcase
  end

  always @ (*) begin // Output R array offset.
    case(state_s)  // Indicating the first entry for each round.
      5'd1   : param_ro_offset = 9'd475;
      5'd2   : param_ro_offset = 9'd473;
      5'd3   : param_ro_offset = 9'd469;
      5'd4   : param_ro_offset = 9'd462;
      5'd5   : param_ro_offset = 9'd447;
      5'd6   : param_ro_offset = 9'd417;
      5'd7   : param_ro_offset = 9'd357;
      5'd8   : param_ro_offset = 9'd238;
      5'd9   : param_ro_offset = 9'd0;
      5'd10  : param_ro_offset = 9'd0;
      default: param_ro_offset = 9'd0;
    endcase
  end

endmodule

