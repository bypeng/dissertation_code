`timescale 1ns/100ps

`include "params.v"

`ifdef Q4621
  `define RQ_ENCODE_PARAM rp653q4621encode_param
  `define RNDENCODE_PARAM rp653q1541encode_param
  `define SIMTYPE "p653q4621"
`elsif Q4591
  `define RQ_ENCODE_PARAM rp761q4591encode_param
  `define RNDENCODE_PARAM rp761q1531encode_param
  `define SIMTYPE "p761q4591"
`elsif Q5167
  `define RQ_ENCODE_PARAM rp857q5167encode_param
  `define RNDENCODE_PARAM rp857q1723encode_param
  `define SIMTYPE "p857q5167"
`elsif Q6343
  `define RQ_ENCODE_PARAM rp953q6343encode_param
  `define RNDENCODE_PARAM rp953q2115encode_param
  `define SIMTYPE "p953q6343"
`elsif Q7177
  `define RQ_ENCODE_PARAM rp1013q7177encode_param
  `define RNDENCODE_PARAM rp1013q2393encode_param
  `define SIMTYPE "p1013q7177"
`elsif Q7879
  `define RQ_ENCODE_PARAM rp1277q7879encode_param
  `define RNDENCODE_PARAM rp1277q2627encode_param
  `define SIMTYPE "p1277q7879"
`endif
 
module encode_wrapper (
    input                     clk,
    input                     start,
    input                     mode,
    output                    done,
    input                     rp_we,
    input   [`RP_D_SIZE-1:0]  rp_aw,
    input   [`RP_D_SIZE-1:0]  rp_dw,
    input   [`OUT_DEPTH-1:0]  cd_ar,
    output  [`OUT_D_SIZE-1:0] cd_dr
    ) ;

    wire enc_start;
    wire enc_done;
    wire [4:0] enc_state_l, rq_state_l, rnd_state_l;
    wire [4:0] enc_state_e, rq_state_e, rnd_state_e;
    wire [4:0] enc_state_s, rq_state_s, rnd_state_s;
    wire [4:0] enc_state_max, rq_state_max, rnd_state_max;
    wire [`RP_DEPTH-1:0] enc_param_state_ct, rq_param_state_ct, rnd_param_state_ct;
    wire [`RP_DEPTH-1:0] enc_param_r_max, rq_param_r_max, rnd_param_r_max;
    wire [`RP_D_SIZE-1:0] enc_param_m0, rq_param_m0, rnd_param_m0;
    wire [1:0] enc_param_outs1, rq_param_outs1, rnd_param_outs1;
    wire [2:0] enc_param_outsl, rq_param_outsl, rnd_param_outsl;

    wire [`RP_DEPTH-1:0] rp_rd_addr;
    wire [`RP_D_SIZE-1:0] rp_rd_data;
    wire rp_wr_en;
    wire [`RP_DEPTH-1:0] rp_wr_addr;
    wire [`RP_D_SIZE-1:0] rp_wr_data;

    wire [`OUT_DEPTH-1:0] cd_rd_addr;
    wire [`OUT_D_SIZE-1:0] cd_rd_data;
    wire cd_wr_en;
    wire [`OUT_DEPTH-1:0] cd_wr_addr;
    wire [`OUT_D_SIZE-1:0] cd_wr_data;

    assign enc_start = start;
    assign done = enc_done;
    assign rq_state_l = enc_state_l;
    assign rnd_state_l = enc_state_l;
    assign rq_state_e = enc_state_e;
    assign rnd_state_e = enc_state_e;
    assign rq_state_s = enc_state_s;
    assign rnd_state_s = enc_state_s;

    assign enc_state_max = mode ? rq_state_max : rnd_state_max;
    assign enc_param_state_ct = mode ? rq_param_state_ct : rnd_param_state_ct;
    assign enc_param_r_max = mode ? rq_param_r_max : rnd_param_r_max;
    assign enc_param_m0 = mode ? rq_param_m0 : rnd_param_m0;
    assign enc_param_outs1 = mode ? rq_param_outs1 : rnd_param_outs1;
    assign enc_param_outsl = mode ? rq_param_outsl : rnd_param_outsl;

    assign rp_wr_en = rp_we;
    assign rp_wr_addr = rp_aw;
    assign rp_wr_data = rp_dw;
    assign cd_rd_addr = cd_ar;
    assign cd_dr = cd_rd_data;

    encode_rp encoder0 (
        .clk(clk),
        .start(enc_start),
        .done(enc_done),
        .state_l(enc_state_l),
        .state_e(enc_state_e),
        .state_s(enc_state_s),
        .rp_rd_addr(rp_rd_addr),
        .rp_rd_data(rp_rd_data),
        .cd_wr_addr(cd_wr_addr),
        .cd_wr_data(cd_wr_data),
        .cd_wr_en(cd_wr_en),
        .state_max(enc_state_max),
        .param_state_ct(enc_param_state_ct),
        .param_r_max(enc_param_r_max),
        .param_m0(enc_param_m0),
        .param_outs1(enc_param_outs1),
        .param_outsl(enc_param_outsl)
    ) ;

    bram_p # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH) ) inram0 (
        .clk(clk),
        .wr_en(rp_wr_en),
        .wr_addr(rp_wr_addr),
        .wr_din(rp_wr_data),
        .rd_addr(rp_rd_addr),
        .rd_dout(rp_rd_data)
    ) ;

    bram_p # ( .D_SIZE(`OUT_D_SIZE), .Q_DEPTH(`OUT_DEPTH) ) outram0 (
        .clk(clk),
        .wr_en(cd_wr_en),
        .wr_addr(cd_wr_addr),
        .wr_din(cd_wr_data),
        .rd_addr(cd_rd_addr),
        .rd_dout(cd_rd_data)
    ) ;

    `RQ_ENCODE_PARAM param0 (
        .state_max(rq_state_max),
        .state_l(rq_state_l),
        .state_e(rq_state_e),
        .state_s(rq_state_s),
        .param_state_ct(rq_param_state_ct),
        .param_r_max(rq_param_r_max),
        .param_m0(rq_param_m0),
        .param_outs1(rq_param_outs1),
        .param_outsl(rq_param_outsl)
    ) ;

    `RNDENCODE_PARAM param1 (
        .state_max(rnd_state_max),
        .state_l(rnd_state_l),
        .state_e(rnd_state_e),
        .state_s(rnd_state_s),
        .param_state_ct(rnd_param_state_ct),
        .param_r_max(rnd_param_r_max),
        .param_m0(rnd_param_m0),
        .param_outs1(rnd_param_outs1),
        .param_outsl(rnd_param_outsl)
    ) ;

endmodule

