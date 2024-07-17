`timescale 1ns/100ps

`include "params.v"   

`ifdef Q4621
  `define RQ_DECODE_PARAM rp653q4621decode_param
  `define RNDDECODE_PARAM rp653q1541decode_param
  `define SIMTYPE "p653q4621"
`elsif Q4591
  `define RQ_DECODE_PARAM rp761q4591decode_param
  `define RNDDECODE_PARAM rp761q1531decode_param
  `define SIMTYPE "p761q4591"
`elsif Q5167
  `define RQ_DECODE_PARAM rp857q5167decode_param
  `define RNDDECODE_PARAM rp857q1723decode_param
  `define SIMTYPE "p857q5167"
`elsif Q6343
  `define RQ_DECODE_PARAM rp953q6343decode_param
  `define RNDDECODE_PARAM rp953q2115decode_param
  `define SIMTYPE "p953q6343"
`elsif Q7177
  `define RQ_DECODE_PARAM rp1013q7177decode_param
  `define RNDDECODE_PARAM rp1013q2393decode_param
  `define SIMTYPE "p1013q7177"
`elsif Q7879
  `define RQ_DECODE_PARAM rp1277q7879decode_param
  `define RNDDECODE_PARAM rp1277q2627decode_param
  `define SIMTYPE "p1277q7879"
