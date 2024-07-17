#!/usr/bin/sage -python
######!/usr/bin/env python3

from sage.all import *
import argparse
import json
import pathlib
import random
#from datetime import datetime

ERR_MSG_INVALIDJSON         = 'Invalid json file name'

# ----- RNG Seeding
seed       = 1
# seed       = datetime.now() # pyhton3 old version only
# seed       = None
random.seed(seed)

# ----- Primitive Finder
def find_gen(q, rN):
  for gen in range(2, q):
    if(pow(gen, rN >> 1, q) == q - 1):
      break
  return gen


# ----- polynomial verilog file management
tbfile = 'test_data.v'

def open_verilog():
  global fp
  fp = open(tbfile, 'w')
  return

def close_verilog():
  global fp
  fp.close()
  return


# ----- p/pc/pc2/lg2_pc2/q0/qs
p          = 653
pc         = 768
pc2        = 1536
lg2_pc     = 10
lg2_pc2    = 11
q0         = 4621
lg2_q0     = 13

goodfactor = 3
pg_c       = 256
pg_c2      = 512
lg2_pgc    = 8
lg2_pgc2   = 9
qs         = [7681, 12289, 15361]
# qs         = [114689, 120833]

# ----- Argument Parser
# parser = argparse.ArgumentParser(description='Good Trick for NTRU Prime 761 Test Data Generator')
parser = argparse.ArgumentParser(description='Good Trick NTT with 3 pcs Test Data Generator')
# parser.add_argument('-v', '--tbverilog', metavar='v', type=pathlib.Path, default='test_data.v', help='Output verilog test data rom file.')
parser.add_argument('-j', '--json', metavar='j', type=pathlib.Path, required=False, help='Input JSON file for non-random test data.')
# parser.add_argument('-qs', '--crtQ', metavar='qs', type=int, nargs='*', default=qs, help='NTT friendly prime numbers Qs for CRT.') 
parser.add_argument('-p', '--psize', metavar='p', type=int, required=True, default=653, help='Polynomial size, larger than 12.')
parser.add_argument('-q0', '--primeQ', metavar='q0', type=int, required=True, default=4621, help='prime number Q.')
parser.add_argument('-qs', '--crtQ', metavar='qs', type=int, nargs='*', help='NTT friendly prime numbers Qs for CRT. Only if q0 is not friendly.')
parser.add_argument('-o', '--output', metavar='o', type=pathlib.Path, default='test_data.v', help='Output verilog test data rom file.')

args = parser.parse_args()

