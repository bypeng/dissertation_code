#!/usr/bin/env python3

import argparse
import json
import sys
import math
from pathlib import Path



json_file = Path('SNTRUP761_IV00000.json')
json_file_template = 'SNTRUP{p:d}_IV{sn:05d}.json'
testdata_file = Path('decode_p761q4591_memP_ref.v')
testdata_template = 'decode_p{p:d}q{q:d}_memP_ref.v'
intervalue_file = Path('decode_p761q4591_intervalues.txt')
iv_template = 'decode_p{p:d}q{q:d}_intervalues.txt'

primep = 761
primeq = 4591
rq_rd_toggle = False
serialno = 0

ERR_MSG_INVALIDTD_PATH = 'Invalid test data file path'
ERR_MSG_INVALIDJSON    = 'Invalid json file name'
ERR_MSG_INVALIDDATA    = 'Invalid data content'



# ----- print redirection
def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

def tdprint(*args, **kwargs):
  global td_fd
  print(*args, file=td_fd, **kwargs)

def ivprint(*args, **kwargs):
  global iv_fd
  print(*args, file=iv_fd, **kwargs)

def ivplist(R, x):
  ivprint("[ ", end='')
  for idx in range(len(R)):
    ivprint("{v:5d}".format(v = R[idx]), end='')
    if (idx == len(R) - 1):
      ivprint(" ]")
    elif (idx % 16 == 15):
      ivprint(",")
      ivprint(' ' * (x+2), end='')
    else:
      ivprint(", ", end='')
# ----- end of eprint()



# ----- Fetch JSON file
def fetch_json():
  global json_file, js_fd, td_json, primep, primeq, rq_rd_toggle

  with json_file.open() as js_fd:
    td_json = json.load(js_fd)
  
  if(rq_rd_toggle): # round encode
    assert primep == len(td_json['c_offset']), ERR_MSG_INVALIDDATA
    for c_item in td_json['c_offset']:
      assert (primeq+2)//3 > c_item, ERR_MSG_INVALIDDATA
    for c_item in td_json['c_pack']:
      assert c_item < 256, ERR_MSG_INVALIDDATA
  else:             # Rq encode
    assert primep == len(td_json['h_offset']), ERR_MSG_INVALIDDATA
    for h_item in td_json['h_offset']:
      assert primeq > h_item, ERR_MSG_INVALIDDATA
    for h_item in td_json['h_pack']:
      assert h_item < 256, ERR_MSG_INVALIDDATA

  return
# ----- end of fetch_json()



# ----- testdata file generator
def gen_testdatafile():
  global td_json, primep, primeq, rq_rd_toggle, testdata_file, td_fd

  if(rq_rd_toggle): # round encode
    R_data = td_json['c_offset']
    B_data = td_json['c_pack']
  else:
    R_data = td_json['h_offset']
    B_data = td_json['h_pack']

  ds_c = 1
  ds_d = 0
  R_l = len(R_data)
  R_d = math.ceil(math.log(R_l, 2))
  B_l = len(B_data)
  B_d = math.ceil(math.log(B_l, 2))

  in_d = ds_d + B_d
  out_d = ds_d + R_d

  with testdata_file.open(mode='w') as td_fd:
    tdprint(     "module mem_ref ( clk, in_addr, in_data, out_addr, out_data_ref ) ;" )
    tdprint(     "" )
    tdprint(     "  localparam DS_CNT = 'd{:d};".format(ds_c) )
    tdprint(     "  localparam DS_DEPTH = 'd{:d};".format(ds_d) )
    tdprint(     "  localparam B_LEN = 'd{:d};".format(B_l) )
    tdprint(     "  localparam B_DEPTH = 'd{:d};".format(B_d) )
    tdprint(     "  localparam R_LEN = 'd{:d};".format(R_l) )
    tdprint(     "  localparam R_DEPTH = 'd{:d};".format(R_d) )
    tdprint(     "" )
    tdprint(     "  input              clk;" )
    tdprint(     "  input      [{:2d}: 0] in_addr;".format(in_d-1) )
    tdprint(     "  output reg [ 7: 0] in_data;" )
    tdprint(     "  input      [{:2d}: 0] out_addr;".format(out_d-1) )
    tdprint(     "  output reg [13: 0] out_data_ref;" )
    tdprint(     "" )

    tdprint(     "  always @ ( posedge clk ) begin" )
    tdprint(     "    case(in_addr)" )
    for ds_i in range(ds_c):
      for B_i in range(B_l):
        index = (ds_i << B_d) + B_i
        tdprint( "      {i_d:2d}'d{i:<5d}: in_data <= 8'h{d:02x};".format(i_d = in_d, i = index, d = B_data[B_i]) )
    tdprint(     "      default: in_data <= 8'h0;" )
    tdprint(     "    endcase" )
    tdprint(     "  end" )
    tdprint(     "" )

    tdprint(     "  always @ ( posedge clk ) begin" )
    tdprint(     "    case(out_addr)" )
    for ds_i in range(ds_c):
      for R_i in range(R_l):
        index = (ds_i << R_d) + R_i
        tdprint( "      {i_d:2d}'d{i:<5d}: out_data_ref <= 14'h{d:04x}; // 'd{d:d}".format(i_d = out_d, i = index, d = R_data[R_i]) )
    tdprint(     "      default: out_data_ref <= 14'h0;" )
    tdprint(     "    endcase" )
    tdprint(     "  end" )
    tdprint(     "" )

    tdprint(     "endmodule" )

  return
