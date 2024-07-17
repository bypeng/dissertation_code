module ntt512_163841 ( clk, rst, start, input_fg, addr, din, dout, valid );

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
  input             [9 : 0] addr;
  input signed      [17 : 0] din;
  output reg signed [17 : 0] dout;
  output reg                 valid;

  // BRAM
  reg            wr_en   [0 : 1];
  reg   [9  : 0] wr_addr [0 : 1];
  reg   [9  : 0] rd_addr [0 : 1];
  reg   [17 : 0] wr_din  [0 : 1];
  wire  [17 : 0] rd_dout [0 : 1];
  wire  [17 : 0] wr_dout [0 : 1];

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
  reg  [10 : 0] ctr;
  reg  [10 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_1, ctr_shift_2;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, stage_rd_end, stage_rd_2, stage_wr_end, ntt_end, point_proc_end, reduce_end;

  // w_array
  reg         [9 : 0] w_addr_in;
  wire signed [17: 0] w_dout ;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [9 : 0] wr_ctr [0 : 1];
  reg [17: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [9 : 0] w_addr_in_shift_1;

  // BRAM instances
  bram_18_10_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_18_10_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[8:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[8:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[8:0], w_addr);

  // Butterfly Unit  , each with a corresponding omega array
  bfu_163841 bfu_inst (clk, ntt_state, in_a, in_b, in_w, bw, out_a, out_b);
  w_163841 rom_w_inst (clk, w_addr_in_shift_1, w_dout);

  assign ctr_half_end         = (ctr[8:0] == 511) ? 1 : 0;
  assign ctr_full_end         = (ctr[9:0] == 1023) ? 1 : 0;
  assign stage_rd_end         = (stage == 10) ? 1 : 0;
  assign stage_rd_2           = (stage == 2) ? 1 : 0;
  assign ntt_end         = (stage_rd_end && ctr[8 : 0] == 10) ? 1 : 0;
  assign crt_end         = (stage_rd_2 && ctr[8 : 0] == 10) ? 1 : 0;
  assign point_proc_end   = (ctr == 1034) ? 1 : 0;
  assign reload_end      = (stage != 0 && ctr[8:0] == 4) ? 1 : 0;
  assign reduce_end      = (ctr == 1028);

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

    if (state == ST_NTT)  begin
      rd_addr[0][9] <= poly_select;
      rd_addr[1][9] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][9] <=  bank_index_rd[0];
      rd_addr[1][9] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][9] <= 0;
      rd_addr[1][9] <= 0;
    end else begin
      rd_addr[0][9] <= 1;
      rd_addr[1][9] <= 1;
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

    if (state == ST_IDLE) begin
      wr_addr[0][9] <= fg_shift_3;
      wr_addr[1][9] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][9] <= poly_select;
      wr_addr[1][9] <= poly_select;
    end else if (state == ST_PMUL || state == ST_REDUCE || state == ST_FINISH) begin
      wr_addr[0][9] <= 0;
      wr_addr[1][9] <= 0;
    end else begin
      wr_addr[0][9] <= 1;
      wr_addr[1][9] <= 1;
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
      w_addr_in <= 1024 - w_addr;
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
      wr_ctr[0] <= addr[9:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7], ctr_shift_1[8], ctr_shift_1[9]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[8:0]};
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
      end else if (ctr_shift_7[8:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[9:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[9:0] == 0 && stage != 0) begin
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

