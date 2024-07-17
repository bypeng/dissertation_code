`timescale 1ns/100ps

`include "params.v"   

`ifdef Q4621
  `define DECODE_PARAM rp653q4621decode_param
  `define SIMTYPE "p653q4621"
`elsif Q1541
  `define DECODE_PARAM rp653q1541decode_param
  `define SIMTYPE "p653q1541"
`elsif Q4591
  `define DECODE_PARAM rp761q4591decode_param
  `define SIMTYPE "p761q4591"
`elsif Q1531
  `define DECODE_PARAM rp761q1531decode_param
  `define SIMTYPE "p761q1531"
`elsif Q5167
  `define DECODE_PARAM rp857q5167decode_param
  `define SIMTYPE "p857q5167"
`elsif Q1723
  `define DECODE_PARAM rp857q1723decode_param
  `define SIMTYPE "p857q1723"
`elsif Q6343
  `define DECODE_PARAM rp953q6343decode_param
  `define SIMTYPE "p953q6343"
`elsif Q2115
  `define DECODE_PARAM rp953q2115decode_param
  `define SIMTYPE "p953q2115"
`elsif Q7177
  `define DECODE_PARAM rp1013q7177decode_param
  `define SIMTYPE "p1013q7177"
`elsif Q2393
  `define DECODE_PARAM rp1013q2393decode_param
  `define SIMTYPE "p1013q2393"
`elsif Q7879
  `define DECODE_PARAM rp1277q7879decode_param
  `define SIMTYPE "p1277q7879"
`elsif Q2627
  `define DECODE_PARAM rp1277q2627decode_param
  `define SIMTYPE "p1277q2627"
`endif
 
module decode_tb;

    /* clock setting */
    reg clk;
        initial begin
        clk=1;
    end
    always #5 clk<=~clk;

    /* vcd file setting */
    initial begin
        $fsdbDumpfile({ "decode_tb_", `SIMTYPE, ".fsdb" });
        $fsdbDumpvars;
        //$dumpfile({ "decode_tb_", `SIMTYPE, ".fsdb" });
        //$dumpvars;
        #20000000;
        $finish;
    end

    //reg [7:0] dataset;

    reg                     start;
    wire                    done;
    wire [4:0]              state_l;
    wire [4:0]              state_e;
    wire [4:0]              state_s;
    wire [`OUT_DEPTH-1:0]   rp_rd_addr;
    wire [`OUT_D_SIZE-1:0]  rp_rd_data;
    wire [`RP_DEPTH-1:0]    cd_wr_addr;
    wire [`RP_D_SIZE-1:0]   cd_wr_data;
    wire                    cd_wr_en;
    wire [4:0]              state_max;
    wire [`RP_DEPTH-2:0]    param_r_max;
    wire [`RP_DEPTH-1:0]    param_ro_max;
    wire                    param_small_r2;
    wire                    param_small_r3;
    wire [`RP_DEPTH-1:0]    param_state_ct;
    wire [`RP_DEPTH-2:0]    param_ri_offset;
    wire [`RP_DEPTH-2:0]    param_ri_len;
    wire [`OUT_DEPTH-1:0]   param_outoffset;
    wire [1:0]              param_outs1;
    wire [1:0]              param_outsl;
    wire [`RP_D_SIZE-1:0]   param_m0;
    wire [`RP_INV_SIZE-1:0] param_m0inv;
    wire [`RP_DEPTH-2:0]    param_ro_offset;

    reg [`RP_DEPTH-1:0]     cd_rd_addr;
    wire [`RP_D_SIZE-1:0]   cd_rd_data;
    wire [`RP_D_SIZE-1:0]   cd_data_ref;
    wire                    data_equal;

    wire rb_addr_conflict;
    wire rb_wr_data_s0r;
    wire rb_wr_data_rprev;
    wire rb_wr_data_r1next;
    wire rb_wr_data_r0next;

    //initial begin
    //    dataset = 8'd0;
    //end

    always begin
        start = 1'b0;

        #5;
        start = 1'b1;
        cd_rd_addr = { `RP_DEPTH {1'b0} };

        #60;
        start = 1'b0;

        wait(done);

        #81920;

        //dataset = dataset + 8'd1;
        //if(dataset == 8'd1) $finish;
        $finish;
    end

    always @ (posedge clk) begin
        if(done) begin
            if(cd_rd_addr == param_ro_max) begin
                cd_rd_addr <= 'd0;
            end else begin
                cd_rd_addr <= cd_rd_addr + 'd1;
            end
        end
    end

    assign data_equal = (cd_rd_data == cd_data_ref);

    decode_rp decoder0 (
        .clk(clk),
        .start(start),
        .done(done),
        .rp_rd_addr(rp_rd_addr),
        .rp_rd_data(rp_rd_data),
        .cd_wr_addr(cd_wr_addr),
        .cd_wr_data(cd_wr_data),
        .cd_wr_en(cd_wr_en),
        .state_l(state_l),
        .state_e(state_e),
        .state_s(state_s),
        .state_max(state_max),
        .param_r_max(param_r_max),
        .param_ro_max(param_ro_max),
        .param_small_r2(param_small_r2),
        .param_small_r3(param_small_r3),
        .param_state_ct(param_state_ct),
        .param_ri_offset(param_ri_offset),
        .param_ri_len(param_ri_len),
        .param_outoffset(param_outoffset),
        .param_outs1(param_outs1),
        .param_outsl(param_outsl),
        .param_m0(param_m0),
        .param_m0inv(param_m0inv),
        .param_ro_offset(param_ro_offset)
    ) ;

    bram_p # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH) ) outram0 (
    //bram_n # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH) ) outram0 (
        .clk(clk),
        .wr_en(cd_wr_en),
        .wr_addr(cd_wr_addr),
        .wr_din(cd_wr_data),
        .rd_addr(cd_rd_addr),
        .rd_dout(cd_rd_data)
    ) ;

    mem_ref testdata0 (
        .clk(clk),
        .in_addr({ 10'b0, rp_rd_addr }),
        .in_data(rp_rd_data),
        .out_addr({ 10'b0, cd_rd_addr }),
        .out_data_ref(cd_data_ref)
    ) ;

    `DECODE_PARAM param0 (
        .state_l(state_l),
        .state_e(state_e),
        .state_s(state_s),
        .state_max(state_max),
        .param_r_max(param_r_max),
        .param_ro_max(param_ro_max),
        .param_small_r2(param_small_r2),
        .param_small_r3(param_small_r3),
        .param_state_ct(param_state_ct),
        .param_ri_offset(param_ri_offset),
        .param_ri_len(param_ri_len),
        .param_outoffset(param_outoffset),
        .param_outs1(param_outs1),
        .param_outsl(param_outsl),
        .param_m0(param_m0),
        .param_m0inv(param_m0inv),
        .param_ro_offset(param_ro_offset)
    ) ;

endmodule

