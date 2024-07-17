module mod_3 ( clk, addr, Out ) ;

  input clk;
  input      [10: 0] addr;
  output reg [1 : 0] Out;

  wire       [2 : 0] even0;
  wire       [2 : 0] odd0;
  reg        [4 : 0] oe0;
  wire       [1 : 0] even1;
  wire       [1 : 0] odd1;
  reg        [2 : 0] oe1;

  assign even0 = addr[0] + addr[2] + addr[4] + addr[6] + addr[8] + addr[10];
  assign odd0 = addr[1] + addr[3] + addr[5] + addr[7] + addr[9];

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

module ntt761good3_4591_by_114689_120833 ( clk, rst, start, input_fg, addr, din, dout, valid );

  localparam Q0 = 4591;
  localparam Q1 = 114689;
  localparam Q2 = 120833;
  localparam Q_n1_INV = 38211;
  localparam Q_n2_INV = -40258;

  localparam Q_n1_PREFIX = 59; // Note: manual optimization for this part may be necessary.
  localparam Q_n1_SHIFT  = 11;
  localparam Q_n2_PREFIX = 7; // Note: manual optimization for this part may be necessary.
  localparam Q_n2_SHIFT  = 14;

  localparam QALLp      = 35'sh33A039801; // Note: manual optimization for this part may be necessary.
  localparam QALLp_DIV2 = 35'sh19D01CC00;
  localparam QALLn      = 35'sh4C5FC67FF;
  localparam QALLn_DIV2 = 35'sh662FE3400;

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
  // Notice: This RTL applies CRT to handle the unfriendliness of 4591.
  //         d[16: 0] for q1 = 114689 in wr_din/rd_dout/wr_dout
  //         d[33:17] for q2 = 120833 in wr_din/rd_dout/wr_dout
  reg            wr_en   [0 : 1];
  reg   [10 : 0] wr_addr [0 : 1];
  reg   [10 : 0] rd_addr [0 : 1];
  reg   [33 : 0] wr_din  [0 : 1];
  wire  [33 : 0] rd_dout [0 : 1];
  wire  [33 : 0] wr_dout [0 : 1];

  // addr_gen
  wire         bank_index_rd [0 : 1];
  wire         bank_index_wr [0 : 1];
  wire [7 : 0] data_index_rd [0 : 1];
  wire [7 : 0] data_index_wr [0 : 1];
  reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;
  reg  fg_shift_1, fg_shift_2, fg_shift_3;

  // w_addr_gen
  reg  [7  : 0] stage_bit;
  wire [7  : 0] w_addr;

  // bfu
  reg                  ntt_state;
  reg                  acc_state;
  reg  signed [16: 0] in_a  [0:1];
  reg  signed [16: 0] in_b  [0:1];
  reg  signed [16: 0] in_w  [0:1];
  wire signed [33: 0] bw    [0:1];
  wire signed [16: 0] out_a [0:1];
  wire signed [16: 0] out_b [0:1];

  // state, stage, counter
  reg  [2 : 0] state, next_state;
  reg  [4 : 0] stage, stage_wr;
  wire [4 : 0] stage_rdM, stage_wrM;
  reg  [9 : 0] ctr;
  reg  [9 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_10, ctr_shift_1, ctr_shift_2, ctr_shift_3, ctr_pmul_shift_2;
  reg  [1 : 0] ctr_good, good_index, good_index_wr;
  wire [2 : 0] good_index_buf;
  wire [1 : 0] ctr_good_next, good_index_next, good_index_wr_next;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, ctr_shift_2_full_end, ctr_shift_10_full_end, stage_rd_end, stage_rd_3, stage_rd_7, stage_wr_end, ntt_end, ctr_good_end, good_index_end, good_index_wr_end, point_proc_end, reduce_end;
  reg          point_proc_end_reg;

  // w_array
  reg         [8 : 0] w_addr_in;
  wire signed [16: 0] w_dout [0:1];

  // mod_3
  wire [1 : 0] in_addr;
  wire [1 : 0] out_good0, out_good1;
  reg  [1 : 0] out_good0_0, out_good1_0;
  wire         acc_ctrl;
  reg  [9 : 0] acc_ctrls;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [8 : 0] wr_ctr [0 : 1];
  reg [12: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [8 : 0] w_addr_in_shift_1;

  // crt
  reg  signed [16:0] in_b_1 [0:1];
  reg  signed [18:0] in_b_sum;
  reg  signed [34:0] bw_sum;
  wire signed [34:0] bw_sum_ALL;
  wire signed [34:0] qproduct_ALL;
  reg  signed [33:0] bw_sum_mod;
  wire signed [12:0] mod4591_out;

  // BRAM instances
  bram_34_11_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_34_11_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[7:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[7:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[7:0], w_addr);

  // Butterfly Unit s , each with a corresponding omega array
  bfu_114689 bfu_inst0 (clk, ntt_state, acc_ctrls[7], in_a[0], in_b[0], in_w[0], bw[0], out_a[0], out_b[0]);
  w_114689 rom_w_inst0 (clk, w_addr_in_shift_1, w_dout[0]);
  bfu_120833 bfu_inst1 (clk, ntt_state, acc_ctrls[7], in_a[1], in_b[1], in_w[1], bw[1], out_a[1], out_b[1]);
  w_120833 rom_w_inst1 (clk, w_addr_in_shift_1, w_dout[1]);

  mod_3 in_addr_gen ( clk, addr, in_addr );
  good3_addr_gen good3_addr_0 ( clk, good_index, ctr_good, out_good0, out_good1, acc_ctrl );

  always @ ( posedge clk ) begin
    out_good0_0 <= out_good0;
    out_good1_0 <= out_good1;
    acc_ctrls <= { acc_ctrls, acc_ctrl };
  end

  // MOD 4591 (Note: manual optimization for this part may be necessary.)
  mod4591S33 mod_q0_inst ( clk, rst, { bw_sum_mod[33], bw_sum_mod[31:0] }, mod4591_out);

  // miscellaneous checkpoint
  assign ctr_half_end         = (ctr[7:0] == 255) ? 1 : 0;
  assign ctr_full_end         = (ctr[8:0] == 511) ? 1 : 0;
  assign ctr_shift_2_full_end = (ctr_shift_2[8:0] == 511) ? 1 : 0;
  assign ctr_shift_10_full_end = (ctr_shift_10[8:0] == 511) ? 1 : 0;
  assign ctr_shift_7_end      = (ctr_shift_7[7 : 0] == 255) ? 1 : 0;
  assign stage_rd_end         = (stage == 9) ? 1 : 0;
  assign stage_rd_3           = (stage == 3) ? 1 : 0;
  assign stage_rd_7           = (stage == 7) ? 1 : 0;
  assign stage_wr_end         = (stage_wr == 9) ? 1 : 0;
  assign ntt_end              = (stage_rd_end && ctr[7 : 0] == 10) ? 1 : 0;
  assign ctr_good_end         = (ctr_good == 'd2);
  assign good_index_end       = (good_index == 'd2);
  assign good_index_wr_end    = (good_index_wr == 'd2);
  assign crt_end              = (stage_rd_7 && ctr[7 : 0] == 10) ? 1 : 0;
  assign point_proc_end       = (ctr == 515) ? 1 : 0;
  assign reload_end           = (stage_rd_3 && ctr[7:0] == 4) ? 1 : 0;
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
    bw_sum[34:11] <= bw[0][23:0] + { bw[1][20:0], 3'b0 };
    bw_sum[10:0] <= 11'b0;
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
        rd_addr[0][7:0] <= data_index_rd[1];
        rd_addr[1][7:0] <= data_index_rd[0];
      end else begin
        rd_addr[0][7:0] <= data_index_rd[0];
        rd_addr[1][7:0] <= data_index_rd[1];
      end
    end else begin
      rd_addr[0][7:0] <= data_index_rd[0];
      rd_addr[1][7:0] <= data_index_rd[0];
    end

    if ( state == ST_PMUL ) begin
      // TODO: good factor control
      rd_addr[0][9:8] <= out_good0_0;
      rd_addr[1][9:8] <= out_good1_0;
    end else if ( state == ST_RELOAD ) begin
      rd_addr[0][9:8] <= { 1'b1, !good_index[1] };
      rd_addr[1][9:8] <= { 1'b1, !good_index[1] };
    end else begin
      rd_addr[0][9:8] <= good_index;
      rd_addr[1][9:8] <= good_index;
    end

    if (state == ST_NTT)  begin
      rd_addr[0][10] <= poly_select;
      rd_addr[1][10] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][10] <=  bank_index_rd[0];
      rd_addr[1][10] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][10] <= good_index[0];
      rd_addr[1][10] <= good_index[0];
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
        wr_addr[0][7:0] <= data_index_wr[1];
        wr_addr[1][7:0] <= data_index_wr[0];
      end else begin
        wr_addr[0][7:0] <= data_index_wr[0];
        wr_addr[1][7:0] <= data_index_wr[1];
      end
    end else begin
      wr_addr[0][7:0] <= data_index_wr[0];
      wr_addr[1][7:0] <= data_index_wr[0];
    end  

    if ( state == ST_IDLE || state == ST_FINISH ) begin
      wr_addr[0][9:8] <= in_addr;
      wr_addr[1][9:8] <= in_addr;
    end else if ( state == ST_PMUL ) begin
      wr_addr[0][9:8] <= good_index_buf[1:0];
      wr_addr[1][9:8] <= good_index_buf[1:0];
    end else if ( state == ST_RELOAD || state == ST_REDUCE ) begin
      wr_addr[0][9:8] <= stage_wr[1:0];
      wr_addr[1][9:8] <= stage_wr[1:0];
    end else if ( state == ST_CRT ) begin
      wr_addr[0][9:8] <= good_index_wr;
      wr_addr[1][9:8] <= good_index_wr;
    end else begin
      wr_addr[0][9:8] <= good_index;
      wr_addr[1][9:8] <= good_index;
    end

    if (state == ST_IDLE) begin
      wr_addr[0][10] <= fg_shift_3;
      wr_addr[1][10] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][10] <= poly_select;
      wr_addr[1][10] <= poly_select;
    end else if (state == ST_PMUL) begin
      wr_addr[0][10] <= good_index_buf[2];
      wr_addr[1][10] <= good_index_buf[2];
    end else if (state == ST_REDUCE || state == ST_FINISH) begin
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
      wr_din[0][16:0] <= { { 4 { din_shift_3[12] } }, din_shift_3 };
      wr_din[1][16:0] <= { { 4 { din_shift_3[12] } }, din_shift_3 };
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_din[0][16:0] <= out_b[0];
        wr_din[1][16:0] <= out_a[0];
      end else begin
        wr_din[0][16:0] <= out_a[0];
        wr_din[1][16:0] <= out_b[0];
      end
    end else if (state == ST_RELOAD) begin
      if (bank_index_rd_shift_2 ^ stage_wr[0]) begin
        wr_din[0][16:0] <= rd_dout[1][16:0];
        wr_din[1][16:0] <= rd_dout[1][16:0];
      end else begin
        wr_din[0][16:0] <= rd_dout[0][16:0];
        wr_din[1][16:0] <= rd_dout[0][16:0];
      end
    end else if (state == ST_REDUCE) begin
      if (bank_index_rd_shift_2) begin
        wr_din[0][16:0] <= rd_dout[0][16:0];
        wr_din[1][16:0] <= rd_dout[0][16:0];
      end else begin
        wr_din[0][16:0] <= rd_dout[1][16:0];
        wr_din[1][16:0] <= rd_dout[1][16:0];
      end
    end else if (state == ST_CRT) begin
      if (stage_wr[2] == 0) begin
        wr_din[0][16:0] <= out_a[0];
        wr_din[1][16:0] <= out_a[0];
      end else begin
        wr_din[0][16:0] <= mod4591_out;
        wr_din[1][16:0] <= mod4591_out;
      end
    end else begin
      wr_din[0][16:0] <= out_a[0];
      wr_din[1][16:0] <= out_a[0];
    end

    if (state == ST_IDLE) begin
      wr_din[0][33:17] <= { { 4 { din_shift_3[12] } }, din_shift_3 };
      wr_din[1][33:17] <= { { 4 { din_shift_3[12] } }, din_shift_3 };
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_din[0][33:17] <= out_b[1];
        wr_din[1][33:17] <= out_a[1];
      end else begin
        wr_din[0][33:17] <= out_a[1];
        wr_din[1][33:17] <= out_b[1];
      end
    end else if (state == ST_RELOAD) begin
      if (bank_index_rd_shift_2 ^ stage_wr[0]) begin
        wr_din[0][33:17] <= rd_dout[1][33:17];
        wr_din[1][33:17] <= rd_dout[1][33:17];
      end else begin
        wr_din[0][33:17] <= rd_dout[0][33:17];
        wr_din[1][33:17] <= rd_dout[0][33:17];
      end
    end else if (state == ST_REDUCE) begin
      if (bank_index_rd_shift_2) begin
        wr_din[0][33:17] <= rd_dout[0][33:17];
        wr_din[1][33:17] <= rd_dout[0][33:17];
      end else begin
        wr_din[0][33:17] <= rd_dout[1][33:17];
        wr_din[1][33:17] <= rd_dout[1][33:17];
      end
    end else if (state == ST_CRT) begin
      if (stage_wr[2] == 0) begin
        wr_din[0][33:17] <= out_a[1];
        wr_din[1][33:17] <= out_a[1];
      end else begin
        wr_din[0][33:17] <= mod4591_out;
        wr_din[1][33:17] <= mod4591_out;
      end
    end else begin
      wr_din[0][33:17] <= out_a[1];
      wr_din[1][33:17] <= out_a[1];
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
        in_b[0] <= $signed(rd_dout[0][16:0]);
        in_b[1] <= $signed(rd_dout[0][33:17]);
      end else begin
        in_b[0] <= $signed(rd_dout[1][16:0]);
        in_b[1] <= $signed(rd_dout[1][33:17]);
      end
    end else if (state == ST_CRT) begin
      if (bank_index_rd_shift_2) begin
        in_b[0] <= $signed(rd_dout[0][16:0]);
        in_b[1] <= $signed(rd_dout[0][33:17]);
      end else begin
        in_b[0] <= $signed(rd_dout[1][16:0]);
        in_b[1] <= $signed(rd_dout[1][33:17]);
      end
    end else begin // ST_PMUL
      in_b[0] <= $signed(rd_dout[1][16:0]);
      in_b[1] <= $signed(rd_dout[1][33:17]);
    end

    if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_rd_shift_2) begin
        in_a[0] <= $signed(rd_dout[1][16:0]);
        in_a[1] <= $signed(rd_dout[1][33:17]);
      end else begin
        in_a[0] <= $signed(rd_dout[0][16:0]);
        in_a[1] <= $signed(rd_dout[0][33:17]);
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
      w_addr_in <= 512 - w_addr;
    end

    if (state == ST_PMUL) begin
        in_w[0] <= rd_dout[0][16:0];
        in_w[1] <= rd_dout[0][33:17];
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
      wr_ctr[0] <= addr[8:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7], ctr_shift_1[8]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[7:0]};
    end else if (state == ST_PMUL) begin
      wr_ctr[0] <= ctr_pmul_shift_2[8:0];
    end else begin
      wr_ctr[0] <= ctr_shift_7[8:0];
    end

    wr_ctr[1] <= {1'b1, ctr_shift_7[7:0]};
  end

  // ctr_MSB_masked
  always @ (*) begin
    if (state == ST_NTT || state == ST_INTT) begin
      ctr_MSB_masked = 0;
    end else begin
      ctr_MSB_masked = ctr[8];
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
      end else if (ctr_shift_7[7:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_3[8:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[8:0] == 0 && stage != 0) begin
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
        stage_bit[7 : 1] <= stage_bit[6 : 0];
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
  input      [ 7: 0] stage_bit;
  input      [ 7: 0] ctr;
  output reg [ 7: 0] w_addr;

  wire [ 7: 0] w;

  assign w[ 0] = (stage_bit[ 0]) ? ctr[ 0] : 0;
  assign w[ 1] = (stage_bit[ 1]) ? ctr[ 1] : 0;
  assign w[ 2] = (stage_bit[ 2]) ? ctr[ 2] : 0;
  assign w[ 3] = (stage_bit[ 3]) ? ctr[ 3] : 0;
  assign w[ 4] = (stage_bit[ 4]) ? ctr[ 4] : 0;
  assign w[ 5] = (stage_bit[ 5]) ? ctr[ 5] : 0;
  assign w[ 6] = (stage_bit[ 6]) ? ctr[ 6] : 0;
  assign w[ 7] = (stage_bit[ 7]) ? ctr[ 7] : 0;

  always @ ( posedge clk ) begin
    w_addr <= {w[0], w[1], w[2], w[3], w[4], w[5], w[6], w[7]};
  end

endmodule

module addr_gen ( clk, stage, ctr, bank_index, data_index );

  input              clk;
  input      [3 : 0] stage;
  input      [8 : 0] ctr;
  output reg         bank_index;
  output reg [7 : 0] data_index;

  wire       [8 : 0] bs_out;

  barrel_shifter bs ( clk, ctr, stage, bs_out );

    always @( posedge clk ) begin
        bank_index <= ^bs_out;
    end

    always @( posedge clk ) begin
        data_index <= bs_out[8:1];
    end

endmodule

module barrel_shifter ( clk, in, shift, out );

  input              clk;
  input      [8 : 0] in;
  input      [3 : 0] shift;
  output reg [8 : 0] out;

  reg        [8 : 0] in_s [0:4];

  always @ (*) begin
    in_s[0] = in;
  end

  always @ (*) begin
    if(shift[0]) begin
      in_s[1] = { in_s[0][0], in_s[0][8:1] };
    end else begin
      in_s[1] = in_s[0];
    end
  end

  always @ (*) begin
    if(shift[1]) begin
      in_s[2] = { in_s[1][1:0], in_s[1][8:2] };
    end else begin
      in_s[2] = in_s[1];
    end
  end

  always @ (*) begin
    if(shift[2]) begin
      in_s[3] = { in_s[2][3:0], in_s[2][8:4] };
    end else begin
      in_s[3] = in_s[2];
    end
  end

  always @ (*) begin
    if(shift[3]) begin
      in_s[4] = { in_s[3][7:0], in_s[3][8] };
    end else begin
      in_s[4] = in_s[3];
    end
  end

  always @ ( posedge clk ) begin
    out <= in_s[4];
  end

endmodule

module bfu_114689 ( clk, state, acc, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input                      acc;
  input      signed [16 : 0] in_a;
  input      signed [16 : 0] in_b;
  input      signed [16 : 0] w;
  output reg signed [32 : 0] bw;
  output reg signed [16 : 0] out_a;
  output reg signed [16 : 0] out_b;

  wire signed       [16 : 0] mod_bw;
  reg signed        [18 : 0] a, b;
  reg signed        [16 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  wire signed       [17 : 0] a_mux;
  reg signed        [32 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [17 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul114689s mod114689s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd114689;
  assign a_sub_q = a - 'sd114689;
  assign b_add_q = b + 'sd114689;
  assign b_sub_q = b - 'sd114689;

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
      if (a > 'sd57344) begin
        out_a <= a_sub_q;
      end else if (a < -'sd57344) begin
        out_a <= a_add_q;
      end else begin
        out_a <= a;
      end
    end else begin
      if (a[0] == 0) begin
        out_a <= a[17:1];
      end else if (a[17] == 0) begin // a > 0
        out_a <= a_sub_q[17:1];
      end else begin                 // a < 0
        out_a <= a_add_q[17:1];
      end
    end

    if (state == 0) begin
      if (b > 'sd57344) begin
        out_b <= b_sub_q;
      end else if (b < -'sd57344) begin
        out_b <= b_add_q;
      end else begin
        out_b <= b;
      end
    end else begin
      if (b[0] == 0) begin
        out_b <= b[17:1];
      end else if (b[17] == 0) begin // b > 0
        out_b <= b_sub_q[17:1];
      end else begin                 // b < 0
        out_b <= b_add_q[17:1];
      end
    end
  end

endmodule

module w_114689 ( clk, addr, dout );

  input                       clk;
  input             [ 8 : 0]  addr;
  output signed     [16 : 0]  dout;

  wire signed       [16 : 0]  dout_p;
  wire signed       [16 : 0]  dout_n;
  reg               [ 8 : 0]  addr_reg;

  (* rom_style = "distributed" *) reg signed [16:0] data [0:255];

  assign dout_p = data[addr_reg[7:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[8] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[  0] =  'sd1;
    data[  1] =  'sd1107;
    data[  2] = -'sd36130;
    data[  3] =  'sd30551;
    data[  4] = -'sd13298;
    data[  5] = -'sd40694;
    data[  6] =  'sd24519;
    data[  7] = -'sd38760;
    data[  8] = -'sd13634;
    data[  9] =  'sd46110;
    data[ 10] =  'sd7165;
    data[ 11] =  'sd18114;
    data[ 12] = -'sd18377;
    data[ 13] = -'sd43386;
    data[ 14] =  'sd26389;
    data[ 15] = -'sd33072;
    data[ 16] = -'sd24913;
    data[ 17] = -'sd53331;
    data[ 18] =  'sd27418;
    data[ 19] = -'sd40859;
    data[ 20] = -'sd43447;
    data[ 21] = -'sd41138;
    data[ 22] = -'sd8233;
    data[ 23] = -'sd53500;
    data[ 24] = -'sd44976;
    data[ 25] = -'sd13406;
    data[ 26] = -'sd45561;
    data[ 27] =  'sd27133;
    data[ 28] = -'sd12287;
    data[ 29] =  'sd46282;
    data[ 30] = -'sd31809;
    data[ 31] = -'sd3040;
    data[ 32] = -'sd39299;
    data[ 33] = -'sd36862;
    data[ 34] =  'sd23050;
    data[ 35] =  'sd55392;
    data[ 36] = -'sd39671;
    data[ 37] =  'sd10090;
    data[ 38] =  'sd44797;
    data[ 39] =  'sd44631;
    data[ 40] = -'sd24442;
    data[ 41] =  'sd9310;
    data[ 42] = -'sd15840;
    data[ 43] =  'sd12537;
    data[ 44] =  'sd1090;
    data[ 45] = -'sd54949;
    data[ 46] = -'sd43373;
    data[ 47] =  'sd40780;
    data[ 48] = -'sd44006;
    data[ 49] =  'sd28183;
    data[ 50] =  'sd3173;
    data[ 51] = -'sd42848;
    data[ 52] =  'sd48510;
    data[ 53] =  'sd26118;
    data[ 54] =  'sd10998;
    data[ 55] =  'sd17752;
    data[ 56] =  'sd39645;
    data[ 57] = -'sd38872;
    data[ 58] = -'sd22929;
    data[ 59] = -'sd36134;
    data[ 60] =  'sd26123;
    data[ 61] =  'sd16533;
    data[ 62] = -'sd48209;
    data[ 63] = -'sd36978;
    data[ 64] =  'sd9327;
    data[ 65] =  'sd2979;
    data[ 66] = -'sd28228;
    data[ 67] = -'sd52988;
    data[ 68] = -'sd51637;
    data[ 69] = -'sd47037;
    data[ 70] = -'sd1153;
    data[ 71] = -'sd14792;
    data[ 72] =  'sd25783;
    data[ 73] = -'sd15780;
    data[ 74] = -'sd35732;
    data[ 75] =  'sd12381;
    data[ 76] = -'sd56913;
    data[ 77] = -'sd38430;
    data[ 78] =  'sd7609;
    data[ 79] =  'sd50866;
    data[ 80] = -'sd3637;
    data[ 81] = -'sd12044;
    data[ 82] = -'sd28784;
    data[ 83] =  'sd19654;
    data[ 84] = -'sd33932;
    data[ 85] =  'sd55268;
    data[ 86] =  'sd52439;
    data[ 87] =  'sd17339;
    data[ 88] =  'sd41210;
    data[ 89] = -'sd26752;
    data[ 90] = -'sd24702;
    data[ 91] = -'sd49132;
    data[ 92] = -'sd26538;
    data[ 93] = -'sd17182;
    data[ 94] =  'sd17900;
    data[ 95] = -'sd25897;
    data[ 96] =  'sd4271;
    data[ 97] =  'sd25748;
    data[ 98] = -'sd54525;
    data[ 99] = -'sd32761;
    data[100] = -'sd24703;
    data[101] = -'sd50239;
    data[102] =  'sd9592;
    data[103] = -'sd47733;
    data[104] =  'sd31198;
    data[105] =  'sd14797;
    data[106] = -'sd20248;
    data[107] = -'sd50181;
    data[108] = -'sd40891;
    data[109] =  'sd35818;
    data[110] = -'sd31868;
    data[111] =  'sd46336;
    data[112] =  'sd27969;
    data[113] = -'sd4347;
    data[114] =  'sd4809;
    data[115] =  'sd47869;
    data[116] =  'sd4665;
    data[117] =  'sd3150;
    data[118] =  'sd46380;
    data[119] = -'sd38012;
    data[120] =  'sd11579;
    data[121] = -'sd27215;
    data[122] =  'sd36202;
    data[123] =  'sd49153;
    data[124] =  'sd49785;
    data[125] = -'sd53414;
    data[126] =  'sd50226;
    data[127] = -'sd23983;
    data[128] = -'sd56022;
    data[129] =  'sd30395;
    data[130] =  'sd43388;
    data[131] = -'sd24175;
    data[132] = -'sd39188;
    data[133] = -'sd28674;
    data[134] =  'sd26735;
    data[135] =  'sd5883;
    data[136] = -'sd24792;
    data[137] = -'sd34073;
    data[138] =  'sd13870;
    data[139] = -'sd14236;
    data[140] = -'sd46859;
    data[141] = -'sd33485;
    data[142] = -'sd23348;
    data[143] = -'sd41211;
    data[144] =  'sd25645;
    data[145] = -'sd53857;
    data[146] =  'sd18581;
    data[147] =  'sd39836;
    data[148] = -'sd56813;
    data[149] = -'sd42419;
    data[150] = -'sd50032;
    data[151] =  'sd9363;
    data[152] =  'sd42831;
    data[153] =  'sd47360;
    data[154] =  'sd14647;
    data[155] =  'sd43080;
    data[156] = -'sd21064;
    data[157] = -'sd35981;
    data[158] = -'sd33884;
    data[159] = -'sd6285;
    data[160] =  'sd38534;
    data[161] = -'sd7170;
    data[162] = -'sd23649;
    data[163] = -'sd30351;
    data[164] =  'sd5320;
    data[165] =  'sd40101;
    data[166] =  'sd7164;
    data[167] =  'sd17007;
    data[168] =  'sd17753;
    data[169] =  'sd40752;
    data[170] =  'sd39687;
    data[171] =  'sd7622;
    data[172] = -'sd49432;
    data[173] = -'sd14571;
    data[174] =  'sd41052;
    data[175] =  'sd27720;
    data[176] = -'sd50612;
    data[177] =  'sd55437;
    data[178] =  'sd10144;
    data[179] = -'sd10114;
    data[180] =  'sd43324;
    data[181] =  'sd19666;
    data[182] = -'sd20648;
    data[183] = -'sd34225;
    data[184] = -'sd39705;
    data[185] = -'sd27548;
    data[186] =  'sd11638;
    data[187] =  'sd38098;
    data[188] = -'sd31066;
    data[189] =  'sd16638;
    data[190] = -'sd46663;
    data[191] = -'sd45891;
    data[192] =  'sd5890;
    data[193] = -'sd17043;
    data[194] =  'sd57084;
    data[195] = -'sd1651;
    data[196] =  'sd7367;
    data[197] =  'sd12350;
    data[198] =  'sd23459;
    data[199] =  'sd49399;
    data[200] = -'sd21960;
    data[201] =  'sd4348;
    data[202] = -'sd3702;
    data[203] =  'sd30690;
    data[204] =  'sd25886;
    data[205] = -'sd16448;
    data[206] =  'sd27615;
    data[207] = -'sd52158;
    data[208] = -'sd50339;
    data[209] =  'sd13581;
    data[210] =  'sd9908;
    data[211] = -'sd41988;
    data[212] = -'sd31671;
    data[213] =  'sd35037;
    data[214] =  'sd21077;
    data[215] =  'sd50372;
    data[216] =  'sd22950;
    data[217] = -'sd55308;
    data[218] =  'sd17970;
    data[219] =  'sd51593;
    data[220] = -'sd1671;
    data[221] = -'sd14773;
    data[222] =  'sd46816;
    data[223] = -'sd14116;
    data[224] = -'sd28708;
    data[225] = -'sd10903;
    data[226] = -'sd27276;
    data[227] = -'sd31325;
    data[228] = -'sd40697;
    data[229] =  'sd21198;
    data[230] = -'sd45059;
    data[231] =  'sd9402;
    data[232] = -'sd28685;
    data[233] =  'sd14558;
    data[234] = -'sd55443;
    data[235] = -'sd16786;
    data[236] = -'sd2484;
    data[237] =  'sd2748;
    data[238] = -'sd54567;
    data[239] =  'sd35434;
    data[240] =  'sd1800;
    data[241] =  'sd42887;
    data[242] = -'sd5337;
    data[243] =  'sd55769;
    data[244] =  'sd33601;
    data[245] =  'sd37071;
    data[246] = -'sd21065;
    data[247] = -'sd37088;
    data[248] =  'sd2246;
    data[249] = -'sd36836;
    data[250] =  'sd51832;
    data[251] =  'sd33524;
    data[252] = -'sd48168;
    data[253] =  'sd8409;
    data[254] =  'sd18954;
    data[255] = -'sd6009;
  end

endmodule

module bfu_120833 ( clk, state, acc, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input                      acc;
  input      signed [16 : 0] in_a;
  input      signed [16 : 0] in_b;
  input      signed [16 : 0] w;
  output reg signed [32 : 0] bw;
  output reg signed [16 : 0] out_a;
  output reg signed [16 : 0] out_b;

  wire signed       [16 : 0] mod_bw;
  reg signed        [18 : 0] a, b;
  reg signed        [16 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  wire signed       [17 : 0] a_mux;
  reg signed        [32 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [17 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul120833s mod120833s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd120833;
  assign a_sub_q = a - 'sd120833;
  assign b_add_q = b + 'sd120833;
  assign b_sub_q = b - 'sd120833;

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
      if (a > 'sd60416) begin
        out_a <= a_sub_q;
      end else if (a < -'sd60416) begin
        out_a <= a_add_q;
      end else begin
        out_a <= a;
      end
    end else begin
      if (a[0] == 0) begin
        out_a <= a[17:1];
      end else if (a[17] == 0) begin // a > 0
        out_a <= a_sub_q[17:1];
      end else begin                 // a < 0
        out_a <= a_add_q[17:1];
      end
    end

    if (state == 0) begin
      if (b > 'sd60416) begin
        out_b <= b_sub_q;
      end else if (b < -'sd60416) begin
        out_b <= b_add_q;
      end else begin
        out_b <= b;
      end
    end else begin
      if (b[0] == 0) begin
        out_b <= b[17:1];
      end else if (b[17] == 0) begin // b > 0
        out_b <= b_sub_q[17:1];
      end else begin                 // b < 0
        out_b <= b_add_q[17:1];
      end
    end
  end

endmodule

module w_120833 ( clk, addr, dout );

  input                       clk;
  input             [ 8 : 0]  addr;
  output signed     [16 : 0]  dout;

  wire signed       [16 : 0]  dout_p;
  wire signed       [16 : 0]  dout_n;
  reg               [ 8 : 0]  addr_reg;

  (* rom_style = "distributed" *) reg signed [16:0] data [0:255];

  assign dout_p = data[addr_reg[7:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[8] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[  0] =  'sd1;
    data[  1] =  'sd133;
    data[  2] =  'sd17689;
    data[  3] =  'sd56810;
    data[  4] = -'sd56749;
    data[  5] = -'sd55971;
    data[  6] =  'sd47503;
    data[  7] =  'sd34583;
    data[  8] =  'sd7885;
    data[  9] = -'sd38792;
    data[ 10] =  'sd36483;
    data[ 11] =  'sd18919;
    data[ 12] = -'sd21266;
    data[ 13] = -'sd49219;
    data[ 14] = -'sd21145;
    data[ 15] = -'sd33126;
    data[ 16] = -'sd55770;
    data[ 17] = -'sd46597;
    data[ 18] = -'sd34918;
    data[ 19] = -'sd52440;
    data[ 20] =  'sd33794;
    data[ 21] =  'sd23781;
    data[ 22] =  'sd21215;
    data[ 23] =  'sd42436;
    data[ 24] = -'sd35163;
    data[ 25] =  'sd35808;
    data[ 26] =  'sd49977;
    data[ 27] =  'sd1126;
    data[ 28] =  'sd28925;
    data[ 29] = -'sd19631;
    data[ 30] =  'sd47403;
    data[ 31] =  'sd21283;
    data[ 32] =  'sd51480;
    data[ 33] = -'sd40641;
    data[ 34] =  'sd32232;
    data[ 35] =  'sd57701;
    data[ 36] = -'sd59079;
    data[ 37] = -'sd3362;
    data[ 38] =  'sd36186;
    data[ 39] = -'sd20582;
    data[ 40] =  'sd41753;
    data[ 41] = -'sd5169;
    data[ 42] =  'sd37521;
    data[ 43] =  'sd36140;
    data[ 44] = -'sd26700;
    data[ 45] = -'sd46943;
    data[ 46] =  'sd39897;
    data[ 47] = -'sd10351;
    data[ 48] = -'sd47520;
    data[ 49] = -'sd36844;
    data[ 50] =  'sd53901;
    data[ 51] =  'sd39686;
    data[ 52] = -'sd38414;
    data[ 53] = -'sd34076;
    data[ 54] =  'sd59546;
    data[ 55] = -'sd55360;
    data[ 56] =  'sd7933;
    data[ 57] = -'sd32408;
    data[ 58] =  'sd39724;
    data[ 59] = -'sd33360;
    data[ 60] =  'sd33941;
    data[ 61] =  'sd43332;
    data[ 62] = -'sd36828;
    data[ 63] =  'sd56029;
    data[ 64] = -'sd39789;
    data[ 65] =  'sd24715;
    data[ 66] =  'sd24604;
    data[ 67] =  'sd9841;
    data[ 68] = -'sd20310;
    data[ 69] = -'sd42904;
    data[ 70] = -'sd27081;
    data[ 71] =  'sd23217;
    data[ 72] = -'sd53797;
    data[ 73] = -'sd25854;
    data[ 74] = -'sd55258;
    data[ 75] =  'sd21499;
    data[ 76] = -'sd40625;
    data[ 77] =  'sd34360;
    data[ 78] = -'sd21774;
    data[ 79] =  'sd4050;
    data[ 80] =  'sd55318;
    data[ 81] = -'sd13519;
    data[ 82] =  'sd14468;
    data[ 83] = -'sd9084;
    data[ 84] =  'sd158;
    data[ 85] =  'sd21014;
    data[ 86] =  'sd15703;
    data[ 87] =  'sd34338;
    data[ 88] = -'sd24700;
    data[ 89] = -'sd22609;
    data[ 90] =  'sd13828;
    data[ 91] =  'sd26629;
    data[ 92] =  'sd37500;
    data[ 93] =  'sd33347;
    data[ 94] = -'sd35670;
    data[ 95] = -'sd31623;
    data[ 96] =  'sd23296;
    data[ 97] = -'sd43290;
    data[ 98] =  'sd42414;
    data[ 99] = -'sd38089;
    data[100] =  'sd9149;
    data[101] =  'sd8487;
    data[102] =  'sd41274;
    data[103] =  'sd51957;
    data[104] =  'sd22800;
    data[105] =  'sd11575;
    data[106] = -'sd31354;
    data[107] =  'sd59073;
    data[108] =  'sd2564;
    data[109] = -'sd21487;
    data[110] =  'sd42221;
    data[111] =  'sd57075;
    data[112] = -'sd21504;
    data[113] =  'sd39960;
    data[114] = -'sd1972;
    data[115] = -'sd20610;
    data[116] =  'sd38029;
    data[117] = -'sd17129;
    data[118] =  'sd17670;
    data[119] =  'sd54283;
    data[120] = -'sd30341;
    data[121] = -'sd47864;
    data[122] =  'sd38237;
    data[123] =  'sd10535;
    data[124] = -'sd48841;
    data[125] =  'sd29129;
    data[126] =  'sd7501;
    data[127] =  'sd30969;
    data[128] =  'sd10555;
    data[129] = -'sd46181;
    data[130] =  'sd20410;
    data[131] =  'sd56204;
    data[132] = -'sd16514;
    data[133] = -'sd21368;
    data[134] =  'sd58048;
    data[135] = -'sd12928;
    data[136] = -'sd27762;
    data[137] =  'sd53477;
    data[138] = -'sd16706;
    data[139] = -'sd46904;
    data[140] =  'sd45084;
    data[141] = -'sd45478;
    data[142] = -'sd6924;
    data[143] =  'sd45772;
    data[144] =  'sd46026;
    data[145] = -'sd41025;
    data[146] = -'sd18840;
    data[147] =  'sd31773;
    data[148] = -'sd3346;
    data[149] =  'sd38314;
    data[150] =  'sd20776;
    data[151] = -'sd15951;
    data[152] =  'sd53511;
    data[153] = -'sd12184;
    data[154] = -'sd49643;
    data[155] =  'sd43296;
    data[156] = -'sd41616;
    data[157] =  'sd23390;
    data[158] = -'sd30788;
    data[159] =  'sd13518;
    data[160] = -'sd14601;
    data[161] = -'sd8605;
    data[162] = -'sd56968;
    data[163] =  'sd35735;
    data[164] =  'sd40268;
    data[165] =  'sd38992;
    data[166] = -'sd9883;
    data[167] =  'sd14724;
    data[168] =  'sd24964;
    data[169] =  'sd57721;
    data[170] = -'sd56419;
    data[171] = -'sd12081;
    data[172] = -'sd35944;
    data[173] =  'sd52768;
    data[174] =  'sd9830;
    data[175] = -'sd21773;
    data[176] =  'sd4183;
    data[177] = -'sd47826;
    data[178] =  'sd43291;
    data[179] = -'sd42281;
    data[180] =  'sd55778;
    data[181] =  'sd47661;
    data[182] =  'sd55597;
    data[183] =  'sd23588;
    data[184] = -'sd4454;
    data[185] =  'sd11783;
    data[186] = -'sd3690;
    data[187] = -'sd7438;
    data[188] = -'sd22590;
    data[189] =  'sd16355;
    data[190] =  'sd221;
    data[191] =  'sd29393;
    data[192] =  'sd42613;
    data[193] = -'sd11622;
    data[194] =  'sd25103;
    data[195] = -'sd44625;
    data[196] = -'sd14308;
    data[197] =  'sd30364;
    data[198] =  'sd50923;
    data[199] =  'sd6111;
    data[200] = -'sd33068;
    data[201] = -'sd48056;
    data[202] =  'sd12701;
    data[203] = -'sd2429;
    data[204] =  'sd39442;
    data[205] =  'sd49967;
    data[206] = -'sd204;
    data[207] = -'sd27132;
    data[208] =  'sd16434;
    data[209] =  'sd10728;
    data[210] = -'sd23172;
    data[211] =  'sd59782;
    data[212] = -'sd23972;
    data[213] = -'sd46618;
    data[214] = -'sd37711;
    data[215] =  'sd59423;
    data[216] =  'sd49114;
    data[217] =  'sd7180;
    data[218] = -'sd11724;
    data[219] =  'sd11537;
    data[220] = -'sd36408;
    data[221] = -'sd8944;
    data[222] =  'sd18778;
    data[223] = -'sd40019;
    data[224] = -'sd5875;
    data[225] = -'sd56377;
    data[226] = -'sd6495;
    data[227] = -'sd18004;
    data[228] =  'sd22128;
    data[229] =  'sd43032;
    data[230] =  'sd44105;
    data[231] = -'sd54852;
    data[232] = -'sd45336;
    data[233] =  'sd11962;
    data[234] =  'sd20117;
    data[235] =  'sd17235;
    data[236] = -'sd3572;
    data[237] =  'sd8256;
    data[238] =  'sd10551;
    data[239] = -'sd46713;
    data[240] = -'sd50346;
    data[241] = -'sd50203;
    data[242] = -'sd31184;
    data[243] = -'sd39150;
    data[244] = -'sd11131;
    data[245] = -'sd30427;
    data[246] = -'sd59302;
    data[247] = -'sd33021;
    data[248] = -'sd41805;
    data[249] = -'sd1747;
    data[250] =  'sd9315;
    data[251] =  'sd30565;
    data[252] = -'sd43177;
    data[253] =  'sd57443;
    data[254] =  'sd27440;
    data[255] =  'sd24530;
  end

endmodule

