#!/usr/bin/env python3

import argparse



def param_file_header_gen(fp):
  print('`include "params.v"', file=fp)
  print('', file=fp)
  return



def parameter_gen(var_M, var_L, brt_k):
  global en_l_param_state_ct, en_l_param_r_max, en_e_param_m0, en_e_param_outs1, en_e_param_outsl
  global de_l_param_state_ct, de_l_param_ri_offset, de_l_param_ri_len, de_l_param_outoffset, de_l_param_outs1, de_l_param_outsl
  global de_l_param_small_r2, de_l_param_small_r3
  global de_e_param_m0, de_e_param_m0inv, de_s_param_ro_offset

  en_l_param_state_ct   = []
  en_l_param_r_max      = []
  en_e_param_m0         = []
  en_e_param_outs1      = []
  en_e_param_outsl      = []

  de_l_param_state_ct   = []
  de_l_param_ri_offset  = []
  de_l_param_ri_len     = []
  de_l_param_outoffset  = []
  de_l_param_outs1      = []
  de_l_param_outsl      = []
  de_l_param_small_r2   = False
  de_l_param_small_r3   = False
  de_e_param_m0         = []
  de_e_param_m0inv      = []
  de_s_param_ro_offset  = []


  m0 = var_M; r_len = var_L; ro_len = (var_L + 1) // 2; round_count = 0
  m1 = var_M

  de_l_param_outoffset  = [0] # + de_l_param_outoffset
  de_s_param_ro_offset  = [0] # + de_s_param_ro_offset

  while r_len > 1:
    en_l_param_r_max    += [r_len]
    en_e_param_m0       += [m0]
    de_e_param_m0       = [m0] + de_e_param_m0

    m0inv               = pow(2,brt_k) // m0
    de_e_param_m0inv    = [m0inv] + de_e_param_m0inv

    m0_2                = m0 * m0
    m0_m1               = m0 * m1

    outs1               = 0
    outsl               = 0

    if(r_len != 2):
      if(m0_2 >= 16384):
        outs1 += 1
        m0_2 = (m0_2 + 255) // 256
        if(m0_2 >= 16384):
          outs1 += 1
          m0_2 = (m0_2 + 255) // 256
      en_e_param_outs1    += [outs1]
      de_l_param_outs1    = [outs1] + de_l_param_outs1

    if(r_len == 2):
      outsl = 1
      while(m0_m1 >= 256):
        m0_m1 = (m0_m1 + 255) // 256
        outsl += 1
      de_l_param_outs1    = [outsl - 1] + de_l_param_outs1
      de_l_param_outsl    = [0] + de_l_param_outsl
    elif((r_len % 2) == 0):
      if(m0_m1 >= 16384):
        outsl += 1
        m0_m1 = (m0_m1 + 255) // 256
        if(m0_m1 >= 16384):
          outsl += 1
          m0_m1 = (m0_m1 + 255) // 256
      de_l_param_outsl    = [outsl] + de_l_param_outsl
    else:
      m0_m1 = m1
      de_l_param_outsl    = [3] + de_l_param_outsl
    en_e_param_outsl    += [outsl]

    if(r_len != 2):
      de_l_param_outoffset = [outs1 * (r_len // 2 - (1 - r_len % 2)) + outsl * (1 - r_len % 2) + de_l_param_outoffset[0]] + de_l_param_outoffset

    if(r_len == 2):
      en_l_param_state_ct += [outsl-1]
    # elif((r_len >= 3) and (r_len <= 6)):
    #   en_l_param_state_ct += [7]
    elif((r_len >= 3) and (r_len <= 4)):
      en_l_param_state_ct += [5]
    elif((r_len >= 5) and (r_len <= 6)):
      en_l_param_state_ct += [7]
    # elif((r_len == 7) or (r_len == 8)):
    #   en_l_param_state_ct += [9]
    else:
      en_l_param_state_ct += [r_len + (r_len % 2) - 1]

    if(round_count == 0):
      de_l_param_state_ct = [r_len - 1]
    elif(r_len == 2):
      de_l_param_state_ct = [outsl + 4] + de_l_param_state_ct
    elif((r_len >= 3) and (r_len <= 4)):
      de_l_param_state_ct = [4] + de_l_param_state_ct
    elif((r_len >= 5) and (r_len <= 6)):
      de_l_param_state_ct = [5] + de_l_param_state_ct
    else:
      de_l_param_state_ct = [r_len - (r_len % 2) - 1] + de_l_param_state_ct

    if(round_count != 0):
      de_l_param_ri_offset = [ro_len - r_len] + de_l_param_ri_offset
      de_s_param_ro_offset = [ro_len - r_len] + de_s_param_ro_offset

    if(r_len == 2):
      de_l_param_ri_len  = [0] + de_l_param_ri_len
    else:
      de_l_param_ri_len  = [r_len // 2 - 1] + de_l_param_ri_len

    if(r_len == 3):
      de_l_param_small_r2 = True

    if(r_len == 5):
      de_l_param_small_r3 = True

    m0 = m0_2
    m1 = m0_m1
    r_len = (r_len // 2) + (r_len % 2)
    round_count += 1

  de_l_param_ri_offset = [0] + de_l_param_ri_offset

  return round_count



# def testbench_gen(var_M, var_L):
# 
#   return



def encode_module_gen(fp, var_M, var_L, round_count):
  global en_l_param_state_ct, en_l_param_r_max, en_e_param_m0, en_e_param_outs1, en_e_param_outsl

  print(  'module rp{:d}q{:d}encode_param ( state_max, state_l, state_e, state_s,'.format(var_L, var_M), file=fp)
  print(  '                                param_state_ct, param_r_max,', file=fp)
  print(  '                                param_m0, param_outs1, param_outsl', file=fp)
  print(  ') ; ', file=fp)
  print(  '', file=fp)

  print(  '  output      [4:0]               state_max;', file=fp)
  print(  '', file=fp)

  print(  '  input       [4:0]               state_l;', file=fp)
  print(  '  input       [4:0]               state_e;', file=fp)
  print(  '  input       [4:0]               state_s;', file=fp)
  print(  '  output reg  [`RP_DEPTH-1:0]     param_state_ct;', file=fp)
  print(  '  output reg  [`RP_DEPTH-1:0]     param_r_max;', file=fp)
  print(  '  output reg  [`RP_D_SIZE-1:0]    param_m0;', file=fp)
  print(  '  output reg  [1:0]               param_outs1;', file=fp)
  print(  '  output reg  [2:0]               param_outsl;', file=fp)
  print(  '', file=fp)

  print(  '  assign state_max = 5\'d{:d};'.format(round_count), file=fp)
  print(  '', file=fp)

  print(  '  always @ (*) begin // state counters.', file=fp)
  print(  '    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.', file=fp)
  for idx in range(len(en_l_param_state_ct)):
    tempstring = '5\'d{i:<4d}: param_state_ct = {l:d}\'d{v:d};'.format(i=idx, l=round_count, v=en_l_param_state_ct[idx]);
    print('      ' + tempstring, file=fp)
  print(  '      default: param_state_ct = {l:d}\'d0;'.format(l=round_count), file=fp)
  print(  '    endcase', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)

  print(  '  always @ (*) begin // length of R array for each round.', file=fp)
  print(  '    case(state_l)', file=fp)
  for idx in range(len(en_l_param_r_max)):
    tempstring = '5\'d{i:<4d}: param_r_max = {l:d}\'d{v:d};'.format(i=idx, l=round_count, v=en_l_param_r_max[idx]);
    print('      ' + tempstring, file=fp)
  print(  '      default: param_r_max = {l:d}\'d0;'.format(l=round_count), file=fp)
  print(  '    endcase', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)

  print(  '  always @ (*) begin // M0 for each round.', file=fp)
  print(  '    case(state_e)  // Note: In the last round, M will be forgot.', file=fp)
  for idx in range(len(en_e_param_m0)):
    tempstring = '5\'d{i:<4d}: param_m0 = 14\'d{v:d};'.format(i=idx+1, v=en_e_param_m0[idx]);
    print('      ' + tempstring, file=fp)
  print(  '      default: param_m0 = 14\'d1;', file=fp)
  print(  '    endcase', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)

  print(  '  always @ (*) begin // Regular output bytes count for each round.', file=fp)
  print(  '    case(state_e)  // Note: It is the special case for the round of |R| <= 2.', file=fp)
  print(  '                   // 2 bytes outputed then set to 2.', file=fp)
  print(  '                   // 1 byte outputed then set to 1.', file=fp)
  print(  '                   // 0 bytes outputed then set to 0.', file=fp)
  for idx in range(len(en_e_param_outs1)):
    tempstring = '5\'d{i:<4d}: param_outs1 = 2\'d{v:d};'.format(i=idx+1, v=en_e_param_outs1[idx]);
    print('      ' + tempstring, file=fp)
  print(  '      default: param_outs1 = 2\'d0;', file=fp)
  print(  '    endcase', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)

  print(  '  always @ (*) begin // The last-pair output bytes count for each round.', file=fp)
  print(  '    case(state_e)  // Note: It is the special case for the round of |R| <= 2.', file=fp)
  print(  '                   // 2 bytes outputed then set to 2.', file=fp)
  print(  '                   // 1 byte outputed then set to 1.', file=fp)
  print(  '                   // 0 bytes outputed then set to 0.', file=fp)
  print(  '                   // Note: output them all in the last round.', file=fp)
  print(  '                   // Eg. In 761-4591 case: 4 bytes.', file=fp)
  for idx in range(len(en_e_param_outsl)):
    tempstring = '5\'d{i:<4d}: param_outsl = 3\'d{v:d};'.format(i=idx+1, v=en_e_param_outsl[idx]);
    print('      ' + tempstring, file=fp)
  print(  '      default: param_outsl = 3\'d0;', file=fp)
  print(  '    endcase', file=fp)
  print(  '  end', file=fp)
  print(  '', file=fp)

  print(  'endmodule', file=fp)
  print(  '', file=fp)

  return



def decode_module_gen(fp, var_M, var_L, brt_k, round_count):
  global de_l_param_state_ct, de_l_param_ri_offset, de_l_param_ri_len, de_l_param_outoffset, de_l_param_outs1, de_l_param_outsl
  global de_l_param_small_r2, de_l_param_small_r3
  global de_e_param_m0, de_e_param_m0inv, de_s_param_ro_offset

  print(    'module rp{:d}q{:d}decode_param ( state_l, state_e, state_s,'.format(var_L, var_M), file=fp)
  print(    '                                state_max, param_r_max, param_ro_max, param_small_r2, param_small_r3,', file=fp)
  print(    '                                param_state_ct, param_ri_offset, param_ri_len,', file=fp)
  print(    '                                param_outoffset, param_outs1, param_outsl, ', file=fp)
  print(    '                                param_m0, param_m0inv,', file=fp)
  print(    '                                param_ro_offset', file=fp)
  print(    ') ; ', file=fp)
  print(    '', file=fp)

  print(    '  input       [4:0]               state_l;', file=fp)
  print(    '  input       [4:0]               state_e;', file=fp)
  print(    '  input       [4:0]               state_s;', file=fp)
  print(    '', file=fp)

  print(    '  output      [4:0]               state_max;', file=fp)
  print(    '  output      [`RP_DEPTH-2:0]     param_r_max;', file=fp)
  print(    '  output      [`RP_DEPTH-1:0]     param_ro_max;', file=fp)
  print(    '  output                          param_small_r2;', file=fp)
  print(    '  output                          param_small_r3;', file=fp)
  print(    '', file=fp)

  print(    '  output reg  [`RP_DEPTH:0]       param_state_ct;', file=fp)
  print(    '  output reg  [`RP_DEPTH-2:0]     param_ri_offset;', file=fp)
  print(    '  output reg  [`RP_DEPTH-2:0]     param_ri_len;', file=fp)
  print(    '  output reg  [`OUT_DEPTH-1:0]    param_outoffset;', file=fp)
  print(    '  output reg  [1:0]               param_outs1;', file=fp)
  print(    '  output reg  [1:0]               param_outsl;', file=fp)
  print(    '  output reg  [`RP_D_SIZE-1:0]    param_m0;', file=fp)
  print(    '  output reg  [`RP_INV_SIZE-1:0]  param_m0inv;', file=fp)
  print(    '  output reg  [`RP_DEPTH-2:0]     param_ro_offset;', file=fp)
  print(    '', file=fp)

  print(    '  assign state_max = 5\'d{:d};'.format(round_count), file=fp)
  print(    '  assign param_r_max = \'d{:d};'.format(var_L // 2), file=fp)
  print(    '  assign param_ro_max = \'d{:d};'.format(var_L - var_L % 2), file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // state counters.', file=fp)
  print(    '    case(state_l)  // Indicating the cycle count (0 for 1 cycle) for each round.', file=fp)
  print(    '                   // note: initial round +1', file=fp)
  for idx in range(len(en_l_param_state_ct)):
    tempstring = '5\'d{i:<4d}: param_state_ct = {l:d}\'d{v:d};'.format(i=idx, l=round_count+1, v=de_l_param_state_ct[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_state_ct = {l:d}\'d0;'.format(l=round_count+1), file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // R array offset. The last entry of R array for', file=fp)
  print(    '    case(state_l)  // each round should be aligned at the last.', file=fp)
  for idx in range(len(de_l_param_ri_offset)):
    tempstring = '5\'d{i:<4d}: param_ri_offset = {l:d}\'d{v:d};'.format(i=idx, l=round_count-1, v=de_l_param_ri_offset[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_ri_offset = {l:d}\'d0;'.format(l=round_count-1), file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // R array offset. The last entry of R array for', file=fp)
  print(    '    case(state_l)  // each round should be aligned at the last.', file=fp)
  print(    '                   // note: no need to refer to R for 1st round.', file=fp)
  for idx in range(len(de_l_param_ri_len)):
    tempstring = '5\'d{i:<4d}: param_ri_len = {l:d}\'d{v:d};'.format(i=idx+1, l=round_count-1, v=de_l_param_ri_len[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_ri_len = {l:d}\'d0;'.format(l=round_count-1), file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // Compressed bytes offset.', file=fp)
  print(    '    case(state_l)  // Indicating the first byte for each round.', file=fp)
  for idx in range(len(de_l_param_outoffset)):
    tempstring = '5\'d{i:<4d}: param_outoffset = {l:d}\'d{v:d};'.format(i=idx+1, l=round_count+1, v=de_l_param_outoffset[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_outoffset = {l:d}\'d0;'.format(l=round_count+1), file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // Regular load bytes', file=fp)
  print(    '    case(state_l)    // note: last two rounds: 1 for 2 bytes, 2 for 3, 3 for 4', file=fp)
  for idx in range(len(de_l_param_outs1)):
    tempstring = '5\'d{i:<4d}: param_outs1 = 2\'d{v:d};'.format(i=idx+1, v=de_l_param_outs1[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_outs1 = 2\'d0;', file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  assign param_small_r2 = 1\'b{v:d};'.format(v=1 if de_l_param_small_r2 else 0), file=fp)
  print(    '  assign param_small_r3 = 1\'b{v:d};'.format(v=1 if de_l_param_small_r3 else 0), file=fp)
  print(    '  always @ (*) begin // Last load bytes', file=fp)
  print(    '    case(state_l)', file=fp)
  for idx in range(len(de_l_param_outsl)):
    tempstring = '5\'d{i:<4d}: param_outsl = 2\'d{v:d};'.format(i=idx+1, v=de_l_param_outsl[idx]);
    print('      ' + tempstring, file=fp)
  print(    '      default: param_outsl = 2\'d0;', file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // M0 for each round.', file=fp)
  print(    '    case(state_e)', file=fp)
  for idx in range(len(de_e_param_m0)):
    tempstring = '5\'d{i:<4d}: param_m0 = 14\'d{v:d};'.format(i=idx+1, v=de_e_param_m0[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_m0 = 14\'d1;', file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // M0^(-1) for each round.', file=fp)
  print(    '    case(state_e)', file=fp)
  for idx in range(len(de_e_param_m0inv)):
    tempstring = '5\'d{i:<4d}: param_m0inv = {l:d}\'d{v:d};'.format(i=idx+1, l=brt_k, v=de_e_param_m0inv[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_m0inv = {l:d}\'d1;'.format(l=brt_k), file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(    '  always @ (*) begin // Output R array offset.', file=fp)
  print(    '    case(state_s)  // Indicating the first entry for each round.', file=fp)
  for idx in range(len(de_s_param_ro_offset)):
    tempstring = '5\'d{i:<4d}: param_ro_offset = {l:d}\'d{v:d};'.format(i=idx+1, l=round_count-1, v=de_s_param_ro_offset[idx]);
    print(  '      ' + tempstring, file=fp)
  print(    '      default: param_ro_offset = {l:d}\'d0;'.format(l=round_count-1), file=fp)
  print(    '    endcase', file=fp)
  print(    '  end', file=fp)
  print(    '', file=fp)

  print(  'endmodule', file=fp)
  print(  '', file=fp)

  return



def parameter_file_gen(var_M, var_L, brt_k):
  paramfn = 'rp{:d}param.v'.format(var_L)
  fp = open(paramfn, 'w')
  
  lg_r = var_L.bit_length()

  param_file_header_gen(fp)

  # round_count = parameter_gen(var_M, var_L, brt_k)
  # encode_module_gen(fp, var_M, var_L, round_count)
  # decode_module_gen(fp, var_M, var_L, brt_k, round_count)

  # round_count = parameter_gen((var_M+2)//3, var_L, brt_k)
  # encode_module_gen(fp, (var_M+2)//3, var_L, round_count)
  # decode_module_gen(fp, (var_M+2)//3, var_L, brt_k, round_count)

  round_count = parameter_gen(var_M, var_L, brt_k)
  encode_module_gen(fp, var_M, var_L, round_count)

  round_count = parameter_gen((var_M+2)//3, var_L, brt_k)
  encode_module_gen(fp, (var_M+2)//3, var_L, round_count)

  round_count = parameter_gen(var_M, var_L, brt_k)
  decode_module_gen(fp, var_M, var_L, brt_k, round_count)

  round_count = parameter_gen((var_M+2)//3, var_L, brt_k)
  decode_module_gen(fp, (var_M+2)//3, var_L, brt_k, round_count)

  fp.close()

  return



def __main__():
  parser = argparse.ArgumentParser(description='DJB Codec Parameters')
  parser.add_argument('M', metavar='M', type=int, help='range for single element')
  parser.add_argument('L', metavar='L', type=int, help='length of the sequence')
  parser.add_argument('k', metavar='k', type=int, help='Barrett reduction factor')

  # try:
  args = parser.parse_args()

  parameter_file_gen(args.M, args.L, args.k)
  # testbench_gen(args.M, args.L)

  # except:
  # parser.print_help()



__main__()

