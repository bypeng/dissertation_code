module bram_34_11_P ( clk, wr_en, wr_addr, rd_addr, wr_din, wr_dout, rd_dout );

  input                   clk;
  input                   wr_en;
  input       [ 10 : 0]   wr_addr;
  input       [ 10 : 0]   rd_addr;
  input       [ 33 : 0]   wr_din;
  output      [ 33 : 0]   wr_dout;
  output      [ 33 : 0]   rd_dout;

  reg         [ 33 : 0]   ram [2047:0];
  reg         [ 10 : 0]   reg_wra;
  reg         [ 10 : 0]   reg_rda;

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
