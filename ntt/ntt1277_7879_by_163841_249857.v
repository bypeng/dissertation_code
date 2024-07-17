module ntt1277_7879_by_163841_249857 ( clk, rst, start, input_fg, addr, din, dout, valid );

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
  wire [10: 0] data_index_rd [0 : 1];
  wire [10: 0] data_index_wr [0 : 1];
  reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;
  reg  fg_shift_1, fg_shift_2, fg_shift_3;

  // w_addr_gen
  reg  [10 : 0] stage_bit;
  wire [10 : 0] w_addr;

  // bfu
  reg                  ntt_state; 
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
  reg  [12 : 0] ctr;
  reg  [12 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_1, ctr_shift_2;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, stage_rd_end, stage_rd_2, stage_wr_end, ntt_end, point_proc_end, reduce_end;

  // w_array
  reg         [11: 0] w_addr_in;
  wire signed [17: 0] w_dout [0:1];

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [11: 0] wr_ctr [0 : 1];
  reg [12: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [11: 0] w_addr_in_shift_1;

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
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[10:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[10:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[10:0], w_addr);

  // Butterfly Unit s , each with a corresponding omega array
  bfu_163841 bfu_inst0 (clk, ntt_state, in_a[0], in_b[0], in_w[0], bw[0], out_a[0], out_b[0]);
  w_163841 rom_w_inst0 (clk, w_addr_in_shift_1, w_dout[0]);
  bfu_249857 bfu_inst1 (clk, ntt_state, in_a[1], in_b[1], in_w[1], bw[1], out_a[1], out_b[1]);
  w_249857 rom_w_inst1 (clk, w_addr_in_shift_1, w_dout[1]);

  // MOD 7879 (Note: manual optimization for this part may be necessary.)
  mod7879S36 mod_q0_inst ( clk, rst, { bw_sum_mod[35], bw_sum_mod[34:0] }, mod7879_out);

  assign ctr_half_end         = (ctr[10:0] == 2047) ? 1 : 0;
  assign ctr_full_end         = (ctr[11:0] == 4095) ? 1 : 0;
  assign stage_rd_end         = (stage == 12) ? 1 : 0;
  assign stage_rd_2           = (stage == 2) ? 1 : 0;
  assign ntt_end         = (stage_rd_end && ctr[10 : 0] == 10) ? 1 : 0;
  assign crt_end         = (stage_rd_2 && ctr[10 : 0] == 10) ? 1 : 0;
  assign point_proc_end   = (ctr == 4106) ? 1 : 0;
  assign reload_end      = (stage != 0 && ctr[10:0] == 4) ? 1 : 0;
  assign reduce_end      = (ctr == 4100);

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
      if (ntt_end) begin
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
        rd_addr[0][10:0] <= data_index_rd[1];
        rd_addr[1][10:0] <= data_index_rd[0];
      end else begin
        rd_addr[0][10:0] <= data_index_rd[0];
        rd_addr[1][10:0] <= data_index_rd[1];
      end
    end else begin
      rd_addr[0][10:0] <= data_index_rd[0];
      rd_addr[1][10:0] <= data_index_rd[0];
    end

    if (state == ST_NTT)  begin
      rd_addr[0][11] <= poly_select;
      rd_addr[1][11] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][11] <=  bank_index_rd[0];
      rd_addr[1][11] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][11] <= 0;
      rd_addr[1][11] <= 0;
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
      if (stage == 0 && ctr < 11) begin
        wr_en[0] <= 0;
        wr_en[1] <= 0;
      end else begin
        wr_en[0] <= ~bank_index_wr[0];
        wr_en[1] <=  bank_index_wr[0];
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
      if (stage == 0 && ctr < 4) begin
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
        wr_addr[0][10:0] <= data_index_wr[1];
        wr_addr[1][10:0] <= data_index_wr[0];
      end else begin
        wr_addr[0][10:0] <= data_index_wr[0];
        wr_addr[1][10:0] <= data_index_wr[1];
      end
    end else begin
      wr_addr[0][10:0] <= data_index_wr[0];
      wr_addr[1][10:0] <= data_index_wr[0];
    end  

    if (state == ST_IDLE) begin
      wr_addr[0][11] <= fg_shift_3;
      wr_addr[1][11] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][11] <= poly_select;
      wr_addr[1][11] <= poly_select;
    end else if (state == ST_PMUL || state == ST_REDUCE || state == ST_FINISH) begin
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
      if (bank_index_rd_shift_2) begin
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
      if (stage_wr == 0) begin
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
      if (bank_index_rd_shift_2) begin
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
      if (stage_wr == 0) begin
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
      w_addr_in <= 4096 - w_addr;
    end

    if (state == ST_PMUL) begin
        in_w[0] <= rd_dout[0][17:0];
        in_w[1] <= rd_dout[0][35:18];
    end else if (state == ST_CRT) begin
      if (stage == 0 || (stage == 1 && ctr <= 3)) begin
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
      wr_ctr[0] <= addr[11:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7], ctr_shift_1[8], ctr_shift_1[9], ctr_shift_1[10], ctr_shift_1[11]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[10:0]};
    end else begin
      wr_ctr[0] <= ctr_shift_7[11:0];
    end

    wr_ctr[1] <= {1'b1, ctr_shift_7[10:0]};
  end

  // ctr_MSB_masked
  always @ (*) begin
    if (state == ST_NTT || state == ST_INTT) begin
      ctr_MSB_masked = 0;
    end else begin
      ctr_MSB_masked = ctr[11];
    end
  end

  // ctr, ctr_shifts
  always @ ( posedge clk ) begin
    if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_PMUL) begin
      if (point_proc_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_CRT) begin
      if (crt_end || ctr_full_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_RELOAD) begin
      if (reload_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else if (state == ST_REDUCE) begin
      if (reduce_end) begin
        ctr <= 0;
      end else begin
        ctr <= ctr + 1;
      end
    end else begin
      ctr <= 0;
    end

    //change ctr_shift_7 <= ctr - 5;
    ctr_shift_7 <= ctr - 7;
    ctr_shift_8 <= ctr_shift_7;
    ctr_shift_9 <= ctr_shift_8;
    ctr_shift_1 <= ctr;
    ctr_shift_2 <= ctr_shift_1;
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
    end else if (state == ST_RELOAD) begin
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
        stage <= stage + 1;
      end else begin
        stage <= stage;
      end
    end else begin
      stage <= 0;
    end

    if (state == ST_NTT || state == ST_INTT) begin
      if (ntt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[10:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[11:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[11:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
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
        stage_bit[10 : 1] <= stage_bit[9 : 0];
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
      if(ntt_end && poly_select == 1)
        next_state = ST_PMUL;
      else
        next_state = ST_NTT;
    end
    ST_PMUL: begin
      if (point_proc_end)
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
      if(ntt_end)
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
  input      [10: 0] stage_bit;
  input      [10: 0] ctr;
  output reg [10: 0] w_addr;

  wire [10: 0] w;

  assign w[ 0] = (stage_bit[ 0]) ? ctr[ 0] : 0;
  assign w[ 1] = (stage_bit[ 1]) ? ctr[ 1] : 0;
  assign w[ 2] = (stage_bit[ 2]) ? ctr[ 2] : 0;
  assign w[ 3] = (stage_bit[ 3]) ? ctr[ 3] : 0;
  assign w[ 4] = (stage_bit[ 4]) ? ctr[ 4] : 0;
  assign w[ 5] = (stage_bit[ 5]) ? ctr[ 5] : 0;
  assign w[ 6] = (stage_bit[ 6]) ? ctr[ 6] : 0;
  assign w[ 7] = (stage_bit[ 7]) ? ctr[ 7] : 0;
  assign w[ 8] = (stage_bit[ 8]) ? ctr[ 8] : 0;
  assign w[ 9] = (stage_bit[ 9]) ? ctr[ 9] : 0;
  assign w[10] = (stage_bit[10]) ? ctr[10] : 0;

  always @ ( posedge clk ) begin
    w_addr <= {w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10]};
  end

endmodule

module addr_gen ( clk, stage, ctr, bank_index, data_index );

  input              clk;
  input      [3 : 0] stage;
  input      [11: 0] ctr;
  output reg         bank_index;
  output reg [10: 0] data_index;

  wire       [11: 0] bs_out;

  barrel_shifter bs ( clk, ctr, stage, bs_out );

    always @( posedge clk ) begin
        bank_index <= ^bs_out;
    end

    always @( posedge clk ) begin
        data_index <= bs_out[11:1];
    end

endmodule

module barrel_shifter ( clk, in, shift, out );

  input              clk;
  input      [11: 0] in;
  input      [3 : 0] shift;
  output reg [11: 0] out;

  reg        [11: 0] in_s [0:4];

  always @ (*) begin
    in_s[0] = in;
  end

  always @ (*) begin
    if(shift[0]) begin
      in_s[1] = { in_s[0][0], in_s[0][11:1] };
    end else begin
      in_s[1] = in_s[0];
    end
  end

  always @ (*) begin
    if(shift[1]) begin
      in_s[2] = { in_s[1][1:0], in_s[1][11:2] };
    end else begin
      in_s[2] = in_s[1];
    end
  end

  always @ (*) begin
    if(shift[2]) begin
      in_s[3] = { in_s[2][3:0], in_s[2][11:4] };
    end else begin
      in_s[3] = in_s[2];
    end
  end

  always @ (*) begin
    if(shift[3]) begin
      in_s[4] = { in_s[3][7:0], in_s[3][11:8] };
    end else begin
      in_s[4] = in_s[3];
    end
  end

  always @ ( posedge clk ) begin
    out <= in_s[4];
  end

endmodule

module bfu_163841 ( clk, state, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input      signed [17 : 0] in_a;
  input      signed [17 : 0] in_b;
  input      signed [17 : 0] w;
  output reg signed [34 : 0] bw;
  output reg signed [17 : 0] out_a;
  output reg signed [17 : 0] out_b;

  wire signed       [17 : 0] mod_bw;
  reg signed        [18 : 0] a, b;
  reg signed        [17 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  reg signed        [34 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [18 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul163841s mod163841s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd163841;
  assign a_sub_q = a - 'sd163841;
  assign b_add_q = b + 'sd163841;
  assign b_sub_q = b - 'sd163841;

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
    a <= in_a_s4 + mod_bw;
    b <= in_a_s4 - mod_bw;

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
  input             [11 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [11 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [17:0] data [0:2047];

  assign dout_p = data[addr_reg[10:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[11] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[   0] =  'sd1;
    data[   1] =  'sd38;
    data[   2] =  'sd1444;
    data[   3] =  'sd54872;
    data[   4] = -'sd44797;
    data[   5] = -'sd63876;
    data[   6] =  'sd30327;
    data[   7] =  'sd5539;
    data[   8] =  'sd46641;
    data[   9] = -'sd29893;
    data[  10] =  'sd10953;
    data[  11] = -'sd75309;
    data[  12] = -'sd76445;
    data[  13] =  'sd44228;
    data[  14] =  'sd42254;
    data[  15] = -'sd32758;
    data[  16] =  'sd65924;
    data[  17] =  'sd47497;
    data[  18] =  'sd2635;
    data[  19] = -'sd63711;
    data[  20] =  'sd36597;
    data[  21] =  'sd79958;
    data[  22] = -'sd74575;
    data[  23] = -'sd48553;
    data[  24] = -'sd42763;
    data[  25] =  'sd13416;
    data[  26] =  'sd18285;
    data[  27] =  'sd39466;
    data[  28] =  'sd25139;
    data[  29] = -'sd27764;
    data[  30] = -'sd71986;
    data[  31] =  'sd49829;
    data[  32] = -'sd72590;
    data[  33] =  'sd26877;
    data[  34] =  'sd38280;
    data[  35] = -'sd19929;
    data[  36] =  'sd61903;
    data[  37] =  'sd58540;
    data[  38] = -'sd69254;
    data[  39] = -'sd10196;
    data[  40] = -'sd59766;
    data[  41] =  'sd22666;
    data[  42] =  'sd42103;
    data[  43] = -'sd38496;
    data[  44] =  'sd11721;
    data[  45] = -'sd46125;
    data[  46] =  'sd49501;
    data[  47] =  'sd78787;
    data[  48] =  'sd44768;
    data[  49] =  'sd62774;
    data[  50] = -'sd72203;
    data[  51] =  'sd41583;
    data[  52] = -'sd58256;
    data[  53] =  'sd80046;
    data[  54] = -'sd71231;
    data[  55] =  'sd78519;
    data[  56] =  'sd34584;
    data[  57] =  'sd3464;
    data[  58] = -'sd32209;
    data[  59] = -'sd77055;
    data[  60] =  'sd21048;
    data[  61] = -'sd19381;
    data[  62] = -'sd81114;
    data[  63] =  'sd30647;
    data[  64] =  'sd17699;
    data[  65] =  'sd17198;
    data[  66] = -'sd1840;
    data[  67] = -'sd69920;
    data[  68] = -'sd35504;
    data[  69] = -'sd38424;
    data[  70] =  'sd14457;
    data[  71] =  'sd57843;
    data[  72] =  'sd68101;
    data[  73] = -'sd33618;
    data[  74] =  'sd33244;
    data[  75] = -'sd47456;
    data[  76] = -'sd1077;
    data[  77] = -'sd40926;
    data[  78] = -'sd80619;
    data[  79] =  'sd49457;
    data[  80] =  'sd77115;
    data[  81] = -'sd18768;
    data[  82] = -'sd57820;
    data[  83] = -'sd67227;
    data[  84] =  'sd66830;
    data[  85] = -'sd81916;
    data[  86] =  'sd171;
    data[  87] =  'sd6498;
    data[  88] = -'sd80758;
    data[  89] =  'sd44175;
    data[  90] =  'sd40240;
    data[  91] =  'sd54551;
    data[  92] = -'sd56995;
    data[  93] = -'sd35877;
    data[  94] = -'sd52598;
    data[  95] = -'sd32632;
    data[  96] =  'sd70712;
    data[  97] =  'sd65600;
    data[  98] =  'sd35185;
    data[  99] =  'sd26302;
    data[ 100] =  'sd16430;
    data[ 101] = -'sd31024;
    data[ 102] = -'sd32025;
    data[ 103] = -'sd70063;
    data[ 104] = -'sd40938;
    data[ 105] = -'sd81075;
    data[ 106] =  'sd32129;
    data[ 107] =  'sd74015;
    data[ 108] =  'sd27273;
    data[ 109] =  'sd53328;
    data[ 110] =  'sd60372;
    data[ 111] =  'sd362;
    data[ 112] =  'sd13756;
    data[ 113] =  'sd31205;
    data[ 114] =  'sd38903;
    data[ 115] =  'sd3745;
    data[ 116] = -'sd21531;
    data[ 117] =  'sd1027;
    data[ 118] =  'sd39026;
    data[ 119] =  'sd8419;
    data[ 120] = -'sd7760;
    data[ 121] =  'sd32802;
    data[ 122] = -'sd64252;
    data[ 123] =  'sd16039;
    data[ 124] = -'sd45882;
    data[ 125] =  'sd58735;
    data[ 126] = -'sd61844;
    data[ 127] = -'sd56298;
    data[ 128] = -'sd9391;
    data[ 129] = -'sd29176;
    data[ 130] =  'sd38199;
    data[ 131] = -'sd23007;
    data[ 132] = -'sd55061;
    data[ 133] =  'sd37615;
    data[ 134] = -'sd45199;
    data[ 135] = -'sd79152;
    data[ 136] = -'sd58638;
    data[ 137] =  'sd65530;
    data[ 138] =  'sd32525;
    data[ 139] = -'sd74778;
    data[ 140] = -'sd56267;
    data[ 141] = -'sd8213;
    data[ 142] =  'sd15588;
    data[ 143] = -'sd63020;
    data[ 144] =  'sd62855;
    data[ 145] = -'sd69125;
    data[ 146] = -'sd5294;
    data[ 147] = -'sd37331;
    data[ 148] =  'sd55991;
    data[ 149] = -'sd2275;
    data[ 150] =  'sd77391;
    data[ 151] = -'sd8280;
    data[ 152] =  'sd13042;
    data[ 153] =  'sd4073;
    data[ 154] = -'sd9067;
    data[ 155] = -'sd16864;
    data[ 156] =  'sd14532;
    data[ 157] =  'sd60693;
    data[ 158] =  'sd12560;
    data[ 159] = -'sd14243;
    data[ 160] = -'sd49711;
    data[ 161] =  'sd77074;
    data[ 162] = -'sd20326;
    data[ 163] =  'sd46817;
    data[ 164] = -'sd23205;
    data[ 165] = -'sd62585;
    data[ 166] =  'sd79385;
    data[ 167] =  'sd67492;
    data[ 168] = -'sd56760;
    data[ 169] = -'sd26947;
    data[ 170] = -'sd40940;
    data[ 171] = -'sd81151;
    data[ 172] =  'sd29241;
    data[ 173] = -'sd35729;
    data[ 174] = -'sd46974;
    data[ 175] =  'sd17239;
    data[ 176] = -'sd282;
    data[ 177] = -'sd10716;
    data[ 178] = -'sd79526;
    data[ 179] = -'sd72850;
    data[ 180] =  'sd16997;
    data[ 181] = -'sd9478;
    data[ 182] = -'sd32482;
    data[ 183] =  'sd76412;
    data[ 184] = -'sd45482;
    data[ 185] =  'sd73935;
    data[ 186] =  'sd24233;
    data[ 187] = -'sd62192;
    data[ 188] = -'sd69522;
    data[ 189] = -'sd20380;
    data[ 190] =  'sd44765;
    data[ 191] =  'sd62660;
    data[ 192] = -'sd76535;
    data[ 193] =  'sd40808;
    data[ 194] =  'sd76135;
    data[ 195] = -'sd56008;
    data[ 196] =  'sd1629;
    data[ 197] =  'sd61902;
    data[ 198] =  'sd58502;
    data[ 199] = -'sd70698;
    data[ 200] = -'sd65068;
    data[ 201] = -'sd14969;
    data[ 202] = -'sd77299;
    data[ 203] =  'sd11776;
    data[ 204] = -'sd44035;
    data[ 205] = -'sd34920;
    data[ 206] = -'sd16232;
    data[ 207] =  'sd38548;
    data[ 208] = -'sd9745;
    data[ 209] = -'sd42628;
    data[ 210] =  'sd18546;
    data[ 211] =  'sd49384;
    data[ 212] =  'sd74341;
    data[ 213] =  'sd39661;
    data[ 214] =  'sd32549;
    data[ 215] = -'sd73866;
    data[ 216] = -'sd21611;
    data[ 217] = -'sd2013;
    data[ 218] = -'sd76494;
    data[ 219] =  'sd42366;
    data[ 220] = -'sd28502;
    data[ 221] =  'sd63811;
    data[ 222] = -'sd32797;
    data[ 223] =  'sd64442;
    data[ 224] = -'sd8819;
    data[ 225] = -'sd7440;
    data[ 226] =  'sd44962;
    data[ 227] =  'sd70146;
    data[ 228] =  'sd44092;
    data[ 229] =  'sd37086;
    data[ 230] = -'sd65301;
    data[ 231] = -'sd23823;
    data[ 232] =  'sd77772;
    data[ 233] =  'sd6198;
    data[ 234] =  'sd71683;
    data[ 235] = -'sd61343;
    data[ 236] = -'sd37260;
    data[ 237] =  'sd58689;
    data[ 238] = -'sd63592;
    data[ 239] =  'sd41119;
    data[ 240] = -'sd75888;
    data[ 241] =  'sd65394;
    data[ 242] =  'sd27357;
    data[ 243] =  'sd56520;
    data[ 244] =  'sd17827;
    data[ 245] =  'sd22062;
    data[ 246] =  'sd19151;
    data[ 247] =  'sd72374;
    data[ 248] = -'sd35085;
    data[ 249] = -'sd22502;
    data[ 250] = -'sd35871;
    data[ 251] = -'sd52370;
    data[ 252] = -'sd23968;
    data[ 253] =  'sd72262;
    data[ 254] = -'sd39341;
    data[ 255] = -'sd20389;
    data[ 256] =  'sd44423;
    data[ 257] =  'sd49664;
    data[ 258] = -'sd78860;
    data[ 259] = -'sd47542;
    data[ 260] = -'sd4345;
    data[ 261] = -'sd1269;
    data[ 262] = -'sd48222;
    data[ 263] = -'sd30185;
    data[ 264] = -'sd143;
    data[ 265] = -'sd5434;
    data[ 266] = -'sd42651;
    data[ 267] =  'sd17672;
    data[ 268] =  'sd16172;
    data[ 269] = -'sd40828;
    data[ 270] = -'sd76895;
    data[ 271] =  'sd27128;
    data[ 272] =  'sd47818;
    data[ 273] =  'sd14833;
    data[ 274] =  'sd72131;
    data[ 275] = -'sd44319;
    data[ 276] = -'sd45712;
    data[ 277] =  'sd65195;
    data[ 278] =  'sd19795;
    data[ 279] = -'sd66995;
    data[ 280] =  'sd75646;
    data[ 281] = -'sd74590;
    data[ 282] = -'sd49123;
    data[ 283] = -'sd64423;
    data[ 284] =  'sd9541;
    data[ 285] =  'sd34876;
    data[ 286] =  'sd14560;
    data[ 287] =  'sd61757;
    data[ 288] =  'sd52992;
    data[ 289] =  'sd47604;
    data[ 290] =  'sd6701;
    data[ 291] = -'sd73044;
    data[ 292] =  'sd9625;
    data[ 293] =  'sd38068;
    data[ 294] = -'sd27985;
    data[ 295] = -'sd80384;
    data[ 296] =  'sd58387;
    data[ 297] = -'sd75068;
    data[ 298] = -'sd67287;
    data[ 299] =  'sd64550;
    data[ 300] = -'sd4715;
    data[ 301] = -'sd15329;
    data[ 302] =  'sd72862;
    data[ 303] = -'sd16541;
    data[ 304] =  'sd26806;
    data[ 305] =  'sd35582;
    data[ 306] =  'sd41388;
    data[ 307] = -'sd65666;
    data[ 308] = -'sd37693;
    data[ 309] =  'sd42235;
    data[ 310] = -'sd33480;
    data[ 311] =  'sd38488;
    data[ 312] = -'sd12025;
    data[ 313] =  'sd34573;
    data[ 314] =  'sd3046;
    data[ 315] = -'sd48093;
    data[ 316] = -'sd25283;
    data[ 317] =  'sd22292;
    data[ 318] =  'sd27891;
    data[ 319] =  'sd76812;
    data[ 320] = -'sd30282;
    data[ 321] = -'sd3829;
    data[ 322] =  'sd18339;
    data[ 323] =  'sd41518;
    data[ 324] = -'sd60726;
    data[ 325] = -'sd13814;
    data[ 326] = -'sd33409;
    data[ 327] =  'sd41186;
    data[ 328] = -'sd73342;
    data[ 329] = -'sd1699;
    data[ 330] = -'sd64562;
    data[ 331] =  'sd4259;
    data[ 332] = -'sd1999;
    data[ 333] = -'sd75962;
    data[ 334] =  'sd62582;
    data[ 335] = -'sd79499;
    data[ 336] = -'sd71824;
    data[ 337] =  'sd55985;
    data[ 338] = -'sd2503;
    data[ 339] =  'sd68727;
    data[ 340] = -'sd9830;
    data[ 341] = -'sd45858;
    data[ 342] =  'sd59647;
    data[ 343] = -'sd27188;
    data[ 344] = -'sd50098;
    data[ 345] =  'sd62368;
    data[ 346] =  'sd76210;
    data[ 347] = -'sd53158;
    data[ 348] = -'sd53912;
    data[ 349] =  'sd81277;
    data[ 350] = -'sd24453;
    data[ 351] =  'sd53832;
    data[ 352] =  'sd79524;
    data[ 353] =  'sd72774;
    data[ 354] = -'sd19885;
    data[ 355] =  'sd63575;
    data[ 356] = -'sd41765;
    data[ 357] =  'sd51340;
    data[ 358] = -'sd15172;
    data[ 359] =  'sd78828;
    data[ 360] =  'sd46326;
    data[ 361] = -'sd41863;
    data[ 362] =  'sd47616;
    data[ 363] =  'sd7157;
    data[ 364] = -'sd55716;
    data[ 365] =  'sd12725;
    data[ 366] = -'sd7973;
    data[ 367] =  'sd24708;
    data[ 368] = -'sd44142;
    data[ 369] = -'sd38986;
    data[ 370] = -'sd6899;
    data[ 371] =  'sd65520;
    data[ 372] =  'sd32145;
    data[ 373] =  'sd74623;
    data[ 374] =  'sd50377;
    data[ 375] = -'sd51766;
    data[ 376] = -'sd1016;
    data[ 377] = -'sd38608;
    data[ 378] =  'sd7465;
    data[ 379] = -'sd44012;
    data[ 380] = -'sd34046;
    data[ 381] =  'sd16980;
    data[ 382] = -'sd10124;
    data[ 383] = -'sd57030;
    data[ 384] = -'sd37207;
    data[ 385] =  'sd60703;
    data[ 386] =  'sd12940;
    data[ 387] =  'sd197;
    data[ 388] =  'sd7486;
    data[ 389] = -'sd43214;
    data[ 390] = -'sd3722;
    data[ 391] =  'sd22405;
    data[ 392] =  'sd32185;
    data[ 393] =  'sd76143;
    data[ 394] = -'sd55704;
    data[ 395] =  'sd13181;
    data[ 396] =  'sd9355;
    data[ 397] =  'sd27808;
    data[ 398] =  'sd73658;
    data[ 399] =  'sd13707;
    data[ 400] =  'sd29343;
    data[ 401] = -'sd31853;
    data[ 402] = -'sd63527;
    data[ 403] =  'sd43589;
    data[ 404] =  'sd17972;
    data[ 405] =  'sd27572;
    data[ 406] =  'sd64690;
    data[ 407] =  'sd605;
    data[ 408] =  'sd22990;
    data[ 409] =  'sd54415;
    data[ 410] = -'sd62163;
    data[ 411] = -'sd68420;
    data[ 412] =  'sd21496;
    data[ 413] = -'sd2357;
    data[ 414] =  'sd74275;
    data[ 415] =  'sd37153;
    data[ 416] = -'sd62755;
    data[ 417] =  'sd72925;
    data[ 418] = -'sd14147;
    data[ 419] = -'sd46063;
    data[ 420] =  'sd51857;
    data[ 421] =  'sd4474;
    data[ 422] =  'sd6171;
    data[ 423] =  'sd70657;
    data[ 424] =  'sd63510;
    data[ 425] = -'sd44235;
    data[ 426] = -'sd42520;
    data[ 427] =  'sd22650;
    data[ 428] =  'sd41495;
    data[ 429] = -'sd61600;
    data[ 430] = -'sd47026;
    data[ 431] =  'sd15263;
    data[ 432] = -'sd75370;
    data[ 433] = -'sd78763;
    data[ 434] = -'sd43856;
    data[ 435] = -'sd28118;
    data[ 436] =  'sd78403;
    data[ 437] =  'sd30176;
    data[ 438] = -'sd199;
    data[ 439] = -'sd7562;
    data[ 440] =  'sd40326;
    data[ 441] =  'sd57819;
    data[ 442] =  'sd67189;
    data[ 443] = -'sd68274;
    data[ 444] =  'sd27044;
    data[ 445] =  'sd44626;
    data[ 446] =  'sd57378;
    data[ 447] =  'sd50431;
    data[ 448] = -'sd49714;
    data[ 449] =  'sd76960;
    data[ 450] = -'sd24658;
    data[ 451] =  'sd46042;
    data[ 452] = -'sd52655;
    data[ 453] = -'sd34798;
    data[ 454] = -'sd11596;
    data[ 455] =  'sd50875;
    data[ 456] = -'sd32842;
    data[ 457] =  'sd62732;
    data[ 458] = -'sd73799;
    data[ 459] = -'sd19065;
    data[ 460] = -'sd69106;
    data[ 461] = -'sd4572;
    data[ 462] = -'sd9895;
    data[ 463] = -'sd48328;
    data[ 464] = -'sd34213;
    data[ 465] =  'sd10634;
    data[ 466] =  'sd76410;
    data[ 467] = -'sd45558;
    data[ 468] =  'sd71047;
    data[ 469] =  'sd78330;
    data[ 470] =  'sd27402;
    data[ 471] =  'sd58230;
    data[ 472] = -'sd81034;
    data[ 473] =  'sd33687;
    data[ 474] = -'sd30622;
    data[ 475] = -'sd16749;
    data[ 476] =  'sd18902;
    data[ 477] =  'sd62912;
    data[ 478] = -'sd66959;
    data[ 479] =  'sd77014;
    data[ 480] = -'sd22606;
    data[ 481] = -'sd39823;
    data[ 482] = -'sd38705;
    data[ 483] =  'sd3779;
    data[ 484] = -'sd20239;
    data[ 485] =  'sd50123;
    data[ 486] = -'sd61418;
    data[ 487] = -'sd40110;
    data[ 488] = -'sd49611;
    data[ 489] =  'sd80874;
    data[ 490] = -'sd39767;
    data[ 491] = -'sd36577;
    data[ 492] = -'sd79198;
    data[ 493] = -'sd60386;
    data[ 494] = -'sd894;
    data[ 495] = -'sd33972;
    data[ 496] =  'sd19792;
    data[ 497] = -'sd67109;
    data[ 498] =  'sd71314;
    data[ 499] = -'sd75365;
    data[ 500] = -'sd78573;
    data[ 501] = -'sd36636;
    data[ 502] = -'sd81440;
    data[ 503] =  'sd18259;
    data[ 504] =  'sd38478;
    data[ 505] = -'sd12405;
    data[ 506] =  'sd20133;
    data[ 507] = -'sd54151;
    data[ 508] =  'sd72195;
    data[ 509] = -'sd41887;
    data[ 510] =  'sd46704;
    data[ 511] = -'sd27499;
    data[ 512] = -'sd61916;
    data[ 513] = -'sd59034;
    data[ 514] =  'sd50482;
    data[ 515] = -'sd47776;
    data[ 516] = -'sd13237;
    data[ 517] = -'sd11483;
    data[ 518] =  'sd55169;
    data[ 519] = -'sd33511;
    data[ 520] =  'sd37310;
    data[ 521] = -'sd56789;
    data[ 522] = -'sd28049;
    data[ 523] =  'sd81025;
    data[ 524] = -'sd34029;
    data[ 525] =  'sd17626;
    data[ 526] =  'sd14424;
    data[ 527] =  'sd56589;
    data[ 528] =  'sd20449;
    data[ 529] = -'sd42143;
    data[ 530] =  'sd36976;
    data[ 531] = -'sd69481;
    data[ 532] = -'sd18822;
    data[ 533] = -'sd59872;
    data[ 534] =  'sd18638;
    data[ 535] =  'sd52880;
    data[ 536] =  'sd43348;
    data[ 537] =  'sd8814;
    data[ 538] =  'sd7250;
    data[ 539] = -'sd52182;
    data[ 540] = -'sd16824;
    data[ 541] =  'sd16052;
    data[ 542] = -'sd45388;
    data[ 543] =  'sd77507;
    data[ 544] = -'sd3872;
    data[ 545] =  'sd16705;
    data[ 546] = -'sd20574;
    data[ 547] =  'sd37393;
    data[ 548] = -'sd53635;
    data[ 549] = -'sd72038;
    data[ 550] =  'sd47853;
    data[ 551] =  'sd16163;
    data[ 552] = -'sd41170;
    data[ 553] =  'sd73950;
    data[ 554] =  'sd24803;
    data[ 555] = -'sd40532;
    data[ 556] = -'sd65647;
    data[ 557] = -'sd36971;
    data[ 558] =  'sd69671;
    data[ 559] =  'sd26042;
    data[ 560] =  'sd6550;
    data[ 561] = -'sd78782;
    data[ 562] = -'sd44578;
    data[ 563] = -'sd55554;
    data[ 564] =  'sd18881;
    data[ 565] =  'sd62114;
    data[ 566] =  'sd66558;
    data[ 567] =  'sd71589;
    data[ 568] = -'sd64915;
    data[ 569] = -'sd9155;
    data[ 570] = -'sd20208;
    data[ 571] =  'sd51301;
    data[ 572] = -'sd16654;
    data[ 573] =  'sd22512;
    data[ 574] =  'sd36251;
    data[ 575] =  'sd66810;
    data[ 576] =  'sd81165;
    data[ 577] = -'sd28709;
    data[ 578] =  'sd55945;
    data[ 579] = -'sd4023;
    data[ 580] =  'sd10967;
    data[ 581] = -'sd74777;
    data[ 582] = -'sd56229;
    data[ 583] = -'sd6769;
    data[ 584] =  'sd70460;
    data[ 585] =  'sd56024;
    data[ 586] = -'sd1021;
    data[ 587] = -'sd38798;
    data[ 588] =  'sd245;
    data[ 589] =  'sd9310;
    data[ 590] =  'sd26098;
    data[ 591] =  'sd8678;
    data[ 592] =  'sd2082;
    data[ 593] =  'sd79116;
    data[ 594] =  'sd57270;
    data[ 595] =  'sd46327;
    data[ 596] = -'sd41825;
    data[ 597] =  'sd49060;
    data[ 598] =  'sd62029;
    data[ 599] =  'sd63328;
    data[ 600] = -'sd51151;
    data[ 601] =  'sd22354;
    data[ 602] =  'sd30247;
    data[ 603] =  'sd2499;
    data[ 604] = -'sd68879;
    data[ 605] =  'sd4054;
    data[ 606] = -'sd9789;
    data[ 607] = -'sd44300;
    data[ 608] = -'sd44990;
    data[ 609] = -'sd71210;
    data[ 610] =  'sd79317;
    data[ 611] =  'sd64908;
    data[ 612] =  'sd8889;
    data[ 613] =  'sd10100;
    data[ 614] =  'sd56118;
    data[ 615] =  'sd2551;
    data[ 616] = -'sd66903;
    data[ 617] =  'sd79142;
    data[ 618] =  'sd58258;
    data[ 619] = -'sd79970;
    data[ 620] =  'sd74119;
    data[ 621] =  'sd31225;
    data[ 622] =  'sd39663;
    data[ 623] =  'sd32625;
    data[ 624] = -'sd70978;
    data[ 625] = -'sd75708;
    data[ 626] =  'sd72234;
    data[ 627] = -'sd40405;
    data[ 628] = -'sd60821;
    data[ 629] = -'sd17424;
    data[ 630] = -'sd6748;
    data[ 631] =  'sd71258;
    data[ 632] = -'sd77493;
    data[ 633] =  'sd4404;
    data[ 634] =  'sd3511;
    data[ 635] = -'sd30423;
    data[ 636] = -'sd9187;
    data[ 637] = -'sd21424;
    data[ 638] =  'sd5093;
    data[ 639] =  'sd29693;
    data[ 640] = -'sd18553;
    data[ 641] = -'sd49650;
    data[ 642] =  'sd79392;
    data[ 643] =  'sd67758;
    data[ 644] = -'sd46652;
    data[ 645] =  'sd29475;
    data[ 646] = -'sd26837;
    data[ 647] = -'sd36760;
    data[ 648] =  'sd77689;
    data[ 649] =  'sd3044;
    data[ 650] = -'sd48169;
    data[ 651] = -'sd28171;
    data[ 652] =  'sd76389;
    data[ 653] = -'sd46356;
    data[ 654] =  'sd40723;
    data[ 655] =  'sd72905;
    data[ 656] = -'sd14907;
    data[ 657] = -'sd74943;
    data[ 658] = -'sd62537;
    data[ 659] =  'sd81209;
    data[ 660] = -'sd27037;
    data[ 661] = -'sd44360;
    data[ 662] = -'sd47270;
    data[ 663] =  'sd5991;
    data[ 664] =  'sd63817;
    data[ 665] = -'sd32569;
    data[ 666] =  'sd73106;
    data[ 667] = -'sd7269;
    data[ 668] =  'sd51460;
    data[ 669] = -'sd10612;
    data[ 670] = -'sd75574;
    data[ 671] =  'sd77326;
    data[ 672] = -'sd10750;
    data[ 673] = -'sd80818;
    data[ 674] =  'sd41895;
    data[ 675] = -'sd46400;
    data[ 676] =  'sd39051;
    data[ 677] =  'sd9369;
    data[ 678] =  'sd28340;
    data[ 679] = -'sd69967;
    data[ 680] = -'sd37290;
    data[ 681] =  'sd57549;
    data[ 682] =  'sd56929;
    data[ 683] =  'sd33369;
    data[ 684] = -'sd42706;
    data[ 685] =  'sd15582;
    data[ 686] = -'sd63248;
    data[ 687] =  'sd54191;
    data[ 688] = -'sd70675;
    data[ 689] = -'sd64194;
    data[ 690] =  'sd18243;
    data[ 691] =  'sd37870;
    data[ 692] = -'sd35509;
    data[ 693] = -'sd38614;
    data[ 694] =  'sd7237;
    data[ 695] = -'sd52676;
    data[ 696] = -'sd35596;
    data[ 697] = -'sd41920;
    data[ 698] =  'sd45450;
    data[ 699] = -'sd75151;
    data[ 700] = -'sd70441;
    data[ 701] = -'sd55302;
    data[ 702] =  'sd28457;
    data[ 703] = -'sd65521;
    data[ 704] = -'sd32183;
    data[ 705] = -'sd76067;
    data[ 706] =  'sd58592;
    data[ 707] = -'sd67278;
    data[ 708] =  'sd64892;
    data[ 709] =  'sd8281;
    data[ 710] = -'sd13004;
    data[ 711] = -'sd2629;
    data[ 712] =  'sd63939;
    data[ 713] = -'sd27933;
    data[ 714] = -'sd78408;
    data[ 715] = -'sd30366;
    data[ 716] = -'sd7021;
    data[ 717] =  'sd60884;
    data[ 718] =  'sd19818;
    data[ 719] = -'sd66121;
    data[ 720] = -'sd54983;
    data[ 721] =  'sd40579;
    data[ 722] =  'sd67433;
    data[ 723] = -'sd59002;
    data[ 724] =  'sd51698;
    data[ 725] = -'sd1568;
    data[ 726] = -'sd59584;
    data[ 727] =  'sd29582;
    data[ 728] = -'sd22771;
    data[ 729] = -'sd46093;
    data[ 730] =  'sd50717;
    data[ 731] = -'sd38846;
    data[ 732] = -'sd1579;
    data[ 733] = -'sd60002;
    data[ 734] =  'sd13698;
    data[ 735] =  'sd29001;
    data[ 736] = -'sd44849;
    data[ 737] = -'sd65852;
    data[ 738] = -'sd44761;
    data[ 739] = -'sd62508;
    data[ 740] = -'sd81530;
    data[ 741] =  'sd14839;
    data[ 742] =  'sd72359;
    data[ 743] = -'sd35655;
    data[ 744] = -'sd44162;
    data[ 745] = -'sd39746;
    data[ 746] = -'sd35779;
    data[ 747] = -'sd48874;
    data[ 748] = -'sd54961;
    data[ 749] =  'sd41415;
    data[ 750] = -'sd64640;
    data[ 751] =  'sd1295;
    data[ 752] =  'sd49210;
    data[ 753] =  'sd67729;
    data[ 754] = -'sd47754;
    data[ 755] = -'sd12401;
    data[ 756] =  'sd20285;
    data[ 757] = -'sd48375;
    data[ 758] = -'sd35999;
    data[ 759] = -'sd57234;
    data[ 760] = -'sd44959;
    data[ 761] = -'sd70032;
    data[ 762] = -'sd39760;
    data[ 763] = -'sd36311;
    data[ 764] = -'sd69090;
    data[ 765] = -'sd3964;
    data[ 766] =  'sd13209;
    data[ 767] =  'sd10419;
    data[ 768] =  'sd68240;
    data[ 769] = -'sd28336;
    data[ 770] =  'sd70119;
    data[ 771] =  'sd43066;
    data[ 772] = -'sd1902;
    data[ 773] = -'sd72276;
    data[ 774] =  'sd38809;
    data[ 775] =  'sd173;
    data[ 776] =  'sd6574;
    data[ 777] = -'sd77870;
    data[ 778] = -'sd9922;
    data[ 779] = -'sd49354;
    data[ 780] = -'sd73201;
    data[ 781] =  'sd3659;
    data[ 782] = -'sd24799;
    data[ 783] =  'sd40684;
    data[ 784] =  'sd71423;
    data[ 785] = -'sd71223;
    data[ 786] =  'sd78823;
    data[ 787] =  'sd46136;
    data[ 788] = -'sd49083;
    data[ 789] = -'sd62903;
    data[ 790] =  'sd67301;
    data[ 791] = -'sd64018;
    data[ 792] =  'sd24931;
    data[ 793] = -'sd35668;
    data[ 794] = -'sd44656;
    data[ 795] = -'sd58518;
    data[ 796] =  'sd70090;
    data[ 797] =  'sd41964;
    data[ 798] = -'sd43778;
    data[ 799] = -'sd25154;
    data[ 800] =  'sd27194;
    data[ 801] =  'sd50326;
    data[ 802] = -'sd53704;
    data[ 803] = -'sd74660;
    data[ 804] = -'sd51783;
    data[ 805] = -'sd1662;
    data[ 806] = -'sd63156;
    data[ 807] =  'sd57687;
    data[ 808] =  'sd62173;
    data[ 809] =  'sd68800;
    data[ 810] = -'sd7056;
    data[ 811] =  'sd59554;
    data[ 812] = -'sd30722;
    data[ 813] = -'sd20549;
    data[ 814] =  'sd38343;
    data[ 815] = -'sd17535;
    data[ 816] = -'sd10966;
    data[ 817] =  'sd74815;
    data[ 818] =  'sd57673;
    data[ 819] =  'sd61641;
    data[ 820] =  'sd48584;
    data[ 821] =  'sd43941;
    data[ 822] =  'sd31348;
    data[ 823] =  'sd44337;
    data[ 824] =  'sd46396;
    data[ 825] = -'sd39203;
    data[ 826] = -'sd15145;
    data[ 827] =  'sd79854;
    data[ 828] = -'sd78527;
    data[ 829] = -'sd34888;
    data[ 830] = -'sd15016;
    data[ 831] = -'sd79085;
    data[ 832] = -'sd56092;
    data[ 833] = -'sd1563;
    data[ 834] = -'sd59394;
    data[ 835] =  'sd36802;
    data[ 836] = -'sd76093;
    data[ 837] =  'sd57604;
    data[ 838] =  'sd59019;
    data[ 839] = -'sd51052;
    data[ 840] =  'sd26116;
    data[ 841] =  'sd9362;
    data[ 842] =  'sd28074;
    data[ 843] = -'sd80075;
    data[ 844] =  'sd70129;
    data[ 845] =  'sd43446;
    data[ 846] =  'sd12538;
    data[ 847] = -'sd15079;
    data[ 848] = -'sd81479;
    data[ 849] =  'sd16777;
    data[ 850] = -'sd17838;
    data[ 851] = -'sd22480;
    data[ 852] = -'sd35035;
    data[ 853] = -'sd20602;
    data[ 854] =  'sd36329;
    data[ 855] =  'sd69774;
    data[ 856] =  'sd29956;
    data[ 857] = -'sd8559;
    data[ 858] =  'sd2440;
    data[ 859] = -'sd71121;
    data[ 860] = -'sd81142;
    data[ 861] =  'sd29583;
    data[ 862] = -'sd22733;
    data[ 863] = -'sd44649;
    data[ 864] = -'sd58252;
    data[ 865] =  'sd80198;
    data[ 866] = -'sd65455;
    data[ 867] = -'sd29675;
    data[ 868] =  'sd19237;
    data[ 869] =  'sd75642;
    data[ 870] = -'sd74742;
    data[ 871] = -'sd54899;
    data[ 872] =  'sd43771;
    data[ 873] =  'sd24888;
    data[ 874] = -'sd37302;
    data[ 875] =  'sd57093;
    data[ 876] =  'sd39601;
    data[ 877] =  'sd30269;
    data[ 878] =  'sd3335;
    data[ 879] = -'sd37111;
    data[ 880] =  'sd64351;
    data[ 881] = -'sd12277;
    data[ 882] =  'sd24997;
    data[ 883] = -'sd33160;
    data[ 884] =  'sd50648;
    data[ 885] = -'sd41468;
    data[ 886] =  'sd62626;
    data[ 887] = -'sd77827;
    data[ 888] = -'sd8288;
    data[ 889] =  'sd12738;
    data[ 890] = -'sd7479;
    data[ 891] =  'sd43480;
    data[ 892] =  'sd13830;
    data[ 893] =  'sd34017;
    data[ 894] = -'sd18082;
    data[ 895] = -'sd31752;
    data[ 896] = -'sd59689;
    data[ 897] =  'sd25592;
    data[ 898] = -'sd10550;
    data[ 899] = -'sd73218;
    data[ 900] =  'sd3013;
    data[ 901] = -'sd49347;
    data[ 902] = -'sd72935;
    data[ 903] =  'sd13767;
    data[ 904] =  'sd31623;
    data[ 905] =  'sd54787;
    data[ 906] = -'sd48027;
    data[ 907] = -'sd22775;
    data[ 908] = -'sd46245;
    data[ 909] =  'sd44941;
    data[ 910] =  'sd69348;
    data[ 911] =  'sd13768;
    data[ 912] =  'sd31661;
    data[ 913] =  'sd56231;
    data[ 914] =  'sd6845;
    data[ 915] = -'sd67572;
    data[ 916] =  'sd53720;
    data[ 917] =  'sd75268;
    data[ 918] =  'sd74887;
    data[ 919] =  'sd60409;
    data[ 920] =  'sd1768;
    data[ 921] =  'sd67184;
    data[ 922] = -'sd68464;
    data[ 923] =  'sd19824;
    data[ 924] = -'sd65893;
    data[ 925] = -'sd46319;
    data[ 926] =  'sd42129;
    data[ 927] = -'sd37508;
    data[ 928] =  'sd49265;
    data[ 929] =  'sd69819;
    data[ 930] =  'sd31666;
    data[ 931] =  'sd56421;
    data[ 932] =  'sd14065;
    data[ 933] =  'sd42947;
    data[ 934] = -'sd6424;
    data[ 935] = -'sd80271;
    data[ 936] =  'sd62681;
    data[ 937] = -'sd75737;
    data[ 938] =  'sd71132;
    data[ 939] =  'sd81560;
    data[ 940] = -'sd13699;
    data[ 941] = -'sd29039;
    data[ 942] =  'sd43405;
    data[ 943] =  'sd10980;
    data[ 944] = -'sd74283;
    data[ 945] = -'sd37457;
    data[ 946] =  'sd51203;
    data[ 947] = -'sd20378;
    data[ 948] =  'sd44841;
    data[ 949] =  'sd65548;
    data[ 950] =  'sd33209;
    data[ 951] = -'sd48786;
    data[ 952] = -'sd51617;
    data[ 953] =  'sd4646;
    data[ 954] =  'sd12707;
    data[ 955] = -'sd8657;
    data[ 956] = -'sd1284;
    data[ 957] = -'sd48792;
    data[ 958] = -'sd51845;
    data[ 959] = -'sd4018;
    data[ 960] =  'sd11157;
    data[ 961] = -'sd67557;
    data[ 962] =  'sd54290;
    data[ 963] = -'sd66913;
    data[ 964] =  'sd78762;
    data[ 965] =  'sd43818;
    data[ 966] =  'sd26674;
    data[ 967] =  'sd30566;
    data[ 968] =  'sd14621;
    data[ 969] =  'sd64075;
    data[ 970] = -'sd22765;
    data[ 971] = -'sd45865;
    data[ 972] =  'sd59381;
    data[ 973] = -'sd37296;
    data[ 974] =  'sd57321;
    data[ 975] =  'sd48265;
    data[ 976] =  'sd31819;
    data[ 977] =  'sd62235;
    data[ 978] =  'sd71156;
    data[ 979] = -'sd81369;
    data[ 980] =  'sd20957;
    data[ 981] = -'sd22839;
    data[ 982] = -'sd48677;
    data[ 983] = -'sd47475;
    data[ 984] = -'sd1799;
    data[ 985] = -'sd68362;
    data[ 986] =  'sd23700;
    data[ 987] =  'sd81395;
    data[ 988] = -'sd19969;
    data[ 989] =  'sd60383;
    data[ 990] =  'sd780;
    data[ 991] =  'sd29640;
    data[ 992] = -'sd20567;
    data[ 993] =  'sd37659;
    data[ 994] = -'sd43527;
    data[ 995] = -'sd15616;
    data[ 996] =  'sd61956;
    data[ 997] =  'sd60554;
    data[ 998] =  'sd7278;
    data[ 999] = -'sd51118;
    data[1000] =  'sd23608;
    data[1001] =  'sd77899;
    data[1002] =  'sd11024;
    data[1003] = -'sd72611;
    data[1004] =  'sd26079;
    data[1005] =  'sd7956;
    data[1006] = -'sd25354;
    data[1007] =  'sd19594;
    data[1008] = -'sd74633;
    data[1009] = -'sd50757;
    data[1010] =  'sd37326;
    data[1011] = -'sd56181;
    data[1012] = -'sd4945;
    data[1013] = -'sd24069;
    data[1014] =  'sd68424;
    data[1015] = -'sd21344;
    data[1016] =  'sd8133;
    data[1017] = -'sd18628;
    data[1018] = -'sd52500;
    data[1019] = -'sd28908;
    data[1020] =  'sd48383;
    data[1021] =  'sd36303;
    data[1022] =  'sd68786;
    data[1023] = -'sd7588;
    data[1024] =  'sd39338;
    data[1025] =  'sd20275;
    data[1026] = -'sd48755;
    data[1027] = -'sd50439;
    data[1028] =  'sd49410;
    data[1029] =  'sd75329;
    data[1030] =  'sd77205;
    data[1031] = -'sd15348;
    data[1032] =  'sd72140;
    data[1033] = -'sd43977;
    data[1034] = -'sd32716;
    data[1035] =  'sd67520;
    data[1036] = -'sd55696;
    data[1037] =  'sd13485;
    data[1038] =  'sd20907;
    data[1039] = -'sd24739;
    data[1040] =  'sd42964;
    data[1041] = -'sd5778;
    data[1042] = -'sd55723;
    data[1043] =  'sd12459;
    data[1044] = -'sd18081;
    data[1045] = -'sd31714;
    data[1046] = -'sd58245;
    data[1047] =  'sd80464;
    data[1048] = -'sd55347;
    data[1049] =  'sd26747;
    data[1050] =  'sd33340;
    data[1051] = -'sd43808;
    data[1052] = -'sd26294;
    data[1053] = -'sd16126;
    data[1054] =  'sd42576;
    data[1055] = -'sd20522;
    data[1056] =  'sd39369;
    data[1057] =  'sd21453;
    data[1058] = -'sd3991;
    data[1059] =  'sd12183;
    data[1060] = -'sd28569;
    data[1061] =  'sd61265;
    data[1062] =  'sd34296;
    data[1063] = -'sd7480;
    data[1064] =  'sd43442;
    data[1065] =  'sd12386;
    data[1066] = -'sd20855;
    data[1067] =  'sd26715;
    data[1068] =  'sd32124;
    data[1069] =  'sd73825;
    data[1070] =  'sd20053;
    data[1071] = -'sd57191;
    data[1072] = -'sd43325;
    data[1073] = -'sd7940;
    data[1074] =  'sd25962;
    data[1075] =  'sd3510;
    data[1076] = -'sd30461;
    data[1077] = -'sd10631;
    data[1078] = -'sd76296;
    data[1079] =  'sd49890;
    data[1080] = -'sd70272;
    data[1081] = -'sd48880;
    data[1082] = -'sd55189;
    data[1083] =  'sd32751;
    data[1084] = -'sd66190;
    data[1085] = -'sd57605;
    data[1086] = -'sd59057;
    data[1087] =  'sd49608;
    data[1088] = -'sd80988;
    data[1089] =  'sd35435;
    data[1090] =  'sd35802;
    data[1091] =  'sd49748;
    data[1092] = -'sd75668;
    data[1093] =  'sd73754;
    data[1094] =  'sd17355;
    data[1095] =  'sd4126;
    data[1096] = -'sd7053;
    data[1097] =  'sd59668;
    data[1098] = -'sd26390;
    data[1099] = -'sd19774;
    data[1100] =  'sd67793;
    data[1101] = -'sd45322;
    data[1102] =  'sd80015;
    data[1103] = -'sd72409;
    data[1104] =  'sd33755;
    data[1105] = -'sd28038;
    data[1106] =  'sd81443;
    data[1107] = -'sd18145;
    data[1108] = -'sd34146;
    data[1109] =  'sd13180;
    data[1110] =  'sd9317;
    data[1111] =  'sd26364;
    data[1112] =  'sd18786;
    data[1113] =  'sd58504;
    data[1114] = -'sd70622;
    data[1115] = -'sd62180;
    data[1116] = -'sd69066;
    data[1117] = -'sd3052;
    data[1118] =  'sd47865;
    data[1119] =  'sd16619;
    data[1120] = -'sd23842;
    data[1121] =  'sd77050;
    data[1122] = -'sd21238;
    data[1123] =  'sd12161;
    data[1124] = -'sd29405;
    data[1125] =  'sd29497;
    data[1126] = -'sd26001;
    data[1127] = -'sd4992;
    data[1128] = -'sd25855;
    data[1129] =  'sd556;
    data[1130] =  'sd21128;
    data[1131] = -'sd16341;
    data[1132] =  'sd34406;
    data[1133] = -'sd3300;
    data[1134] =  'sd38441;
    data[1135] = -'sd13811;
    data[1136] = -'sd33295;
    data[1137] =  'sd45518;
    data[1138] = -'sd72567;
    data[1139] =  'sd27751;
    data[1140] =  'sd71492;
    data[1141] = -'sd68601;
    data[1142] =  'sd14618;
    data[1143] =  'sd63961;
    data[1144] = -'sd27097;
    data[1145] = -'sd46640;
    data[1146] =  'sd29931;
    data[1147] = -'sd9509;
    data[1148] = -'sd33660;
    data[1149] =  'sd31648;
    data[1150] =  'sd55737;
    data[1151] = -'sd11927;
    data[1152] =  'sd38297;
    data[1153] = -'sd19283;
    data[1154] = -'sd77390;
    data[1155] =  'sd8318;
    data[1156] = -'sd11598;
    data[1157] =  'sd50799;
    data[1158] = -'sd35730;
    data[1159] = -'sd47012;
    data[1160] =  'sd15795;
    data[1161] = -'sd55154;
    data[1162] =  'sd34081;
    data[1163] = -'sd15650;
    data[1164] =  'sd60664;
    data[1165] =  'sd11458;
    data[1166] = -'sd56119;
    data[1167] = -'sd2589;
    data[1168] =  'sd65459;
    data[1169] =  'sd29827;
    data[1170] = -'sd13461;
    data[1171] = -'sd19995;
    data[1172] =  'sd59395;
    data[1173] = -'sd36764;
    data[1174] =  'sd77537;
    data[1175] = -'sd2732;
    data[1176] =  'sd60025;
    data[1177] = -'sd12824;
    data[1178] =  'sd4211;
    data[1179] = -'sd3823;
    data[1180] =  'sd18567;
    data[1181] =  'sd50182;
    data[1182] = -'sd59176;
    data[1183] =  'sd45086;
    data[1184] =  'sd74858;
    data[1185] =  'sd59307;
    data[1186] = -'sd40108;
    data[1187] = -'sd49535;
    data[1188] = -'sd80079;
    data[1189] =  'sd69977;
    data[1190] =  'sd37670;
    data[1191] = -'sd43109;
    data[1192] =  'sd268;
    data[1193] =  'sd10184;
    data[1194] =  'sd59310;
    data[1195] = -'sd39994;
    data[1196] = -'sd45203;
    data[1197] = -'sd79304;
    data[1198] = -'sd64414;
    data[1199] =  'sd9883;
    data[1200] =  'sd47872;
    data[1201] =  'sd16885;
    data[1202] = -'sd13734;
    data[1203] = -'sd30369;
    data[1204] = -'sd7135;
    data[1205] =  'sd56552;
    data[1206] =  'sd19043;
    data[1207] =  'sd68270;
    data[1208] = -'sd27196;
    data[1209] = -'sd50402;
    data[1210] =  'sd50816;
    data[1211] = -'sd35084;
    data[1212] = -'sd22464;
    data[1213] = -'sd34427;
    data[1214] =  'sd2502;
    data[1215] = -'sd68765;
    data[1216] =  'sd8386;
    data[1217] = -'sd9014;
    data[1218] = -'sd14850;
    data[1219] = -'sd72777;
    data[1220] =  'sd19771;
    data[1221] = -'sd67907;
    data[1222] =  'sd40990;
    data[1223] = -'sd80790;
    data[1224] =  'sd42959;
    data[1225] = -'sd5968;
    data[1226] = -'sd62943;
    data[1227] =  'sd65781;
    data[1228] =  'sd42063;
    data[1229] = -'sd40016;
    data[1230] = -'sd46039;
    data[1231] =  'sd52769;
    data[1232] =  'sd39130;
    data[1233] =  'sd12371;
    data[1234] = -'sd21425;
    data[1235] =  'sd5055;
    data[1236] =  'sd28249;
    data[1237] = -'sd73425;
    data[1238] = -'sd4853;
    data[1239] = -'sd20573;
    data[1240] =  'sd37431;
    data[1241] = -'sd52191;
    data[1242] = -'sd17166;
    data[1243] =  'sd3056;
    data[1244] = -'sd47713;
    data[1245] = -'sd10843;
    data[1246] =  'sd79489;
    data[1247] =  'sd71444;
    data[1248] = -'sd70425;
    data[1249] = -'sd54694;
    data[1250] =  'sd51561;
    data[1251] = -'sd6774;
    data[1252] =  'sd70270;
    data[1253] =  'sd48804;
    data[1254] =  'sd52301;
    data[1255] =  'sd21346;
    data[1256] = -'sd8057;
    data[1257] =  'sd21516;
    data[1258] = -'sd1597;
    data[1259] = -'sd60686;
    data[1260] = -'sd12294;
    data[1261] =  'sd24351;
    data[1262] = -'sd57708;
    data[1263] = -'sd62971;
    data[1264] =  'sd64717;
    data[1265] =  'sd1631;
    data[1266] =  'sd61978;
    data[1267] =  'sd61390;
    data[1268] =  'sd39046;
    data[1269] =  'sd9179;
    data[1270] =  'sd21120;
    data[1271] = -'sd16645;
    data[1272] =  'sd22854;
    data[1273] =  'sd49247;
    data[1274] =  'sd69135;
    data[1275] =  'sd5674;
    data[1276] =  'sd51771;
    data[1277] =  'sd1206;
    data[1278] =  'sd45828;
    data[1279] = -'sd60787;
    data[1280] = -'sd16132;
    data[1281] =  'sd42348;
    data[1282] = -'sd29186;
    data[1283] =  'sd37819;
    data[1284] = -'sd37447;
    data[1285] =  'sd51583;
    data[1286] = -'sd5938;
    data[1287] = -'sd61803;
    data[1288] = -'sd54740;
    data[1289] =  'sd49813;
    data[1290] = -'sd73198;
    data[1291] =  'sd3773;
    data[1292] = -'sd20467;
    data[1293] =  'sd41459;
    data[1294] = -'sd62968;
    data[1295] =  'sd64831;
    data[1296] =  'sd5963;
    data[1297] =  'sd62753;
    data[1298] = -'sd73001;
    data[1299] =  'sd11259;
    data[1300] = -'sd63681;
    data[1301] =  'sd37737;
    data[1302] = -'sd40563;
    data[1303] = -'sd66825;
    data[1304] = -'sd81735;
    data[1305] =  'sd7049;
    data[1306] = -'sd59820;
    data[1307] =  'sd20614;
    data[1308] = -'sd35873;
    data[1309] = -'sd52446;
    data[1310] = -'sd26856;
    data[1311] = -'sd37482;
    data[1312] =  'sd50253;
    data[1313] = -'sd56478;
    data[1314] = -'sd16231;
    data[1315] =  'sd38586;
    data[1316] = -'sd8301;
    data[1317] =  'sd12244;
    data[1318] = -'sd26251;
    data[1319] = -'sd14492;
    data[1320] = -'sd59173;
    data[1321] =  'sd45200;
    data[1322] =  'sd79190;
    data[1323] =  'sd60082;
    data[1324] = -'sd10658;
    data[1325] = -'sd77322;
    data[1326] =  'sd10902;
    data[1327] = -'sd77247;
    data[1328] =  'sd13752;
    data[1329] =  'sd31053;
    data[1330] =  'sd33127;
    data[1331] = -'sd51902;
    data[1332] = -'sd6184;
    data[1333] = -'sd71151;
    data[1334] =  'sd81559;
    data[1335] = -'sd13737;
    data[1336] = -'sd30483;
    data[1337] = -'sd11467;
    data[1338] =  'sd55777;
    data[1339] = -'sd10407;
    data[1340] = -'sd67784;
    data[1341] =  'sd45664;
    data[1342] = -'sd67019;
    data[1343] =  'sd74734;
    data[1344] =  'sd54595;
    data[1345] = -'sd55323;
    data[1346] =  'sd27659;
    data[1347] =  'sd67996;
    data[1348] = -'sd37608;
    data[1349] =  'sd45465;
    data[1350] = -'sd74581;
    data[1351] = -'sd48781;
    data[1352] = -'sd51427;
    data[1353] =  'sd11866;
    data[1354] = -'sd40615;
    data[1355] = -'sd68801;
    data[1356] =  'sd7018;
    data[1357] = -'sd60998;
    data[1358] = -'sd24150;
    data[1359] =  'sd65346;
    data[1360] =  'sd25533;
    data[1361] = -'sd12792;
    data[1362] =  'sd5427;
    data[1363] =  'sd42385;
    data[1364] = -'sd27780;
    data[1365] = -'sd72594;
    data[1366] =  'sd26725;
    data[1367] =  'sd32504;
    data[1368] = -'sd75576;
    data[1369] =  'sd77250;
    data[1370] = -'sd13638;
    data[1371] = -'sd26721;
    data[1372] = -'sd32352;
    data[1373] =  'sd81352;
    data[1374] = -'sd21603;
    data[1375] = -'sd1709;
    data[1376] = -'sd64942;
    data[1377] = -'sd10181;
    data[1378] = -'sd59196;
    data[1379] =  'sd44326;
    data[1380] =  'sd45978;
    data[1381] = -'sd55087;
    data[1382] =  'sd36627;
    data[1383] =  'sd81098;
    data[1384] = -'sd31255;
    data[1385] = -'sd40803;
    data[1386] = -'sd75945;
    data[1387] =  'sd63228;
    data[1388] = -'sd54951;
    data[1389] =  'sd41795;
    data[1390] = -'sd50200;
    data[1391] =  'sd58492;
    data[1392] = -'sd71078;
    data[1393] = -'sd79508;
    data[1394] = -'sd72166;
    data[1395] =  'sd42989;
    data[1396] = -'sd4828;
    data[1397] = -'sd19623;
    data[1398] =  'sd73531;
    data[1399] =  'sd8881;
    data[1400] =  'sd9796;
    data[1401] =  'sd44566;
    data[1402] =  'sd55098;
    data[1403] = -'sd36209;
    data[1404] = -'sd65214;
    data[1405] = -'sd20517;
    data[1406] =  'sd39559;
    data[1407] =  'sd28673;
    data[1408] = -'sd57313;
    data[1409] = -'sd47961;
    data[1410] = -'sd20267;
    data[1411] =  'sd49059;
    data[1412] =  'sd61991;
    data[1413] =  'sd61884;
    data[1414] =  'sd57818;
    data[1415] =  'sd67151;
    data[1416] = -'sd69718;
    data[1417] = -'sd27828;
    data[1418] = -'sd74418;
    data[1419] = -'sd42587;
    data[1420] =  'sd20104;
    data[1421] = -'sd55253;
    data[1422] =  'sd30319;
    data[1423] =  'sd5235;
    data[1424] =  'sd35089;
    data[1425] =  'sd22654;
    data[1426] =  'sd41647;
    data[1427] = -'sd55824;
    data[1428] =  'sd8621;
    data[1429] = -'sd84;
    data[1430] = -'sd3192;
    data[1431] =  'sd42545;
    data[1432] = -'sd21700;
    data[1433] = -'sd5395;
    data[1434] = -'sd41169;
    data[1435] =  'sd73988;
    data[1436] =  'sd26247;
    data[1437] =  'sd14340;
    data[1438] =  'sd53397;
    data[1439] =  'sd62994;
    data[1440] = -'sd63843;
    data[1441] =  'sd31581;
    data[1442] =  'sd53191;
    data[1443] =  'sd55166;
    data[1444] = -'sd33625;
    data[1445] =  'sd32978;
    data[1446] = -'sd57564;
    data[1447] = -'sd57499;
    data[1448] = -'sd55029;
    data[1449] =  'sd38831;
    data[1450] =  'sd1009;
    data[1451] =  'sd38342;
    data[1452] = -'sd17573;
    data[1453] = -'sd12410;
    data[1454] =  'sd19943;
    data[1455] = -'sd61371;
    data[1456] = -'sd38324;
    data[1457] =  'sd18257;
    data[1458] =  'sd38402;
    data[1459] = -'sd15293;
    data[1460] =  'sd74230;
    data[1461] =  'sd35443;
    data[1462] =  'sd36106;
    data[1463] =  'sd61300;
    data[1464] =  'sd35626;
    data[1465] =  'sd43060;
    data[1466] = -'sd2130;
    data[1467] = -'sd80940;
    data[1468] =  'sd37259;
    data[1469] = -'sd58727;
    data[1470] =  'sd62148;
    data[1471] =  'sd67850;
    data[1472] = -'sd43156;
    data[1473] = -'sd1518;
    data[1474] = -'sd57684;
    data[1475] = -'sd62059;
    data[1476] = -'sd64468;
    data[1477] =  'sd7831;
    data[1478] = -'sd30104;
    data[1479] =  'sd2935;
    data[1480] = -'sd52311;
    data[1481] = -'sd21726;
    data[1482] = -'sd6383;
    data[1483] = -'sd78713;
    data[1484] = -'sd41956;
    data[1485] =  'sd44082;
    data[1486] =  'sd36706;
    data[1487] = -'sd79741;
    data[1488] = -'sd81020;
    data[1489] =  'sd34219;
    data[1490] = -'sd10406;
    data[1491] = -'sd67746;
    data[1492] =  'sd47108;
    data[1493] = -'sd12147;
    data[1494] =  'sd29937;
    data[1495] = -'sd9281;
    data[1496] = -'sd24996;
    data[1497] =  'sd33198;
    data[1498] = -'sd49204;
    data[1499] = -'sd67501;
    data[1500] =  'sd56418;
    data[1501] =  'sd13951;
    data[1502] =  'sd38615;
    data[1503] = -'sd7199;
    data[1504] =  'sd54120;
    data[1505] = -'sd73373;
    data[1506] = -'sd2877;
    data[1507] =  'sd54515;
    data[1508] = -'sd58363;
    data[1509] =  'sd75980;
    data[1510] = -'sd61898;
    data[1511] = -'sd58350;
    data[1512] =  'sd76474;
    data[1513] = -'sd43126;
    data[1514] = -'sd378;
    data[1515] = -'sd14364;
    data[1516] = -'sd54309;
    data[1517] =  'sd66191;
    data[1518] =  'sd57643;
    data[1519] =  'sd60501;
    data[1520] =  'sd5264;
    data[1521] =  'sd36191;
    data[1522] =  'sd64530;
    data[1523] = -'sd5475;
    data[1524] = -'sd44209;
    data[1525] = -'sd41532;
    data[1526] =  'sd60194;
    data[1527] = -'sd6402;
    data[1528] = -'sd79435;
    data[1529] = -'sd69392;
    data[1530] = -'sd15440;
    data[1531] =  'sd68644;
    data[1532] = -'sd12984;
    data[1533] = -'sd1869;
    data[1534] = -'sd71022;
    data[1535] = -'sd77380;
    data[1536] =  'sd8698;
    data[1537] =  'sd2842;
    data[1538] = -'sd55845;
    data[1539] =  'sd7823;
    data[1540] = -'sd30408;
    data[1541] = -'sd8617;
    data[1542] =  'sd236;
    data[1543] =  'sd8968;
    data[1544] =  'sd13102;
    data[1545] =  'sd6353;
    data[1546] =  'sd77573;
    data[1547] = -'sd1364;
    data[1548] = -'sd51832;
    data[1549] = -'sd3524;
    data[1550] =  'sd29929;
    data[1551] = -'sd9585;
    data[1552] = -'sd36548;
    data[1553] = -'sd78096;
    data[1554] = -'sd18510;
    data[1555] = -'sd48016;
    data[1556] = -'sd22357;
    data[1557] = -'sd30361;
    data[1558] = -'sd6831;
    data[1559] =  'sd68104;
    data[1560] = -'sd33504;
    data[1561] =  'sd37576;
    data[1562] = -'sd46681;
    data[1563] =  'sd28373;
    data[1564] = -'sd68713;
    data[1565] =  'sd10362;
    data[1566] =  'sd66074;
    data[1567] =  'sd53197;
    data[1568] =  'sd55394;
    data[1569] = -'sd24961;
    data[1570] =  'sd34528;
    data[1571] =  'sd1336;
    data[1572] =  'sd50768;
    data[1573] = -'sd36908;
    data[1574] =  'sd72065;
    data[1575] = -'sd46827;
    data[1576] =  'sd22825;
    data[1577] =  'sd48145;
    data[1578] =  'sd27259;
    data[1579] =  'sd52796;
    data[1580] =  'sd40156;
    data[1581] =  'sd51359;
    data[1582] = -'sd14450;
    data[1583] = -'sd57577;
    data[1584] = -'sd57993;
    data[1585] = -'sd73801;
    data[1586] = -'sd19141;
    data[1587] = -'sd71994;
    data[1588] =  'sd49525;
    data[1589] =  'sd79699;
    data[1590] =  'sd79424;
    data[1591] =  'sd68974;
    data[1592] = -'sd444;
    data[1593] = -'sd16872;
    data[1594] =  'sd14228;
    data[1595] =  'sd49141;
    data[1596] =  'sd65107;
    data[1597] =  'sd16451;
    data[1598] = -'sd30226;
    data[1599] = -'sd1701;
    data[1600] = -'sd64638;
    data[1601] =  'sd1371;
    data[1602] =  'sd52098;
    data[1603] =  'sd13632;
    data[1604] =  'sd26493;
    data[1605] =  'sd23688;
    data[1606] =  'sd80939;
    data[1607] = -'sd37297;
    data[1608] =  'sd57283;
    data[1609] =  'sd46821;
    data[1610] = -'sd23053;
    data[1611] = -'sd56809;
    data[1612] = -'sd28809;
    data[1613] =  'sd52145;
    data[1614] =  'sd15418;
    data[1615] = -'sd69480;
    data[1616] = -'sd18784;
    data[1617] = -'sd58428;
    data[1618] =  'sd73510;
    data[1619] =  'sd8083;
    data[1620] = -'sd20528;
    data[1621] =  'sd39141;
    data[1622] =  'sd12789;
    data[1623] = -'sd5541;
    data[1624] = -'sd46717;
    data[1625] =  'sd27005;
    data[1626] =  'sd43144;
    data[1627] =  'sd1062;
    data[1628] =  'sd40356;
    data[1629] =  'sd58959;
    data[1630] = -'sd53332;
    data[1631] = -'sd60524;
    data[1632] = -'sd6138;
    data[1633] = -'sd69403;
    data[1634] = -'sd15858;
    data[1635] =  'sd52760;
    data[1636] =  'sd38788;
    data[1637] = -'sd625;
    data[1638] = -'sd23750;
    data[1639] =  'sd80546;
    data[1640] = -'sd52231;
    data[1641] = -'sd18686;
    data[1642] = -'sd54704;
    data[1643] =  'sd51181;
    data[1644] = -'sd21214;
    data[1645] =  'sd13073;
    data[1646] =  'sd5251;
    data[1647] =  'sd35697;
    data[1648] =  'sd45758;
    data[1649] = -'sd63447;
    data[1650] =  'sd46629;
    data[1651] = -'sd30349;
    data[1652] = -'sd6375;
    data[1653] = -'sd78409;
    data[1654] = -'sd30404;
    data[1655] = -'sd8465;
    data[1656] =  'sd6012;
    data[1657] =  'sd64615;
    data[1658] = -'sd2245;
    data[1659] =  'sd78531;
    data[1660] =  'sd35040;
    data[1661] =  'sd20792;
    data[1662] = -'sd29109;
    data[1663] =  'sd40745;
    data[1664] =  'sd73741;
    data[1665] =  'sd16861;
    data[1666] = -'sd14646;
    data[1667] = -'sd65025;
    data[1668] = -'sd13335;
    data[1669] = -'sd15207;
    data[1670] =  'sd77498;
    data[1671] = -'sd4214;
    data[1672] =  'sd3709;
    data[1673] = -'sd22899;
    data[1674] = -'sd50957;
    data[1675] =  'sd29726;
    data[1676] = -'sd17299;
    data[1677] = -'sd1998;
    data[1678] = -'sd75924;
    data[1679] =  'sd64026;
    data[1680] = -'sd24627;
    data[1681] =  'sd47220;
    data[1682] = -'sd7891;
    data[1683] =  'sd27824;
    data[1684] =  'sd74266;
    data[1685] =  'sd36811;
    data[1686] = -'sd75751;
    data[1687] =  'sd70600;
    data[1688] =  'sd61344;
    data[1689] =  'sd37298;
    data[1690] = -'sd57245;
    data[1691] = -'sd45377;
    data[1692] =  'sd77925;
    data[1693] =  'sd12012;
    data[1694] = -'sd35067;
    data[1695] = -'sd21818;
    data[1696] = -'sd9879;
    data[1697] = -'sd47720;
    data[1698] = -'sd11109;
    data[1699] =  'sd69381;
    data[1700] =  'sd15022;
    data[1701] =  'sd79313;
    data[1702] =  'sd64756;
    data[1703] =  'sd3113;
    data[1704] = -'sd45547;
    data[1705] =  'sd71465;
    data[1706] = -'sd69627;
    data[1707] = -'sd24370;
    data[1708] =  'sd56986;
    data[1709] =  'sd35535;
    data[1710] =  'sd39602;
    data[1711] =  'sd30307;
    data[1712] =  'sd4779;
    data[1713] =  'sd17761;
    data[1714] =  'sd19554;
    data[1715] = -'sd76153;
    data[1716] =  'sd55324;
    data[1717] = -'sd27621;
    data[1718] = -'sd66552;
    data[1719] = -'sd71361;
    data[1720] =  'sd73579;
    data[1721] =  'sd10705;
    data[1722] =  'sd79108;
    data[1723] =  'sd56966;
    data[1724] =  'sd34775;
    data[1725] =  'sd10722;
    data[1726] =  'sd79754;
    data[1727] =  'sd81514;
    data[1728] = -'sd15447;
    data[1729] =  'sd68378;
    data[1730] = -'sd23092;
    data[1731] = -'sd58291;
    data[1732] =  'sd78716;
    data[1733] =  'sd42070;
    data[1734] = -'sd39750;
    data[1735] = -'sd35931;
    data[1736] = -'sd54650;
    data[1737] =  'sd53233;
    data[1738] =  'sd56762;
    data[1739] =  'sd27023;
    data[1740] =  'sd43828;
    data[1741] =  'sd27054;
    data[1742] =  'sd45006;
    data[1743] =  'sd71818;
    data[1744] = -'sd56213;
    data[1745] = -'sd6161;
    data[1746] = -'sd70277;
    data[1747] = -'sd49070;
    data[1748] = -'sd62409;
    data[1749] = -'sd77768;
    data[1750] = -'sd6046;
    data[1751] = -'sd65907;
    data[1752] = -'sd46851;
    data[1753] =  'sd21913;
    data[1754] =  'sd13489;
    data[1755] =  'sd21059;
    data[1756] = -'sd18963;
    data[1757] = -'sd65230;
    data[1758] = -'sd21125;
    data[1759] =  'sd16455;
    data[1760] = -'sd30074;
    data[1761] =  'sd4075;
    data[1762] = -'sd8991;
    data[1763] = -'sd13976;
    data[1764] = -'sd39565;
    data[1765] = -'sd28901;
    data[1766] =  'sd48649;
    data[1767] =  'sd46411;
    data[1768] = -'sd38633;
    data[1769] =  'sd6515;
    data[1770] = -'sd80112;
    data[1771] =  'sd68723;
    data[1772] = -'sd9982;
    data[1773] = -'sd51634;
    data[1774] =  'sd4000;
    data[1775] = -'sd11841;
    data[1776] =  'sd41565;
    data[1777] = -'sd58940;
    data[1778] =  'sd54054;
    data[1779] = -'sd75881;
    data[1780] =  'sd65660;
    data[1781] =  'sd37465;
    data[1782] = -'sd50899;
    data[1783] =  'sd31930;
    data[1784] =  'sd66453;
    data[1785] =  'sd67599;
    data[1786] = -'sd52694;
    data[1787] = -'sd36280;
    data[1788] = -'sd67912;
    data[1789] =  'sd40800;
    data[1790] =  'sd75831;
    data[1791] = -'sd67560;
    data[1792] =  'sd54176;
    data[1793] = -'sd71245;
    data[1794] =  'sd77987;
    data[1795] =  'sd14368;
    data[1796] =  'sd54461;
    data[1797] = -'sd60415;
    data[1798] = -'sd1996;
    data[1799] = -'sd75848;
    data[1800] =  'sd66914;
    data[1801] = -'sd78724;
    data[1802] = -'sd42374;
    data[1803] =  'sd28198;
    data[1804] = -'sd75363;
    data[1805] = -'sd78497;
    data[1806] = -'sd33748;
    data[1807] =  'sd28304;
    data[1808] = -'sd71335;
    data[1809] =  'sd74567;
    data[1810] =  'sd48249;
    data[1811] =  'sd31211;
    data[1812] =  'sd39131;
    data[1813] =  'sd12409;
    data[1814] = -'sd19981;
    data[1815] =  'sd59927;
    data[1816] = -'sd16548;
    data[1817] =  'sd26540;
    data[1818] =  'sd25474;
    data[1819] = -'sd15034;
    data[1820] = -'sd79769;
    data[1821] =  'sd81757;
    data[1822] = -'sd6213;
    data[1823] = -'sd72253;
    data[1824] =  'sd39683;
    data[1825] =  'sd33385;
    data[1826] = -'sd42098;
    data[1827] =  'sd38686;
    data[1828] = -'sd4501;
    data[1829] = -'sd7197;
    data[1830] =  'sd54196;
    data[1831] = -'sd70485;
    data[1832] = -'sd56974;
    data[1833] = -'sd35079;
    data[1834] = -'sd22274;
    data[1835] = -'sd27207;
    data[1836] = -'sd50820;
    data[1837] =  'sd34932;
    data[1838] =  'sd16688;
    data[1839] = -'sd21220;
    data[1840] =  'sd12845;
    data[1841] = -'sd3413;
    data[1842] =  'sd34147;
    data[1843] = -'sd13142;
    data[1844] = -'sd7873;
    data[1845] =  'sd28508;
    data[1846] = -'sd63583;
    data[1847] =  'sd41461;
    data[1848] = -'sd62892;
    data[1849] =  'sd67719;
    data[1850] = -'sd48134;
    data[1851] = -'sd26841;
    data[1852] = -'sd36912;
    data[1853] =  'sd71913;
    data[1854] = -'sd52603;
    data[1855] = -'sd32822;
    data[1856] =  'sd63492;
    data[1857] = -'sd44919;
    data[1858] = -'sd68512;
    data[1859] =  'sd18000;
    data[1860] =  'sd28636;
    data[1861] = -'sd58719;
    data[1862] =  'sd62452;
    data[1863] =  'sd79402;
    data[1864] =  'sd68138;
    data[1865] = -'sd32212;
    data[1866] = -'sd77169;
    data[1867] =  'sd16716;
    data[1868] = -'sd20156;
    data[1869] =  'sd53277;
    data[1870] =  'sd58434;
    data[1871] = -'sd73282;
    data[1872] =  'sd581;
    data[1873] =  'sd22078;
    data[1874] =  'sd19759;
    data[1875] = -'sd68363;
    data[1876] =  'sd23662;
    data[1877] =  'sd79951;
    data[1878] = -'sd74841;
    data[1879] = -'sd58661;
    data[1880] =  'sd64656;
    data[1881] = -'sd687;
    data[1882] = -'sd26106;
    data[1883] = -'sd8982;
    data[1884] = -'sd13634;
    data[1885] = -'sd26569;
    data[1886] = -'sd26576;
    data[1887] = -'sd26842;
    data[1888] = -'sd36950;
    data[1889] =  'sd70469;
    data[1890] =  'sd56366;
    data[1891] =  'sd11975;
    data[1892] = -'sd36473;
    data[1893] = -'sd75246;
    data[1894] = -'sd74051;
    data[1895] = -'sd28641;
    data[1896] =  'sd58529;
    data[1897] = -'sd69672;
    data[1898] = -'sd26080;
    data[1899] = -'sd7994;
    data[1900] =  'sd23910;
    data[1901] = -'sd74466;
    data[1902] = -'sd44411;
    data[1903] = -'sd49208;
    data[1904] = -'sd67653;
    data[1905] =  'sd50642;
    data[1906] = -'sd41696;
    data[1907] =  'sd53962;
    data[1908] = -'sd79377;
    data[1909] = -'sd67188;
    data[1910] =  'sd68312;
    data[1911] = -'sd25600;
    data[1912] =  'sd10246;
    data[1913] =  'sd61666;
    data[1914] =  'sd49534;
    data[1915] =  'sd80041;
    data[1916] = -'sd71421;
    data[1917] =  'sd71299;
    data[1918] = -'sd75935;
    data[1919] =  'sd63608;
    data[1920] = -'sd40511;
    data[1921] = -'sd64849;
    data[1922] = -'sd6647;
    data[1923] =  'sd75096;
    data[1924] =  'sd68351;
    data[1925] = -'sd24118;
    data[1926] =  'sd66562;
    data[1927] =  'sd71741;
    data[1928] = -'sd59139;
    data[1929] =  'sd46492;
    data[1930] = -'sd35555;
    data[1931] = -'sd40362;
    data[1932] = -'sd59187;
    data[1933] =  'sd44668;
    data[1934] =  'sd58974;
    data[1935] = -'sd52762;
    data[1936] = -'sd38864;
    data[1937] = -'sd2263;
    data[1938] =  'sd77847;
    data[1939] =  'sd9048;
    data[1940] =  'sd16142;
    data[1941] = -'sd41968;
    data[1942] =  'sd43626;
    data[1943] =  'sd19378;
    data[1944] =  'sd81000;
    data[1945] = -'sd34979;
    data[1946] = -'sd18474;
    data[1947] = -'sd46648;
    data[1948] =  'sd29627;
    data[1949] = -'sd21061;
    data[1950] =  'sd18887;
    data[1951] =  'sd62342;
    data[1952] =  'sd75222;
    data[1953] =  'sd73139;
    data[1954] = -'sd6015;
    data[1955] = -'sd64729;
    data[1956] = -'sd2087;
    data[1957] = -'sd79306;
    data[1958] = -'sd64490;
    data[1959] =  'sd6995;
    data[1960] = -'sd61872;
    data[1961] = -'sd57362;
    data[1962] = -'sd49823;
    data[1963] =  'sd72818;
    data[1964] = -'sd18213;
    data[1965] = -'sd36730;
    data[1966] =  'sd78829;
    data[1967] =  'sd46364;
    data[1968] = -'sd40419;
    data[1969] = -'sd61353;
    data[1970] = -'sd37640;
    data[1971] =  'sd44249;
    data[1972] =  'sd43052;
    data[1973] = -'sd2434;
    data[1974] =  'sd71349;
    data[1975] = -'sd74035;
    data[1976] = -'sd28033;
    data[1977] =  'sd81633;
    data[1978] = -'sd10925;
    data[1979] =  'sd76373;
    data[1980] = -'sd46964;
    data[1981] =  'sd17619;
    data[1982] =  'sd14158;
    data[1983] =  'sd46481;
    data[1984] = -'sd35973;
    data[1985] = -'sd56246;
    data[1986] = -'sd7415;
    data[1987] =  'sd45912;
    data[1988] = -'sd57595;
    data[1989] = -'sd58677;
    data[1990] =  'sd64048;
    data[1991] = -'sd23791;
    data[1992] =  'sd78988;
    data[1993] =  'sd52406;
    data[1994] =  'sd25336;
    data[1995] = -'sd20278;
    data[1996] =  'sd48641;
    data[1997] =  'sd46107;
    data[1998] = -'sd50185;
    data[1999] =  'sd59062;
    data[2000] = -'sd49418;
    data[2001] = -'sd75633;
    data[2002] =  'sd75084;
    data[2003] =  'sd67895;
    data[2004] = -'sd41446;
    data[2005] =  'sd63462;
    data[2006] = -'sd46059;
    data[2007] =  'sd52009;
    data[2008] =  'sd10250;
    data[2009] =  'sd61818;
    data[2010] =  'sd55310;
    data[2011] = -'sd28153;
    data[2012] =  'sd77073;
    data[2013] = -'sd20364;
    data[2014] =  'sd45373;
    data[2015] = -'sd78077;
    data[2016] = -'sd17788;
    data[2017] = -'sd20580;
    data[2018] =  'sd37165;
    data[2019] = -'sd62299;
    data[2020] = -'sd73588;
    data[2021] = -'sd11047;
    data[2022] =  'sd71737;
    data[2023] = -'sd59291;
    data[2024] =  'sd40716;
    data[2025] =  'sd72639;
    data[2026] = -'sd25015;
    data[2027] =  'sd32476;
    data[2028] = -'sd76640;
    data[2029] =  'sd36818;
    data[2030] = -'sd75485;
    data[2031] =  'sd80708;
    data[2032] = -'sd46075;
    data[2033] =  'sd51401;
    data[2034] = -'sd12854;
    data[2035] =  'sd3071;
    data[2036] = -'sd47143;
    data[2037] =  'sd10817;
    data[2038] = -'sd80477;
    data[2039] =  'sd54853;
    data[2040] = -'sd45519;
    data[2041] =  'sd72529;
    data[2042] = -'sd29195;
    data[2043] =  'sd37477;
    data[2044] = -'sd50443;
    data[2045] =  'sd49258;
    data[2046] =  'sd69553;
    data[2047] =  'sd21558;
  end

endmodule

module bfu_249857 ( clk, state, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input      signed [17 : 0] in_a;
  input      signed [17 : 0] in_b;
  input      signed [17 : 0] w;
  output reg signed [34 : 0] bw;
  output reg signed [17 : 0] out_a;
  output reg signed [17 : 0] out_b;

  wire signed       [17 : 0] mod_bw;
  reg signed        [18 : 0] a, b;
  reg signed        [17 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  reg signed        [34 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [18 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul249857s mod249857s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd249857;
  assign a_sub_q = a - 'sd249857;
  assign b_add_q = b + 'sd249857;
  assign b_sub_q = b - 'sd249857;

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
    a <= in_a_s4 + mod_bw;
    b <= in_a_s4 - mod_bw;

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
  input             [11 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [11 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [17:0] data [0:2047];

  assign dout_p = data[addr_reg[10:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[11] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[   0] =  'sd1;
    data[   1] =  'sd185;
    data[   2] =  'sd34225;
    data[   3] =  'sd85200;
    data[   4] =  'sd21009;
    data[   5] = -'sd111047;
    data[   6] = -'sd55421;
    data[   7] = -'sd8748;
    data[   8] = -'sd119238;
    data[   9] = -'sd71614;
    data[  10] = -'sd6169;
    data[  11] =  'sd108020;
    data[  12] = -'sd4860;
    data[  13] =  'sd100328;
    data[  14] =  'sd71262;
    data[  15] = -'sd58951;
    data[  16] =  'sd87773;
    data[  17] = -'sd2700;
    data[  18] =  'sd214;
    data[  19] =  'sd39590;
    data[  20] =  'sd78297;
    data[  21] = -'sd6761;
    data[  22] = -'sd1500;
    data[  23] = -'sd27643;
    data[  24] = -'sd116815;
    data[  25] = -'sd123073;
    data[  26] = -'sd31518;
    data[  27] = -'sd84119;
    data[  28] = -'sd70881;
    data[  29] = -'sd120421;
    data[  30] = -'sd40612;
    data[  31] = -'sd17510;
    data[  32] =  'sd8791;
    data[  33] = -'sd122664;
    data[  34] =  'sd44147;
    data[  35] = -'sd78086;
    data[  36] =  'sd45796;
    data[  37] = -'sd22878;
    data[  38] =  'sd15139;
    data[  39] =  'sd52288;
    data[  40] = -'sd71143;
    data[  41] =  'sd80966;
    data[  42] = -'sd12710;
    data[  43] = -'sd102637;
    data[  44] =  'sd1287;
    data[  45] = -'sd11762;
    data[  46] =  'sd72743;
    data[  47] = -'sd34823;
    data[  48] =  'sd54027;
    data[  49] =  'sd715;
    data[  50] = -'sd117582;
    data[  51] = -'sd15111;
    data[  52] = -'sd47108;
    data[  53] =  'sd30015;
    data[  54] =  'sd55921;
    data[  55] =  'sd101248;
    data[  56] = -'sd8395;
    data[  57] = -'sd53933;
    data[  58] =  'sd16675;
    data[  59] =  'sd86591;
    data[  60] =  'sd28487;
    data[  61] =  'sd23098;
    data[  62] =  'sd25561;
    data[  63] = -'sd18498;
    data[  64] =  'sd75868;
    data[  65] =  'sd43588;
    data[  66] =  'sd68356;
    data[  67] = -'sd96847;
    data[  68] =  'sd73009;
    data[  69] =  'sd14387;
    data[  70] = -'sd86832;
    data[  71] = -'sd73072;
    data[  72] = -'sd26042;
    data[  73] = -'sd70487;
    data[  74] = -'sd47531;
    data[  75] = -'sd48240;
    data[  76] =  'sd70452;
    data[  77] =  'sd41056;
    data[  78] =  'sd99650;
    data[  79] = -'sd54168;
    data[  80] = -'sd26800;
    data[  81] =  'sd39140;
    data[  82] = -'sd4953;
    data[  83] =  'sd83123;
    data[  84] = -'sd113379;
    data[  85] =  'sd12873;
    data[  86] = -'sd117065;
    data[  87] =  'sd80534;
    data[  88] = -'sd92630;
    data[  89] =  'sd103583;
    data[  90] = -'sd76134;
    data[  91] = -'sd92798;
    data[  92] =  'sd72503;
    data[  93] = -'sd79223;
    data[  94] =  'sd85308;
    data[  95] =  'sd40989;
    data[  96] =  'sd87255;
    data[  97] = -'sd98530;
    data[  98] =  'sd11511;
    data[  99] = -'sd119178;
    data[ 100] = -'sd60514;
    data[ 101] =  'sd48475;
    data[ 102] = -'sd26977;
    data[ 103] =  'sd6395;
    data[ 104] = -'sd66210;
    data[ 105] = -'sd5857;
    data[ 106] = -'sd84117;
    data[ 107] = -'sd70511;
    data[ 108] = -'sd51971;
    data[ 109] = -'sd120069;
    data[ 110] =  'sd24508;
    data[ 111] =  'sd36554;
    data[ 112] =  'sd16351;
    data[ 113] =  'sd26651;
    data[ 114] = -'sd66705;
    data[ 115] = -'sd97432;
    data[ 116] = -'sd35216;
    data[ 117] = -'sd18678;
    data[ 118] =  'sd42568;
    data[ 119] = -'sd120344;
    data[ 120] = -'sd26367;
    data[ 121] =  'sd119245;
    data[ 122] =  'sd72909;
    data[ 123] = -'sd4113;
    data[ 124] = -'sd11334;
    data[ 125] = -'sd97934;
    data[ 126] =  'sd121771;
    data[ 127] =  'sd40505;
    data[ 128] = -'sd2285;
    data[ 129] =  'sd76989;
    data[ 130] =  'sd1116;
    data[ 131] = -'sd43397;
    data[ 132] = -'sd33021;
    data[ 133] = -'sd112317;
    data[ 134] = -'sd40514;
    data[ 135] =  'sd620;
    data[ 136] =  'sd114700;
    data[ 137] = -'sd18345;
    data[ 138] =  'sd104173;
    data[ 139] =  'sd33016;
    data[ 140] =  'sd111392;
    data[ 141] =  'sd119246;
    data[ 142] =  'sd73094;
    data[ 143] =  'sd30112;
    data[ 144] =  'sd73866;
    data[ 145] = -'sd76925;
    data[ 146] =  'sd10724;
    data[ 147] = -'sd14916;
    data[ 148] = -'sd11033;
    data[ 149] = -'sd42249;
    data[ 150] = -'sd70498;
    data[ 151] = -'sd49566;
    data[ 152] =  'sd74999;
    data[ 153] = -'sd117177;
    data[ 154] =  'sd59814;
    data[ 155] =  'sd71882;
    data[ 156] =  'sd55749;
    data[ 157] =  'sd69428;
    data[ 158] =  'sd101473;
    data[ 159] =  'sd33230;
    data[ 160] = -'sd98875;
    data[ 161] = -'sd52314;
    data[ 162] =  'sd66333;
    data[ 163] =  'sd28612;
    data[ 164] =  'sd46223;
    data[ 165] =  'sd56117;
    data[ 166] = -'sd112349;
    data[ 167] = -'sd46434;
    data[ 168] = -'sd95152;
    data[ 169] = -'sd113130;
    data[ 170] =  'sd58938;
    data[ 171] = -'sd90178;
    data[ 172] =  'sd57489;
    data[ 173] = -'sd108386;
    data[ 174] = -'sd62850;
    data[ 175] =  'sd116029;
    data[ 176] = -'sd22337;
    data[ 177] =  'sd115224;
    data[ 178] =  'sd78595;
    data[ 179] =  'sd48369;
    data[ 180] = -'sd46587;
    data[ 181] = -'sd123457;
    data[ 182] = -'sd102558;
    data[ 183] =  'sd15902;
    data[ 184] = -'sd56414;
    data[ 185] =  'sd57404;
    data[ 186] = -'sd124111;
    data[ 187] =  'sd26309;
    data[ 188] =  'sd119882;
    data[ 189] = -'sd59103;
    data[ 190] =  'sd59653;
    data[ 191] =  'sd42097;
    data[ 192] =  'sd42378;
    data[ 193] =  'sd94363;
    data[ 194] = -'sd32835;
    data[ 195] = -'sd77907;
    data[ 196] =  'sd78911;
    data[ 197] =  'sd106829;
    data[ 198] =  'sd24662;
    data[ 199] =  'sd65044;
    data[ 200] =  'sd40004;
    data[ 201] = -'sd94970;
    data[ 202] = -'sd79460;
    data[ 203] =  'sd41463;
    data[ 204] = -'sd74912;
    data[ 205] = -'sd116585;
    data[ 206] = -'sd80523;
    data[ 207] =  'sd94665;
    data[ 208] =  'sd23035;
    data[ 209] =  'sd13906;
    data[ 210] =  'sd74040;
    data[ 211] = -'sd44735;
    data[ 212] = -'sd30694;
    data[ 213] =  'sd68321;
    data[ 214] = -'sd103322;
    data[ 215] =  'sd124419;
    data[ 216] =  'sd30671;
    data[ 217] = -'sd72576;
    data[ 218] =  'sd65718;
    data[ 219] = -'sd85163;
    data[ 220] = -'sd14164;
    data[ 221] = -'sd121770;
    data[ 222] = -'sd40320;
    data[ 223] =  'sd36510;
    data[ 224] =  'sd8211;
    data[ 225] =  'sd19893;
    data[ 226] = -'sd67650;
    data[ 227] = -'sd22400;
    data[ 228] =  'sd103569;
    data[ 229] = -'sd78724;
    data[ 230] = -'sd72234;
    data[ 231] = -'sd120869;
    data[ 232] = -'sd123492;
    data[ 233] = -'sd109033;
    data[ 234] =  'sd67312;
    data[ 235] = -'sd40130;
    data[ 236] =  'sd71660;
    data[ 237] =  'sd14679;
    data[ 238] = -'sd32812;
    data[ 239] = -'sd73652;
    data[ 240] =  'sd116515;
    data[ 241] =  'sd67573;
    data[ 242] =  'sd8155;
    data[ 243] =  'sd9533;
    data[ 244] =  'sd14606;
    data[ 245] = -'sd46317;
    data[ 246] = -'sd73507;
    data[ 247] = -'sd106517;
    data[ 248] =  'sd33058;
    data[ 249] =  'sd119162;
    data[ 250] =  'sd57554;
    data[ 251] = -'sd96361;
    data[ 252] = -'sd86938;
    data[ 253] = -'sd92682;
    data[ 254] =  'sd93963;
    data[ 255] = -'sd106835;
    data[ 256] = -'sd25772;
    data[ 257] = -'sd20537;
    data[ 258] = -'sd51490;
    data[ 259] = -'sd31084;
    data[ 260] = -'sd3829;
    data[ 261] =  'sd41206;
    data[ 262] = -'sd122457;
    data[ 263] =  'sd82442;
    data[ 264] =  'sd10493;
    data[ 265] = -'sd57651;
    data[ 266] =  'sd78416;
    data[ 267] =  'sd15254;
    data[ 268] =  'sd73563;
    data[ 269] =  'sd116877;
    data[ 270] = -'sd115314;
    data[ 271] = -'sd95245;
    data[ 272] =  'sd119522;
    data[ 273] =  'sd124154;
    data[ 274] = -'sd18354;
    data[ 275] =  'sd102508;
    data[ 276] = -'sd25152;
    data[ 277] =  'sd94163;
    data[ 278] = -'sd69835;
    data[ 279] =  'sd73089;
    data[ 280] =  'sd29187;
    data[ 281] = -'sd97259;
    data[ 282] = -'sd3211;
    data[ 283] = -'sd94321;
    data[ 284] =  'sd40605;
    data[ 285] =  'sd16215;
    data[ 286] =  'sd1491;
    data[ 287] =  'sd25978;
    data[ 288] =  'sd58647;
    data[ 289] =  'sd105844;
    data[ 290] =  'sd92294;
    data[ 291] =  'sd84114;
    data[ 292] =  'sd69956;
    data[ 293] = -'sd50704;
    data[ 294] =  'sd114326;
    data[ 295] = -'sd87535;
    data[ 296] =  'sd46730;
    data[ 297] = -'sd99945;
    data[ 298] = -'sd407;
    data[ 299] = -'sd75295;
    data[ 300] =  'sd62417;
    data[ 301] =  'sd53723;
    data[ 302] = -'sd55525;
    data[ 303] = -'sd27988;
    data[ 304] =  'sd69217;
    data[ 305] =  'sd62438;
    data[ 306] =  'sd57608;
    data[ 307] = -'sd86371;
    data[ 308] =  'sd12213;
    data[ 309] =  'sd10692;
    data[ 310] = -'sd20836;
    data[ 311] = -'sd106805;
    data[ 312] = -'sd20222;
    data[ 313] =  'sd6785;
    data[ 314] =  'sd5940;
    data[ 315] =  'sd99472;
    data[ 316] = -'sd87098;
    data[ 317] = -'sd122282;
    data[ 318] =  'sd114817;
    data[ 319] =  'sd3300;
    data[ 320] =  'sd110786;
    data[ 321] =  'sd7136;
    data[ 322] =  'sd70875;
    data[ 323] =  'sd119311;
    data[ 324] =  'sd85119;
    data[ 325] =  'sd6024;
    data[ 326] =  'sd115012;
    data[ 327] =  'sd39375;
    data[ 328] =  'sd38522;
    data[ 329] = -'sd119283;
    data[ 330] = -'sd79939;
    data[ 331] = -'sd47152;
    data[ 332] =  'sd21875;
    data[ 333] =  'sd49163;
    data[ 334] =  'sd100303;
    data[ 335] =  'sd66637;
    data[ 336] =  'sd84852;
    data[ 337] = -'sd43371;
    data[ 338] = -'sd28211;
    data[ 339] =  'sd27962;
    data[ 340] = -'sd74027;
    data[ 341] =  'sd47140;
    data[ 342] = -'sd24095;
    data[ 343] =  'sd39851;
    data[ 344] = -'sd123275;
    data[ 345] = -'sd68888;
    data[ 346] = -'sd1573;
    data[ 347] = -'sd41148;
    data[ 348] = -'sd116670;
    data[ 349] = -'sd96248;
    data[ 350] = -'sd66033;
    data[ 351] =  'sd26888;
    data[ 352] = -'sd22860;
    data[ 353] =  'sd18469;
    data[ 354] = -'sd81233;
    data[ 355] = -'sd36685;
    data[ 356] = -'sd40586;
    data[ 357] = -'sd12700;
    data[ 358] = -'sd100787;
    data[ 359] =  'sd93680;
    data[ 360] =  'sd90667;
    data[ 361] =  'sd32976;
    data[ 362] =  'sd103992;
    data[ 363] = -'sd469;
    data[ 364] = -'sd86765;
    data[ 365] = -'sd60677;
    data[ 366] =  'sd18320;
    data[ 367] = -'sd108798;
    data[ 368] =  'sd110787;
    data[ 369] =  'sd7321;
    data[ 370] =  'sd105100;
    data[ 371] = -'sd45346;
    data[ 372] =  'sd106128;
    data[ 373] = -'sd105023;
    data[ 374] =  'sd59591;
    data[ 375] =  'sd30627;
    data[ 376] = -'sd80716;
    data[ 377] =  'sd58960;
    data[ 378] = -'sd86108;
    data[ 379] =  'sd60868;
    data[ 380] =  'sd17015;
    data[ 381] = -'sd100366;
    data[ 382] = -'sd78292;
    data[ 383] =  'sd7686;
    data[ 384] = -'sd77232;
    data[ 385] = -'sd46071;
    data[ 386] = -'sd27997;
    data[ 387] =  'sd67552;
    data[ 388] =  'sd4270;
    data[ 389] =  'sd40379;
    data[ 390] = -'sd25595;
    data[ 391] =  'sd12208;
    data[ 392] =  'sd9767;
    data[ 393] =  'sd57896;
    data[ 394] = -'sd33091;
    data[ 395] =  'sd124590;
    data[ 396] =  'sd62306;
    data[ 397] =  'sd33188;
    data[ 398] = -'sd106645;
    data[ 399] =  'sd9378;
    data[ 400] = -'sd14069;
    data[ 401] = -'sd104195;
    data[ 402] = -'sd37086;
    data[ 403] = -'sd114771;
    data[ 404] =  'sd5210;
    data[ 405] = -'sd35578;
    data[ 406] = -'sd85648;
    data[ 407] = -'sd103889;
    data[ 408] =  'sd19524;
    data[ 409] =  'sd113942;
    data[ 410] =  'sd91282;
    data[ 411] = -'sd103106;
    data[ 412] = -'sd85478;
    data[ 413] = -'sd72439;
    data[ 414] =  'sd91063;
    data[ 415] =  'sd106236;
    data[ 416] = -'sd85043;
    data[ 417] =  'sd8036;
    data[ 418] = -'sd12482;
    data[ 419] = -'sd60457;
    data[ 420] =  'sd59020;
    data[ 421] = -'sd75008;
    data[ 422] =  'sd115512;
    data[ 423] = -'sd117982;
    data[ 424] = -'sd89111;
    data[ 425] =  'sd5027;
    data[ 426] = -'sd69433;
    data[ 427] = -'sd102398;
    data[ 428] =  'sd45502;
    data[ 429] = -'sd77268;
    data[ 430] = -'sd52731;
    data[ 431] = -'sd10812;
    data[ 432] = -'sd1364;
    data[ 433] = -'sd2483;
    data[ 434] =  'sd40359;
    data[ 435] = -'sd29295;
    data[ 436] =  'sd77279;
    data[ 437] =  'sd54766;
    data[ 438] = -'sd112427;
    data[ 439] = -'sd60864;
    data[ 440] = -'sd16275;
    data[ 441] = -'sd12591;
    data[ 442] = -'sd80622;
    data[ 443] =  'sd76350;
    data[ 444] = -'sd117099;
    data[ 445] =  'sd74244;
    data[ 446] = -'sd6995;
    data[ 447] = -'sd44790;
    data[ 448] = -'sd40869;
    data[ 449] = -'sd65055;
    data[ 450] = -'sd42039;
    data[ 451] = -'sd31648;
    data[ 452] = -'sd108169;
    data[ 453] = -'sd22705;
    data[ 454] =  'sd47144;
    data[ 455] = -'sd23355;
    data[ 456] = -'sd73106;
    data[ 457] = -'sd32332;
    data[ 458] =  'sd15148;
    data[ 459] =  'sd53953;
    data[ 460] = -'sd12975;
    data[ 461] =  'sd98195;
    data[ 462] = -'sd73486;
    data[ 463] = -'sd102632;
    data[ 464] =  'sd2212;
    data[ 465] = -'sd90494;
    data[ 466] = -'sd971;
    data[ 467] =  'sd70222;
    data[ 468] = -'sd1494;
    data[ 469] = -'sd26533;
    data[ 470] =  'sd88535;
    data[ 471] = -'sd111587;
    data[ 472] =  'sd94536;
    data[ 473] = -'sd830;
    data[ 474] =  'sd96307;
    data[ 475] =  'sd76948;
    data[ 476] = -'sd6469;
    data[ 477] =  'sd52520;
    data[ 478] = -'sd28223;
    data[ 479] =  'sd25742;
    data[ 480] =  'sd14987;
    data[ 481] =  'sd24168;
    data[ 482] = -'sd26346;
    data[ 483] =  'sd123130;
    data[ 484] =  'sd42063;
    data[ 485] =  'sd36088;
    data[ 486] = -'sd69859;
    data[ 487] =  'sd68649;
    data[ 488] = -'sd42642;
    data[ 489] =  'sd106654;
    data[ 490] = -'sd7713;
    data[ 491] =  'sd72237;
    data[ 492] =  'sd121424;
    data[ 493] = -'sd23690;
    data[ 494] =  'sd114776;
    data[ 495] = -'sd4285;
    data[ 496] = -'sd43154;
    data[ 497] =  'sd11934;
    data[ 498] = -'sd40923;
    data[ 499] = -'sd75045;
    data[ 500] =  'sd108667;
    data[ 501] =  'sd114835;
    data[ 502] =  'sd6630;
    data[ 503] = -'sd22735;
    data[ 504] =  'sd41594;
    data[ 505] = -'sd50677;
    data[ 506] =  'sd119321;
    data[ 507] =  'sd86969;
    data[ 508] =  'sd98417;
    data[ 509] = -'sd32416;
    data[ 510] = -'sd392;
    data[ 511] = -'sd72520;
    data[ 512] =  'sd76078;
    data[ 513] =  'sd82438;
    data[ 514] =  'sd9753;
    data[ 515] =  'sd55306;
    data[ 516] = -'sd12527;
    data[ 517] = -'sd68782;
    data[ 518] =  'sd18037;
    data[ 519] =  'sd88704;
    data[ 520] = -'sd80322;
    data[ 521] = -'sd118007;
    data[ 522] = -'sd93736;
    data[ 523] = -'sd101027;
    data[ 524] =  'sd49280;
    data[ 525] =  'sd121948;
    data[ 526] =  'sd73250;
    data[ 527] =  'sd58972;
    data[ 528] = -'sd83888;
    data[ 529] = -'sd28146;
    data[ 530] =  'sd39987;
    data[ 531] = -'sd98115;
    data[ 532] =  'sd88286;
    data[ 533] =  'sd92205;
    data[ 534] =  'sd67649;
    data[ 535] =  'sd22215;
    data[ 536] =  'sd112063;
    data[ 537] = -'sd6476;
    data[ 538] =  'sd51225;
    data[ 539] = -'sd17941;
    data[ 540] = -'sd70944;
    data[ 541] =  'sd117781;
    data[ 542] =  'sd51926;
    data[ 543] =  'sd111744;
    data[ 544] = -'sd65491;
    data[ 545] = -'sd122699;
    data[ 546] =  'sd37672;
    data[ 547] = -'sd26676;
    data[ 548] =  'sd62080;
    data[ 549] = -'sd8622;
    data[ 550] = -'sd95928;
    data[ 551] = -'sd6833;
    data[ 552] = -'sd14820;
    data[ 553] =  'sd6727;
    data[ 554] = -'sd4790;
    data[ 555] =  'sd113278;
    data[ 556] = -'sd31558;
    data[ 557] = -'sd91519;
    data[ 558] =  'sd59261;
    data[ 559] = -'sd30423;
    data[ 560] =  'sd118456;
    data[ 561] = -'sd73056;
    data[ 562] = -'sd23082;
    data[ 563] = -'sd22601;
    data[ 564] =  'sd66384;
    data[ 565] =  'sd38047;
    data[ 566] =  'sd42699;
    data[ 567] = -'sd96109;
    data[ 568] = -'sd40318;
    data[ 569] =  'sd36880;
    data[ 570] =  'sd76661;
    data[ 571] = -'sd59564;
    data[ 572] = -'sd25632;
    data[ 573] =  'sd5363;
    data[ 574] = -'sd7273;
    data[ 575] = -'sd96220;
    data[ 576] = -'sd60853;
    data[ 577] = -'sd14240;
    data[ 578] =  'sd114027;
    data[ 579] =  'sd107007;
    data[ 580] =  'sd57592;
    data[ 581] = -'sd89331;
    data[ 582] = -'sd35673;
    data[ 583] = -'sd103223;
    data[ 584] = -'sd107123;
    data[ 585] = -'sd79052;
    data[ 586] =  'sd116943;
    data[ 587] = -'sd103104;
    data[ 588] = -'sd85108;
    data[ 589] = -'sd3989;
    data[ 590] =  'sd11606;
    data[ 591] = -'sd101603;
    data[ 592] = -'sd57280;
    data[ 593] = -'sd102806;
    data[ 594] = -'sd29978;
    data[ 595] = -'sd49076;
    data[ 596] = -'sd84208;
    data[ 597] = -'sd87346;
    data[ 598] =  'sd81695;
    data[ 599] =  'sd122155;
    data[ 600] =  'sd111545;
    data[ 601] = -'sd102306;
    data[ 602] =  'sd62522;
    data[ 603] =  'sd73148;
    data[ 604] =  'sd40102;
    data[ 605] = -'sd76840;
    data[ 606] =  'sd26449;
    data[ 607] = -'sd104075;
    data[ 608] = -'sd14886;
    data[ 609] = -'sd5483;
    data[ 610] = -'sd14927;
    data[ 611] = -'sd13068;
    data[ 612] =  'sd80990;
    data[ 613] = -'sd8270;
    data[ 614] = -'sd30808;
    data[ 615] =  'sd47231;
    data[ 616] = -'sd7260;
    data[ 617] = -'sd93815;
    data[ 618] = -'sd115642;
    data[ 619] =  'sd93932;
    data[ 620] = -'sd112570;
    data[ 621] = -'sd87319;
    data[ 622] =  'sd86690;
    data[ 623] =  'sd46802;
    data[ 624] = -'sd86625;
    data[ 625] = -'sd34777;
    data[ 626] =  'sd62537;
    data[ 627] =  'sd75923;
    data[ 628] =  'sd53763;
    data[ 629] = -'sd48125;
    data[ 630] =  'sd91727;
    data[ 631] = -'sd20781;
    data[ 632] = -'sd96630;
    data[ 633] =  'sd113154;
    data[ 634] = -'sd54498;
    data[ 635] = -'sd87850;
    data[ 636] = -'sd11545;
    data[ 637] =  'sd112888;
    data[ 638] = -'sd103708;
    data[ 639] =  'sd53009;
    data[ 640] =  'sd62242;
    data[ 641] =  'sd21348;
    data[ 642] = -'sd48332;
    data[ 643] =  'sd53432;
    data[ 644] = -'sd109360;
    data[ 645] =  'sd6817;
    data[ 646] =  'sd11860;
    data[ 647] = -'sd54613;
    data[ 648] = -'sd109125;
    data[ 649] =  'sd50292;
    data[ 650] =  'sd59311;
    data[ 651] = -'sd21173;
    data[ 652] =  'sd80707;
    data[ 653] = -'sd60625;
    data[ 654] =  'sd27940;
    data[ 655] = -'sd78097;
    data[ 656] =  'sd43761;
    data[ 657] =  'sd100361;
    data[ 658] =  'sd77367;
    data[ 659] =  'sd71046;
    data[ 660] = -'sd98911;
    data[ 661] = -'sd58974;
    data[ 662] =  'sd83518;
    data[ 663] = -'sd40304;
    data[ 664] =  'sd39470;
    data[ 665] =  'sd56097;
    data[ 666] = -'sd116049;
    data[ 667] =  'sd18637;
    data[ 668] = -'sd50153;
    data[ 669] = -'sd33596;
    data[ 670] =  'sd31165;
    data[ 671] =  'sd18814;
    data[ 672] = -'sd17408;
    data[ 673] =  'sd27661;
    data[ 674] =  'sd120145;
    data[ 675] = -'sd10448;
    data[ 676] =  'sd65976;
    data[ 677] = -'sd37433;
    data[ 678] =  'sd70891;
    data[ 679] =  'sd122271;
    data[ 680] = -'sd116852;
    data[ 681] =  'sd119939;
    data[ 682] = -'sd48558;
    data[ 683] =  'sd11622;
    data[ 684] = -'sd98643;
    data[ 685] = -'sd9394;
    data[ 686] =  'sd11109;
    data[ 687] =  'sd56309;
    data[ 688] = -'sd76829;
    data[ 689] =  'sd28484;
    data[ 690] =  'sd22543;
    data[ 691] = -'sd77114;
    data[ 692] = -'sd24241;
    data[ 693] =  'sd12841;
    data[ 694] = -'sd122985;
    data[ 695] = -'sd15238;
    data[ 696] = -'sd70603;
    data[ 697] = -'sd68991;
    data[ 698] = -'sd20628;
    data[ 699] = -'sd68325;
    data[ 700] =  'sd102582;
    data[ 701] = -'sd11462;
    data[ 702] = -'sd121614;
    data[ 703] = -'sd11460;
    data[ 704] = -'sd121244;
    data[ 705] =  'sd56990;
    data[ 706] =  'sd49156;
    data[ 707] =  'sd99008;
    data[ 708] =  'sd76919;
    data[ 709] = -'sd11834;
    data[ 710] =  'sd59423;
    data[ 711] = -'sd453;
    data[ 712] = -'sd83805;
    data[ 713] = -'sd12791;
    data[ 714] = -'sd117622;
    data[ 715] = -'sd22511;
    data[ 716] =  'sd83034;
    data[ 717] =  'sd120013;
    data[ 718] = -'sd34868;
    data[ 719] =  'sd45702;
    data[ 720] = -'sd40268;
    data[ 721] =  'sd46130;
    data[ 722] =  'sd38912;
    data[ 723] = -'sd47133;
    data[ 724] =  'sd25390;
    data[ 725] = -'sd50133;
    data[ 726] = -'sd29896;
    data[ 727] = -'sd33906;
    data[ 728] = -'sd26185;
    data[ 729] = -'sd96942;
    data[ 730] =  'sd55434;
    data[ 731] =  'sd11153;
    data[ 732] =  'sd64449;
    data[ 733] = -'sd70071;
    data[ 734] =  'sd29429;
    data[ 735] = -'sd52489;
    data[ 736] =  'sd33958;
    data[ 737] =  'sd35805;
    data[ 738] = -'sd122214;
    data[ 739] = -'sd122460;
    data[ 740] =  'sd81887;
    data[ 741] = -'sd92182;
    data[ 742] = -'sd63394;
    data[ 743] =  'sd15389;
    data[ 744] =  'sd98538;
    data[ 745] = -'sd10031;
    data[ 746] = -'sd106736;
    data[ 747] = -'sd7457;
    data[ 748] =  'sd119597;
    data[ 749] = -'sd111828;
    data[ 750] =  'sd49951;
    data[ 751] = -'sd3774;
    data[ 752] =  'sd51381;
    data[ 753] =  'sd10919;
    data[ 754] =  'sd21159;
    data[ 755] = -'sd83297;
    data[ 756] =  'sd81189;
    data[ 757] =  'sd28545;
    data[ 758] =  'sd33828;
    data[ 759] =  'sd11755;
    data[ 760] = -'sd74038;
    data[ 761] =  'sd45105;
    data[ 762] =  'sd99144;
    data[ 763] =  'sd102079;
    data[ 764] = -'sd104517;
    data[ 765] = -'sd96656;
    data[ 766] =  'sd108344;
    data[ 767] =  'sd55080;
    data[ 768] = -'sd54337;
    data[ 769] = -'sd58065;
    data[ 770] =  'sd1826;
    data[ 771] =  'sd87953;
    data[ 772] =  'sd30600;
    data[ 773] = -'sd85711;
    data[ 774] = -'sd115544;
    data[ 775] =  'sd112062;
    data[ 776] = -'sd6661;
    data[ 777] =  'sd17000;
    data[ 778] = -'sd103141;
    data[ 779] = -'sd91953;
    data[ 780] = -'sd21029;
    data[ 781] =  'sd107347;
    data[ 782] =  'sd120492;
    data[ 783] =  'sd53747;
    data[ 784] = -'sd51085;
    data[ 785] =  'sd43841;
    data[ 786] =  'sd115161;
    data[ 787] =  'sd66940;
    data[ 788] = -'sd108950;
    data[ 789] =  'sd82667;
    data[ 790] =  'sd52118;
    data[ 791] = -'sd102593;
    data[ 792] =  'sd9427;
    data[ 793] = -'sd5004;
    data[ 794] =  'sd73688;
    data[ 795] = -'sd109855;
    data[ 796] = -'sd84758;
    data[ 797] =  'sd60761;
    data[ 798] = -'sd2780;
    data[ 799] = -'sd14586;
    data[ 800] =  'sd50017;
    data[ 801] =  'sd8436;
    data[ 802] =  'sd61518;
    data[ 803] = -'sd112592;
    data[ 804] = -'sd91389;
    data[ 805] =  'sd83311;
    data[ 806] = -'sd78599;
    data[ 807] = -'sd49109;
    data[ 808] = -'sd90313;
    data[ 809] =  'sd32514;
    data[ 810] =  'sd18522;
    data[ 811] = -'sd71428;
    data[ 812] =  'sd28241;
    data[ 813] = -'sd22412;
    data[ 814] =  'sd101349;
    data[ 815] =  'sd10290;
    data[ 816] = -'sd95206;
    data[ 817] = -'sd123120;
    data[ 818] = -'sd40213;
    data[ 819] =  'sd56305;
    data[ 820] = -'sd77569;
    data[ 821] = -'sd108416;
    data[ 822] = -'sd68400;
    data[ 823] =  'sd88707;
    data[ 824] = -'sd79767;
    data[ 825] = -'sd15332;
    data[ 826] = -'sd87993;
    data[ 827] = -'sd38000;
    data[ 828] = -'sd34004;
    data[ 829] = -'sd44315;
    data[ 830] =  'sd47006;
    data[ 831] = -'sd48885;
    data[ 832] = -'sd48873;
    data[ 833] = -'sd46653;
    data[ 834] =  'sd114190;
    data[ 835] = -'sd112695;
    data[ 836] = -'sd110444;
    data[ 837] =  'sd56134;
    data[ 838] = -'sd109204;
    data[ 839] =  'sd35677;
    data[ 840] =  'sd103963;
    data[ 841] = -'sd5834;
    data[ 842] = -'sd79862;
    data[ 843] = -'sd32907;
    data[ 844] = -'sd91227;
    data[ 845] =  'sd113281;
    data[ 846] = -'sd31003;
    data[ 847] =  'sd11156;
    data[ 848] =  'sd65004;
    data[ 849] =  'sd32604;
    data[ 850] =  'sd35172;
    data[ 851] =  'sd10538;
    data[ 852] = -'sd49326;
    data[ 853] =  'sd119399;
    data[ 854] =  'sd101399;
    data[ 855] =  'sd19540;
    data[ 856] =  'sd116902;
    data[ 857] = -'sd110689;
    data[ 858] =  'sd10809;
    data[ 859] =  'sd809;
    data[ 860] = -'sd100192;
    data[ 861] = -'sd46102;
    data[ 862] = -'sd33732;
    data[ 863] =  'sd6005;
    data[ 864] =  'sd111497;
    data[ 865] = -'sd111186;
    data[ 866] = -'sd81136;
    data[ 867] = -'sd18740;
    data[ 868] =  'sd31098;
    data[ 869] =  'sd6419;
    data[ 870] = -'sd61770;
    data[ 871] =  'sd65972;
    data[ 872] = -'sd38173;
    data[ 873] = -'sd66009;
    data[ 874] =  'sd31328;
    data[ 875] =  'sd48969;
    data[ 876] =  'sd64413;
    data[ 877] = -'sd76731;
    data[ 878] =  'sd46614;
    data[ 879] = -'sd121405;
    data[ 880] =  'sd27205;
    data[ 881] =  'sd35785;
    data[ 882] =  'sd123943;
    data[ 883] = -'sd57389;
    data[ 884] = -'sd122971;
    data[ 885] = -'sd12648;
    data[ 886] = -'sd91167;
    data[ 887] =  'sd124381;
    data[ 888] =  'sd23641;
    data[ 889] = -'sd123841;
    data[ 890] =  'sd76259;
    data[ 891] =  'sd115923;
    data[ 892] = -'sd41947;
    data[ 893] = -'sd14628;
    data[ 894] =  'sd42247;
    data[ 895] =  'sd70128;
    data[ 896] = -'sd18884;
    data[ 897] =  'sd4458;
    data[ 898] =  'sd75159;
    data[ 899] = -'sd87577;
    data[ 900] =  'sd38960;
    data[ 901] = -'sd38253;
    data[ 902] = -'sd80809;
    data[ 903] =  'sd41755;
    data[ 904] = -'sd20892;
    data[ 905] = -'sd117165;
    data[ 906] =  'sd62034;
    data[ 907] = -'sd17132;
    data[ 908] =  'sd78721;
    data[ 909] =  'sd71679;
    data[ 910] =  'sd18194;
    data[ 911] =  'sd117749;
    data[ 912] =  'sd46006;
    data[ 913] =  'sd15972;
    data[ 914] = -'sd43464;
    data[ 915] = -'sd45416;
    data[ 916] =  'sd93178;
    data[ 917] = -'sd2203;
    data[ 918] =  'sd92159;
    data[ 919] =  'sd59139;
    data[ 920] = -'sd52993;
    data[ 921] = -'sd59282;
    data[ 922] =  'sd26538;
    data[ 923] = -'sd87610;
    data[ 924] =  'sd32855;
    data[ 925] =  'sd81607;
    data[ 926] =  'sd105875;
    data[ 927] =  'sd98029;
    data[ 928] = -'sd104196;
    data[ 929] = -'sd37271;
    data[ 930] =  'sd100861;
    data[ 931] = -'sd79990;
    data[ 932] = -'sd56587;
    data[ 933] =  'sd25399;
    data[ 934] = -'sd48468;
    data[ 935] =  'sd28272;
    data[ 936] = -'sd16677;
    data[ 937] = -'sd86961;
    data[ 938] = -'sd96937;
    data[ 939] =  'sd56359;
    data[ 940] = -'sd67579;
    data[ 941] = -'sd9265;
    data[ 942] =  'sd34974;
    data[ 943] = -'sd26092;
    data[ 944] = -'sd79737;
    data[ 945] = -'sd9782;
    data[ 946] = -'sd60671;
    data[ 947] =  'sd19430;
    data[ 948] =  'sd96552;
    data[ 949] =  'sd122273;
    data[ 950] = -'sd116482;
    data[ 951] = -'sd61468;
    data[ 952] =  'sd121842;
    data[ 953] =  'sd53640;
    data[ 954] = -'sd70880;
    data[ 955] = -'sd120236;
    data[ 956] = -'sd6387;
    data[ 957] =  'sd67690;
    data[ 958] =  'sd29800;
    data[ 959] =  'sd16146;
    data[ 960] = -'sd11274;
    data[ 961] = -'sd86834;
    data[ 962] = -'sd73442;
    data[ 963] = -'sd94492;
    data[ 964] =  'sd8970;
    data[ 965] = -'sd89549;
    data[ 966] = -'sd76003;
    data[ 967] = -'sd68563;
    data[ 968] =  'sd58552;
    data[ 969] =  'sd88269;
    data[ 970] =  'sd89060;
    data[ 971] = -'sd14462;
    data[ 972] =  'sd72957;
    data[ 973] =  'sd4767;
    data[ 974] = -'sd117533;
    data[ 975] = -'sd6046;
    data[ 976] = -'sd119082;
    data[ 977] = -'sd42754;
    data[ 978] =  'sd85934;
    data[ 979] = -'sd93058;
    data[ 980] =  'sd24403;
    data[ 981] =  'sd17129;
    data[ 982] = -'sd79276;
    data[ 983] =  'sd75503;
    data[ 984] = -'sd23937;
    data[ 985] =  'sd69081;
    data[ 986] =  'sd37278;
    data[ 987] = -'sd99566;
    data[ 988] =  'sd69708;
    data[ 989] = -'sd96584;
    data[ 990] =  'sd121664;
    data[ 991] =  'sd20710;
    data[ 992] =  'sd83495;
    data[ 993] = -'sd44559;
    data[ 994] =  'sd1866;
    data[ 995] =  'sd95353;
    data[ 996] = -'sd99542;
    data[ 997] =  'sd74148;
    data[ 998] = -'sd24755;
    data[ 999] = -'sd82249;
    data[1000] =  'sd25212;
    data[1001] = -'sd83063;
    data[1002] =  'sd124479;
    data[1003] =  'sd41771;
    data[1004] = -'sd17932;
    data[1005] = -'sd69279;
    data[1006] = -'sd73908;
    data[1007] =  'sd69155;
    data[1008] =  'sd50968;
    data[1009] = -'sd65486;
    data[1010] = -'sd121774;
    data[1011] = -'sd41060;
    data[1012] = -'sd100390;
    data[1013] = -'sd82732;
    data[1014] = -'sd64143;
    data[1015] = -'sd123176;
    data[1016] = -'sd50573;
    data[1017] = -'sd111296;
    data[1018] = -'sd101486;
    data[1019] = -'sd35635;
    data[1020] = -'sd96193;
    data[1021] = -'sd55858;
    data[1022] = -'sd89593;
    data[1023] = -'sd84143;
    data[1024] = -'sd75321;
    data[1025] =  'sd57607;
    data[1026] = -'sd86556;
    data[1027] = -'sd22012;
    data[1028] = -'sd74508;
    data[1029] = -'sd41845;
    data[1030] =  'sd4242;
    data[1031] =  'sd35199;
    data[1032] =  'sd15533;
    data[1033] = -'sd124679;
    data[1034] = -'sd78771;
    data[1035] = -'sd80929;
    data[1036] =  'sd19555;
    data[1037] =  'sd119677;
    data[1038] = -'sd97028;
    data[1039] =  'sd39524;
    data[1040] =  'sd66087;
    data[1041] = -'sd16898;
    data[1042] =  'sd122011;
    data[1043] =  'sd84905;
    data[1044] = -'sd33566;
    data[1045] =  'sd36715;
    data[1046] =  'sd46136;
    data[1047] =  'sd40022;
    data[1048] = -'sd91640;
    data[1049] =  'sd36876;
    data[1050] =  'sd75921;
    data[1051] =  'sd53393;
    data[1052] = -'sd116575;
    data[1053] = -'sd78673;
    data[1054] = -'sd62799;
    data[1055] = -'sd124393;
    data[1056] = -'sd25861;
    data[1057] = -'sd37002;
    data[1058] = -'sd99231;
    data[1059] = -'sd118174;
    data[1060] = -'sd124631;
    data[1061] = -'sd69891;
    data[1062] =  'sd62729;
    data[1063] =  'sd111443;
    data[1064] = -'sd121176;
    data[1065] =  'sd69570;
    data[1066] = -'sd122114;
    data[1067] = -'sd103960;
    data[1068] =  'sd6389;
    data[1069] = -'sd67320;
    data[1070] =  'sd38650;
    data[1071] = -'sd95603;
    data[1072] =  'sd53292;
    data[1073] =  'sd114597;
    data[1074] = -'sd37400;
    data[1075] =  'sd76996;
    data[1076] =  'sd2411;
    data[1077] = -'sd53679;
    data[1078] =  'sd63665;
    data[1079] =  'sd34746;
    data[1080] = -'sd68272;
    data[1081] =  'sd112387;
    data[1082] =  'sd53464;
    data[1083] = -'sd103440;
    data[1084] =  'sd102589;
    data[1085] = -'sd10167;
    data[1086] =  'sd117961;
    data[1087] =  'sd85226;
    data[1088] =  'sd25819;
    data[1089] =  'sd29232;
    data[1090] = -'sd88934;
    data[1091] =  'sd37772;
    data[1092] = -'sd8176;
    data[1093] = -'sd13418;
    data[1094] =  'sd16240;
    data[1095] =  'sd6116;
    data[1096] = -'sd117825;
    data[1097] = -'sd60066;
    data[1098] = -'sd118502;
    data[1099] =  'sd64546;
    data[1100] = -'sd52126;
    data[1101] =  'sd101113;
    data[1102] = -'sd33370;
    data[1103] =  'sd72975;
    data[1104] =  'sd8097;
    data[1105] = -'sd1197;
    data[1106] =  'sd28412;
    data[1107] =  'sd9223;
    data[1108] = -'sd42744;
    data[1109] =  'sd87784;
    data[1110] = -'sd665;
    data[1111] = -'sd123025;
    data[1112] = -'sd22638;
    data[1113] =  'sd59539;
    data[1114] =  'sd21007;
    data[1115] = -'sd111417;
    data[1116] = -'sd123871;
    data[1117] =  'sd70709;
    data[1118] =  'sd88601;
    data[1119] = -'sd99377;
    data[1120] =  'sd104673;
    data[1121] = -'sd124341;
    data[1122] = -'sd16241;
    data[1123] = -'sd6301;
    data[1124] =  'sd83600;
    data[1125] = -'sd25134;
    data[1126] =  'sd97493;
    data[1127] =  'sd46501;
    data[1128] =  'sd107547;
    data[1129] = -'sd92365;
    data[1130] = -'sd97249;
    data[1131] = -'sd1361;
    data[1132] = -'sd1928;
    data[1133] = -'sd106823;
    data[1134] = -'sd23552;
    data[1135] = -'sd109551;
    data[1136] = -'sd28518;
    data[1137] = -'sd28833;
    data[1138] = -'sd87108;
    data[1139] = -'sd124132;
    data[1140] =  'sd22424;
    data[1141] = -'sd99129;
    data[1142] = -'sd99304;
    data[1143] =  'sd118178;
    data[1144] = -'sd124486;
    data[1145] = -'sd43066;
    data[1146] =  'sd28214;
    data[1147] = -'sd27407;
    data[1148] = -'sd73155;
    data[1149] = -'sd41397;
    data[1150] =  'sd87122;
    data[1151] = -'sd123135;
    data[1152] = -'sd42988;
    data[1153] =  'sd42644;
    data[1154] = -'sd106284;
    data[1155] =  'sd76163;
    data[1156] =  'sd98163;
    data[1157] = -'sd79406;
    data[1158] =  'sd51453;
    data[1159] =  'sd24239;
    data[1160] = -'sd13211;
    data[1161] =  'sd54535;
    data[1162] =  'sd94695;
    data[1163] =  'sd28585;
    data[1164] =  'sd41228;
    data[1165] = -'sd118387;
    data[1166] =  'sd85821;
    data[1167] = -'sd113963;
    data[1168] = -'sd95167;
    data[1169] = -'sd115905;
    data[1170] =  'sd45277;
    data[1171] = -'sd118893;
    data[1172] = -'sd7789;
    data[1173] =  'sd58177;
    data[1174] =  'sd18894;
    data[1175] = -'sd2608;
    data[1176] =  'sd17234;
    data[1177] = -'sd59851;
    data[1178] = -'sd78727;
    data[1179] = -'sd72789;
    data[1180] =  'sd26313;
    data[1181] =  'sd120622;
    data[1182] =  'sd77797;
    data[1183] = -'sd99261;
    data[1184] = -'sd123724;
    data[1185] =  'sd97904;
    data[1186] =  'sd122536;
    data[1187] = -'sd67827;
    data[1188] = -'sd55145;
    data[1189] =  'sd42312;
    data[1190] =  'sd82153;
    data[1191] = -'sd42972;
    data[1192] =  'sd45604;
    data[1193] = -'sd58398;
    data[1194] = -'sd59779;
    data[1195] = -'sd65407;
    data[1196] = -'sd107159;
    data[1197] = -'sd85712;
    data[1198] = -'sd115729;
    data[1199] =  'sd77837;
    data[1200] = -'sd91861;
    data[1201] = -'sd4009;
    data[1202] =  'sd7906;
    data[1203] = -'sd36532;
    data[1204] = -'sd12281;
    data[1205] = -'sd23272;
    data[1206] = -'sd57751;
    data[1207] =  'sd59916;
    data[1208] =  'sd90752;
    data[1209] =  'sd48701;
    data[1210] =  'sd14833;
    data[1211] = -'sd4322;
    data[1212] = -'sd49999;
    data[1213] = -'sd5106;
    data[1214] =  'sd54818;
    data[1215] = -'sd102807;
    data[1216] = -'sd30163;
    data[1217] = -'sd83301;
    data[1218] =  'sd80449;
    data[1219] = -'sd108355;
    data[1220] = -'sd57115;
    data[1221] = -'sd72281;
    data[1222] =  'sd120293;
    data[1223] =  'sd16932;
    data[1224] = -'sd115721;
    data[1225] =  'sd79317;
    data[1226] = -'sd67918;
    data[1227] = -'sd71980;
    data[1228] = -'sd73879;
    data[1229] =  'sd74520;
    data[1230] =  'sd44065;
    data[1231] = -'sd93256;
    data[1232] = -'sd12227;
    data[1233] = -'sd13282;
    data[1234] =  'sd41400;
    data[1235] = -'sd86567;
    data[1236] = -'sd24047;
    data[1237] =  'sd48731;
    data[1238] =  'sd20383;
    data[1239] =  'sd23000;
    data[1240] =  'sd7431;
    data[1241] = -'sd124407;
    data[1242] = -'sd28451;
    data[1243] = -'sd16438;
    data[1244] = -'sd42746;
    data[1245] =  'sd87414;
    data[1246] = -'sd69115;
    data[1247] = -'sd43568;
    data[1248] = -'sd64656;
    data[1249] =  'sd31776;
    data[1250] = -'sd118008;
    data[1251] = -'sd93921;
    data[1252] =  'sd114605;
    data[1253] = -'sd35920;
    data[1254] =  'sd100939;
    data[1255] = -'sd65560;
    data[1256] =  'sd114393;
    data[1257] = -'sd75140;
    data[1258] =  'sd91092;
    data[1259] =  'sd111601;
    data[1260] = -'sd91946;
    data[1261] = -'sd19734;
    data[1262] =  'sd97065;
    data[1263] = -'sd32679;
    data[1264] = -'sd49047;
    data[1265] = -'sd78843;
    data[1266] = -'sd94249;
    data[1267] =  'sd53925;
    data[1268] = -'sd18155;
    data[1269] = -'sd110534;
    data[1270] =  'sd39484;
    data[1271] =  'sd58687;
    data[1272] =  'sd113244;
    data[1273] = -'sd37848;
    data[1274] = -'sd5884;
    data[1275] = -'sd89112;
    data[1276] =  'sd4842;
    data[1277] = -'sd103658;
    data[1278] =  'sd62259;
    data[1279] =  'sd24493;
    data[1280] =  'sd33779;
    data[1281] =  'sd2690;
    data[1282] = -'sd2064;
    data[1283] =  'sd117874;
    data[1284] =  'sd69131;
    data[1285] =  'sd46528;
    data[1286] =  'sd112542;
    data[1287] =  'sd82139;
    data[1288] = -'sd45562;
    data[1289] =  'sd66168;
    data[1290] = -'sd1913;
    data[1291] = -'sd104048;
    data[1292] = -'sd9891;
    data[1293] = -'sd80836;
    data[1294] =  'sd36760;
    data[1295] =  'sd54461;
    data[1296] =  'sd81005;
    data[1297] = -'sd5495;
    data[1298] = -'sd17147;
    data[1299] =  'sd75946;
    data[1300] =  'sd58018;
    data[1301] = -'sd10521;
    data[1302] =  'sd52471;
    data[1303] = -'sd37288;
    data[1304] =  'sd97716;
    data[1305] =  'sd87756;
    data[1306] = -'sd5845;
    data[1307] = -'sd81897;
    data[1308] =  'sd90332;
    data[1309] = -'sd28999;
    data[1310] = -'sd117818;
    data[1311] = -'sd58771;
    data[1312] =  'sd121073;
    data[1313] = -'sd88625;
    data[1314] =  'sd94937;
    data[1315] =  'sd73355;
    data[1316] =  'sd78397;
    data[1317] =  'sd11739;
    data[1318] = -'sd76998;
    data[1319] = -'sd2781;
    data[1320] = -'sd14771;
    data[1321] =  'sd15792;
    data[1322] = -'sd76764;
    data[1323] =  'sd40509;
    data[1324] = -'sd1545;
    data[1325] = -'sd35968;
    data[1326] =  'sd92059;
    data[1327] =  'sd40639;
    data[1328] =  'sd22505;
    data[1329] = -'sd84144;
    data[1330] = -'sd75506;
    data[1331] =  'sd23382;
    data[1332] =  'sd78101;
    data[1333] = -'sd43021;
    data[1334] =  'sd36539;
    data[1335] =  'sd13576;
    data[1336] =  'sd12990;
    data[1337] = -'sd95420;
    data[1338] =  'sd87147;
    data[1339] = -'sd118510;
    data[1340] =  'sd63066;
    data[1341] = -'sd76069;
    data[1342] = -'sd80773;
    data[1343] =  'sd48415;
    data[1344] = -'sd38077;
    data[1345] = -'sd48249;
    data[1346] =  'sd68787;
    data[1347] = -'sd17112;
    data[1348] =  'sd82421;
    data[1349] =  'sd6608;
    data[1350] = -'sd26805;
    data[1351] =  'sd38215;
    data[1352] =  'sd73779;
    data[1353] = -'sd93020;
    data[1354] =  'sd31433;
    data[1355] =  'sd68394;
    data[1356] = -'sd89817;
    data[1357] =  'sd124274;
    data[1358] =  'sd3846;
    data[1359] = -'sd38061;
    data[1360] = -'sd45289;
    data[1361] =  'sd116673;
    data[1362] =  'sd96803;
    data[1363] = -'sd81149;
    data[1364] = -'sd21145;
    data[1365] =  'sd85887;
    data[1366] = -'sd101753;
    data[1367] = -'sd85030;
    data[1368] =  'sd10441;
    data[1369] = -'sd67271;
    data[1370] =  'sd47715;
    data[1371] =  'sd82280;
    data[1372] = -'sd19477;
    data[1373] = -'sd105247;
    data[1374] =  'sd18151;
    data[1375] =  'sd109794;
    data[1376] =  'sd73473;
    data[1377] =  'sd100227;
    data[1378] =  'sd52577;
    data[1379] = -'sd17678;
    data[1380] = -'sd22289;
    data[1381] =  'sd124104;
    data[1382] = -'sd27604;
    data[1383] = -'sd109600;
    data[1384] = -'sd37583;
    data[1385] =  'sd43141;
    data[1386] = -'sd14339;
    data[1387] =  'sd95712;
    data[1388] = -'sd33127;
    data[1389] =  'sd117930;
    data[1390] =  'sd79491;
    data[1391] = -'sd35728;
    data[1392] = -'sd113398;
    data[1393] =  'sd9358;
    data[1394] = -'sd17769;
    data[1395] = -'sd39124;
    data[1396] =  'sd7913;
    data[1397] = -'sd35237;
    data[1398] = -'sd22563;
    data[1399] =  'sd73414;
    data[1400] =  'sd89312;
    data[1401] =  'sd32158;
    data[1402] = -'sd47338;
    data[1403] = -'sd12535;
    data[1404] = -'sd70262;
    data[1405] = -'sd5906;
    data[1406] = -'sd93182;
    data[1407] =  'sd1463;
    data[1408] =  'sd20798;
    data[1409] =  'sd99775;
    data[1410] = -'sd31043;
    data[1411] =  'sd3756;
    data[1412] = -'sd54711;
    data[1413] =  'sd122602;
    data[1414] = -'sd55617;
    data[1415] = -'sd45008;
    data[1416] = -'sd81199;
    data[1417] = -'sd30395;
    data[1418] =  'sd123636;
    data[1419] = -'sd114184;
    data[1420] =  'sd113805;
    data[1421] =  'sd65937;
    data[1422] = -'sd44648;
    data[1423] = -'sd14599;
    data[1424] =  'sd47612;
    data[1425] =  'sd63225;
    data[1426] = -'sd46654;
    data[1427] =  'sd114005;
    data[1428] =  'sd102937;
    data[1429] =  'sd54213;
    data[1430] =  'sd35125;
    data[1431] =  'sd1843;
    data[1432] =  'sd91098;
    data[1433] =  'sd112711;
    data[1434] =  'sd113404;
    data[1435] = -'sd8248;
    data[1436] = -'sd26738;
    data[1437] =  'sd50610;
    data[1438] =  'sd118141;
    data[1439] =  'sd118526;
    data[1440] = -'sd60106;
    data[1441] =  'sd123955;
    data[1442] = -'sd55169;
    data[1443] =  'sd37872;
    data[1444] =  'sd10324;
    data[1445] = -'sd88916;
    data[1446] =  'sd41102;
    data[1447] =  'sd108160;
    data[1448] =  'sd21040;
    data[1449] = -'sd105312;
    data[1450] =  'sd6126;
    data[1451] = -'sd115975;
    data[1452] =  'sd32327;
    data[1453] = -'sd16073;
    data[1454] =  'sd24779;
    data[1455] =  'sd86689;
    data[1456] =  'sd46617;
    data[1457] = -'sd120850;
    data[1458] = -'sd119977;
    data[1459] =  'sd41528;
    data[1460] = -'sd62887;
    data[1461] =  'sd109184;
    data[1462] = -'sd39377;
    data[1463] = -'sd38892;
    data[1464] =  'sd50833;
    data[1465] = -'sd90461;
    data[1466] =  'sd5134;
    data[1467] = -'sd49638;
    data[1468] =  'sd61679;
    data[1469] = -'sd82807;
    data[1470] = -'sd78018;
    data[1471] =  'sd58376;
    data[1472] =  'sd55709;
    data[1473] =  'sd62028;
    data[1474] = -'sd18242;
    data[1475] =  'sd123228;
    data[1476] =  'sd60193;
    data[1477] = -'sd107860;
    data[1478] =  'sd34460;
    data[1479] = -'sd121182;
    data[1480] =  'sd68460;
    data[1481] = -'sd77607;
    data[1482] = -'sd115446;
    data[1483] = -'sd119665;
    data[1484] =  'sd99248;
    data[1485] =  'sd121319;
    data[1486] = -'sd43115;
    data[1487] =  'sd19149;
    data[1488] =  'sd44567;
    data[1489] = -'sd386;
    data[1490] = -'sd71410;
    data[1491] =  'sd31571;
    data[1492] =  'sd93924;
    data[1493] = -'sd114050;
    data[1494] = -'sd111262;
    data[1495] = -'sd95196;
    data[1496] = -'sd121270;
    data[1497] =  'sd52180;
    data[1498] = -'sd91123;
    data[1499] = -'sd117336;
    data[1500] =  'sd30399;
    data[1501] = -'sd122896;
    data[1502] =  'sd1227;
    data[1503] = -'sd22862;
    data[1504] =  'sd18099;
    data[1505] =  'sd100174;
    data[1506] =  'sd42772;
    data[1507] = -'sd82604;
    data[1508] = -'sd40463;
    data[1509] =  'sd10055;
    data[1510] =  'sd111176;
    data[1511] =  'sd79286;
    data[1512] = -'sd73653;
    data[1513] =  'sd116330;
    data[1514] =  'sd33348;
    data[1515] = -'sd77045;
    data[1516] = -'sd11476;
    data[1517] = -'sd124204;
    data[1518] =  'sd9104;
    data[1519] = -'sd64759;
    data[1520] =  'sd12721;
    data[1521] =  'sd104672;
    data[1522] = -'sd124526;
    data[1523] = -'sd50466;
    data[1524] = -'sd91501;
    data[1525] =  'sd62591;
    data[1526] =  'sd85913;
    data[1527] = -'sd96943;
    data[1528] =  'sd55249;
    data[1529] = -'sd23072;
    data[1530] = -'sd20751;
    data[1531] = -'sd91080;
    data[1532] = -'sd109381;
    data[1533] =  'sd2932;
    data[1534] =  'sd42706;
    data[1535] = -'sd94814;
    data[1536] = -'sd50600;
    data[1537] = -'sd116291;
    data[1538] = -'sd26133;
    data[1539] = -'sd87322;
    data[1540] =  'sd86135;
    data[1541] = -'sd55873;
    data[1542] = -'sd92368;
    data[1543] = -'sd97804;
    data[1544] = -'sd104036;
    data[1545] = -'sd7671;
    data[1546] =  'sd80007;
    data[1547] =  'sd59732;
    data[1548] =  'sd56712;
    data[1549] = -'sd2274;
    data[1550] =  'sd79024;
    data[1551] = -'sd122123;
    data[1552] = -'sd105625;
    data[1553] = -'sd51779;
    data[1554] = -'sd84549;
    data[1555] =  'sd99426;
    data[1556] = -'sd95608;
    data[1557] =  'sd52367;
    data[1558] = -'sd56528;
    data[1559] =  'sd36314;
    data[1560] = -'sd28049;
    data[1561] =  'sd57932;
    data[1562] = -'sd26431;
    data[1563] =  'sd107405;
    data[1564] = -'sd118635;
    data[1565] =  'sd39941;
    data[1566] = -'sd106625;
    data[1567] =  'sd13078;
    data[1568] = -'sd79140;
    data[1569] =  'sd100663;
    data[1570] = -'sd116620;
    data[1571] = -'sd86998;
    data[1572] = -'sd103782;
    data[1573] =  'sd39319;
    data[1574] =  'sd28162;
    data[1575] = -'sd37027;
    data[1576] = -'sd103856;
    data[1577] =  'sd25629;
    data[1578] = -'sd5918;
    data[1579] = -'sd95402;
    data[1580] =  'sd90477;
    data[1581] = -'sd2174;
    data[1582] =  'sd97524;
    data[1583] =  'sd52236;
    data[1584] = -'sd80763;
    data[1585] =  'sd50265;
    data[1586] =  'sd54316;
    data[1587] =  'sd54180;
    data[1588] =  'sd29020;
    data[1589] =  'sd121703;
    data[1590] =  'sd27925;
    data[1591] = -'sd80872;
    data[1592] =  'sd30100;
    data[1593] =  'sd71646;
    data[1594] =  'sd12089;
    data[1595] = -'sd12248;
    data[1596] = -'sd17167;
    data[1597] =  'sd72246;
    data[1598] =  'sd123089;
    data[1599] =  'sd34478;
    data[1600] = -'sd117852;
    data[1601] = -'sd65061;
    data[1602] = -'sd43149;
    data[1603] =  'sd12859;
    data[1604] = -'sd119655;
    data[1605] =  'sd101098;
    data[1606] = -'sd36145;
    data[1607] =  'sd59314;
    data[1608] = -'sd20618;
    data[1609] = -'sd66475;
    data[1610] = -'sd54882;
    data[1611] =  'sd90967;
    data[1612] =  'sd88476;
    data[1613] = -'sd122502;
    data[1614] =  'sd74117;
    data[1615] = -'sd30490;
    data[1616] =  'sd106061;
    data[1617] = -'sd117418;
    data[1618] =  'sd15229;
    data[1619] =  'sd68938;
    data[1620] =  'sd10823;
    data[1621] =  'sd3399;
    data[1622] = -'sd120756;
    data[1623] = -'sd102587;
    data[1624] =  'sd10537;
    data[1625] = -'sd49511;
    data[1626] =  'sd85174;
    data[1627] =  'sd16199;
    data[1628] = -'sd1469;
    data[1629] = -'sd21908;
    data[1630] = -'sd55268;
    data[1631] =  'sd19557;
    data[1632] =  'sd120047;
    data[1633] = -'sd28578;
    data[1634] = -'sd39933;
    data[1635] =  'sd108105;
    data[1636] =  'sd10865;
    data[1637] =  'sd11169;
    data[1638] =  'sd67409;
    data[1639] = -'sd22185;
    data[1640] = -'sd106513;
    data[1641] =  'sd33798;
    data[1642] =  'sd6205;
    data[1643] = -'sd101360;
    data[1644] = -'sd12325;
    data[1645] = -'sd31412;
    data[1646] = -'sd64509;
    data[1647] =  'sd58971;
    data[1648] = -'sd84073;
    data[1649] = -'sd62371;
    data[1650] = -'sd45213;
    data[1651] = -'sd119124;
    data[1652] = -'sd50524;
    data[1653] = -'sd102231;
    data[1654] =  'sd76397;
    data[1655] = -'sd108404;
    data[1656] = -'sd66180;
    data[1657] = -'sd307;
    data[1658] = -'sd56795;
    data[1659] = -'sd13081;
    data[1660] =  'sd78585;
    data[1661] =  'sd46519;
    data[1662] =  'sd110877;
    data[1663] =  'sd23971;
    data[1664] = -'sd62791;
    data[1665] = -'sd122913;
    data[1666] = -'sd1918;
    data[1667] = -'sd104973;
    data[1668] =  'sd68841;
    data[1669] = -'sd7122;
    data[1670] = -'sd68285;
    data[1671] =  'sd109982;
    data[1672] =  'sd108253;
    data[1673] =  'sd38245;
    data[1674] =  'sd79329;
    data[1675] = -'sd65698;
    data[1676] =  'sd88863;
    data[1677] = -'sd50907;
    data[1678] =  'sd76771;
    data[1679] = -'sd39214;
    data[1680] = -'sd8737;
    data[1681] = -'sd117203;
    data[1682] =  'sd55004;
    data[1683] = -'sd68397;
    data[1684] =  'sd89262;
    data[1685] =  'sd22908;
    data[1686] = -'sd9589;
    data[1687] = -'sd24966;
    data[1688] = -'sd121284;
    data[1689] =  'sd49590;
    data[1690] = -'sd70559;
    data[1691] = -'sd60851;
    data[1692] = -'sd13870;
    data[1693] = -'sd67380;
    data[1694] =  'sd27550;
    data[1695] =  'sd99610;
    data[1696] = -'sd61568;
    data[1697] =  'sd103342;
    data[1698] = -'sd120719;
    data[1699] = -'sd95742;
    data[1700] =  'sd27577;
    data[1701] =  'sd104605;
    data[1702] =  'sd112936;
    data[1703] = -'sd94828;
    data[1704] = -'sd53190;
    data[1705] = -'sd95727;
    data[1706] =  'sd30352;
    data[1707] =  'sd118266;
    data[1708] = -'sd108206;
    data[1709] = -'sd29550;
    data[1710] =  'sd30104;
    data[1711] =  'sd72386;
    data[1712] = -'sd100868;
    data[1713] =  'sd78695;
    data[1714] =  'sd66869;
    data[1715] = -'sd122085;
    data[1716] = -'sd98595;
    data[1717] = -'sd514;
    data[1718] = -'sd95090;
    data[1719] = -'sd101660;
    data[1720] = -'sd67825;
    data[1721] = -'sd54775;
    data[1722] =  'sd110762;
    data[1723] =  'sd2696;
    data[1724] = -'sd954;
    data[1725] =  'sd73367;
    data[1726] =  'sd80617;
    data[1727] = -'sd77275;
    data[1728] = -'sd54026;
    data[1729] = -'sd530;
    data[1730] = -'sd98050;
    data[1731] =  'sd100311;
    data[1732] =  'sd68117;
    data[1733] =  'sd108795;
    data[1734] = -'sd111342;
    data[1735] = -'sd109996;
    data[1736] = -'sd110843;
    data[1737] = -'sd17681;
    data[1738] = -'sd22844;
    data[1739] =  'sd21429;
    data[1740] = -'sd33347;
    data[1741] =  'sd77230;
    data[1742] =  'sd45701;
    data[1743] = -'sd40453;
    data[1744] =  'sd11905;
    data[1745] = -'sd46288;
    data[1746] = -'sd68142;
    data[1747] = -'sd113420;
    data[1748] =  'sd5288;
    data[1749] = -'sd21148;
    data[1750] =  'sd85332;
    data[1751] =  'sd45429;
    data[1752] = -'sd90773;
    data[1753] = -'sd52586;
    data[1754] =  'sd16013;
    data[1755] = -'sd35879;
    data[1756] =  'sd108524;
    data[1757] =  'sd88380;
    data[1758] =  'sd109595;
    data[1759] =  'sd36658;
    data[1760] =  'sd35591;
    data[1761] =  'sd88053;
    data[1762] =  'sd49100;
    data[1763] =  'sd88648;
    data[1764] = -'sd90682;
    data[1765] = -'sd35751;
    data[1766] = -'sd117653;
    data[1767] = -'sd28246;
    data[1768] =  'sd21487;
    data[1769] = -'sd22617;
    data[1770] =  'sd63424;
    data[1771] = -'sd9839;
    data[1772] = -'sd71216;
    data[1773] =  'sd67461;
    data[1774] = -'sd12565;
    data[1775] = -'sd75812;
    data[1776] = -'sd33228;
    data[1777] =  'sd99245;
    data[1778] =  'sd120764;
    data[1779] =  'sd104067;
    data[1780] =  'sd13406;
    data[1781] = -'sd18460;
    data[1782] =  'sd82898;
    data[1783] =  'sd94853;
    data[1784] =  'sd57815;
    data[1785] = -'sd48076;
    data[1786] =  'sd100792;
    data[1787] = -'sd92755;
    data[1788] =  'sd80458;
    data[1789] = -'sd106690;
    data[1790] =  'sd1053;
    data[1791] = -'sd55052;
    data[1792] =  'sd59517;
    data[1793] =  'sd16937;
    data[1794] = -'sd114796;
    data[1795] =  'sd585;
    data[1796] =  'sd108225;
    data[1797] =  'sd33065;
    data[1798] =  'sd120457;
    data[1799] =  'sd47272;
    data[1800] =  'sd325;
    data[1801] =  'sd60125;
    data[1802] = -'sd120440;
    data[1803] = -'sd44127;
    data[1804] =  'sd81786;
    data[1805] = -'sd110867;
    data[1806] = -'sd22121;
    data[1807] = -'sd94673;
    data[1808] = -'sd24515;
    data[1809] = -'sd37849;
    data[1810] = -'sd6069;
    data[1811] = -'sd123337;
    data[1812] = -'sd80358;
    data[1813] = -'sd124667;
    data[1814] = -'sd76551;
    data[1815] =  'sd79914;
    data[1816] =  'sd42527;
    data[1817] =  'sd121928;
    data[1818] =  'sd69550;
    data[1819] =  'sd124043;
    data[1820] = -'sd38889;
    data[1821] =  'sd51388;
    data[1822] =  'sd12214;
    data[1823] =  'sd10877;
    data[1824] =  'sd13389;
    data[1825] = -'sd21605;
    data[1826] =  'sd787;
    data[1827] = -'sd104262;
    data[1828] = -'sd49481;
    data[1829] =  'sd90724;
    data[1830] =  'sd43521;
    data[1831] =  'sd55961;
    data[1832] =  'sd108648;
    data[1833] =  'sd111320;
    data[1834] =  'sd105926;
    data[1835] =  'sd107464;
    data[1836] = -'sd107720;
    data[1837] =  'sd60360;
    data[1838] = -'sd76965;
    data[1839] =  'sd3324;
    data[1840] =  'sd115226;
    data[1841] =  'sd78965;
    data[1842] =  'sd116819;
    data[1843] =  'sd123813;
    data[1844] = -'sd81439;
    data[1845] = -'sd74795;
    data[1846] = -'sd94940;
    data[1847] = -'sd73910;
    data[1848] =  'sd68785;
    data[1849] = -'sd17482;
    data[1850] =  'sd13971;
    data[1851] =  'sd86065;
    data[1852] = -'sd68823;
    data[1853] =  'sd10452;
    data[1854] = -'sd65236;
    data[1855] = -'sd75524;
    data[1856] =  'sd20052;
    data[1857] = -'sd38235;
    data[1858] = -'sd77479;
    data[1859] = -'sd91766;
    data[1860] =  'sd13566;
    data[1861] =  'sd11140;
    data[1862] =  'sd62044;
    data[1863] = -'sd15282;
    data[1864] = -'sd78743;
    data[1865] = -'sd75749;
    data[1866] = -'sd21573;
    data[1867] =  'sd6707;
    data[1868] = -'sd8490;
    data[1869] = -'sd71508;
    data[1870] =  'sd13441;
    data[1871] = -'sd11985;
    data[1872] =  'sd31488;
    data[1873] =  'sd78569;
    data[1874] =  'sd43559;
    data[1875] =  'sd62991;
    data[1876] = -'sd89944;
    data[1877] =  'sd100779;
    data[1878] = -'sd95160;
    data[1879] = -'sd114610;
    data[1880] =  'sd34995;
    data[1881] = -'sd22207;
    data[1882] = -'sd110583;
    data[1883] =  'sd30419;
    data[1884] = -'sd119196;
    data[1885] = -'sd63844;
    data[1886] = -'sd67861;
    data[1887] = -'sd61435;
    data[1888] = -'sd121910;
    data[1889] = -'sd66220;
    data[1890] = -'sd7707;
    data[1891] =  'sd73347;
    data[1892] =  'sd76917;
    data[1893] = -'sd12204;
    data[1894] = -'sd9027;
    data[1895] =  'sd79004;
    data[1896] =  'sd124034;
    data[1897] = -'sd40554;
    data[1898] = -'sd6780;
    data[1899] = -'sd5015;
    data[1900] =  'sd71653;
    data[1901] =  'sd13384;
    data[1902] = -'sd22530;
    data[1903] =  'sd79519;
    data[1904] = -'sd30548;
    data[1905] =  'sd95331;
    data[1906] = -'sd103612;
    data[1907] =  'sd70769;
    data[1908] =  'sd99701;
    data[1909] = -'sd44733;
    data[1910] = -'sd30324;
    data[1911] = -'sd113086;
    data[1912] =  'sd67078;
    data[1913] = -'sd83420;
    data[1914] =  'sd58434;
    data[1915] =  'sd66439;
    data[1916] =  'sd48222;
    data[1917] = -'sd73782;
    data[1918] =  'sd92465;
    data[1919] =  'sd115749;
    data[1920] = -'sd74137;
    data[1921] =  'sd26790;
    data[1922] = -'sd40990;
    data[1923] = -'sd87440;
    data[1924] =  'sd64305;
    data[1925] = -'sd96711;
    data[1926] =  'sd98169;
    data[1927] = -'sd78296;
    data[1928] =  'sd6946;
    data[1929] =  'sd35725;
    data[1930] =  'sd112843;
    data[1931] = -'sd112033;
    data[1932] =  'sd12026;
    data[1933] = -'sd23903;
    data[1934] =  'sd75371;
    data[1935] = -'sd48357;
    data[1936] =  'sd48807;
    data[1937] =  'sd34443;
    data[1938] = -'sd124327;
    data[1939] = -'sd13651;
    data[1940] = -'sd26865;
    data[1941] =  'sd27115;
    data[1942] =  'sd19135;
    data[1943] =  'sd41977;
    data[1944] =  'sd20178;
    data[1945] = -'sd14925;
    data[1946] = -'sd12698;
    data[1947] = -'sd100417;
    data[1948] = -'sd87727;
    data[1949] =  'sd11210;
    data[1950] =  'sd74994;
    data[1951] = -'sd118102;
    data[1952] = -'sd111311;
    data[1953] = -'sd104261;
    data[1954] = -'sd49296;
    data[1955] = -'sd124908;
    data[1956] = -'sd121136;
    data[1957] =  'sd76970;
    data[1958] = -'sd2399;
    data[1959] =  'sd55899;
    data[1960] =  'sd97178;
    data[1961] = -'sd11774;
    data[1962] =  'sd70523;
    data[1963] =  'sd54191;
    data[1964] =  'sd31055;
    data[1965] = -'sd1536;
    data[1966] = -'sd34303;
    data[1967] = -'sd99630;
    data[1968] =  'sd57868;
    data[1969] = -'sd38271;
    data[1970] = -'sd84139;
    data[1971] = -'sd74581;
    data[1972] = -'sd55350;
    data[1973] =  'sd4387;
    data[1974] =  'sd62024;
    data[1975] = -'sd18982;
    data[1976] = -'sd13672;
    data[1977] = -'sd30750;
    data[1978] =  'sd57961;
    data[1979] = -'sd21066;
    data[1980] =  'sd100502;
    data[1981] =  'sd103452;
    data[1982] = -'sd100369;
    data[1983] = -'sd78847;
    data[1984] = -'sd94989;
    data[1985] = -'sd82975;
    data[1986] = -'sd109098;
    data[1987] =  'sd55287;
    data[1988] = -'sd16042;
    data[1989] =  'sd30514;
    data[1990] = -'sd101621;
    data[1991] = -'sd60610;
    data[1992] =  'sd30715;
    data[1993] = -'sd64436;
    data[1994] =  'sd72476;
    data[1995] = -'sd84218;
    data[1996] = -'sd89196;
    data[1997] = -'sd10698;
    data[1998] =  'sd19726;
    data[1999] = -'sd98545;
    data[2000] =  'sd8736;
    data[2001] =  'sd117018;
    data[2002] = -'sd89229;
    data[2003] = -'sd16803;
    data[2004] = -'sd110271;
    data[2005] =  'sd88139;
    data[2006] =  'sd65010;
    data[2007] =  'sd33714;
    data[2008] = -'sd9335;
    data[2009] =  'sd22024;
    data[2010] =  'sd76728;
    data[2011] = -'sd47169;
    data[2012] =  'sd18730;
    data[2013] = -'sd32948;
    data[2014] = -'sd98812;
    data[2015] = -'sd40659;
    data[2016] = -'sd26205;
    data[2017] = -'sd100642;
    data[2018] =  'sd120505;
    data[2019] =  'sd56152;
    data[2020] = -'sd105874;
    data[2021] = -'sd97844;
    data[2022] = -'sd111436;
    data[2023] =  'sd122471;
    data[2024] = -'sd79852;
    data[2025] = -'sd31057;
    data[2026] =  'sd1166;
    data[2027] = -'sd34147;
    data[2028] = -'sd70770;
    data[2029] = -'sd99886;
    data[2030] =  'sd10508;
    data[2031] = -'sd54876;
    data[2032] =  'sd92077;
    data[2033] =  'sd43969;
    data[2034] = -'sd111016;
    data[2035] = -'sd49686;
    data[2036] =  'sd52799;
    data[2037] =  'sd23392;
    data[2038] =  'sd79951;
    data[2039] =  'sd49372;
    data[2040] = -'sd110889;
    data[2041] = -'sd26191;
    data[2042] = -'sd98052;
    data[2043] =  'sd99941;
    data[2044] = -'sd333;
    data[2045] = -'sd61605;
    data[2046] =  'sd96497;
    data[2047] =  'sd112098;
  end

endmodule

