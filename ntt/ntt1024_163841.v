module ntt1024_163841 ( clk, rst, start, input_fg, addr, din, dout, valid );

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
  input             [10 : 0] addr;
  input signed      [17 : 0] din;
  output reg signed [17 : 0] dout;
  output reg                 valid;

  // BRAM
  reg            wr_en   [0 : 1];
  reg   [10 : 0] wr_addr [0 : 1];
  reg   [10 : 0] rd_addr [0 : 1];
  reg   [17 : 0] wr_din  [0 : 1];
  wire  [17 : 0] rd_dout [0 : 1];
  wire  [17 : 0] wr_dout [0 : 1];

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
  reg  [11 : 0] ctr;
  reg  [11 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_1, ctr_shift_2;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, stage_rd_end, stage_rd_2, stage_wr_end, ntt_end, point_proc_end, reduce_end;

  // w_array
  reg         [10: 0] w_addr_in;
  wire signed [17: 0] w_dout ;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [10: 0] wr_ctr [0 : 1];
  reg [17: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [10: 0] w_addr_in_shift_1;

  // BRAM instances
  bram_18_11_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_18_11_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[9:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[9:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[9:0], w_addr);

  // Butterfly Unit  , each with a corresponding omega array
  bfu_163841 bfu_inst (clk, ntt_state, in_a, in_b, in_w, bw, out_a, out_b);
  w_163841 rom_w_inst (clk, w_addr_in_shift_1, w_dout);

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
      w_addr_in <= 2048 - w_addr;
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

