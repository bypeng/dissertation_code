#!/usr/bin/env python3

import argparse
import math
import sys

from sympy.ntheory import isprime
from numpy import prod

p = 761
p_cover = 2048
lg2_pc = 11

p_g_cover = 512
lg2_pgc = 9

goodfactor = 3

q0 = 4591
lg2_q0 = 13
lg2_2q0 = 24

pqbound = 4008206025
lg2_pqb = 33

qs = [114689, 120833]
lg2_qs = [17, 17]
lg2_2qs = [33, 33]
qs_inv = [38211, -40258]
qs_else = [(59, 11, 6), (7, 14, 3)]

lg2_wmax = 17

ntt_modulename = 'ntt761good3_4591_by_114689_120833'


# ----- Finding the least bit which is 1, and extracting the MSB part
def DivideMSB(x):
  if(x == 0):
    return 0, 0, 0
  x -= 1
  y = 0
  while(((x % 2) == 0) and (x != 0)):
    x >>= 1
    y += 1
  lenx = int(math.ceil(math.log2(x+1)))
  return x, y, lenx

def LeastOne(x):
  x, y, lenx = DivideMSB(x)
  return y

def ExtractMSB(x):
  x, y, lenx = DivideMSB(x)
  return x

def LenMSB(x):
  x, y, lenx = DivideMSB(x)
  return lenx


# ----- Finding the generator with in Fq
def find_gen(q, rN):
  for gen in range(2, q):
    if(pow(gen, rN >> 1, q) == q - 1):
      break
  return gen


# ----- NTT module name assignment
def NTTModulenameGen():
  global p, q0, qs
  fn = 'ntt{}good{}_{}'.format(p, goodfactor, q0);
  for idx, qi in enumerate(qs):
    if(idx == 0):
      fn += '_by'
    fn += '_{}'.format(qi)
  return fn


