module ntt653_4621_by_163841_249857 ( clk, rst, start, input_fg, addr, din, dout, valid );

  localparam Q0 = 4621;
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
  input             [10 : 0] addr;
  input signed      [12 : 0] din;
  output reg signed [12 : 0] dout;
  output reg                 valid;

  // BRAM
  // Notice: This RTL applies CRT to handle the unfriendliness of 4621.
  //         d[17: 0] for q1 = 163841 in wr_din/rd_dout/wr_dout
  //         d[35:18] for q2 = 249857 in wr_din/rd_dout/wr_dout
  reg            wr_en   [0 : 1];
  reg   [10 : 0] wr_addr [0 : 1];
  reg   [10 : 0] rd_addr [0 : 1];
  reg   [35 : 0] wr_din  [0 : 1];
  wire  [35 : 0] rd_dout [0 : 1];
  wire  [35 : 0] wr_dout [0 : 1];

  // addr_gen
  wire         bank_index_rd [0 : 1];
  wire         bank_index_wr [0 : 1];
  wire [9 : 0] data_index_rd [0 : 1];
  wire [9 : 0] data_index_wr [0 : 1];
  reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;
  reg  fg_shift_1, fg_shift_2, fg_shift_3;

  // w_addr_gen
  reg  [9  : 0] stage_bit;
  wire [9  : 0] w_addr;

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
  reg  [11 : 0] ctr;
  reg  [11 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_1, ctr_shift_2;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, stage_rd_end, stage_rd_2, stage_wr_end, ntt_end, point_proc_end, reduce_end;

  // w_array
  reg         [10: 0] w_addr_in;
  wire signed [17: 0] w_dout [0:1];

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [10: 0] wr_ctr [0 : 1];
  reg [12: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [10: 0] w_addr_in_shift_1;

  // crt
  reg  signed [17:0] in_b_1 [0:1];
  reg  signed [19:0] in_b_sum;
  reg  signed [36:0] bw_sum;
  wire signed [36:0] bw_sum_ALL;
  wire signed [36:0] qproduct_ALL;
  reg  signed [35:0] bw_sum_mod;
  wire signed [12:0] mod4621_out;

  // BRAM instances
  bram_36_11_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_36_11_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[9:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[9:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[9:0], w_addr);

  // Butterfly Unit s , each with a corresponding omega array
  bfu_163841 bfu_inst0 (clk, ntt_state, in_a[0], in_b[0], in_w[0], bw[0], out_a[0], out_b[0]);
  w_163841 rom_w_inst0 (clk, w_addr_in_shift_1, w_dout[0]);
  bfu_249857 bfu_inst1 (clk, ntt_state, in_a[1], in_b[1], in_w[1], bw[1], out_a[1], out_b[1]);
  w_249857 rom_w_inst1 (clk, w_addr_in_shift_1, w_dout[1]);

  // MOD 4621 (Note: manual optimization for this part may be necessary.)
  mod4621S33 mod_q0_inst ( clk, rst, { bw_sum_mod[35], bw_sum_mod[31:0] }, mod4621_out);

  assign ctr_half_end         = (ctr[9:0] == 1023) ? 1 : 0;
  assign ctr_full_end         = (ctr[10:0] == 2047) ? 1 : 0;
  assign stage_rd_end         = (stage == 11) ? 1 : 0;
  assign stage_rd_2           = (stage == 2) ? 1 : 0;
  assign ntt_end         = (stage_rd_end && ctr[9 : 0] == 10) ? 1 : 0;
  assign crt_end         = (stage_rd_2 && ctr[9 : 0] == 10) ? 1 : 0;
  assign point_proc_end   = (ctr == 2058) ? 1 : 0;
  assign reload_end      = (stage != 0 && ctr[9:0] == 4) ? 1 : 0;
  assign reduce_end      = (ctr == 2052);

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
        rd_addr[0][9:0] <= data_index_rd[1];
        rd_addr[1][9:0] <= data_index_rd[0];
      end else begin
        rd_addr[0][9:0] <= data_index_rd[0];
        rd_addr[1][9:0] <= data_index_rd[1];
      end
    end else begin
      rd_addr[0][9:0] <= data_index_rd[0];
      rd_addr[1][9:0] <= data_index_rd[0];
    end

    if (state == ST_NTT)  begin
      rd_addr[0][10] <= poly_select;
      rd_addr[1][10] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][10] <=  bank_index_rd[0];
      rd_addr[1][10] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][10] <= 0;
      rd_addr[1][10] <= 0;
    end else begin
      rd_addr[0][10] <= 1;
      rd_addr[1][10] <= 1;
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
        wr_addr[0][9:0] <= data_index_wr[1];
        wr_addr[1][9:0] <= data_index_wr[0];
      end else begin
        wr_addr[0][9:0] <= data_index_wr[0];
        wr_addr[1][9:0] <= data_index_wr[1];
      end
    end else begin
      wr_addr[0][9:0] <= data_index_wr[0];
      wr_addr[1][9:0] <= data_index_wr[0];
    end  

    if (state == ST_IDLE) begin
      wr_addr[0][10] <= fg_shift_3;
      wr_addr[1][10] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][10] <= poly_select;
      wr_addr[1][10] <= poly_select;
    end else if (state == ST_PMUL || state == ST_REDUCE || state == ST_FINISH) begin
      wr_addr[0][10] <= 0;
      wr_addr[1][10] <= 0;
    end else begin
      wr_addr[0][10] <= 1;
      wr_addr[1][10] <= 1;
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
        wr_din[0][17:0] <= mod4621_out;
        wr_din[1][17:0] <= mod4621_out;
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
        wr_din[0][35:18] <= mod4621_out;
        wr_din[1][35:18] <= mod4621_out;
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
      w_addr_in <= 2048 - w_addr;
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
      wr_ctr[0] <= addr[10:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7], ctr_shift_1[8], ctr_shift_1[9], ctr_shift_1[10]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[9:0]};
    end else begin
      wr_ctr[0] <= ctr_shift_7[10:0];
    end

    wr_ctr[1] <= {1'b1, ctr_shift_7[9:0]};
  end

  // ctr_MSB_masked
  always @ (*) begin
    if (state == ST_NTT || state == ST_INTT) begin
      ctr_MSB_masked = 0;
    end else begin
      ctr_MSB_masked = ctr[10];
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
      end else if (ctr_shift_7[9:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[10:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[10:0] == 0 && stage != 0) begin
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
        stage_bit[9 : 1] <= stage_bit[8 : 0];
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
  input      [ 9: 0] stage_bit;
  input      [ 9: 0] ctr;
  output reg [ 9: 0] w_addr;

  wire [ 9: 0] w;

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

  always @ ( posedge clk ) begin
    w_addr <= {w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9]};
  end

endmodule

module addr_gen ( clk, stage, ctr, bank_index, data_index );

  input              clk;
  input      [3 : 0] stage;
  input      [10: 0] ctr;
  output reg         bank_index;
  output reg [9 : 0] data_index;

  wire       [10: 0] bs_out;

  barrel_shifter bs ( clk, ctr, stage, bs_out );

    always @( posedge clk ) begin
        bank_index <= ^bs_out;
    end

    always @( posedge clk ) begin
        data_index <= bs_out[10:1];
    end

endmodule

module barrel_shifter ( clk, in, shift, out );

  input              clk;
  input      [10: 0] in;
  input      [3 : 0] shift;
  output reg [10: 0] out;

  reg        [10: 0] in_s [0:4];

  always @ (*) begin
    in_s[0] = in;
  end

  always @ (*) begin
    if(shift[0]) begin
      in_s[1] = { in_s[0][0], in_s[0][10:1] };
    end else begin
      in_s[1] = in_s[0];
    end
  end

  always @ (*) begin
    if(shift[1]) begin
      in_s[2] = { in_s[1][1:0], in_s[1][10:2] };
    end else begin
      in_s[2] = in_s[1];
    end
  end

  always @ (*) begin
    if(shift[2]) begin
      in_s[3] = { in_s[2][3:0], in_s[2][10:4] };
    end else begin
      in_s[3] = in_s[2];
    end
  end

  always @ (*) begin
    if(shift[3]) begin
      in_s[4] = { in_s[3][7:0], in_s[3][10:8] };
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
  input             [10 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [10 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [17:0] data [0:1023];

  assign dout_p = data[addr_reg[9:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[10] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[   0] =  'sd1;
    data[   1] =  'sd171;
    data[   2] =  'sd29241;
    data[   3] = -'sd78860;
    data[   4] = -'sd50098;
    data[   5] = -'sd47026;
    data[   6] = -'sd13237;
    data[   7] =  'sd30247;
    data[   8] = -'sd70675;
    data[   9] =  'sd38809;
    data[  10] = -'sd81142;
    data[  11] =  'sd51203;
    data[  12] =  'sd72140;
    data[  13] =  'sd47865;
    data[  14] = -'sd7135;
    data[  15] = -'sd73198;
    data[  16] = -'sd64942;
    data[  17] =  'sd36106;
    data[  18] = -'sd51832;
    data[  19] = -'sd15858;
    data[  20] =  'sd73579;
    data[  21] = -'sd33748;
    data[  22] = -'sd36473;
    data[  23] = -'sd10925;
    data[  24] = -'sd65924;
    data[  25] =  'sd32025;
    data[  26] =  'sd69522;
    data[  27] = -'sd72131;
    data[  28] = -'sd46326;
    data[  29] = -'sd57378;
    data[  30] =  'sd18822;
    data[  31] = -'sd58258;
    data[  32] =  'sd32183;
    data[  33] = -'sd67301;
    data[  34] = -'sd39601;
    data[  35] = -'sd54290;
    data[  36] =  'sd55347;
    data[  37] = -'sd38441;
    data[  38] = -'sd19771;
    data[  39] =  'sd59820;
    data[  40] =  'sd71078;
    data[  41] =  'sd30104;
    data[  42] =  'sd68713;
    data[  43] = -'sd46629;
    data[  44] =  'sd54650;
    data[  45] =  'sd6213;
    data[  46] =  'sd79377;
    data[  47] = -'sd25336;
    data[  48] = -'sd72590;
    data[  49] =  'sd39026;
    data[  50] = -'sd44035;
    data[  51] =  'sd6701;
    data[  52] = -'sd1016;
    data[  53] = -'sd9895;
    data[  54] = -'sd53635;
    data[  55] =  'sd3511;
    data[  56] = -'sd54983;
    data[  57] = -'sd63156;
    data[  58] =  'sd13830;
    data[  59] =  'sd71156;
    data[  60] =  'sd43442;
    data[  61] =  'sd55737;
    data[  62] =  'sd28249;
    data[  63] =  'sd79190;
    data[  64] = -'sd57313;
    data[  65] =  'sd29937;
    data[  66] =  'sd40156;
    data[  67] = -'sd14646;
    data[  68] = -'sd46851;
    data[  69] =  'sd16688;
    data[  70] =  'sd68351;
    data[  71] =  'sd55310;
    data[  72] = -'sd44768;
    data[  73] =  'sd45199;
    data[  74] =  'sd28502;
    data[  75] = -'sd41388;
    data[  76] = -'sd32185;
    data[  77] =  'sd66959;
    data[  78] = -'sd18881;
    data[  79] =  'sd48169;
    data[  80] =  'sd44849;
    data[  81] = -'sd31348;
    data[  82] =  'sd46245;
    data[  83] =  'sd43527;
    data[  84] =  'sd70272;
    data[  85] =  'sd56119;
    data[  86] = -'sd70270;
    data[  87] = -'sd55777;
    data[  88] = -'sd35089;
    data[  89] =  'sd61898;
    data[  90] = -'sd65107;
    data[  91] =  'sd7891;
    data[  92] =  'sd38633;
    data[  93] =  'sd52603;
    data[  94] = -'sd16142;
    data[  95] =  'sd25015;
    data[  96] =  'sd17699;
    data[  97] =  'sd77391;
    data[  98] = -'sd37260;
    data[  99] =  'sd18339;
    data[ 100] =  'sd22990;
    data[ 101] = -'sd894;
    data[ 102] =  'sd10967;
    data[ 103] =  'sd73106;
    data[ 104] =  'sd49210;
    data[ 105] =  'sd59019;
    data[ 106] = -'sd65893;
    data[ 107] =  'sd37326;
    data[ 108] = -'sd7053;
    data[ 109] = -'sd59176;
    data[ 110] =  'sd39046;
    data[ 111] = -'sd40615;
    data[ 112] = -'sd63843;
    data[ 113] =  'sd60194;
    data[ 114] = -'sd28809;
    data[ 115] = -'sd11109;
    data[ 116] =  'sd66453;
    data[ 117] =  'sd58434;
    data[ 118] = -'sd2087;
    data[ 119] = -'sd29195;
    data[ 120] = -'sd77115;
    data[ 121] = -'sd79385;
    data[ 122] =  'sd23968;
    data[ 123] =  'sd2503;
    data[ 124] = -'sd63510;
    data[ 125] = -'sd46704;
    data[ 126] =  'sd41825;
    data[ 127] = -'sd56929;
    data[ 128] = -'sd68240;
    data[ 129] = -'sd36329;
    data[ 130] =  'sd13699;
    data[ 131] =  'sd48755;
    data[ 132] = -'sd18786;
    data[ 133] =  'sd64414;
    data[ 134] =  'sd37447;
    data[ 135] =  'sd13638;
    data[ 136] =  'sd38324;
    data[ 137] = -'sd236;
    data[ 138] = -'sd40356;
    data[ 139] = -'sd19554;
    data[ 140] = -'sd66914;
    data[ 141] =  'sd26576;
    data[ 142] = -'sd43052;
    data[ 143] =  'sd10953;
    data[ 144] =  'sd70712;
    data[ 145] = -'sd32482;
    data[ 146] =  'sd16172;
    data[ 147] = -'sd19885;
    data[ 148] =  'sd40326;
    data[ 149] =  'sd14424;
    data[ 150] =  'sd8889;
    data[ 151] =  'sd45450;
    data[ 152] =  'sd71423;
    data[ 153] = -'sd74742;
    data[ 154] = -'sd1284;
    data[ 155] = -'sd55723;
    data[ 156] = -'sd25855;
    data[ 157] =  'sd2502;
    data[ 158] = -'sd63681;
    data[ 159] = -'sd75945;
    data[ 160] = -'sd43156;
    data[ 161] = -'sd6831;
    data[ 162] = -'sd21214;
    data[ 163] = -'sd23092;
    data[ 164] = -'sd16548;
    data[ 165] = -'sd44411;
    data[ 166] = -'sd57595;
    data[ 167] = -'sd18285;
    data[ 168] = -'sd13756;
    data[ 169] = -'sd58502;
    data[ 170] = -'sd9541;
    data[ 171] =  'sd6899;
    data[ 172] =  'sd32842;
    data[ 173] =  'sd45388;
    data[ 174] =  'sd60821;
    data[ 175] =  'sd78408;
    data[ 176] = -'sd27194;
    data[ 177] = -'sd62626;
    data[ 178] = -'sd59381;
    data[ 179] =  'sd3991;
    data[ 180] =  'sd27097;
    data[ 181] =  'sd46039;
    data[ 182] =  'sd8301;
    data[ 183] = -'sd55098;
    data[ 184] =  'sd81020;
    data[ 185] = -'sd72065;
    data[ 186] = -'sd35040;
    data[ 187] =  'sd70277;
    data[ 188] =  'sd56974;
    data[ 189] =  'sd75935;
    data[ 190] =  'sd41446;
    data[ 191] =  'sd42103;
    data[ 192] = -'sd9391;
    data[ 193] =  'sd32549;
    data[ 194] = -'sd4715;
    data[ 195] =  'sd12940;
    data[ 196] = -'sd81034;
    data[ 197] =  'sd69671;
    data[ 198] = -'sd46652;
    data[ 199] =  'sd50717;
    data[ 200] = -'sd10966;
    data[ 201] = -'sd72935;
    data[ 202] = -'sd19969;
    data[ 203] =  'sd25962;
    data[ 204] =  'sd15795;
    data[ 205] =  'sd79489;
    data[ 206] = -'sd6184;
    data[ 207] = -'sd74418;
    data[ 208] =  'sd54120;
    data[ 209] =  'sd79424;
    data[ 210] = -'sd17299;
    data[ 211] = -'sd8991;
    data[ 212] = -'sd62892;
    data[ 213] =  'sd58974;
    data[ 214] = -'sd73588;
    data[ 215] =  'sd32209;
    data[ 216] = -'sd62855;
    data[ 217] =  'sd65301;
    data[ 218] =  'sd25283;
    data[ 219] =  'sd63527;
    data[ 220] =  'sd49611;
    data[ 221] = -'sd36251;
    data[ 222] =  'sd27037;
    data[ 223] =  'sd35779;
    data[ 224] =  'sd56092;
    data[ 225] = -'sd74887;
    data[ 226] = -'sd26079;
    data[ 227] = -'sd35802;
    data[ 228] = -'sd60025;
    data[ 229] =  'sd57708;
    data[ 230] =  'sd37608;
    data[ 231] =  'sd41169;
    data[ 232] = -'sd5264;
    data[ 233] = -'sd80939;
    data[ 234] = -'sd77925;
    data[ 235] = -'sd54054;
    data[ 236] = -'sd68138;
    data[ 237] = -'sd18887;
    data[ 238] =  'sd47143;
    data[ 239] =  'sd33244;
    data[ 240] = -'sd49711;
    data[ 241] =  'sd19151;
    data[ 242] = -'sd1999;
    data[ 243] = -'sd14147;
    data[ 244] =  'sd38478;
    data[ 245] =  'sd26098;
    data[ 246] =  'sd39051;
    data[ 247] = -'sd39760;
    data[ 248] = -'sd81479;
    data[ 249] = -'sd6424;
    data[ 250] =  'sd48383;
    data[ 251] =  'sd81443;
    data[ 252] =  'sd268;
    data[ 253] =  'sd45828;
    data[ 254] = -'sd27780;
    data[ 255] =  'sd1009;
    data[ 256] =  'sd8698;
    data[ 257] =  'sd12789;
    data[ 258] =  'sd56986;
    data[ 259] =  'sd77987;
    data[ 260] =  'sd64656;
    data[ 261] =  'sd78829;
    data[ 262] =  'sd44797;
    data[ 263] = -'sd40240;
    data[ 264] =  'sd282;
    data[ 265] =  'sd48222;
    data[ 266] =  'sd53912;
    data[ 267] =  'sd43856;
    data[ 268] = -'sd37310;
    data[ 269] =  'sd9789;
    data[ 270] =  'sd35509;
    data[ 271] =  'sd9922;
    data[ 272] =  'sd58252;
    data[ 273] = -'sd33209;
    data[ 274] =  'sd55696;
    data[ 275] =  'sd21238;
    data[ 276] =  'sd27196;
    data[ 277] =  'sd62968;
    data[ 278] = -'sd45978;
    data[ 279] =  'sd2130;
    data[ 280] =  'sd36548;
    data[ 281] =  'sd23750;
    data[ 282] = -'sd34775;
    data[ 283] = -'sd48249;
    data[ 284] = -'sd58529;
    data[ 285] = -'sd14158;
    data[ 286] =  'sd36597;
    data[ 287] =  'sd32129;
    data[ 288] = -'sd76535;
    data[ 289] =  'sd19795;
    data[ 290] = -'sd55716;
    data[ 291] = -'sd24658;
    data[ 292] =  'sd43348;
    data[ 293] =  'sd39663;
    data[ 294] =  'sd64892;
    data[ 295] = -'sd44656;
    data[ 296] =  'sd64351;
    data[ 297] =  'sd26674;
    data[ 298] = -'sd26294;
    data[ 299] = -'sd72567;
    data[ 300] =  'sd42959;
    data[ 301] = -'sd26856;
    data[ 302] = -'sd4828;
    data[ 303] = -'sd6383;
    data[ 304] =  'sd55394;
    data[ 305] = -'sd30404;
    data[ 306] =  'sd43828;
    data[ 307] = -'sd42098;
    data[ 308] =  'sd10246;
    data[ 309] = -'sd50185;
    data[ 310] = -'sd61903;
    data[ 311] =  'sd64252;
    data[ 312] =  'sd9745;
    data[ 313] =  'sd27985;
    data[ 314] =  'sd34046;
    data[ 315] = -'sd76410;
    data[ 316] =  'sd41170;
    data[ 317] = -'sd5093;
    data[ 318] = -'sd51698;
    data[ 319] =  'sd7056;
    data[ 320] =  'sd59689;
    data[ 321] =  'sd48677;
    data[ 322] = -'sd32124;
    data[ 323] =  'sd77390;
    data[ 324] = -'sd37431;
    data[ 325] = -'sd10902;
    data[ 326] = -'sd61991;
    data[ 327] =  'sd49204;
    data[ 328] =  'sd57993;
    data[ 329] = -'sd77498;
    data[ 330] =  'sd18963;
    data[ 331] = -'sd34147;
    data[ 332] =  'sd59139;
    data[ 333] = -'sd45373;
    data[ 334] = -'sd58256;
    data[ 335] =  'sd32525;
    data[ 336] = -'sd8819;
    data[ 337] = -'sd33480;
    data[ 338] =  'sd9355;
    data[ 339] = -'sd38705;
    data[ 340] = -'sd64915;
    data[ 341] =  'sd40723;
    data[ 342] = -'sd81530;
    data[ 343] = -'sd15145;
    data[ 344] =  'sd31661;
    data[ 345] =  'sd7278;
    data[ 346] = -'sd66190;
    data[ 347] = -'sd13461;
    data[ 348] = -'sd8057;
    data[ 349] = -'sd67019;
    data[ 350] =  'sd8621;
    data[ 351] = -'sd378;
    data[ 352] = -'sd64638;
    data[ 353] = -'sd75751;
    data[ 354] = -'sd9982;
    data[ 355] = -'sd68512;
    data[ 356] =  'sd81000;
    data[ 357] = -'sd75485;
    data[ 358] =  'sd35504;
    data[ 359] =  'sd9067;
    data[ 360] =  'sd75888;
    data[ 361] =  'sd33409;
    data[ 362] = -'sd21496;
    data[ 363] = -'sd71314;
    data[ 364] = -'sd70460;
    data[ 365] =  'sd75574;
    data[ 366] = -'sd20285;
    data[ 367] = -'sd28074;
    data[ 368] = -'sd49265;
    data[ 369] = -'sd68424;
    data[ 370] = -'sd67793;
    data[ 371] =  'sd40108;
    data[ 372] = -'sd22854;
    data[ 373] =  'sd24150;
    data[ 374] =  'sd33625;
    data[ 375] =  'sd15440;
    data[ 376] =  'sd18784;
    data[ 377] = -'sd64756;
    data[ 378] =  'sd67912;
    data[ 379] = -'sd19759;
    data[ 380] =  'sd61872;
    data[ 381] = -'sd69553;
    data[ 382] =  'sd66830;
    data[ 383] = -'sd40940;
    data[ 384] =  'sd44423;
    data[ 385] =  'sd59647;
    data[ 386] =  'sd41495;
    data[ 387] =  'sd50482;
    data[ 388] = -'sd51151;
    data[ 389] = -'sd63248;
    data[ 390] = -'sd1902;
    data[ 391] =  'sd2440;
    data[ 392] = -'sd74283;
    data[ 393] =  'sd77205;
    data[ 394] = -'sd69066;
    data[ 395] = -'sd13734;
    data[ 396] = -'sd54740;
    data[ 397] = -'sd21603;
    data[ 398] =  'sd74230;
    data[ 399] =  'sd77573;
    data[ 400] = -'sd6138;
    data[ 401] = -'sd66552;
    data[ 402] = -'sd75363;
    data[ 403] =  'sd56366;
    data[ 404] = -'sd28033;
    data[ 405] = -'sd42254;
    data[ 406] = -'sd16430;
    data[ 407] = -'sd24233;
    data[ 408] = -'sd47818;
    data[ 409] =  'sd15172;
    data[ 410] = -'sd27044;
    data[ 411] = -'sd36976;
    data[ 412] =  'sd66903;
    data[ 413] = -'sd28457;
    data[ 414] =  'sd49083;
    data[ 415] =  'sd37302;
    data[ 416] = -'sd11157;
    data[ 417] =  'sd58245;
    data[ 418] = -'sd34406;
    data[ 419] =  'sd14850;
    data[ 420] =  'sd81735;
    data[ 421] =  'sd50200;
    data[ 422] =  'sd64468;
    data[ 423] =  'sd46681;
    data[ 424] = -'sd45758;
    data[ 425] =  'sd39750;
    data[ 426] =  'sd79769;
    data[ 427] =  'sd41696;
    data[ 428] = -'sd78988;
    data[ 429] = -'sd71986;
    data[ 430] = -'sd21531;
    data[ 431] = -'sd77299;
    data[ 432] =  'sd52992;
    data[ 433] =  'sd50377;
    data[ 434] = -'sd69106;
    data[ 435] = -'sd20574;
    data[ 436] = -'sd77493;
    data[ 437] =  'sd19818;
    data[ 438] = -'sd51783;
    data[ 439] = -'sd7479;
    data[ 440] =  'sd31819;
    data[ 441] =  'sd34296;
    data[ 442] = -'sd33660;
    data[ 443] = -'sd21425;
    data[ 444] = -'sd59173;
    data[ 445] =  'sd39559;
    data[ 446] =  'sd47108;
    data[ 447] =  'sd27259;
    data[ 448] =  'sd73741;
    data[ 449] = -'sd6046;
    data[ 450] = -'sd50820;
    data[ 451] = -'sd6647;
    data[ 452] =  'sd10250;
    data[ 453] = -'sd49501;
    data[ 454] =  'sd55061;
    data[ 455] =  'sd76494;
    data[ 456] = -'sd26806;
    data[ 457] =  'sd3722;
    data[ 458] = -'sd18902;
    data[ 459] =  'sd44578;
    data[ 460] = -'sd77689;
    data[ 461] = -'sd13698;
    data[ 462] = -'sd48584;
    data[ 463] =  'sd48027;
    data[ 464] =  'sd20567;
    data[ 465] =  'sd76296;
    data[ 466] = -'sd60664;
    data[ 467] = -'sd51561;
    data[ 468] =  'sd30483;
    data[ 469] = -'sd30319;
    data[ 470] =  'sd58363;
    data[ 471] = -'sd14228;
    data[ 472] =  'sd24627;
    data[ 473] = -'sd48649;
    data[ 474] =  'sd36912;
    data[ 475] = -'sd77847;
    data[ 476] = -'sd40716;
    data[ 477] = -'sd81114;
    data[ 478] =  'sd55991;
    data[ 479] =  'sd71683;
    data[ 480] = -'sd30282;
    data[ 481] =  'sd64690;
    data[ 482] = -'sd79198;
    data[ 483] =  'sd55945;
    data[ 484] =  'sd63817;
    data[ 485] = -'sd64640;
    data[ 486] = -'sd76093;
    data[ 487] = -'sd68464;
    data[ 488] = -'sd74633;
    data[ 489] =  'sd17355;
    data[ 490] =  'sd18567;
    data[ 491] =  'sd61978;
    data[ 492] = -'sd51427;
    data[ 493] =  'sd53397;
    data[ 494] = -'sd44209;
    data[ 495] = -'sd23053;
    data[ 496] = -'sd9879;
    data[ 497] = -'sd50899;
    data[ 498] = -'sd20156;
    data[ 499] = -'sd6015;
    data[ 500] = -'sd45519;
    data[ 501] =  'sd80619;
    data[ 502] =  'sd23205;
    data[ 503] =  'sd35871;
    data[ 504] =  'sd71824;
    data[ 505] = -'sd6171;
    data[ 506] = -'sd72195;
    data[ 507] = -'sd57270;
    data[ 508] =  'sd37290;
    data[ 509] = -'sd13209;
    data[ 510] =  'sd35035;
    data[ 511] = -'sd71132;
    data[ 512] = -'sd39338;
    data[ 513] = -'sd9317;
    data[ 514] =  'sd45203;
    data[ 515] =  'sd29186;
    data[ 516] =  'sd75576;
    data[ 517] = -'sd19943;
    data[ 518] =  'sd30408;
    data[ 519] = -'sd43144;
    data[ 520] = -'sd4779;
    data[ 521] =  'sd1996;
    data[ 522] =  'sd13634;
    data[ 523] =  'sd37640;
    data[ 524] =  'sd46641;
    data[ 525] = -'sd52598;
    data[ 526] =  'sd16997;
    data[ 527] = -'sd42651;
    data[ 528] =  'sd79524;
    data[ 529] = -'sd199;
    data[ 530] = -'sd34029;
    data[ 531] =  'sd79317;
    data[ 532] = -'sd35596;
    data[ 533] = -'sd24799;
    data[ 534] =  'sd19237;
    data[ 535] =  'sd12707;
    data[ 536] =  'sd42964;
    data[ 537] = -'sd26001;
    data[ 538] = -'sd22464;
    data[ 539] = -'sd73001;
    data[ 540] = -'sd31255;
    data[ 541] =  'sd62148;
    data[ 542] = -'sd22357;
    data[ 543] = -'sd54704;
    data[ 544] = -'sd15447;
    data[ 545] = -'sd19981;
    data[ 546] =  'sd23910;
    data[ 547] = -'sd7415;
    data[ 548] =  'sd42763;
    data[ 549] = -'sd60372;
    data[ 550] = -'sd1629;
    data[ 551] =  'sd49123;
    data[ 552] =  'sd44142;
    data[ 553] =  'sd11596;
    data[ 554] =  'sd16824;
    data[ 555] = -'sd72234;
    data[ 556] = -'sd63939;
    data[ 557] =  'sd43778;
    data[ 558] = -'sd50648;
    data[ 559] =  'sd22765;
    data[ 560] = -'sd39369;
    data[ 561] = -'sd14618;
    data[ 562] = -'sd42063;
    data[ 563] =  'sd16231;
    data[ 564] = -'sd9796;
    data[ 565] = -'sd36706;
    data[ 566] = -'sd50768;
    data[ 567] =  'sd2245;
    data[ 568] =  'sd56213;
    data[ 569] = -'sd54196;
    data[ 570] =  'sd71421;
    data[ 571] = -'sd75084;
    data[ 572] = -'sd59766;
    data[ 573] = -'sd61844;
    data[ 574] =  'sd74341;
    data[ 575] = -'sd67287;
    data[ 576] = -'sd37207;
    data[ 577] =  'sd27402;
    data[ 578] = -'sd65647;
    data[ 579] =  'sd79392;
    data[ 580] = -'sd22771;
    data[ 581] =  'sd38343;
    data[ 582] =  'sd3013;
    data[ 583] =  'sd23700;
    data[ 584] = -'sd43325;
    data[ 585] = -'sd35730;
    data[ 586] = -'sd47713;
    data[ 587] =  'sd33127;
    data[ 588] = -'sd69718;
    data[ 589] =  'sd38615;
    data[ 590] =  'sd49525;
    data[ 591] = -'sd50957;
    data[ 592] = -'sd30074;
    data[ 593] = -'sd63583;
    data[ 594] = -'sd59187;
    data[ 595] =  'sd37165;
    data[ 596] = -'sd34584;
    data[ 597] = -'sd15588;
    data[ 598] = -'sd44092;
    data[ 599] = -'sd3046;
    data[ 600] = -'sd29343;
    data[ 601] =  'sd61418;
    data[ 602] =  'sd16654;
    data[ 603] =  'sd62537;
    data[ 604] =  'sd44162;
    data[ 605] =  'sd15016;
    data[ 606] = -'sd53720;
    data[ 607] = -'sd11024;
    data[ 608] =  'sd80988;
    data[ 609] = -'sd77537;
    data[ 610] =  'sd12294;
    data[ 611] = -'sd27659;
    data[ 612] =  'sd21700;
    data[ 613] = -'sd57643;
    data[ 614] = -'sd26493;
    data[ 615] =  'sd57245;
    data[ 616] = -'sd41565;
    data[ 617] = -'sd62452;
    data[ 618] = -'sd29627;
    data[ 619] =  'sd12854;
    data[ 620] =  'sd68101;
    data[ 621] =  'sd12560;
    data[ 622] =  'sd17827;
    data[ 623] = -'sd64562;
    data[ 624] = -'sd62755;
    data[ 625] = -'sd81440;
    data[ 626] =  'sd245;
    data[ 627] =  'sd41895;
    data[ 628] = -'sd44959;
    data[ 629] =  'sd12538;
    data[ 630] =  'sd14065;
    data[ 631] = -'sd52500;
    data[ 632] =  'sd33755;
    data[ 633] =  'sd37670;
    data[ 634] =  'sd51771;
    data[ 635] =  'sd5427;
    data[ 636] = -'sd55029;
    data[ 637] = -'sd71022;
    data[ 638] = -'sd20528;
    data[ 639] = -'sd69627;
    data[ 640] =  'sd54176;
    data[ 641] = -'sd74841;
    data[ 642] = -'sd18213;
    data[ 643] = -'sd1444;
    data[ 644] =  'sd80758;
    data[ 645] =  'sd46974;
    data[ 646] =  'sd4345;
    data[ 647] = -'sd76210;
    data[ 648] =  'sd75370;
    data[ 649] = -'sd55169;
    data[ 650] =  'sd68879;
    data[ 651] = -'sd18243;
    data[ 652] = -'sd6574;
    data[ 653] =  'sd22733;
    data[ 654] = -'sd44841;
    data[ 655] =  'sd32716;
    data[ 656] =  'sd23842;
    data[ 657] = -'sd19043;
    data[ 658] =  'sd20467;
    data[ 659] =  'sd59196;
    data[ 660] = -'sd35626;
    data[ 661] = -'sd29929;
    data[ 662] = -'sd38788;
    data[ 663] = -'sd79108;
    data[ 664] =  'sd71335;
    data[ 665] =  'sd74051;
    data[ 666] =  'sd46964;
    data[ 667] =  'sd2635;
    data[ 668] = -'sd40938;
    data[ 669] =  'sd44765;
    data[ 670] = -'sd45712;
    data[ 671] =  'sd47616;
    data[ 672] = -'sd49714;
    data[ 673] =  'sd18638;
    data[ 674] =  'sd74119;
    data[ 675] =  'sd58592;
    data[ 676] =  'sd24931;
    data[ 677] =  'sd3335;
    data[ 678] =  'sd78762;
    data[ 679] =  'sd33340;
    data[ 680] = -'sd33295;
    data[ 681] =  'sd40990;
    data[ 682] = -'sd35873;
    data[ 683] = -'sd72166;
    data[ 684] = -'sd52311;
    data[ 685] =  'sd66074;
    data[ 686] = -'sd6375;
    data[ 687] =  'sd56762;
    data[ 688] =  'sd39683;
    data[ 689] =  'sd68312;
    data[ 690] =  'sd48641;
    data[ 691] = -'sd38280;
    data[ 692] =  'sd7760;
    data[ 693] =  'sd16232;
    data[ 694] = -'sd9625;
    data[ 695] = -'sd7465;
    data[ 696] =  'sd34213;
    data[ 697] = -'sd47853;
    data[ 698] =  'sd9187;
    data[ 699] = -'sd67433;
    data[ 700] = -'sd62173;
    data[ 701] =  'sd18082;
    data[ 702] = -'sd20957;
    data[ 703] =  'sd20855;
    data[ 704] = -'sd38297;
    data[ 705] =  'sd4853;
    data[ 706] =  'sd10658;
    data[ 707] =  'sd20267;
    data[ 708] =  'sd24996;
    data[ 709] =  'sd14450;
    data[ 710] =  'sd13335;
    data[ 711] = -'sd13489;
    data[ 712] = -'sd12845;
    data[ 713] = -'sd66562;
    data[ 714] = -'sd77073;
    data[ 715] = -'sd72203;
    data[ 716] = -'sd58638;
    data[ 717] = -'sd32797;
    data[ 718] = -'sd37693;
    data[ 719] = -'sd55704;
    data[ 720] = -'sd22606;
    data[ 721] =  'sd66558;
    data[ 722] =  'sd76389;
    data[ 723] = -'sd44761;
    data[ 724] =  'sd46396;
    data[ 725] =  'sd69348;
    data[ 726] =  'sd61956;
    data[ 727] = -'sd55189;
    data[ 728] =  'sd65459;
    data[ 729] =  'sd52301;
    data[ 730] = -'sd67784;
    data[ 731] =  'sd41647;
    data[ 732] =  'sd76474;
    data[ 733] = -'sd30226;
    data[ 734] =  'sd74266;
    data[ 735] = -'sd80112;
    data[ 736] =  'sd63492;
    data[ 737] =  'sd43626;
    data[ 738] = -'sd76640;
    data[ 739] =  'sd1840;
    data[ 740] = -'sd13042;
    data[ 741] =  'sd63592;
    data[ 742] =  'sd60726;
    data[ 743] =  'sd62163;
    data[ 744] = -'sd19792;
    data[ 745] =  'sd56229;
    data[ 746] = -'sd51460;
    data[ 747] =  'sd47754;
    data[ 748] = -'sd26116;
    data[ 749] = -'sd42129;
    data[ 750] =  'sd4945;
    data[ 751] =  'sd26390;
    data[ 752] = -'sd74858;
    data[ 753] = -'sd21120;
    data[ 754] = -'sd7018;
    data[ 755] = -'sd53191;
    data[ 756] =  'sd79435;
    data[ 757] = -'sd15418;
    data[ 758] = -'sd15022;
    data[ 759] =  'sd52694;
    data[ 760] = -'sd581;
    data[ 761] =  'sd64490;
    data[ 762] =  'sd50443;
    data[ 763] = -'sd57820;
    data[ 764] = -'sd56760;
    data[ 765] = -'sd39341;
    data[ 766] = -'sd9830;
    data[ 767] = -'sd42520;
    data[ 768] = -'sd61916;
    data[ 769] =  'sd62029;
    data[ 770] = -'sd42706;
    data[ 771] =  'sd70119;
    data[ 772] =  'sd29956;
    data[ 773] =  'sd43405;
    data[ 774] =  'sd49410;
    data[ 775] = -'sd70622;
    data[ 776] =  'sd47872;
    data[ 777] = -'sd5938;
    data[ 778] = -'sd32352;
    data[ 779] =  'sd38402;
    data[ 780] =  'sd13102;
    data[ 781] = -'sd53332;
    data[ 782] =  'sd55324;
    data[ 783] = -'sd42374;
    data[ 784] = -'sd36950;
    data[ 785] =  'sd71349;
    data[ 786] =  'sd76445;
    data[ 787] = -'sd35185;
    data[ 788] =  'sd45482;
    data[ 789] =  'sd76895;
    data[ 790] =  'sd41765;
    data[ 791] = -'sd67189;
    data[ 792] = -'sd20449;
    data[ 793] = -'sd56118;
    data[ 794] =  'sd70441;
    data[ 795] = -'sd78823;
    data[ 796] = -'sd43771;
    data[ 797] =  'sd51845;
    data[ 798] =  'sd18081;
    data[ 799] = -'sd21128;
    data[ 800] = -'sd8386;
    data[ 801] =  'sd40563;
    data[ 802] =  'sd54951;
    data[ 803] =  'sd57684;
    data[ 804] =  'sd33504;
    data[ 805] = -'sd5251;
    data[ 806] = -'sd78716;
    data[ 807] = -'sd25474;
    data[ 808] =  'sd67653;
    data[ 809] = -'sd64048;
    data[ 810] =  'sd25139;
    data[ 811] =  'sd38903;
    data[ 812] = -'sd65068;
    data[ 813] =  'sd14560;
    data[ 814] =  'sd32145;
    data[ 815] = -'sd73799;
    data[ 816] = -'sd3872;
    data[ 817] = -'sd6748;
    data[ 818] = -'sd7021;
    data[ 819] = -'sd53704;
    data[ 820] = -'sd8288;
    data[ 821] =  'sd57321;
    data[ 822] = -'sd28569;
    data[ 823] =  'sd29931;
    data[ 824] =  'sd39130;
    data[ 825] = -'sd26251;
    data[ 826] = -'sd65214;
    data[ 827] = -'sd10406;
    data[ 828] =  'sd22825;
    data[ 829] = -'sd29109;
    data[ 830] = -'sd62409;
    data[ 831] = -'sd22274;
    data[ 832] = -'sd40511;
    data[ 833] = -'sd46059;
    data[ 834] = -'sd11721;
    data[ 835] = -'sd38199;
    data[ 836] =  'sd21611;
    data[ 837] = -'sd72862;
    data[ 838] = -'sd7486;
    data[ 839] =  'sd30622;
    data[ 840] = -'sd6550;
    data[ 841] =  'sd26837;
    data[ 842] =  'sd1579;
    data[ 843] = -'sd57673;
    data[ 844] = -'sd31623;
    data[ 845] = -'sd780;
    data[ 846] =  'sd30461;
    data[ 847] = -'sd34081;
    data[ 848] =  'sd70425;
    data[ 849] = -'sd81559;
    data[ 850] = -'sd20104;
    data[ 851] =  'sd2877;
    data[ 852] =  'sd444;
    data[ 853] =  'sd75924;
    data[ 854] =  'sd39565;
    data[ 855] =  'sd48134;
    data[ 856] =  'sd38864;
    data[ 857] = -'sd71737;
    data[ 858] =  'sd21048;
    data[ 859] = -'sd5294;
    data[ 860] =  'sd77772;
    data[ 861] =  'sd27891;
    data[ 862] =  'sd17972;
    data[ 863] = -'sd39767;
    data[ 864] =  'sd81165;
    data[ 865] = -'sd47270;
    data[ 866] = -'sd54961;
    data[ 867] = -'sd59394;
    data[ 868] =  'sd1768;
    data[ 869] = -'sd25354;
    data[ 870] = -'sd75668;
    data[ 871] =  'sd4211;
    data[ 872] =  'sd64717;
    data[ 873] = -'sd74581;
    data[ 874] =  'sd26247;
    data[ 875] =  'sd64530;
    data[ 876] =  'sd57283;
    data[ 877] = -'sd35067;
    data[ 878] =  'sd65660;
    data[ 879] = -'sd77169;
    data[ 880] =  'sd75222;
    data[ 881] = -'sd80477;
    data[ 882] =  'sd1077;
    data[ 883] =  'sd20326;
    data[ 884] =  'sd35085;
    data[ 885] = -'sd62582;
    data[ 886] = -'sd51857;
    data[ 887] = -'sd20133;
    data[ 888] = -'sd2082;
    data[ 889] = -'sd28340;
    data[ 890] =  'sd69090;
    data[ 891] =  'sd17838;
    data[ 892] = -'sd62681;
    data[ 893] = -'sd68786;
    data[ 894] =  'sd34146;
    data[ 895] = -'sd59310;
    data[ 896] =  'sd16132;
    data[ 897] = -'sd26725;
    data[ 898] =  'sd17573;
    data[ 899] =  'sd55845;
    data[ 900] =  'sd46717;
    data[ 901] = -'sd39602;
    data[ 902] = -'sd54461;
    data[ 903] =  'sd26106;
    data[ 904] =  'sd40419;
    data[ 905] =  'sd30327;
    data[ 906] = -'sd56995;
    data[ 907] = -'sd79526;
    data[ 908] = -'sd143;
    data[ 909] = -'sd24453;
    data[ 910] =  'sd78403;
    data[ 911] = -'sd28049;
    data[ 912] = -'sd44990;
    data[ 913] =  'sd7237;
    data[ 914] = -'sd73201;
    data[ 915] = -'sd65455;
    data[ 916] = -'sd51617;
    data[ 917] =  'sd20907;
    data[ 918] = -'sd29405;
    data[ 919] =  'sd50816;
    data[ 920] =  'sd5963;
    data[ 921] =  'sd36627;
    data[ 922] =  'sd37259;
    data[ 923] = -'sd18510;
    data[ 924] = -'sd52231;
    data[ 925] =  'sd79754;
    data[ 926] =  'sd39131;
    data[ 927] = -'sd26080;
    data[ 928] = -'sd35973;
    data[ 929] =  'sd74575;
    data[ 930] = -'sd27273;
    data[ 931] = -'sd76135;
    data[ 932] = -'sd75646;
    data[ 933] =  'sd7973;
    data[ 934] =  'sd52655;
    data[ 935] = -'sd7250;
    data[ 936] =  'sd70978;
    data[ 937] =  'sd13004;
    data[ 938] = -'sd70090;
    data[ 939] = -'sd24997;
    data[ 940] = -'sd14621;
    data[ 941] = -'sd42576;
    data[ 942] = -'sd71492;
    data[ 943] =  'sd62943;
    data[ 944] = -'sd50253;
    data[ 945] = -'sd73531;
    data[ 946] =  'sd41956;
    data[ 947] = -'sd34528;
    data[ 948] = -'sd6012;
    data[ 949] = -'sd45006;
    data[ 950] =  'sd4501;
    data[ 951] = -'sd49534;
    data[ 952] =  'sd49418;
    data[ 953] = -'sd69254;
    data[ 954] = -'sd45882;
    data[ 955] =  'sd18546;
    data[ 956] =  'sd58387;
    data[ 957] = -'sd10124;
    data[ 958] =  'sd71047;
    data[ 959] =  'sd24803;
    data[ 960] = -'sd18553;
    data[ 961] = -'sd59584;
    data[ 962] = -'sd30722;
    data[ 963] = -'sd10550;
    data[ 964] = -'sd1799;
    data[ 965] =  'sd20053;
    data[ 966] = -'sd11598;
    data[ 967] = -'sd17166;
    data[ 968] =  'sd13752;
    data[ 969] =  'sd57818;
    data[ 970] =  'sd56418;
    data[ 971] = -'sd19141;
    data[ 972] =  'sd3709;
    data[ 973] = -'sd21125;
    data[ 974] = -'sd7873;
    data[ 975] = -'sd35555;
    data[ 976] = -'sd17788;
    data[ 977] =  'sd71231;
    data[ 978] =  'sd56267;
    data[ 979] = -'sd44962;
    data[ 980] =  'sd12025;
    data[ 981] = -'sd73658;
    data[ 982] =  'sd20239;
    data[ 983] =  'sd20208;
    data[ 984] =  'sd14907;
    data[ 985] = -'sd72359;
    data[ 986] =  'sd78527;
    data[ 987] = -'sd6845;
    data[ 988] = -'sd23608;
    data[ 989] =  'sd59057;
    data[ 990] = -'sd59395;
    data[ 991] =  'sd1597;
    data[ 992] = -'sd54595;
    data[ 993] =  'sd3192;
    data[ 994] =  'sd54309;
    data[ 995] = -'sd52098;
    data[ 996] = -'sd61344;
    data[ 997] = -'sd4000;
    data[ 998] = -'sd28636;
    data[ 999] =  'sd18474;
    data[1000] =  'sd46075;
    data[1001] =  'sd14457;
    data[1002] =  'sd14532;
    data[1003] =  'sd27357;
    data[1004] = -'sd73342;
    data[1005] =  'sd74275;
    data[1006] = -'sd78573;
    data[1007] = -'sd1021;
    data[1008] = -'sd10750;
    data[1009] = -'sd35999;
    data[1010] =  'sd70129;
    data[1011] =  'sd31666;
    data[1012] =  'sd8133;
    data[1013] =  'sd80015;
    data[1014] = -'sd80079;
    data[1015] =  'sd69135;
    data[1016] =  'sd25533;
    data[1017] = -'sd57564;
    data[1018] = -'sd12984;
    data[1019] =  'sd73510;
    data[1020] = -'sd45547;
    data[1021] =  'sd75831;
    data[1022] =  'sd23662;
    data[1023] = -'sd49823;
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
  input             [10 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [10 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [17:0] data [0:1023];

  assign dout_p = data[addr_reg[9:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[10] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[   0] =  'sd1;
    data[   1] =  'sd214;
    data[   2] =  'sd45796;
    data[   3] =  'sd55921;
    data[   4] = -'sd26042;
    data[   5] = -'sd76134;
    data[   6] = -'sd51971;
    data[   7] =  'sd121771;
    data[   8] =  'sd73866;
    data[   9] =  'sd66333;
    data[  10] = -'sd46587;
    data[  11] =  'sd24662;
    data[  12] =  'sd30671;
    data[  13] =  'sd67312;
    data[  14] = -'sd86938;
    data[  15] = -'sd115314;
    data[  16] =  'sd58647;
    data[  17] =  'sd57608;
    data[  18] =  'sd85119;
    data[  19] = -'sd24095;
    data[  20] =  'sd90667;
    data[  21] = -'sd86108;
    data[  22] =  'sd62306;
    data[  23] =  'sd91063;
    data[  24] = -'sd1364;
    data[  25] = -'sd42039;
    data[  26] = -'sd1494;
    data[  27] = -'sd69859;
    data[  28] =  'sd41594;
    data[  29] = -'sd93736;
    data[  30] = -'sd70944;
    data[  31] =  'sd59261;
    data[  32] = -'sd60853;
    data[  33] = -'sd29978;
    data[  34] =  'sd80990;
    data[  35] =  'sd91727;
    data[  36] = -'sd109125;
    data[  37] = -'sd116049;
    data[  38] = -'sd98643;
    data[  39] = -'sd121614;
    data[  40] = -'sd40268;
    data[  41] = -'sd122214;
    data[  42] =  'sd81189;
    data[  43] = -'sd115544;
    data[  44] =  'sd9427;
    data[  45] =  'sd18522;
    data[  46] = -'sd34004;
    data[  47] = -'sd31003;
    data[  48] =  'sd111497;
    data[  49] =  'sd123943;
    data[  50] =  'sd38960;
    data[  51] =  'sd92159;
    data[  52] = -'sd16677;
    data[  53] = -'sd70880;
    data[  54] =  'sd72957;
    data[  55] =  'sd121664;
    data[  56] =  'sd50968;
    data[  57] = -'sd86556;
    data[  58] = -'sd33566;
    data[  59] =  'sd62729;
    data[  60] = -'sd68272;
    data[  61] = -'sd118502;
    data[  62] = -'sd123871;
    data[  63] = -'sd23552;
    data[  64] = -'sd42988;
    data[  65] =  'sd45277;
    data[  66] = -'sd55145;
    data[  67] = -'sd57751;
    data[  68] = -'sd115721;
    data[  69] = -'sd28451;
    data[  70] = -'sd91946;
    data[  71] =  'sd62259;
    data[  72] =  'sd81005;
    data[  73] =  'sd94937;
    data[  74] =  'sd78101;
    data[  75] = -'sd26805;
    data[  76] =  'sd10441;
    data[  77] = -'sd14339;
    data[  78] = -'sd70262;
    data[  79] = -'sd44648;
    data[  80] = -'sd60106;
    data[  81] = -'sd119977;
    data[  82] =  'sd60193;
    data[  83] = -'sd111262;
    data[  84] = -'sd73653;
    data[  85] = -'sd20751;
    data[  86] =  'sd56712;
    data[  87] = -'sd106625;
    data[  88] = -'sd80763;
    data[  89] = -'sd43149;
    data[  90] =  'sd10823;
    data[  91] =  'sd67409;
    data[  92] = -'sd66180;
    data[  93] =  'sd79329;
    data[  94] = -'sd13870;
    data[  95] =  'sd30104;
    data[  96] = -'sd54026;
    data[  97] = -'sd68142;
    data[  98] = -'sd90682;
    data[  99] =  'sd82898;
    data[ 100] =  'sd325;
    data[ 101] =  'sd69550;
    data[ 102] = -'sd107720;
    data[ 103] = -'sd65236;
    data[ 104] =  'sd31488;
    data[ 105] = -'sd7707;
    data[ 106] =  'sd99701;
    data[ 107] =  'sd98169;
    data[ 108] =  'sd20178;
    data[ 109] =  'sd70523;
    data[ 110] =  'sd100502;
    data[ 111] =  'sd19726;
    data[ 112] = -'sd26205;
    data[ 113] = -'sd111016;
    data[ 114] = -'sd21009;
    data[ 115] =  'sd1500;
    data[ 116] =  'sd71143;
    data[ 117] = -'sd16675;
    data[ 118] = -'sd70452;
    data[ 119] = -'sd85308;
    data[ 120] = -'sd16351;
    data[ 121] = -'sd1116;
    data[ 122] =  'sd11033;
    data[ 123] =  'sd112349;
    data[ 124] =  'sd56414;
    data[ 125] =  'sd79460;
    data[ 126] =  'sd14164;
    data[ 127] =  'sd32812;
    data[ 128] =  'sd25772;
    data[ 129] =  'sd18354;
    data[ 130] = -'sd69956;
    data[ 131] =  'sd20836;
    data[ 132] = -'sd38522;
    data[ 133] =  'sd1573;
    data[ 134] =  'sd86765;
    data[ 135] =  'sd78292;
    data[ 136] =  'sd14069;
    data[ 137] =  'sd12482;
    data[ 138] = -'sd77279;
    data[ 139] = -'sd47144;
    data[ 140] = -'sd94536;
    data[ 141] =  'sd7713;
    data[ 142] = -'sd98417;
    data[ 143] = -'sd73250;
    data[ 144] =  'sd65491;
    data[ 145] =  'sd23082;
    data[ 146] = -'sd57592;
    data[ 147] = -'sd81695;
    data[ 148] =  'sd7260;
    data[ 149] =  'sd54498;
    data[ 150] = -'sd80707;
    data[ 151] = -'sd31165;
    data[ 152] =  'sd76829;
    data[ 153] = -'sd49156;
    data[ 154] = -'sd25390;
    data[ 155] =  'sd63394;
    data[ 156] =  'sd74038;
    data[ 157] =  'sd103141;
    data[ 158] =  'sd84758;
    data[ 159] = -'sd101349;
    data[ 160] =  'sd48873;
    data[ 161] = -'sd35172;
    data[ 162] = -'sd31098;
    data[ 163] =  'sd91167;
    data[ 164] =  'sd20892;
    data[ 165] = -'sd26538;
    data[ 166] =  'sd67579;
    data[ 167] = -'sd29800;
    data[ 168] =  'sd119082;
    data[ 169] = -'sd1866;
    data[ 170] =  'sd100390;
    data[ 171] = -'sd4242;
    data[ 172] =  'sd91640;
    data[ 173] =  'sd122114;
    data[ 174] = -'sd102589;
    data[ 175] =  'sd33370;
    data[ 176] = -'sd104673;
    data[ 177] =  'sd87108;
    data[ 178] = -'sd98163;
    data[ 179] = -'sd18894;
    data[ 180] = -'sd45604;
    data[ 181] = -'sd14833;
    data[ 182] =  'sd73879;
    data[ 183] =  'sd69115;
    data[ 184] =  'sd49047;
    data[ 185] =  'sd2064;
    data[ 186] = -'sd58018;
    data[ 187] =  'sd76998;
    data[ 188] = -'sd12990;
    data[ 189] = -'sd31433;
    data[ 190] =  'sd19477;
    data[ 191] = -'sd79491;
    data[ 192] = -'sd20798;
    data[ 193] =  'sd46654;
    data[ 194] = -'sd10324;
    data[ 195] =  'sd39377;
    data[ 196] = -'sd68460;
    data[ 197] =  'sd91123;
    data[ 198] =  'sd11476;
    data[ 199] = -'sd42706;
    data[ 200] =  'sd105625;
    data[ 201] =  'sd116620;
    data[ 202] = -'sd29020;
    data[ 203] =  'sd36145;
    data[ 204] = -'sd10537;
    data[ 205] = -'sd6205;
    data[ 206] = -'sd78585;
    data[ 207] = -'sd76771;
    data[ 208] =  'sd61568;
    data[ 209] = -'sd66869;
    data[ 210] = -'sd68117;
    data[ 211] = -'sd85332;
    data[ 212] = -'sd21487;
    data[ 213] = -'sd100792;
    data[ 214] = -'sd81786;
    data[ 215] = -'sd12214;
    data[ 216] = -'sd115226;
    data[ 217] =  'sd77479;
    data[ 218] =  'sd89944;
    data[ 219] =  'sd9027;
    data[ 220] = -'sd67078;
    data[ 221] = -'sd112843;
    data[ 222] =  'sd87727;
    data[ 223] =  'sd34303;
    data[ 224] =  'sd94989;
    data[ 225] =  'sd89229;
    data[ 226] =  'sd105874;
    data[ 227] = -'sd79951;
    data[ 228] = -'sd119238;
    data[ 229] = -'sd31518;
    data[ 230] =  'sd1287;
    data[ 231] =  'sd25561;
    data[ 232] = -'sd26800;
    data[ 233] =  'sd11511;
    data[ 234] = -'sd35216;
    data[ 235] = -'sd40514;
    data[ 236] =  'sd74999;
    data[ 237] =  'sd58938;
    data[ 238] =  'sd119882;
    data[ 239] = -'sd80523;
    data[ 240] =  'sd8211;
    data[ 241] =  'sd8155;
    data[ 242] = -'sd3829;
    data[ 243] = -'sd69835;
    data[ 244] =  'sd46730;
    data[ 245] =  'sd5940;
    data[ 246] =  'sd21875;
    data[ 247] = -'sd66033;
    data[ 248] =  'sd110787;
    data[ 249] = -'sd27997;
    data[ 250] =  'sd5210;
    data[ 251] =  'sd115512;
    data[ 252] = -'sd16275;
    data[ 253] =  'sd15148;
    data[ 254] = -'sd6469;
    data[ 255] =  'sd114776;
    data[ 256] =  'sd76078;
    data[ 257] =  'sd39987;
    data[ 258] =  'sd62080;
    data[ 259] =  'sd42699;
    data[ 260] = -'sd107123;
    data[ 261] =  'sd62522;
    data[ 262] = -'sd112570;
    data[ 263] = -'sd103708;
    data[ 264] =  'sd43761;
    data[ 265] =  'sd120145;
    data[ 266] = -'sd24241;
    data[ 267] =  'sd59423;
    data[ 268] = -'sd26185;
    data[ 269] = -'sd106736;
    data[ 270] = -'sd104517;
    data[ 271] =  'sd120492;
    data[ 272] =  'sd50017;
    data[ 273] = -'sd40213;
    data[ 274] = -'sd110444;
    data[ 275] =  'sd101399;
    data[ 276] = -'sd38173;
    data[ 277] =  'sd76259;
    data[ 278] =  'sd78721;
    data[ 279] =  'sd105875;
    data[ 280] = -'sd79737;
    data[ 281] = -'sd73442;
    data[ 282] =  'sd24403;
    data[ 283] = -'sd24755;
    data[ 284] = -'sd50573;
    data[ 285] = -'sd78771;
    data[ 286] = -'sd116575;
    data[ 287] =  'sd38650;
    data[ 288] =  'sd25819;
    data[ 289] =  'sd28412;
    data[ 290] =  'sd83600;
    data[ 291] = -'sd99304;
    data[ 292] = -'sd13211;
    data[ 293] = -'sd78727;
    data[ 294] = -'sd107159;
    data[ 295] =  'sd54818;
    data[ 296] = -'sd12227;
    data[ 297] = -'sd118008;
    data[ 298] = -'sd18155;
    data[ 299] =  'sd112542;
    data[ 300] =  'sd97716;
    data[ 301] = -'sd76764;
    data[ 302] =  'sd63066;
    data[ 303] =  'sd3846;
    data[ 304] =  'sd73473;
    data[ 305] = -'sd17769;
    data[ 306] = -'sd54711;
    data[ 307] =  'sd35125;
    data[ 308] =  'sd21040;
    data[ 309] =  'sd5134;
    data[ 310] =  'sd99248;
    data[ 311] =  'sd1227;
    data[ 312] =  'sd12721;
    data[ 313] = -'sd26133;
    data[ 314] = -'sd95608;
    data[ 315] =  'sd28162;
    data[ 316] =  'sd30100;
    data[ 317] = -'sd54882;
    data[ 318] = -'sd1469;
    data[ 319] = -'sd64509;
    data[ 320] = -'sd62791;
    data[ 321] =  'sd55004;
    data[ 322] =  'sd27577;
    data[ 323] = -'sd95090;
    data[ 324] = -'sd110843;
    data[ 325] =  'sd16013;
    data[ 326] = -'sd71216;
    data[ 327] =  'sd1053;
    data[ 328] = -'sd24515;
    data[ 329] =  'sd787;
    data[ 330] = -'sd81439;
    data[ 331] =  'sd62044;
    data[ 332] =  'sd34995;
    data[ 333] = -'sd6780;
    data[ 334] =  'sd48222;
    data[ 335] =  'sd75371;
    data[ 336] = -'sd111311;
    data[ 337] = -'sd84139;
    data[ 338] = -'sd16042;
    data[ 339] =  'sd65010;
    data[ 340] = -'sd79852;
    data[ 341] = -'sd98052;
    data[ 342] =  'sd4860;
    data[ 343] =  'sd40612;
    data[ 344] = -'sd54027;
    data[ 345] = -'sd68356;
    data[ 346] =  'sd113379;
    data[ 347] =  'sd26977;
    data[ 348] =  'sd26367;
    data[ 349] = -'sd104173;
    data[ 350] = -'sd55749;
    data[ 351] =  'sd62850;
    data[ 352] = -'sd42378;
    data[ 353] = -'sd74040;
    data[ 354] = -'sd103569;
    data[ 355] =  'sd73507;
    data[ 356] = -'sd10493;
    data[ 357] =  'sd3211;
    data[ 358] = -'sd62417;
    data[ 359] = -'sd114817;
    data[ 360] = -'sd84852;
    data[ 361] =  'sd81233;
    data[ 362] = -'sd106128;
    data[ 363] =  'sd25595;
    data[ 364] = -'sd19524;
    data[ 365] =  'sd69433;
    data[ 366] =  'sd117099;
    data[ 367] =  'sd73486;
    data[ 368] = -'sd14987;
    data[ 369] =  'sd40923;
    data[ 370] =  'sd12527;
    data[ 371] = -'sd67649;
    data[ 372] =  'sd14820;
    data[ 373] = -'sd76661;
    data[ 374] =  'sd85108;
    data[ 375] = -'sd26449;
    data[ 376] =  'sd86625;
    data[ 377] =  'sd48332;
    data[ 378] =  'sd98911;
    data[ 379] = -'sd70891;
    data[ 380] =  'sd70603;
    data[ 381] =  'sd117622;
    data[ 382] = -'sd64449;
    data[ 383] = -'sd49951;
    data[ 384] =  'sd54337;
    data[ 385] = -'sd115161;
    data[ 386] =  'sd91389;
    data[ 387] =  'sd68400;
    data[ 388] = -'sd103963;
    data[ 389] = -'sd10809;
    data[ 390] = -'sd64413;
    data[ 391] = -'sd42247;
    data[ 392] = -'sd46006;
    data[ 393] = -'sd100861;
    data[ 394] = -'sd96552;
    data[ 395] =  'sd76003;
    data[ 396] =  'sd23937;
    data[ 397] = -'sd124479;
    data[ 398] =  'sd96193;
    data[ 399] =  'sd97028;
    data[ 400] =  'sd25861;
    data[ 401] =  'sd37400;
    data[ 402] =  'sd8176;
    data[ 403] =  'sd665;
    data[ 404] = -'sd107547;
    data[ 405] = -'sd28214;
    data[ 406] = -'sd41228;
    data[ 407] = -'sd77797;
    data[ 408] =  'sd91861;
    data[ 409] = -'sd80449;
    data[ 410] =  'sd24047;
    data[ 411] = -'sd100939;
    data[ 412] = -'sd113244;
    data[ 413] =  'sd1913;
    data[ 414] = -'sd90332;
    data[ 415] = -'sd92059;
    data[ 416] =  'sd38077;
    data[ 417] = -'sd96803;
    data[ 418] =  'sd22289;
    data[ 419] =  'sd22563;
    data[ 420] =  'sd81199;
    data[ 421] = -'sd113404;
    data[ 422] = -'sd32327;
    data[ 423] =  'sd78018;
    data[ 424] = -'sd44567;
    data[ 425] = -'sd42772;
    data[ 426] =  'sd91501;
    data[ 427] =  'sd92368;
    data[ 428] =  'sd28049;
    data[ 429] =  'sd5918;
    data[ 430] =  'sd17167;
    data[ 431] = -'sd74117;
    data[ 432] = -'sd120047;
    data[ 433] =  'sd45213;
    data[ 434] = -'sd68841;
    data[ 435] =  'sd9589;
    data[ 436] =  'sd53190;
    data[ 437] = -'sd110762;
    data[ 438] =  'sd33347;
    data[ 439] = -'sd109595;
    data[ 440] =  'sd33228;
    data[ 441] =  'sd114796;
    data[ 442] =  'sd80358;
    data[ 443] = -'sd43521;
    data[ 444] = -'sd68785;
    data[ 445] =  'sd21573;
    data[ 446] =  'sd119196;
    data[ 447] =  'sd22530;
    data[ 448] =  'sd74137;
    data[ 449] =  'sd124327;
    data[ 450] =  'sd121136;
    data[ 451] = -'sd62024;
    data[ 452] = -'sd30715;
    data[ 453] = -'sd76728;
    data[ 454] =  'sd70770;
    data[ 455] = -'sd96497;
    data[ 456] =  'sd87773;
    data[ 457] =  'sd44147;
    data[ 458] = -'sd47108;
    data[ 459] = -'sd86832;
    data[ 460] = -'sd92630;
    data[ 461] = -'sd84117;
    data[ 462] = -'sd11334;
    data[ 463] =  'sd73094;
    data[ 464] = -'sd98875;
    data[ 465] =  'sd78595;
    data[ 466] =  'sd78911;
    data[ 467] = -'sd103322;
    data[ 468] = -'sd123492;
    data[ 469] =  'sd57554;
    data[ 470] =  'sd73563;
    data[ 471] =  'sd1491;
    data[ 472] =  'sd69217;
    data[ 473] =  'sd70875;
    data[ 474] = -'sd74027;
    data[ 475] = -'sd100787;
    data[ 476] = -'sd80716;
    data[ 477] = -'sd33091;
    data[ 478] = -'sd85478;
    data[ 479] = -'sd52731;
    data[ 480] = -'sd40869;
    data[ 481] = -'sd971;
    data[ 482] =  'sd42063;
    data[ 483] =  'sd6630;
    data[ 484] = -'sd80322;
    data[ 485] =  'sd51225;
    data[ 486] = -'sd31558;
    data[ 487] = -'sd7273;
    data[ 488] = -'sd57280;
    data[ 489] = -'sd14927;
    data[ 490] =  'sd53763;
    data[ 491] =  'sd11860;
    data[ 492] =  'sd39470;
    data[ 493] = -'sd48558;
    data[ 494] =  'sd102582;
    data[ 495] = -'sd34868;
    data[ 496] =  'sd33958;
    data[ 497] =  'sd21159;
    data[ 498] =  'sd30600;
    data[ 499] =  'sd52118;
    data[ 500] = -'sd90313;
    data[ 501] = -'sd87993;
    data[ 502] = -'sd91227;
    data[ 503] = -'sd33732;
    data[ 504] =  'sd27205;
    data[ 505] =  'sd75159;
    data[ 506] =  'sd93178;
    data[ 507] = -'sd48468;
    data[ 508] =  'sd121842;
    data[ 509] =  'sd89060;
    data[ 510] =  'sd69708;
    data[ 511] = -'sd73908;
    data[ 512] = -'sd75321;
    data[ 513] =  'sd122011;
    data[ 514] = -'sd124631;
    data[ 515] =  'sd63665;
    data[ 516] = -'sd117825;
    data[ 517] =  'sd21007;
    data[ 518] = -'sd1928;
    data[ 519] =  'sd87122;
    data[ 520] = -'sd95167;
    data[ 521] =  'sd122536;
    data[ 522] = -'sd12281;
    data[ 523] =  'sd120293;
    data[ 524] =  'sd7431;
    data[ 525] =  'sd91092;
    data[ 526] =  'sd4842;
    data[ 527] =  'sd36760;
    data[ 528] =  'sd121073;
    data[ 529] = -'sd75506;
    data[ 530] =  'sd82421;
    data[ 531] = -'sd101753;
    data[ 532] = -'sd37583;
    data[ 533] = -'sd47338;
    data[ 534] =  'sd113805;
    data[ 535] =  'sd118141;
    data[ 536] =  'sd46617;
    data[ 537] = -'sd18242;
    data[ 538] =  'sd93924;
    data[ 539] =  'sd111176;
    data[ 540] =  'sd55249;
    data[ 541] =  'sd80007;
    data[ 542] = -'sd118635;
    data[ 543] =  'sd97524;
    data[ 544] = -'sd117852;
    data[ 545] =  'sd15229;
    data[ 546] =  'sd10865;
    data[ 547] =  'sd76397;
    data[ 548] =  'sd108253;
    data[ 549] = -'sd70559;
    data[ 550] = -'sd108206;
    data[ 551] =  'sd80617;
    data[ 552] =  'sd11905;
    data[ 553] =  'sd49100;
    data[ 554] =  'sd13406;
    data[ 555] =  'sd120457;
    data[ 556] =  'sd42527;
    data[ 557] =  'sd105926;
    data[ 558] = -'sd68823;
    data[ 559] =  'sd13441;
    data[ 560] = -'sd121910;
    data[ 561] = -'sd103612;
    data[ 562] =  'sd64305;
    data[ 563] =  'sd19135;
    data[ 564] =  'sd97178;
    data[ 565] =  'sd57961;
    data[ 566] = -'sd89196;
    data[ 567] = -'sd98812;
    data[ 568] =  'sd92077;
    data[ 569] = -'sd34225;
    data[ 570] = -'sd78297;
    data[ 571] = -'sd15139;
    data[ 572] =  'sd8395;
    data[ 573] =  'sd47531;
    data[ 574] = -'sd72503;
    data[ 575] = -'sd24508;
    data[ 576] =  'sd2285;
    data[ 577] = -'sd10724;
    data[ 578] = -'sd46223;
    data[ 579] =  'sd102558;
    data[ 580] = -'sd40004;
    data[ 581] = -'sd65718;
    data[ 582] = -'sd71660;
    data[ 583] = -'sd93963;
    data[ 584] = -'sd119522;
    data[ 585] = -'sd92294;
    data[ 586] = -'sd12213;
    data[ 587] = -'sd115012;
    data[ 588] =  'sd123275;
    data[ 589] = -'sd103992;
    data[ 590] = -'sd17015;
    data[ 591] =  'sd106645;
    data[ 592] =  'sd85043;
    data[ 593] = -'sd40359;
    data[ 594] =  'sd108169;
    data[ 595] = -'sd88535;
    data[ 596] =  'sd42642;
    data[ 597] = -'sd119321;
    data[ 598] = -'sd49280;
    data[ 599] = -'sd51926;
    data[ 600] = -'sd118456;
    data[ 601] = -'sd114027;
    data[ 602] =  'sd84208;
    data[ 603] =  'sd30808;
    data[ 604] =  'sd96630;
    data[ 605] = -'sd59311;
    data[ 606] =  'sd50153;
    data[ 607] = -'sd11109;
    data[ 608] =  'sd121244;
    data[ 609] = -'sd38912;
    data[ 610] = -'sd81887;
    data[ 611] = -'sd33828;
    data[ 612] =  'sd6661;
    data[ 613] = -'sd73688;
    data[ 614] = -'sd28241;
    data[ 615] = -'sd47006;
    data[ 616] = -'sd65004;
    data[ 617] =  'sd81136;
    data[ 618] =  'sd122971;
    data[ 619] =  'sd80809;
    data[ 620] =  'sd52993;
    data[ 621] =  'sd96937;
    data[ 622] =  'sd6387;
    data[ 623] =  'sd117533;
    data[ 624] = -'sd83495;
    data[ 625] =  'sd121774;
    data[ 626] =  'sd74508;
    data[ 627] = -'sd46136;
    data[ 628] =  'sd121176;
    data[ 629] = -'sd53464;
    data[ 630] =  'sd52126;
    data[ 631] = -'sd88601;
    data[ 632] =  'sd28518;
    data[ 633] =  'sd106284;
    data[ 634] =  'sd7789;
    data[ 635] = -'sd82153;
    data[ 636] = -'sd90752;
    data[ 637] =  'sd67918;
    data[ 638] =  'sd42746;
    data[ 639] = -'sd97065;
    data[ 640] = -'sd33779;
    data[ 641] =  'sd17147;
    data[ 642] = -'sd78397;
    data[ 643] = -'sd36539;
    data[ 644] = -'sd73779;
    data[ 645] = -'sd47715;
    data[ 646] =  'sd33127;
    data[ 647] =  'sd93182;
    data[ 648] = -'sd47612;
    data[ 649] =  'sd55169;
    data[ 650] =  'sd62887;
    data[ 651] = -'sd34460;
    data[ 652] =  'sd121270;
    data[ 653] = -'sd33348;
    data[ 654] =  'sd109381;
    data[ 655] = -'sd79024;
    data[ 656] =  'sd79140;
    data[ 657] = -'sd54316;
    data[ 658] =  'sd119655;
    data[ 659] =  'sd120756;
    data[ 660] =  'sd106513;
    data[ 661] =  'sd56795;
    data[ 662] = -'sd88863;
    data[ 663] = -'sd27550;
    data[ 664] =  'sd100868;
    data[ 665] =  'sd98050;
    data[ 666] = -'sd5288;
    data[ 667] =  'sd117653;
    data[ 668] = -'sd57815;
    data[ 669] =  'sd120440;
    data[ 670] =  'sd38889;
    data[ 671] =  'sd76965;
    data[ 672] = -'sd20052;
    data[ 673] = -'sd43559;
    data[ 674] = -'sd76917;
    data[ 675] =  'sd30324;
    data[ 676] = -'sd6946;
    data[ 677] =  'sd12698;
    data[ 678] = -'sd31055;
    data[ 679] =  'sd100369;
    data[ 680] = -'sd8736;
    data[ 681] = -'sd120505;
    data[ 682] = -'sd52799;
    data[ 683] = -'sd55421;
    data[ 684] = -'sd116815;
    data[ 685] = -'sd12710;
    data[ 686] =  'sd28487;
    data[ 687] =  'sd99650;
    data[ 688] =  'sd87255;
    data[ 689] = -'sd66705;
    data[ 690] = -'sd33021;
    data[ 691] = -'sd70498;
    data[ 692] = -'sd95152;
    data[ 693] = -'sd124111;
    data[ 694] = -'sd74912;
    data[ 695] = -'sd40320;
    data[ 696] =  'sd116515;
    data[ 697] = -'sd51490;
    data[ 698] = -'sd25152;
    data[ 699] =  'sd114326;
    data[ 700] = -'sd20222;
    data[ 701] = -'sd79939;
    data[ 702] = -'sd116670;
    data[ 703] =  'sd18320;
    data[ 704] = -'sd77232;
    data[ 705] = -'sd37086;
    data[ 706] =  'sd59020;
    data[ 707] = -'sd112427;
    data[ 708] = -'sd73106;
    data[ 709] =  'sd96307;
    data[ 710] =  'sd121424;
    data[ 711] = -'sd392;
    data[ 712] = -'sd83888;
    data[ 713] =  'sd37672;
    data[ 714] =  'sd66384;
    data[ 715] = -'sd35673;
    data[ 716] =  'sd111545;
    data[ 717] = -'sd115642;
    data[ 718] = -'sd11545;
    data[ 719] =  'sd27940;
    data[ 720] = -'sd17408;
    data[ 721] =  'sd22543;
    data[ 722] =  'sd76919;
    data[ 723] = -'sd29896;
    data[ 724] =  'sd98538;
    data[ 725] =  'sd99144;
    data[ 726] = -'sd21029;
    data[ 727] = -'sd2780;
    data[ 728] = -'sd95206;
    data[ 729] =  'sd114190;
    data[ 730] = -'sd49326;
    data[ 731] = -'sd61770;
    data[ 732] =  'sd23641;
    data[ 733] =  'sd62034;
    data[ 734] =  'sd32855;
    data[ 735] =  'sd34974;
    data[ 736] = -'sd11274;
    data[ 737] =  'sd85934;
    data[ 738] = -'sd99542;
    data[ 739] = -'sd64143;
    data[ 740] =  'sd15533;
    data[ 741] =  'sd75921;
    data[ 742] =  'sd6389;
    data[ 743] =  'sd117961;
    data[ 744] =  'sd8097;
    data[ 745] = -'sd16241;
    data[ 746] =  'sd22424;
    data[ 747] =  'sd51453;
    data[ 748] =  'sd17234;
    data[ 749] = -'sd59779;
    data[ 750] = -'sd49999;
    data[ 751] =  'sd44065;
    data[ 752] = -'sd64656;
    data[ 753] = -'sd94249;
    data[ 754] =  'sd69131;
    data[ 755] =  'sd52471;
    data[ 756] = -'sd14771;
    data[ 757] =  'sd87147;
    data[ 758] = -'sd89817;
    data[ 759] =  'sd18151;
    data[ 760] = -'sd113398;
    data[ 761] = -'sd31043;
    data[ 762] =  'sd102937;
    data[ 763] =  'sd41102;
    data[ 764] =  'sd50833;
    data[ 765] = -'sd115446;
    data[ 766] =  'sd30399;
    data[ 767] =  'sd9104;
    data[ 768] = -'sd50600;
    data[ 769] = -'sd84549;
    data[ 770] = -'sd103782;
    data[ 771] =  'sd27925;
    data[ 772] = -'sd20618;
    data[ 773] =  'sd85174;
    data[ 774] = -'sd12325;
    data[ 775] =  'sd110877;
    data[ 776] = -'sd8737;
    data[ 777] = -'sd120719;
    data[ 778] = -'sd98595;
    data[ 779] = -'sd111342;
    data[ 780] = -'sd90773;
    data[ 781] =  'sd63424;
    data[ 782] =  'sd80458;
    data[ 783] = -'sd22121;
    data[ 784] =  'sd13389;
    data[ 785] =  'sd116819;
    data[ 786] =  'sd13566;
    data[ 787] = -'sd95160;
    data[ 788] =  'sd124034;
    data[ 789] =  'sd58434;
    data[ 790] =  'sd12026;
    data[ 791] =  'sd74994;
    data[ 792] =  'sd57868;
    data[ 793] = -'sd109098;
    data[ 794] = -'sd110271;
    data[ 795] = -'sd111436;
    data[ 796] = -'sd110889;
    data[ 797] =  'sd6169;
    data[ 798] =  'sd70881;
    data[ 799] = -'sd72743;
    data[ 800] = -'sd75868;
    data[ 801] =  'sd4953;
    data[ 802] =  'sd60514;
    data[ 803] = -'sd42568;
    data[ 804] = -'sd114700;
    data[ 805] = -'sd59814;
    data[ 806] = -'sd57489;
    data[ 807] = -'sd59653;
    data[ 808] = -'sd23035;
    data[ 809] =  'sd67650;
    data[ 810] = -'sd14606;
    data[ 811] =  'sd122457;
    data[ 812] = -'sd29187;
    data[ 813] =  'sd407;
    data[ 814] =  'sd87098;
    data[ 815] = -'sd100303;
    data[ 816] =  'sd22860;
    data[ 817] = -'sd105100;
    data[ 818] = -'sd4270;
    data[ 819] =  'sd85648;
    data[ 820] =  'sd89111;
    data[ 821] =  'sd80622;
    data[ 822] =  'sd12975;
    data[ 823] =  'sd28223;
    data[ 824] =  'sd43154;
    data[ 825] = -'sd9753;
    data[ 826] = -'sd88286;
    data[ 827] =  'sd95928;
    data[ 828] =  'sd40318;
    data[ 829] = -'sd116943;
    data[ 830] = -'sd40102;
    data[ 831] = -'sd86690;
    data[ 832] = -'sd62242;
    data[ 833] = -'sd77367;
    data[ 834] = -'sd65976;
    data[ 835] =  'sd122985;
    data[ 836] =  'sd83805;
    data[ 837] = -'sd55434;
    data[ 838] = -'sd119597;
    data[ 839] = -'sd108344;
    data[ 840] =  'sd51085;
    data[ 841] = -'sd61518;
    data[ 842] =  'sd77569;
    data[ 843] =  'sd109204;
    data[ 844] = -'sd116902;
    data[ 845] = -'sd31328;
    data[ 846] =  'sd41947;
    data[ 847] = -'sd18194;
    data[ 848] =  'sd104196;
    data[ 849] =  'sd60671;
    data[ 850] = -'sd8970;
    data[ 851] =  'sd79276;
    data[ 852] = -'sd25212;
    data[ 853] =  'sd101486;
    data[ 854] = -'sd19555;
    data[ 855] =  'sd62799;
    data[ 856] = -'sd53292;
    data[ 857] =  'sd88934;
    data[ 858] =  'sd42744;
    data[ 859] = -'sd97493;
    data[ 860] =  'sd124486;
    data[ 861] = -'sd94695;
    data[ 862] = -'sd26313;
    data[ 863] =  'sd115729;
    data[ 864] =  'sd30163;
    data[ 865] = -'sd41400;
    data[ 866] = -'sd114605;
    data[ 867] = -'sd39484;
    data[ 868] =  'sd45562;
    data[ 869] =  'sd5845;
    data[ 870] =  'sd1545;
    data[ 871] =  'sd80773;
    data[ 872] =  'sd45289;
    data[ 873] = -'sd52577;
    data[ 874] = -'sd7913;
    data[ 875] =  'sd55617;
    data[ 876] = -'sd91098;
    data[ 877] = -'sd6126;
    data[ 878] = -'sd61679;
    data[ 879] =  'sd43115;
    data[ 880] = -'sd18099;
    data[ 881] =  'sd124526;
    data[ 882] = -'sd86135;
    data[ 883] =  'sd56528;
    data[ 884] =  'sd103856;
    data[ 885] = -'sd12089;
    data[ 886] = -'sd88476;
    data[ 887] =  'sd55268;
    data[ 888] =  'sd84073;
    data[ 889] =  'sd1918;
    data[ 890] = -'sd89262;
    data[ 891] = -'sd112936;
    data[ 892] =  'sd67825;
    data[ 893] =  'sd22844;
    data[ 894] = -'sd108524;
    data[ 895] =  'sd12565;
    data[ 896] = -'sd59517;
    data[ 897] =  'sd6069;
    data[ 898] =  'sd49481;
    data[ 899] =  'sd94940;
    data[ 900] =  'sd78743;
    data[ 901] =  'sd110583;
    data[ 902] = -'sd71653;
    data[ 903] = -'sd92465;
    data[ 904] = -'sd48807;
    data[ 905] =  'sd49296;
    data[ 906] =  'sd55350;
    data[ 907] =  'sd101621;
    data[ 908] =  'sd9335;
    data[ 909] = -'sd1166;
    data[ 910] =  'sd333;
    data[ 911] =  'sd71262;
    data[ 912] =  'sd8791;
    data[ 913] = -'sd117582;
    data[ 914] =  'sd73009;
    data[ 915] = -'sd117065;
    data[ 916] = -'sd66210;
    data[ 917] =  'sd72909;
    data[ 918] =  'sd111392;
    data[ 919] =  'sd101473;
    data[ 920] = -'sd22337;
    data[ 921] = -'sd32835;
    data[ 922] = -'sd30694;
    data[ 923] = -'sd72234;
    data[ 924] =  'sd33058;
    data[ 925] =  'sd78416;
    data[ 926] =  'sd40605;
    data[ 927] = -'sd55525;
    data[ 928] =  'sd110786;
    data[ 929] = -'sd28211;
    data[ 930] = -'sd40586;
    data[ 931] =  'sd59591;
    data[ 932] =  'sd9767;
    data[ 933] =  'sd91282;
    data[ 934] =  'sd45502;
    data[ 935] = -'sd6995;
    data[ 936] =  'sd2212;
    data[ 937] = -'sd26346;
    data[ 938] =  'sd108667;
    data[ 939] =  'sd18037;
    data[ 940] =  'sd112063;
    data[ 941] = -'sd4790;
    data[ 942] = -'sd25632;
    data[ 943] =  'sd11606;
    data[ 944] = -'sd14886;
    data[ 945] =  'sd62537;
    data[ 946] = -'sd109360;
    data[ 947] =  'sd83518;
    data[ 948] = -'sd116852;
    data[ 949] = -'sd20628;
    data[ 950] =  'sd83034;
    data[ 951] =  'sd29429;
    data[ 952] =  'sd51381;
    data[ 953] =  'sd1826;
    data[ 954] = -'sd108950;
    data[ 955] = -'sd78599;
    data[ 956] = -'sd79767;
    data[ 957] = -'sd79862;
    data[ 958] = -'sd100192;
    data[ 959] =  'sd46614;
    data[ 960] = -'sd18884;
    data[ 961] = -'sd43464;
    data[ 962] = -'sd56587;
    data[ 963] = -'sd116482;
    data[ 964] =  'sd58552;
    data[ 965] =  'sd37278;
    data[ 966] = -'sd17932;
    data[ 967] = -'sd89593;
    data[ 968] =  'sd66087;
    data[ 969] = -'sd99231;
    data[ 970] =  'sd2411;
    data[ 971] =  'sd16240;
    data[ 972] = -'sd22638;
    data[ 973] = -'sd97249;
    data[ 974] = -'sd73155;
    data[ 975] =  'sd85821;
    data[ 976] = -'sd123724;
    data[ 977] =  'sd7906;
    data[ 978] = -'sd57115;
    data[ 979] =  'sd20383;
    data[ 980] =  'sd114393;
    data[ 981] = -'sd5884;
    data[ 982] = -'sd9891;
    data[ 983] = -'sd117818;
    data[ 984] =  'sd22505;
    data[ 985] =  'sd68787;
    data[ 986] = -'sd21145;
    data[ 987] = -'sd27604;
    data[ 988] =  'sd89312;
    data[ 989] =  'sd123636;
    data[ 990] = -'sd26738;
    data[ 991] =  'sd24779;
    data[ 992] =  'sd55709;
    data[ 993] = -'sd71410;
    data[ 994] = -'sd40463;
    data[ 995] =  'sd85913;
    data[ 996] = -'sd104036;
    data[ 997] = -'sd26431;
    data[ 998] =  'sd90477;
    data[ 999] =  'sd123089;
    data[1000] =  'sd106061;
    data[1001] = -'sd39933;
    data[1002] = -'sd50524;
    data[1003] = -'sd68285;
    data[1004] = -'sd121284;
    data[1005] =  'sd30352;
    data[1006] = -'sd954;
    data[1007] =  'sd45701;
    data[1008] =  'sd35591;
    data[1009] =  'sd120764;
    data[1010] =  'sd108225;
    data[1011] = -'sd76551;
    data[1012] =  'sd108648;
    data[1013] =  'sd13971;
    data[1014] = -'sd8490;
    data[1015] = -'sd67861;
    data[1016] = -'sd30548;
    data[1017] = -'sd40990;
    data[1018] = -'sd26865;
    data[1019] = -'sd2399;
    data[1020] = -'sd13672;
    data[1021] =  'sd72476;
    data[1022] =  'sd18730;
    data[1023] =  'sd10508;
  end

endmodule

