module ntt2048_163841 ( clk, rst, start, input_fg, addr, din, dout, valid );

  localparam Q0 = 163841;

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
  input signed      [17 : 0] din;
  output reg signed [17 : 0] dout;
  output reg                 valid;

  // BRAM
  reg            wr_en   [0 : 1];
  reg   [11 : 0] wr_addr [0 : 1];
  reg   [11 : 0] rd_addr [0 : 1];
  reg   [17 : 0] wr_din  [0 : 1];
  wire  [17 : 0] rd_dout [0 : 1];
  wire  [17 : 0] wr_dout [0 : 1];

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
  reg  signed [17: 0] in_a  ;
  reg  signed [17: 0] in_b  ;
  reg  signed [17: 0] in_w  ;
  wire signed [35: 0] bw    ;
  wire signed [17: 0] out_a ;
  wire signed [17: 0] out_b ;

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
  wire signed [17: 0] w_dout ;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [11: 0] wr_ctr [0 : 1];
  reg [17: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [11: 0] w_addr_in_shift_1;

  // BRAM instances
  bram_18_12_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_18_12_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[10:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[10:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[10:0], w_addr);

  // Butterfly Unit  , each with a corresponding omega array
  bfu_163841 bfu_inst (clk, ntt_state, in_a, in_b, in_w, bw, out_a, out_b);
  w_163841 rom_w_inst (clk, w_addr_in_shift_1, w_dout);

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
        dout <= wr_dout[1][17:0];
      end else begin
        dout <= wr_dout[0][17:0];
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
      wr_din[0][17:0] <= { din_shift_3 };
      wr_din[1][17:0] <= { din_shift_3 };
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_din[0][17:0] <= out_b;
        wr_din[1][17:0] <= out_a;
      end else begin
        wr_din[0][17:0] <= out_a;
        wr_din[1][17:0] <= out_b;
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
    end else begin
      wr_din[0][17:0] <= out_a;
      wr_din[1][17:0] <= out_a;
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
        in_b <= $signed(rd_dout[0]);
      end else begin
        in_b <= $signed(rd_dout[1]);
      end
    end else if (state == ST_CRT) begin
      if (bank_index_rd_shift_2) begin
        in_b <= $signed(rd_dout[0]);
      end else begin
        in_b <= $signed(rd_dout[1]);
      end
    end else begin // ST_PMUL
      in_b <= $signed(rd_dout[1]);
    end

    if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_rd_shift_2) begin
        in_a <= $signed(rd_dout[1]);
      end else begin
        in_a <= $signed(rd_dout[0]);
      end
    end else begin // ST_PMUL, ST_CRT
      in_a <= 'sd0;
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
        in_w <= rd_dout[0];
    end else begin
      in_w <= w_dout;
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
        next_state = ST_REDUCE;
      else
        next_state = ST_INTT;
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