# ----- end of testdata file generator



# ----- Decode function with intermediate values dump, modified from NTRU Prime Specification
limit = 16384

def Decode(S,M):
  global iv_fd

  if len(M) == 0:
    R = []
    ivprint("len == {l:<4d} :".format(l=0))
    ivprint("  R == ", R)
    return R
  if len(M) == 1:
    R = [sum(S[i]*256**i for i in range(len(S)))%M[0]]
    ivprint("len == {l:<4d} :".format(l=1))
    ivprint("  R == ", R)
    return R
  k = 0
  bottom,M2 = [],[]
  for i in range(0,len(M)-1,2):
    m,r,t = M[i]*M[i+1],0,1
    while m >= limit:
      r,t,k,m = r+S[k]*t,t*256,k+1,(m+255)//256
    bottom += [(r,t)]
    M2 += [m]
  if len(M)&1:
    M2 += [M[-1]]
  R2 = Decode(S[k:],M2)
  R = []
  for i in range(0,len(M)-1,2):
    r,t = bottom[i//2]
    r += t*R2[i//2]
    R += [r%M[i]]
    R += [(r//M[i])%M[i+1]]
  if len(M)&1:
    R += [R2[-1]]
  ivprint("len == {l:<4d} :".format(l=len(R)))
  ivprint("  R == ", end='')
  ivplist(R, 7) # indent: 7
  return R
# ----- end of Decode function with intermediate values dump, modified from NTRU Prime Specification



# ----- intermediate value dump
def gen_intervalue():
  global td_json, primep, primeq, rq_rd_toggle, intervalue_file, iv_fd

  if(rq_rd_toggle): # round encode
    R_data = td_json['c_offset']
    B_data = td_json['c_pack']
    M_data = [(primeq+2)//3] * primep
  else:
    R_data = td_json['h_offset']
    B_data = td_json['h_pack']
    M_data = [primeq] * primep

  with intervalue_file.open(mode='w') as iv_fd:
    R_out = Decode(B_data, M_data)

  assert R_out == R_data

  return
# ----- end of intermediate value dump



# ----- main funciton
def __main__():
  global json_file, testdata_file, intervalue_file, primep, primeq, rq_rd_toggle, serialno

  parser = argparse.ArgumentParser(description='')
  parser.add_argument('-p', '--primep', type=int, required=False, default=761, help='length of the sequence (p)')
  parser.add_argument('-q', '--primeq', type=int, required=False, default=4591, help='range of each element (q)')
  parser.add_argument('-n', '--serialno', type=int, required=False, default=0, help='test data set serial number')
  parser.add_argument('-r', '--round', type=bool, required=False, default=False, help='Rq Decode / Round Decode toggle (True = Round)')

  parser.add_argument('-j', '--jsonfile', type=Path, required=False, help='Input json file name')
  parser.add_argument('-d', '--tdfile', type=Path, required=False, help='Output test data verilog file name')
  parser.add_argument('-i', '--ivfile', type=Path, required=False, help='test data intermediate value dump file name')

  args = parser.parse_args()

  primep = args.primep
  primeq = args.primeq
  rq_rd_toggle = args.round
  serialno = args.serialno

  if(args.jsonfile == None):
    json_file = Path(json_file_template.format(p=primep, sn=serialno))
  else:
    json_file = Path(args.jsonfile)

  if(args.tdfile == None):
    if(rq_rd_toggle):
      testdata_file = Path(testdata_template.format(p=primep, q=(primeq+2)//3))
      intervalue_file = Path(iv_template.format(p=primep, q=(primeq+2)//3))
    else:
      testdata_file = Path(testdata_template.format(p=primep, q=primeq))
      intervalue_file = Path(iv_template.format(p=primep, q=primeq))
  else:
    testdata_file = Path(args.tdfile)
    intervalue_file = Path(args.ivfile)

  try:
    assert Path(json_file).is_file(), ERR_MSG_INVALIDJSON
    assert Path(testdata_file).parent.exists(), ERR_MSG_INVALIDTD_PATH
    assert Path(intervalue_file).parent.exists(), ERR_MSG_INVALIDTD_PATH
    fetch_json()
    gen_testdatafile()
    gen_intervalue()
  except AssertionError as msg:
    if(str(msg) == ERR_MSG_INVALIDJSON):
      eprint('{:s} is an INVALID filename.'.format(str(json_file)))
    elif(str(msg) == ERR_MSG_INVALIDTD_PATH):
      eprint('{:s} or {:s} is at an INVALID path.'.format(str(testdata_file), str(intervalue_file)))

  return
# ----- end of main funciton



__main__()


