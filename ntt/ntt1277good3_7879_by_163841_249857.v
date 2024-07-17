module mod_3 ( clk, addr, Out ) ;

  input clk;
  input      [11: 0] addr;
  output reg [1 : 0] Out;

  wire       [2 : 0] even0;
  wire       [2 : 0] odd0;
  reg        [4 : 0] oe0;
  wire       [1 : 0] even1;
  wire       [1 : 0] odd1;
  reg        [2 : 0] oe1;

  assign even0 = addr[0] + addr[2] + addr[4] + addr[6] + addr[8] + addr[10];
  assign odd0 = addr[1] + addr[3] + addr[5] + addr[7] + addr[9] + addr[11];

  always @ ( posedge clk ) begin
    oe0 <= {odd0, 1'b0} + even0;
  end

  assign even1 = oe0[0] + oe0[2] + oe0[4];
  assign odd1 = oe0[1] + oe0[3];

  always @ ( posedge clk ) begin
    oe1 <= {odd1, 1'b0} + even1;
  end

  always @ ( posedge clk ) begin
    case(oe1)
      3'd0 :   Out <= 'd0;
      3'd1 :   Out <= 'd1;
      3'd2 :   Out <= 'd2;
      3'd3 :   Out <= 'd0;
      3'd4 :   Out <= 'd1;
      3'd5 :   Out <= 'd2;
      3'd6 :   Out <= 'd0;
      3'd7 :   Out <= 'd1;
      default: Out <= 'd0;
    endcase
  end

endmodule

module good3_addr_gen ( clk, y_deg, in_good, out_good0, out_good1, acc_ctrl );

  input            clk;
  input      [1:0] y_deg;
  input      [1:0] in_good;
  output reg [1:0] out_good0;
  output reg [1:0] out_good1;
  output reg       acc_ctrl;

  wire             in_good_reset;
  assign in_good_reset = (in_good == 2'd0);

  always @ ( posedge clk ) begin
    out_good0 <= in_good;
    case(y_deg)
      2'd1:    begin
        out_good1 <= { in_good[1], in_good[1] ^ (!in_good[0]) } ;
      end
      2'd2:    begin
        out_good1 <= { (!in_good[1]) & (!in_good[0]), in_good[0] } ;
      end
      default: begin // 2'd0
        out_good1 <= in_good_reset ? 2'd0 : { !in_good[1], !in_good[0] } ;
      end
    endcase
  end

  always @ ( posedge clk ) begin
    acc_ctrl <= !in_good_reset;
  end

endmodule

module ntt1277good3_7879_by_163841_249857 ( clk, rst, start, input_fg, addr, din, dout, valid );

  localparam Q0 = 7879;
  localparam Q1 = 163841;
  localparam Q2 = 249857;
  localparam Q_n1_INV = 15602;
  localparam Q_n2_INV = -23793;

  localparam Q_n1_PREFIX = 61; // Note: manual optimization for this part may be necessary.
  localparam Q_n1_SHIFT  = 12;
  localparam Q_n2_PREFIX = 5; // Note: manual optimization for this part may be necessary.
  localparam Q_n2_SHIFT  = 15;

  localparam QALLp      = 37'sh0988065001; // Note: manual optimization for this part may be necessary.
  localparam QALLp_DIV2 = 37'sh04C4032800;
  localparam QALLn      = 37'sh1677F9AFFF;
  localparam QALLn_DIV2 = 37'sh1B3BFCD800;

  // STATE
  localparam ST_IDLE   = 0;
  localparam ST_NTT    = 1;
  localparam ST_PMUL   = 2;
  localparam ST_RELOAD = 3;
  localparam ST_INTT   = 4;
  localparam ST_CRT    = 5;  // not applied for single prime scheme
  localparam ST_REDUCE = 6;
  localparam ST_FINISH = 7;

  input                      clk;
  input                      rst;
  input                      start;
  input                      input_fg;
  input             [11 : 0] addr;
  input signed      [12 : 0] din;
  output reg signed [12 : 0] dout;
  output reg                 valid;

  // BRAM
  // Notice: This RTL applies CRT to handle the unfriendliness of 7879.
  //         d[17: 0] for q1 = 163841 in wr_din/rd_dout/wr_dout
  //         d[35:18] for q2 = 249857 in wr_din/rd_dout/wr_dout
  reg            wr_en   [0 : 1];
  reg   [11 : 0] wr_addr [0 : 1];
  reg   [11 : 0] rd_addr [0 : 1];
  reg   [35 : 0] wr_din  [0 : 1];
  wire  [35 : 0] rd_dout [0 : 1];
  wire  [35 : 0] wr_dout [0 : 1];

  // addr_gen
  wire         bank_index_rd [0 : 1];
  wire         bank_index_wr [0 : 1];
  wire [8 : 0] data_index_rd [0 : 1];
  wire [8 : 0] data_index_wr [0 : 1];
  reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;
  reg  fg_shift_1, fg_shift_2, fg_shift_3;

  // w_addr_gen
  reg  [8  : 0] stage_bit;
  wire [8  : 0] w_addr;

  // bfu
  reg                  ntt_state;
  reg                  acc_state;
  reg  signed [17: 0] in_a  [0:1];
  reg  signed [17: 0] in_b  [0:1];
  reg  signed [17: 0] in_w  [0:1];
  wire signed [35: 0] bw    [0:1];
  wire signed [17: 0] out_a [0:1];
  wire signed [17: 0] out_b [0:1];

  // state, stage, counter
  reg  [2 : 0] state, next_state;
  reg  [4 : 0] stage, stage_wr;
  wire [4 : 0] stage_rdM, stage_wrM;
  reg  [10 : 0] ctr;
  reg  [10 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_10, ctr_shift_1, ctr_shift_2, ctr_shift_3, ctr_pmul_shift_2;
  reg  [1 : 0] ctr_good, good_index, good_index_wr;
  wire [2 : 0] good_index_buf;
  wire [1 : 0] ctr_good_next, good_index_next, good_index_wr_next;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, ctr_shift_2_full_end, ctr_shift_10_full_end, stage_rd_end, stage_rd_3, stage_rd_7, stage_wr_end, ntt_end, ctr_good_end, good_index_end, good_index_wr_end, point_proc_end, reduce_end;
  reg          point_proc_end_reg;

  // w_array
  reg         [9 : 0] w_addr_in;
  wire signed [17: 0] w_dout [0:1];

  // mod_3
  wire [1 : 0] in_addr;
  wire [1 : 0] out_good0, out_good1;
  reg  [1 : 0] out_good0_0, out_good1_0;
  wire         acc_ctrl;
  reg  [9 : 0] acc_ctrls;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [9 : 0] wr_ctr [0 : 1];
  reg [12: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [9 : 0] w_addr_in_shift_1;

  // crt
  reg  signed [17:0] in_b_1 [0:1];
  reg  signed [19:0] in_b_sum;
  reg  signed [36:0] bw_sum;
  wire signed [36:0] bw_sum_ALL;
  wire signed [36:0] qproduct_ALL;
  reg  signed [35:0] bw_sum_mod;
  wire signed [12:0] mod7879_out;

  // BRAM instances
  bram_36_12_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_36_12_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[8:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[8:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[8:0], w_addr);

  // Butterfly Unit s , each with a corresponding omega array
  bfu_163841 bfu_inst0 (clk, ntt_state, acc_ctrls[7], in_a[0], in_b[0], in_w[0], bw[0], out_a[0], out_b[0]);
  w_163841 rom_w_inst0 (clk, w_addr_in_shift_1, w_dout[0]);
  bfu_249857 bfu_inst1 (clk, ntt_state, acc_ctrls[7], in_a[1], in_b[1], in_w[1], bw[1], out_a[1], out_b[1]);
  w_249857 rom_w_inst1 (clk, w_addr_in_shift_1, w_dout[1]);

  mod_3 in_addr_gen ( clk, addr, in_addr );
  good3_addr_gen good3_addr_0 ( clk, good_index, ctr_good, out_good0, out_good1, acc_ctrl );

  always @ ( posedge clk ) begin
    out_good0_0 <= out_good0;
    out_good1_0 <= out_good1;
    acc_ctrls <= { acc_ctrls, acc_ctrl };
  end

  // MOD 7879 (Note: manual optimization for this part may be necessary.)
  mod7879S36 mod_q0_inst ( clk, rst, { bw_sum_mod[35], bw_sum_mod[34:0] }, mod7879_out);

  // miscellaneous checkpoint
  assign ctr_half_end         = (ctr[8:0] == 511) ? 1 : 0;
  assign ctr_full_end         = (ctr[9:0] == 1023) ? 1 : 0;
  assign ctr_shift_2_full_end = (ctr_shift_2[9:0] == 1023) ? 1 : 0;
  assign ctr_shift_10_full_end = (ctr_shift_10[9:0] == 1023) ? 1 : 0;
  assign ctr_shift_7_end      = (ctr_shift_7[8 : 0] == 511) ? 1 : 0;
  assign stage_rd_end         = (stage == 10) ? 1 : 0;
  assign stage_rd_3           = (stage == 3) ? 1 : 0;
  assign stage_rd_7           = (stage == 7) ? 1 : 0;
  assign stage_wr_end         = (stage_wr == 10) ? 1 : 0;
  assign ntt_end              = (stage_rd_end && ctr[8 : 0] == 10) ? 1 : 0;
  assign ctr_good_end         = (ctr_good == 'd2);
  assign good_index_end       = (good_index == 'd2);
  assign good_index_wr_end    = (good_index_wr == 'd2);
  assign crt_end              = (stage_rd_7 && ctr[8 : 0] == 10) ? 1 : 0;
  assign point_proc_end       = (ctr == 1027) ? 1 : 0;
  assign reload_end           = (stage_rd_3 && ctr[8:0] == 4) ? 1 : 0;
  assign reduce_end           = reload_end;
  always @ ( posedge clk ) begin
    if (state != ST_PMUL) begin
      point_proc_end_reg <= 0;
    end else if (good_index_end && ctr_full_end && ctr_good_end) begin
      point_proc_end_reg <= 1;
    end
  end

  // crt
  assign bw_sum_ALL = bw_sum + in_b_sum;
  assign qproduct_ALL = (bw_sum_ALL > QALLp_DIV2) ? $signed(QALLn) :
                        (bw_sum_ALL < QALLn_DIV2) ? $signed(QALLp) : 'sd0;

  always @ ( posedge clk ) begin
    in_b_1[0] <= in_b[0];
    in_b_1[1] <= in_b[1];
    in_b_sum <= in_b_1[0] + in_b_1[1];
    bw_sum[36:12] <= bw[0][24:0] + { bw[1][21:0], 3'b0 };
    bw_sum[11:0] <= 12'b0;
    bw_sum_mod <= bw_sum_ALL + qproduct_ALL;
  end

  // fg_shift
  always @ ( posedge clk ) begin
    fg_shift_1 <= input_fg;
    fg_shift_2 <= fg_shift_1;
    fg_shift_3 <= fg_shift_2;
  end
  // dout
  always @ ( posedge clk ) begin
    if (state == ST_FINISH) begin
      if (bank_index_wr_0_shift_2) begin
        dout <= wr_dout[1][12:0];
      end else begin
        dout <= wr_dout[0][12:0];
      end
    end else begin
      dout <= 'sd0;
    end
  end

  // bank_index_wr_0_shift_1
  always @ ( posedge clk ) begin
    bank_index_wr_0_shift_1 <= bank_index_wr[0];
    bank_index_wr_0_shift_2 <= bank_index_wr_0_shift_1;
  end

  // poly_select
  always @ ( posedge clk ) begin
    if (state == ST_NTT || state == ST_INTT) begin
      if (good_index_end && ntt_end) begin
        poly_select <= ~poly_select;
      end else begin
        poly_select <= poly_select;
      end    
    end else if (state == ST_RELOAD) begin
      poly_select <= 1;
    end else begin
      poly_select <= 0;
    end
  end

  // good_index
  assign good_index_next = good_index_end ? 'd0 : (good_index + 'd1);
  always @ ( posedge clk ) begin
    if (state != next_state) begin
      good_index <= 'd0;
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        good_index <= good_index_next;
      end else begin
        good_index <= good_index;
      end
    end else if (state == ST_PMUL) begin
      if (point_proc_end && ctr_good_end) begin
        good_index <= good_index_next;
      end else begin
        good_index <= good_index;
      end
    end else if (state == ST_RELOAD || state == ST_CRT || state == ST_REDUCE ) begin
      if (ctr_shift_2_full_end) begin
        good_index <= good_index_next;
      end else begin
        good_index <= good_index;
      end
    end else begin
      if (ctr_full_end) begin
        good_index <= good_index_next;
      end else begin
        good_index <= good_index;
      end
    end
  end
  assign good_index_buf = { good_index[0], 1'b1, !good_index[1] };

  // good_index_wr
  assign good_index_wr_next = good_index_wr_end ? 'd0 : (good_index_wr + 'd1);
  always @ ( posedge clk ) begin
    if (state != next_state) begin
      good_index_wr <= 'd0;
    end else if (state == ST_CRT) begin
      if (ctr_shift_10_full_end && good_index_wr != good_index) begin
        good_index_wr <= good_index_wr_next;
      end else begin
        good_index_wr <= good_index_wr;
      end
    end else begin
      if (ctr_full_end) begin
        good_index_wr <= good_index_wr_next;
      end else begin
        good_index_wr <= good_index_wr;
      end
    end
  end

  // w_addr_in_shift_1
  always @ ( posedge clk ) begin
    w_addr_in_shift_1 <= w_addr_in;
  end

  // din_shift
  always @ ( posedge clk ) begin
    din_shift_1 <= din;
    din_shift_2 <= din_shift_1;
    din_shift_3 <= din_shift_2;
  end

  // rd_addr
  always @(posedge clk ) begin
    if ( state == ST_NTT || state == ST_INTT ) begin
      if (poly_select ^ bank_index_rd[0]) begin
        rd_addr[0][8:0] <= data_index_rd[1];
        rd_addr[1][8:0] <= data_index_rd[0];
      end else begin
        rd_addr[0][8:0] <= data_index_rd[0];
        rd_addr[1][8:0] <= data_index_rd[1];
      end
    end else begin
      rd_addr[0][8:0] <= data_index_rd[0];
      rd_addr[1][8:0] <= data_index_rd[0];
    end

    if ( state == ST_PMUL ) begin
      // TODO: good factor control
      rd_addr[0][10:9] <= out_good0_0;
      rd_addr[1][10:9] <= out_good1_0;
    end else if ( state == ST_RELOAD ) begin
      rd_addr[0][10:9] <= { 1'b1, !good_index[1] };
      rd_addr[1][10:9] <= { 1'b1, !good_index[1] };
    end else begin
      rd_addr[0][10:9] <= good_index;
      rd_addr[1][10:9] <= good_index;
    end

    if (state == ST_NTT)  begin
      rd_addr[0][11] <= poly_select;
      rd_addr[1][11] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][11] <=  bank_index_rd[0];
      rd_addr[1][11] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][11] <= good_index[0];
      rd_addr[1][11] <= good_index[0];
    end else begin
      rd_addr[0][11] <= 1;
      rd_addr[1][11] <= 1;
    end
  end

  // wr_en
  always @ ( posedge clk ) begin
    if (state == ST_NTT || state == ST_INTT) begin
      if (stage == 0 && ctr < 11) begin
        wr_en[0] <= 0;
        wr_en[1] <= 0;
      end else begin
        wr_en[0] <= 1;
        wr_en[1] <= 1;
      end
    end else if (state == ST_IDLE) begin
      if (fg_shift_3 ^ bank_index_wr[0]) begin
        wr_en[0] <= 0;
        wr_en[1] <= 1;
      end else begin
        wr_en[0] <= 1;
        wr_en[1] <= 0;
      end
    end else if (state == ST_PMUL) begin
      if ((ctr < 4) || (ctr_good != 1)) begin
        wr_en[0] <= 0;
        wr_en[1] <= 0;
      end else begin
        wr_en[0] <= good_index_buf[2] ^ ~bank_index_wr[0];
        wr_en[1] <= good_index_buf[2] ^  bank_index_wr[0];
      end
    end else if (state == ST_REDUCE) begin
      if (stage == 0 && ctr < 4) begin
        wr_en[0] <= 0;
        wr_en[1] <= 0;
      end else begin
        wr_en[0] <= ~bank_index_wr[0];
        wr_en[1] <=  bank_index_wr[0];
      end
    end else if (state == ST_CRT) begin
      if (stage == 0 && ctr < 11) begin
        wr_en[0] <= 0;
        wr_en[1] <= 0;
      end else begin
        wr_en[0] <=  bank_index_wr[0];
        wr_en[1] <= ~bank_index_wr[0];
      end
    end else if (state == ST_RELOAD) begin
      if ((stage == 0 && ctr < 4) || (stage_wr == 3)) begin
        wr_en[0] <= 0;
        wr_en[1] <= 0;
      end else begin
        wr_en[0] <=  bank_index_wr[0];
        wr_en[1] <= ~bank_index_wr[0];
      end
    end else begin
      wr_en[0] <= 0;
      wr_en[1] <= 0;
    end
  end

  // wr_addr
  always @(posedge clk ) begin
    if ( state == ST_NTT || state == ST_INTT ) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_addr[0][8:0] <= data_index_wr[1];
        wr_addr[1][8:0] <= data_index_wr[0];
      end else begin
        wr_addr[0][8:0] <= data_index_wr[0];
        wr_addr[1][8:0] <= data_index_wr[1];
      end
    end else begin
      wr_addr[0][8:0] <= data_index_wr[0];
      wr_addr[1][8:0] <= data_index_wr[0];
    end  

    if ( state == ST_IDLE || state == ST_FINISH ) begin
      wr_addr[0][10:9] <= in_addr;
      wr_addr[1][10:9] <= in_addr;
    end else if ( state == ST_PMUL ) begin
      wr_addr[0][10:9] <= good_index_buf[1:0];
      wr_addr[1][10:9] <= good_index_buf[1:0];
    end else if ( state == ST_RELOAD || state == ST_REDUCE ) begin
      wr_addr[0][10:9] <= stage_wr[1:0];
      wr_addr[1][10:9] <= stage_wr[1:0];
    end else if ( state == ST_CRT ) begin
      wr_addr[0][10:9] <= good_index_wr;
      wr_addr[1][10:9] <= good_index_wr;
    end else begin
      wr_addr[0][10:9] <= good_index;
      wr_addr[1][10:9] <= good_index;
    end

    if (state == ST_IDLE) begin
      wr_addr[0][11] <= fg_shift_3;
      wr_addr[1][11] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][11] <= poly_select;
      wr_addr[1][11] <= poly_select;
    end else if (state == ST_PMUL) begin
      wr_addr[0][11] <= good_index_buf[2];
      wr_addr[1][11] <= good_index_buf[2];
    end else if (state == ST_REDUCE || state == ST_FINISH) begin
      wr_addr[0][11] <= 0;
      wr_addr[1][11] <= 0;
    end else begin
      wr_addr[0][11] <= 1;
      wr_addr[1][11] <= 1;
    end     
  end

  // wr_din
  always @ ( posedge clk ) begin
    if (state == ST_IDLE) begin
      wr_din[0][17:0] <= { { 5 { din_shift_3[12] } }, din_shift_3 };
      wr_din[1][17:0] <= { { 5 { din_shift_3[12] } }, din_shift_3 };
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_din[0][17:0] <= out_b[0];
        wr_din[1][17:0] <= out_a[0];
      end else begin
        wr_din[0][17:0] <= out_a[0];
        wr_din[1][17:0] <= out_b[0];
      end
    end else if (state == ST_RELOAD) begin
      if (bank_index_rd_shift_2 ^ stage_wr[0]) begin
        wr_din[0][17:0] <= rd_dout[1][17:0];
        wr_din[1][17:0] <= rd_dout[1][17:0];
      end else begin
        wr_din[0][17:0] <= rd_dout[0][17:0];
        wr_din[1][17:0] <= rd_dout[0][17:0];
      end
    end else if (state == ST_REDUCE) begin
      if (bank_index_rd_shift_2) begin
        wr_din[0][17:0] <= rd_dout[0][17:0];
        wr_din[1][17:0] <= rd_dout[0][17:0];
      end else begin
        wr_din[0][17:0] <= rd_dout[1][17:0];
        wr_din[1][17:0] <= rd_dout[1][17:0];
      end
    end else if (state == ST_CRT) begin
      if (stage_wr[2] == 0) begin
        wr_din[0][17:0] <= out_a[0];
        wr_din[1][17:0] <= out_a[0];
      end else begin
        wr_din[0][17:0] <= mod7879_out;
        wr_din[1][17:0] <= mod7879_out;
      end
    end else begin
      wr_din[0][17:0] <= out_a[0];
      wr_din[1][17:0] <= out_a[0];
    end

    if (state == ST_IDLE) begin
      wr_din[0][35:18] <= { { 5 { din_shift_3[12] } }, din_shift_3 };
      wr_din[1][35:18] <= { { 5 { din_shift_3[12] } }, din_shift_3 };
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_din[0][35:18] <= out_b[1];
        wr_din[1][35:18] <= out_a[1];
      end else begin
        wr_din[0][35:18] <= out_a[1];
        wr_din[1][35:18] <= out_b[1];
      end
    end else if (state == ST_RELOAD) begin
      if (bank_index_rd_shift_2 ^ stage_wr[0]) begin
        wr_din[0][35:18] <= rd_dout[1][35:18];
        wr_din[1][35:18] <= rd_dout[1][35:18];
      end else begin
        wr_din[0][35:18] <= rd_dout[0][35:18];
        wr_din[1][35:18] <= rd_dout[0][35:18];
      end
    end else if (state == ST_REDUCE) begin
      if (bank_index_rd_shift_2) begin
        wr_din[0][35:18] <= rd_dout[0][35:18];
        wr_din[1][35:18] <= rd_dout[0][35:18];
      end else begin
        wr_din[0][35:18] <= rd_dout[1][35:18];
        wr_din[1][35:18] <= rd_dout[1][35:18];
      end
    end else if (state == ST_CRT) begin
      if (stage_wr[2] == 0) begin
        wr_din[0][35:18] <= out_a[1];
        wr_din[1][35:18] <= out_a[1];
      end else begin
        wr_din[0][35:18] <= mod7879_out;
        wr_din[1][35:18] <= mod7879_out;
      end
    end else begin
      wr_din[0][35:18] <= out_a[1];
      wr_din[1][35:18] <= out_a[1];
    end
  end

  // bank_index_rd_shift
  always @ ( posedge clk ) begin
    bank_index_rd_shift_1 <= bank_index_rd[0];
    bank_index_rd_shift_2 <= bank_index_rd_shift_1;
  end

  // ntt_state
  always @ ( posedge clk ) begin
    if (state == ST_INTT) begin
      ntt_state <= 1;
    end else begin
      ntt_state <= 0;
    end
  end

  //acc_state
  always @ ( posedge clk ) begin
    if ( state == ST_PMUL ) begin
      // acc_state turn off 1 cycle per _goodfactor_ cycles
    end else begin
      acc_state <= 0;
    end
  end

  // in_a, in_b
  always @ ( posedge clk ) begin
    if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_rd_shift_2) begin
        in_b[0] <= $signed(rd_dout[0][17:0]);
        in_b[1] <= $signed(rd_dout[0][35:18]);
      end else begin
        in_b[0] <= $signed(rd_dout[1][17:0]);
        in_b[1] <= $signed(rd_dout[1][35:18]);
      end
    end else if (state == ST_CRT) begin
      if (bank_index_rd_shift_2) begin
        in_b[0] <= $signed(rd_dout[0][17:0]);
        in_b[1] <= $signed(rd_dout[0][35:18]);
      end else begin
        in_b[0] <= $signed(rd_dout[1][17:0]);
        in_b[1] <= $signed(rd_dout[1][35:18]);
      end
    end else begin // ST_PMUL
      in_b[0] <= $signed(rd_dout[1][17:0]);
      in_b[1] <= $signed(rd_dout[1][35:18]);
    end

    if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_rd_shift_2) begin
        in_a[0] <= $signed(rd_dout[1][17:0]);
        in_a[1] <= $signed(rd_dout[1][35:18]);
      end else begin
        in_a[0] <= $signed(rd_dout[0][17:0]);
        in_a[1] <= $signed(rd_dout[0][35:18]);
      end
    end else begin // ST_PMUL, ST_CRT
      in_a[0] <= 'sd0;
      in_a[1] <= 'sd0;
    end
  end

  // w_addr_in, in_w
  always @ ( posedge clk ) begin
    if (state == ST_NTT) begin
      w_addr_in <= {1'b0, w_addr};
    end else begin
      w_addr_in <= 1024 - w_addr;
    end

    if (state == ST_PMUL) begin
        in_w[0] <= rd_dout[0][17:0];
        in_w[1] <= rd_dout[0][35:18];
    end else if (state == ST_CRT) begin
      if (stage[2] == 0 || (stage == 4 && ctr <= 3)) begin
        in_w[0] <= Q_n1_INV;
        in_w[1] <= Q_n2_INV;
      end else begin
        in_w[0] <= Q_n1_PREFIX;
        in_w[1] <= Q_n2_PREFIX;
      end
    end else begin
      in_w[0] <= w_dout[0];
      in_w[1] <= w_dout[1];
    end
  end

  // wr_ctr
  always @ ( posedge clk ) begin
    if (state == ST_IDLE || state == ST_FINISH) begin
      wr_ctr[0] <= addr[9:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7], ctr_shift_1[8], ctr_shift_1[9]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[8:0]};
    end else if (state == ST_PMUL) begin
      wr_ctr[0] <= ctr_pmul_shift_2[9:0];
    end else begin
      wr_ctr[0] <= ctr_shift_7[9:0];
    end

    wr_ctr[1] <= {1'b1, ctr_shift_7[8:0]};
  end

  // ctr_MSB_masked
  always @ (*) begin
    if (state == ST_NTT || state == ST_INTT) begin
      ctr_MSB_masked = 0;
    end else begin
      ctr_MSB_masked = ctr[9];
    end
  end

  // ctr, ctr_good, ctr_shifts
  always @ ( posedge clk ) begin
    if (state != next_state) begin
      ctr <= 0;
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_PMUL) begin
      if (ctr_good_end) begin
        if (point_proc_end) begin
          ctr <= 0;
        end else begin
          ctr <= ctr + 1;
        end
      end
    end else if (state == ST_CRT) begin
      if (crt_end || ctr_full_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_RELOAD) begin
      if (ctr_full_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_REDUCE) begin
      if (ctr_full_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else begin
      ctr <= 0;
    end

    if (state == ST_PMUL) begin
      if (ctr_good == 'd2) begin
        ctr_good <= 'd0;
      end else begin
        ctr_good <= ctr_good + 'd1;
      end
    end else begin
      ctr_good <= 'd0;
    end

    //change ctr_shift_7 <= ctr - 5;
    ctr_shift_7 <= ctr - 7;
    ctr_shift_8 <= ctr_shift_7;
    ctr_shift_9 <= ctr_shift_8;
    ctr_shift_10 <= ctr_shift_9;
    ctr_shift_1 <= ctr;
    ctr_shift_2 <= ctr_shift_1;
    ctr_shift_3 <= ctr_shift_2;
    ctr_pmul_shift_2 <= ctr_shift_1 - 2;
  end

  // stage, stage_wr
  always @ ( posedge clk ) begin
    if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        stage <= 0;
      end else if (ctr_half_end) begin
        stage <= stage + 1;
      end else begin
        stage <= stage;
      end
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      if (reload_end) begin
        stage <= 0;
      end else if (ctr_full_end) begin
        stage <= stage + 1;
      end else begin
        stage <= stage;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage <= 0;
      end else if (ctr_full_end) begin
        if(stage == 2) begin
          stage <= 4;
        end else begin
          stage <= stage + 1;
        end
      end else begin
        stage <= stage;
      end
    end else begin
      stage <= 0;
    end

    if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[8:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_3[9:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[9:0] == 0 && stage != 0) begin
        if(stage_wr == 2) begin
          stage_wr <= 4;
        end else begin
          stage_wr <= stage_wr + 1;
        end
      end else begin
        stage_wr <= stage_wr;
      end
    end else begin
      stage_wr <= 0;
    end        
  end
  assign stage_rdM = (state == ST_NTT || state == ST_INTT) ? stage : 0;
  assign stage_wrM = (state == ST_NTT || state == ST_INTT) ? stage_wr : 0;

  // stage_bit
  always @ ( posedge clk ) begin
    if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        stage_bit <= 0;
      end else if (ctr_half_end) begin
        stage_bit[0] <= 1'b1;
        stage_bit[8 : 1] <= stage_bit[7 : 0];
      end else begin
        stage_bit <= stage_bit;
      end
    end else begin
      stage_bit <= 'b0;
    end
  end

  // valid
  always @ (*) begin
      if (state == ST_FINISH) begin
          valid = 1;
      end else begin
          valid = 0;
      end
  end

  // state
  always @ ( posedge clk ) begin
    if(rst) begin
            state <= 0;
        end else begin
            state <= next_state;
        end
  end

  always @(*) begin
    case(state)
    ST_IDLE: begin
      if(start)
        next_state = ST_NTT;
      else
        next_state = ST_IDLE;
    end
    ST_NTT: begin
      if(ntt_end && good_index_end && poly_select == 1)
        next_state = ST_PMUL;
      else
        next_state = ST_NTT;
    end
    ST_PMUL: begin
      if (point_proc_end && point_proc_end_reg && ctr_good_end)
        next_state = ST_RELOAD;
      else
        next_state = ST_PMUL;
    end
    ST_RELOAD: begin
      if (reload_end) begin
        next_state = ST_INTT;
      end else begin
        next_state = ST_RELOAD;
      end
    end
    ST_INTT: begin
      if(ntt_end && good_index_end)
        next_state = ST_CRT;
      else
        next_state = ST_INTT;
    end
    ST_CRT: begin
      if(crt_end)
        next_state = ST_REDUCE;
      else
        next_state = ST_CRT;
    end
    ST_REDUCE: begin
      if(reduce_end)
        next_state = ST_FINISH;
      else
        next_state = ST_REDUCE;
    end
    ST_FINISH: begin
      if(!start)
        next_state = ST_FINISH;
      else
        next_state = ST_IDLE;
    end
    default: next_state = ST_IDLE;
    endcase
  end

endmodule

module w_addr_gen ( clk, stage_bit, ctr, w_addr );

  input              clk;
  input      [ 8: 0] stage_bit;
  input      [ 8: 0] ctr;
  output reg [ 8: 0] w_addr;

  wire [ 8: 0] w;

  assign w[ 0] = (stage_bit[ 0]) ? ctr[ 0] : 0;
  assign w[ 1] = (stage_bit[ 1]) ? ctr[ 1] : 0;
  assign w[ 2] = (stage_bit[ 2]) ? ctr[ 2] : 0;
  assign w[ 3] = (stage_bit[ 3]) ? ctr[ 3] : 0;
  assign w[ 4] = (stage_bit[ 4]) ? ctr[ 4] : 0;
  assign w[ 5] = (stage_bit[ 5]) ? ctr[ 5] : 0;
  assign w[ 6] = (stage_bit[ 6]) ? ctr[ 6] : 0;
  assign w[ 7] = (stage_bit[ 7]) ? ctr[ 7] : 0;
  assign w[ 8] = (stage_bit[ 8]) ? ctr[ 8] : 0;

  always @ ( posedge clk ) begin
    w_addr <= {w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8]};
  end

endmodule

module addr_gen ( clk, stage, ctr, bank_index, data_index );

  input              clk;
  input      [3 : 0] stage;
  input      [9 : 0] ctr;
  output reg         bank_index;
  output reg [8 : 0] data_index;

  wire       [9 : 0] bs_out;

  barrel_shifter bs ( clk, ctr, stage, bs_out );

    always @( posedge clk ) begin
        bank_index <= ^bs_out;
    end

    always @( posedge clk ) begin
        data_index <= bs_out[9:1];
    end

endmodule

module barrel_shifter ( clk, in, shift, out );

  input              clk;
  input      [9 : 0] in;
  input      [3 : 0] shift;
  output reg [9 : 0] out;

  reg        [9 : 0] in_s [0:4];

  always @ (*) begin
    in_s[0] = in;
  end

  always @ (*) begin
    if(shift[0]) begin
      in_s[1] = { in_s[0][0], in_s[0][9:1] };
    end else begin
      in_s[1] = in_s[0];
    end
  end

  always @ (*) begin
    if(shift[1]) begin
      in_s[2] = { in_s[1][1:0], in_s[1][9:2] };
    end else begin
      in_s[2] = in_s[1];
    end
  end

  always @ (*) begin
    if(shift[2]) begin
      in_s[3] = { in_s[2][3:0], in_s[2][9:4] };
    end else begin
      in_s[3] = in_s[2];
    end
  end

  always @ (*) begin
    if(shift[3]) begin
      in_s[4] = { in_s[3][7:0], in_s[3][9:8] };
    end else begin
      in_s[4] = in_s[3];
    end
  end

  always @ ( posedge clk ) begin
    out <= in_s[4];
  end

endmodule

module bfu_163841 ( clk, state, acc, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input                      acc;
  input      signed [17 : 0] in_a;
  input      signed [17 : 0] in_b;
  input      signed [17 : 0] w;
  output reg signed [34 : 0] bw;
  output reg signed [17 : 0] out_a;
  output reg signed [17 : 0] out_b;

  wire signed       [17 : 0] mod_bw;
  reg signed        [19 : 0] a, b;
  reg signed        [17 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  wire signed       [18 : 0] a_mux;
  reg signed        [34 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [18 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul163841s mod163841s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd163841;
  assign a_sub_q = a - 'sd163841;
  assign b_add_q = b + 'sd163841;
  assign b_sub_q = b - 'sd163841;

  assign a_mux = acc ? a : in_a_s4;

  always @(posedge clk ) begin
    in_a_s1 <= in_a;
    in_a_s2 <= in_a_s1;
    in_a_s3 <= in_a_s2;
    in_a_s4 <= in_a_s3;
    in_a_s5 <= in_a_s4;
  end

  always @ ( posedge clk ) begin
    bw <= in_b * w;
  end

  always @ ( posedge clk ) begin
    a <= a_mux + mod_bw;
    b <= a_mux - mod_bw;

    if (state == 0) begin
      if (a > 'sd81920) begin
        out_a <= a_sub_q;
      end else if (a < -'sd81920) begin
        out_a <= a_add_q;
      end else begin
        out_a <= a;
      end
    end else begin
      if (a[0] == 0) begin
        out_a <= a[18:1];
      end else if (a[18] == 0) begin // a > 0
        out_a <= a_sub_q[18:1];
      end else begin                 // a < 0
        out_a <= a_add_q[18:1];
      end
    end

    if (state == 0) begin
      if (b > 'sd81920) begin
        out_b <= b_sub_q;
      end else if (b < -'sd81920) begin
        out_b <= b_add_q;
      end else begin
        out_b <= b;
      end
    end else begin
      if (b[0] == 0) begin
        out_b <= b[18:1];
      end else if (b[18] == 0) begin // b > 0
        out_b <= b_sub_q[18:1];
      end else begin                 // b < 0
        out_b <= b_add_q[18:1];
      end
    end
  end

endmodule

module w_163841 ( clk, addr, dout );

  input                       clk;
  input             [ 9 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [ 9 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [17:0] data [0:511];

  assign dout_p = data[addr_reg[8:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[9] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[  0] =  'sd1;
    data[  1] =  'sd245;
    data[  2] =  'sd60025;
    data[  3] = -'sd39565;
    data[  4] = -'sd26806;
    data[  5] = -'sd13830;
    data[  6] =  'sd52311;
    data[  7] =  'sd36597;
    data[  8] = -'sd44990;
    data[  9] = -'sd45203;
    data[ 10] =  'sd66453;
    data[ 11] =  'sd60726;
    data[ 12] = -'sd31661;
    data[ 13] = -'sd56418;
    data[ 14] = -'sd59766;
    data[ 15] = -'sd60821;
    data[ 16] =  'sd8386;
    data[ 17] = -'sd75363;
    data[ 18] =  'sd50098;
    data[ 19] = -'sd14065;
    data[ 20] = -'sd5264;
    data[ 21] =  'sd21048;
    data[ 22] =  'sd77689;
    data[ 23] =  'sd28249;
    data[ 24] =  'sd39683;
    data[ 25] =  'sd55716;
    data[ 26] =  'sd51617;
    data[ 27] =  'sd30408;
    data[ 28] =  'sd77115;
    data[ 29] =  'sd51460;
    data[ 30] = -'sd8057;
    data[ 31] = -'sd7873;
    data[ 32] =  'sd37207;
    data[ 33] = -'sd59381;
    data[ 34] =  'sd33504;
    data[ 35] =  'sd16430;
    data[ 36] = -'sd70675;
    data[ 37] =  'sd51771;
    data[ 38] =  'sd68138;
    data[ 39] = -'sd17972;
    data[ 40] =  'sd20567;
    data[ 41] = -'sd40156;
    data[ 42] = -'sd7760;
    data[ 43] =  'sd64892;
    data[ 44] =  'sd5963;
    data[ 45] = -'sd13634;
    data[ 46] = -'sd63510;
    data[ 47] =  'sd4945;
    data[ 48] =  'sd64638;
    data[ 49] = -'sd56267;
    data[ 50] = -'sd22771;
    data[ 51] = -'sd8301;
    data[ 52] = -'sd67653;
    data[ 53] = -'sd27044;
    data[ 54] = -'sd72140;
    data[ 55] =  'sd20528;
    data[ 56] = -'sd49711;
    data[ 57] = -'sd54961;
    data[ 58] = -'sd30483;
    data[ 59] =  'sd68351;
    data[ 60] =  'sd34213;
    data[ 61] =  'sd26294;
    data[ 62] =  'sd52231;
    data[ 63] =  'sd16997;
    data[ 64] =  'sd68240;
    data[ 65] =  'sd7018;
    data[ 66] =  'sd81000;
    data[ 67] =  'sd20239;
    data[ 68] =  'sd43325;
    data[ 69] = -'sd35040;
    data[ 70] = -'sd65068;
    data[ 71] = -'sd49083;
    data[ 72] = -'sd64942;
    data[ 73] = -'sd18213;
    data[ 74] = -'sd38478;
    data[ 75] =  'sd75668;
    data[ 76] =  'sd24627;
    data[ 77] = -'sd28502;
    data[ 78] =  'sd62173;
    data[ 79] = -'sd4828;
    data[ 80] = -'sd35973;
    data[ 81] =  'sd34029;
    data[ 82] = -'sd18786;
    data[ 83] = -'sd15022;
    data[ 84] = -'sd75888;
    data[ 85] = -'sd78527;
    data[ 86] = -'sd69718;
    data[ 87] = -'sd41446;
    data[ 88] =  'sd3872;
    data[ 89] = -'sd34406;
    data[ 90] = -'sd73579;
    data[ 91] = -'sd4345;
    data[ 92] = -'sd81479;
    data[ 93] =  'sd26247;
    data[ 94] =  'sd40716;
    data[ 95] = -'sd18881;
    data[ 96] = -'sd38297;
    data[ 97] = -'sd43828;
    data[ 98] =  'sd75646;
    data[ 99] =  'sd19237;
    data[100] = -'sd38324;
    data[101] = -'sd50443;
    data[102] = -'sd70460;
    data[103] = -'sd59395;
    data[104] =  'sd30074;
    data[105] = -'sd4715;
    data[106] = -'sd8288;
    data[107] = -'sd64468;
    data[108] = -'sd65924;
    data[109] =  'sd68879;
    data[110] = -'sd268;
    data[111] = -'sd65660;
    data[112] = -'sd30282;
    data[113] = -'sd46245;
    data[114] = -'sd24996;
    data[115] = -'sd61903;
    data[116] =  'sd70978;
    data[117] =  'sd22464;
    data[118] = -'sd66914;
    data[119] = -'sd9830;
    data[120] =  'sd49265;
    data[121] = -'sd54309;
    data[122] = -'sd34584;
    data[123] =  'sd46652;
    data[124] = -'sd39130;
    data[125] =  'sd79769;
    data[126] =  'sd46326;
    data[127] =  'sd44841;
    data[128] =  'sd8698;
    data[129] =  'sd1077;
    data[130] = -'sd63817;
    data[131] = -'sd70270;
    data[132] = -'sd12845;
    data[133] = -'sd34046;
    data[134] =  'sd14621;
    data[135] = -'sd22357;
    data[136] = -'sd70712;
    data[137] =  'sd42706;
    data[138] = -'sd22854;
    data[139] = -'sd28636;
    data[140] =  'sd29343;
    data[141] = -'sd19969;
    data[142] =  'sd22825;
    data[143] =  'sd21531;
    data[144] =  'sd32183;
    data[145] =  'sd20467;
    data[146] = -'sd64656;
    data[147] =  'sd51857;
    data[148] = -'sd74633;
    data[149] =  'sd65107;
    data[150] =  'sd58638;
    data[151] = -'sd51698;
    data[152] = -'sd50253;
    data[153] = -'sd23910;
    data[154] =  'sd40326;
    data[155] =  'sd49410;
    data[156] = -'sd18784;
    data[157] = -'sd14532;
    data[158] =  'sd44162;
    data[159] =  'sd6184;
    data[160] =  'sd40511;
    data[161] = -'sd69106;
    data[162] = -'sd55347;
    data[163] =  'sd38788;
    data[164] =  'sd282;
    data[165] =  'sd69090;
    data[166] =  'sd51427;
    data[167] = -'sd16142;
    data[168] = -'sd22606;
    data[169] =  'sd32124;
    data[170] =  'sd6012;
    data[171] = -'sd1629;
    data[172] = -'sd71423;
    data[173] =  'sd32352;
    data[174] =  'sd61872;
    data[175] = -'sd78573;
    data[176] = -'sd80988;
    data[177] = -'sd17299;
    data[178] =  'sd21611;
    data[179] =  'sd51783;
    data[180] =  'sd71078;
    data[181] =  'sd46964;
    data[182] =  'sd37310;
    data[183] = -'sd34146;
    data[184] = -'sd9879;
    data[185] =  'sd37260;
    data[186] = -'sd46396;
    data[187] = -'sd61991;
    data[188] =  'sd49418;
    data[189] = -'sd16824;
    data[190] = -'sd25855;
    data[191] =  'sd55324;
    data[192] = -'sd44423;
    data[193] = -'sd70129;
    data[194] =  'sd21700;
    data[195] =  'sd73588;
    data[196] =  'sd6550;
    data[197] = -'sd33660;
    data[198] = -'sd54650;
    data[199] =  'sd45712;
    data[200] =  'sd58252;
    data[201] =  'sd17573;
    data[202] =  'sd45519;
    data[203] =  'sd10967;
    data[204] =  'sd65459;
    data[205] = -'sd18963;
    data[206] = -'sd58387;
    data[207] = -'sd50648;
    data[208] =  'sd43156;
    data[209] = -'sd76445;
    data[210] = -'sd51151;
    data[211] = -'sd80079;
    data[212] =  'sd41565;
    data[213] =  'sd25283;
    data[214] = -'sd31623;
    data[215] = -'sd47108;
    data[216] = -'sd72590;
    data[217] =  'sd74119;
    data[218] = -'sd27196;
    data[219] =  'sd54461;
    data[220] =  'sd71824;
    data[221] =  'sd65893;
    data[222] = -'sd76474;
    data[223] = -'sd58256;
    data[224] = -'sd18553;
    data[225] =  'sd42063;
    data[226] = -'sd16548;
    data[227] =  'sd41765;
    data[228] =  'sd74283;
    data[229] =  'sd12984;
    data[230] =  'sd68101;
    data[231] = -'sd27037;
    data[232] = -'sd70425;
    data[233] = -'sd50820;
    data[234] =  'sd1016;
    data[235] = -'sd78762;
    data[236] =  'sd36548;
    data[237] = -'sd56995;
    data[238] = -'sd37290;
    data[239] =  'sd39046;
    data[240] =  'sd63492;
    data[241] = -'sd9355;
    data[242] =  'sd1799;
    data[243] = -'sd50768;
    data[244] =  'sd13756;
    data[245] = -'sd70441;
    data[246] = -'sd54740;
    data[247] =  'sd23662;
    data[248] =  'sd62755;
    data[249] = -'sd26079;
    data[250] =  'sd444;
    data[251] = -'sd55061;
    data[252] = -'sd54983;
    data[253] = -'sd35873;
    data[254] =  'sd58529;
    data[255] = -'sd78403;
    data[256] = -'sd39338;
    data[257] =  'sd28809;
    data[258] =  'sd13042;
    data[259] = -'sd81530;
    data[260] =  'sd13752;
    data[261] = -'sd71421;
    data[262] =  'sd32842;
    data[263] =  'sd18081;
    data[264] =  'sd6138;
    data[265] =  'sd29241;
    data[266] = -'sd44959;
    data[267] = -'sd37608;
    data[268] = -'sd38864;
    data[269] = -'sd18902;
    data[270] = -'sd43442;
    data[271] =  'sd6375;
    data[272] = -'sd76535;
    data[273] = -'sd73201;
    data[274] = -'sd75576;
    data[275] = -'sd2087;
    data[276] = -'sd19792;
    data[277] =  'sd66190;
    data[278] = -'sd3709;
    data[279] =  'sd74341;
    data[280] =  'sd27194;
    data[281] = -'sd54951;
    data[282] = -'sd28033;
    data[283] =  'sd13237;
    data[284] = -'sd33755;
    data[285] = -'sd77925;
    data[286] =  'sd77772;
    data[287] =  'sd48584;
    data[288] = -'sd57313;
    data[289] =  'sd48641;
    data[290] = -'sd43348;
    data[291] =  'sd29405;
    data[292] = -'sd4779;
    data[293] = -'sd23968;
    data[294] =  'sd26116;
    data[295] =  'sd8621;
    data[296] = -'sd17788;
    data[297] =  'sd65647;
    data[298] =  'sd27097;
    data[299] = -'sd78716;
    data[300] =  'sd47818;
    data[301] = -'sd81142;
    data[302] = -'sd55029;
    data[303] = -'sd47143;
    data[304] = -'sd81165;
    data[305] = -'sd60664;
    data[306] =  'sd46851;
    data[307] =  'sd9625;
    data[308] =  'sd64351;
    data[309] =  'sd37259;
    data[310] = -'sd46641;
    data[311] =  'sd41825;
    data[312] = -'sd74858;
    data[313] =  'sd9982;
    data[314] = -'sd12025;
    data[315] =  'sd3013;
    data[316] = -'sd81020;
    data[317] = -'sd25139;
    data[318] =  'sd66903;
    data[319] =  'sd7135;
    data[320] = -'sd54176;
    data[321] = -'sd1999;
    data[322] =  'sd1768;
    data[323] = -'sd58363;
    data[324] = -'sd44768;
    data[325] =  'sd9187;
    data[326] = -'sd42959;
    data[327] = -'sd39131;
    data[328] =  'sd79524;
    data[329] = -'sd13699;
    data[330] = -'sd79435;
    data[331] =  'sd35504;
    data[332] =  'sd14907;
    data[333] =  'sd47713;
    data[334] =  'sd56974;
    data[335] =  'sd32145;
    data[336] =  'sd11157;
    data[337] = -'sd51832;
    data[338] =  'sd80758;
    data[339] = -'sd39051;
    data[340] = -'sd64717;
    data[341] =  'sd36912;
    data[342] =  'sd32185;
    data[343] =  'sd20957;
    data[344] =  'sd55394;
    data[345] = -'sd27273;
    data[346] =  'sd35596;
    data[347] =  'sd37447;
    data[348] = -'sd581;
    data[349] =  'sd21496;
    data[350] =  'sd23608;
    data[351] =  'sd49525;
    data[352] =  'sd9391;
    data[353] =  'sd7021;
    data[354] =  'sd81735;
    data[355] =  'sd36473;
    data[356] = -'sd75370;
    data[357] =  'sd48383;
    data[358] =  'sd57283;
    data[359] = -'sd55991;
    data[360] =  'sd44849;
    data[361] =  'sd10658;
    data[362] = -'sd10246;
    data[363] = -'sd52655;
    data[364] =  'sd42964;
    data[365] =  'sd40356;
    data[366] =  'sd56760;
    data[367] = -'sd20285;
    data[368] = -'sd54595;
    data[369] =  'sd59187;
    data[370] = -'sd81034;
    data[371] = -'sd28569;
    data[372] =  'sd45758;
    data[373] =  'sd69522;
    data[374] = -'sd6574;
    data[375] =  'sd27780;
    data[376] = -'sd75222;
    data[377] = -'sd79198;
    data[378] = -'sd70272;
    data[379] = -'sd13335;
    data[380] =  'sd9745;
    data[381] = -'sd70090;
    data[382] =  'sd31255;
    data[383] = -'sd43052;
    data[384] = -'sd61916;
    data[385] =  'sd67793;
    data[386] =  'sd61344;
    data[387] = -'sd44092;
    data[388] =  'sd10966;
    data[389] =  'sd65214;
    data[390] = -'sd78988;
    data[391] = -'sd18822;
    data[392] = -'sd23842;
    data[393] =  'sd56986;
    data[394] =  'sd35085;
    data[395] =  'sd76093;
    data[396] = -'sd35089;
    data[397] = -'sd77073;
    data[398] = -'sd41170;
    data[399] =  'sd71492;
    data[400] = -'sd15447;
    data[401] = -'sd16172;
    data[402] = -'sd29956;
    data[403] =  'sd33625;
    data[404] =  'sd46075;
    data[405] = -'sd16654;
    data[406] =  'sd15795;
    data[407] = -'sd62409;
    data[408] = -'sd52992;
    data[409] = -'sd39601;
    data[410] = -'sd35626;
    data[411] = -'sd44797;
    data[412] =  'sd2082;
    data[413] =  'sd18567;
    data[414] = -'sd38633;
    data[415] =  'sd37693;
    data[416] =  'sd59689;
    data[417] =  'sd41956;
    data[418] = -'sd42763;
    data[419] =  'sd8889;
    data[420] =  'sd47872;
    data[421] = -'sd67912;
    data[422] =  'sd73342;
    data[423] = -'sd53720;
    data[424] = -'sd54120;
    data[425] =  'sd11721;
    data[426] = -'sd77493;
    data[427] =  'sd19771;
    data[428] = -'sd71335;
    data[429] =  'sd53912;
    data[430] = -'sd62681;
    data[431] =  'sd44209;
    data[432] =  'sd17699;
    data[433] =  'sd76389;
    data[434] =  'sd37431;
    data[435] = -'sd4501;
    data[436] =  'sd44142;
    data[437] =  'sd1284;
    data[438] = -'sd13102;
    data[439] =  'sd66830;
    data[440] = -'sd10750;
    data[441] = -'sd12294;
    data[442] = -'sd62892;
    data[443] = -'sd7486;
    data[444] = -'sd31819;
    data[445] =  'sd68713;
    data[446] = -'sd40938;
    data[447] = -'sd35509;
    data[448] = -'sd16132;
    data[449] = -'sd20156;
    data[450] = -'sd22990;
    data[451] = -'sd61956;
    data[452] =  'sd57993;
    data[453] = -'sd45882;
    data[454] =  'sd63939;
    data[455] = -'sd63681;
    data[456] = -'sd36950;
    data[457] = -'sd41495;
    data[458] = -'sd8133;
    data[459] = -'sd26493;
    data[460] =  'sd62855;
    data[461] = -'sd1579;
    data[462] = -'sd59173;
    data[463] = -'sd79377;
    data[464] =  'sd49714;
    data[465] =  'sd55696;
    data[466] =  'sd46717;
    data[467] = -'sd23205;
    data[468] =  'sd49210;
    data[469] = -'sd67784;
    data[470] = -'sd59139;
    data[471] = -'sd71047;
    data[472] = -'sd39369;
    data[473] =  'sd21214;
    data[474] = -'sd45482;
    data[475] = -'sd1902;
    data[476] =  'sd25533;
    data[477] =  'sd29627;
    data[478] =  'sd49611;
    data[479] =  'sd30461;
    data[480] = -'sd73741;
    data[481] = -'sd44035;
    data[482] =  'sd24931;
    data[483] =  'sd45978;
    data[484] = -'sd40419;
    data[485] = -'sd72195;
    data[486] =  'sd7053;
    data[487] = -'sd74266;
    data[488] = -'sd8819;
    data[489] = -'sd30722;
    data[490] =  'sd9796;
    data[491] = -'sd57595;
    data[492] = -'sd20449;
    data[493] =  'sd69066;
    data[494] =  'sd45547;
    data[495] =  'sd17827;
    data[496] = -'sd56092;
    data[497] =  'sd20104;
    data[498] =  'sd10250;
    data[499] =  'sd53635;
    data[500] =  'sd33295;
    data[501] = -'sd34775;
    data[502] = -'sd143;
    data[503] = -'sd35035;
    data[504] = -'sd63843;
    data[505] = -'sd76640;
    data[506] =  'sd64915;
    data[507] =  'sd11598;
    data[508] =  'sd56213;
    data[509] =  'sd9541;
    data[510] =  'sd43771;
    data[511] =  'sd74230;
  end

endmodule

module bfu_249857 ( clk, state, acc, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input                      acc;
  input      signed [17 : 0] in_a;
  input      signed [17 : 0] in_b;
  input      signed [17 : 0] w;
  output reg signed [34 : 0] bw;
  output reg signed [17 : 0] out_a;
  output reg signed [17 : 0] out_b;

  wire signed       [17 : 0] mod_bw;
  reg signed        [19 : 0] a, b;
  reg signed        [17 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  wire signed       [18 : 0] a_mux;
  reg signed        [34 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [18 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul249857s mod249857s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd249857;
  assign a_sub_q = a - 'sd249857;
  assign b_add_q = b + 'sd249857;
  assign b_sub_q = b - 'sd249857;

  assign a_mux = acc ? a : in_a_s4;

  always @(posedge clk ) begin
    in_a_s1 <= in_a;
    in_a_s2 <= in_a_s1;
    in_a_s3 <= in_a_s2;
    in_a_s4 <= in_a_s3;
    in_a_s5 <= in_a_s4;
  end

  always @ ( posedge clk ) begin
    bw <= in_b * w;
  end

  always @ ( posedge clk ) begin
    a <= a_mux + mod_bw;
    b <= a_mux - mod_bw;

    if (state == 0) begin
      if (a > 'sd124928) begin
        out_a <= a_sub_q;
      end else if (a < -'sd124928) begin
        out_a <= a_add_q;
      end else begin
        out_a <= a;
      end
    end else begin
      if (a[0] == 0) begin
        out_a <= a[18:1];
      end else if (a[18] == 0) begin // a > 0
        out_a <= a_sub_q[18:1];
      end else begin                 // a < 0
        out_a <= a_add_q[18:1];
      end
    end

    if (state == 0) begin
      if (b > 'sd124928) begin
        out_b <= b_sub_q;
      end else if (b < -'sd124928) begin
        out_b <= b_add_q;
      end else begin
        out_b <= b;
      end
    end else begin
      if (b[0] == 0) begin
        out_b <= b[18:1];
      end else if (b[18] == 0) begin // b > 0
        out_b <= b_sub_q[18:1];
      end else begin                 // b < 0
        out_b <= b_add_q[18:1];
      end
    end
  end

endmodule

module w_249857 ( clk, addr, dout );

  input                       clk;
  input             [ 9 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [ 9 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [17:0] data [0:511];

  assign dout_p = data[addr_reg[8:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[9] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[  0] =  'sd1;
    data[  1] =  'sd333;
    data[  2] =  'sd110889;
    data[  3] = -'sd52799;
    data[  4] = -'sd92077;
    data[  5] =  'sd70770;
    data[  6] =  'sd79852;
    data[  7] =  'sd105874;
    data[  8] =  'sd26205;
    data[  9] = -'sd18730;
    data[ 10] =  'sd9335;
    data[ 11] =  'sd110271;
    data[ 12] = -'sd8736;
    data[ 13] =  'sd89196;
    data[ 14] = -'sd30715;
    data[ 15] =  'sd16042;
    data[ 16] =  'sd94989;
    data[ 17] = -'sd100502;
    data[ 18] =  'sd13672;
    data[ 19] =  'sd55350;
    data[ 20] = -'sd57868;
    data[ 21] = -'sd31055;
    data[ 22] = -'sd97178;
    data[ 23] =  'sd121136;
    data[ 24] =  'sd111311;
    data[ 25] =  'sd87727;
    data[ 26] = -'sd20178;
    data[ 27] =  'sd26865;
    data[ 28] = -'sd48807;
    data[ 29] = -'sd12026;
    data[ 30] = -'sd6946;
    data[ 31] = -'sd64305;
    data[ 32] =  'sd74137;
    data[ 33] = -'sd48222;
    data[ 34] = -'sd67078;
    data[ 35] = -'sd99701;
    data[ 36] =  'sd30548;
    data[ 37] = -'sd71653;
    data[ 38] = -'sd124034;
    data[ 39] = -'sd76917;
    data[ 40] =  'sd121910;
    data[ 41] =  'sd119196;
    data[ 42] = -'sd34995;
    data[ 43] =  'sd89944;
    data[ 44] = -'sd31488;
    data[ 45] =  'sd8490;
    data[ 46] =  'sd78743;
    data[ 47] = -'sd13566;
    data[ 48] = -'sd20052;
    data[ 49] =  'sd68823;
    data[ 50] = -'sd68785;
    data[ 51] =  'sd81439;
    data[ 52] = -'sd115226;
    data[ 53] =  'sd107720;
    data[ 54] = -'sd108648;
    data[ 55] =  'sd49481;
    data[ 56] = -'sd13389;
    data[ 57] =  'sd38889;
    data[ 58] = -'sd42527;
    data[ 59] =  'sd80358;
    data[ 60] =  'sd24515;
    data[ 61] = -'sd81786;
    data[ 62] = -'sd325;
    data[ 63] = -'sd108225;
    data[ 64] = -'sd59517;
    data[ 65] = -'sd80458;
    data[ 66] = -'sd57815;
    data[ 67] = -'sd13406;
    data[ 68] =  'sd33228;
    data[ 69] =  'sd71216;
    data[ 70] = -'sd21487;
    data[ 71] =  'sd90682;
    data[ 72] = -'sd35591;
    data[ 73] = -'sd108524;
    data[ 74] =  'sd90773;
    data[ 75] = -'sd5288;
    data[ 76] = -'sd11905;
    data[ 77] =  'sd33347;
    data[ 78] =  'sd110843;
    data[ 79] = -'sd68117;
    data[ 80] =  'sd54026;
    data[ 81] =  'sd954;
    data[ 82] =  'sd67825;
    data[ 83] =  'sd98595;
    data[ 84] =  'sd100868;
    data[ 85] =  'sd108206;
    data[ 86] =  'sd53190;
    data[ 87] = -'sd27577;
    data[ 88] =  'sd61568;
    data[ 89] =  'sd13870;
    data[ 90] =  'sd121284;
    data[ 91] = -'sd89262;
    data[ 92] =  'sd8737;
    data[ 93] = -'sd88863;
    data[ 94] = -'sd108253;
    data[ 95] = -'sd68841;
    data[ 96] =  'sd62791;
    data[ 97] = -'sd78585;
    data[ 98] =  'sd66180;
    data[ 99] =  'sd50524;
    data[100] =  'sd84073;
    data[101] =  'sd12325;
    data[102] =  'sd106513;
    data[103] = -'sd10865;
    data[104] = -'sd120047;
    data[105] =  'sd1469;
    data[106] = -'sd10537;
    data[107] = -'sd10823;
    data[108] = -'sd106061;
    data[109] = -'sd88476;
    data[110] =  'sd20618;
    data[111] =  'sd119655;
    data[112] =  'sd117852;
    data[113] =  'sd17167;
    data[114] = -'sd30100;
    data[115] = -'sd29020;
    data[116] =  'sd80763;
    data[117] = -'sd90477;
    data[118] =  'sd103856;
    data[119] =  'sd103782;
    data[120] =  'sd79140;
    data[121] =  'sd118635;
    data[122] =  'sd28049;
    data[123] =  'sd95608;
    data[124] =  'sd105625;
    data[125] = -'sd56712;
    data[126] =  'sd104036;
    data[127] = -'sd86135;
    data[128] =  'sd50600;
    data[129] =  'sd109381;
    data[130] = -'sd55249;
    data[131] =  'sd91501;
    data[132] = -'sd12721;
    data[133] =  'sd11476;
    data[134] =  'sd73653;
    data[135] =  'sd40463;
    data[136] = -'sd18099;
    data[137] = -'sd30399;
    data[138] =  'sd121270;
    data[139] = -'sd93924;
    data[140] = -'sd44567;
    data[141] = -'sd99248;
    data[142] = -'sd68460;
    data[143] = -'sd60193;
    data[144] = -'sd55709;
    data[145] = -'sd61679;
    data[146] = -'sd50833;
    data[147] =  'sd62887;
    data[148] = -'sd46617;
    data[149] = -'sd32327;
    data[150] = -'sd21040;
    data[151] = -'sd10324;
    data[152] =  'sd60106;
    data[153] =  'sd26738;
    data[154] = -'sd91098;
    data[155] = -'sd102937;
    data[156] = -'sd47612;
    data[157] = -'sd113805;
    data[158] =  'sd81199;
    data[159] =  'sd54711;
    data[160] = -'sd20798;
    data[161] =  'sd70262;
    data[162] = -'sd89312;
    data[163] = -'sd7913;
    data[164] =  'sd113398;
    data[165] =  'sd33127;
    data[166] =  'sd37583;
    data[167] =  'sd22289;
    data[168] = -'sd73473;
    data[169] =  'sd19477;
    data[170] = -'sd10441;
    data[171] =  'sd21145;
    data[172] =  'sd45289;
    data[173] =  'sd89817;
    data[174] = -'sd73779;
    data[175] = -'sd82421;
    data[176] =  'sd38077;
    data[177] = -'sd63066;
    data[178] = -'sd12990;
    data[179] = -'sd78101;
    data[180] = -'sd22505;
    data[181] =  'sd1545;
    data[182] =  'sd14771;
    data[183] = -'sd78397;
    data[184] = -'sd121073;
    data[185] = -'sd90332;
    data[186] = -'sd97716;
    data[187] = -'sd58018;
    data[188] = -'sd81005;
    data[189] =  'sd9891;
    data[190] =  'sd45562;
    data[191] = -'sd69131;
    data[192] = -'sd33779;
    data[193] = -'sd4842;
    data[194] = -'sd113244;
    data[195] =  'sd18155;
    data[196] =  'sd49047;
    data[197] =  'sd91946;
    data[198] = -'sd114393;
    data[199] = -'sd114605;
    data[200] =  'sd64656;
    data[201] =  'sd42746;
    data[202] = -'sd7431;
    data[203] =  'sd24047;
    data[204] =  'sd12227;
    data[205] =  'sd73879;
    data[206] =  'sd115721;
    data[207] =  'sd57115;
    data[208] =  'sd30163;
    data[209] =  'sd49999;
    data[210] = -'sd90752;
    data[211] =  'sd12281;
    data[212] =  'sd91861;
    data[213] =  'sd107159;
    data[214] = -'sd45604;
    data[215] =  'sd55145;
    data[216] =  'sd123724;
    data[217] = -'sd26313;
    data[218] = -'sd17234;
    data[219] =  'sd7789;
    data[220] =  'sd95167;
    data[221] = -'sd41228;
    data[222] =  'sd13211;
    data[223] = -'sd98163;
    data[224] =  'sd42988;
    data[225] =  'sd73155;
    data[226] =  'sd124486;
    data[227] = -'sd22424;
    data[228] =  'sd28518;
    data[229] =  'sd1928;
    data[230] = -'sd107547;
    data[231] = -'sd83600;
    data[232] = -'sd104673;
    data[233] =  'sd123871;
    data[234] =  'sd22638;
    data[235] =  'sd42744;
    data[236] = -'sd8097;
    data[237] =  'sd52126;
    data[238] =  'sd117825;
    data[239] =  'sd8176;
    data[240] = -'sd25819;
    data[241] = -'sd102589;
    data[242] =  'sd68272;
    data[243] = -'sd2411;
    data[244] = -'sd53292;
    data[245] = -'sd6389;
    data[246] =  'sd121176;
    data[247] =  'sd124631;
    data[248] =  'sd25861;
    data[249] =  'sd116575;
    data[250] =  'sd91640;
    data[251] =  'sd33566;
    data[252] = -'sd66087;
    data[253] = -'sd19555;
    data[254] = -'sd15533;
    data[255] =  'sd74508;
    data[256] =  'sd75321;
    data[257] =  'sd96193;
    data[258] =  'sd50573;
    data[259] =  'sd100390;
    data[260] = -'sd50968;
    data[261] =  'sd17932;
    data[262] = -'sd25212;
    data[263] =  'sd99542;
    data[264] = -'sd83495;
    data[265] = -'sd69708;
    data[266] =  'sd23937;
    data[267] = -'sd24403;
    data[268] =  'sd119082;
    data[269] = -'sd72957;
    data[270] = -'sd58552;
    data[271] = -'sd8970;
    data[272] =  'sd11274;
    data[273] =  'sd6387;
    data[274] = -'sd121842;
    data[275] = -'sd96552;
    data[276] =  'sd79737;
    data[277] =  'sd67579;
    data[278] =  'sd16677;
    data[279] =  'sd56587;
    data[280] =  'sd104196;
    data[281] = -'sd32855;
    data[282] =  'sd52993;
    data[283] = -'sd93178;
    data[284] = -'sd46006;
    data[285] = -'sd78721;
    data[286] =  'sd20892;
    data[287] = -'sd38960;
    data[288] =  'sd18884;
    data[289] =  'sd41947;
    data[290] = -'sd23641;
    data[291] =  'sd122971;
    data[292] = -'sd27205;
    data[293] = -'sd64413;
    data[294] =  'sd38173;
    data[295] = -'sd31098;
    data[296] = -'sd111497;
    data[297] =  'sd100192;
    data[298] = -'sd116902;
    data[299] =  'sd49326;
    data[300] = -'sd65004;
    data[301] =  'sd91227;
    data[302] = -'sd103963;
    data[303] =  'sd110444;
    data[304] =  'sd48873;
    data[305] =  'sd34004;
    data[306] =  'sd79767;
    data[307] =  'sd77569;
    data[308] =  'sd95206;
    data[309] = -'sd28241;
    data[310] =  'sd90313;
    data[311] =  'sd91389;
    data[312] = -'sd50017;
    data[313] =  'sd84758;
    data[314] = -'sd9427;
    data[315] =  'sd108950;
    data[316] =  'sd51085;
    data[317] =  'sd21029;
    data[318] =  'sd6661;
    data[319] = -'sd30600;
    data[320] =  'sd54337;
    data[321] =  'sd104517;
    data[322] =  'sd74038;
    data[323] = -'sd81189;
    data[324] = -'sd51381;
    data[325] = -'sd119597;
    data[326] = -'sd98538;
    data[327] = -'sd81887;
    data[328] = -'sd33958;
    data[329] = -'sd64449;
    data[330] =  'sd26185;
    data[331] = -'sd25390;
    data[332] =  'sd40268;
    data[333] = -'sd83034;
    data[334] =  'sd83805;
    data[335] = -'sd76919;
    data[336] =  'sd121244;
    data[337] = -'sd102582;
    data[338] =  'sd70603;
    data[339] =  'sd24241;
    data[340] =  'sd76829;
    data[341] =  'sd98643;
    data[342] =  'sd116852;
    data[343] = -'sd65976;
    data[344] =  'sd17408;
    data[345] =  'sd50153;
    data[346] = -'sd39470;
    data[347] =  'sd98911;
    data[348] = -'sd43761;
    data[349] = -'sd80707;
    data[350] =  'sd109125;
    data[351] =  'sd109360;
    data[352] = -'sd62242;
    data[353] =  'sd11545;
    data[354] =  'sd96630;
    data[355] = -'sd53763;
    data[356] =  'sd86625;
    data[357] =  'sd112570;
    data[358] =  'sd7260;
    data[359] = -'sd80990;
    data[360] =  'sd14886;
    data[361] = -'sd40102;
    data[362] = -'sd111545;
    data[363] =  'sd84208;
    data[364] =  'sd57280;
    data[365] =  'sd85108;
    data[366] =  'sd107123;
    data[367] = -'sd57592;
    data[368] =  'sd60853;
    data[369] =  'sd25632;
    data[370] =  'sd40318;
    data[371] = -'sd66384;
    data[372] = -'sd118456;
    data[373] =  'sd31558;
    data[374] =  'sd14820;
    data[375] = -'sd62080;
    data[376] =  'sd65491;
    data[377] =  'sd70944;
    data[378] = -'sd112063;
    data[379] = -'sd88286;
    data[380] =  'sd83888;
    data[381] = -'sd49280;
    data[382] =  'sd80322;
    data[383] =  'sd12527;
    data[384] = -'sd76078;
    data[385] = -'sd98417;
    data[386] = -'sd41594;
    data[387] = -'sd108667;
    data[388] =  'sd43154;
    data[389] = -'sd121424;
    data[390] =  'sd42642;
    data[391] = -'sd42063;
    data[392] = -'sd14987;
    data[393] =  'sd6469;
    data[394] = -'sd94536;
    data[395] =  'sd1494;
    data[396] = -'sd2212;
    data[397] =  'sd12975;
    data[398] =  'sd73106;
    data[399] =  'sd108169;
    data[400] =  'sd40869;
    data[401] =  'sd117099;
    data[402] =  'sd16275;
    data[403] = -'sd77279;
    data[404] =  'sd1364;
    data[405] = -'sd45502;
    data[406] =  'sd89111;
    data[407] = -'sd59020;
    data[408] =  'sd85043;
    data[409] =  'sd85478;
    data[410] = -'sd19524;
    data[411] = -'sd5210;
    data[412] =  'sd14069;
    data[413] = -'sd62306;
    data[414] = -'sd9767;
    data[415] = -'sd4270;
    data[416] =  'sd77232;
    data[417] = -'sd17015;
    data[418] =  'sd80716;
    data[419] = -'sd106128;
    data[420] = -'sd110787;
    data[421] =  'sd86765;
    data[422] = -'sd90667;
    data[423] =  'sd40586;
    data[424] =  'sd22860;
    data[425] =  'sd116670;
    data[426] =  'sd123275;
    data[427] =  'sd74027;
    data[428] = -'sd84852;
    data[429] = -'sd21875;
    data[430] = -'sd38522;
    data[431] = -'sd85119;
    data[432] = -'sd110786;
    data[433] =  'sd87098;
    data[434] =  'sd20222;
    data[435] = -'sd12213;
    data[436] = -'sd69217;
    data[437] = -'sd62417;
    data[438] = -'sd46730;
    data[439] = -'sd69956;
    data[440] = -'sd58647;
    data[441] = -'sd40605;
    data[442] = -'sd29187;
    data[443] =  'sd25152;
    data[444] = -'sd119522;
    data[445] = -'sd73563;
    data[446] = -'sd10493;
    data[447] =  'sd3829;
    data[448] =  'sd25772;
    data[449] =  'sd86938;
    data[450] = -'sd33058;
    data[451] = -'sd14606;
    data[452] = -'sd116515;
    data[453] = -'sd71660;
    data[454] =  'sd123492;
    data[455] = -'sd103569;
    data[456] = -'sd8211;
    data[457] =  'sd14164;
    data[458] = -'sd30671;
    data[459] =  'sd30694;
    data[460] = -'sd23035;
    data[461] =  'sd74912;
    data[462] = -'sd40004;
    data[463] = -'sd78911;
    data[464] = -'sd42378;
    data[465] = -'sd119882;
    data[466] =  'sd56414;
    data[467] =  'sd46587;
    data[468] =  'sd22337;
    data[469] = -'sd57489;
    data[470] =  'sd95152;
    data[471] = -'sd46223;
    data[472] =  'sd98875;
    data[473] = -'sd55749;
    data[474] = -'sd74999;
    data[475] =  'sd11033;
    data[476] = -'sd73866;
    data[477] = -'sd111392;
    data[478] = -'sd114700;
    data[479] =  'sd33021;
    data[480] =  'sd2285;
    data[481] =  'sd11334;
    data[482] =  'sd26367;
    data[483] =  'sd35216;
    data[484] = -'sd16351;
    data[485] =  'sd51971;
    data[486] =  'sd66210;
    data[487] =  'sd60514;
    data[488] = -'sd87255;
    data[489] = -'sd72503;
    data[490] =  'sd92630;
    data[491] =  'sd113379;
    data[492] =  'sd26800;
    data[493] = -'sd70452;
    data[494] =  'sd26042;
    data[495] = -'sd73009;
    data[496] = -'sd75868;
    data[497] = -'sd28487;
    data[498] =  'sd8395;
    data[499] =  'sd47108;
    data[500] = -'sd54027;
    data[501] = -'sd1287;
    data[502] =  'sd71143;
    data[503] = -'sd45796;
    data[504] = -'sd8791;
    data[505] =  'sd70881;
    data[506] =  'sd116815;
    data[507] = -'sd78297;
    data[508] = -'sd87773;
    data[509] =  'sd4860;
    data[510] =  'sd119238;
    data[511] = -'sd21009;
  end

endmodule

