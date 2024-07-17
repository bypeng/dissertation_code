module bram_18_13_P ( clk, wr_en, wr_addr, rd_addr, wr_din, wr_dout, rd_dout );

  input                   clk;
  input                   wr_en;
  input       [ 12 : 0]   wr_addr;
  input       [ 12 : 0]   rd_addr;
  input       [ 17 : 0]   wr_din;
  output      [ 17 : 0]   wr_dout;
  output      [ 17 : 0]   rd_dout;

  reg         [ 17 : 0]   ram [8191:0];
  reg         [ 12 : 0]   reg_wra;
  reg         [ 12 : 0]   reg_rda;

  always @ (posedge clk) begin
    if(wr_en) begin
      ram[wr_addr] <= wr_din;
    end
    reg_wra <= wr_addr;
    reg_rda <= rd_addr;
  end

  assign wr_dout = ram[reg_wra];
  assign rd_dout = ram[reg_rda];

endmodule
