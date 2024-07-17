module ntt128_163841 ( clk, rst, start, input_fg, addr, din, dout, valid );

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
  input             [7 : 0] addr;
  input signed      [17 : 0] din;
  output reg signed [17 : 0] dout;
  output reg                 valid;

  // BRAM
  reg            wr_en   [0 : 1];
  reg   [7  : 0] wr_addr [0 : 1];
  reg   [7  : 0] rd_addr [0 : 1];
  reg   [17 : 0] wr_din  [0 : 1];
  wire  [17 : 0] rd_dout [0 : 1];
  wire  [17 : 0] wr_dout [0 : 1];

  // addr_gen
  wire         bank_index_rd [0 : 1];
  wire         bank_index_wr [0 : 1];
  wire [6 : 0] data_index_rd [0 : 1];
  wire [6 : 0] data_index_wr [0 : 1];
  reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;
  reg  fg_shift_1, fg_shift_2, fg_shift_3;

  // w_addr_gen
  reg  [6  : 0] stage_bit;
  wire [6  : 0] w_addr;

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
  reg  [3 : 0] stage, stage_wr;
  wire [3 : 0] stage_rdM, stage_wrM;
  reg  [8 : 0] ctr;
  reg  [8 : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_1, ctr_shift_2;
  reg          ctr_MSB_masked;
  reg          poly_select;
  reg          ctr_msb_shift_1;
  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, stage_rd_end, stage_rd_2, stage_wr_end, ntt_end, point_proc_end, reduce_end;

  // w_array
  reg         [7 : 0] w_addr_in;
  wire signed [17: 0] w_dout ;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [7 : 0] wr_ctr [0 : 1];
  reg [17: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [7 : 0] w_addr_in_shift_1;

  // BRAM instances
  bram_18_8_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_18_8_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[6:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[6:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[6:0], w_addr);

  // Butterfly Unit  , each with a corresponding omega array
  bfu_163841 bfu_inst (clk, ntt_state, in_a, in_b, in_w, bw, out_a, out_b);
  w_163841 rom_w_inst (clk, w_addr_in_shift_1, w_dout);

  assign ctr_half_end         = (ctr[6:0] == 127) ? 1 : 0;
  assign ctr_full_end         = (ctr[7:0] == 255) ? 1 : 0;
  assign stage_rd_end         = (stage == 8) ? 1 : 0;
  assign stage_rd_2           = (stage == 2) ? 1 : 0;
  assign ntt_end         = (stage_rd_end && ctr[6 : 0] == 10) ? 1 : 0;
  assign crt_end         = (stage_rd_2 && ctr[6 : 0] == 10) ? 1 : 0;
  assign point_proc_end   = (ctr == 266) ? 1 : 0;
  assign reload_end      = (stage != 0 && ctr[6:0] == 4) ? 1 : 0;
  assign reduce_end      = (ctr == 260);

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
        rd_addr[0][6:0] <= data_index_rd[1];
        rd_addr[1][6:0] <= data_index_rd[0];
      end else begin
        rd_addr[0][6:0] <= data_index_rd[0];
        rd_addr[1][6:0] <= data_index_rd[1];
      end
    end else begin
      rd_addr[0][6:0] <= data_index_rd[0];
      rd_addr[1][6:0] <= data_index_rd[0];
    end

    if (state == ST_NTT)  begin
      rd_addr[0][7] <= poly_select;
      rd_addr[1][7] <= poly_select;
    end else if (state == ST_PMUL) begin
      rd_addr[0][7] <=  bank_index_rd[0];
      rd_addr[1][7] <= ~bank_index_rd[0];
    end else if (state == ST_RELOAD) begin
      rd_addr[0][7] <= 0;
      rd_addr[1][7] <= 0;
    end else begin
      rd_addr[0][7] <= 1;
      rd_addr[1][7] <= 1;
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
        wr_addr[0][6:0] <= data_index_wr[1];
        wr_addr[1][6:0] <= data_index_wr[0];
      end else begin
        wr_addr[0][6:0] <= data_index_wr[0];
        wr_addr[1][6:0] <= data_index_wr[1];
      end
    end else begin
      wr_addr[0][6:0] <= data_index_wr[0];
      wr_addr[1][6:0] <= data_index_wr[0];
    end  

    if (state == ST_IDLE) begin
      wr_addr[0][7] <= fg_shift_3;
      wr_addr[1][7] <= fg_shift_3;
    end else if(state == ST_NTT || state == ST_INTT) begin
      wr_addr[0][7] <= poly_select;
      wr_addr[1][7] <= poly_select;
    end else if (state == ST_PMUL || state == ST_REDUCE || state == ST_FINISH) begin
      wr_addr[0][7] <= 0;
      wr_addr[1][7] <= 0;
    end else begin
      wr_addr[0][7] <= 1;
      wr_addr[1][7] <= 1;
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
      w_addr_in <= 256 - w_addr;
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
      wr_ctr[0] <= addr[7:0];
    end else if (state == ST_RELOAD || state == ST_REDUCE) begin
      wr_ctr[0] <= {ctr_shift_1[0], ctr_shift_1[1], ctr_shift_1[2], ctr_shift_1[3], ctr_shift_1[4], ctr_shift_1[5], ctr_shift_1[6], ctr_shift_1[7]};
    end else if (state == ST_NTT || state == ST_INTT) begin
      wr_ctr[0] <= {1'b0, ctr_shift_7[6:0]};
    end else begin
      wr_ctr[0] <= ctr_shift_7[7:0];
    end

    wr_ctr[1] <= {1'b1, ctr_shift_7[6:0]};
  end

  // ctr_MSB_masked
  always @ (*) begin
    if (state == ST_NTT || state == ST_INTT) begin
      ctr_MSB_masked = 0;
    end else begin
      ctr_MSB_masked = ctr[7];
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
      end else if (ctr_shift_7[6:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_RELOAD) begin
      if (reload_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_7[7:0] == 0 && stage != 0) begin
        stage_wr <= stage_wr + 1;
      end else begin
        stage_wr <= stage_wr;
      end
    end else if (state == ST_CRT) begin
      if (crt_end) begin
        stage_wr <= 0;
      end else if (ctr_shift_9[7:0] == 0 && stage != 0) begin
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
        stage_bit[6 : 1] <= stage_bit[5 : 0];
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
  input      [ 6: 0] stage_bit;
  input      [ 6: 0] ctr;
  output reg [ 6: 0] w_addr;

  wire [ 6: 0] w;

  assign w[ 0] = (stage_bit[ 0]) ? ctr[ 0] : 0;
  assign w[ 1] = (stage_bit[ 1]) ? ctr[ 1] : 0;
  assign w[ 2] = (stage_bit[ 2]) ? ctr[ 2] : 0;
  assign w[ 3] = (stage_bit[ 3]) ? ctr[ 3] : 0;
  assign w[ 4] = (stage_bit[ 4]) ? ctr[ 4] : 0;
  assign w[ 5] = (stage_bit[ 5]) ? ctr[ 5] : 0;
  assign w[ 6] = (stage_bit[ 6]) ? ctr[ 6] : 0;

  always @ ( posedge clk ) begin
    w_addr <= {w[0], w[1], w[2], w[3], w[4], w[5], w[6]};
  end

endmodule

module addr_gen ( clk, stage, ctr, bank_index, data_index );

  input              clk;
  input      [2 : 0] stage;
  input      [7 : 0] ctr;
  output reg         bank_index;
  output reg [6 : 0] data_index;

  wire       [7 : 0] bs_out;

  barrel_shifter bs ( clk, ctr, stage, bs_out );

    always @( posedge clk ) begin
        bank_index <= ^bs_out;
    end

    always @( posedge clk ) begin
        data_index <= bs_out[7:1];
    end

endmodule

module barrel_shifter ( clk, in, shift, out );

  input              clk;
  input      [7 : 0] in;
  input      [2 : 0] shift;
  output reg [7 : 0] out;

  reg        [7 : 0] in_s [0:3];

  always @ (*) begin
    in_s[0] = in;
  end

  always @ (*) begin
    if(shift[0]) begin
      in_s[1] = { in_s[0][0], in_s[0][7:1] };
    end else begin
      in_s[1] = in_s[0];
    end
  end

  always @ (*) begin
    if(shift[1]) begin
      in_s[2] = { in_s[1][1:0], in_s[1][7:2] };
    end else begin
      in_s[2] = in_s[1];
    end
  end

  always @ (*) begin
    if(shift[2]) begin
      in_s[3] = { in_s[2][3:0], in_s[2][7:4] };
    end else begin
      in_s[3] = in_s[2];
    end
  end

  always @ ( posedge clk ) begin
    out <= in_s[3];
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
  input             [ 7 : 0]  addr;
  output signed     [17 : 0]  dout;

  wire signed       [17 : 0]  dout_p;
  wire signed       [17 : 0]  dout_n;
  reg               [ 7 : 0]  addr_reg;

  (* rom_style = "distributed" *) reg signed [17:0] data [0:127];

  assign dout_p = data[addr_reg[6:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[7] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[  0] =  'sd1;
    data[  1] =  'sd282;
    data[  2] =  'sd79524;
    data[  3] = -'sd20449;
    data[  4] = -'sd32183;
    data[  5] = -'sd64351;
    data[  6] =  'sd39369;
    data[  7] = -'sd39130;
    data[  8] = -'sd57313;
    data[  9] =  'sd57993;
    data[ 10] = -'sd30074;
    data[ 11] =  'sd38864;
    data[ 12] = -'sd17699;
    data[ 13] = -'sd75888;
    data[ 14] =  'sd62755;
    data[ 15] =  'sd2082;
    data[ 16] = -'sd68240;
    data[ 17] = -'sd74283;
    data[ 18] =  'sd23842;
    data[ 19] =  'sd5963;
    data[ 20] =  'sd43156;
    data[ 21] =  'sd45758;
    data[ 22] = -'sd39683;
    data[ 23] = -'sd49418;
    data[ 24] = -'sd9391;
    data[ 25] = -'sd26806;
    data[ 26] = -'sd22606;
    data[ 27] =  'sd14907;
    data[ 28] = -'sd56092;
    data[ 29] =  'sd74633;
    data[ 30] =  'sd74858;
    data[ 31] = -'sd25533;
    data[ 32] =  'sd8698;
    data[ 33] = -'sd4779;
    data[ 34] = -'sd36950;
    data[ 35] =  'sd65924;
    data[ 36] =  'sd76535;
    data[ 37] = -'sd44142;
    data[ 38] =  'sd3872;
    data[ 39] = -'sd54983;
    data[ 40] =  'sd59689;
    data[ 41] = -'sd43325;
    data[ 42] =  'sd70425;
    data[ 43] =  'sd35089;
    data[ 44] =  'sd64638;
    data[ 45] =  'sd41565;
    data[ 46] = -'sd75222;
    data[ 47] = -'sd77115;
    data[ 48] =  'sd44423;
    data[ 49] =  'sd75370;
    data[ 50] = -'sd44990;
    data[ 51] = -'sd71423;
    data[ 52] =  'sd11157;
    data[ 53] =  'sd33295;
    data[ 54] =  'sd50253;
    data[ 55] =  'sd81020;
    data[ 56] =  'sd73741;
    data[ 57] = -'sd12845;
    data[ 58] = -'sd17788;
    data[ 59] =  'sd62855;
    data[ 60] =  'sd30282;
    data[ 61] =  'sd19792;
    data[ 62] =  'sd10750;
    data[ 63] = -'sd81479;
    data[ 64] = -'sd39338;
    data[ 65] =  'sd47872;
    data[ 66] =  'sd64942;
    data[ 67] = -'sd36548;
    data[ 68] =  'sd15447;
    data[ 69] = -'sd67653;
    data[ 70] = -'sd72590;
    data[ 71] =  'sd9745;
    data[ 72] = -'sd37207;
    data[ 73] = -'sd6550;
    data[ 74] = -'sd44849;
    data[ 75] = -'sd31661;
    data[ 76] = -'sd80988;
    data[ 77] = -'sd64717;
    data[ 78] = -'sd63843;
    data[ 79] =  'sd18784;
    data[ 80] =  'sd54176;
    data[ 81] =  'sd40419;
    data[ 82] = -'sd70712;
    data[ 83] =  'sd47818;
    data[ 84] =  'sd49714;
    data[ 85] = -'sd70978;
    data[ 86] = -'sd27194;
    data[ 87] =  'sd31819;
    data[ 88] = -'sd38297;
    data[ 89] =  'sd13752;
    data[ 90] = -'sd54120;
    data[ 91] = -'sd24627;
    data[ 92] = -'sd63492;
    data[ 93] = -'sd46075;
    data[ 94] = -'sd49711;
    data[ 95] =  'sd71824;
    data[ 96] = -'sd61916;
    data[ 97] =  'sd70675;
    data[ 98] = -'sd58252;
    data[ 99] = -'sd42964;
    data[100] =  'sd8386;
    data[101] =  'sd71078;
    data[102] =  'sd55394;
    data[103] =  'sd56213;
    data[104] = -'sd40511;
    data[105] =  'sd44768;
    data[106] =  'sd8819;
    data[107] =  'sd29343;
    data[108] = -'sd81165;
    data[109] =  'sd49210;
    data[110] = -'sd49265;
    data[111] =  'sd33755;
    data[112] =  'sd16132;
    data[113] = -'sd38324;
    data[114] =  'sd6138;
    data[115] = -'sd71335;
    data[116] =  'sd35973;
    data[117] = -'sd13756;
    data[118] =  'sd52992;
    data[119] =  'sd34213;
    data[120] = -'sd18553;
    data[121] =  'sd10966;
    data[122] = -'sd20567;
    data[123] = -'sd65459;
    data[124] =  'sd54595;
    data[125] = -'sd5264;
    data[126] = -'sd9879;
    data[127] = -'sd581;
  end

endmodule

