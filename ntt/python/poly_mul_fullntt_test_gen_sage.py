#!/usr/bin/sage -python
######!/usr/bin/env python3

from sage.all import *
import argparse
import pathlib
import random
#from datetime import datetime

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
testdatafile = 'test_data.v'

def open_verilog():
  global fp
  fp = open(testdatafile, 'w')
  return

def close_verilog():
  global fp
  fp.close()
  return

# ----- A template of p/pc/pc2/lg2_pc2/q0/qs
p          = 1277
pc         = 2048
pc2        = 4096
lg2_pc2    = 12
q0         = 7879
qs         = [12289, 40961, 61441]

# ----- Argument Parser
parser = argparse.ArgumentParser(description='Full NTT Test Data Generator')
parser.add_argument('-p', '--psize', metavar='p', type=int, required=True, default=256, help='point size of NTT, larger than 4.')
parser.add_argument('-q0', '--primeQ', metavar='q0', type=int, required=True, default=7681, help='prime number Q.')
parser.add_argument('-qs', '--crtQ', metavar='qs', type=int, nargs='*', help='NTT friendly prime numbers Qs for CRT. Only if q0 is not friendly.')
parser.add_argument('-o', '--output', metavar='o', type=pathlib.Path, default='test_data.v', help='Output verilog test data rom file.')

args = parser.parse_args()
p = args.psize

lg2_pc2 = int(ceil(log(p, 2)) + 1)
pc = int(2 ** (lg2_pc2 - 1))
pc2 = int(pc * 2)
q0 = args.primeQ
qs = [q0] if args.crtQ == None else sorted(args.crtQ)

testdatafile = args.output

# ----- q0 fields / rings definition
Zx      = ZZ['x'] ; Zx.inject_variables(verbose=False)
R       = Zx.quotient(x ** pc2 - Integer(1), names=('xp',)) ; R.inject_variables(verbose=False)

Fq      = GF(q0)
Fqx     = Fq['xq'] ; Fqx.inject_variables(verbose=False)
Rq      = Fqx.quotient(xq ** p - xq - Integer(1), names=('xqp',)) ; Rq.inject_variables(verbose=False)

for qi in qs:
  assert is_prime(qi)

