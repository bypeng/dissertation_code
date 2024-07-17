`timescale 1ns/100ps

`include "params.v"   

`define DATASET_COUNT 'd1

`ifdef Q4621
  `define ENCODE_PARAM rp653q4621encode_param
  `define SIMTYPE "p653q4621"
`elsif Q1541
  `define ENCODE_PARAM rp653q1541encode_param
  `define SIMTYPE "p653q1541"
`elsif Q4591
  `define ENCODE_PARAM rp761q4591encode_param
  `define SIMTYPE "p761q4591"
`elsif Q1531
  `define ENCODE_PARAM rp761q1531encode_param
  `define SIMTYPE "p761q1531"
`elsif Q5167
  `define ENCODE_PARAM rp857q5167encode_param
  `define SIMTYPE "p857q5167"
`elsif Q1723
  `define ENCODE_PARAM rp857q1723encode_param
  `define SIMTYPE "p857q1723"
`elsif Q6343
  `define ENCODE_PARAM rp953q6343encode_param
  `define SIMTYPE "p953q6343"
`elsif Q2115
  `define ENCODE_PARAM rp953q2115encode_param
  `define SIMTYPE "p953q2115"
`elsif Q7177
  `define ENCODE_PARAM rp1013q7177encode_param
  `define SIMTYPE "p1013q7177"
`elsif Q2393
  `define ENCODE_PARAM rp1013q2393encode_param
  `define SIMTYPE "p1013q2393"
`elsif Q7879
  `define ENCODE_PARAM rp1277q7879encode_param
  `define SIMTYPE "p1277q7879"
`elsif Q2627
  `define ENCODE_PARAM rp1277q2627encode_param
  `define SIMTYPE "p1277q2627"
`endif
 
module encode_tb;

    /* clock setting */
    reg clk;
        initial begin
        clk=1;
    end
    always #5 clk<=~clk;

    /* vcd file setting */
    initial begin
        $fsdbDumpfile({ "encode_tb_", `SIMTYPE, ".fsdb" });
        $fsdbDumpvars;
        //$dumpfile({ "encode_tb_", `SIMTYPE, ".fsdb" });
        //$dumpvars;
        #20000000;
        $finish;
    end

    reg [7:0] dataset;

    reg start;
    wire done;
    wire [4:0] state_l;
    wire [4:0] state_e;
    wire [4:0] state_s;
    wire [`OUT_DEPTH-1:0] cd_wr_addr;
    wire [`OUT_D_SIZE-1:0] cd_wr_data;
    wire cd_wr_en;
    wire [`RP_DEPTH-1:0] rp_rd_addr;
    wire [`RP_D_SIZE-1:0] rp_rd_data;
    wire [4:0] state_max;
    wire [`RP_DEPTH-1:0] param_state_ct;
    wire [`RP_DEPTH-1:0] param_r_max;
    wire [`RP_D_SIZE-1:0] param_m0;
    //wire param_1st_round;
    wire [1:0] param_outs1;
    wire [2:0] param_outsl;

    reg [`OUT_DEPTH-1:0] cd_rd_addr;
    wire [`OUT_D_SIZE-1:0] cd_rd_data;
    wire [`OUT_D_SIZE-1:0] cd_data_ref;
    wire data_equal;

    initial begin
        dataset = 8'd0;
    end

    always begin
        start = 1'b0;

        #5;
        start = 1'b1;
        cd_rd_addr = { `OUT_DEPTH {1'b0} };

        #60;
        start = 1'b0;

        wait(done);

        #81920;

        dataset = dataset + 8'd1;
        if(dataset == `DATASET_COUNT) $finish;
    end

    always @ (posedge clk) begin
        if(done) begin
            #10 cd_rd_addr <= cd_rd_addr + { { (`OUT_DEPTH-1) {1'b0} }, 1'b1 };
        end
    end

    assign data_equal = (cd_rd_data == cd_data_ref);

    encode_rp encoder0 (
        .clk(clk),
        .start(start),
        .done(done),
        .state_l(state_l),
        .state_e(state_e),
        .state_s(state_s),
        .rp_rd_addr(rp_rd_addr),
        .rp_rd_data(rp_rd_data),
        .cd_wr_addr(cd_wr_addr),
        .cd_wr_data(cd_wr_data),
        .cd_wr_en(cd_wr_en),
        .state_max(state_max),
        .param_state_ct(param_state_ct),
        .param_r_max(param_r_max),
        .param_m0(param_m0),
        //.param_1st_round(param_1st_round),
        .param_outs1(param_outs1),
        .param_outsl(param_outsl)
    ) ;

    bram_p # ( .D_SIZE(`OUT_D_SIZE), .Q_DEPTH(`OUT_DEPTH) ) outram0 (
        .clk(clk),
        .wr_en(cd_wr_en),
        .wr_addr(cd_wr_addr),
        .wr_din(cd_wr_data),
        .rd_addr(cd_rd_addr),
        .rd_dout(cd_rd_data)
    ) ;

    mem_ref testdata0 (
        .clk(clk),
        .in_addr({ dataset, rp_rd_addr }),
        .in_data(rp_rd_data),
        .out_addr({ dataset, cd_rd_addr }),
        .out_data_ref(cd_data_ref)
    ) ;

    `ENCODE_PARAM param0 (
        .state_max(state_max),
        .state_l(state_l),
        .state_e(state_e),
        .state_s(state_s),
        .param_state_ct(param_state_ct),
        .param_r_max(param_r_max),
        .param_m0(param_m0),
        //.param_1st_round(param_1st_round),
        .param_outs1(param_outs1),
        .param_outsl(param_outsl)
    ) ;

endmodule

