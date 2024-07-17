module ntt2048_61441 ( clk, rst, start, input_fg, addr, din, dout, valid );

  localparam Q0 = 61441;

  // STATE
  localparam ST_IDLE   = 0;
  localparam ST_NTT    = 1;
  localparam ST_PMUL   = 2;
  localparam ST_RELOAD = 3;
  localparam ST_INTT   = 4;
  localparam ST_CRT    = 5;  // not applied for single prime scheme
  localparam ST_REDUCE = 6;
  localparam ST_FINISH = 7;

  input                clk;
  input                rst;
  input                start;
  input                input_fg;
  input       [11 : 0] addr;
  input       [15 : 0] din;
  output reg  [15 : 0] dout;
  output reg           valid;

  // BRAM
  reg            wr_en   [0 : 1];
  reg   [11 : 0] wr_addr [0 : 1];
  reg   [11 : 0] rd_addr [0 : 1];
  reg   [15 : 0] wr_din  [0 : 1];
  wire  [15 : 0] rd_dout [0 : 1];
  wire  [15 : 0] wr_dout [0 : 1];

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
  reg  signed [15: 0] in_a  ;
  reg  signed [15: 0] in_b  ;
  reg  signed [15: 0] in_w  ;
  wire signed [31: 0] bw    ;
  wire signed [15: 0] out_a ;
  wire signed [15: 0] out_b ;

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
  wire signed [15: 0] w_dout ;

  // misc
  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;
  reg [11: 0] wr_ctr [0 : 1];
  reg [15: 0] din_shift_1, din_shift_2, din_shift_3;
  reg [11: 0] w_addr_in_shift_1;

  // BRAM instances
  bram_16_12_P bank_0
  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);
  bram_16_12_P bank_1
  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);

  // Read/Write Address Generator
  addr_gen addr_rd_0 (clk, stage_rdM, {ctr_MSB_masked, ctr[10:0]}, bank_index_rd[0], data_index_rd[0]);
  addr_gen addr_rd_1 (clk, stage_rdM, {1'b1, ctr[10:0]}, bank_index_rd[1], data_index_rd[1]);
  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);
  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);

  // Omega Address Generator
  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[10:0], w_addr);

  // Butterfly Unit  , each with a corresponding omega array
  bfu_61441 bfu_inst (clk, ntt_state, in_a, in_b, in_w, bw, out_a, out_b);
  w_61441 rom_w_inst (clk, w_addr_in_shift_1, w_dout);

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
        dout <= wr_dout[1][15:0];
      end else begin
        dout <= wr_dout[0][15:0];
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
      wr_din[0][15:0] <= { din_shift_3 };
      wr_din[1][15:0] <= { din_shift_3 };
    end else if (state == ST_NTT || state == ST_INTT) begin
      if (poly_select ^ bank_index_wr[0]) begin
        wr_din[0][15:0] <= out_b;
        wr_din[1][15:0] <= out_a;
      end else begin
        wr_din[0][15:0] <= out_a;
        wr_din[1][15:0] <= out_b;
      end
    end else if (state == ST_RELOAD) begin
      if (bank_index_rd_shift_2) begin
        wr_din[0][15:0] <= rd_dout[1][15:0];
        wr_din[1][15:0] <= rd_dout[1][15:0];
      end else begin
        wr_din[0][15:0] <= rd_dout[0][15:0];
        wr_din[1][15:0] <= rd_dout[0][15:0];
      end
    end else if (state == ST_REDUCE) begin
      if (bank_index_rd_shift_2) begin
        wr_din[0][15:0] <= rd_dout[0][15:0];
        wr_din[1][15:0] <= rd_dout[0][15:0];
      end else begin
        wr_din[0][15:0] <= rd_dout[1][15:0];
        wr_din[1][15:0] <= rd_dout[1][15:0];
      end
    end else begin
      wr_din[0][15:0] <= out_a;
      wr_din[1][15:0] <= out_a;
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

