`timescale 1ns/100ps
`define stringify(x) `"x`"

module tb_ntt;

    parameter RUNS = 1;
    parameter HALFCLK = 5;
    localparam FULLCLK = 2 * HALFCLK;

    localparam NTRUPRIME_P      = `PRIMEP;
    localparam NTRUPRIME_Q      = `PRIMEQ;
    localparam NTRUPRIME_PC     = `PCOVER;
    localparam NTRUPRIME_LG2_Q  = $clog2(NTRUPRIME_Q);
    localparam NTRUPRIME_LG2_PC = $clog2(NTRUPRIME_PC);

    /* clock setting */
    reg clk;
        initial begin
        clk=0;
    end
    always #(HALFCLK) clk<=~clk;

    reg [1024:0] waveformfile;

    /* vcd file setting */
    initial begin
        waveformfile = { "tb_", `stringify(`NTTMODULE), ".fsdb" } ; 
        //$fsdbDumpfile("tb_ntt.fsdb");
        $fsdbDumpfile(waveformfile);
        $fsdbDumpvars;
        #(1048576*FULLCLK);
        $finish;
    end

    reg           rst;

    reg   [NTRUPRIME_LG2_PC+1:0]  addr [9:0];
    wire  [NTRUPRIME_LG2_PC:0]  addr1;
    wire  [NTRUPRIME_LG2_PC:0]  addr3;
    wire  [NTRUPRIME_LG2_PC:0]  addr4;
    wire  [NTRUPRIME_LG2_PC:0]  addr5;
    wire  [NTRUPRIME_LG2_PC:0]  addr8;
    wire  [NTRUPRIME_LG2_PC:0]  addr9;

    reg   [3:0]   start;
    wire          start3;
    reg   [3:0]   input_fg;
    wire          input_fg2;
    wire          input_fg3;

    reg   [NTRUPRIME_LG2_Q-1 : 0]  din;
    wire  [NTRUPRIME_LG2_Q-1 : 0]  dout;
    wire                valid;

    wire  [NTRUPRIME_LG2_Q-1 : 0]  f_dout;
    wire  [NTRUPRIME_LG2_Q-1 : 0]  g_dout;
    wire  [NTRUPRIME_LG2_Q-1 : 0]  h_dref;
    wire  [NTRUPRIME_LG2_Q-1 : 0]  hp_dref;

    reg           comparison;
    wire          equal;
    wire          equal_p;

    assign addr1 = addr[1];
    assign addr3 = addr[3];
    assign addr4 = addr[4];
    assign addr5 = addr[5];
    assign addr8 = addr[8];
    assign addr9 = addr[9];

    assign start3 = start[3];
    assign input_fg2 = input_fg[2];
    assign input_fg3 = input_fg[3];

    `NTTMODULE ntt0 ( .clk(clk), .rst(rst), .start(start3), .input_fg(input_fg3),
                      .addr(addr3), .din(din), .dout(dout), .valid(valid) );

    f_rom  f_r0  ( .clk(clk), .rst(rst), .addr(addr1), .dout(f_dout)  );
    g_rom  g_r0  ( .clk(clk), .rst(rst), .addr(addr1), .dout(g_dout)  );
    //hp_rom hp_r0 ( .clk(clk), .rst(rst), .addr(addr4), .dout(hp_dref) );
    hp_rom hp_r0 ( .clk(clk), .rst(rst), .addr(addr8), .dout(hp_dref) );
    h_rom  h_r0  ( .clk(clk), .rst(rst), .addr(addr8), .dout(h_dref)  );

    integer index;
    always @ (posedge clk) begin
      if(rst) begin
        start[3:1] <= 0; input_fg[3:1] <= 0;
        for(index = 1; index <= 9; index = index + 1) begin
          addr[index] <= 'd0;
        end
      end else begin
        start[3:1] <= start[2:0]; input_fg[3:1] <= input_fg[2:0];
        for(index = 1; index <= 9; index = index + 1) begin
          addr[index] <= addr[index-1];
        end
      end
    end

    always @ (posedge clk) begin
      if(rst) begin
        din <= 'sd0;
      end else begin
        if(valid) begin
          din <= 'sd0;
        end else begin
          if(!input_fg2) begin
            din <= f_dout;
          end else begin
            din <= g_dout;
          end
        end
      end
    end

    assign equal = ($signed(dout) == $signed(h_dref));
    assign equal_p = ($signed(dout) == $signed(hp_dref));

    // Input Part
    integer runs;
    initial begin
      for(runs = 'd0; runs < RUNS; runs = runs + 'd1) begin
        rst = 0; start[0] = 0; input_fg[0] = 0;
        addr[0] = 0;

        #(FULLCLK) rst = 1;
        #(FULLCLK) rst = 0;
        #(FULLCLK);

        input_fg[0] = 0;
        for(addr[0] = 'd0; addr[0] < 2*NTRUPRIME_PC - 1; addr[0] = addr[0] + 'd1) begin
          #(FULLCLK);
        end
        #(8*FULLCLK);

        input_fg[0] = 1;
        for(addr[0] = 'd0; addr[0] < 2*NTRUPRIME_PC - 1; addr[0] = addr[0] + 'd1) begin
          #(FULLCLK);
        end
        #(8*FULLCLK);

        start[0] = 1;
        #(FULLCLK) start[0] = 0;

        wait(valid);
        #(FULLCLK);
        input_fg[0] = 0;
        #(FULLCLK);

        for(addr[0] = 'd0; addr[0] < 2*NTRUPRIME_PC - 1; addr[0] = addr[0] + 'd1) begin
          #(FULLCLK);
          //#(8*FULLCLK);
        end
        #(FULLCLK);
        //#(8*FULLCLK);

        #(128*FULLCLK);

      end
      $display("********** If you see this, then the output assertion success. **********");
      $finish;
    end

    // Output examination part
    initial begin
      comparison = 1'b0;
      wait(rst);
      #(FULLCLK) wait(~rst);
      #(FULLCLK) wait(valid);
      #(10*FULLCLK) comparison = 1'b1;
    end

    always @ ( posedge clk ) begin
      if(comparison) begin
        if(!equal) begin
          $display("!!!!!!!!!! Output Assertion Failure at addr = %d, where dout = %d and h_dref = %d. !!!!!!!!!!", addr[9], dout, h_dref);
          #(16*FULLCLK);
          $finish;
        end
      end
    end

endmodule