p         = args.psize
lg2_pgc   = int(math.ceil(math.log2(p // goodfactor)))
lg2_pgc2  = lg2_pgc + 1
pg_c      = (1 << lg2_pgc)
pg_c2     = (1 << lg2_pgc2)
pc        = pg_c * goodfactor
lg2_pc    = int(math.ceil(math.log2(pc)))
pc2       = pc * 2
lg2_pc2   = int(math.ceil(math.log2(pc2)))


q0        = args.primeQ
assert is_prime(q0)
lg2_q0    = int(math.ceil(math.log2(q0)))
tbfile    = args.output
jsonfile  = args.json
qs = sorted(args.crtQ)

assert len(qs) <= 3
for qi in qs:
  assert is_prime(qi)

# ----- q0 fields / rings definition
Zx      = ZZ['x'] ; Zx.inject_variables(verbose=False)
R       = Zx.quotient(x ** pc2 - Integer(1), names=('xp',)) ; R.inject_variables(verbose=False)
R0      = Zx.quotient(x ** p - x - Integer(1), names=('x0',)) ; R0.inject_variables(verbose=False)
Rg      = Zx.quotient(x ** pg_c2 - Integer(1), names=('xg',)) ; Rg.inject_variables(verbose=False)

Fq      = GF(q0)
Fqx     = Fq['xq'] ; Fqx.inject_variables(verbose=False)
Rq      = Fqx.quotient(xq ** p - xq - Integer(1), names=('xqp',)) ; Rq.inject_variables(verbose=False)

qALL         = reduce(lambda x, y: x*y, qs, 1)
q0_div2      = ZZ((q0  -1)/2)
qALL_div2    = ZZ((qALL-1)/2)
qs_div2      = [ZZ((qi - 1)/2) for qi in qs]
qA_qs_inv    = [inverse_mod(qALL // qi, qi) for qi in qs]
qs_primitive = [find_gen(qi, pg_c2) for qi in qs]

# ----- higher-level randomness
def randomq():
  return random.randrange(q0)

def urandom32():
  c0 = random8()
  c1 = random8()
  c2 = random8()
  c3 = random8()
  return c0 + 256*c1 + 65536*c2 + 16777216*c3

def randomrange3():
  return ((urandom32() & 0x3fffffff) * 3) >> 30

def random_polyq():
  r = R0([randomq()-q0_div2 for i in range(p)])
  return r

def random_small():
  r = R0([randomrange3()-1 for i in range(p)])
  return r

# ----- Specified F and G
def special_f():
  r = R0([1 - int(mod(i, 3)) for i in range(p)])
  return r

def special_g():
  r = R0([2 - int(mod(i, 5)) for i in range(p)])
  return r

# ----- arithmetic mod q
def ZZ_fromFq(c):
  assert c in Fq
  return ZZ(c+q0_div2)-q0_div2

def R_fromRq(r):
  assert r in Rq
  return R([ZZ_fromFq(r[i]) for i in range(pc2)])

def Rq_fromR(r):
  assert r in R
  return Rq([r[i] for i in range(pc2)])

def Rq_fromR0(r):
  assert r in R0
  return Rq([r[i] for i in range(p)])

def R0_fromRq(r):
  assert r in Rq
  return R0([ZZ_fromFq(r[i]) for i in range(p)])

for idx, (qi, qi_primitive) in enumerate(zip(qs, qs_primitive)):
  # ----- qi fields / rings definition
  gen_str = ''
  gen_str += 'Fq{idx:d} = GF({qi:d})\n'.format(idx=idx+1, qi=int(qi))
  gen_str += 'Fq{idx:d}x = Fq{idx:d}[\'xq{idx:d}\'] ; Fq{idx:d}x.inject_variables(verbose=False)\n'.format(idx=idx+1)
  gen_str += 'Rq{idx:d} = Fq{idx:d}x.quotient(xq{idx:d} ** pg_c2 - Integer(1), names=(\'xq{idx:d}p\',)) ; Fq{idx:d}x.inject_variables(verbose=False)\n'.format(idx=idx+1)
  exec(gen_str, globals())

  # ----- omega_qi generator
  gen_str = ''
  gen_str += 'omega_q{idx:d} = range(pc)\n'.format(idx=idx+1)
  gen_str += 'omega_q{idx:d} = [Fq{idx:d}(pow({qi_pri:d}, omega)) for omega in omega_q{idx:d}]\n'.format(idx=idx+1, qi_pri=qi_primitive)
  gen_str += 'omega_q{idx:d} += [-omega for omega in omega_q{idx:d}]\n'.format(idx=idx+1)
  exec(gen_str, globals())

  # ----- arithmetic mod qi
  gen_str = ''
  gen_str += 'def ZZ_fromFq{idx:d}(c):\n'.format(idx=idx+1)
  gen_str += '  assert c in Fq{idx:d}\n'.format(idx=idx+1)
  gen_str += '  return ZZ(c+qs_div2[{idxm:d}])-qs_div2[{idxm:d}]\n'.format(idx=idx+1, idxm=idx)
  gen_str += '\n'
  gen_str += 'def Zx_fromFq{idx:d}x(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in Fq{idx:d}x\n'.format(idx=idx+1)
  gen_str += '  return Zx([ZZ_fromFq{idx:d}(r[i]) for i in range(2*p)])\n'.format(idx=idx+1)
  gen_str += '\n'
  gen_str += 'def Rg_fromRq{idx:d}(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in Rq{idx:d}\n'.format(idx=idx+1)
  gen_str += '  return Rg([ZZ_fromFq{idx:d}(r[i]) for i in range(p)])\n'.format(idx=idx+1)
  gen_str += '\n'
  gen_str += 'def Rq{idx:d}_fromRg(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in Rg\n'.format(idx=idx+1)
  gen_str += '  return Rq{idx:d}([r[i] for i in range(p)])\n'.format(idx=idx+1)
  gen_str += '\n'
  gen_str += 'def Fq{idx:d}x_fromRg(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in Rg\n'.format(idx=idx+1)
  gen_str += '  return Fq{idx:d}x([r[i] for i in range(p)])\n'.format(idx=idx+1)
  gen_str += '\n'
  gen_str += 'def Red_fromFq{idx:d}x(r, n, omega):\n'.format(idx=idx+1)
  gen_str += '  assert r in Fq{idx:d}x\n'.format(idx=idx+1)
  gen_str += '  assert r.degree() < 2*n\n'.format(idx=idx+1)
  gen_str += '  assert omega in Fq{idx:d}\n'.format(idx=idx+1)
  gen_str += '  return Fq{idx:d}x([r[i]+r[i+n]*omega for i in range(n)])\n'.format(idx=idx+1)
  exec(gen_str, globals())

# ----- Functions and Rings
gen_str = ''
gen_str +=     'def Q_Funcs(q):\n'
if(len(qs) == 1):
  gen_str +=   '  return ZZ_fromFq1, Zx_fromFq1x, Rg_fromRq1, Rq1_fromRg, Fq1x_fromRg, Red_fromFq1x\n'
else:
  for idx, qi in enumerate(qs):
    if(idx == 0):
      gen_str += '  if '
    elif(idx != len(qs)-1):
      gen_str += '  elif '
    else:
      gen_str += '  else: # '
    gen_str += '(q == {qi:d}):\n'.format(qi=qi)
    gen_str += '    return ZZ_fromFq{idx:d}, Zx_fromFq{idx:d}x, Rg_fromRq{idx:d}, Rq{idx:d}_fromRg, Fq{idx:d}x_fromRg, Red_fromFq{idx:d}x\n'.format(idx=idx+1)
exec(gen_str, globals())

gen_str = ''
gen_str +=     'def Q_Rings(q):\n'
if(len(qs) == 1):
  gen_str +=   '  return Fq1, Fq1x, xq1, Rq1, omega_q1\n'
else:
  for idx, qi in enumerate(qs):
    if(idx == 0):
      gen_str += '  if '
    elif(idx != len(qs)-1):
      gen_str += '  elif '
    else:
      gen_str += '  else: # '
    gen_str += '(q == {qi:d}):\n'.format(qi=qi)
    gen_str += '    return Fq{idx:d}, Fq{idx:d}x, xq{idx:d}, Rq{idx:d}, omega_q{idx:d}\n'.format(idx=idx+1)
exec(gen_str, globals())


# ----- arithmetic in Z
def Zx_fromFqx(r):
  assert r in Fqx
  return Zx([ZZ_fromFq(r[i]) for i in range(2*p)])

def Fqx_fromR(r):
  assert r in R
  return Fqx([r[i] for i in range(p)])


# ----- Bit Reversal
def bitrev(x, n):
  assert x < pow(2, n)
  y = 0
  for idx in range(n):
    y = (y << 1) + (x % 2)
    x >>= 1
  return y


# ----- Decomposition with Good's Trick
def GOODDecomposite(r):
  assert r in R0
  r_good = []
  for idx in range(goodfactor):
    if(mod(pg_c2 * idx + 1, goodfactor) == 0):
      zinc = pg_c2 * idx + 1
      break
  for idx in range(goodfactor):
    if(mod(pg_c2 * idx, goodfactor) == 1):
      yinc = pg_c2 * idx
      break
  for idx in range(goodfactor):
    r_gitem = R([r[ int(mod(zinc*i + yinc*idx, goodfactor*pg_c2))  ] for i in range(pg_c2)])
    r_good.append(r_gitem)
  return r_good


# ----- Composition with Good's Trick
def GoodComposite(r, qi):
  assert len(r) == goodfactor
  assert qi in qs or qi == q0

  if(qi == q0):
    for r_item in r:
      assert r_item in Fqx
  else:
    ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
    Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)
    for r_item in r:
      assert r_item in Fqix

  r_good = R([r[int(i % goodfactor)][int(i % pg_c2)] for i in range(pc2)])

  return r_good


# ----- Polynomial Decomposition in NTT
def NTTDecomposite(r, qi):
  assert r in Rg
  assert qi in qs

  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  r_qi = []
  r_qi_stage_before = [Fqix_fromR(r)]
  r_qi.append(r_qi_stage_before)
  for idx in range(lg2_pgc2):
    # w_idx_b = 1 << (lg2_pgc2-1-idx) # type 1: omega^pg_c2 style
    r_qi_stage = []
    for idxF, r_before in enumerate(r_qi_stage_before):
      # w_idx_o = w_idx_b if idx == 0 else (bitrev(idxF, idx) << (lg2_pgc2-1-idx)) + w_idx_b # type 1: omega^pg_c2 style
      w_idx_o = 0 if idx == 0 else (bitrev(idxF, idx) << (lg2_pgc2-1-idx)) # type 2: omega^0 style
      r_qi_term = Red_fromFqix(r_before, pg_c//(1 << idx),  omega_qi[w_idx_o]); r_qi_stage.append(r_qi_term)
      r_qi_term = Red_fromFqix(r_before, pg_c//(1 << idx), -omega_qi[w_idx_o]); r_qi_stage.append(r_qi_term)
    r_qi.append(r_qi_stage)
    r_qi_stage_before = r_qi_stage

  return r_qi


# ----- Polynomial Vector Multiplication with Good's Trick
def NTTGoodMult(f_good, g_good, qi):
  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  h_good = []

  for idxI in range(goodfactor):
    for idxJ in range(goodfactor):
      idxK = (idxI + goodfactor - idxJ) % goodfactor
      h_item = NTTMult(f_good[idxJ], g_good[idxK], qi)
      if(idxJ == 0):
        h_sum = h_item
      else:
        h_sum = NTTAdd(h_sum, h_item, qi)
    h_good.append(h_sum)

  return h_good


# ----- Polynomial Addition in NTT Domain
def NTTAdd(f_qi, g_qi, qi):
  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  assert len(f_qi) == len(g_qi)
  for (f_qi_stage, g_qi_stage) in zip(f_qi, g_qi):
    assert len(f_qi_stage) == len(g_qi_stage)
    for (f_qi_poly, g_qi_poly) in zip(f_qi_stage, g_qi_stage):
      assert f_qi_poly in Fqix
      assert g_qi_poly in Fqix

  h_qi = []

  for idx, (f_qi_stage, g_qi_stage) in enumerate(zip(f_qi, g_qi)):
    h_qi_stage = []
    for idxF, (f_qi_poly, g_qi_poly) in enumerate(zip(f_qi_stage, g_qi_stage)):
      h_qi_poly = Red_fromFqix(f_qi_poly + g_qi_poly, pg_c2, 1)
      h_qi_stage.append(h_qi_poly)
    h_qi.append(h_qi_stage)

  return h_qi


# ----- Polynomial Multiplication with NTT
def NTTMult(f_qi, g_qi, qi):
  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  assert len(f_qi) == len(g_qi)
  for (f_qi_stage, g_qi_stage) in zip(f_qi, g_qi):
    assert len(f_qi_stage) == len(g_qi_stage)
    for (f_qi_poly, g_qi_poly) in zip(f_qi_stage, g_qi_stage):
      assert f_qi_poly in Fqix
      assert g_qi_poly in Fqix

  h_qi = []

  for idx, (f_qi_stage, g_qi_stage) in enumerate(zip(f_qi, g_qi)):
    # w_idx_b = 1 << (lg2_pc2-idx) # type 1
    h_qi_stage = []
    for idxF, (f_qi_poly, g_qi_poly) in enumerate(zip(f_qi_stage, g_qi_stage)):
      # w_idx_o = w_idx_b if idx == 0 else (bitrev(idxF, idx) << (lg2_pc2-idx)) + w_idx_b # type 1
      # w_idx_o = 0 if w_idx_o == pc2 else w_idx_o # type 1
      w_idx_o = 0 if idx == 0 else (bitrev(idxF, idx) << (lg2_pgc2-idx)) # type 2
      h_qi_poly = Red_fromFqix(f_qi_poly * g_qi_poly, pg_c2//(1 << idx), omega_qi[w_idx_o])
      h_qi_stage.append(h_qi_poly)
    h_qi.append(h_qi_stage)

  return h_qi


# ----- Assertion: each stage with NTT is OK
def NTTCompositeAssert(r_qi, qi):
  ZZ_fromFqi, Zx_fromFqix, Rg_fromRqi, Rqi_fromRg, Fqix_fromRg, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  for idx, r_qi_stage in enumerate(r_qi):
    if(idx == 0):
      r_qi_before = r_qi_stage
      continue
    # w_idx_b = 1 << (11-idx) # type 1
    assert len(r_qi_stage) == 2 * len(r_qi_before)
    for idxF in range(0, len(r_qi_stage), 2):
      # w_idx_o = w_idx_b if idx == 1 else (bitrev((idxF >> 1), idx-1) << (lg2_pg_c2-idx)) + w_idx_b # type 1
      # w_idx_o = 0 if w_idx_o == pg_c2 else pg_c2 - w_idx_o # type 1
      w_idx_o = 0 if idx == 1 else (bitrev((idxF >> 1), idx-1) << (lg2_pgc2-idx)) # type 2
      w_idx_o = 0 if w_idx_o == 0 else pc2 - w_idx_o # type 2
      r_qi_up = ((r_qi_stage[idxF] + r_qi_stage[idxF+1]) + \
                 (r_qi_stage[idxF] - r_qi_stage[idxF+1]) * (xqi ** (1 << (lg2_pgc2-idx))) * omega_qi[w_idx_o]) // 2
      assert r_qi_up == r_qi_before[idxF >> 1]
    r_qi_before = r_qi_stage

  return


# ----- polynomial output
def NTTDC_print(rname, r, qi):
  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  for idxL,r_i in enumerate(r):
    rnamestring = '{:s}({:d}) [{:d}] = '.format(rname, qi, idxL)
    print(rnamestring, end='')
    print_offset = 0
    for idxI,r_ii in enumerate(r_i):
      assert r_ii in Fqix
      r_iiZ = Zx_fromFqix(r_ii)
      # r_iiZ_list = [r_iiZ[idxZ] for idxZ in range(1 << (11 - idxL))]
      # print('{:s}_{:d} [{:d}][{:d}] = '.format(rname, qi, idxL, idxI), r_iiZ)
      print(' ( ', r_iiZ, ' ) ', end='')
      if(pg_c2 // (2 ** idxL) * (idxI + 1 - print_offset) >= 16):
        print_offset = idxI + 1
        print('')
        print(' '*len(rnamestring), end='')
      # print(r_iiZ_list, end='')
    print('')

  return


# ----- Fetch JSON file
def fetch_json():
  global jsonfile

  with jsonfile.open() as js_fd:
    testinfo = json.load(js_fd)
  return testinfo


# ----- Load / Generate polynomials
def load_polynomial():
  global jsonfile, h_ref

  if(jsonfile == None):
    f = random_polyq()
    # f = random_small()
    # f = special_f()
    g = random_polyq()
    # g = random_small()
    # g = special_g()
    h_ref = R_fromRq(Rq_fromR0(f) * Rq_fromR0(g))
  else:
    assert pathlib.Path(jsonfile).is_file(), ERR_MSG_INVALIDJSON
    testinfo = fetch_json()
    f = R0(testinfo['h'])
    g = R0(testinfo['r'])
    h_ref = R(testinfo['hr'])
    # f = R0(testinfo['g'])
    # g = R0(testinfo['1/3f'])
    # h_ref = R(testinfo['g/3f'])

  return (f, g)


# ----- polynomial output
def print_polynomial(r_module, r):
  global fp

  def vprint(*args, **kwargs):
    # nonlocal fp
    print(*args, file=fp, **kwargs)


  vprint(     'module {mname:s} ('.format(mname=r_module))
  vprint(     '  input                    clk,')
  vprint(     '  input                    rst,')
  vprint(     '  input             [{:2d}:0] addr,'.format(lg2_pc2-1))
  vprint(     '  output reg signed [{:2d}:0] dout'.format(lg2_q0-1))
  vprint(     ') ;')
  vprint(     '')
  vprint(     '  always @ (posedge clk) begin')
  vprint(     '    if(rst) begin')
  vprint(     '      dout <= \'sd0;')
  vprint(     '    end else begin')
  vprint(     '      case(addr)')

  for index,value in enumerate(r):
    if(value < 0):
      vprint( '        \'h{i:03x}: dout <= -\'sd{v:d}; // {i:d}'.format(i=index, v=-value))
    else:
      vprint( '        \'h{i:03x}: dout <=  \'sd{v:d}; // {i:d}'.format(i=index, v=value))

  vprint(     '        default: dout <= \'sd0;')
  vprint(     '      endcase')
  vprint(     '    end')
  vprint(     '  end')
  vprint(     '')
  vprint(     'endmodule')
  vprint(     '')


# ----- main
def __main__():
  global h_ref

  open_verilog()

  (f, g) = load_polynomial()

  f_good = GOODDecomposite(f)
  g_good = GOODDecomposite(g) 

  # print('f = ', f)
  # print('')
  # print('g = ', g)
  # print('')

  if (len(qs) == 3):

    f_good_q1 = []
    f_good_q2 = []
    f_good_q3 = []
    g_good_q1 = []
    g_good_q2 = []
    g_good_q3 = [] 

    for idx,(f_gitem,g_gitem) in enumerate(zip(f_good, g_good)):
      f_q1 = NTTDecomposite(f_gitem, qs[0])
      f_q2 = NTTDecomposite(f_gitem, qs[1])
      f_q3 = NTTDecomposite(f_gitem, qs[2])
      g_q1 = NTTDecomposite(g_gitem, qs[0])
      g_q2 = NTTDecomposite(g_gitem, qs[1])
      g_q3 = NTTDecomposite(g_gitem, qs[2])

      NTTCompositeAssert(f_q1, qs[0])
      NTTCompositeAssert(f_q2, qs[1])
      NTTCompositeAssert(f_q3, qs[2])
      NTTCompositeAssert(g_q1, qs[0])
      NTTCompositeAssert(g_q2, qs[1])
      NTTCompositeAssert(g_q3, qs[2])

      f_good_q1.append(f_q1)
      f_good_q2.append(f_q2)
      f_good_q3.append(f_q3)
      g_good_q1.append(g_q1)
      g_good_q2.append(g_q2)
      g_good_q3.append(g_q3)

    # NTT Mult Good3 
    h_good_q1 = NTTGoodMult(f_good_q1, g_good_q1, qs[0])
    h_good_q2 = NTTGoodMult(f_good_q2, g_good_q2, qs[1])
    h_good_q3 = NTTGoodMult(f_good_q3, g_good_q3, qs[2])

    h_good_crt = []

    for idx,(f_q1, f_q2, f_q3, g_q1, g_q2, g_q3, h_q1, h_q2, h_q3) in enumerate(zip(f_good_q1, f_good_q2, f_good_q3, g_good_q1, g_good_q2, g_good_q3, h_good_q1, h_good_q2, h_good_q3)):
      NTTCompositeAssert(h_q1, qs[0])
      NTTCompositeAssert(h_q2, qs[1])
      NTTCompositeAssert(h_q3, qs[2])

      # NTTDC_print('f_good_q1[{}]'.format(idx), f_q1, qs[0])
      # NTTDC_print('g_good_q1[{}]'.format(idx), g_q1, qs[0])
      # NTTDC_print('h_good_q1[{}]'.format(idx), h_q1, qs[0])

      # NTTDC_print('f_good_q2[{}]'.format(idx), f_q2, qs[1])
      # NTTDC_print('g_good_q2[{}]'.format(idx), g_q2, qs[1])
      # NTTDC_print('h_good_q2[{}]'.format(idx), h_q2, qs[1])

      # NTTDC_print('f_good_q3[{}]'.format(idx), f_q3, qs[2])
      # NTTDC_print('g_good_q3[{}]'.format(idx), g_q3, qs[2])
      # NTTDC_print('h_good_q3[{}]'.format(idx), h_q3, qs[2])

    for idx,(h_q1, h_q2, h_q3) in enumerate(zip(h_good_q1, h_good_q2, h_good_q3)):
      h_good_crt_item = [ZZ_fromFq1(mod(h_q1[0][0][i]*qA_qs_inv[0],qs[0])) * (qALL//qs[0]) + \
                         ZZ_fromFq2(mod(h_q2[0][0][i]*qA_qs_inv[1],qs[1])) * (qALL//qs[1]) + \
                         ZZ_fromFq3(mod(h_q3[0][0][i]*qA_qs_inv[2],qs[2])) * (qALL//qs[2]) for i in range(pg_c2)]
      h_good_crt_item = [h_good_crt_item[i] - qALL if h_good_crt_item[i] > (qALL-1)//2 else h_good_crt_item[i] + qALL if h_good_crt_item[i] < -(qALL-1)//2 else h_good_crt_item[i] for i in range(pg_c2)]
      h_good_crt_item = Zx_fromFqx(Fqx(h_good_crt_item))
      # print('h_good_crt[{:d}] = '.format(idx), h_good_crt_item)
      h_good_crt.append(h_good_crt_item)

    h_q1 = GoodComposite([h_good_q1[0][0][0], h_good_q1[1][0][0], h_good_q1[2][0][0]], qs[0])
    h_q1 = R([ZZ(Fq1(h_q1[i])+qs_div2[0])-qs_div2[0] for i in range(pc2)])
    h_q2 = GoodComposite([h_good_q2[0][0][0], h_good_q2[1][0][0], h_good_q2[2][0][0]], qs[1])
    h_q2 = R([ZZ(Fq2(h_q2[i])+qs_div2[1])-qs_div2[1] for i in range(pc2)])
    h_q3 = GoodComposite([h_good_q3[0][0][0], h_good_q3[1][0][0], h_good_q3[2][0][0]], qs[2])
    h_q3 = R([ZZ(Fq3(h_q3[i])+qs_div2[2])-qs_div2[2] for i in range(pc2)])

    # print('h_q1 = ', h_q1)
    # print('h_q2 = ', h_q2)
    # print('h_q3 = ', h_q3)

    h_crt = [ZZ_fromFq1(mod(h_q1[i]*qA_qs_inv[0],qs[0])) * (qALL//qs[0]) + \
             ZZ_fromFq2(mod(h_q2[i]*qA_qs_inv[1],qs[1])) * (qALL//qs[1]) + \
             ZZ_fromFq3(mod(h_q3[i]*qA_qs_inv[2],qs[2])) * (qALL//qs[2]) for i in range(2*pc)]
    h_crt = [h_crt[i] - qALL if h_crt[i] > (qALL-1)//2 else h_crt[i] + qALL if h_crt[i] < -(qALL-1)//2 else h_crt[i] for i in range(2*pc)]
    h_crt = Zx_fromFqx(Fqx(h_crt))
    h_red = R_fromRq(Rq(h_crt))

  else: # len(qs) == 2

    f_good_q1 = []
    f_good_q2 = []
    g_good_q1 = []
    g_good_q2 = []

    for idx,(f_gitem,g_gitem) in enumerate(zip(f_good, g_good)):
      f_q1 = NTTDecomposite(f_gitem, qs[0])
      f_q2 = NTTDecomposite(f_gitem, qs[1])
      g_q1 = NTTDecomposite(g_gitem, qs[0])
      g_q2 = NTTDecomposite(g_gitem, qs[1])

      NTTCompositeAssert(f_q1, qs[0])
      NTTCompositeAssert(f_q2, qs[1])
      NTTCompositeAssert(g_q1, qs[0])
      NTTCompositeAssert(g_q2, qs[1])

      f_good_q1.append(f_q1)
      f_good_q2.append(f_q2)
      g_good_q1.append(g_q1)
      g_good_q2.append(g_q2)

    # NTT Mult Good3 
    h_good_q1 = NTTGoodMult(f_good_q1, g_good_q1, qs[0])
    h_good_q2 = NTTGoodMult(f_good_q2, g_good_q2, qs[1])

    h_good_crt = []

    for idx,(f_q1, f_q2, g_q1, g_q2, h_q1, h_q2) in enumerate(zip(f_good_q1, f_good_q2, g_good_q1, g_good_q2, h_good_q1, h_good_q2)):
      NTTCompositeAssert(h_q1, qs[0])
      NTTCompositeAssert(h_q2, qs[1])

      NTTDC_print('f_good_q1[{}]'.format(idx), f_q1, qs[0])
      NTTDC_print('g_good_q1[{}]'.format(idx), g_q1, qs[0])
      NTTDC_print('h_good_q1[{}]'.format(idx), h_q1, qs[0])

      NTTDC_print('f_good_q2[{}]'.format(idx), f_q2, qs[1])
      NTTDC_print('g_good_q2[{}]'.format(idx), g_q2, qs[1])
      NTTDC_print('h_good_q2[{}]'.format(idx), h_q2, qs[1])

    for idx,(h_q1, h_q2) in enumerate(zip(h_good_q1, h_good_q2)):
      h_good_crt_item = [ZZ_fromFq1(mod(h_q1[0][0][i]*qA_qs_inv[0],qs[0])) * (qALL//qs[0]) + \
                         ZZ_fromFq2(mod(h_q2[0][0][i]*qA_qs_inv[1],qs[1])) * (qALL//qs[1]) for i in range(pg_c2)]
      h_good_crt_item = [h_good_crt_item[i] - qALL if h_good_crt_item[i] > (qALL-1)//2 else h_good_crt_item[i] + qALL if h_good_crt_item[i] < -(qALL-1)//2 else h_good_crt_item[i] for i in range(pg_c2)]
      h_good_crt_item = Zx_fromFqx(Fqx(h_good_crt_item))
      print('h_good_crt[{:d}] = '.format(idx), h_good_crt_item)
      h_good_crt.append(h_good_crt_item)

    h_q1 = GoodComposite([h_good_q1[0][0][0], h_good_q1[1][0][0], h_good_q1[2][0][0]], qs[0])
    h_q1 = R([ZZ(Fq1(h_q1[i])+qs_div2[0])-qs_div2[0] for i in range(pc2)])
    h_q2 = GoodComposite([h_good_q2[0][0][0], h_good_q2[1][0][0], h_good_q2[2][0][0]], qs[1])
    h_q2 = R([ZZ(Fq2(h_q2[i])+qs_div2[1])-qs_div2[1] for i in range(pc2)])

    print('h_q1 = ', h_q1)
    print('h_q2 = ', h_q2)

    h_crt = [ZZ_fromFq1(mod(h_q1[i]*qA_qs_inv[0],qs[0])) * (qALL//qs[0]) + \
             ZZ_fromFq2(mod(h_q2[i]*qA_qs_inv[1],qs[1])) * (qALL//qs[1]) for i in range(2*pc)]
    h_crt = [h_crt[i] - qALL if h_crt[i] > (qALL-1)//2 else h_crt[i] + qALL if h_crt[i] < -(qALL-1)//2 else h_crt[i] for i in range(2*pc)]
    h_crt = Zx_fromFqx(Fqx(h_crt))
    h_red = R_fromRq(Rq(h_crt))

  print('')
  print('h_crt = ', h_crt)
  print('')
  print('h_red = ', h_red)
  print('')
  print('h_ref = ', h_ref)
  hq0 = R0_fromRq(Rq_fromR0(f)*Rq_fromR0(g))
  # print('hq0 = ', hq0); print('')
  # 
  # assert hq0 == h_crt
  # 
  # h = Zx_fromFqx(Fqx_fromR0(f)*Fqx_fromR0(g))

  print_polynomial('f_rom', f)
  print_polynomial('g_rom', g)
  print_polynomial('h_rom', h_crt)
  print_polynomial('hp_rom', hq0)
  # # # print_polynomial('h_q1_rom', h_q1)
  # # # print_polynomial('h_q2_rom', h_q2)

  close_verilog()


__main__()