# ----- Check the parameter set meet the requirement of NTT
def NTTCheckFriendly():
  global p, p_cover, lg2_pc, p_g_cover, lg2_pgc, q0, lg2_q0, lg2_2q0, qs, lg2_qs, lg2_2qs, qs_inv, qs_else, lg2_wmax, lg2_pqb, pqbound, lg2_pqb

  print('p = ', p)
  print('q0 = ', q0)
  print('qs = ', qs)
  print('')

  lg2_pc = int(math.ceil(math.log2(p)) + 1)
  p_cover = int(pow(2, lg2_pc))

  lg2_pgc = int(math.ceil(math.log2(p // goodfactor)) + 1)
  p_g_cover = int(pow(2, lg2_pgc))

  lg2_q0 = int(math.ceil(math.log2(q0)))
  lg2_2q0 = int(math.ceil(math.log2(q0) * 2)-1)
  lg2_qs = [] if len(qs) == 0 else [int(math.ceil(math.log2(qi))) for qi in qs]
  lg2_2qs = [] if len(qs) == 0 else [int(math.ceil(math.log2(qi) * 2)-1) for qi in qs]

  qproduct = int(prod(qs))
  pqbound = p * int(pow((q0-1)/2, 2))
  lg2_pqb = int(math.ceil(math.log2(pqbound)) + 1) if (len(qs) != 0) else lg2_2q0
  if(len(qs) == 0):
    qs_inv = []
  elif(len(qs) == 1):
    qs_inv = [1]
  else:
    qs_inv = [pow(int(divmod(qproduct, qi)[0]), qi - 2, qi) for qi in qs]
    for idx, qi in enumerate(qs):
      qs_inv[idx] = qs_inv[idx] if (qs_inv[idx] <= ((qi-1) >> 1)) else qs_inv[idx] - qi
  qs_else = [] if len(qs) == 0 else [(0,0,0)] if len(qs) == 1 else [DivideMSB(int(divmod(qproduct, qi)[0])) for qi in qs]

  lg2_qs_else = list(map(lambda qi_else: qi_else[2], qs_else))
  lg2_wmax = lg2_q0 if (len(qs)==0) else max(max(lg2_qs), max(lg2_qs_else)+1)

  if(lg2_pgc <= 5):
    print('This script only supports p > 48.')
    return False
  print('NTT{pc} is to be constructed, suitable for the ring F_{{{q0}}} [x] / \\langle x^{{{gd}*{pc}}} - 1 \\rangle . '.format(pc=p_g_cover, gd=goodfactor, q0=q0))

  if(not isprime(q0)):
    print('{} needs to be a prime number.'.format(q0))
    return False

  if((LeastOne(q0) >= lg2_pgc) and (len(qs) != 0)):
    print('{} is actually friendly to NTT{}. No qs list necessary.'.format(q0, p_g_cover))
    return False

  if(LeastOne(q0) < lg2_pgc):
    if(len(qs) == 0):
      print('{} is not friendly to NTT{}. Friendly prime list needs to be provided.'.format(q0, p_g_cover))
      return False
    else:
      if(len(qs) != len(set(qs))):
        print('{} contains duplicate prime number(s). Select another set.'.format(qs))
        return False
      if(len(qs) > 3):
        print('{} contains 4 or more prime numbers but this script supports at most 3 prime numbers for CRT. Select another set.'.format(qs))
        return False
      for qi in qs:
        if(not isprime(qi)):
          print('It is found that {} is not a prime number. Select a prime number.'.format(qi))
          return False
        if(qi < q0):
          print('Its is found that {} < {}. Select another prime number.'.format(qi, q0))
        if(LeastOne(qi) < lg2_pgc):
          print('It is found that {} is not friendly to NTT{}. Select another prime number.'.format(qi, p_g_cover))
          return False
      if(2 * pqbound > qproduct):
        print('Warning: it is found that ', end='')
        for idx, qi in enumerate(qs):
          if(idx != 0):
            print('* ', end='')
          print('{} '.format(qi), end='')
        print('< 2 * {p} * {q} * {q}. This makes CRT ambiguity. Pick more prime number(s) in qs list to avoid this ambiguity.'.format(p=p, q=(q0-1)>>1))
  print(  'Note: A fast reduction within 3 cycles from {}-bit signed integer to {}-bit signed integer modulo {} needs to be designed.'.format(lg2_pqb, lg2_q0, q0))
  for (qi, lg2_qi, lg2_2qi) in zip(qs, lg2_qs, lg2_2qs):
    print('      A fast redutcion within 3 cycles form {}-bit signed integer to {}-bit signed integer modulo {} needs to be designed.'.format(lg2_2qi, lg2_qi, qi))

  return True


# ----- ntt top entity generator
def ntt_top_gen(fp, mod3_delay):
  global ntt_modulename, p, p_cover, lg2_pc, p_g_cover, lg2_pgc, q0, lg2_q0, lg2_2q0, qs, lg2_qs, lg2_2qs, qs_inv, qs_else, lg2_wmax, lg2_pqb

  ql_total = lg2_q0 if (len(lg2_qs) == 0) else sum(lg2_qs)
  q_count = 1 if (len(qs) <= 1) else len(qs)
  qa_str = '' if (q_count==1) else '[0:{:d}]'.format(q_count - 1)
  lg2_qi_max = lg2_q0 if (len(qs)==0) else max(lg2_qs)

  if( len(qs) == 0 ):
    qsX = [q0]
    lg2_qsX = [lg2_q0]
    lg2_qsXdiff = [0]
  else:
    qsX = qs
    lg2_qsX = lg2_qs
    lg2_qsXdiff = [lg2_qi - lg2_q0 for lg2_qi in lg2_qsX]
    qproduct = int(prod(qs))
    qp2 = (qproduct-1) >> 1
    lg2_qp = int(math.ceil(math.log2(qproduct))+1)
    qpn = pow(2, lg2_qp) - qproduct
    qpn2 = pow(2, lg2_qp) - qp2

  print(    'module {:s} ( clk, rst, start, input_fg, addr, din, dout, valid );'.format(ntt_modulename), file=fp)
  print(    '', file=fp)

  print(    '  localparam Q0 = {:d};'.format(q0), file=fp)
  for idx,qi in enumerate(qs):
    print(  '  localparam Q{:d} = {:d};'.format(idx+1, qi), file=fp)
  if(len(qs) > 1):
    for idx,(qi,qi_inv) in enumerate(zip(qs,qs_inv)):
      qi_inv_signed = qi_inv - qi if qi_inv > ((qi-1)>>1) else qi_inv
      print('  localparam Q_n{:d}_INV = {:d};'.format(idx+1, qi_inv_signed), file=fp)
    print(  '', file=fp)
  if(len(qs) >= 2):
    for idx,(qi,qi_else) in enumerate(zip(qs,qs_else)):
      print('  localparam Q_n{:d}_PREFIX = {:d}; // Note: manual optimization for this part may be necessary.'.format(idx+1, qi_else[0]), file=fp)
      print('  localparam Q_n{:d}_SHIFT  = {:d};'.format(idx+1, qi_else[1]), file=fp)
    print(  '', file=fp)
  if(len(qs) != 0):
    x = '{{:d}}\'sh{{:0{}X}}'.format((lg2_qp+3) >> 2)
    print(  '  localparam QALLp      = ' + x.format(lg2_qp, qproduct) + '; // Note: manual optimization for this part may be necessary.', file=fp)
    print(  '  localparam QALLp_DIV2 = ' + x.format(lg2_qp, qp2) + ';', file=fp)
    print(  '  localparam QALLn      = ' + x.format(lg2_qp, qpn) + ';', file=fp)
    print(  '  localparam QALLn_DIV2 = ' + x.format(lg2_qp, qpn2) + ';', file=fp)
  print(    '', file=fp)

  print(    '  // STATE', file=fp)
  print(    '  localparam ST_IDLE   = 0;', file=fp)
  print(    '  localparam ST_NTT    = 1;', file=fp)
  print(    '  localparam ST_PMUL   = 2;', file=fp)
  print(    '  localparam ST_RELOAD = 3;', file=fp)
  print(    '  localparam ST_INTT   = 4;', file=fp)
  print(    '  localparam ST_CRT    = 5;  // not applied for single prime scheme', file=fp)
  print(    '  localparam ST_REDUCE = 6;', file=fp)
  print(    '  localparam ST_FINISH = 7;', file=fp)
  print(    '', file=fp)

  print(    '  input                      clk;', file=fp)
  print(    '  input                      rst;', file=fp)
  print(    '  input                      start;', file=fp)
  print(    '  input                      input_fg;', file=fp)
  print(    '  input             [{:d} : 0] addr;'.format(lg2_pc-1), file=fp)
  print(    '  input signed      [{:d} : 0] din;'.format(lg2_q0-1), file=fp)
  print(    '  output reg signed [{:d} : 0] dout;'.format(lg2_q0-1), file=fp)
  print(    '  output reg                 valid;', file=fp)
  print(    '', file=fp)

  print(    '  // BRAM', file=fp)
  if(len(qs) != 0):
    print(  '  // Notice: This RTL applies CRT to handle the unfriendliness of {:d}.'.format(q0), file=fp)
    lg2_q_st = 0
    for idx, (qi, lg2_qi) in enumerate(zip(qs, lg2_qs)):
      print('  //         d[{:<2d}:{:>2d}] for q{:d} = {:d} in wr_din/rd_dout/wr_dout'.format(lg2_q_st+lg2_qi-1, lg2_q_st, idx+1, qi), file=fp)
      lg2_q_st += lg2_qi
  print(    '  reg            wr_en   [0 : 1];', file=fp)
  print(    '  reg   [{:<2d} : 0] wr_addr [0 : 1];'.format(lg2_pc-1), file=fp)
  print(    '  reg   [{:<2d} : 0] rd_addr [0 : 1];'.format(lg2_pc-1), file=fp)
  print(    '  reg   [{:<2d} : 0] wr_din  [0 : 1];'.format(ql_total-1), file=fp)
  print(    '  wire  [{:<2d} : 0] rd_dout [0 : 1];'.format(ql_total-1), file=fp)
  print(    '  wire  [{:<2d} : 0] wr_dout [0 : 1];'.format(ql_total-1), file=fp)
  print(    '', file=fp)

  print(    '  // addr_gen', file=fp)
  print(    '  wire         bank_index_rd [0 : 1];', file=fp)
  print(    '  wire         bank_index_wr [0 : 1];', file=fp)
  print(    '  wire [{:<2d}: 0] data_index_rd [0 : 1];'.format(lg2_pgc-2), file=fp)
  print(    '  wire [{:<2d}: 0] data_index_wr [0 : 1];'.format(lg2_pgc-2), file=fp)
  print(    '  reg  bank_index_wr_0_shift_1, bank_index_wr_0_shift_2;', file=fp)
  print(    '  reg  fg_shift_1, fg_shift_2, fg_shift_3;', file=fp)
  print(    '', file=fp)

  print(    '  // w_addr_gen', file=fp)
  print(    '  reg  [{:<2d} : 0] stage_bit;'.format(lg2_pgc-2), file=fp)
  print(    '  wire [{:<2d} : 0] w_addr;'.format(lg2_pgc-2), file=fp)
  print(    '', file=fp)

  print(    '  // bfu', file=fp)
  print(    '  reg                  ntt_state;', file=fp)
  print(    '  reg                  acc_state;', file=fp)
  print(    '  reg  signed [{:<2d}: 0] in_a  {:s};'.format(lg2_qi_max-1, qa_str), file=fp)
  print(    '  reg  signed [{:<2d}: 0] in_b  {:s};'.format(lg2_qi_max-1, qa_str), file=fp)
  print(    '  reg  signed [{:<2d}: 0] in_w  {:s};'.format(lg2_wmax-1, qa_str), file=fp)
  print(    '  wire signed [{:<2d}: 0] bw    {:s};'.format(lg2_qi_max+lg2_wmax-1, qa_str), file=fp)
  print(    '  wire signed [{:<2d}: 0] out_a {:s};'.format(lg2_qi_max-1, qa_str), file=fp)
  print(    '  wire signed [{:<2d}: 0] out_b {:s};'.format(lg2_qi_max-1, qa_str), file=fp)
  print(    '', file=fp)

  print(    '  // state, stage, counter', file=fp)
  lg2lg2_pgc = int(math.ceil(math.log2(lg2_pgc)))
  print(    '  reg  [2 : 0] state, next_state;', file=fp)
  print(    '  reg  [{:d} : 0] stage, stage_wr;'.format(lg2lg2_pgc), file=fp)
  print(    '  wire [{:d} : 0] stage_rdM, stage_wrM;'.format(lg2lg2_pgc), file=fp)
  print(    '  reg  [{:d} : 0] ctr;'.format(lg2_pgc), file=fp)
  print(    '  reg  [{:d} : 0] ctr_shift_7, ctr_shift_8, ctr_shift_9, ctr_shift_10, ctr_shift_1, ctr_shift_2, ctr_shift_3, ctr_pmul_shift_2;'.format(lg2_pgc), file=fp)
  print(    '  reg  [{:d} : 0] ctr_good, good_index, good_index_wr;'.format(lg2_pc - lg2_pgc - 1), file=fp)
  print(    '  wire [{:d} : 0] good_index_buf;'.format(lg2_pc - lg2_pgc), file=fp)
  print(    '  wire [{:d} : 0] ctr_good_next, good_index_next, good_index_wr_next;'.format(lg2_pc - lg2_pgc - 1), file=fp)
  print(    '  reg          ctr_MSB_masked;', file=fp)
  print(    '  reg          poly_select;', file=fp)
  print(    '  reg          ctr_msb_shift_1;', file=fp)
  print(    '  wire         ctr_half_end, ctr_full_end, ctr_shift_7_end, ctr_shift_2_full_end, ctr_shift_10_full_end, stage_rd_end, stage_rd_3, stage_rd_7, stage_wr_end, ntt_end, ctr_good_end, good_index_end, good_index_wr_end, point_proc_end, reduce_end;', file=fp)
  print(    '  reg          point_proc_end_reg;',file=fp)
  print(    '', file=fp)

  print(    '  // w_array', file=fp)
  print(    '  reg         [{:<2d}: 0] w_addr_in;'.format(lg2_pgc-1), file=fp)
  if(len(qs) != 0):
    print(  '  wire signed [{:<2d}: 0] w_dout {:s};'.format(max(lg2_qs)-1, qa_str), file=fp)
  else:
    print(  '  wire signed [{:<2d}: 0] w_dout ;'.format(lg2_q0-1), file=fp)
  print(    '', file=fp)

  if(goodfactor == 3):
    print(  '  // mod_3', file=fp)
    print(  '  wire [1 : 0] in_addr;', file=fp)
    print(  '  wire [1 : 0] out_good0, out_good1;', file=fp)
    print(  '  reg  [1 : 0] out_good0_0, out_good1_0;', file=fp)
    print(  '  wire         acc_ctrl;', file=fp)
    print(  '  reg  [9 : 0] acc_ctrls;', file=fp)
  print(    '', file=fp)

  print(    '  // misc', file=fp)
  print(    '  reg          bank_index_rd_shift_1, bank_index_rd_shift_2;', file=fp)
  print(    '  reg [{:<2d}: 0] wr_ctr [0 : 1];'.format(lg2_pgc-1), file=fp)
  print(    '  reg [{:<2d}: 0] din_shift_1, din_shift_2, din_shift_3;'.format(lg2_q0-1), file=fp)
  print(    '  reg [{:<2d}: 0] w_addr_in_shift_1;'.format(lg2_pgc-1), file=fp)
  print(    '', file=fp)

  if(len(qs) != 0):
    print(  '  // crt', file=fp)
    print(  '  reg  signed [{:<2d}:0] in_b_1 {:s};'.format(lg2_qi_max-1, qa_str), file=fp)
    print(  '  reg  signed [{:<2d}:0] in_b_sum;'.format(lg2_qi_max+1), file=fp)
    print(  '  reg  signed [{:<2d}:0] bw_sum;'.format(lg2_qp-1), file=fp)
    print(  '  wire signed [{:<2d}:0] bw_sum_ALL;'.format(lg2_qp-1), file=fp)
    print(  '  wire signed [{:<2d}:0] qproduct_ALL;'.format(lg2_qp-1), file=fp)
    print(  '  reg  signed [{:<2d}:0] bw_sum_mod;'.format(lg2_qp-2), file=fp)
    print(  '  wire signed [{ql:d}:0] mod{q0:d}_out;'.format(ql=lg2_q0-1,q0=q0), file=fp)
    print(    '', file=fp)

  print(    '  // BRAM instances', file=fp)
  print(    '  bram_{:d}_{:d}_P bank_0'.format(ql_total, lg2_pc), file=fp)
  print(    '  (clk, wr_en[0], wr_addr[0], rd_addr[0], wr_din[0], wr_dout[0], rd_dout[0]);', file=fp)
  print(    '  bram_{:d}_{:d}_P bank_1'.format(ql_total, lg2_pc), file=fp)
  print(    '  (clk, wr_en[1], wr_addr[1], rd_addr[1], wr_din[1], wr_dout[1], rd_dout[1]);', file=fp)
  print(    '', file=fp)

  print(    '  // Read/Write Address Generator', file=fp)
  print(    '  addr_gen addr_rd_0 (clk, stage_rdM, {{ctr_MSB_masked, ctr[{:d}:0]}}, bank_index_rd[0], data_index_rd[0]);'.format(lg2_pgc-2), file=fp)
  print(    '  addr_gen addr_rd_1 (clk, stage_rdM, {{1\'b1, ctr[{:d}:0]}}, bank_index_rd[1], data_index_rd[1]);'.format(lg2_pgc-2), file=fp)
  print(    '  addr_gen addr_wr_0 (clk, stage_wrM, {wr_ctr[0]}, bank_index_wr[0], data_index_wr[0]);', file=fp)
  print(    '  addr_gen addr_wr_1 (clk, stage_wrM, {wr_ctr[1]}, bank_index_wr[1], data_index_wr[1]);', file=fp)
  print(    '', file=fp)

  print(    '  // Omega Address Generator', file=fp)
  print(    '  w_addr_gen w_addr_gen_0 (clk, stage_bit, ctr[{:d}:0], w_addr);'.format(lg2_pgc-2), file=fp)
  print(    '', file=fp)

  print(      '  // Butterfly Unit ' + ('' if (len(qs) <= 1) else 's') + ' , each with a corresponding omega array', file=fp)
  if(len(qs) == 0):
    print(    '  bfu_{:d} bfu_inst (clk, ntt_state, acc_ctrls[7], in_a, in_b, in_w, bw, out_a, out_b);'.format(q0), file=fp)
    print(    '  w_{:d} rom_w_inst (clk, w_addr_in_shift_1, w_dout);'.format(q0), file=fp) 
  elif(len(qs) == 1):
    print(    '  bfu_{:d} bfu_inst (clk, ntt_state, acc_ctrls[7], in_a, in_b, in_w, bw, out_a, out_b);'.format(qs[0]), file=fp)
    print(    '  w_{:d} rom_w_inst (clk, w_addr_in_shift_1, w_dout);'.format(qs[0]), file=fp) 
  else:
    for idx, (qi, lg2_qi) in enumerate(zip(qs, lg2_qs)):
      print(  '  bfu_{q:d} bfu_inst{idx} (clk, ntt_state, acc_ctrls[7], in_a[{idx}], in_b[{idx}], in_w[{idx}], bw[{idx}], out_a[{idx}], out_b[{idx}]);'.format(q=qi, idx=idx), file=fp)
      if(lg2_qi != max(lg2_qs)):
        print('  w_{q:d} rom_w_inst{idx} (clk, w_addr_in_shift_1, w_dout[{idx}][{lg2qim}:0]);'.format(q=qi, idx=idx, lg2qim=lg2_qi-1), file=fp)
        print('  assign w_dout[{idx}][{lg2mxm}:{lg2qi}] = {{ {num} {{ w_dout[{idx}][{lg2qim}] }} }} ;'.format(idx=idx, lg2mxm=max(lg2_qs)-1, lg2qi=lg2_qi, num = max(lg2_qs) - lg2_qi, lg2qim=lg2_qi-1), file=fp)
      else:
        print('  w_{q:d} rom_w_inst{idx} (clk, w_addr_in_shift_1, w_dout[{idx}]);'.format(q=qi, idx=idx), file=fp) 
  print(      '', file=fp)

  if(goodfactor == 3):
    print(  '  mod_3 in_addr_gen ( clk, addr, in_addr );', file=fp)
    print(  '  good3_addr_gen good3_addr_0 ( clk, good_index, ctr_good, out_good0, out_good1, acc_ctrl );', file=fp)
    print(  '', file=fp)
    print(  '  always @ ( posedge clk ) begin', file=fp)
    print(  '    out_good0_0 <= out_good0;', file=fp)
    print(  '    out_good1_0 <= out_good1;', file=fp)
    print(  '    acc_ctrls <= { acc_ctrls, acc_ctrl };', file=fp)
    print(  '  end', file=fp)
    print(  '', file=fp)

  if(len(qs) != 0):
    print(  '  // MOD {:d} (Note: manual optimization for this part may be necessary.)'.format(q0), file=fp)
    x = '{{ bw_sum_mod[{M:d}], bw_sum_mod[{Mm:d}:0] }}'.format(M=lg2_qp-2,Mm=lg2_pqb-2)
    print(  '  mod{q0:d}SS{lg2_pqb:d} mod_q0_inst ( clk, rst, {x:s}, mod{q0:d}_out);'.format(q0=q0,lg2_pqb=lg2_pqb,x=x), file=fp)
    print(  '', file=fp)

  print(    '  // miscellaneous checkpoint', file=fp)
  print(    '  assign ctr_half_end         = (ctr[{:d}:0] == {:d}) ? 1 : 0;'.format(lg2_pgc-2, (p_g_cover >> 1)-1), file=fp)
  print(    '  assign ctr_full_end         = (ctr[{:d}:0] == {:d}) ? 1 : 0;'.format(lg2_pgc-1, p_g_cover-1), file=fp)
  print(    '  assign ctr_shift_2_full_end = (ctr_shift_2[{:d}:0] == {:d}) ? 1 : 0;'.format(lg2_pgc-1, p_g_cover-1), file=fp)
  print(    '  assign ctr_shift_10_full_end = (ctr_shift_10[{:d}:0] == {:d}) ? 1 : 0;'.format(lg2_pgc-1, p_g_cover-1), file=fp)
  print(    '  assign ctr_shift_7_end      = (ctr_shift_7[{:d} : 0] == {:d}) ? 1 : 0;'.format(lg2_pgc-2, (p_g_cover >> 1)-1), file=fp)
  print(    '  assign stage_rd_end         = (stage == {:d}) ? 1 : 0;'.format(lg2_pgc), file=fp)
  if(goodfactor == 3):
    print(  '  assign stage_rd_3           = (stage == 3) ? 1 : 0;', file=fp)
    print(  '  assign stage_rd_7           = (stage == 7) ? 1 : 0;', file=fp)
  print(    '  assign stage_wr_end         = (stage_wr == {:d}) ? 1 : 0;'.format(lg2_pgc), file=fp)
  print(    '  assign ntt_end              = (stage_rd_end && ctr[{:d} : 0] == 10) ? 1 : 0;'.format(lg2_pgc-2), file=fp)
  print(    '  assign ctr_good_end         = (ctr_good == \'d{:d});'.format(goodfactor-1), file=fp)
  print(    '  assign good_index_end       = (good_index == \'d{});'.format(goodfactor-1), file=fp)
  print(    '  assign good_index_wr_end    = (good_index_wr == \'d{});'.format(goodfactor-1), file=fp)
  print(    '  assign crt_end              = (stage_rd_7 && ctr[{:d} : 0] == 10) ? 1 : 0;'.format(lg2_pgc-2), file=fp)
  print(    '  assign point_proc_end       = (ctr == {:d}) ? 1 : 0;'.format(p_g_cover + 3), file=fp)
  if(goodfactor == 3):
    print(  '  assign reload_end           = (stage_rd_3 && ctr[{:d}:0] == 4) ? 1 : 0;'.format(lg2_pgc-2), file=fp)
  print(    '  assign reduce_end           = reload_end;', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state != ST_PMUL) begin', file=fp)
  print(    '      point_proc_end_reg <= 0;', file=fp)
  print(    '    end else if (good_index_end && ctr_full_end && ctr_good_end) begin', file=fp)
  print(    '      point_proc_end_reg <= 1;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // crt', file=fp)
  if (len(qs) == 1):
    print(  '  assign bw_sum_ALL = bw_sum;', file=fp)
    print(  '  assign qproduct_ALL = (bw_sum_ALL > QALLp_DIV2) ? $signed(QALLn) :', file=fp)
    print(  '                        (bw_sum_ALL < QALLn_DIV2) ? $signed(QALLp) : \'sd0;', file=fp)
    print(  '', file=fp)
    print(  '  always @ ( posedge clk ) begin', file=fp)
    print(  '    in_b_1     <= in_b;', file=fp)
    print(  '    in_b_sum   <= in_b_1;', file=fp)
    print(  '    bw_sum     <= bw;', file=fp)
    print(  '    bw_sum_mod <= bw_sum_ALL + qproduct_ALL;', file=fp)
    print(  '  end', file=fp)
    print(  '', file=fp)
  elif (len(qs) >= 2):
    print(  '  assign bw_sum_ALL = bw_sum + in_b_sum;', file=fp)
    print(  '  assign qproduct_ALL = (bw_sum_ALL > QALLp_DIV2) ? $signed(QALLn) :', file=fp)
    print(  '                        (bw_sum_ALL < QALLn_DIV2) ? $signed(QALLp) : \'sd0;', file=fp)
    print(  '', file=fp)
    print(  '  always @ ( posedge clk ) begin', file=fp)
    qs_else_shift = list(map(lambda qi_else: qi_else[1], qs_else))
    mqes = min(qs_else_shift)
    ibs_x = ''
    bsm_x = ''
    for idx,qi_else_shift in enumerate(qs_else_shift):
      print('    in_b_1[{qid:d}] <= in_b[{qid:d}];'.format(qid=idx), file=fp)
      if (idx != 0):
        ibs_x += ' + '
        bsm_x += ' + '
      ibs_x += 'in_b_1[{qid:d}]'.format(qid=idx)
      if(qi_else_shift == mqes): 
        bsm_x += 'bw[{qid:d}][{qh:d}:0]'.format(qid=idx,qh=lg2_qp-1-mqes)
      else:
        bsm_x += '{{ bw[{qid:d}][{qh:d}:0], {bws:d}\'b0 }}'.format(qid=idx,qh=lg2_qp-1-qi_else_shift,bws=qi_else_shift-mqes)
    print(  '    in_b_sum <= {:s};'.format(ibs_x), file=fp)
    print(  '    bw_sum[{qh:d}:{ql:d}] <= {bsm:s};'.format(qh=lg2_qp-1, ql=mqes, bsm=bsm_x), file=fp)
    print(  '    bw_sum[{ql:d}:0] <= {qlp:d}\'b0;'.format(ql=mqes-1,qlp=mqes), file=fp)
    print(  '    bw_sum_mod <= bw_sum_ALL + qproduct_ALL;', file=fp)
    print(  '  end', file=fp)
    print(  '', file=fp)

  print(    '  // fg_shift', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    fg_shift_1 <= input_fg;', file=fp)
  print(    '    fg_shift_2 <= fg_shift_1;', file=fp)
  print(    '    fg_shift_3 <= fg_shift_2;', file=fp)
  print(    '  end', file=fp)

  print(    '  // dout', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_FINISH) begin', file=fp) 
  print(    '      if (bank_index_wr_0_shift_2) begin', file=fp)
  print(    '        dout <= wr_dout[1][{:d}:0];'.format(lg2_q0-1), file=fp)
  print(    '      end else begin', file=fp)
  print(    '        dout <= wr_dout[0][{:d}:0];'.format(lg2_q0-1), file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      dout <= \'sd0;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // bank_index_wr_0_shift_1', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    bank_index_wr_0_shift_1 <= bank_index_wr[0];', file=fp)
  print(    '    bank_index_wr_0_shift_2 <= bank_index_wr_0_shift_1;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // poly_select', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (good_index_end && ntt_end) begin', file=fp)
  print(    '        poly_select <= ~poly_select;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        poly_select <= poly_select;', file=fp)
  print(    '      end    ', file=fp)
  print(    '    end else if (state == ST_RELOAD) begin', file=fp)
  print(    '      poly_select <= 1;', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      poly_select <= 0;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // good_index', file=fp)
  print(    '  assign good_index_next = good_index_end ? \'d0 : (good_index + \'d1);', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state != next_state) begin', file=fp)
  print(    '      good_index <= \'d0;', file=fp)
  print(    '    end else if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (ntt_end) begin', file=fp)
  print(    '        good_index <= good_index_next;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        good_index <= good_index;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_PMUL) begin', file=fp)
  print(    '      if (point_proc_end && ctr_good_end) begin', file=fp)
  print(    '        good_index <= good_index_next;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        good_index <= good_index;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_RELOAD || state == ST_CRT || state == ST_REDUCE ) begin', file=fp)
  print(    '      if (ctr_shift_2_full_end) begin', file=fp)
  print(    '        good_index <= good_index_next;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        good_index <= good_index;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      if (ctr_full_end) begin', file=fp)
  print(    '        good_index <= good_index_next;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        good_index <= good_index;', file=fp)
  print(    '      end', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  if(goodfactor == 3):
    print(  '  assign good_index_buf = { good_index[0], 1\'b1, !good_index[1] };', file=fp)
  print(    '', file=fp)

  print(    '  // good_index_wr', file=fp)
  print(    '  assign good_index_wr_next = good_index_wr_end ? \'d0 : (good_index_wr + \'d1);', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state != next_state) begin', file=fp)
  print(    '      good_index_wr <= \'d0;', file=fp)
  print(    '    end else if (state == ST_CRT) begin', file=fp)
  print(    '      if (ctr_shift_10_full_end && good_index_wr != good_index) begin', file=fp)
  print(    '        good_index_wr <= good_index_wr_next;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        good_index_wr <= good_index_wr;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      if (ctr_full_end) begin', file=fp)
  print(    '        good_index_wr <= good_index_wr_next;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        good_index_wr <= good_index_wr;', file=fp)
  print(    '      end', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // w_addr_in_shift_1', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    w_addr_in_shift_1 <= w_addr_in;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // din_shift', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    din_shift_1 <= din;', file=fp)
  print(    '    din_shift_2 <= din_shift_1;', file=fp)
  print(    '    din_shift_3 <= din_shift_2;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // rd_addr', file=fp)
  print(    '  always @(posedge clk ) begin', file=fp)
  print(    '    if ( state == ST_NTT || state == ST_INTT ) begin', file=fp)
  print(    '      if (poly_select ^ bank_index_rd[0]) begin', file=fp)
  print(    '        rd_addr[0][{:d}:0] <= data_index_rd[1];'.format(lg2_pgc-2), file=fp)
  print(    '        rd_addr[1][{:d}:0] <= data_index_rd[0];'.format(lg2_pgc-2), file=fp)
  print(    '      end else begin', file=fp)
  print(    '        rd_addr[0][{:d}:0] <= data_index_rd[0];'.format(lg2_pgc-2), file=fp)
  print(    '        rd_addr[1][{:d}:0] <= data_index_rd[1];'.format(lg2_pgc-2), file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      rd_addr[0][{ql:d}:0] <= data_index_rd[0];'.format(ql=lg2_pgc-2), file=fp)
  print(    '      rd_addr[1][{ql:d}:0] <= data_index_rd[0];'.format(ql=lg2_pgc-2), file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    if ( state == ST_PMUL ) begin', file=fp)
  print(    '      // TODO: good factor control', file=fp)
  print(    '      rd_addr[0][{qh:d}:{ql:d}] <= out_good0_0;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '      rd_addr[1][{qh:d}:{ql:d}] <= out_good1_0;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '    end else if ( state == ST_RELOAD ) begin', file=fp)
  if(goodfactor == 3):
    print(  '      rd_addr[0][{qh:d}:{ql:d}] <= {{ 1\'b1, !good_index[1] }};'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
    print(  '      rd_addr[1][{qh:d}:{ql:d}] <= {{ 1\'b1, !good_index[1] }};'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '    end else begin', file=fp)
  print(    '      rd_addr[0][{qh:d}:{ql:d}] <= good_index;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '      rd_addr[1][{qh:d}:{ql:d}] <= good_index;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    if (state == ST_NTT)  begin', file=fp)
  print(    '      rd_addr[0][{:d}] <= poly_select;'.format(lg2_pc-1), file=fp)
  print(    '      rd_addr[1][{:d}] <= poly_select;'.format(lg2_pc-1), file=fp)
  print(    '    end else if (state == ST_PMUL) begin', file=fp)
  print(    '      rd_addr[0][{:d}] <=  bank_index_rd[0];'.format(lg2_pc-1), file=fp)
  print(    '      rd_addr[1][{:d}] <= ~bank_index_rd[0];'.format(lg2_pc-1), file=fp)
  print(    '    end else if (state == ST_RELOAD) begin', file=fp)
  if(goodfactor == 3):
    print(  '      rd_addr[0][{:d}] <= good_index[0];'.format(lg2_pc-1), file=fp)
    print(  '      rd_addr[1][{:d}] <= good_index[0];'.format(lg2_pc-1), file=fp)
  print(    '    end else begin', file=fp)
  print(    '      rd_addr[0][{:d}] <= 1;'.format(lg2_pc-1), file=fp)
  print(    '      rd_addr[1][{:d}] <= 1;'.format(lg2_pc-1), file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // wr_en', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (stage == 0 && ctr < 11) begin', file=fp)
  print(    '        wr_en[0] <= 0;', file=fp)
  print(    '        wr_en[1] <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_en[0] <= 1;', file=fp)
  print(    '        wr_en[1] <= 1;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_IDLE) begin', file=fp)
  print(    '      if (fg_shift_3 ^ bank_index_wr[0]) begin', file=fp)
  print(    '        wr_en[0] <= 0;', file=fp)
  print(    '        wr_en[1] <= 1;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_en[0] <= 1;', file=fp)
  print(    '        wr_en[1] <= 0;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_PMUL) begin', file=fp)
  print(    '      if ((ctr < 4) || (ctr_good != 1)) begin', file=fp)
  print(    '        wr_en[0] <= 0;', file=fp)
  print(    '        wr_en[1] <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_en[0] <= good_index_buf[{:d}] ^ ~bank_index_wr[0];'.format(lg2_pc-lg2_pgc), file=fp)
  print(    '        wr_en[1] <= good_index_buf[{:d}] ^  bank_index_wr[0];'.format(lg2_pc-lg2_pgc), file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_REDUCE) begin', file=fp)
  print(    '      if (stage == 0 && ctr < 4) begin', file=fp)
  print(    '        wr_en[0] <= 0;', file=fp)
  print(    '        wr_en[1] <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_en[0] <= ~bank_index_wr[0];', file=fp)
  print(    '        wr_en[1] <=  bank_index_wr[0];', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_CRT) begin', file=fp)
  print(    '      if (stage == 0 && ctr < 11) begin', file=fp)
  print(    '        wr_en[0] <= 0;', file=fp)
  print(    '        wr_en[1] <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_en[0] <=  bank_index_wr[0];', file=fp)
  print(    '        wr_en[1] <= ~bank_index_wr[0];', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_RELOAD) begin', file=fp)
  print(    '      if ((stage == 0 && ctr < 4) || (stage_wr == {:d})) begin'.format(goodfactor), file=fp)
  print(    '        wr_en[0] <= 0;', file=fp)
  print(    '        wr_en[1] <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_en[0] <=  bank_index_wr[0];', file=fp)
  print(    '        wr_en[1] <= ~bank_index_wr[0];', file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      wr_en[0] <= 0;', file=fp)
  print(    '      wr_en[1] <= 0;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // wr_addr', file=fp)
  print(    '  always @(posedge clk ) begin', file=fp)
  print(    '    if ( state == ST_NTT || state == ST_INTT ) begin', file=fp)
  print(    '      if (poly_select ^ bank_index_wr[0]) begin', file=fp)
  print(    '        wr_addr[0][{:d}:0] <= data_index_wr[1];'.format(lg2_pgc-2), file=fp)
  print(    '        wr_addr[1][{:d}:0] <= data_index_wr[0];'.format(lg2_pgc-2), file=fp)
  print(    '      end else begin', file=fp)
  print(    '        wr_addr[0][{:d}:0] <= data_index_wr[0];'.format(lg2_pgc-2), file=fp)
  print(    '        wr_addr[1][{:d}:0] <= data_index_wr[1];'.format(lg2_pgc-2), file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      wr_addr[0][{:d}:0] <= data_index_wr[0];'.format(lg2_pgc-2), file=fp)
  print(    '      wr_addr[1][{:d}:0] <= data_index_wr[0];'.format(lg2_pgc-2), file=fp)
  print(    '    end  ', file=fp)
  print(    '', file=fp)
  print(    '    if ( state == ST_IDLE || state == ST_FINISH ) begin', file=fp)
  print(    '      wr_addr[0][{qh:d}:{ql:d}] <= in_addr;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '      wr_addr[1][{qh:d}:{ql:d}] <= in_addr;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '    end else if ( state == ST_PMUL ) begin', file=fp)
  print(    '      wr_addr[0][{qh:d}:{ql:d}] <= good_index_buf[{qgl:d}:0];'.format(qh=lg2_pc-2, ql=lg2_pgc-1, qgl=lg2_pc-lg2_pgc-1), file=fp)
  print(    '      wr_addr[1][{qh:d}:{ql:d}] <= good_index_buf[{qgl:d}:0];'.format(qh=lg2_pc-2, ql=lg2_pgc-1, qgl=lg2_pc-lg2_pgc-1), file=fp)
  print(    '    end else if ( state == ST_RELOAD || state == ST_REDUCE ) begin', file=fp)
  print(    '      wr_addr[0][{qh:d}:{ql:d}] <= stage_wr[{qgl:d}:0];'.format(qh=lg2_pc-2, ql=lg2_pgc-1, qgl=lg2_pc-lg2_pgc-1), file=fp)
  print(    '      wr_addr[1][{qh:d}:{ql:d}] <= stage_wr[{qgl:d}:0];'.format(qh=lg2_pc-2, ql=lg2_pgc-1, qgl=lg2_pc-lg2_pgc-1), file=fp)
  print(    '    end else if ( state == ST_CRT ) begin', file=fp)
  print(    '      wr_addr[0][{qh:d}:{ql:d}] <= good_index_wr;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '      wr_addr[1][{qh:d}:{ql:d}] <= good_index_wr;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '    end else begin', file=fp)
  print(    '      wr_addr[0][{qh:d}:{ql:d}] <= good_index;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '      wr_addr[1][{qh:d}:{ql:d}] <= good_index;'.format(qh=lg2_pc-2, ql=lg2_pgc-1), file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    if (state == ST_IDLE) begin', file=fp)
  print(    '      wr_addr[0][{:d}] <= fg_shift_3;'.format(lg2_pc-1), file=fp)
  print(    '      wr_addr[1][{:d}] <= fg_shift_3;'.format(lg2_pc-1), file=fp)
  print(    '    end else if(state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      wr_addr[0][{:d}] <= poly_select;'.format(lg2_pc-1), file=fp)
  print(    '      wr_addr[1][{:d}] <= poly_select;'.format(lg2_pc-1), file=fp)
  print(    '    end else if (state == ST_PMUL) begin', file=fp)
  print(    '      wr_addr[0][{:d}] <= good_index_buf[{:d}];'.format(lg2_pc-1, lg2_pc-lg2_pgc), file=fp)
  print(    '      wr_addr[1][{:d}] <= good_index_buf[{:d}];'.format(lg2_pc-1, lg2_pc-lg2_pgc), file=fp)
  print(    '    end else if (state == ST_REDUCE || state == ST_FINISH) begin', file=fp)
  print(    '      wr_addr[0][{:d}] <= 0;'.format(lg2_pc-1), file=fp)
  print(    '      wr_addr[1][{:d}] <= 0;'.format(lg2_pc-1), file=fp)
  print(    '    end else begin', file=fp)
  print(    '      wr_addr[0][{:d}] <= 1;'.format(lg2_pc-1), file=fp)
  print(    '      wr_addr[1][{:d}] <= 1;'.format(lg2_pc-1), file=fp)
  print(    '    end     ', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // wr_din', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  lg2_q_st = 0
  for idx, (qi, lg2_qi, lg2_qi_diff) in enumerate(zip(qsX, lg2_qsX, lg2_qsXdiff)):
    if(idx != 0):
      print('', file=fp)
    print(  '    if (state == ST_IDLE) begin', file=fp)
    x = '{ '
    if (lg2_qi_diff == 1):
      x += 'din_shift_3[{:d}], '.format(lg2_q0-1)
    elif (lg2_qi_diff != 0):
      x += '{{ {:d} {{ din_shift_3[{:d}] }} }}, '.format(lg2_qi_diff, lg2_q0-1)
    x += 'din_shift_3 }'
    print(  '      wr_din[0][{qh:d}:{ql:d}] <= {din:s};'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, din=x), file=fp)
    print(  '      wr_din[1][{qh:d}:{ql:d}] <= {din:s};'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, din=x), file=fp)
    print(  '    end else if (state == ST_NTT || state == ST_INTT) begin', file=fp)
    print(  '      if (poly_select ^ bank_index_wr[0]) begin', file=fp)
    if(len(qs) >= 2):
      print('        wr_din[0][{qh:d}:{ql:d}] <= out_b[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
      print('        wr_din[1][{qh:d}:{ql:d}] <= out_a[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
    else:
      print('        wr_din[0][{qh:d}:{ql:d}] <= out_b;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
      print('        wr_din[1][{qh:d}:{ql:d}] <= out_a;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '      end else begin', file=fp)
    if(len(qs) >= 2):
      print('        wr_din[0][{qh:d}:{ql:d}] <= out_a[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
      print('        wr_din[1][{qh:d}:{ql:d}] <= out_b[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
    else:
      print('        wr_din[0][{qh:d}:{ql:d}] <= out_a;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
      print('        wr_din[1][{qh:d}:{ql:d}] <= out_b;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '      end', file=fp)
    print(  '    end else if (state == ST_RELOAD) begin', file=fp)
    print(  '      if (bank_index_rd_shift_2 ^ stage_wr[0]) begin', file=fp)
    print(  '        wr_din[0][{qh:d}:{ql:d}] <= rd_dout[1][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '        wr_din[1][{qh:d}:{ql:d}] <= rd_dout[1][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '      end else begin', file=fp)
    print(  '        wr_din[0][{qh:d}:{ql:d}] <= rd_dout[0][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '        wr_din[1][{qh:d}:{ql:d}] <= rd_dout[0][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '      end', file=fp)
    print(  '    end else if (state == ST_REDUCE) begin', file=fp)
    print(  '      if (bank_index_rd_shift_2) begin', file=fp)
    print(  '        wr_din[0][{qh:d}:{ql:d}] <= rd_dout[0][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '        wr_din[1][{qh:d}:{ql:d}] <= rd_dout[0][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '      end else begin', file=fp)
    print(  '        wr_din[0][{qh:d}:{ql:d}] <= rd_dout[1][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '        wr_din[1][{qh:d}:{ql:d}] <= rd_dout[1][{qh:d}:{ql:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '      end', file=fp)
    if(len(qs) == 1):
      print('    end else if (state == ST_CRT) begin', file=fp)
      print('      wr_din[0][{qh:d}:{ql:d}] <= mod{q0:d}_out;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, q0=q0), file=fp)
      print('      wr_din[1][{qh:d}:{ql:d}] <= mod{q0:d}_out;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, q0=q0), file=fp)
    elif(len(qs) >= 2):
      print('    end else if (state == ST_CRT) begin', file=fp)
      print('      if (stage_wr[{:d}] == 0) begin'.format(2 if (goodfactor == 3) else 0), file=fp)
      print('        wr_din[0][{qh:d}:{ql:d}] <= out_a[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
      print('        wr_din[1][{qh:d}:{ql:d}] <= out_a[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
      print('      end else begin', file=fp)
      print('        wr_din[0][{qh:d}:{ql:d}] <= mod{q0:d}_out;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, q0=q0), file=fp)
      print('        wr_din[1][{qh:d}:{ql:d}] <= mod{q0:d}_out;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, q0=q0), file=fp)
      print('      end', file=fp)
    print(  '    end else begin', file=fp)
    if(len(qs) >= 2):
      print(  '      wr_din[0][{qh:d}:{ql:d}] <= out_a[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
      print(  '      wr_din[1][{qh:d}:{ql:d}] <= out_a[{qid:d}];'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st, qid=idx), file=fp)
    else:
      print(  '      wr_din[0][{qh:d}:{ql:d}] <= out_a;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
      print(  '      wr_din[1][{qh:d}:{ql:d}] <= out_a;'.format(qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    print(  '    end', file=fp)
    lg2_q_st += lg2_qi
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // bank_index_rd_shift', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    bank_index_rd_shift_1 <= bank_index_rd[0];', file=fp)
  print(    '    bank_index_rd_shift_2 <= bank_index_rd_shift_1;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // ntt_state', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_INTT) begin', file=fp)
  print(    '      ntt_state <= 1;', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      ntt_state <= 0;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  //acc_state', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if ( state == ST_PMUL ) begin', file=fp)
  print(    '      // acc_state turn off 1 cycle per _goodfactor_ cycles', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      acc_state <= 0;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // in_a, in_b', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  # in_b
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (poly_select ^ bank_index_rd_shift_2) begin', file=fp)
  if (len(qsX) == 1):
    print(  '        in_b <= $signed(rd_dout[0]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('        in_b[{qid:d}] <= $signed(rd_dout[0][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '      end else begin', file=fp)
  if (len(qsX) == 1):
    print(  '        in_b <= $signed(rd_dout[1]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('        in_b[{qid:d}] <= $signed(rd_dout[1][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_CRT) begin', file=fp)
  print(    '      if (bank_index_rd_shift_2) begin', file=fp)
  if (len(qsX) == 1):
    print(  '        in_b <= $signed(rd_dout[0]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('        in_b[{qid:d}] <= $signed(rd_dout[0][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '      end else begin', file=fp)
  if (len(qsX) == 1):
    print(  '        in_b <= $signed(rd_dout[1]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('        in_b[{qid:d}] <= $signed(rd_dout[1][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '      end', file=fp)
  print(    '    end else begin // ST_PMUL', file=fp)
  if (len(qsX) == 1):
    print(  '      in_b <= $signed(rd_dout[1]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('      in_b[{qid:d}] <= $signed(rd_dout[1][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '    end', file=fp)
  print(    '', file=fp)
  # in_a
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (poly_select ^ bank_index_rd_shift_2) begin', file=fp)
  if (len(qsX) == 1):
    print(  '        in_a <= $signed(rd_dout[1]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('        in_a[{qid:d}] <= $signed(rd_dout[1][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '      end else begin', file=fp)
  if (len(qsX) == 1):
    print(  '        in_a <= $signed(rd_dout[0]);', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('        in_a[{qid:d}] <= $signed(rd_dout[0][{qh:d}:{ql:d}]);'.format(qid=idx,qh=lg2_q_st+lg2_qi-1,ql=lg2_q_st), file=fp)
      lg2_q_st += lg2_qi
  print(    '      end', file=fp)
  print(    '    end else begin // ST_PMUL, ST_CRT', file=fp)
  if (len(qsX) == 1):
    print(  '      in_a <= \'sd0;', file=fp)
  else:
    lg2_q_st = 0
    for idx, lg2_qi in enumerate(lg2_qsX):
      print('      in_a[{qid:d}] <= \'sd0;'.format(qid=idx), file=fp)
      lg2_q_st += lg2_qi
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(      '  // w_addr_in, in_w', file=fp)
  print(      '  always @ ( posedge clk ) begin', file=fp)
  print(      '    if (state == ST_NTT) begin', file=fp)
  print(      '      w_addr_in <= {1\'b0, w_addr};', file=fp)
  print(      '    end else begin', file=fp)
  print(      '      w_addr_in <= {:d} - w_addr;'.format(p_g_cover), file=fp)
  print(      '    end', file=fp)
  print(      '', file=fp)
  print(      '    if (state == ST_PMUL) begin', file=fp)
  lg2_q_st = 0
  for idx, lg2_qi in enumerate(lg2_qsX):
    lg2_w_diff = lg2_wmax - lg2_qi
    if( len(qs) == 0 ):
      print(  '        in_w <= rd_dout[0];', file=fp)
    else:
      if (lg2_w_diff == 1):
        print('        in_w[{qid:d}] <= {{ rd_dout[0][{qh:d}], rd_dout[0][{qh:d}:{ql:d}] }};'.format(qid=idx, qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
      elif (lg2_w_diff == 0):
        print('        in_w[{qid:d}] <= rd_dout[0][{qh:d}:{ql:d}];'.format(qid=idx, qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
      else:
        print('        in_w[{qid:d}] <= {{ {{ {qd:d} {{ rd_dout[0][{qh:d}] }} }}, rd_dout[0][{qh:d}:{ql:d}] }};'.format( \
              qid=idx, qd=lg2_w_diff, qh=lg2_q_st+lg2_qi-1, ql=lg2_q_st), file=fp)
    lg2_q_st += lg2_qi
  if ( len(qs) >= 2 ):
    print(    '    end else if (state == ST_CRT) begin', file=fp)
    if(goodfactor == 3):
      print(  '      if (stage[2] == 0 || (stage == 4 && ctr <= 3)) begin', file=fp)
    else:
      print(  '      if (stage == 0 || (stage == 1 && ctr <= 3)) begin', file=fp)
    for idx in range(len(qs)):
      print(  '        in_w[{qid:d}] <= Q_n{qidp:d}_INV;'.format(qid=idx, qidp=idx+1), file=fp)
    print(    '      end else begin', file=fp)
    for idx in range(len(qs)):
      print(  '        in_w[{qid:d}] <= Q_n{qidp:d}_PREFIX;'.format(qid=idx, qidp=idx+1), file=fp)
    print(    '      end', file=fp)
  elif ( len(qs) == 1 ):
    print(    '    end else if (state == ST_CRT) begin', file=fp)
    print(    '      in_w <= 1;', file=fp) 
  print(      '    end else begin', file=fp)
  for idx in range(len(qsX)):
    if(len(qs) >= 2):
      print(  '      in_w[{qid:d}] <= w_dout[{qid:d}];'.format(qid=idx), file=fp)
    else:
      print(  '      in_w <= w_dout;'.format(qid=idx), file=fp)
  print(      '    end', file=fp)
  print(      '  end', file=fp)
  print(      '', file=fp)

  print(    '  // wr_ctr', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_IDLE || state == ST_FINISH) begin', file=fp)
  print(    '      wr_ctr[0] <= addr[{:d}:0];'.format(lg2_pgc-1), file=fp)
  print(    '    end else if (state == ST_RELOAD || state == ST_REDUCE) begin', file=fp)
  # NOTE: latency may not be 2 in the case ST_REDUCE, need to be investigated
  print(    '      wr_ctr[0] <= {', end='', file=fp)
  for idx in range(lg2_pgc):
    if (idx != 0): print(', ', end='', file=fp)
    print(         'ctr_shift_1[{:d}]'.format(idx), end='', file=fp)
  print(           '};', file=fp)
  print(    '    end else if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      wr_ctr[0] <= {{1\'b0, ctr_shift_7[{:d}:0]}};'.format(lg2_pgc-2), file=fp)
  print(    '    end else if (state == ST_PMUL) begin', file=fp)
  if(goodfactor == 3):
    print(  '      wr_ctr[0] <= ctr_pmul_shift_2[{:d}:0];'.format(lg2_pgc-1), file=fp)
  print(    '    end else begin', file=fp)
  print(    '      wr_ctr[0] <= ctr_shift_7[{:d}:0];'.format(lg2_pgc-1), file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    wr_ctr[1] <= {{1\'b1, ctr_shift_7[{:d}:0]}};'.format(lg2_pgc-2), file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // ctr_MSB_masked', file=fp)
  print(    '  always @ (*) begin', file=fp)
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      ctr_MSB_masked = 0;', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      ctr_MSB_masked = ctr[{:d}];'.format(lg2_pgc-1), file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // ctr, ctr_good, ctr_shifts', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state != next_state) begin', file=fp)
  print(    '      ctr <= 0;', file=fp)
  print(    '    end else if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (ntt_end) begin', file=fp)
  print(    '        ctr <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        ctr <= ctr + 1;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_PMUL) begin', file=fp)
  print(    '      if (ctr_good_end) begin', file=fp)
  print(    '        if (point_proc_end) begin', file=fp)
  print(    '          ctr <= 0;', file=fp)
  print(    '        end else begin', file=fp)
  print(    '          ctr <= ctr + 1;', file=fp)
  print(    '        end', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_CRT) begin', file=fp)
  print(    '      if (crt_end || ctr_full_end) begin', file=fp)
  print(    '        ctr <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        ctr <= ctr + 1;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_RELOAD) begin', file=fp)
  print(    '      if (ctr_full_end) begin', file=fp)
  print(    '        ctr <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        ctr <= ctr + 1;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_REDUCE) begin', file=fp)
  print(    '      if (ctr_full_end) begin', file=fp)
  print(    '        ctr <= 0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        ctr <= ctr + 1;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      ctr <= 0;', file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    if (state == ST_PMUL) begin', file=fp)
  print(    '      if (ctr_good == \'d{:d}) begin'.format(goodfactor-1), file=fp)
  print(    '        ctr_good <= \'d0;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        ctr_good <= ctr_good + \'d1;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      ctr_good <= \'d0;', file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    //change ctr_shift_7 <= ctr - 5;', file=fp)
  print(    '    ctr_shift_7 <= ctr - 7;', file=fp)
  print(    '    ctr_shift_8 <= ctr_shift_7;', file=fp)
  print(    '    ctr_shift_9 <= ctr_shift_8;', file=fp)
  print(    '    ctr_shift_10 <= ctr_shift_9;', file=fp)
  print(    '    ctr_shift_1 <= ctr;', file=fp)
  print(    '    ctr_shift_2 <= ctr_shift_1;', file=fp)
  print(    '    ctr_shift_3 <= ctr_shift_2;', file=fp)
  print(    '    ctr_pmul_shift_2 <= ctr_shift_1 - 2;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // stage, stage_wr', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (ntt_end) begin', file=fp)
  print(    '        stage <= 0;', file=fp)
  print(    '      end else if (ctr_half_end) begin', file=fp)
  print(    '        stage <= stage + 1;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        stage <= stage;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_RELOAD || state == ST_REDUCE) begin', file=fp)
  print(    '      if (reload_end) begin', file=fp)
  print(    '        stage <= 0;', file=fp)
  print(    '      end else if (ctr_full_end) begin', file=fp)
  print(    '        stage <= stage + 1;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        stage <= stage;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_CRT) begin', file=fp)
  if(goodfactor == 3):
    print(  '      if (crt_end) begin', file=fp)
    print(  '        stage <= 0;', file=fp)
    print(  '      end else if (ctr_full_end) begin', file=fp)
    print(  '        if(stage == 2) begin', file=fp)
    print(  '          stage <= 4;', file=fp)
    print(  '        end else begin', file=fp)
    print(  '          stage <= stage + 1;', file=fp)
    print(  '        end', file=fp)
    print(  '      end else begin', file=fp)
    print(  '        stage <= stage;', file=fp)
    print(  '      end', file=fp)
  # NOTE: case state == ST_REDUCE may be necessary to modulo primitive polynomial
  print(    '    end else begin', file=fp)
  print(    '      stage <= 0;', file=fp)
  print(    '    end', file=fp)
  print(    '', file=fp)
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (ntt_end) begin', file=fp)
  print(    '        stage_wr <= 0;', file=fp)
  print(    '      end else if (ctr_shift_7[{:d}:0] == 0 && stage != 0) begin'.format(lg2_pgc-2), file=fp)
  print(    '        stage_wr <= stage_wr + 1;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        stage_wr <= stage_wr;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_RELOAD || state == ST_REDUCE) begin', file=fp)
  print(    '      if (reload_end) begin', file=fp)
  print(    '        stage_wr <= 0;', file=fp)
  print(    '      end else if (ctr_shift_3[{:d}:0] == 0 && stage != 0) begin'.format(lg2_pgc-1), file=fp) # NOTE: evaluate delay
  print(    '        stage_wr <= stage_wr + 1;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        stage_wr <= stage_wr;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else if (state == ST_CRT) begin', file=fp)
  if(goodfactor == 3):
    print(  '      if (crt_end) begin', file=fp)
    print(  '        stage_wr <= 0;', file=fp)
    print(  '      end else if (ctr_shift_9[{:d}:0] == 0 && stage != 0) begin'.format(lg2_pgc-1), file=fp)
    print(  '        if(stage_wr == 2) begin', file=fp)
    print(  '          stage_wr <= 4;', file=fp)
    print(  '        end else begin', file=fp)
    print(  '          stage_wr <= stage_wr + 1;', file=fp)
    print(  '        end', file=fp)
    print(  '      end else begin', file=fp)
    print(  '        stage_wr <= stage_wr;', file=fp)
    print(  '      end', file=fp)
  # NOTE: case state_wr == ST_REDUCE may be necessary to modulo primitive polynomial
  print(    '    end else begin', file=fp)
  print(    '      stage_wr <= 0;', file=fp)
  print(    '    end        ', file=fp)
  print(    '  end', file=fp)
  print(    '  assign stage_rdM = (state == ST_NTT || state == ST_INTT) ? stage : 0;', file=fp)
  print(    '  assign stage_wrM = (state == ST_NTT || state == ST_INTT) ? stage_wr : 0;', file=fp)
  print(    '', file=fp)

  print(    '  // stage_bit', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if (state == ST_NTT || state == ST_INTT) begin', file=fp)
  print(    '      if (ntt_end) begin', file=fp)
  print(    '        stage_bit <= 0;', file=fp)
  print(    '      end else if (ctr_half_end) begin', file=fp)
  print(    '        stage_bit[0] <= 1\'b1;', file=fp)
  print(    '        stage_bit[{sh:d} : 1] <= stage_bit[{shm:d} : 0];'.format(sh=lg2_pgc-2, shm=lg2_pgc-3), file=fp)
  print(    '      end else begin', file=fp)
  print(    '        stage_bit <= stage_bit;', file=fp)
  print(    '      end', file=fp)
  print(    '    end else begin', file=fp)
  print(    '      stage_bit <= \'b0;', file=fp)
  print(    '    end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // valid', file=fp)
  print(    '  always @ (*) begin', file=fp)
  print(    '      if (state == ST_FINISH) begin', file=fp)
  print(    '          valid = 1;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '          valid = 0;', file=fp)
  print(    '      end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  // state', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    if(rst) begin', file=fp)
  print(    '            state <= 0;', file=fp)
  print(    '        end else begin', file=fp)
  print(    '            state <= next_state;', file=fp)
  print(    '        end', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    '  always @(*) begin', file=fp)
  print(    '    case(state)', file=fp)
  print(    '    ST_IDLE: begin', file=fp)
  print(    '      if(start)', file=fp)
  print(    '        next_state = ST_NTT;', file=fp)
  print(    '      else', file=fp)
  print(    '        next_state = ST_IDLE;', file=fp)
  print(    '    end', file=fp)
  print(    '    ST_NTT: begin', file=fp)
  print(    '      if(ntt_end && good_index_end && poly_select == 1)', file=fp)
  print(    '        next_state = ST_PMUL;', file=fp)
  print(    '      else', file=fp)
  print(    '        next_state = ST_NTT;', file=fp)
  print(    '    end', file=fp)
  print(    '    ST_PMUL: begin', file=fp)
  print(    '      if (point_proc_end && point_proc_end_reg && ctr_good_end)', file=fp)
  print(    '        next_state = ST_RELOAD;', file=fp)
  print(    '      else', file=fp)
  print(    '        next_state = ST_PMUL;', file=fp)
  print(    '    end', file=fp)
  print(    '    ST_RELOAD: begin', file=fp)
  print(    '      if (reload_end) begin', file=fp)
  print(    '        next_state = ST_INTT;', file=fp)
  print(    '      end else begin', file=fp)
  print(    '        next_state = ST_RELOAD;', file=fp)
  print(    '      end', file=fp)
  print(    '    end', file=fp)
  print(    '    ST_INTT: begin', file=fp)
  print(    '      if(ntt_end && good_index_end)', file=fp)
  if (len(qs) != 0):
    print(  '        next_state = ST_CRT;', file=fp)
  else:
    print(  '        next_state = ST_REDUCE;', file=fp)
  print(    '      else', file=fp)
  print(    '        next_state = ST_INTT;', file=fp)
  print(    '    end', file=fp)
  if (len(qs) != 0):
    print(  '    ST_CRT: begin', file=fp)
    print(  '      if(crt_end)', file=fp)
    print(  '        next_state = ST_REDUCE;', file=fp)
    print(  '      else', file=fp)
    print(  '        next_state = ST_CRT;', file=fp)
    print(  '    end', file=fp)
  print(    '    ST_REDUCE: begin', file=fp)
  print(    '      if(reduce_end)', file=fp)
  print(    '        next_state = ST_FINISH;', file=fp)
  print(    '      else', file=fp)
  print(    '        next_state = ST_REDUCE;', file=fp)
  print(    '    end', file=fp)
  print(    '    ST_FINISH: begin', file=fp)
  print(    '      if(!start)', file=fp)
  print(    '        next_state = ST_FINISH;', file=fp)
  print(    '      else', file=fp)
  print(    '        next_state = ST_IDLE;', file=fp)
  print(    '    end', file=fp)
  print(    '    default: next_state = ST_IDLE;', file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    'endmodule', file=fp)
  print(    '', file=fp)

  return


# ----- mod_3 generator
def mod3_gen(fp, lg2_pc):
  lg2_pc_it = lg2_pc
  oddbit = []
  lg2_ob = []
  evenbit = []
  lg2_eb = []
  oesummax = []
  lg2_oesm = []

  
  while(lg2_pc_it > 4):
    oddbit_it = lg2_pc_it // 2
    oddbit += [oddbit_it]
    lg2_ob_it = oddbit_it.bit_length()
    lg2_ob += [lg2_ob_it]
    evenbit_it = lg2_pc_it - oddbit_it
    evenbit += [evenbit_it]
    lg2_eb_it = evenbit_it.bit_length()
    lg2_eb += [lg2_eb_it]
    oesummax_it = evenbit_it + 2 * oddbit_it
    oesummax += [oesummax_it]
    lg2_pc_it = oesummax_it.bit_length()
    lg2_oesm += [lg2_pc_it]

  round_oe = len(oddbit)

  print(    'module mod_3 ( clk, addr, Out ) ;', file=fp)
  print(    '', file=fp)
  print(    '  input clk;',file=fp)
  print(    '  input      [{:<2d}: 0] addr;'.format(lg2_pc-1), file=fp)
  print(    '  output reg [1 : 0] Out;', file=fp)
  print(    '', file=fp)
  for idx0 in range(round_oe):
    print(  '  wire       [{:<2d}: 0] even{:d};'.format(lg2_eb[idx0]-1, idx0), file=fp)
    print(  '  wire       [{:<2d}: 0] odd{:d};'.format(lg2_ob[idx0]-1, idx0), file=fp)
    print(  '  reg        [{:<2d}: 0] oe{:d};'.format(lg2_oesm[idx0]-1, idx0), file=fp)
  print(    '', file=fp)
  for idx0 in range(round_oe):
    print(  '  assign even{:d} = '.format(idx0), end='', file=fp)
    for idx1 in range(evenbit[idx0]):
      if(idx1 != 0):
        print(' + ', end='', file=fp)
      if(idx0 == 0):
        bitstr = 'addr[{}]'
      else:
        bitstr = 'oe{}[{{}}]'.format(idx0-1)
      print(bitstr.format(2*idx1), end='', file=fp)
    print(  ';', file=fp)
    print(  '  assign odd{:d} = '.format(idx0), end='', file=fp)
    for idx1 in range(oddbit[idx0]):
      if(idx1 != 0):
        print(' + ', end='', file=fp)
      if(idx0 == 0):
        bitstr = 'addr[{}]'
      else:
        bitstr = 'oe{}[{{}}]'.format(idx0-1)
      print(bitstr.format(2*idx1+1), end='', file=fp)
    print(  ';', file=fp)
    print(  '', file=fp)
    print(  '  always @ ( posedge clk ) begin', file=fp)
    print(  '    oe{idx} <= {{odd{idx}, 1\'b0}} + even{idx};'.format(idx=idx0), file=fp)
    print(  '  end', file=fp)
    print(  '', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    case(oe{})'.format(round_oe-1), file=fp)
  for idx0 in range(oesummax[round_oe-1]+1):
    print(  '      {loesm:d}\'d{idx:<2d}:   Out <= \'d{residue};'.format(loesm=lg2_oesm[round_oe-1],idx=idx0,residue=idx0 % 3), file=fp)
  print(    '      default: Out <= \'d0;', file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    'endmodule', file=fp)
  print(    '', file=fp)

  print(    'module good3_addr_gen ( clk, y_deg, in_good, out_good0, out_good1, acc_ctrl );', file=fp)
  print(    '', file=fp)
  print(    '  input            clk;',file=fp)
  print(    '  input      [1:0] y_deg;',file=fp)
  print(    '  input      [1:0] in_good;', file=fp)
  print(    '  output reg [1:0] out_good0;', file=fp)
  print(    '  output reg [1:0] out_good1;', file=fp)
  print(    '  output reg       acc_ctrl;', file=fp)
  print(    '', file=fp)
  print(    '  wire             in_good_reset;',file=fp)
  print(    '  assign in_good_reset = (in_good == 2\'d0);', file=fp)
  print(    '', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    out_good0 <= in_good;', file=fp)
  print(    '    case(y_deg)', file=fp)
  print(    '      2\'d1:    begin', file=fp)
  print(    '        out_good1 <= { in_good[1], in_good[1] ^ (!in_good[0]) } ;', file=fp)
  print(    '      end', file=fp)
  print(    '      2\'d2:    begin', file=fp)
  print(    '        out_good1 <= { (!in_good[1]) & (!in_good[0]), in_good[0] } ;',file=fp)
  print(    '      end', file=fp)
  print(    '      default: begin // 2\'d0', file=fp)
  print(    '        out_good1 <= in_good_reset ? 2\'d0 : { !in_good[1], !in_good[0] } ;', file=fp)
  print(    '      end', file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    acc_ctrl <= !in_good_reset;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    'endmodule', file=fp)
  print(    '', file=fp)

  return round_oe + 1


# ----- bfu generator
def bfu_gen(fp, qi, lg2_qi, lg2_2qi, lg2_wmax):
  lg2_bw = lg2_qi + lg2_wmax - 1
  qi_div2 = int((qi-1) >> 1)

  print(  'module bfu_{} ( clk, state, acc, in_a, in_b, w, bw, out_a, out_b );'.format(qi), file=fp)
  print(  '', file=fp)
  print(  '  input                      clk;', file=fp)
  print(  '  input                      state;', file=fp)
  print(  '  input                      acc;', file=fp)
  print(  '  input      signed [{:<2d} : 0] in_a;'.format(lg2_qi-1), file=fp)
  print(  '  input      signed [{:<2d} : 0] in_b;'.format(lg2_qi-1), file=fp)
  print(  '  input      signed [{:<2d} : 0] w;'.format(lg2_wmax-1), file=fp)
  print(  '  output reg signed [{:<2d} : 0] bw;'.format(lg2_bw-1), file=fp)
  print(  '  output reg signed [{:<2d} : 0] out_a;'.format(lg2_qi-1), file=fp)
  print(  '  output reg signed [{:<2d} : 0] out_b;'.format(lg2_qi-1), file=fp)
  print(  '', file=fp)
  print(  '  wire signed       [{:<2d} : 0] mod_bw;'.format(lg2_qi-1), file=fp)
  print(  '  reg signed        [{:<2d} : 0] a, b;'.format(lg2_qi+1), file=fp)
  print(  '  reg signed        [{:<2d} : 0] in_a_s1, in_a_s2, in_a_s3, in_a_s4, in_a_s5;'.format(lg2_qi-1), file=fp)
  print(  '', file=fp)
  print(  '  wire signed       [{:<2d} : 0] a_mux;'.format(lg2_qi), file=fp)
  print(  '  reg signed        [{:<2d} : 0] bwQ_0, bwQ_1, bwQ_2;'.format(lg2_bw-1), file=fp)
  print(  '  wire signed       [{:<2d} : 0] a_add_q, a_sub_q, b_add_q, b_sub_q;'.format(lg2_qi), file=fp)
  print(  '', file=fp)
  print(  '  mod{qi:d}SS{bws:d} mod{qi:d}s_inst ( clk, 1\'b0, bw, mod_bw );'.format(qi=qi, bws=lg2_bw), file=fp)
  print(  '', file=fp)
  print(  '  assign a_add_q = a + \'sd{};'.format(qi), file=fp)
  print(  '  assign a_sub_q = a - \'sd{};'.format(qi), file=fp)
  print(  '  assign b_add_q = b + \'sd{};'.format(qi), file=fp)
  print(  '  assign b_sub_q = b - \'sd{};'.format(qi), file=fp)
  print(  '', file=fp)
  print(  '  assign a_mux = acc ? a : in_a_s4;', file=fp)
  print(  '', file=fp)
  print(  '  always @(posedge clk ) begin', file=fp)
  print(  '    in_a_s1 <= in_a;', file=fp)
  print(  '    in_a_s2 <= in_a_s1;', file=fp)
  print(  '    in_a_s3 <= in_a_s2;', file=fp)
  print(  '    in_a_s4 <= in_a_s3;', file=fp)
  print(  '    in_a_s5 <= in_a_s4;', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)
  print(  '  always @ ( posedge clk ) begin', file=fp)
  print(  '    bw <= in_b * w;', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)
  print(  '  always @ ( posedge clk ) begin', file=fp)
  print(  '    a <= a_mux + mod_bw;', file=fp)
  print(  '    b <= a_mux - mod_bw;', file=fp)
  print(  '', file=fp)
  print(  '    if (state == 0) begin', file=fp)
  print(  '      if (a > \'sd{}) begin'.format(qi_div2), file=fp)
  print(  '        out_a <= a_sub_q;', file=fp)
  print(  '      end else if (a < -\'sd{}) begin'.format(qi_div2), file=fp)
  print(  '        out_a <= a_add_q;', file=fp)
  print(  '      end else begin', file=fp)
  print(  '        out_a <= a;', file=fp)
  print(  '      end', file=fp)
  print(  '    end else begin', file=fp)
  print(  '      if (a[0] == 0) begin', file=fp)
  print(  '        out_a <= a[{}:1];'.format(lg2_qi), file=fp)
  print(  '      end else if (a[{:2d}] == 0) begin // a > 0'.format(lg2_qi), file=fp)
  print(  '        out_a <= a_sub_q[{}:1];'.format(lg2_qi), file=fp)
  print(  '      end else begin                 // a < 0', file=fp)
  print(  '        out_a <= a_add_q[{}:1];'.format(lg2_qi), file=fp)
  print(  '      end', file=fp)
  print(  '    end', file=fp)
  print(  '', file=fp)
  print(  '    if (state == 0) begin', file=fp)
  print(  '      if (b > \'sd{}) begin'.format(qi_div2), file=fp)
  print(  '        out_b <= b_sub_q;', file=fp)
  print(  '      end else if (b < -\'sd{}) begin'.format(qi_div2), file=fp)
  print(  '        out_b <= b_add_q;', file=fp)
  print(  '      end else begin', file=fp)
  print(  '        out_b <= b;', file=fp)
  print(  '      end', file=fp)
  print(  '    end else begin', file=fp)
  print(  '      if (b[0] == 0) begin', file=fp)
  print(  '        out_b <= b[{}:1];'.format(lg2_qi), file=fp)
  print(  '      end else if (b[{:2d}] == 0) begin // b > 0'.format(lg2_qi), file=fp)
  print(  '        out_b <= b_sub_q[{}:1];'.format(lg2_qi), file=fp)
  print(  '      end else begin                 // b < 0', file=fp)
  print(  '        out_b <= b_add_q[{}:1];'.format(lg2_qi), file=fp)
  print(  '      end', file=fp)
  print(  '    end', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)
  print(  'endmodule', file=fp)
  print(  '', file=fp)

  return


# ----- w_addr_gen generator
def waddrgen_gen(fp, aw):

  print(  'module w_addr_gen ( clk, stage_bit, ctr, w_addr );', file=fp)
  print(  '', file=fp)
  print(  '  input              clk;', file=fp)
  print(  '  input      [{:2d}: 0] stage_bit;'.format(aw-2), file=fp)
  print(  '  input      [{:2d}: 0] ctr;'.format(aw-2), file=fp)
  print(  '  output reg [{:2d}: 0] w_addr;'.format(aw-2), file=fp)
  print(  '', file=fp)
  print(  '  wire [{:2d}: 0] w;'.format(aw-2), file=fp)
  print(  '', file=fp)
  for idx in range(aw-1):
    print('  assign w[{idx:2d}] = (stage_bit[{idx:2d}]) ? ctr[{idx:2d}] : 0;'.format(idx=idx), file=fp)
  print(  '', file=fp)
  print(  '  always @ ( posedge clk ) begin', file=fp)

  print(  '    w_addr <= {', end='', file=fp)
  for idx in range(aw-1):
    if(idx != 0):
      print(', ', end='', file=fp)
    print(  'w[{}]'.format(idx), end='', file=fp)
  print(    '};', file=fp)

  print(  '  end', file=fp)
  print(  '', file=fp)
  print(  'endmodule', file=fp)
  print(  '', file=fp)

  return 


# ----- polynomial address generator
def addrgen_gen(fp, aw):
  lg2_aw = int(math.ceil(math.log2(aw)))

  print(  'module addr_gen ( clk, stage, ctr, bank_index, data_index );', file=fp)
  print(  '', file=fp)
  print(  '  input              clk;', file=fp)
  print(  '  input      [{:<2d}: 0] stage;'.format(lg2_aw-1), file=fp)
  print(  '  input      [{:<2d}: 0] ctr;'.format(aw-1), file=fp)
  print(  '  output reg         bank_index;', file=fp)
  print(  '  output reg [{:<2d}: 0] data_index;'.format(aw-2), file=fp)
  print(  '', file=fp)
  print(  '  wire       [{:<2d}: 0] bs_out;'.format(aw-1), file=fp)
  print(  '', file=fp)
  print(  '  barrel_shifter bs ( clk, ctr, stage, bs_out );', file=fp)
  print(  '', file=fp)
  print(  '    always @( posedge clk ) begin', file=fp)
  print(  '        bank_index <= ^bs_out;', file=fp)
  print(  '    end', file=fp)
  print(  '', file=fp)
  print(  '    always @( posedge clk ) begin', file=fp)
  print(  '        data_index <= bs_out[{:d}:1];'.format(aw-1), file=fp)
  print(  '    end', file=fp)
  print(  '', file=fp)
  print(  'endmodule', file=fp)
  print(  '', file=fp)

  return


# ----- Barrel shifter module generator
def bshift_gen(fp, dw):
  lg2_dw = int(math.ceil(math.log2(dw)))

  print(    'module barrel_shifter ( clk, in, shift, out );', file=fp)
  print(    '', file=fp)
  print(    '  input              clk;', file=fp)
  print(    '  input      [{:<2d}: 0] in;'.format(dw-1), file=fp)
  print(    '  input      [{:<2d}: 0] shift;'.format(lg2_dw-1), file=fp)
  print(    '  output reg [{:<2d}: 0] out;'.format(dw-1), file=fp)
  print(    '', file=fp)
  print(    '  reg        [{:<2d}: 0] in_s [0:{:d}];'.format(dw-1, lg2_dw), file=fp)
  print(    '', file=fp)
  print(    '  always @ (*) begin', file=fp)
  print(    '    in_s[0] = in;', file=fp)
  print(    '  end', file=fp) 
  print(    '', file=fp)
  for idx in range(lg2_dw):
    lsb = int(pow(2, idx) - 1)
    print(  '  always @ (*) begin', file=fp)
    print(  '    if(shift[{}]) begin'.format(idx), file=fp)
    if(lsb == 0):
      print('      in_s[{a}] = {{ in_s[{b}][0], in_s[{b}][{d}:1] }};'.format(a=idx+1, b=idx, d=dw-1), file=fp)
    elif(lsb == dw-2):
      print('      in_s[{a}] = {{ in_s[{b}][{d1}:0], in_s[{b}][{dM}] }};'.format(a=idx+1, b=idx, d1=lsb, dM=dw-1), file=fp)
    else:
      print('      in_s[{a}] = {{ in_s[{b}][{d1}:0], in_s[{b}][{dM}:{d2}] }};'.format(a=idx+1, b=idx, d1=lsb, dM=dw-1, d2=lsb+1), file=fp)
    print(  '    end else begin', file=fp)
    print(  '      in_s[{a}] = in_s[{b}];'.format(a=idx+1, b=idx), file=fp)
    print(  '    end', file=fp)
    print(  '  end', file=fp)
    print(  '', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    out <= in_s[{:d}];'.format(lg2_dw), file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    'endmodule', file=fp)
  print(    '', file=fp)

  return


# ----- Omega array generator
def w_array_gen(fp, q, lg2_q):
  global p_g_cover, lg2_pgc
  gen = find_gen(q, p_g_cover)

  print(    'module w_{} ( clk, addr, dout );'.format(q), file=fp)
  print(    '', file=fp)
  print(    '  input                       clk;', file=fp)
  print(    '  input             [{:2d} : 0]  addr;'.format(lg2_pgc-1), file=fp)
  print(    '  output signed     [{:2d} : 0]  dout;'.format(lg2_q-1), file=fp)
  print(    '', file=fp)
  print(    '  wire signed       [{:2d} : 0]  dout_p;'.format(lg2_q-1), file=fp)
  print(    '  wire signed       [{:2d} : 0]  dout_n;'.format(lg2_q-1), file=fp)
  print(    '  reg               [{:2d} : 0]  addr_reg;'.format(lg2_pgc-1), file=fp)
  print(    '', file=fp)
  if(lg2_pgc > 9):
    print(  '  (* rom_style = "block" *) reg signed [{:d}:0] data [0:{:d}];'.format(lg2_q-1,(p_g_cover>>1)-1), file=fp)
  else:
    print(  '  (* rom_style = "distributed" *) reg signed [{:d}:0] data [0:{:d}];'.format(lg2_q-1,(p_g_cover>>1)-1), file=fp)
  print(    '', file=fp)
  if(lg2_pgc == 2):
    print(  '  assign dout_p = data[addr_reg[0]];', file=fp)
  else:
    print(  '  assign dout_p = data[addr_reg[{}:0]];'.format(lg2_pgc-2), file=fp)
  print(    '  assign dout_n = -dout_p;', file=fp)
  print(    '  assign dout   = addr_reg[{}] ? dout_n : dout_p;'.format(lg2_pgc-1), file=fp)
  print(    '', file=fp)
  print(    '  always @ ( posedge clk ) begin', file=fp)
  print(    '    addr_reg <= addr;', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    '  initial begin', file=fp)
  xlen = int(math.ceil(math.log10((p_g_cover>>1) + 1)))
  pstr =    '    data[{{:{:d}d}}] =  \'sd{{:d}};'.format(xlen)
  nstr =    '    data[{{:{:d}d}}] = -\'sd{{:d}};'.format(xlen)
  for idx in range(p_g_cover>>1):
    v = pow(gen, idx, q)
    if v > ((q-1) >> 1): v -= q
    if(v >= 0):
      print(pstr.format(idx, v), file=fp)
    else:
      print(nstr.format(idx, -v), file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)
  print(    'endmodule', file=fp)
  print(    '', file=fp)

  return


# ----- Full generator of NTT modules
def NTT_RTLGen():
  global ntt_modulename, p, p_cover, lg2_pc, p_g_cover, lg2_pgc, q0, lg2_q0, lg2_2q0, qs, lg2_qs, lg2_2qs, qs_inv, qs_else, lg2_wmax, goodfactor

  ntt_modulename = NTTModulenameGen()

  fp = open(ntt_modulename + '.v', 'w')
  # fp = None

  print('Generating NTT modules to file "{}"...'.format(ntt_modulename + '.v'))

  if(goodfactor == 3):
    mod3_delay = mod3_gen(fp, lg2_pc)
  ntt_top_gen(fp, mod3_delay)
  waddrgen_gen(fp, lg2_pgc)
  addrgen_gen(fp, lg2_pgc)
  bshift_gen(fp, lg2_pgc)

  if(len(qs) == 0):
    bfu_gen(fp, q0, lg2_q0, lg2_2q0, lg2_wmax)
    w_array_gen(fp, q0, lg2_q0)
  else:
    for (qi, lg2_qi, lg2_2qi) in zip(qs, lg2_qs, lg2_2qs):
      bfu_gen(fp, qi, lg2_qi, lg2_2qi, lg2_wmax)
      w_array_gen(fp, qi, lg2_qi)

  return


# ----- main function
def __main__():
  global p, q0, qs

  parser = argparse.ArgumentParser(description='')
  parser.add_argument('-p', '--psize', metavar='p', type=int, required=True, default=256, help='point size of NTT, larger than 4.')
  parser.add_argument('-q0', '--primeQ', metavar='q0', type=int, required=True, default=7681, help='prime number Q.')
  parser.add_argument('-qs', '--crtQ', metavar='qs', type=int, nargs='*', help='NTT friendly prime numbers Qs for CRT. Only if q0 is not friendly.')

  args = parser.parse_args()

  p = args.psize
  q0 = args.primeQ
  qs = [] if args.crtQ == None else sorted(args.crtQ)

  if(not NTTCheckFriendly()):
    parser.print_help()
    return

  NTT_RTLGen()
  return


# ----- run main function
__main__()