module bfu_61441 ( clk, state, in_a, in_b, w, bw, out_a, out_b );

  input                      clk;
  input                      state;
  input      signed [15 : 0] in_a;
  input      signed [15 : 0] in_b;
  input      signed [15 : 0] w;
  output reg signed [30 : 0] bw;
  output reg signed [15 : 0] out_a;
  output reg signed [15 : 0] out_b;

  wire signed       [15 : 0] mod_bw;
  reg signed        [16 : 0] a, b;
  reg signed        [15 : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;

  reg signed        [30 : 0] bwQ_0, bwQ_1, bwQ_2;
  wire signed       [16 : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;

  modmul61441s modmul61441s_inst ( clk, 1'b0, bw, mod_bw );

  assign a_add_q = a + 'sd61441;
  assign a_sub_q = a - 'sd61441;
  assign b_add_q = b + 'sd61441;
  assign b_sub_q = b - 'sd61441;

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
      if (a > 'sd30720) begin
        out_a <= a_sub_q;
      end else if (a < -'sd30720) begin
        out_a <= a_add_q;
      end else begin
        out_a <= a;
      end
    end else begin
      if (a[0] == 0) begin
        out_a <= a[16:1];
      end else if (a[16] == 0) begin // a > 0
        out_a <= a_sub_q[16:1];
      end else begin                 // a < 0
        out_a <= a_add_q[16:1];
      end
    end

    if (state == 0) begin
      if (b > 'sd30720) begin
        out_b <= b_sub_q;
      end else if (b < -'sd30720) begin
        out_b <= b_add_q;
      end else begin
        out_b <= b;
      end
    end else begin
      if (b[0] == 0) begin
        out_b <= b[16:1];
      end else if (b[16] == 0) begin // b > 0
        out_b <= b_sub_q[16:1];
      end else begin                 // b < 0
        out_b <= b_add_q[16:1];
      end
    end
  end

endmodule

module w_61441 ( clk, addr, dout );

  input                       clk;
  input             [11 : 0]  addr;
  output signed     [15 : 0]  dout;

  wire signed       [15 : 0]  dout_p;
  wire signed       [15 : 0]  dout_n;
  reg               [11 : 0]  addr_reg;

  (* rom_style = "block" *) reg signed [15:0] data [0:2047];

  assign dout_p = data[addr_reg[10:0]];
  assign dout_n = -dout_p;
  assign dout   = addr_reg[11] ? dout_n : dout_p;

  always @ ( posedge clk ) begin
    addr_reg <= addr;
  end

  initial begin
    data[   0] =  'sd1;
    data[   1] =  'sd19;
    data[   2] =  'sd361;
    data[   3] =  'sd6859;
    data[   4] =  'sd7439;
    data[   5] =  'sd18459;
    data[   6] = -'sd17925;
    data[   7] =  'sd28071;
    data[   8] = -'sd19620;
    data[   9] = -'sd4134;
    data[  10] = -'sd17105;
    data[  11] = -'sd17790;
    data[  12] =  'sd30636;
    data[  13] =  'sd29115;
    data[  14] =  'sd216;
    data[  15] =  'sd4104;
    data[  16] =  'sd16535;
    data[  17] =  'sd6960;
    data[  18] =  'sd9358;
    data[  19] = -'sd6521;
    data[  20] = -'sd1017;
    data[  21] = -'sd19323;
    data[  22] =  'sd1509;
    data[  23] =  'sd28671;
    data[  24] = -'sd8220;
    data[  25] =  'sd28143;
    data[  26] = -'sd18252;
    data[  27] =  'sd21858;
    data[  28] = -'sd14785;
    data[  29] =  'sd26290;
    data[  30] =  'sd7982;
    data[  31] =  'sd28776;
    data[  32] = -'sd6225;
    data[  33] =  'sd4607;
    data[  34] =  'sd26092;
    data[  35] =  'sd4220;
    data[  36] =  'sd18739;
    data[  37] = -'sd12605;
    data[  38] =  'sd6269;
    data[  39] = -'sd3771;
    data[  40] = -'sd10208;
    data[  41] = -'sd9629;
    data[  42] =  'sd1372;
    data[  43] =  'sd26068;
    data[  44] =  'sd3764;
    data[  45] =  'sd10075;
    data[  46] =  'sd7102;
    data[  47] =  'sd12056;
    data[  48] = -'sd16700;
    data[  49] = -'sd10095;
    data[  50] = -'sd7482;
    data[  51] = -'sd19276;
    data[  52] =  'sd2402;
    data[  53] = -'sd15803;
    data[  54] =  'sd6948;
    data[  55] =  'sd9130;
    data[  56] = -'sd10853;
    data[  57] = -'sd21884;
    data[  58] =  'sd14291;
    data[  59] =  'sd25765;
    data[  60] = -'sd1993;
    data[  61] =  'sd23574;
    data[  62] =  'sd17819;
    data[  63] = -'sd30085;
    data[  64] = -'sd18646;
    data[  65] =  'sd14372;
    data[  66] =  'sd27304;
    data[  67] =  'sd27248;
    data[  68] =  'sd26184;
    data[  69] =  'sd5968;
    data[  70] = -'sd9490;
    data[  71] =  'sd4013;
    data[  72] =  'sd14806;
    data[  73] = -'sd25891;
    data[  74] = -'sd401;
    data[  75] = -'sd7619;
    data[  76] = -'sd21879;
    data[  77] =  'sd14386;
    data[  78] =  'sd27570;
    data[  79] = -'sd29139;
    data[  80] = -'sd672;
    data[  81] = -'sd12768;
    data[  82] =  'sd3172;
    data[  83] = -'sd1173;
    data[  84] = -'sd22287;
    data[  85] =  'sd6634;
    data[  86] =  'sd3164;
    data[  87] = -'sd1325;
    data[  88] = -'sd25175;
    data[  89] =  'sd13203;
    data[  90] =  'sd5093;
    data[  91] = -'sd26115;
    data[  92] = -'sd4657;
    data[  93] = -'sd27042;
    data[  94] = -'sd22270;
    data[  95] =  'sd6957;
    data[  96] =  'sd9301;
    data[  97] = -'sd7604;
    data[  98] = -'sd21594;
    data[  99] =  'sd19801;
    data[ 100] =  'sd7573;
    data[ 101] =  'sd21005;
    data[ 102] =  'sd30449;
    data[ 103] =  'sd25562;
    data[ 104] = -'sd5850;
    data[ 105] =  'sd11732;
    data[ 106] = -'sd22856;
    data[ 107] = -'sd4177;
    data[ 108] = -'sd17922;
    data[ 109] =  'sd28128;
    data[ 110] = -'sd18537;
    data[ 111] =  'sd16443;
    data[ 112] =  'sd5212;
    data[ 113] = -'sd23854;
    data[ 114] = -'sd23139;
    data[ 115] = -'sd9554;
    data[ 116] =  'sd2797;
    data[ 117] = -'sd8298;
    data[ 118] =  'sd26661;
    data[ 119] =  'sd15031;
    data[ 120] = -'sd21616;
    data[ 121] =  'sd19383;
    data[ 122] = -'sd369;
    data[ 123] = -'sd7011;
    data[ 124] = -'sd10327;
    data[ 125] = -'sd11890;
    data[ 126] =  'sd19854;
    data[ 127] =  'sd8580;
    data[ 128] = -'sd21303;
    data[ 129] =  'sd25330;
    data[ 130] = -'sd10258;
    data[ 131] = -'sd10579;
    data[ 132] = -'sd16678;
    data[ 133] = -'sd9677;
    data[ 134] =  'sd460;
    data[ 135] =  'sd8740;
    data[ 136] = -'sd18263;
    data[ 137] =  'sd21649;
    data[ 138] = -'sd18756;
    data[ 139] =  'sd12282;
    data[ 140] = -'sd12406;
    data[ 141] =  'sd10050;
    data[ 142] =  'sd6627;
    data[ 143] =  'sd3031;
    data[ 144] = -'sd3852;
    data[ 145] = -'sd11747;
    data[ 146] =  'sd22571;
    data[ 147] = -'sd1238;
    data[ 148] = -'sd23522;
    data[ 149] = -'sd16831;
    data[ 150] = -'sd12584;
    data[ 151] =  'sd6668;
    data[ 152] =  'sd3810;
    data[ 153] =  'sd10949;
    data[ 154] =  'sd23708;
    data[ 155] =  'sd20365;
    data[ 156] =  'sd18289;
    data[ 157] = -'sd21155;
    data[ 158] =  'sd28142;
    data[ 159] = -'sd18271;
    data[ 160] =  'sd21497;
    data[ 161] = -'sd21644;
    data[ 162] =  'sd18851;
    data[ 163] = -'sd10477;
    data[ 164] = -'sd14740;
    data[ 165] =  'sd27145;
    data[ 166] =  'sd24227;
    data[ 167] =  'sd30226;
    data[ 168] =  'sd21325;
    data[ 169] = -'sd24912;
    data[ 170] =  'sd18200;
    data[ 171] = -'sd22846;
    data[ 172] = -'sd3987;
    data[ 173] = -'sd14312;
    data[ 174] = -'sd26164;
    data[ 175] = -'sd5588;
    data[ 176] =  'sd16710;
    data[ 177] =  'sd10285;
    data[ 178] =  'sd11092;
    data[ 179] =  'sd26425;
    data[ 180] =  'sd10547;
    data[ 181] =  'sd16070;
    data[ 182] = -'sd1875;
    data[ 183] =  'sd25816;
    data[ 184] = -'sd1024;
    data[ 185] = -'sd19456;
    data[ 186] = -'sd1018;
    data[ 187] = -'sd19342;
    data[ 188] =  'sd1148;
    data[ 189] =  'sd21812;
    data[ 190] = -'sd15659;
    data[ 191] =  'sd9684;
    data[ 192] = -'sd327;
    data[ 193] = -'sd6213;
    data[ 194] =  'sd4835;
    data[ 195] =  'sd30424;
    data[ 196] =  'sd25087;
    data[ 197] = -'sd14875;
    data[ 198] =  'sd24580;
    data[ 199] = -'sd24508;
    data[ 200] =  'sd25876;
    data[ 201] =  'sd116;
    data[ 202] =  'sd2204;
    data[ 203] = -'sd19565;
    data[ 204] = -'sd3089;
    data[ 205] =  'sd2750;
    data[ 206] = -'sd9191;
    data[ 207] =  'sd9694;
    data[ 208] = -'sd137;
    data[ 209] = -'sd2603;
    data[ 210] =  'sd11984;
    data[ 211] = -'sd18068;
    data[ 212] =  'sd25354;
    data[ 213] = -'sd9802;
    data[ 214] = -'sd1915;
    data[ 215] =  'sd25056;
    data[ 216] = -'sd15464;
    data[ 217] =  'sd13389;
    data[ 218] =  'sd8627;
    data[ 219] = -'sd20410;
    data[ 220] = -'sd19144;
    data[ 221] =  'sd4910;
    data[ 222] = -'sd29592;
    data[ 223] = -'sd9279;
    data[ 224] =  'sd8022;
    data[ 225] =  'sd29536;
    data[ 226] =  'sd8215;
    data[ 227] = -'sd28238;
    data[ 228] =  'sd16447;
    data[ 229] =  'sd5288;
    data[ 230] = -'sd22410;
    data[ 231] =  'sd4297;
    data[ 232] =  'sd20202;
    data[ 233] =  'sd15192;
    data[ 234] = -'sd18557;
    data[ 235] =  'sd16063;
    data[ 236] = -'sd2008;
    data[ 237] =  'sd23289;
    data[ 238] =  'sd12404;
    data[ 239] = -'sd10088;
    data[ 240] = -'sd7349;
    data[ 241] = -'sd16749;
    data[ 242] = -'sd11026;
    data[ 243] = -'sd25171;
    data[ 244] =  'sd13279;
    data[ 245] =  'sd6537;
    data[ 246] =  'sd1321;
    data[ 247] =  'sd25099;
    data[ 248] = -'sd14647;
    data[ 249] =  'sd28912;
    data[ 250] = -'sd3641;
    data[ 251] = -'sd7738;
    data[ 252] = -'sd24140;
    data[ 253] = -'sd28573;
    data[ 254] =  'sd10082;
    data[ 255] =  'sd7235;
    data[ 256] =  'sd14583;
    data[ 257] = -'sd30128;
    data[ 258] = -'sd19463;
    data[ 259] = -'sd1151;
    data[ 260] = -'sd21869;
    data[ 261] =  'sd14576;
    data[ 262] = -'sd30261;
    data[ 263] = -'sd21990;
    data[ 264] =  'sd12277;
    data[ 265] = -'sd12501;
    data[ 266] =  'sd8245;
    data[ 267] = -'sd27668;
    data[ 268] =  'sd27277;
    data[ 269] =  'sd26735;
    data[ 270] =  'sd16437;
    data[ 271] =  'sd5098;
    data[ 272] = -'sd26020;
    data[ 273] = -'sd2852;
    data[ 274] =  'sd7253;
    data[ 275] =  'sd14925;
    data[ 276] = -'sd23630;
    data[ 277] = -'sd18883;
    data[ 278] =  'sd9869;
    data[ 279] =  'sd3188;
    data[ 280] = -'sd869;
    data[ 281] = -'sd16511;
    data[ 282] = -'sd6504;
    data[ 283] = -'sd694;
    data[ 284] = -'sd13186;
    data[ 285] = -'sd4770;
    data[ 286] = -'sd29189;
    data[ 287] = -'sd1622;
    data[ 288] =  'sd30623;
    data[ 289] =  'sd28868;
    data[ 290] = -'sd4477;
    data[ 291] = -'sd23622;
    data[ 292] = -'sd18731;
    data[ 293] =  'sd12757;
    data[ 294] = -'sd3381;
    data[ 295] = -'sd2798;
    data[ 296] =  'sd8279;
    data[ 297] = -'sd27022;
    data[ 298] = -'sd21890;
    data[ 299] =  'sd14177;
    data[ 300] =  'sd23599;
    data[ 301] =  'sd18294;
    data[ 302] = -'sd21060;
    data[ 303] =  'sd29947;
    data[ 304] =  'sd16024;
    data[ 305] = -'sd2749;
    data[ 306] =  'sd9210;
    data[ 307] = -'sd9333;
    data[ 308] =  'sd6996;
    data[ 309] =  'sd10042;
    data[ 310] =  'sd6475;
    data[ 311] =  'sd143;
    data[ 312] =  'sd2717;
    data[ 313] = -'sd9818;
    data[ 314] = -'sd2219;
    data[ 315] =  'sd19280;
    data[ 316] = -'sd2326;
    data[ 317] =  'sd17247;
    data[ 318] =  'sd20488;
    data[ 319] =  'sd20626;
    data[ 320] =  'sd23248;
    data[ 321] =  'sd11625;
    data[ 322] = -'sd24889;
    data[ 323] =  'sd18637;
    data[ 324] = -'sd14543;
    data[ 325] = -'sd30553;
    data[ 326] = -'sd27538;
    data[ 327] =  'sd29747;
    data[ 328] =  'sd12224;
    data[ 329] = -'sd13508;
    data[ 330] = -'sd10888;
    data[ 331] = -'sd22549;
    data[ 332] =  'sd1656;
    data[ 333] = -'sd29977;
    data[ 334] = -'sd16594;
    data[ 335] = -'sd8081;
    data[ 336] = -'sd30657;
    data[ 337] = -'sd29514;
    data[ 338] = -'sd7797;
    data[ 339] = -'sd25261;
    data[ 340] =  'sd11569;
    data[ 341] = -'sd25953;
    data[ 342] = -'sd1579;
    data[ 343] = -'sd30001;
    data[ 344] = -'sd17050;
    data[ 345] = -'sd16745;
    data[ 346] = -'sd10950;
    data[ 347] = -'sd23727;
    data[ 348] = -'sd20726;
    data[ 349] = -'sd25148;
    data[ 350] =  'sd13716;
    data[ 351] =  'sd14840;
    data[ 352] = -'sd25245;
    data[ 353] =  'sd11873;
    data[ 354] = -'sd20177;
    data[ 355] = -'sd14717;
    data[ 356] =  'sd27582;
    data[ 357] = -'sd28911;
    data[ 358] =  'sd3660;
    data[ 359] =  'sd8099;
    data[ 360] = -'sd30442;
    data[ 361] = -'sd25429;
    data[ 362] =  'sd8377;
    data[ 363] = -'sd25160;
    data[ 364] =  'sd13488;
    data[ 365] =  'sd10508;
    data[ 366] =  'sd15329;
    data[ 367] = -'sd15954;
    data[ 368] =  'sd4079;
    data[ 369] =  'sd16060;
    data[ 370] = -'sd2065;
    data[ 371] =  'sd22206;
    data[ 372] = -'sd8173;
    data[ 373] =  'sd29036;
    data[ 374] = -'sd1285;
    data[ 375] = -'sd24415;
    data[ 376] =  'sd27643;
    data[ 377] = -'sd27752;
    data[ 378] =  'sd25681;
    data[ 379] = -'sd3589;
    data[ 380] = -'sd6750;
    data[ 381] = -'sd5368;
    data[ 382] =  'sd20890;
    data[ 383] =  'sd28264;
    data[ 384] = -'sd15953;
    data[ 385] =  'sd4098;
    data[ 386] =  'sd16421;
    data[ 387] =  'sd4794;
    data[ 388] =  'sd29645;
    data[ 389] =  'sd10286;
    data[ 390] =  'sd11111;
    data[ 391] =  'sd26786;
    data[ 392] =  'sd17406;
    data[ 393] =  'sd23509;
    data[ 394] =  'sd16584;
    data[ 395] =  'sd7891;
    data[ 396] =  'sd27047;
    data[ 397] =  'sd22365;
    data[ 398] = -'sd5152;
    data[ 399] =  'sd24994;
    data[ 400] = -'sd16642;
    data[ 401] = -'sd8993;
    data[ 402] =  'sd13456;
    data[ 403] =  'sd9900;
    data[ 404] =  'sd3777;
    data[ 405] =  'sd10322;
    data[ 406] =  'sd11795;
    data[ 407] = -'sd21659;
    data[ 408] =  'sd18566;
    data[ 409] = -'sd15892;
    data[ 410] =  'sd5257;
    data[ 411] = -'sd22999;
    data[ 412] = -'sd6894;
    data[ 413] = -'sd8104;
    data[ 414] =  'sd30347;
    data[ 415] =  'sd23624;
    data[ 416] =  'sd18769;
    data[ 417] = -'sd12035;
    data[ 418] =  'sd17099;
    data[ 419] =  'sd17676;
    data[ 420] =  'sd28639;
    data[ 421] = -'sd8828;
    data[ 422] =  'sd16591;
    data[ 423] =  'sd8024;
    data[ 424] =  'sd29574;
    data[ 425] =  'sd8937;
    data[ 426] = -'sd14520;
    data[ 427] = -'sd30116;
    data[ 428] = -'sd19235;
    data[ 429] =  'sd3181;
    data[ 430] = -'sd1002;
    data[ 431] = -'sd19038;
    data[ 432] =  'sd6924;
    data[ 433] =  'sd8674;
    data[ 434] = -'sd19517;
    data[ 435] = -'sd2177;
    data[ 436] =  'sd20078;
    data[ 437] =  'sd12836;
    data[ 438] = -'sd1880;
    data[ 439] =  'sd25721;
    data[ 440] = -'sd2829;
    data[ 441] =  'sd7690;
    data[ 442] =  'sd23228;
    data[ 443] =  'sd11245;
    data[ 444] =  'sd29332;
    data[ 445] =  'sd4339;
    data[ 446] =  'sd21000;
    data[ 447] =  'sd30354;
    data[ 448] =  'sd23757;
    data[ 449] =  'sd21296;
    data[ 450] = -'sd25463;
    data[ 451] =  'sd7731;
    data[ 452] =  'sd24007;
    data[ 453] =  'sd26046;
    data[ 454] =  'sd3346;
    data[ 455] =  'sd2133;
    data[ 456] = -'sd20914;
    data[ 457] = -'sd28720;
    data[ 458] =  'sd7289;
    data[ 459] =  'sd15609;
    data[ 460] = -'sd10634;
    data[ 461] = -'sd17723;
    data[ 462] = -'sd29532;
    data[ 463] = -'sd8139;
    data[ 464] =  'sd29682;
    data[ 465] =  'sd10989;
    data[ 466] =  'sd24468;
    data[ 467] = -'sd26636;
    data[ 468] = -'sd14556;
    data[ 469] =  'sd30641;
    data[ 470] =  'sd29210;
    data[ 471] =  'sd2021;
    data[ 472] = -'sd23042;
    data[ 473] = -'sd7711;
    data[ 474] = -'sd23627;
    data[ 475] = -'sd18826;
    data[ 476] =  'sd10952;
    data[ 477] =  'sd23765;
    data[ 478] =  'sd21448;
    data[ 479] = -'sd22575;
    data[ 480] =  'sd1162;
    data[ 481] =  'sd22078;
    data[ 482] = -'sd10605;
    data[ 483] = -'sd17172;
    data[ 484] = -'sd19063;
    data[ 485] =  'sd6449;
    data[ 486] = -'sd351;
    data[ 487] = -'sd6669;
    data[ 488] = -'sd3829;
    data[ 489] = -'sd11310;
    data[ 490] = -'sd30567;
    data[ 491] = -'sd27804;
    data[ 492] =  'sd24693;
    data[ 493] = -'sd22361;
    data[ 494] =  'sd5228;
    data[ 495] = -'sd23550;
    data[ 496] = -'sd17363;
    data[ 497] = -'sd22692;
    data[ 498] = -'sd1061;
    data[ 499] = -'sd20159;
    data[ 500] = -'sd14375;
    data[ 501] = -'sd27361;
    data[ 502] = -'sd28331;
    data[ 503] =  'sd14680;
    data[ 504] = -'sd28285;
    data[ 505] =  'sd15554;
    data[ 506] = -'sd11679;
    data[ 507] =  'sd23863;
    data[ 508] =  'sd23310;
    data[ 509] =  'sd12803;
    data[ 510] = -'sd2507;
    data[ 511] =  'sd13808;
    data[ 512] =  'sd16588;
    data[ 513] =  'sd7967;
    data[ 514] =  'sd28491;
    data[ 515] = -'sd11640;
    data[ 516] =  'sd24604;
    data[ 517] = -'sd24052;
    data[ 518] = -'sd26901;
    data[ 519] = -'sd19591;
    data[ 520] = -'sd3583;
    data[ 521] = -'sd6636;
    data[ 522] = -'sd3202;
    data[ 523] =  'sd603;
    data[ 524] =  'sd11457;
    data[ 525] = -'sd28081;
    data[ 526] =  'sd19430;
    data[ 527] =  'sd524;
    data[ 528] =  'sd9956;
    data[ 529] =  'sd4841;
    data[ 530] =  'sd30538;
    data[ 531] =  'sd27253;
    data[ 532] =  'sd26279;
    data[ 533] =  'sd7773;
    data[ 534] =  'sd24805;
    data[ 535] = -'sd20233;
    data[ 536] = -'sd15781;
    data[ 537] =  'sd7366;
    data[ 538] =  'sd17072;
    data[ 539] =  'sd17163;
    data[ 540] =  'sd18892;
    data[ 541] = -'sd9698;
    data[ 542] =  'sd61;
    data[ 543] =  'sd1159;
    data[ 544] =  'sd22021;
    data[ 545] = -'sd11688;
    data[ 546] =  'sd23692;
    data[ 547] =  'sd20061;
    data[ 548] =  'sd12513;
    data[ 549] = -'sd8017;
    data[ 550] = -'sd29441;
    data[ 551] = -'sd6410;
    data[ 552] =  'sd1092;
    data[ 553] =  'sd20748;
    data[ 554] =  'sd25566;
    data[ 555] = -'sd5774;
    data[ 556] =  'sd13176;
    data[ 557] =  'sd4580;
    data[ 558] =  'sd25579;
    data[ 559] = -'sd5527;
    data[ 560] =  'sd17869;
    data[ 561] = -'sd29135;
    data[ 562] = -'sd596;
    data[ 563] = -'sd11324;
    data[ 564] =  'sd30608;
    data[ 565] =  'sd28583;
    data[ 566] = -'sd9892;
    data[ 567] = -'sd3625;
    data[ 568] = -'sd7434;
    data[ 569] = -'sd18364;
    data[ 570] =  'sd19730;
    data[ 571] =  'sd6224;
    data[ 572] = -'sd4626;
    data[ 573] = -'sd26453;
    data[ 574] = -'sd11079;
    data[ 575] = -'sd26178;
    data[ 576] = -'sd5854;
    data[ 577] =  'sd11656;
    data[ 578] = -'sd24300;
    data[ 579] =  'sd29828;
    data[ 580] =  'sd13763;
    data[ 581] =  'sd15733;
    data[ 582] = -'sd8278;
    data[ 583] =  'sd27041;
    data[ 584] =  'sd22251;
    data[ 585] = -'sd7318;
    data[ 586] = -'sd16160;
    data[ 587] =  'sd165;
    data[ 588] =  'sd3135;
    data[ 589] = -'sd1876;
    data[ 590] =  'sd25797;
    data[ 591] = -'sd1385;
    data[ 592] = -'sd26315;
    data[ 593] = -'sd8457;
    data[ 594] =  'sd23640;
    data[ 595] =  'sd19073;
    data[ 596] = -'sd6259;
    data[ 597] =  'sd3961;
    data[ 598] =  'sd13818;
    data[ 599] =  'sd16778;
    data[ 600] =  'sd11577;
    data[ 601] = -'sd25801;
    data[ 602] =  'sd1309;
    data[ 603] =  'sd24871;
    data[ 604] = -'sd18979;
    data[ 605] =  'sd8045;
    data[ 606] =  'sd29973;
    data[ 607] =  'sd16518;
    data[ 608] =  'sd6637;
    data[ 609] =  'sd3221;
    data[ 610] = -'sd242;
    data[ 611] = -'sd4598;
    data[ 612] = -'sd25921;
    data[ 613] = -'sd971;
    data[ 614] = -'sd18449;
    data[ 615] =  'sd18115;
    data[ 616] = -'sd24461;
    data[ 617] =  'sd26769;
    data[ 618] =  'sd17083;
    data[ 619] =  'sd17372;
    data[ 620] =  'sd22863;
    data[ 621] =  'sd4310;
    data[ 622] =  'sd20449;
    data[ 623] =  'sd19885;
    data[ 624] =  'sd9169;
    data[ 625] = -'sd10112;
    data[ 626] = -'sd7805;
    data[ 627] = -'sd25413;
    data[ 628] =  'sd8681;
    data[ 629] = -'sd19384;
    data[ 630] =  'sd350;
    data[ 631] =  'sd6650;
    data[ 632] =  'sd3468;
    data[ 633] =  'sd4451;
    data[ 634] =  'sd23128;
    data[ 635] =  'sd9345;
    data[ 636] = -'sd6768;
    data[ 637] = -'sd5710;
    data[ 638] =  'sd14392;
    data[ 639] =  'sd27684;
    data[ 640] = -'sd26973;
    data[ 641] = -'sd20959;
    data[ 642] = -'sd29575;
    data[ 643] = -'sd8956;
    data[ 644] =  'sd14159;
    data[ 645] =  'sd23257;
    data[ 646] =  'sd11796;
    data[ 647] = -'sd21640;
    data[ 648] =  'sd18927;
    data[ 649] = -'sd9033;
    data[ 650] =  'sd12696;
    data[ 651] = -'sd4540;
    data[ 652] = -'sd24819;
    data[ 653] =  'sd19967;
    data[ 654] =  'sd10727;
    data[ 655] =  'sd19490;
    data[ 656] =  'sd1664;
    data[ 657] = -'sd29825;
    data[ 658] = -'sd13706;
    data[ 659] = -'sd14650;
    data[ 660] =  'sd28855;
    data[ 661] = -'sd4724;
    data[ 662] = -'sd28315;
    data[ 663] =  'sd14984;
    data[ 664] = -'sd22509;
    data[ 665] =  'sd2416;
    data[ 666] = -'sd15537;
    data[ 667] =  'sd12002;
    data[ 668] = -'sd17726;
    data[ 669] = -'sd29589;
    data[ 670] = -'sd9222;
    data[ 671] =  'sd9105;
    data[ 672] = -'sd11328;
    data[ 673] =  'sd30532;
    data[ 674] =  'sd27139;
    data[ 675] =  'sd24113;
    data[ 676] =  'sd28060;
    data[ 677] = -'sd19829;
    data[ 678] = -'sd8105;
    data[ 679] =  'sd30328;
    data[ 680] =  'sd23263;
    data[ 681] =  'sd11910;
    data[ 682] = -'sd19474;
    data[ 683] = -'sd1360;
    data[ 684] = -'sd25840;
    data[ 685] =  'sd568;
    data[ 686] =  'sd10792;
    data[ 687] =  'sd20725;
    data[ 688] =  'sd25129;
    data[ 689] = -'sd14077;
    data[ 690] = -'sd21699;
    data[ 691] =  'sd17806;
    data[ 692] = -'sd30332;
    data[ 693] = -'sd23339;
    data[ 694] = -'sd13354;
    data[ 695] = -'sd7962;
    data[ 696] = -'sd28396;
    data[ 697] =  'sd13445;
    data[ 698] =  'sd9691;
    data[ 699] = -'sd194;
    data[ 700] = -'sd3686;
    data[ 701] = -'sd8593;
    data[ 702] =  'sd21056;
    data[ 703] = -'sd30023;
    data[ 704] = -'sd17468;
    data[ 705] = -'sd24687;
    data[ 706] =  'sd22475;
    data[ 707] = -'sd3062;
    data[ 708] =  'sd3263;
    data[ 709] =  'sd556;
    data[ 710] =  'sd10564;
    data[ 711] =  'sd16393;
    data[ 712] =  'sd4262;
    data[ 713] =  'sd19537;
    data[ 714] =  'sd2557;
    data[ 715] = -'sd12858;
    data[ 716] =  'sd1462;
    data[ 717] =  'sd27778;
    data[ 718] = -'sd25187;
    data[ 719] =  'sd12975;
    data[ 720] =  'sd761;
    data[ 721] =  'sd14459;
    data[ 722] =  'sd28957;
    data[ 723] = -'sd2786;
    data[ 724] =  'sd8507;
    data[ 725] = -'sd22690;
    data[ 726] = -'sd1023;
    data[ 727] = -'sd19437;
    data[ 728] = -'sd657;
    data[ 729] = -'sd12483;
    data[ 730] =  'sd8587;
    data[ 731] = -'sd21170;
    data[ 732] =  'sd27857;
    data[ 733] = -'sd23686;
    data[ 734] = -'sd19947;
    data[ 735] = -'sd10347;
    data[ 736] = -'sd12270;
    data[ 737] =  'sd12634;
    data[ 738] = -'sd5718;
    data[ 739] =  'sd14240;
    data[ 740] =  'sd24796;
    data[ 741] = -'sd20404;
    data[ 742] = -'sd19030;
    data[ 743] =  'sd7076;
    data[ 744] =  'sd11562;
    data[ 745] = -'sd26086;
    data[ 746] = -'sd4106;
    data[ 747] = -'sd16573;
    data[ 748] = -'sd7682;
    data[ 749] = -'sd23076;
    data[ 750] = -'sd8357;
    data[ 751] =  'sd25540;
    data[ 752] = -'sd6268;
    data[ 753] =  'sd3790;
    data[ 754] =  'sd10569;
    data[ 755] =  'sd16488;
    data[ 756] =  'sd6067;
    data[ 757] = -'sd7609;
    data[ 758] = -'sd21689;
    data[ 759] =  'sd17996;
    data[ 760] = -'sd26722;
    data[ 761] = -'sd16190;
    data[ 762] = -'sd405;
    data[ 763] = -'sd7695;
    data[ 764] = -'sd23323;
    data[ 765] = -'sd13050;
    data[ 766] = -'sd2186;
    data[ 767] =  'sd19907;
    data[ 768] =  'sd9587;
    data[ 769] = -'sd2170;
    data[ 770] =  'sd20211;
    data[ 771] =  'sd15363;
    data[ 772] = -'sd15308;
    data[ 773] =  'sd16353;
    data[ 774] =  'sd3502;
    data[ 775] =  'sd5097;
    data[ 776] = -'sd26039;
    data[ 777] = -'sd3213;
    data[ 778] =  'sd394;
    data[ 779] =  'sd7486;
    data[ 780] =  'sd19352;
    data[ 781] = -'sd958;
    data[ 782] = -'sd18202;
    data[ 783] =  'sd22808;
    data[ 784] =  'sd3265;
    data[ 785] =  'sd594;
    data[ 786] =  'sd11286;
    data[ 787] =  'sd30111;
    data[ 788] =  'sd19140;
    data[ 789] = -'sd4986;
    data[ 790] =  'sd28148;
    data[ 791] = -'sd18157;
    data[ 792] =  'sd23663;
    data[ 793] =  'sd19510;
    data[ 794] =  'sd2044;
    data[ 795] = -'sd22605;
    data[ 796] =  'sd592;
    data[ 797] =  'sd11248;
    data[ 798] =  'sd29389;
    data[ 799] =  'sd5422;
    data[ 800] = -'sd19864;
    data[ 801] = -'sd8770;
    data[ 802] =  'sd17693;
    data[ 803] =  'sd28962;
    data[ 804] = -'sd2691;
    data[ 805] =  'sd10312;
    data[ 806] =  'sd11605;
    data[ 807] = -'sd25269;
    data[ 808] =  'sd11417;
    data[ 809] = -'sd28841;
    data[ 810] =  'sd4990;
    data[ 811] = -'sd28072;
    data[ 812] =  'sd19601;
    data[ 813] =  'sd3773;
    data[ 814] =  'sd10246;
    data[ 815] =  'sd10351;
    data[ 816] =  'sd12346;
    data[ 817] = -'sd11190;
    data[ 818] = -'sd28287;
    data[ 819] =  'sd15516;
    data[ 820] = -'sd12401;
    data[ 821] =  'sd10145;
    data[ 822] =  'sd8432;
    data[ 823] = -'sd24115;
    data[ 824] = -'sd28098;
    data[ 825] =  'sd19107;
    data[ 826] = -'sd5613;
    data[ 827] =  'sd16235;
    data[ 828] =  'sd1260;
    data[ 829] =  'sd23940;
    data[ 830] =  'sd24773;
    data[ 831] = -'sd20841;
    data[ 832] = -'sd27333;
    data[ 833] = -'sd27799;
    data[ 834] =  'sd24788;
    data[ 835] = -'sd20556;
    data[ 836] = -'sd21918;
    data[ 837] =  'sd13645;
    data[ 838] =  'sd13491;
    data[ 839] =  'sd10565;
    data[ 840] =  'sd16412;
    data[ 841] =  'sd4623;
    data[ 842] =  'sd26396;
    data[ 843] =  'sd9996;
    data[ 844] =  'sd5601;
    data[ 845] = -'sd16463;
    data[ 846] = -'sd5592;
    data[ 847] =  'sd16634;
    data[ 848] =  'sd8841;
    data[ 849] = -'sd16344;
    data[ 850] = -'sd3331;
    data[ 851] = -'sd1848;
    data[ 852] =  'sd26329;
    data[ 853] =  'sd8723;
    data[ 854] = -'sd18586;
    data[ 855] =  'sd15512;
    data[ 856] = -'sd12477;
    data[ 857] =  'sd8701;
    data[ 858] = -'sd19004;
    data[ 859] =  'sd7570;
    data[ 860] =  'sd20948;
    data[ 861] =  'sd29366;
    data[ 862] =  'sd4985;
    data[ 863] = -'sd28167;
    data[ 864] =  'sd17796;
    data[ 865] = -'sd30522;
    data[ 866] = -'sd26949;
    data[ 867] = -'sd20503;
    data[ 868] = -'sd20911;
    data[ 869] = -'sd28663;
    data[ 870] =  'sd8372;
    data[ 871] = -'sd25255;
    data[ 872] =  'sd11683;
    data[ 873] = -'sd23787;
    data[ 874] = -'sd21866;
    data[ 875] =  'sd14633;
    data[ 876] = -'sd29178;
    data[ 877] = -'sd1413;
    data[ 878] = -'sd26847;
    data[ 879] = -'sd18565;
    data[ 880] =  'sd15911;
    data[ 881] = -'sd4896;
    data[ 882] =  'sd29858;
    data[ 883] =  'sd14333;
    data[ 884] =  'sd26563;
    data[ 885] =  'sd13169;
    data[ 886] =  'sd4447;
    data[ 887] =  'sd23052;
    data[ 888] =  'sd7901;
    data[ 889] =  'sd27237;
    data[ 890] =  'sd25975;
    data[ 891] =  'sd1997;
    data[ 892] = -'sd23498;
    data[ 893] = -'sd16375;
    data[ 894] = -'sd3920;
    data[ 895] = -'sd13039;
    data[ 896] = -'sd1977;
    data[ 897] =  'sd23878;
    data[ 898] =  'sd23595;
    data[ 899] =  'sd18218;
    data[ 900] = -'sd22504;
    data[ 901] =  'sd2511;
    data[ 902] = -'sd13732;
    data[ 903] = -'sd15144;
    data[ 904] =  'sd19469;
    data[ 905] =  'sd1265;
    data[ 906] =  'sd24035;
    data[ 907] =  'sd26578;
    data[ 908] =  'sd13454;
    data[ 909] =  'sd9862;
    data[ 910] =  'sd3055;
    data[ 911] = -'sd3396;
    data[ 912] = -'sd3083;
    data[ 913] =  'sd2864;
    data[ 914] = -'sd7025;
    data[ 915] = -'sd10593;
    data[ 916] = -'sd16944;
    data[ 917] = -'sd14731;
    data[ 918] =  'sd27316;
    data[ 919] =  'sd27476;
    data[ 920] =  'sd30516;
    data[ 921] =  'sd26835;
    data[ 922] =  'sd18337;
    data[ 923] = -'sd20243;
    data[ 924] = -'sd15971;
    data[ 925] =  'sd3756;
    data[ 926] =  'sd9923;
    data[ 927] =  'sd4214;
    data[ 928] =  'sd18625;
    data[ 929] = -'sd14771;
    data[ 930] =  'sd26556;
    data[ 931] =  'sd13036;
    data[ 932] =  'sd1920;
    data[ 933] = -'sd24961;
    data[ 934] =  'sd17269;
    data[ 935] =  'sd20906;
    data[ 936] =  'sd28568;
    data[ 937] = -'sd10177;
    data[ 938] = -'sd9040;
    data[ 939] =  'sd12563;
    data[ 940] = -'sd7067;
    data[ 941] = -'sd11391;
    data[ 942] =  'sd29335;
    data[ 943] =  'sd4396;
    data[ 944] =  'sd22083;
    data[ 945] = -'sd10510;
    data[ 946] = -'sd15367;
    data[ 947] =  'sd15232;
    data[ 948] = -'sd17797;
    data[ 949] =  'sd30503;
    data[ 950] =  'sd26588;
    data[ 951] =  'sd13644;
    data[ 952] =  'sd13472;
    data[ 953] =  'sd10204;
    data[ 954] =  'sd9553;
    data[ 955] = -'sd2816;
    data[ 956] =  'sd7937;
    data[ 957] =  'sd27921;
    data[ 958] = -'sd22470;
    data[ 959] =  'sd3157;
    data[ 960] = -'sd1458;
    data[ 961] = -'sd27702;
    data[ 962] =  'sd26631;
    data[ 963] =  'sd14461;
    data[ 964] =  'sd28995;
    data[ 965] = -'sd2064;
    data[ 966] =  'sd22225;
    data[ 967] = -'sd7812;
    data[ 968] = -'sd25546;
    data[ 969] =  'sd6154;
    data[ 970] = -'sd5956;
    data[ 971] =  'sd9718;
    data[ 972] =  'sd319;
    data[ 973] =  'sd6061;
    data[ 974] = -'sd7723;
    data[ 975] = -'sd23855;
    data[ 976] = -'sd23158;
    data[ 977] = -'sd9915;
    data[ 978] = -'sd4062;
    data[ 979] = -'sd15737;
    data[ 980] =  'sd8202;
    data[ 981] = -'sd28485;
    data[ 982] =  'sd11754;
    data[ 983] = -'sd22438;
    data[ 984] =  'sd3765;
    data[ 985] =  'sd10094;
    data[ 986] =  'sd7463;
    data[ 987] =  'sd18915;
    data[ 988] = -'sd9261;
    data[ 989] =  'sd8364;
    data[ 990] = -'sd25407;
    data[ 991] =  'sd8795;
    data[ 992] = -'sd17218;
    data[ 993] = -'sd19937;
    data[ 994] = -'sd10157;
    data[ 995] = -'sd8660;
    data[ 996] =  'sd19783;
    data[ 997] =  'sd7231;
    data[ 998] =  'sd14507;
    data[ 999] =  'sd29869;
    data[1000] =  'sd14542;
    data[1001] =  'sd30534;
    data[1002] =  'sd27177;
    data[1003] =  'sd24835;
    data[1004] = -'sd19663;
    data[1005] = -'sd4951;
    data[1006] =  'sd28813;
    data[1007] = -'sd5522;
    data[1008] =  'sd17964;
    data[1009] = -'sd27330;
    data[1010] = -'sd27742;
    data[1011] =  'sd25871;
    data[1012] =  'sd21;
    data[1013] =  'sd399;
    data[1014] =  'sd7581;
    data[1015] =  'sd21157;
    data[1016] = -'sd28104;
    data[1017] =  'sd18993;
    data[1018] = -'sd7779;
    data[1019] = -'sd24919;
    data[1020] =  'sd18067;
    data[1021] = -'sd25373;
    data[1022] =  'sd9441;
    data[1023] = -'sd4944;
    data[1024] =  'sd28946;
    data[1025] = -'sd2995;
    data[1026] =  'sd4536;
    data[1027] =  'sd24743;
    data[1028] = -'sd21411;
    data[1029] =  'sd23278;
    data[1030] =  'sd12195;
    data[1031] = -'sd14059;
    data[1032] = -'sd21357;
    data[1033] =  'sd24304;
    data[1034] = -'sd29752;
    data[1035] = -'sd12319;
    data[1036] =  'sd11703;
    data[1037] = -'sd23407;
    data[1038] = -'sd14646;
    data[1039] =  'sd28931;
    data[1040] = -'sd3280;
    data[1041] = -'sd879;
    data[1042] = -'sd16701;
    data[1043] = -'sd10114;
    data[1044] = -'sd7843;
    data[1045] = -'sd26135;
    data[1046] = -'sd5037;
    data[1047] =  'sd27179;
    data[1048] =  'sd24873;
    data[1049] = -'sd18941;
    data[1050] =  'sd8767;
    data[1051] = -'sd17750;
    data[1052] = -'sd30045;
    data[1053] = -'sd17886;
    data[1054] =  'sd28812;
    data[1055] = -'sd5541;
    data[1056] =  'sd17603;
    data[1057] =  'sd27252;
    data[1058] =  'sd26260;
    data[1059] =  'sd7412;
    data[1060] =  'sd17946;
    data[1061] = -'sd27672;
    data[1062] =  'sd27201;
    data[1063] =  'sd25291;
    data[1064] = -'sd10999;
    data[1065] = -'sd24658;
    data[1066] =  'sd23026;
    data[1067] =  'sd7407;
    data[1068] =  'sd17851;
    data[1069] = -'sd29477;
    data[1070] = -'sd7094;
    data[1071] = -'sd11904;
    data[1072] =  'sd19588;
    data[1073] =  'sd3526;
    data[1074] =  'sd5553;
    data[1075] = -'sd17375;
    data[1076] = -'sd22920;
    data[1077] = -'sd5393;
    data[1078] =  'sd20415;
    data[1079] =  'sd19239;
    data[1080] = -'sd3105;
    data[1081] =  'sd2446;
    data[1082] = -'sd14967;
    data[1083] =  'sd22832;
    data[1084] =  'sd3721;
    data[1085] =  'sd9258;
    data[1086] = -'sd8421;
    data[1087] =  'sd24324;
    data[1088] = -'sd29372;
    data[1089] = -'sd5099;
    data[1090] =  'sd26001;
    data[1091] =  'sd2491;
    data[1092] = -'sd14112;
    data[1093] = -'sd22364;
    data[1094] =  'sd5171;
    data[1095] = -'sd24633;
    data[1096] =  'sd23501;
    data[1097] =  'sd16432;
    data[1098] =  'sd5003;
    data[1099] = -'sd27825;
    data[1100] =  'sd24294;
    data[1101] = -'sd29942;
    data[1102] = -'sd15929;
    data[1103] =  'sd4554;
    data[1104] =  'sd25085;
    data[1105] = -'sd14913;
    data[1106] =  'sd23858;
    data[1107] =  'sd23215;
    data[1108] =  'sd10998;
    data[1109] =  'sd24639;
    data[1110] = -'sd23387;
    data[1111] = -'sd14266;
    data[1112] = -'sd25290;
    data[1113] =  'sd11018;
    data[1114] =  'sd25019;
    data[1115] = -'sd16167;
    data[1116] =  'sd32;
    data[1117] =  'sd608;
    data[1118] =  'sd11552;
    data[1119] = -'sd26276;
    data[1120] = -'sd7716;
    data[1121] = -'sd23722;
    data[1122] = -'sd20631;
    data[1123] = -'sd23343;
    data[1124] = -'sd13430;
    data[1125] = -'sd9406;
    data[1126] =  'sd5609;
    data[1127] = -'sd16311;
    data[1128] = -'sd2704;
    data[1129] =  'sd10065;
    data[1130] =  'sd6912;
    data[1131] =  'sd8446;
    data[1132] = -'sd23849;
    data[1133] = -'sd23044;
    data[1134] = -'sd7749;
    data[1135] = -'sd24349;
    data[1136] =  'sd28897;
    data[1137] = -'sd3926;
    data[1138] = -'sd13153;
    data[1139] = -'sd4143;
    data[1140] = -'sd17276;
    data[1141] = -'sd21039;
    data[1142] =  'sd30346;
    data[1143] =  'sd23605;
    data[1144] =  'sd18408;
    data[1145] = -'sd18894;
    data[1146] =  'sd9660;
    data[1147] = -'sd783;
    data[1148] = -'sd14877;
    data[1149] =  'sd24542;
    data[1150] = -'sd25230;
    data[1151] =  'sd12158;
    data[1152] = -'sd14762;
    data[1153] =  'sd26727;
    data[1154] =  'sd16285;
    data[1155] =  'sd2210;
    data[1156] = -'sd19451;
    data[1157] = -'sd923;
    data[1158] = -'sd17537;
    data[1159] = -'sd25998;
    data[1160] = -'sd2434;
    data[1161] =  'sd15195;
    data[1162] = -'sd18500;
    data[1163] =  'sd17146;
    data[1164] =  'sd18569;
    data[1165] = -'sd15835;
    data[1166] =  'sd6340;
    data[1167] = -'sd2422;
    data[1168] =  'sd15423;
    data[1169] = -'sd14168;
    data[1170] = -'sd23428;
    data[1171] = -'sd15045;
    data[1172] =  'sd21350;
    data[1173] = -'sd24437;
    data[1174] =  'sd27225;
    data[1175] =  'sd25747;
    data[1176] = -'sd2335;
    data[1177] =  'sd17076;
    data[1178] =  'sd17239;
    data[1179] =  'sd20336;
    data[1180] =  'sd17738;
    data[1181] =  'sd29817;
    data[1182] =  'sd13554;
    data[1183] =  'sd11762;
    data[1184] = -'sd22286;
    data[1185] =  'sd6653;
    data[1186] =  'sd3525;
    data[1187] =  'sd5534;
    data[1188] = -'sd17736;
    data[1189] = -'sd29779;
    data[1190] = -'sd12832;
    data[1191] =  'sd1956;
    data[1192] = -'sd24277;
    data[1193] =  'sd30265;
    data[1194] =  'sd22066;
    data[1195] = -'sd10833;
    data[1196] = -'sd21504;
    data[1197] =  'sd21511;
    data[1198] = -'sd21378;
    data[1199] =  'sd23905;
    data[1200] =  'sd24108;
    data[1201] =  'sd27965;
    data[1202] = -'sd21634;
    data[1203] =  'sd19041;
    data[1204] = -'sd6867;
    data[1205] = -'sd7591;
    data[1206] = -'sd21347;
    data[1207] =  'sd24494;
    data[1208] = -'sd26142;
    data[1209] = -'sd5170;
    data[1210] =  'sd24652;
    data[1211] = -'sd23140;
    data[1212] = -'sd9573;
    data[1213] =  'sd2436;
    data[1214] = -'sd15157;
    data[1215] =  'sd19222;
    data[1216] = -'sd3428;
    data[1217] = -'sd3691;
    data[1218] = -'sd8688;
    data[1219] =  'sd19251;
    data[1220] = -'sd2877;
    data[1221] =  'sd6778;
    data[1222] =  'sd5900;
    data[1223] = -'sd10782;
    data[1224] = -'sd20535;
    data[1225] = -'sd21519;
    data[1226] =  'sd21226;
    data[1227] = -'sd26793;
    data[1228] = -'sd17539;
    data[1229] = -'sd26036;
    data[1230] = -'sd3156;
    data[1231] =  'sd1477;
    data[1232] =  'sd28063;
    data[1233] = -'sd19772;
    data[1234] = -'sd7022;
    data[1235] = -'sd10536;
    data[1236] = -'sd15861;
    data[1237] =  'sd5846;
    data[1238] = -'sd11808;
    data[1239] =  'sd21412;
    data[1240] = -'sd23259;
    data[1241] = -'sd11834;
    data[1242] =  'sd20918;
    data[1243] =  'sd28796;
    data[1244] = -'sd5845;
    data[1245] =  'sd11827;
    data[1246] = -'sd21051;
    data[1247] =  'sd30118;
    data[1248] =  'sd19273;
    data[1249] = -'sd2459;
    data[1250] =  'sd14720;
    data[1251] = -'sd27525;
    data[1252] =  'sd29994;
    data[1253] =  'sd16917;
    data[1254] =  'sd14218;
    data[1255] =  'sd24378;
    data[1256] = -'sd28346;
    data[1257] =  'sd14395;
    data[1258] =  'sd27741;
    data[1259] = -'sd25890;
    data[1260] = -'sd382;
    data[1261] = -'sd7258;
    data[1262] = -'sd15020;
    data[1263] =  'sd21825;
    data[1264] = -'sd15412;
    data[1265] =  'sd14377;
    data[1266] =  'sd27399;
    data[1267] =  'sd29053;
    data[1268] = -'sd962;
    data[1269] = -'sd18278;
    data[1270] =  'sd21364;
    data[1271] = -'sd24171;
    data[1272] = -'sd29162;
    data[1273] = -'sd1109;
    data[1274] = -'sd21071;
    data[1275] =  'sd29738;
    data[1276] =  'sd12053;
    data[1277] = -'sd16757;
    data[1278] = -'sd11178;
    data[1279] = -'sd28059;
    data[1280] =  'sd19848;
    data[1281] =  'sd8466;
    data[1282] = -'sd23469;
    data[1283] = -'sd15824;
    data[1284] =  'sd6549;
    data[1285] =  'sd1549;
    data[1286] =  'sd29431;
    data[1287] =  'sd6220;
    data[1288] = -'sd4702;
    data[1289] = -'sd27897;
    data[1290] =  'sd22926;
    data[1291] =  'sd5507;
    data[1292] = -'sd18249;
    data[1293] =  'sd21915;
    data[1294] = -'sd13702;
    data[1295] = -'sd14574;
    data[1296] =  'sd30299;
    data[1297] =  'sd22712;
    data[1298] =  'sd1441;
    data[1299] =  'sd27379;
    data[1300] =  'sd28673;
    data[1301] = -'sd8182;
    data[1302] =  'sd28865;
    data[1303] = -'sd4534;
    data[1304] = -'sd24705;
    data[1305] =  'sd22133;
    data[1306] = -'sd9560;
    data[1307] =  'sd2683;
    data[1308] = -'sd10464;
    data[1309] = -'sd14493;
    data[1310] = -'sd29603;
    data[1311] = -'sd9488;
    data[1312] =  'sd4051;
    data[1313] =  'sd15528;
    data[1314] = -'sd12173;
    data[1315] =  'sd14477;
    data[1316] =  'sd29299;
    data[1317] =  'sd3712;
    data[1318] =  'sd9087;
    data[1319] = -'sd11670;
    data[1320] =  'sd24034;
    data[1321] =  'sd26559;
    data[1322] =  'sd13093;
    data[1323] =  'sd3003;
    data[1324] = -'sd4384;
    data[1325] = -'sd21855;
    data[1326] =  'sd14842;
    data[1327] = -'sd25207;
    data[1328] =  'sd12595;
    data[1329] = -'sd6459;
    data[1330] =  'sd161;
    data[1331] =  'sd3059;
    data[1332] = -'sd3320;
    data[1333] = -'sd1639;
    data[1334] =  'sd30300;
    data[1335] =  'sd22731;
    data[1336] =  'sd1802;
    data[1337] = -'sd27203;
    data[1338] = -'sd25329;
    data[1339] =  'sd10277;
    data[1340] =  'sd10940;
    data[1341] =  'sd23537;
    data[1342] =  'sd17116;
    data[1343] =  'sd17999;
    data[1344] = -'sd26665;
    data[1345] = -'sd15107;
    data[1346] =  'sd20172;
    data[1347] =  'sd14622;
    data[1348] = -'sd29387;
    data[1349] = -'sd5384;
    data[1350] =  'sd20586;
    data[1351] =  'sd22488;
    data[1352] = -'sd2815;
    data[1353] =  'sd7956;
    data[1354] =  'sd28282;
    data[1355] = -'sd15611;
    data[1356] =  'sd10596;
    data[1357] =  'sd17001;
    data[1358] =  'sd15814;
    data[1359] = -'sd6739;
    data[1360] = -'sd5159;
    data[1361] =  'sd24861;
    data[1362] = -'sd19169;
    data[1363] =  'sd4435;
    data[1364] =  'sd22824;
    data[1365] =  'sd3569;
    data[1366] =  'sd6370;
    data[1367] = -'sd1852;
    data[1368] =  'sd26253;
    data[1369] =  'sd7279;
    data[1370] =  'sd15419;
    data[1371] = -'sd14244;
    data[1372] = -'sd24872;
    data[1373] =  'sd18960;
    data[1374] = -'sd8406;
    data[1375] =  'sd24609;
    data[1376] = -'sd23957;
    data[1377] = -'sd25096;
    data[1378] =  'sd14704;
    data[1379] = -'sd27829;
    data[1380] =  'sd24218;
    data[1381] =  'sd30055;
    data[1382] =  'sd18076;
    data[1383] = -'sd25202;
    data[1384] =  'sd12690;
    data[1385] = -'sd4654;
    data[1386] = -'sd26985;
    data[1387] = -'sd21187;
    data[1388] =  'sd27534;
    data[1389] = -'sd29823;
    data[1390] = -'sd13668;
    data[1391] = -'sd13928;
    data[1392] = -'sd18868;
    data[1393] =  'sd10154;
    data[1394] =  'sd8603;
    data[1395] = -'sd20866;
    data[1396] = -'sd27808;
    data[1397] =  'sd24617;
    data[1398] = -'sd23805;
    data[1399] = -'sd22208;
    data[1400] =  'sd8135;
    data[1401] = -'sd29758;
    data[1402] = -'sd12433;
    data[1403] =  'sd9537;
    data[1404] = -'sd3120;
    data[1405] =  'sd2161;
    data[1406] = -'sd20382;
    data[1407] = -'sd18612;
    data[1408] =  'sd15018;
    data[1409] = -'sd21863;
    data[1410] =  'sd14690;
    data[1411] = -'sd28095;
    data[1412] =  'sd19164;
    data[1413] = -'sd4530;
    data[1414] = -'sd24629;
    data[1415] =  'sd23577;
    data[1416] =  'sd17876;
    data[1417] = -'sd29002;
    data[1418] =  'sd1931;
    data[1419] = -'sd24752;
    data[1420] =  'sd21240;
    data[1421] = -'sd26527;
    data[1422] = -'sd12485;
    data[1423] =  'sd8549;
    data[1424] = -'sd21892;
    data[1425] =  'sd14139;
    data[1426] =  'sd22877;
    data[1427] =  'sd4576;
    data[1428] =  'sd25503;
    data[1429] = -'sd6971;
    data[1430] = -'sd9567;
    data[1431] =  'sd2550;
    data[1432] = -'sd12991;
    data[1433] = -'sd1065;
    data[1434] = -'sd20235;
    data[1435] = -'sd15819;
    data[1436] =  'sd6644;
    data[1437] =  'sd3354;
    data[1438] =  'sd2285;
    data[1439] = -'sd18026;
    data[1440] =  'sd26152;
    data[1441] =  'sd5360;
    data[1442] = -'sd21042;
    data[1443] =  'sd30289;
    data[1444] =  'sd22522;
    data[1445] = -'sd2169;
    data[1446] =  'sd20230;
    data[1447] =  'sd15724;
    data[1448] = -'sd8449;
    data[1449] =  'sd23792;
    data[1450] =  'sd21961;
    data[1451] = -'sd12828;
    data[1452] =  'sd2032;
    data[1453] = -'sd22833;
    data[1454] = -'sd3740;
    data[1455] = -'sd9619;
    data[1456] =  'sd1562;
    data[1457] =  'sd29678;
    data[1458] =  'sd10913;
    data[1459] =  'sd23024;
    data[1460] =  'sd7369;
    data[1461] =  'sd17129;
    data[1462] =  'sd18246;
    data[1463] = -'sd21972;
    data[1464] =  'sd12619;
    data[1465] = -'sd6003;
    data[1466] =  'sd8825;
    data[1467] = -'sd16648;
    data[1468] = -'sd9107;
    data[1469] =  'sd11290;
    data[1470] =  'sd30187;
    data[1471] =  'sd20584;
    data[1472] =  'sd22450;
    data[1473] = -'sd3537;
    data[1474] = -'sd5762;
    data[1475] =  'sd13404;
    data[1476] =  'sd8912;
    data[1477] = -'sd14995;
    data[1478] =  'sd22300;
    data[1479] = -'sd6387;
    data[1480] =  'sd1529;
    data[1481] =  'sd29051;
    data[1482] = -'sd1000;
    data[1483] = -'sd19000;
    data[1484] =  'sd7646;
    data[1485] =  'sd22392;
    data[1486] = -'sd4639;
    data[1487] = -'sd26700;
    data[1488] = -'sd15772;
    data[1489] =  'sd7537;
    data[1490] =  'sd20321;
    data[1491] =  'sd17453;
    data[1492] =  'sd24402;
    data[1493] = -'sd27890;
    data[1494] =  'sd23059;
    data[1495] =  'sd8034;
    data[1496] =  'sd29764;
    data[1497] =  'sd12547;
    data[1498] = -'sd7371;
    data[1499] = -'sd17167;
    data[1500] = -'sd18968;
    data[1501] =  'sd8254;
    data[1502] = -'sd27497;
    data[1503] =  'sd30526;
    data[1504] =  'sd27025;
    data[1505] =  'sd21947;
    data[1506] = -'sd13094;
    data[1507] = -'sd3022;
    data[1508] =  'sd4023;
    data[1509] =  'sd14996;
    data[1510] = -'sd22281;
    data[1511] =  'sd6748;
    data[1512] =  'sd5330;
    data[1513] = -'sd21612;
    data[1514] =  'sd19459;
    data[1515] =  'sd1075;
    data[1516] =  'sd20425;
    data[1517] =  'sd19429;
    data[1518] =  'sd505;
    data[1519] =  'sd9595;
    data[1520] = -'sd2018;
    data[1521] =  'sd23099;
    data[1522] =  'sd8794;
    data[1523] = -'sd17237;
    data[1524] = -'sd20298;
    data[1525] = -'sd17016;
    data[1526] = -'sd16099;
    data[1527] =  'sd1324;
    data[1528] =  'sd25156;
    data[1529] = -'sd13564;
    data[1530] = -'sd11952;
    data[1531] =  'sd18676;
    data[1532] = -'sd13802;
    data[1533] = -'sd16474;
    data[1534] = -'sd5801;
    data[1535] =  'sd12663;
    data[1536] = -'sd5167;
    data[1537] =  'sd24709;
    data[1538] = -'sd22057;
    data[1539] =  'sd11004;
    data[1540] =  'sd24753;
    data[1541] = -'sd21221;
    data[1542] =  'sd26888;
    data[1543] =  'sd19344;
    data[1544] = -'sd1110;
    data[1545] = -'sd21090;
    data[1546] =  'sd29377;
    data[1547] =  'sd5194;
    data[1548] = -'sd24196;
    data[1549] = -'sd29637;
    data[1550] = -'sd10134;
    data[1551] = -'sd8223;
    data[1552] =  'sd28086;
    data[1553] = -'sd19335;
    data[1554] =  'sd1281;
    data[1555] =  'sd24339;
    data[1556] = -'sd29087;
    data[1557] =  'sd316;
    data[1558] =  'sd6004;
    data[1559] = -'sd8806;
    data[1560] =  'sd17009;
    data[1561] =  'sd15966;
    data[1562] = -'sd3851;
    data[1563] = -'sd11728;
    data[1564] =  'sd22932;
    data[1565] =  'sd5621;
    data[1566] = -'sd16083;
    data[1567] =  'sd1628;
    data[1568] = -'sd30509;
    data[1569] = -'sd26702;
    data[1570] = -'sd15810;
    data[1571] =  'sd6815;
    data[1572] =  'sd6603;
    data[1573] =  'sd2575;
    data[1574] = -'sd12516;
    data[1575] =  'sd7960;
    data[1576] =  'sd28358;
    data[1577] = -'sd14167;
    data[1578] = -'sd23409;
    data[1579] = -'sd14684;
    data[1580] =  'sd28209;
    data[1581] = -'sd16998;
    data[1582] = -'sd15757;
    data[1583] =  'sd7822;
    data[1584] =  'sd25736;
    data[1585] = -'sd2544;
    data[1586] =  'sd13105;
    data[1587] =  'sd3231;
    data[1588] = -'sd52;
    data[1589] = -'sd988;
    data[1590] = -'sd18772;
    data[1591] =  'sd11978;
    data[1592] = -'sd18182;
    data[1593] =  'sd23188;
    data[1594] =  'sd10485;
    data[1595] =  'sd14892;
    data[1596] = -'sd24257;
    data[1597] =  'sd30645;
    data[1598] =  'sd29286;
    data[1599] =  'sd3465;
    data[1600] =  'sd4394;
    data[1601] =  'sd22045;
    data[1602] = -'sd11232;
    data[1603] = -'sd29085;
    data[1604] =  'sd354;
    data[1605] =  'sd6726;
    data[1606] =  'sd4912;
    data[1607] = -'sd29554;
    data[1608] = -'sd8557;
    data[1609] =  'sd21740;
    data[1610] = -'sd17027;
    data[1611] = -'sd16308;
    data[1612] = -'sd2647;
    data[1613] =  'sd11148;
    data[1614] =  'sd27489;
    data[1615] = -'sd30678;
    data[1616] = -'sd29913;
    data[1617] = -'sd15378;
    data[1618] =  'sd15023;
    data[1619] = -'sd21768;
    data[1620] =  'sd16495;
    data[1621] =  'sd6200;
    data[1622] = -'sd5082;
    data[1623] =  'sd26324;
    data[1624] =  'sd8628;
    data[1625] = -'sd20391;
    data[1626] = -'sd18783;
    data[1627] =  'sd11769;
    data[1628] = -'sd22153;
    data[1629] =  'sd9180;
    data[1630] = -'sd9903;
    data[1631] = -'sd3834;
    data[1632] = -'sd11405;
    data[1633] =  'sd29069;
    data[1634] = -'sd658;
    data[1635] = -'sd12502;
    data[1636] =  'sd8226;
    data[1637] = -'sd28029;
    data[1638] =  'sd20418;
    data[1639] =  'sd19296;
    data[1640] = -'sd2022;
    data[1641] =  'sd23023;
    data[1642] =  'sd7350;
    data[1643] =  'sd16768;
    data[1644] =  'sd11387;
    data[1645] = -'sd29411;
    data[1646] = -'sd5840;
    data[1647] =  'sd11922;
    data[1648] = -'sd19246;
    data[1649] =  'sd2972;
    data[1650] = -'sd4973;
    data[1651] =  'sd28395;
    data[1652] = -'sd13464;
    data[1653] = -'sd10052;
    data[1654] = -'sd6665;
    data[1655] = -'sd3753;
    data[1656] = -'sd9866;
    data[1657] = -'sd3131;
    data[1658] =  'sd1952;
    data[1659] = -'sd24353;
    data[1660] =  'sd28821;
    data[1661] = -'sd5370;
    data[1662] =  'sd20852;
    data[1663] =  'sd27542;
    data[1664] = -'sd29671;
    data[1665] = -'sd10780;
    data[1666] = -'sd20497;
    data[1667] = -'sd20797;
    data[1668] = -'sd26497;
    data[1669] = -'sd11915;
    data[1670] =  'sd19379;
    data[1671] = -'sd445;
    data[1672] = -'sd8455;
    data[1673] =  'sd23678;
    data[1674] =  'sd19795;
    data[1675] =  'sd7459;
    data[1676] =  'sd18839;
    data[1677] = -'sd10705;
    data[1678] = -'sd19072;
    data[1679] =  'sd6278;
    data[1680] = -'sd3600;
    data[1681] = -'sd6959;
    data[1682] = -'sd9339;
    data[1683] =  'sd6882;
    data[1684] =  'sd7876;
    data[1685] =  'sd26762;
    data[1686] =  'sd16950;
    data[1687] =  'sd14845;
    data[1688] = -'sd25150;
    data[1689] =  'sd13678;
    data[1690] =  'sd14118;
    data[1691] =  'sd22478;
    data[1692] = -'sd3005;
    data[1693] =  'sd4346;
    data[1694] =  'sd21133;
    data[1695] = -'sd28560;
    data[1696] =  'sd10329;
    data[1697] =  'sd11928;
    data[1698] = -'sd19132;
    data[1699] =  'sd5138;
    data[1700] = -'sd25260;
    data[1701] =  'sd11588;
    data[1702] = -'sd25592;
    data[1703] =  'sd5280;
    data[1704] = -'sd22562;
    data[1705] =  'sd1409;
    data[1706] =  'sd26771;
    data[1707] =  'sd17121;
    data[1708] =  'sd18094;
    data[1709] = -'sd24860;
    data[1710] =  'sd19188;
    data[1711] = -'sd4074;
    data[1712] = -'sd15965;
    data[1713] =  'sd3870;
    data[1714] =  'sd12089;
    data[1715] = -'sd16073;
    data[1716] =  'sd1818;
    data[1717] = -'sd26899;
    data[1718] = -'sd19553;
    data[1719] = -'sd2861;
    data[1720] =  'sd7082;
    data[1721] =  'sd11676;
    data[1722] = -'sd23920;
    data[1723] = -'sd24393;
    data[1724] =  'sd28061;
    data[1725] = -'sd19810;
    data[1726] = -'sd7744;
    data[1727] = -'sd24254;
    data[1728] =  'sd30702;
    data[1729] =  'sd30369;
    data[1730] =  'sd24042;
    data[1731] =  'sd26711;
    data[1732] =  'sd15981;
    data[1733] = -'sd3566;
    data[1734] = -'sd6313;
    data[1735] =  'sd2935;
    data[1736] = -'sd5676;
    data[1737] =  'sd15038;
    data[1738] = -'sd21483;
    data[1739] =  'sd21910;
    data[1740] = -'sd13797;
    data[1741] = -'sd16379;
    data[1742] = -'sd3996;
    data[1743] = -'sd14483;
    data[1744] = -'sd29413;
    data[1745] = -'sd5878;
    data[1746] =  'sd11200;
    data[1747] =  'sd28477;
    data[1748] = -'sd11906;
    data[1749] =  'sd19550;
    data[1750] =  'sd2804;
    data[1751] = -'sd8165;
    data[1752] =  'sd29188;
    data[1753] =  'sd1603;
    data[1754] =  'sd30457;
    data[1755] =  'sd25714;
    data[1756] = -'sd2962;
    data[1757] =  'sd5163;
    data[1758] = -'sd24785;
    data[1759] =  'sd20613;
    data[1760] =  'sd23001;
    data[1761] =  'sd6932;
    data[1762] =  'sd8826;
    data[1763] = -'sd16629;
    data[1764] = -'sd8746;
    data[1765] =  'sd18149;
    data[1766] = -'sd23815;
    data[1767] = -'sd22398;
    data[1768] =  'sd4525;
    data[1769] =  'sd24534;
    data[1770] = -'sd25382;
    data[1771] =  'sd9270;
    data[1772] = -'sd8193;
    data[1773] =  'sd28656;
    data[1774] = -'sd8505;
    data[1775] =  'sd22728;
    data[1776] =  'sd1745;
    data[1777] = -'sd28286;
    data[1778] =  'sd15535;
    data[1779] = -'sd12040;
    data[1780] =  'sd17004;
    data[1781] =  'sd15871;
    data[1782] = -'sd5656;
    data[1783] =  'sd15418;
    data[1784] = -'sd14263;
    data[1785] = -'sd25233;
    data[1786] =  'sd12101;
    data[1787] = -'sd15845;
    data[1788] =  'sd6150;
    data[1789] = -'sd6032;
    data[1790] =  'sd8274;
    data[1791] = -'sd27117;
    data[1792] = -'sd23695;
    data[1793] = -'sd20118;
    data[1794] = -'sd13596;
    data[1795] = -'sd12560;
    data[1796] =  'sd7124;
    data[1797] =  'sd12474;
    data[1798] = -'sd8758;
    data[1799] =  'sd17921;
    data[1800] = -'sd28147;
    data[1801] =  'sd18176;
    data[1802] = -'sd23302;
    data[1803] = -'sd12651;
    data[1804] =  'sd5395;
    data[1805] = -'sd20377;
    data[1806] = -'sd18517;
    data[1807] =  'sd16823;
    data[1808] =  'sd12432;
    data[1809] = -'sd9556;
    data[1810] =  'sd2759;
    data[1811] = -'sd9020;
    data[1812] =  'sd12943;
    data[1813] =  'sd153;
    data[1814] =  'sd2907;
    data[1815] = -'sd6208;
    data[1816] =  'sd4930;
    data[1817] = -'sd29212;
    data[1818] = -'sd2059;
    data[1819] =  'sd22320;
    data[1820] = -'sd6007;
    data[1821] =  'sd8749;
    data[1822] = -'sd18092;
    data[1823] =  'sd24898;
    data[1824] = -'sd18466;
    data[1825] =  'sd17792;
    data[1826] = -'sd30598;
    data[1827] = -'sd28393;
    data[1828] =  'sd13502;
    data[1829] =  'sd10774;
    data[1830] =  'sd20383;
    data[1831] =  'sd18631;
    data[1832] = -'sd14657;
    data[1833] =  'sd28722;
    data[1834] = -'sd7251;
    data[1835] = -'sd14887;
    data[1836] =  'sd24352;
    data[1837] = -'sd28840;
    data[1838] =  'sd5009;
    data[1839] = -'sd27711;
    data[1840] =  'sd26460;
    data[1841] =  'sd11212;
    data[1842] =  'sd28705;
    data[1843] = -'sd7574;
    data[1844] = -'sd21024;
    data[1845] =  'sd30631;
    data[1846] =  'sd29020;
    data[1847] = -'sd1589;
    data[1848] = -'sd30191;
    data[1849] = -'sd20660;
    data[1850] = -'sd23894;
    data[1851] = -'sd23899;
    data[1852] = -'sd23994;
    data[1853] = -'sd25799;
    data[1854] =  'sd1347;
    data[1855] =  'sd25593;
    data[1856] = -'sd5261;
    data[1857] =  'sd22923;
    data[1858] =  'sd5450;
    data[1859] = -'sd19332;
    data[1860] =  'sd1338;
    data[1861] =  'sd25422;
    data[1862] = -'sd8510;
    data[1863] =  'sd22633;
    data[1864] = -'sd60;
    data[1865] = -'sd1140;
    data[1866] = -'sd21660;
    data[1867] =  'sd18547;
    data[1868] = -'sd16253;
    data[1869] = -'sd1602;
    data[1870] = -'sd30438;
    data[1871] = -'sd25353;
    data[1872] =  'sd9821;
    data[1873] =  'sd2276;
    data[1874] = -'sd18197;
    data[1875] =  'sd22903;
    data[1876] =  'sd5070;
    data[1877] = -'sd26552;
    data[1878] = -'sd12960;
    data[1879] = -'sd476;
    data[1880] = -'sd9044;
    data[1881] =  'sd12487;
    data[1882] = -'sd8511;
    data[1883] =  'sd22614;
    data[1884] = -'sd421;
    data[1885] = -'sd7999;
    data[1886] = -'sd29099;
    data[1887] =  'sd88;
    data[1888] =  'sd1672;
    data[1889] = -'sd29673;
    data[1890] = -'sd10818;
    data[1891] = -'sd21219;
    data[1892] =  'sd26926;
    data[1893] =  'sd20066;
    data[1894] =  'sd12608;
    data[1895] = -'sd6212;
    data[1896] =  'sd4854;
    data[1897] = -'sd30656;
    data[1898] = -'sd29495;
    data[1899] = -'sd7436;
    data[1900] = -'sd18402;
    data[1901] =  'sd19008;
    data[1902] = -'sd7494;
    data[1903] = -'sd19504;
    data[1904] = -'sd1930;
    data[1905] =  'sd24771;
    data[1906] = -'sd20879;
    data[1907] = -'sd28055;
    data[1908] =  'sd19924;
    data[1909] =  'sd9910;
    data[1910] =  'sd3967;
    data[1911] =  'sd13932;
    data[1912] =  'sd18944;
    data[1913] = -'sd8710;
    data[1914] =  'sd18833;
    data[1915] = -'sd10819;
    data[1916] = -'sd21238;
    data[1917] =  'sd26565;
    data[1918] =  'sd13207;
    data[1919] =  'sd5169;
    data[1920] = -'sd24671;
    data[1921] =  'sd22779;
    data[1922] =  'sd2714;
    data[1923] = -'sd9875;
    data[1924] = -'sd3302;
    data[1925] = -'sd1297;
    data[1926] = -'sd24643;
    data[1927] =  'sd23311;
    data[1928] =  'sd12822;
    data[1929] = -'sd2146;
    data[1930] =  'sd20667;
    data[1931] =  'sd24027;
    data[1932] =  'sd26426;
    data[1933] =  'sd10566;
    data[1934] =  'sd16431;
    data[1935] =  'sd4984;
    data[1936] = -'sd28186;
    data[1937] =  'sd17435;
    data[1938] =  'sd24060;
    data[1939] =  'sd27053;
    data[1940] =  'sd22479;
    data[1941] = -'sd2986;
    data[1942] =  'sd4707;
    data[1943] =  'sd27992;
    data[1944] = -'sd21121;
    data[1945] =  'sd28788;
    data[1946] = -'sd5997;
    data[1947] =  'sd8939;
    data[1948] = -'sd14482;
    data[1949] = -'sd29394;
    data[1950] = -'sd5517;
    data[1951] =  'sd18059;
    data[1952] = -'sd25525;
    data[1953] =  'sd6553;
    data[1954] =  'sd1625;
    data[1955] = -'sd30566;
    data[1956] = -'sd27785;
    data[1957] =  'sd25054;
    data[1958] = -'sd15502;
    data[1959] =  'sd12667;
    data[1960] = -'sd5091;
    data[1961] =  'sd26153;
    data[1962] =  'sd5379;
    data[1963] = -'sd20681;
    data[1964] = -'sd24293;
    data[1965] =  'sd29961;
    data[1966] =  'sd16290;
    data[1967] =  'sd2305;
    data[1968] = -'sd17646;
    data[1969] = -'sd28069;
    data[1970] =  'sd19658;
    data[1971] =  'sd4856;
    data[1972] = -'sd30618;
    data[1973] = -'sd28773;
    data[1974] =  'sd6282;
    data[1975] = -'sd3524;
    data[1976] = -'sd5515;
    data[1977] =  'sd18097;
    data[1978] = -'sd24803;
    data[1979] =  'sd20271;
    data[1980] =  'sd16503;
    data[1981] =  'sd6352;
    data[1982] = -'sd2194;
    data[1983] =  'sd19755;
    data[1984] =  'sd6699;
    data[1985] =  'sd4399;
    data[1986] =  'sd22140;
    data[1987] = -'sd9427;
    data[1988] =  'sd5210;
    data[1989] = -'sd23892;
    data[1990] = -'sd23861;
    data[1991] = -'sd23272;
    data[1992] = -'sd12081;
    data[1993] =  'sd16225;
    data[1994] =  'sd1070;
    data[1995] =  'sd20330;
    data[1996] =  'sd17624;
    data[1997] =  'sd27651;
    data[1998] = -'sd27600;
    data[1999] =  'sd28569;
    data[2000] = -'sd10158;
    data[2001] = -'sd8679;
    data[2002] =  'sd19422;
    data[2003] =  'sd372;
    data[2004] =  'sd7068;
    data[2005] =  'sd11410;
    data[2006] = -'sd28974;
    data[2007] =  'sd2463;
    data[2008] = -'sd14644;
    data[2009] =  'sd28969;
    data[2010] = -'sd2558;
    data[2011] =  'sd12839;
    data[2012] = -'sd1823;
    data[2013] =  'sd26804;
    data[2014] =  'sd17748;
    data[2015] =  'sd30007;
    data[2016] =  'sd17164;
    data[2017] =  'sd18911;
    data[2018] = -'sd9337;
    data[2019] =  'sd6920;
    data[2020] =  'sd8598;
    data[2021] = -'sd20961;
    data[2022] = -'sd29613;
    data[2023] = -'sd9678;
    data[2024] =  'sd441;
    data[2025] =  'sd8379;
    data[2026] = -'sd25122;
    data[2027] =  'sd14210;
    data[2028] =  'sd24226;
    data[2029] =  'sd30207;
    data[2030] =  'sd20964;
    data[2031] =  'sd29670;
    data[2032] =  'sd10761;
    data[2033] =  'sd20136;
    data[2034] =  'sd13938;
    data[2035] =  'sd19058;
    data[2036] = -'sd6544;
    data[2037] = -'sd1454;
    data[2038] = -'sd27626;
    data[2039] =  'sd28075;
    data[2040] = -'sd19544;
    data[2041] = -'sd2690;
    data[2042] =  'sd10331;
    data[2043] =  'sd11966;
    data[2044] = -'sd18410;
    data[2045] =  'sd18856;
    data[2046] = -'sd10382;
    data[2047] = -'sd12935;
  end

endmodule

