module ntt256_163841 ( clk, rst, start, input_fg, addr, din, dout, valid );

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
  input             [8 : 0] addr;
  input signed      [17 : 0] din;
  output reg signed [17 : 0] dout;
  output reg                 valid;

  // BRAM
  reg            wr_en   [0 : 1];
  reg   [8  : 0] wr_addr [0 : 1];
  reg   [8  : 0] rd_addr [0 : 1];
  reg   [17 : 0] wr_din  [0 : 1];
  wire  [17 : 0] rd_dout [0 : 1];
  wire  [17 : 0] wr_dout [0 : 1];

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
  reg  [9 : 0] ctr;
  reg  [9 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_1, ctr_shift_2;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, stage_rd_end, stage_rd_2, stage_wr_end, ntt_end, point_proc_end, reduce_end;

  // w_array
  reg         [8 : 0] w_addr_in;
  wire signed [17: 0] w_dout ;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [8 : 0] wr_ctr [0 : 1];
  reg [17: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [8 : 0] w_addr_in_shift_1;

  // BRAM instances
  bram_18_9_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_18_9_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[7:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[7:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[7:0], w_addr);

  // Butterfly Unit  , each with a corresponding omega array
  bfu_163841 bfu_inst (clk, ntt_state, in_a, in_b, in_w, bw, out_a, out_b);
  w_163841 rom_w_inst (clk, w_addr_in_shift_1, w_dout);

  assign ctr_half_end         = (ctr[7:0] == 255) ? 1 : 0;
  assign ctr_full_end         = (ctr[8:0] == 511) ? 1 : 0;
  assign stage_rd_end         = (stage == 9) ? 1 : 0;
  assign stage_rd_2           = (stage == 2) ? 1 : 0;
  assign ntt_end         = (stage_rd_end && ctr[7 : 0] == 10) ? 1 : 0;
  assign crt_end         = (stage_rd_2 && ctr[7 : 0] == 10) ? 1 : 0;
  assign point_proc_end   = (ctr == 522) ? 1 : 0;
  assign reload_end      = (stage != 0 && ctr[7:0] == 4) ? 1 : 0;
  assign reduce_end      = (ctr == 516);

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

    if (state == ST_NTT)  begin
      rd_addr[0][8] <= poly_select;
      rd_addr[1][8] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][8] <=  bank_index_rd[0];
      rd_addr[1][8] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][8] <= 0;
      rd_addr[1][8] <= 0;
    end else begin
      rd_addr[0][8] <= 1;
      rd_addr[1][8] <= 1;
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

    if (state == ST_IDLE) begin
      wr_addr[0][8] <= fg_shift_3;
      wr_addr[1][8] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][8] <= poly_select;
      wr_addr[1][8] <= poly_select;
    end else if (state == ST_PMUL || state == ST_REDUCE || state == ST_FINISH) begin
      wr_addr[0][8] <= 0;
      wr_addr[1][8] <= 0;
    end else begin
      wr_addr[0][8] <= 1;
      wr_addr[1][8] <= 1;
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
      w_addr_in <= 512 - w_addr;
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
      wr_ctr[0] <= addr[8:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7], ctr_shift_1[8]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[7:0]};
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
      end else if (ctr_shift_7[7:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[8:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[8:0] == 0 && stage != 0) begin
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
  input             [ 8 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [ 8 : 0]  addr_reg;

  (* rom_style = "distributed" *) reg signed [17:0] data [0:255];

  assign dout_p = data[addr_reg[7:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[8] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[  0] =  'sd1;
    data[  1] =  'sd143;
    data[  2] =  'sd20449;
    data[  3] = -'sd24931;
    data[  4] =  'sd39369;
    data[  5] =  'sd59173;
    data[  6] = -'sd57993;
    data[  7] =  'sd62892;
    data[  8] = -'sd17699;
    data[  9] = -'sd73342;
    data[ 10] = -'sd2082;
    data[ 11] =  'sd29956;
    data[ 12] =  'sd23842;
    data[ 13] = -'sd31255;
    data[ 14] = -'sd45758;
    data[ 15] =  'sd10246;
    data[ 16] = -'sd9391;
    data[ 17] = -'sd32185;
    data[ 18] = -'sd14907;
    data[ 19] = -'sd1768;
    data[ 20] =  'sd74858;
    data[ 21] =  'sd55029;
    data[ 22] =  'sd4779;
    data[ 23] =  'sd28033;
    data[ 24] =  'sd76535;
    data[ 25] = -'sd32842;
    data[ 26] =  'sd54983;
    data[ 27] = -'sd1799;
    data[ 28] =  'sd70425;
    data[ 29] =  'sd76474;
    data[ 30] = -'sd41565;
    data[ 31] = -'sd45519;
    data[ 32] =  'sd44423;
    data[ 33] = -'sd37310;
    data[ 34] =  'sd71423;
    data[ 35] =  'sd55347;
    data[ 36] =  'sd50253;
    data[ 37] = -'sd22825;
    data[ 38] =  'sd12845;
    data[ 39] =  'sd34584;
    data[ 40] =  'sd30282;
    data[ 41] =  'sd70460;
    data[ 42] =  'sd81479;
    data[ 43] =  'sd18786;
    data[ 44] =  'sd64942;
    data[ 45] = -'sd52231;
    data[ 46] =  'sd67653;
    data[ 47] =  'sd7760;
    data[ 48] = -'sd37207;
    data[ 49] = -'sd77689;
    data[ 50] =  'sd31661;
    data[ 51] = -'sd60025;
    data[ 52] = -'sd63843;
    data[ 53] =  'sd45547;
    data[ 54] = -'sd40419;
    data[ 55] = -'sd45482;
    data[ 56] =  'sd49714;
    data[ 57] =  'sd63939;
    data[ 58] = -'sd31819;
    data[ 59] =  'sd37431;
    data[ 60] = -'sd54120;
    data[ 61] = -'sd38633;
    data[ 62] =  'sd46075;
    data[ 63] =  'sd35085;
    data[ 64] = -'sd61916;
    data[ 65] = -'sd6574;
    data[ 66] =  'sd42964;
    data[ 67] =  'sd81735;
    data[ 68] =  'sd55394;
    data[ 69] =  'sd56974;
    data[ 70] = -'sd44768;
    data[ 71] = -'sd12025;
    data[ 72] = -'sd81165;
    data[ 73] =  'sd26116;
    data[ 74] = -'sd33755;
    data[ 75] = -'sd75576;
    data[ 76] =  'sd6138;
    data[ 77] =  'sd58529;
    data[ 78] =  'sd13756;
    data[ 79] =  'sd1016;
    data[ 80] = -'sd18553;
    data[ 81] = -'sd31623;
    data[ 82] =  'sd65459;
    data[ 83] =  'sd21700;
    data[ 84] = -'sd9879;
    data[ 85] =  'sd61872;
    data[ 86] =  'sd282;
    data[ 87] =  'sd40326;
    data[ 88] =  'sd32183;
    data[ 89] =  'sd14621;
    data[ 90] = -'sd39130;
    data[ 91] = -'sd24996;
    data[ 92] =  'sd30074;
    data[ 93] =  'sd40716;
    data[ 94] = -'sd75888;
    data[ 95] = -'sd38478;
    data[ 96] =  'sd68240;
    data[ 97] = -'sd72140;
    data[ 98] =  'sd5963;
    data[ 99] =  'sd33504;
    data[100] =  'sd39683;
    data[101] = -'sd59766;
    data[102] = -'sd26806;
    data[103] = -'sd64915;
    data[104] =  'sd56092;
    data[105] = -'sd7053;
    data[106] = -'sd25533;
    data[107] = -'sd46717;
    data[108] =  'sd36950;
    data[109] =  'sd40938;
    data[110] = -'sd44142;
    data[111] =  'sd77493;
    data[112] = -'sd59689;
    data[113] = -'sd15795;
    data[114] =  'sd35089;
    data[115] = -'sd61344;
    data[116] =  'sd75222;
    data[117] = -'sd56760;
    data[118] =  'sd75370;
    data[119] = -'sd35596;
    data[120] = -'sd11157;
    data[121] =  'sd42959;
    data[122] =  'sd81020;
    data[123] = -'sd46851;
    data[124] =  'sd17788;
    data[125] = -'sd77772;
    data[126] =  'sd19792;
    data[127] =  'sd44959;
    data[128] =  'sd39338;
    data[129] =  'sd54740;
    data[130] = -'sd36548;
    data[131] =  'sd16548;
    data[132] =  'sd72590;
    data[133] =  'sd58387;
    data[134] = -'sd6550;
    data[135] =  'sd46396;
    data[136] =  'sd80988;
    data[137] = -'sd51427;
    data[138] =  'sd18784;
    data[139] =  'sd64656;
    data[140] =  'sd70712;
    data[141] = -'sd46326;
    data[142] = -'sd70978;
    data[143] =  'sd8288;
    data[144] =  'sd38297;
    data[145] =  'sd69718;
    data[146] = -'sd24627;
    data[147] = -'sd81000;
    data[148] =  'sd49711;
    data[149] =  'sd63510;
    data[150] =  'sd70675;
    data[151] = -'sd51617;
    data[152] = -'sd8386;
    data[153] = -'sd52311;
    data[154] =  'sd56213;
    data[155] =  'sd10250;
    data[156] = -'sd8819;
    data[157] =  'sd49611;
    data[158] =  'sd49210;
    data[159] = -'sd8133;
    data[160] = -'sd16132;
    data[161] = -'sd13102;
    data[162] = -'sd71335;
    data[163] = -'sd42763;
    data[164] = -'sd52992;
    data[165] = -'sd41170;
    data[166] =  'sd10966;
    data[167] = -'sd70272;
    data[168] = -'sd54595;
    data[169] =  'sd57283;
    data[170] = -'sd581;
    data[171] =  'sd80758;
    data[172] =  'sd79524;
    data[173] =  'sd66903;
    data[174] =  'sd64351;
    data[175] =  'sd27097;
    data[176] = -'sd57313;
    data[177] = -'sd3709;
    data[178] = -'sd38864;
    data[179] =  'sd13042;
    data[180] =  'sd62755;
    data[181] = -'sd37290;
    data[182] =  'sd74283;
    data[183] = -'sd27196;
    data[184] =  'sd43156;
    data[185] = -'sd54650;
    data[186] =  'sd49418;
    data[187] =  'sd21611;
    data[188] = -'sd22606;
    data[189] =  'sd44162;
    data[190] = -'sd74633;
    data[191] = -'sd22854;
    data[192] =  'sd8698;
    data[193] = -'sd66914;
    data[194] = -'sd65924;
    data[195] =  'sd75646;
    data[196] =  'sd3872;
    data[197] =  'sd62173;
    data[198] =  'sd43325;
    data[199] = -'sd30483;
    data[200] =  'sd64638;
    data[201] =  'sd68138;
    data[202] =  'sd77115;
    data[203] =  'sd50098;
    data[204] = -'sd44990;
    data[205] = -'sd43771;
    data[206] = -'sd33295;
    data[207] = -'sd9796;
    data[208] =  'sd73741;
    data[209] =  'sd59139;
    data[210] = -'sd62855;
    data[211] =  'sd22990;
    data[212] =  'sd10750;
    data[213] =  'sd62681;
    data[214] = -'sd47872;
    data[215] =  'sd35626;
    data[216] =  'sd15447;
    data[217] =  'sd78988;
    data[218] = -'sd9745;
    data[219] =  'sd81034;
    data[220] = -'sd44849;
    data[221] = -'sd23608;
    data[222] =  'sd64717;
    data[223] =  'sd79435;
    data[224] =  'sd54176;
    data[225] =  'sd46641;
    data[226] = -'sd47818;
    data[227] =  'sd43348;
    data[228] = -'sd27194;
    data[229] =  'sd43442;
    data[230] = -'sd13752;
    data[231] = -'sd444;
    data[232] = -'sd63492;
    data[233] = -'sd68101;
    data[234] = -'sd71824;
    data[235] =  'sd51151;
    data[236] = -'sd58252;
    data[237] =  'sd25855;
    data[238] = -'sd71078;
    data[239] = -'sd6012;
    data[240] = -'sd40511;
    data[241] = -'sd58638;
    data[242] = -'sd29343;
    data[243] =  'sd63817;
    data[244] = -'sd49265;
    data[245] =  'sd268;
    data[246] =  'sd38324;
    data[247] =  'sd73579;
    data[248] =  'sd35973;
    data[249] =  'sd65068;
    data[250] = -'sd34213;
    data[251] =  'sd22771;
    data[252] = -'sd20567;
    data[253] =  'sd8057;
    data[254] =  'sd5264;
    data[255] = -'sd66453;
  end

endmodule

