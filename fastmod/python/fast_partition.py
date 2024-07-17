#!/usr/bin/env python3

import argparse
import itertools
import numpy as np
import sys
import os



def bin_representation(number):
  if(number == 0):
    return [0]
  elif(number == 1):
    return [1]
  else:
    quotient, remainder = divmod(number, 2)
    return [remainder] + bin_representation(quotient)



def sgn(number):
  return 1 if number > 0 else -1 if number < 0 else 0



def evaluate_naf(number):
  x = number
  xh = x // 2
  x3 = x + xh
  c = xh ^ x3
  np = x3 & c
  nm = xh & c
  bin_np = bin_representation(np)
  bin_nm = bin_representation(nm)
  # if(len(bin_np) > len(bin_nm)):
  #   bin_nm += [0] * (len(bin_np) - len(bin_nm))
  # if(len(bin_nm) > len(bin_np)):
  #   bin_np += [0] * (len(bin_nm) - len(bin_np))
  # bin_num = [bin_np[i] - bin_nm[i] for i in range(len(bin_nm))]
  # return bin_np, bin_nm
  shw = sum(bin_np) + sum(bin_nm)
  return np, nm, shw



def powerset(N):
  if N <= 1:
    yield [0]
    yield [1]
  else:
    for item in powerset(N-1):
      yield item+[0]
      yield item+[1]



def Get_rp(poweritem):
  return poweritem[1]



def partition_powers(quotient, power, infmt, outfmt):
  if(outfmt != 0):
    overquotient = int(np.ceil(np.log2(quotient+1))) - 2
    assert overquotient + 1 <= power
  else:
    overquotient = int(np.ceil(np.log2(quotient+1))) - 1
    assert overquotient <= power

  itemcount = power - overquotient
  groupcount = (itemcount + 5) // 6
  groupcount = 5 if (groupcount >= 4) else 3

  # q_hex_l = int(np.ceil(np.log2(quotient)/4))
  # q_bin_l = int(np.ceil(np.log2(quotient)))
  # q_dec_l = int(np.ceil(np.log10(quotient)))

  enumerate_values = list(range(overquotient, power))
  partitions = []
  poweritems = []
  itemperpart = (itemcount + groupcount - 1) // groupcount
  for item in enumerate_values:
    rp = pow(2, item) % quotient
    rn = (quotient - rp) % quotient
    # rpp, rpn, shwp = evaluate_naf(rp)
    # rnp, rnn, shwn = evaluate_naf(rn)
    # print(item, rp, rn, infmt, file=sys.stderr)
    if((item == power - 1) and (infmt != 0)):
      # poweritem = (-item, rn, rp, rnp, rnn, rpp, rpn, shwn, shwp)
      # print('swap item', file=sys.stderr)
      poweritem = (item, rn, rp)
    else:
      # poweritem = (item, rp, rn, rpp, rpn, rnp, rnn, shwp, shwn)
      poweritem = (item, rp, rn)
    poweritems.append(poweritem)
    if(len(poweritems) >= itemperpart):
      # print(partitions, itemcount, groupcount, itemperpart, flush=True) 
      partitions += [poweritems]
      itemcount -= len(poweritems)
      if(itemcount != 0):
        groupcount -= 1
        itemperpart = (itemcount + groupcount - 1) // groupcount
      poweritems = []
      # print(partitions, itemcount, groupcount, itemperpart, flush=True)
  return partitions



