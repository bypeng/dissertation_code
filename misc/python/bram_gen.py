#!/usr/bin/env python3

import argparse
import sys



# Parameter Check 
def check_interface(dis, qid, dos, qod):
  assert (qid > 0) and (qod > 0), 'qi_depth and qo_depth need to be larger than 0'
  assert (dis > 0) and (dos > 0), 'di_size and do_size need to be larger than 0'
  if(dis > dos):
    R = dis // dos
    assert (R * dos == dis), 'di_size needs to be a multiple of do_size when di_size > do_size'
  elif(dis < dos):
    R = dos // dis
    assert (R * dis == dos), 'do_size needs to be a multiple of di_size when do_size > di_size'
  assert ((1 << qid) * dis == (1 << qod) * dos), 'it is necessary (2^qi_depth * di_size) == (2^qo_depth * do_size)'



# File Generator
def gen_bram_v(dis, qid, dos, qod, tt):
  if(dis > dos):
    gencase = 1
  elif(dis < dos):
    gencase = -1
  else:
    gencase = 0

  tt_text = 'P' if (tt) else 'N'
  tt_tr = 'posedge' if (tt) else 'negedge'

  logR = qod - qid if (gencase ==  1) else qid - qod
  logRm = logR - 1
  R = 1 << logR;
  Rm = R - 1

  qidm = qid - 1
  dism = dis - 1
  qis  = 1 << qid
  qism = qis - 1
  qodm = qod - 1
  dosm = dos - 1
  qos  = 1 << qod
  qosm = qos - 1

  if(gencase == 0):
    print(   'module bram_{:d}_{:d}_{:s} ( clk, wr_en, wr_addr, rd_addr, wr_din, wr_dout, rd_dout );'.format(dis, qid, tt_text) )
  else:
    print(   'module bram_{:d}_{:d}_{:d}_{:d}_{:s} ( clk, wr_en, wr_addr, rd_addr, wr_din, wr_dout, rd_dout );'.format(dis, qid, dos, qod, tt_text) )
  print(     '' )
  print(     '  input                   clk;' )
  print(     '  input                   wr_en;' )
  print(     '  input       [{:3d} : 0]   wr_addr;'.format(qidm) )
  print(     '  input       [{:3d} : 0]   rd_addr;'.format(qodm) )
  print(     '  input       [{:3d} : 0]   wr_din;'.format(dism) )

  if(gencase == -1):
    print(   '  output reg  [{:3d} : 0]   wr_dout;'.format(dism) )
  else:
    print(   '  output      [{:3d} : 0]   wr_dout;'.format(dism) )

  if(gencase == 1):
    print(   '  output reg  [{:3d} : 0]   rd_dout;'.format(dosm) )
  else:
    print(   '  output      [{:3d} : 0]   rd_dout;'.format(dosm) )

  print(     '' )

  if(gencase == -1):
    print(   '  reg         [{:3d} : 0]   ram [{:d}:0];'.format(dosm, qosm) )
  else:
    print(   '  reg         [{:3d} : 0]   ram [{:d}:0];'.format(dism, qism) )

  print(     '  reg         [{:3d} : 0]   reg_wra;'.format(qidm) )
  print(     '  reg         [{:3d} : 0]   reg_rda;'.format(qodm) )
  print(     '' )
  print(     '  always @ ({:s} clk) begin'.format(tt_tr) )
  print(     '    if(wr_en) begin' )

  if(gencase == -1):
    if (logRm == 0):
      print( '      case(wr_addr[0])' ) 
    else:
      print( '      case(wr_addr[{:d}:0])'.format(logRm) )
    for idx0 in range(Rm):
      didxL = idx0 * dis
      didxH = didxL + dis - 1
      print( '        \'d{:d}:'.format(idx0) )
      print( '          ram[wr_addr[{:d}:{:d}]][{:d}:{:d}] <= wr_din;'.format(qidm, logR, didxH, didxL) )
    didxL = Rm * dis
    didxH = didxL + dis - 1
    print(   '        default:' )
    print(   '          ram[wr_addr[{:d}:{:d}]][{:d}:{:d}] <= wr_din;'.format(qidm, logR, didxH, didxL) )
    print(   '      endcase' )
  else:
    print(   '      ram[wr_addr] <= wr_din;' )

  print(     '    end' )
  print(     '    reg_wra <= wr_addr;' )
  print(     '    reg_rda <= rd_addr;' )
  print(     '  end' )
  print(     '' )

  if(gencase == -1):
    print(   '  always @ (*) begin' )
    if (logRm == 0):
      print( '    case(reg_wra[0])' ) 
    else:
      print( '    case(reg_wra[{:d}:0])'.format(logRm) )
    for idx0 in range(Rm):
      didxL = idx0 * dis
      didxH = didxL + dis - 1
      print( '      \'d{:d}:'.format(idx0) )
      print( '        wr_dout = ram[reg_wra[{:d}:{:d}]][{:d}:{:d}];'.format(qidm, logR, didxH, didxL) )
    didxL = Rm * dis
    didxH = didxL + dis - 1
    print(   '      default:' )
    print(   '        wr_dout = ram[reg_wra[{:d}:{:d}]][{:d}:{:d}];'.format(qidm, logR, didxH, didxL) )
    print(   '    endcase' )
    print(   '  end' )
  else:
    print(   '  assign wr_dout = ram[reg_wra];' )

  if(gencase == 1):
    print(   '  always @ (*) begin' )
    if (logRm == 0):
      print( '    case(reg_rda[0])' ) 
    else:
      print( '    case(reg_rda[{:d}:0])'.format(logRm) )
    for idx0 in range(Rm):
      didxL = idx0 * dos
      didxH = didxL + dos - 1
      print( '      \'d{:d}:'.format(idx0) )
      print( '        rd_dout = ram[reg_rda[{:d}:{:d}]][{:d}:{:d}];'.format(qodm, logR, didxH, didxL) )
    didxL = Rm * dos
    didxH = didxL + dos - 1
    print(   '      default:' )
    print(   '        rd_dout = ram[reg_rda[{:d}:{:d}]][{:d}:{:d}];'.format(qodm, logR, didxH, didxL) )
    print(   '    endcase' )
    print(   '  end' )
  else:
    print(   '  assign rd_dout = ram[reg_rda];' )

  print(     '' )
  print(     'endmodule' )



def __main__():
  parser = argparse.ArgumentParser(description='BRAM Generator')
  parser.add_argument('--di_size', '-di', metavar='DI', type=int, required=False, default=32, help='Input data width, default 32-bit')
  parser.add_argument('--qi_depth', '-qi',  metavar='QI', type=int, required=False, default=10, help='Input data depth, default 10-bit')
  parser.add_argument('--do_size', '-do',  metavar='DO', type=int, required=False, default=None, help='Output data width, default same as input data width')
  parser.add_argument('--qo_depth', '-qo', metavar='QO', type=int, required=False, default=None, help='Output data depth, default same as output data width')

  parser.add_argument('--pos', '-p', dest='tt', default=True, action='store_true', help='Set positive trigger type (as default)')
  parser.add_argument('--neg', '-n', dest='tt', action='store_false', help='Set negative trigger type')

  args = parser.parse_args()
  dis = args.di_size
  qid = args.qi_depth
  dos = dis if (args.do_size == None) else args.do_size
  qod = qid if (args.qo_depth == None) else args.qo_depth
  tt = args.tt

  try:
    check_interface(dis, qid, dos, qod)
  except AssertionError as msg:
    print(msg, file=sys.stderr)
  else:
    gen_bram_v(dis, qid, dos, qod, tt)



__main__()