qALL         = reduce(lambda x, y: x*y, qs, 1)
q0_div2      = ZZ((q0  -1)/2)
qALL_div2    = ZZ((qALL-1)/2)
qs_div2      = [ZZ((qi - 1)/2) for qi in qs]
qA_qs_inv    = [inverse_mod(qALL // qi, qi) for qi in qs]
qs_primitive = [find_gen(qi, pc2) for qi in qs]

# lg2_2p is the same as lg2_pc2
lg2_q = ceil(log(max(qs),2))

# ----- PRNG
def random8():
  return random.randrange(256)

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
  r = R([randomq()-q0_div2 for i in range(p)])
  return r

def random_small():
  r = R([randomrange3()-1 for i in range(p)])
  return r

# ----- Specified F and G
def special_f():
  r = R([1 - int(mod(i, 3)) for i in range(p)])
  return r

def special_g():
  r = R([2 - int(mod(i, 5)) for i in range(p)])
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

for idx, (qi, qi_primitive) in enumerate(zip(qs, qs_primitive)):
  # ----- qi fields / rings definition
  gen_str = ''
  gen_str += 'Fq{idx:d} = GF({qi:d})\n'.format(idx=idx+1, qi=int(qi))
  gen_str += 'Fq{idx:d}x = Fq{idx:d}[\'xq{idx:d}\'] ; Fq{idx:d}x.inject_variables(verbose=False)\n'.format(idx=idx+1)
  gen_str += 'Rq{idx:d} = Fq{idx:d}x.quotient(xq{idx:d} ** pc2 - Integer(1), names=(\'xq{idx:d}p\',)) ; Fq{idx:d}x.inject_variables(verbose=False)\n'.format(idx=idx+1)
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
  gen_str += 'def R_fromRq{idx:d}(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in Rq{idx:d}\n'.format(idx=idx+1)
  gen_str += '  return R([ZZ_fromFq{idx:d}(r[i]) for i in range(p)])\n'.format(idx=idx+1)
  gen_str += '\n'
  gen_str += 'def Rq{idx:d}_fromR(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in R\n'.format(idx=idx+1)
  gen_str += '  return Rq{idx:d}([r[i] for i in range(p)])\n'.format(idx=idx+1)
  gen_str += '\n'
  gen_str += 'def Fq{idx:d}x_fromR(r):\n'.format(idx=idx+1)
  gen_str += '  assert r in R\n'.format(idx=idx+1)
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
  gen_str +=   '  return ZZ_fromFq1, Zx_fromFq1x, R_fromRq1, Rq1_fromR, Fq1x_fromR, Red_fromFq1x\n'
else:
  for idx, qi in enumerate(qs):
    if(idx == 0):
      gen_str += '  if '
    elif(idx != len(qs)-1):
      gen_str += '  elif '
    else:
      gen_str += '  else: # '
    gen_str += '(q == {qi:d}):\n'.format(qi=qi)
    gen_str += '    return ZZ_fromFq{idx:d}, Zx_fromFq{idx:d}x, R_fromRq{idx:d}, Rq{idx:d}_fromR, Fq{idx:d}x_fromR, Red_fromFq{idx:d}x\n'.format(idx=idx+1)
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


# ----- Polynomial Decomposition in NTT
def NTTDecomposite(r, qi):
  assert r in R
  assert qi in qs

  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  r_qi = []
  r_qi_stage_before = [Fqix_fromR(r)]
  r_qi.append(r_qi_stage_before)
  for idx in range(lg2_pc2):
    # w_idx_b = 1 << (lg2_pc2-1-idx) # type 1: omega^pc2 style
    r_qi_stage = []
    for idxF, r_before in enumerate(r_qi_stage_before):
      # w_idx_o = w_idx_b if idx == 0 else (bitrev(idxF, idx) << (lg2_pc2-1-idx)) + w_idx_b # type 1: omega^pc2 style
      w_idx_o = 0 if idx == 0 else (bitrev(idxF, idx) << (lg2_pc2-1-idx)) # type 2: omega^0 style
      r_qi_term = Red_fromFqix(r_before, pc//(1 << idx),  omega_qi[w_idx_o]); r_qi_stage.append(r_qi_term)
      r_qi_term = Red_fromFqix(r_before, pc//(1 << idx), -omega_qi[w_idx_o]); r_qi_stage.append(r_qi_term)
    r_qi.append(r_qi_stage)
    r_qi_stage_before = r_qi_stage

  return r_qi


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
      w_idx_o = 0 if idx == 0 else (bitrev(idxF, idx) << (lg2_pc2-idx)) # type 2
      h_qi_poly = Red_fromFqix(f_qi_poly * g_qi_poly, pc2//(1 << idx), omega_qi[w_idx_o])
      h_qi_stage.append(h_qi_poly)
    h_qi.append(h_qi_stage)

  return h_qi


# ----- Assertion: each stage with NTT is OK
def NTTCompositeAssert(r_qi, qi):
  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  for idx, r_qi_stage in enumerate(r_qi):
    if(idx == 0):
      r_qi_before = r_qi_stage
      continue
    # w_idx_b = 1 << (lg2_pc2-idx) # type 1
    assert len(r_qi_stage) == 2 * len(r_qi_before)
    for idxF in range(0, len(r_qi_stage), 2):
      # w_idx_o = w_idx_b if idx == 1 else (bitrev((idxF >> 1), idx-1) << (lg2_pc2-idx)) + w_idx_b # type 1
      # w_idx_o = 0 if w_idx_o == pc2 else pc2 - w_idx_o # type 1
      w_idx_o = 0 if idx == 1 else (bitrev((idxF >> 1), idx-1) << (lg2_pc2-idx)) # type 2
      w_idx_o = 0 if w_idx_o == 0 else pc2 - w_idx_o # type 2
      r_qi_up = ((r_qi_stage[idxF] + r_qi_stage[idxF+1]) + \
                 (r_qi_stage[idxF] - r_qi_stage[idxF+1]) * (xqi ** (1 << (lg2_pc2-idx))) * omega_qi[w_idx_o]) / 2
      assert r_qi_up == r_qi_before[idxF >> 1]
    r_qi_before = r_qi_stage

  return


# ----- polynomial output
def NTTDC_print(rname, r, qi):
  ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
  Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)

  for idxL,r_i in enumerate(r):
    print('{:s}_{:d} [{:d}] = '.format(rname, qi, idxL), end='')
    for idxI,r_ii in enumerate(r_i):
      assert r_ii in Fqix
      r_iiZ = Zx_fromFqix(r_ii)
      # r_iiZ_list = [r_iiZ[idxZ] for idxZ in range(1 << (11 - idxL))]
      # print('{:s}_{:d} [{:d}][{:d}] = '.format(rname, qi, idxL, idxI), r_iiZ)
      print(' ( ', r_iiZ, ' ) ', end='')
      # print(r_iiZ_list, end='')
    print('')

  return


# ----- polynomial output in verilog ROM        
def print_polynomial(r_module, r):
  global fp

  print('module {mname:s} ('.format(mname=r_module), file=fp)
  print('  input                    clk,', file=fp)
  print('  input                    rst,', file=fp)
  print('  input             [{:2d}:0] addr,'.format(lg2_pc2-1), file=fp)
  print('  output reg signed [{:2d}:0] dout'.format(lg2_q-1), file=fp)
  print(') ;', file=fp)
  print('', file=fp)
  print('  always @ (posedge clk) begin', file=fp)
  print('    if(rst) begin', file=fp)
  print('      dout <= \'sd0;', file=fp)
  print('    end else begin', file=fp)
  print('      case(addr)', file=fp)

  for index,value in enumerate(r):
    if(value < 0):
      print('        \'h{i:03x}: dout <= -\'sd{v:d}; // {i:d}'.format(i=index, v=-value), file=fp)
    else:
      print('        \'h{i:03x}: dout <=  \'sd{v:d}; // {i:d}'.format(i=index, v=value), file=fp)

  print('        default: dout <= \'sd0;', file=fp)
  print('      endcase', file=fp)
  print('    end', file=fp)
  print('  end', file=fp)
  print('', file=fp)
  print('endmodule', file=fp)
  print('', file=fp)

  return



# ----- main
def __main__():

  open_verilog()

  # f = random_polyq()
  # f = random_small()
  f = special_f()
  # g = random_polyq()
  # g = random_small()
  g = special_g()

  h = Zx_fromFqx(Fqx_fromR(f)*Fqx_fromR(g))
  hq0 = R_fromRq(Rq_fromR(f)*Rq_fromR(g))

  f_qs = []
  g_qs = []

  for qi in qs:
    f_qi = NTTDecomposite(f, qi)
    NTTCompositeAssert(f_qi, qi)
    f_qs.append(f_qi)
    g_qi = NTTDecomposite(g, qi)
    NTTCompositeAssert(g_qi, qi)
    g_qs.append(g_qi)

  h_qs = []

  for f_qi, g_qi, qi in zip(f_qs, g_qs, qs):
    h_qi = NTTMult(f_qi, g_qi, qi)
    NTTCompositeAssert(h_qi, qi)
    h_qs.append(h_qi)

  # NTTDC_print('f_q1', f_qs[0], qs[0])
  # NTTDC_print('g_q1', g_qs[0], qs[0])
  # NTTDC_print('h_q1', h_qs[0], qs[0])

  h_crt = [ZZ(0) for i in range(2*pc)]
  for qi, qA_qi_inv, h_qi in zip(qs, qA_qs_inv, h_qs):
    ZZ_fromFqi, Zx_fromFqix, R_fromRqi, Rqi_fromR, Fqix_fromR, Red_fromFqix = Q_Funcs(qi)
    Fqi, Fqix, xqi, Rqi, omega_qi = Q_Rings(qi)
    h_crt = [h_crt[i] + ZZ_fromFqi(mod(h_qi[0][0][i]*qA_qi_inv,qi)) * (qALL // qi) for i in range(2*pc)]
  h_crt = [h_crt[i] - qALL if h_crt[i] >  qALL_div2 else h_crt[i] for i in range(2*pc)]
  h_crt = [h_crt[i] + qALL if h_crt[i] < -qALL_div2 else h_crt[i] for i in range(2*pc)]
  h_crt = Zx_fromFqx(Fqx(h_crt))

  # print('h = ', h); print('')
  # print('hq0 = ', hq0); print('')
  # print('h_crt = ', h_crt)

  assert h == h_crt

  print_polynomial('f_rom', f)
  print_polynomial('g_rom', g)
  print_polynomial('h_rom', h)
  print_polynomial('hp_rom', hq0)
  # # print_polynomial('h_q1_rom', h_q1)
  # # print_polynomial('h_q2_rom', h_q2)



__main__()