def genRTL(partitions, quotient, power, infmt, outfmt):
  qlen = quotient.bit_length()
  quotient32 = (3*quotient - 1) // 2
  qlen32 = quotient32.bit_length()
  quotient34 = (3*quotient - 1) // 4
  qlen34 = quotient34.bit_length()
  quotient12 = (  quotient - 1) // 2
  qlen12 = quotient12.bit_length()
  quotient14 = (  quotient - 1) // 4
  qlen14 = quotient14.bit_length()

  if((infmt == 0) and (outfmt == 0)):
    vecmname = 'mod{}UUvec{}'.format(quotient, power)
    rtlmname = 'mod{}UU{}'.format(quotient, power)
  elif((infmt == 0) and (outfmt == 1)):
    vecmname = 'mod{}USvec{}'.format(quotient, power)
    rtlmname = 'mod{}US{}'.format(quotient, power)
  elif((infmt == 1) and (outfmt == 0)):
    vecmname = 'mod{}SUvec{}'.format(quotient, power)
    rtlmname = 'mod{}SU{}'.format(quotient, power)
  else:
    vecmname = 'mod{}SSvec{}'.format(quotient, power)
    rtlmname = 'mod{}SS{}'.format(quotient, power)

  with open(vecmname + '.v', 'w') as vecfile:
  # with open(os.devnull, 'w') as vecfile:
  # with sys.stdout as vecfile:
    def vprint(*args, **kwargs):
      nonlocal vecfile
      print(*args, file=vecfile, **kwargs)

    vprint(      'module ' + vecmname + ' (')
    if(infmt == 0):
      vprint(    '  input [{:<2d}: 0] z_in,'.format(power-1))
    else:
      vprint(    '  input signed [{:<2d}: 0] z_in,'.format(power-1))
    vprint(      '')
    if(outfmt == 0):
      vprint(    '  output     [{:<2d}: 0] p0,'.format(qlen-2))
      for idx0 in range(len(partitions)):
        if(idx0 != 0):
          vprint(',')
        vprint(  '  output reg [{:<2d}: 0] p{:d}'.format(qlen-1, idx0+1), end='')
    else:
      vprint(    '  output            [{:<2d}: 0] p0,'.format(qlen-3))
      for idx0 in range(len(partitions)):
        if(idx0 != 0):
          vprint(',') 
          vprint('  output reg signed [{:<2d}: 0] p{:d}'.format(qlen34, idx0+1), end='')
        else:
          vprint('  output reg        [{:<2d}: 0] p1'.format(qlen-1), end='')

    vprint('')
    vprint(      ') ;')
    vprint(      '')

    if(outfmt == 0):
      vprint(    '  assign p0 = z_in[{:<2d}:0];'.format(qlen-2))
    else:
      vprint(    '  assign p0 = z_in[{:<2d}:0];'.format(qlen-3))
    vprint(      '')

    for idx0, pitems in enumerate(partitions):
      if(len(pitems) > 4):
        vcasestr = '{:d}\'h{:02x}: p{:d} = '
      else:
        vcasestr = '{:d}\'h{:01x}: p{:d} = '
      vprint(    '  always @ (*) begin')
      vprint(    '    case({ ', end='')
      for idx1, pitem in enumerate(reversed(pitems)):
        if(idx1 != 0):
          vprint(', ', end='')
        vprint('z_in[{}]'.format(pitem[0]), end='')
      vprint(' })')
      for idx1 in range(int(pow(2, len(pitems)))):
        rp = 0
        bit_idx1 = bin_representation(idx1)
        bit_idx1 += [0] * (len(pitems) - len(bit_idx1))
        for idx2, pitem in enumerate(pitems):
          rp += bit_idx1[idx2] * pitem[1]
        rp = rp % quotient
        vprint(  '      ' + vcasestr.format(len(pitems), idx1, idx0+1), end='')
        if((idx0 == 0) or (outfmt == 0)):
          vprint('{:d}\'d{:d};'.format(qlen, rp))
        else:
          rp = rp - quotient if (rp > quotient34) else rp
          if(rp >= 0):
            vprint(' {:d}\'sd{:d};'.format(qlen34+1, rp))
          else:
            vprint('-{:d}\'sd{:d};'.format(qlen34+1, -rp))
      vprint(    '    endcase')
      vprint(    '  end')
      vprint(    '')
    
    vprint(      'endmodule')
    vprint(      '')
  
  with open(rtlmname + '.v', 'w') as rtlfile:
  # with sys.stdout as rtlfile:
    def rprint(*args, **kwargs):
      nonlocal rtlfile
      print(*args, file=rtlfile, **kwargs)

    rprint(      'module ' + rtlmname + ' ( clk, Reset, In, Out ) ;')
    rprint(      '')
    if(outfmt == 0):
      rprint(    '  localparam signed PRIME_2Q = {:d}\'sd{:d};'.format(qlen+1, quotient << 1))
    rprint(      '  localparam signed PRIME_Q  = {:d}\'sd{:d};'.format(qlen, quotient))
    if(outfmt != 0):
      rprint(    '  localparam signed PRIME_QH = {:d}\'sd{:d};'.format(qlen-1, quotient12))
    rprint(      '')
    rprint(      '  input clk;')
    rprint(      '  input Reset;')
    if(infmt == 0):
      rprint(    '  input             [{:<2d}: 0] In;'.format(power-1))
    else:
      rprint(    '  input signed      [{:<2d}: 0] In;'.format(power-1))
    if(outfmt == 0):
      rprint(    '  output reg        [{:<2d}: 0] Out;'.format(qlen-1))
    else:
      rprint(    '  output reg signed [{:<2d}: 0] Out;'.format(qlen-1))
    rprint(      '')

    if(outfmt == 0):
      rprint(    '  wire              [{:<2d}: 0] intP0;'.format(qlen-2))
      for idx0 in range(len(partitions)):
        rprint(  '  wire              [{:<2d}: 0] intP{:d};'.format(qlen-1, idx0+1))
    else:
      rprint(    '  wire              [{:<2d}: 0] intP0;'.format(qlen-3))
      for idx0 in range(len(partitions)):
        if(idx0 != 0):
          rprint('  wire signed       [{:<2d}: 0] intP{:d};'.format(qlen34, idx0+1))
        else:
          rprint('  wire              [{:<2d}: 0] intP1;'.format(qlen-1))
    rprint(      '')

    if(outfmt == 0):
      for idx0 in range(0, len(partitions), 2):
        rprint(    '  wire              [{:<2d}: 0] intP{:d}{:d};'.format(qlen, idx0, idx0+1))
        rprint(    '  wire signed       [{:<2d}: 0] intP{:d}{:d}q;'.format(qlen, idx0, idx0+1))
        rprint(    '  reg               [{:<2d}: 0] regP{:d}{:d};'.format(qlen-1, idx0, idx0+1))
    else:
      rprint(      '  wire              [{:<2d}: 0] intP01;'.format(qlen32-1))
      rprint(      '  wire signed       [{:<2d}: 0] intP01q;'.format(qlen))
      rprint(      '  reg signed        [{:<2d}: 0] regP01;'.format(qlen-1))
      for idx0 in range(2, len(partitions), 2):
        rprint(    '  wire signed       [{:<2d}: 0] intP{:d}{:d};'.format(qlen32, idx0, idx0+1))
        rprint(    '  wire signed       [{:<2d}: 0] intP{:d}{:d}q;'.format(qlen, idx0, idx0+1))
        rprint(    '  reg signed        [{:<2d}: 0] regP{:d}{:d};'.format(qlen-1, idx0, idx0+1))
    rprint(        '')

    if(outfmt == 0):
      rprint(      '  reg               [{:<2d}: 0] regD;'.format(qlen+1))
      rprint(      '  wire signed       [{:<2d}: 0] intDq1;'.format(qlen+1))
      rprint(      '  wire signed       [{:<2d}: 0] intDq2;'.format(qlen+1))
    else:
      rprint(      '  reg signed        [{:<2d}: 0] regD;'.format(qlen32+1))
      rprint(      '  wire              [1:0]       intD_f;')
      rprint(      '  reg signed        [{:<2d}: 0] intDq;'.format(qlen))
    rprint(        '')

    rprint(      '  ' + vecmname + ' mvec0 (')
    rprint(      '    .z_in(In),')
    rprint(      '    .p0(intP0)', end='')
    for idx0 in range(len(partitions)):
      rprint(', .p{idx}(intP{idx})'.format(idx=idx0+1), end='')
    rprint(' );')
    rprint('')    

    if(outfmt == 0):
      rprint(    '  assign intP01   = { 2\'b0, intP0 } + { 1\'b0, intP1 };')
      rprint(    '  assign intP01q  = intP01 - PRIME_Q;')
      for idx0 in range(2, len(partitions), 2):
        rprint(  '  assign intP{idxA:d}{idxB:d}   = {{ 1\'b0, intP{idxA:d} }} + {{ 1\'b0, intP{idxB:d} }};'.format(idxA=idx0,idxB=idx0+1))
        rprint(  '  assign intP{idxA:d}{idxB:d}q  = intP{idxA:d}{idxB:d} - PRIME_Q;'.format(idxA=idx0,idxB=idx0+1))
    else:
      rprint(    '  assign intP01   = { 3\'b0, intP0 } + { 1\'b0, intP1 };')
      rprint(    '  assign intP01q  = (intP01 > PRIME_QH) ? -PRIME_Q : 0;')
      for idx0 in range(2, len(partitions), 2):
        rprint(  '  assign intP{idxA:d}{idxB:d}   = {{ 1\'b0, intP{idxA:d} }} + {{ 1\'b0, intP{idxB:d} }};'.format(idxA=idx0,idxB=idx0+1))
        rprint(  '  assign intP{idxA:d}{idxB:d}q  = (intP{idxA:d}{idxB:d} > PRIME_QH) ? -PRIME_Q : 0;'.format(idxA=idx0,idxB=idx0+1))
    rprint(      '')

    rprint(      '  always @ ( posedge clk ) begin')
    rprint(      '    if(Reset) begin')
    for idx0 in range(0, len(partitions), 2):
      rprint(    '      regP01 <= {:d}\''.format(qlen), end='')
      if(outfmt == 0):
        rprint('d0;')
      else:
        rprint('sd0;')
    rprint(      '    end else begin')
    if(outfmt == 0):
      for idx0 in range(0, len(partitions), 2):
        rprint(  '      regP{idxA:d}{idxB:d} <= intP{idxA:d}{idxB:d}q[{ql:d}] ? intP{idxA:d}{idxB:d} : intP{idxA:d}{idxB:d}q;'.format(idxA=idx0,idxB=idx0+1,ql=qlen))
    else:
      for idx0 in range(0, len(partitions), 2):
        rprint(  '      regP{idxA:d}{idxB:d} <= intP{idxA:d}{idxB:d} + intP{idxA:d}{idxB:d}q;'.format(idxA=idx0,idxB=idx0+1))
    rprint(      '    end')
    rprint(      '  end')
    rprint(      '')

    rprint(      '  always @ ( posedge clk ) begin')
    rprint(      '    if(Reset) begin')
    if(outfmt == 0):
      rprint(    '      regD <= {:d}\'d0;'.format(qlen+2))
    else:
      rprint(    '      regD <= {:d}\'sd0;'.format(qlen32+2))
    rprint(      '    end else begin')
    rprint(      '      regD <= ', end='')
    for idx0 in range(0, len(partitions), 2):
      if(idx0 != 0):
        rprint(' + ', end='')
      rprint('regP{idxA:d}{idxB:d}'.format(idxA=idx0,idxB=idx0+1), end='')
    rprint(      ';')
    rprint(      '    end')
    rprint(      '  end')
    rprint(      '')

    if(outfmt == 0):
      rprint(    '  assign intDq1 = regD - PRIME_Q;')
      rprint(    '  assign intDq2 = regD - PRIME_2Q;')
      rprint(    '')
      rprint(    '  always @ ( posedge clk ) begin')
      rprint(    '    if(Reset) begin')
      rprint(    '      Out <= {:d}\'d0;'.format(qlen))
      rprint(    '    end else begin')
      rprint(    '      if(intDq1[{:d}]) begin'.format(qlen+1))
      rprint(    '        Out <= regD;')
      rprint(    '      end else if(intDq2[{:d}]) begin'.format(qlen+1))
      rprint(    '        Out <= intDq1;')
      rprint(    '      end else begin')
      rprint(    '        Out <= intDq2;')
      rprint(    '      end')
      rprint(    '    end')
      rprint(    '  end')
    else:
      rprint(    '  assign intD_f[0] = (regD >  PRIME_QH);')
      rprint(    '  assign intD_f[1] = (regD < -PRIME_QH);')
      rprint(    '')
      rprint(    '  always @ (*) begin')
      rprint(    '    case(intD_f)')
      rprint(    '      2\'b10:   intDq =  PRIME_Q;')
      rprint(    '      2\'b01:   intDq = -PRIME_Q;')
      rprint(    '      default: intDq = \'sd0;')
      rprint(    '    endcase')
      rprint(    '  end')
      rprint(    '')
      rprint(    '  always @ ( posedge clk ) begin')
      rprint(    '    if(Reset) begin')
      rprint(    '      Out <= {:d}\'sd0;'.format(qlen))
      rprint(    '    end else begin')
      rprint(    '      Out <= regD + intDq;')
      rprint(    '    end')
      rprint(    '  end')
    rprint(      '')

    rprint(      'endmodule')
    rprint(      '')

  return