`endif
 
module decode_wrapper (
    input                     clk,
    input                     start,
    input                     mode,
    output                    done,
    input                     rp_we,
    input   [`OUT_D_SIZE-1:0] rp_aw,
    input   [`OUT_D_SIZE-1:0] rp_dw,
    input   [`RP_DEPTH-1:0]   cd_ar,
    output  [`RP_D_SIZE-1:0]  cd_dr
    ) ;

    wire dec_start;
    wire dec_done;
    wire [4:0]              dec_state_l, rq_state_l, rnd_state_l;
    wire [4:0]              dec_state_e, rq_state_e, rnd_state_e;
    wire [4:0]              dec_state_s, rq_state_s, rnd_state_s;
    wire [4:0]              dec_state_max, rq_state_max, rnd_state_max;
    wire [`RP_DEPTH-2:0]    dec_param_r_max, rq_param_r_max, rnd_param_r_max;
    wire [`RP_DEPTH-1:0]    dec_param_ro_max, rq_param_ro_max, rnd_param_ro_max;
    wire                    dec_param_small_r2, rq_param_small_r2, rnd_param_small_r2;
    wire                    dec_param_small_r3, rq_param_small_r3, rnd_param_small_r3;
    wire [`RP_DEPTH-1:0]    dec_param_state_ct, rq_param_state_ct, rnd_param_state_ct;
    wire [`RP_DEPTH-2:0]    dec_param_ri_offset, rq_param_ri_offset, rnd_param_ri_offset;
    wire [`RP_DEPTH-2:0]    dec_param_ri_len, rq_param_ri_len, rnd_param_ri_len;
    wire [`OUT_DEPTH-1:0]   dec_param_outoffset, rq_param_outoffset, rnd_param_outoffset;
    wire [1:0]              dec_param_outs1, rq_param_outs1, rnd_param_outs1;
    wire [1:0]              dec_param_outsl, rq_param_outsl, rnd_param_outsl;
    wire [`RP_D_SIZE-1:0]   dec_param_m0, rq_param_m0, rnd_param_m0;
    wire [`RP_INV_SIZE-1:0] dec_param_m0inv, rq_param_m0inv, rnd_param_m0inv;
    wire [`RP_DEPTH-2:0]    dec_param_ro_offset, rq_param_ro_offset, rnd_param_ro_offset;

    wire [`OUT_DEPTH-1:0] rp_rd_addr;
    wire [`OUT_D_SIZE-1:0] rp_rd_data;
    wire rp_wr_en;
    wire [`OUT_DEPTH-1:0] rp_wr_addr;
    wire [`OUT_D_SIZE-1:0] rp_wr_data;

    wire [`RP_DEPTH-1:0] cd_rd_addr;
    wire [`RP_D_SIZE-1:0] cd_rd_data;
    wire cd_wr_en;
    wire [`RP_DEPTH-1:0] cd_wr_addr;
    wire [`RP_D_SIZE-1:0] cd_wr_data;

    assign dec_start = start;
    assign done = dec_done;
    assign rq_state_l = dec_state_l;
    assign rnd_state_l = dec_state_l;
    assign rq_state_e = dec_state_e;
    assign rnd_state_e = dec_state_e;
    assign rq_state_s = dec_state_s;
    assign rnd_state_s = dec_state_s;

    assign dec_state_max = mode ? rq_state_max : rnd_state_max;
    assign dec_param_r_max = mode ? rq_param_r_max : rnd_param_r_max;
    assign dec_param_ro_max = mode ? rq_param_ro_max : rnd_param_ro_max;
    assign dec_param_small_r2 = mode ? rq_param_small_r2 : rnd_param_small_r2;
    assign dec_param_small_r3 = mode ? rq_param_small_r3 : rnd_param_small_r3;
    assign dec_param_state_ct = mode ? rq_param_state_ct : rnd_param_state_ct;
    assign dec_param_ri_offset = mode ? rq_param_ri_offset : rnd_param_ri_offset;
    assign dec_param_ri_len = mode ? rq_param_ri_len : rnd_param_ri_len;
    assign dec_param_outoffset = mode ? rq_param_outoffset : rnd_param_outoffset;
    assign dec_param_outs1 = mode ? rq_param_outs1 : rnd_param_outs1;
    assign dec_param_outsl = mode ? rq_param_outsl : rnd_param_outsl;
    assign dec_param_m0 = mode ? rq_param_m0 : rnd_param_m0;
    assign dec_param_m0inv = mode ? rq_param_m0inv : rnd_param_m0inv;
    assign dec_param_ro_offset = mode ? rq_param_ro_offset : rnd_param_ro_offset;

    assign rp_wr_en = rp_we;
    assign rp_wr_addr = rp_aw;
    assign rp_wr_data = rp_dw;
    assign cd_rd_addr = cd_ar;
    assign cd_dr = cd_rd_data;

    decode_rp decoder0 (
        .clk(clk),
        .start(dec_start),
        .done(dec_done),
        .rp_rd_addr(rp_rd_addr),
        .rp_rd_data(rp_rd_data),
        .cd_wr_addr(cd_wr_addr),
        .cd_wr_data(cd_wr_data),
        .cd_wr_en(cd_wr_en),
        .state_l(dec_state_l),
        .state_e(dec_state_e),
        .state_s(dec_state_s),
        .state_max(dec_state_max),
        .param_r_max(dec_param_r_max),
        .param_ro_max(dec_param_ro_max),
        .param_small_r2(dec_param_small_r2),
        .param_small_r3(dec_param_small_r3),
        .param_state_ct(dec_param_state_ct),
        .param_ri_offset(dec_param_ri_offset),
        .param_ri_len(dec_param_ri_len),
        .param_outoffset(dec_param_outoffset),
        .param_outs1(dec_param_outs1),
        .param_outsl(dec_param_outsl),
        .param_m0(dec_param_m0),
        .param_m0inv(dec_param_m0inv),
        .param_ro_offset(dec_param_ro_offset)
    ) ;

    bram_p # ( .D_SIZE(`OUT_D_SIZE), .Q_DEPTH(`OUT_DEPTH) ) inram0 (
        .clk(clk),
        .wr_en(rp_wr_en),
        .wr_addr(rp_wr_addr),
        .wr_din(rp_wr_data),
        .rd_addr(rp_rd_addr),
        .rd_dout(rp_rd_data)
    ) ;

    bram_p # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH) ) outram0 (
        .clk(clk),
        .wr_en(cd_wr_en),
        .wr_addr(cd_wr_addr),
        .wr_din(cd_wr_data),
        .rd_addr(cd_rd_addr),
        .rd_dout(cd_rd_data)
    ) ;

    `RQ_DECODE_PARAM param0 (
        .state_l(rq_state_l),
        .state_e(rq_state_e),
        .state_s(rq_state_s),
        .state_max(rq_state_max),
        .param_r_max(rq_param_r_max),
        .param_ro_max(rq_param_ro_max),
        .param_small_r2(rq_param_small_r2),
        .param_small_r3(rq_param_small_r3),
        .param_state_ct(rq_param_state_ct),
        .param_ri_offset(rq_param_ri_offset),
        .param_ri_len(rq_param_ri_len),
        .param_outoffset(rq_param_outoffset),
        .param_outs1(rq_param_outs1),
        .param_outsl(rq_param_outsl),
        .param_m0(rq_param_m0),
        .param_m0inv(rq_param_m0inv),
        .param_ro_offset(rq_param_ro_offset)
    ) ;

    `RNDDECODE_PARAM param1 (
        .state_l(rnd_state_l),
        .state_e(rnd_state_e),
        .state_s(rnd_state_s),
        .state_max(rnd_state_max),
        .param_r_max(rnd_param_r_max),
        .param_ro_max(rnd_param_ro_max),
        .param_small_r2(rnd_param_small_r2),
        .param_small_r3(rnd_param_small_r3),
        .param_state_ct(rnd_param_state_ct),
        .param_ri_offset(rnd_param_ri_offset),
        .param_ri_len(rnd_param_ri_len),
        .param_outoffset(rnd_param_outoffset),
        .param_outs1(rnd_param_outs1),
        .param_outsl(rnd_param_outsl),
        .param_m0(rnd_param_m0),
        .param_m0inv(rnd_param_m0inv),
        .param_ro_offset(rnd_param_ro_offset)
    ) ;

endmodule