def genTB(quotient, power, infmt, outfmt):
  qlen = quotient.bit_length()
  # quotient32 = (3*quotient - 1) // 2
  # qlen32 = quotient32.bit_length()
  # quotient34 = (3*quotient - 1) // 4
  # qlen34 = quotient34.bit_length()
  quotient12 = (  quotient - 1) // 2
  qlen12 = quotient12.bit_length()
  # quotient14 = (  quotient - 1) // 4
  # qlen14 = quotient14.bit_length()

  if((infmt == 0) and (outfmt == 0)):
    vecmname = 'mod{}UUvec{}'.format(quotient, power)
    rtlmname = 'mod{}UU{}'.format(quotient, power)
  elif((infmt == 0) and (outfmt == 1)):
    vecmname = 'mod{}USvec{}'.format(quotient, power)
    rtlmname = 'mod{}US{}'.format(quotient, power)
  elif((infmt == 1) and (outfmt == 0)):
    vecmname = 'mod{}SUvec{}'.format(quotient, power)
    rtlmname = 'mod{}SU{}'.format(quotient, power)
  else:
    vecmname = 'mod{}SSvec{}'.format(quotient, power)
    rtlmname = 'mod{}SS{}'.format(quotient, power)

  with open('Makefile', 'w') as mkfile:
    def mprint(*args, **kwargs):
      nonlocal mkfile
      print(*args, file=mkfile, **kwargs)

    mprint('SIMULATOR = vcs')
    mprint('ARGUMENT = -full64 -R -debug_access+all +v2k')
    mprint('')

    mprint('VCSRC = /usr/cad/synopsys/CIC/vcs.cshrc')
    mprint('VERDIRC = /usr/cad/synopsys/CIC/verdi.cshrc')
    mprint('')

    mprint('TESTBENCH = ' + rtlmname + '_tb.v')
    mprint('SOURCE = ' + rtlmname + '.v ' + vecmname + '.v')
    mprint('')

    mprint('.PHONY: clean all ' + rtlmname)
    mprint('')

    mprint('all: ' + rtlmname)
    mprint('')

    mprint(rtlmname + ': $(TESTBENCH) $(SOURCE)')
    mprint('\tcsh -c \'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(TESTBENCH) $(SOURCE) $(ARGUMENT)\'')
    mprint('')

    mprint('clean:')
    mprint('\trm -rf INCA_libs')
    mprint('\trm -rf csrc')
    mprint('\trm -rf simv.daidir')
    mprint('\trm -rf xcelium.d')
    mprint('\trm -rf nWaveLog')
    mprint('\trm -f *.fsdb ncverilog.history ncverilog.log novas.conf novas.rc novas_dump.log ucli.key simv')

  with open(rtlmname + '_tb.v', 'w') as tbfile:
    def tprint(*args, **kwargs):
      nonlocal tbfile
      print(*args, file=tbfile, **kwargs)

    tprint(      '`timescale 1ns/100ps')
    tprint(      '')
    tprint(      'module ' + rtlmname + '_tb;')
    tprint(      '')
    tprint(      '  parameter HALFCLK = 5;')
    tprint(      '')
    tprint(      '  /* clock setting */')
    tprint(      '  reg clk;')
    tprint(      '    initial begin')
    tprint(      '    clk=1;')
    tprint(      '  end')
    tprint(      '  always #(HALFCLK) clk<=~clk;')
    tprint(      '')
    tprint(      '  /* vcd file setting */')
    tprint(      '  initial begin')
    tprint(      '    $fsdbDumpfile("' + rtlmname + '_tb.fsdb");')
    tprint(      '    $fsdbDumpvars;')
    tprint(      '    #10000000000;')
    tprint(      '    $finish;')
    tprint(      '  end')
    tprint(      '')

    tprint(      '  wire [255:0] equals;')
    tprint(      '')
    tprint(      '  wire equal_all;')
    tprint(      '  assign equal = &equals;')
    tprint(      '')

    tprint(      '  genvar prefix;')
    tprint(      '  generate')
    tprint(      '    for(prefix = \'d0; prefix < \'d256; prefix = prefix + \'d1) begin : tester')
    tprint(      '      reg rst;')
    tprint(      '')
    tprint(      '      reg [{:<2d}: 0] postfix;'.format(power-9))
    if(infmt == 0):
      tprint(    '      wire        [{:<2d}: 0] inZ;'.format(power-1))
    else:
      tprint(    '      wire signed [{:<2d}: 0] inZ;'.format(power-1))
    if(outfmt == 0):
      tprint(    '      wire        [{:<2d}: 0] outZ;'.format(qlen-1))
      tprint(    '      wire        [{:<2d}: 0]  outZ_ref;'.format(qlen))
      tprint(    '      reg         [{:<2d}: 0]  outZ_ref_c_r0;'.format(qlen))
      tprint(    '      reg         [{:<2d}: 0]  outZ_ref_c_r1;'.format(qlen))
      tprint(    '      reg         [{:<2d}: 0]  outZ_ref_c_r2;'.format(qlen))
    else:
      tprint(    '      wire signed [{:<2d}: 0] outZ;'.format(qlen-1))
      tprint(    '      wire signed [{:<2d}: 0]  outZ_ref;'.format(qlen))
      tprint(    '      wire signed [{:<2d}: 0]  outZ_ref_c;'.format(qlen))
      tprint(    '      reg signed  [{:<2d}: 0]  outZ_ref_c_r0;'.format(qlen))
      tprint(    '      reg signed  [{:<2d}: 0]  outZ_ref_c_r1;'.format(qlen))
      tprint(    '      reg signed  [{:<2d}: 0]  outZ_ref_c_r2;'.format(qlen))
    tprint(      '')

    tprint(      '      assign inZ = { prefix[7:0], postfix };')
    tprint(      '')
    if(outfmt == 0):
      tprint(    '      assign outZ_ref = inZ % {:d}\'d{:d};'.format(qlen, quotient))
    else:
      tprint(    '      assign outZ_ref = inZ % {:d}\'sd{:d};'.format(qlen+1, quotient))
      tprint(    '      assign outZ_ref_c = (outZ_ref >  {ql:d}\'sd{q12:d}) ? (outZ_ref - {ql:d}\'sd{quo:d}) :'.format(ql=qlen+1,q12=quotient12,quo=quotient))
      tprint(    '                          (outZ_ref < -{ql:d}\'sd{q12:d}) ? (outZ_ref + {ql:d}\'sd{quo:d}) : outZ_ref;'.format(ql=qlen+1,q12=quotient12,quo=quotient))
    tprint(      '')

    tprint(      '      always @ (posedge clk) begin')
    if(outfmt == 0):
      tprint(    '        outZ_ref_c_r0 <= outZ_ref;') 
    else:
      tprint(    '        outZ_ref_c_r0 <= outZ_ref_c;')
    tprint(      '        outZ_ref_c_r1 <= outZ_ref_c_r0;')
    tprint(      '        outZ_ref_c_r2 <= outZ_ref_c_r1;')
    tprint(      '      end')
    tprint(      '')

    tprint(      '      wire equal;')
    tprint(      '      wire equalp;')
    tprint(      '      wire equal0;')
    tprint(      '      wire equaln;')
    tprint(      '')

    if(outfmt == 0):
      tprint(    '      assign equalp = ( {{ 1\'b0, outZ }} - {:>2d}\'d{:<5d} == outZ_ref_c_r2 );'.format(qlen+1, quotient))
      tprint(    '      assign equal0 = ( {{ 1\'b0, outZ }}              == outZ_ref_c_r2 );')
      tprint(    '      assign equaln = ( {{ 1\'b0, outZ }} + {:>2d}\'d{:<5d} == outZ_ref_c_r2 );'.format(qlen+1, quotient))
    else:
      tprint(    '      assign equalp = ( {{ 1\'b0, outZ }} - {:>2d}\'sd{:<5d} == outZ_ref_c_r2 );'.format(qlen+1, quotient))
      tprint(    '      assign equal0 = ( {{ 1\'b0, outZ }}               == outZ_ref_c_r2 );')
      tprint(    '      assign equaln = ( {{ 1\'b0, outZ }} + {:>2d}\'sd{:<5d} == outZ_ref_c_r2 );'.format(qlen+1, quotient))
    tprint(      '')

    tprint(      '      //assign equal = equalp | equal0 | equaln;')
    tprint(      '      assign equal = equal0;')
    tprint(      '')
    tprint(      '      assign equals[prefix] = equal;')
    tprint(      '')

    tprint(      '      integer index;')
    tprint(      '      initial begin')
    tprint(      '')
    tprint(      '        rst = 1\'b0;')
    tprint(      '        #(2*HALFCLK);')
    tprint(      '        rst = 1\'b1;')
    tprint(      '        #(2*HALFCLK);')
    tprint(      '        rst = 1\'b0;')
    tprint(      '')

    pwr_prefix = power % 4
    maxstr = '' if (pwr_prefix == 0) else '1' if (pwr_prefix == 1) else '3' if (pwr_prefix == 2) else '7'
    maxstr += 'f' * ((power // 4) - 2)

    tprint(      '        for (index = \'h0; index <= \'h' + maxstr + '; index = index + \'h1) begin')
    tprint(      '')
    tprint(      '            if (!(index & \'hffff) && (prefix == 0)) $display("index == %x", index);')
    tprint(      '')
    tprint(      '            postfix = index;')
    tprint(      '            #(8*HALFCLK);')
    tprint(      '        end')
    tprint(      '')
    tprint(      '        $finish;')
    tprint(      '      end ')
    tprint(      '')

    tprint(      '      ' + rtlmname + ' mod_inst ( .clk(clk), .Reset(rst), .In(inZ), .Out(outZ) );')
    tprint(      '    end // tester')
    tprint(      '  endgenerate')
    tprint(      '')

    tprint(      '  always @ (posedge clk) begin')
    tprint(      '    if(!equal_all) begin')
    tprint(      '      $display("WARNING! equals = %t!", $realtime);')
    tprint(      '      $display("equals = %X", equals);')
    tprint(      '      #(16*HALFCLK);')
    tprint(      '      $finish;')
    tprint(      '    end')
    tprint(      '  end')
    tprint(      '')

    tprint(      'endmodule')
    tprint(      '')

  with open(rtlmname + '_zedboard.tcl', 'w') as tclfile:
    def tcprint(*args, **kwargs):
      nonlocal tclfile
      print(*args, file=tclfile, **kwargs)

    tcprint(    'create_project ' + rtlmname + ' ' + rtlmname + '_zedboard -part xc7z020clg484-1')
    tcprint(    'set_property board_part em.avnet.com:zed:part0:1.4 [current_project]')
    tcprint(    'add_files -norecurse {' + vecmname + '.v ' + rtlmname + '.v}')
    tcprint(    'import_files -force -norecurse')
    tcprint(    'import_files -fileset constrs_1 -force -norecurse ../timing.xdc')
    tcprint(    'update_compile_order -fileset sources_1')
    tcprint(    'update_compile_order -fileset sources_1')
    tcprint(    'launch_runs synth_1 -jobs 64')
    tcprint(    'wait_on_run synth_1')
    tcprint(    'launch_runs impl_1 -jobs 64')
    tcprint(    'wait_on_run impl_1')
    tcprint(    'close_project')

  with open(rtlmname + '_zcu102.tcl', 'w') as tclfile:
    def tcprint(*args, **kwargs):
      nonlocal tclfile
      print(*args, file=tclfile, **kwargs)

    tcprint(    'create_project ' + rtlmname + ' ' + rtlmname + '_zcu102 -part xczu9eg-ffvb1156-2-e')
    tcprint(    'set_property board_part xilinx.com:zcu102:part0:3.3 [current_project]')
    tcprint(    'add_files -norecurse {' + vecmname + '.v ' + rtlmname + '.v}')
    tcprint(    'import_files -force -norecurse')
    tcprint(    'import_files -fileset constrs_1 -force -norecurse ../timing.xdc')
    tcprint(    'update_compile_order -fileset sources_1')
    tcprint(    'update_compile_order -fileset sources_1')
    tcprint(    'launch_runs synth_1 -jobs 64')
    tcprint(    'wait_on_run synth_1')
    tcprint(    'launch_runs impl_1 -jobs 64')
    tcprint(    'wait_on_run impl_1')
    tcprint(    'close_project')

  return 



def __main__():
  parser = argparse.ArgumentParser(description='List Parser')
  parser.add_argument('quotient', metavar='Q', type=int, help='quotient')
  parser.add_argument('power', metavar='N', type=int, help='power, minus implies signed input')
  parser.add_argument('-s', '--signed', dest='outfmt', action='store_const', const=1, default=1, help='signed output (default)')
  parser.add_argument('-u', '--unsigned', dest='outfmt', action='store_const', const=0, help='unsigned output')

  # try:
  args = parser.parse_args()

  (power, infmt) = (args.power, 0) if args.power > 0 else (-args.power, 1)

  partitions = partition_powers(args.quotient, power, infmt, args.outfmt)
  # print(partitions)
  genRTL(partitions, args.quotient, power, infmt, args.outfmt)
  genTB(args.quotient, power, infmt, args.outfmt)
  # except:
  #   parser.print_help()



__main__()

