#!/usr/bin/env python3

import argparse
import os
import sys
import time
from functools import partial
from multiprocessing import Process, Array
from pathlib import Path

Argument_Error = 'Argument Error'
DEBUG_Verify_Error = 'Verify Error'



########## file i/o related functions ##########
def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)
  return

def fprint(*args, **kwargs):
  global f_fd
  print(*args, file=f_fd, **kwargs)
  return



########## number system related functions ##########

# Binary representation of 'number' as a list
def bin_representation(number):
  assert (number >= 0)
  if(number == 0):
    return [0]
  elif(number == 1):
    return [1]
  else:
    quotient, remainder = divmod(number, 2)
    return [remainder] + bin_representation(quotient)

# 2's Complement binary representatiopn of 'number' as a list
def bin_signed_representation(number, sign_power):
  comple = pow(2, sign_power)
  if (number < 0):
    bin_num = bin_representation(comple + number)
  else:
    bin_num = bin_representation(number)
  if(len(bin_num) < sign_power):
    bin_num += ([0] * (sign_power - len(bin_num)))
  return bin_num

# Sign of number
def sgn(number):
  return 1 if number > 0 else -1 if number < 0 else 0

# Find the non-adjacent form of number
def evaluate_naf(number):
  x = number
  xh = x // 2
  x3 = x + xh
  c = xh ^ x3
  np = x3 & c
  nm = xh & c
  bin_np = bin_representation(np)
  bin_nm = bin_representation(nm)
  if(len(bin_np) > len(bin_nm)):
    bin_nm += [0] * (len(bin_np) - len(bin_nm))
  if(len(bin_nm) > len(bin_np)):
    bin_np += [0] * (len(bin_nm) - len(bin_np))
  bin_num = [bin_np[i] - bin_nm[i] for i in range(len(bin_nm))]
  while(bin_num[-1] == 0):
    bin_num.pop()
  return bin_num



########## 2^n-1 form checker ##########
def is_2pow_minus1(x):
  return bool(x == (int(pow(2, x.bit_length())) - 1))



########## reduction criteria functions ##########
def interval_signed_loose_check(m, n):
  if (m > ((5 * n - 1) // 2)):
    return True
  else:
    return False

def interval_signed_check(m, n):
  if (m > ((3 * n - 1) // 2)):
    return True
  else:
    return False

def interval_signed_strict_check(m, n):
  if (m > ((n - 1) // 2)):
    return True
  else:
    return False

def interval_unsigned_loose_check(m, n):
  if (m > (2 * n - 1)):
    return True
  else:
    return False

def interval_unsigned_check(m, n):
  l_n = n.bit_length()
  n_r = (1 << l_n)
  if (m > (n_r - 1)):
    return True
  else:
    return False

def interval_unsigned_strict_check(m, n):
  if (m > (n - 1)):
    return True
  else:
    return False

def set_interval_check(number):
  global interval_signed_pos_check, interval_unsigned_pos_check, interval_signed_neg_check, interval_unsigned_neg_check
  interval_signed_pos_check   = partial(interval_signed_check, n=number)
  interval_unsigned_pos_check = partial(interval_unsigned_loose_check, n=number)
  interval_signed_neg_check   = partial(interval_signed_check, n=number)
  interval_unsigned_neg_check = partial(interval_unsigned_strict_check, n=number)
  return



########## reduction plan data structure related functions          ##########
########## Token: (sign, vp, exp, len, stageno, z_style)            ##########
########## tk = sign * Z_{z_style, stageno} [vp+len-1 : vp] * 2^exp ##########

# Find the position of MSB of the token
def MSB(x):
  return x[2] + x[3] - 1

# Find the MSB index of the token
def MSB_full(x):
  return x[1] + x[3] - 1



# Print the list storing the stage plan
def print_stage_list(stage_list, stageno = -1):
  if(stage_list == []):
    print('NO STAGES')
    return

  MSB_all = 0
  for stage in stage_list:
    MSB_pcomp = 0 if len(stage[1]) == 0 else MSB(max(stage[1], key=MSB))
    MSB_ncomp = 0 if len(stage[2]) == 0 else MSB(max(stage[2], key=MSB))
    if(MSB_pcomp > MSB_all): MSB_all = MSB_pcomp
    if(MSB_ncomp > MSB_all): MSB_all = MSB_ncomp

  # print('DEBUG: MSB_all = {}'.format(MSB_all))

  stage_current = [[], []]
  last_pos_max = -1
  last_neg_max = -1

  for idx0, stage in enumerate(stage_list):
    if(stageno != -1):
      print('Stage {}:'.format(stageno))
    else:
      print('Stage {}:'.format(idx0))
    
    for idx1 in range(MSB_all, -1, -1):
      print(' {:7d}'.format(idx1), end='')
    print(' ')
    for idx1 in range(MSB_all + 1):
      print('--------', end='')
    print('-')

    MSB_stage = 0
    MSB_pstage = 0 if len(stage[1]) == 0 else MSB_full(max(stage[1], key=MSB_full))
    MSB_nstage = 0 if len(stage[2]) == 0 else MSB_full(max(stage[2], key=MSB_full))
    if(MSB_pstage > MSB_stage): MSB_stage = MSB_pstage
    if(MSB_nstage > MSB_stage): MSB_stage = MSB_nstage
    MSB_stage += 1
    # print('DEBUG: MSB_stage = {}'.format(MSB_stage))
    # print('stage[1] is {}'.format(stage[1]))
    # print('stage[2] is {}'.format(stage[2]))


    if(idx0 != 0):
      if(stage[0] >= 0):
        stage_current[0].clear()
      if(stage[0] <= 0):
        stage_current[1].clear()

    for token in stage[1]:
      stage_current[0].append(token)
    for token in stage[2]:
      stage_current[1].append(token)

    for token in stage_current[0] + stage_current[1]:
      MSB_token = MSB(token)
      for idx1 in range(MSB_all - MSB_token):
        print('        ', end='')
      for idx1 in range(token[3], 0, -1):
        idx_current = token[1]+idx1-1
        if(token[5] > 0):
          z_fstr = 'zp{s}_{idx:d}'
        elif(token[5] < 0):
          z_fstr = 'zn{s}_{idx:d}'
        else:
          print(' ', end='')
          z_fstr = 'z{s}_{idx:d}'
        if(idx_current < 10):
          print(' ', end='')
        if(token[0] < 0):
          print(' -', end='')
        else:
          print('  ', end='')
        print(z_fstr.format(s=token[4], idx=idx_current), end='')
      print('')
    print('')
    # print('DEBUG: MSB_stage = {}, last_pos_max = {}, last_neg_max = {}, stage[0] = {}'.format(MSB_stage, last_pos_max, last_neg_max, stage[0]))
    pos_max, neg_max = evaluate_reduction_range((stage[1], stage[2]), MSB_stage, last_pos_max, last_neg_max, stage[0])

    print('pos_max = {}, neg_max = {}'.format(pos_max, neg_max))
    last_pos_max = pos_max
    last_neg_max = neg_max
    # print('DEBUG: stage end here')
    print('')

  return



# evaluate the new token list of the combination of t1 and t2 for the case the ADDITION works
def integrate_sync_vectors(t1, t2):
  if((t1[4] != t2[4]) or (t1[5] != t2[5])):
    return False, []
  else:
    stageno = t1[4]
    z_style = t1[5]

  if (MSB(t1) < MSB(t2)):
    ta = t2
    tb = t1
  elif (MSB(t2) < MSB(t1)):
    ta = t1
    tb = t2
  elif (t1[2] < t2[2]):
    ta = t2
    tb = t1
  else:
    ta = t1
    tb = t2

  to_list = []

  if ((ta[1] - ta[2]) != (tb[1] - tb[2])): # offset not match => no need to integrate

    return False, to_list

  else: # abs(partial(ta)) == abs(partial(tb))

    if (ta[2] > MSB(tb)): # No overlap
      if((ta[2] == MSB(tb) + 1) and (ta[0] == tb[0])): # Concatenation available
        #   ta +---+
        #   tb      +---+
        # t_ov +--------+
        to = (tb[0], tb[1], tb[2], ta[3] + tb[3], stageno, z_style)
        to_list += [to]
        return True, to_list
      else:
        return False, to_list

    if (MSB(ta) != MSB(tb)):
      #   ta +-------+
      #   tb     +-...
      # ta_u +--+
      to = (ta[0], ta[1] + (MSB(tb) - ta[2] + 1), MSB(tb) + 1, ta[3] - (MSB(tb) - ta[2] + 1), stageno, z_style)
      to_list += [to]

    if(ta[2] > tb[2]):
      #   ta +-------+
      #   tb     +-------+
      # tb_l          +--+
      to = (tb[0], tb[1], tb[2], ta[2] - tb[2], stageno, z_style)
      to_list += [to]
      if(ta[0] == tb[0]): # same sign: ta_l + tb_u = t_ov = 2 ta_l = 2 tb_u
        #   ta +-------+
        #   tb     +-------+
        # t_ov    +---+
        to = (ta[0], ta[1], ta[2] + 1, MSB(tb) - ta[2] + 1, stageno, z_style)
        to_list += [to]
    elif(tb[2] > ta[2]):
      #   ta +-----------+
      #   tb     +---+
      # ta_l          +--+
      to = (ta[0], ta[1], ta[2], tb[2] - ta[2], stageno, z_style)
      to_list += [to]
      if(ta[0] == tb[0]): # same sign: ta_m + tb = t_ov = 2 ta_m = 2 tb
        #   ta +-----------+
        #   tb     +---+
        # t_ov    +---+
        to = (tb[0], tb[1], tb[2] + 1, tb[3], stageno, z_style)
        to_list += [to]
    else: # ta[2] == tb[2]
      if(ta[0] == tb[0]): # same sign: ta_l + tb = t_ov = 2 ta_l = 2 tb
        #   ta +-------+
        #   tb     +---+
        # t_ov    +---+
        to = (tb[0], tb[1], tb[2] + 1, tb[3], stageno, z_style)
        to_list += [to]    

    return True, to_list



########## Token: (sign, vp, exp, len, stageno, z_style)            ##########
########## tk = sign * Z_{z_style, stageno} [vp+len-1 : vp] * 2^exp ##########
def shifting_reduction_single_stage_gen(number, power, stageno, z_style):
  n_naf = evaluate_naf(number)
  token_list = ([], [])
  (abspower, insign) = (power, 1) if (power > 0) else (-power, -1)
  for idx0 in range(abspower):
    pow_idx0 = int(pow(2,idx0))
    pow_idx0_minus = int(pow(2, idx0-1))
    exact_power_flag = (pow_idx0 > number) and (pow_idx0_minus <= number)
    np = int(pow(2, idx0)) % number
    nn = (number - np) % number
    if((idx0 == abspower - 1) and (insign == -1)):
      np, nn = nn, np
      signstr = '-'
    else:
      signstr = ' '
    np_naf = evaluate_naf(np)
    hw_np = sum([abs(np_naf[idx1]) for idx1 in range(len(np_naf))])
    nn_naf = evaluate_naf(nn)
    hw_nn = sum([abs(nn_naf[idx1]) for idx1 in range(len(nn_naf))])
    # if((len(np_naf) + hw_np <= len(nn_naf) + hw_nn) and (not exact_power_flag)):
    if (len(np_naf) + hw_np <= len(nn_naf) + hw_nn):
      # print('DEBUG: {}2^{} == {} (mod {}) is selected, _naf = {}'.format(signstr if (idx0 == abspower - 1) else '', idx0, np, number, np_naf))
      for idx1 in range(len(np_naf)):
        if(np_naf[idx1] > 0):
          token = (1 if z_style >= 0 else -1, idx0, idx1, 1, stageno, z_style)
          tf, to_list = False, []
          for t_in_l in token_list[0]:
            tf, to_list = integrate_sync_vectors(t_in_l, token)
            if(tf):
              token_list[0].remove(t_in_l)
              for tx in to_list:
                token_list[0].append(tx)
              break
          if(not tf):
            token_list[0].append(token)
          # token_list[0].append((1, idx0, idx1, 1, stageno, z_style))
        elif(np_naf[idx1] < 0):
          token = (-1 if z_style >= 0 else 1, idx0, idx1, 1, stageno, z_style)
          tf, to_list = False, []
          for t_in_l in token_list[1]:
            tf, to_list = integrate_sync_vectors(t_in_l, token)
            if(tf):
              token_list[1].remove(t_in_l)
              for tx in to_list:
                token_list[1].append(tx)
              break
          if(not tf):
            token_list[1].append(token)
          # token_list[1].append((-1, idx0, idx1, 1, stageno, z_style))
    else:
      # print('DEBUG: {}2^{} == {} (mod {}) is selected, _naf = {}'.format(signstr if (idx0 == abspower - 1) else '', idx0, -nn, number, nn_naf))
      for idx1 in range(len(nn_naf)):
        if(nn_naf[idx1] > 0):
          token = (-1 if z_style >= 0 else 1, idx0, idx1, 1, stageno, z_style)
          tf, to_list = False, []
          for t_in_l in token_list[1]:
            tf, to_list = integrate_sync_vectors(t_in_l, token)
            if(tf):
              token_list[1].remove(t_in_l)
              for tx in to_list:
                token_list[1].append(tx)
              break
          if(not tf):
            token_list[1].append(token)
          # token_list[1].append((-1, idx0, idx1, 1, stageno, z_style))
        elif(nn_naf[idx1] < 0):
          token = (1 if z_style >= 0 else -1, idx0, idx1, 1, stageno, z_style)
          tf, to_list = False, []
          for t_in_l in token_list[0]:
            tf, to_list = integrate_sync_vectors(t_in_l, token)
            if(tf):
              token_list[0].remove(t_in_l)
              for tx in to_list:
                token_list[0].append(tx)
              break
          if(not tf):
            token_list[0].append(token)
          # token_list[0].append((1, idx0, idx1, 1, stageno, z_style))
 
  if(z_style >= 0):
    return token_list
  else:
    return (token_list[1], token_list[0])



# Extract the value of bit p
def extract_p(stage_detail, power):
  pos_value = 0
  neg_value = 0
  for token in stage_detail[0]+stage_detail[1]:
    if (token[1] <= power) and (token[1] + token[3] - 1 >= power):
      if(token[0] > 0):
        pos_value += (1 << (token[2] + power - token[1]))
      else:
        neg_value += (1 << (token[2] + power - token[1]))
  return pos_value, neg_value



# evaluate the range of the reduction plan with given last-stage range
def evaluate_reduction_range(stage_detail, power, last_pos_max, last_neg_max, z_style = 0):
  if (power > 0):
    abs_power = power
    sign_power = 1
  elif (power < 0):
    abs_power = -power
    sign_power = -1
  else: # power == 0
    return last_pos_max, last_neg_max

  if(z_style > 0):
    if((last_pos_max >= 0) and (last_pos_max < ((1 << abs_power) - 1))):
      # not-full enumeration
      neg_max = last_neg_max if (last_neg_max >= 0) else 0

      l_pm = last_pos_max.bit_length()
      pos_max_1, neg_max_1 = evaluate_reduction_range(stage_detail, l_pm - 1, -1, 0, 1)
      
      last_pos_max_minus = last_pos_max - (1 << (l_pm - 1))
      l_pm_minus = last_pos_max_minus.bit_length()
      pos_msb, neg_msb = extract_p(stage_detail, l_pm - 1)
      pos_lsb, neg_lsb = evaluate_reduction_range(stage_detail, l_pm_minus, last_pos_max_minus, 0, 1)
      pos_max_2 = pos_msb + pos_lsb
      neg_max_2 = neg_msb + neg_lsb

      pos_max = max(pos_max_1, pos_max_2)
      neg_max += max(neg_max_1, neg_max_2)
      return pos_max, neg_max

  elif(z_style < 0):
    if((last_neg_max != -1) and (last_neg_max < ((1 << abs_power) - 1))):
      # not-full enumeration
      pos_max = last_pos_max if (last_pos_max >= 0) else 0

      l_nm = last_neg_max.bit_length()
      pos_max_1, neg_max_1 = evaluate_reduction_range(stage_detail, l_nm - 1, 0, -1, -1)
      
      last_neg_max_minus = last_neg_max - (1 << (l_nm - 1))
      l_nm_minus = last_neg_max_minus.bit_length()
      pos_msb, neg_msb = extract_p(stage_detail, l_nm - 1)
      pos_lsb, neg_lsb = evaluate_reduction_range(stage_detail, l_nm_minus, 0, last_neg_max_minus, -1)
      pos_max_2 = pos_msb + pos_lsb
      neg_max_2 = neg_msb + neg_lsb

      pos_max += max(pos_max_1, pos_max_2)
      neg_max = max(neg_max_1, neg_max_2)
      return pos_max, neg_max

  pos_max = last_pos_max if ((last_pos_max >= 0) and z_style < 0) else 0
  neg_max = last_neg_max if ((last_neg_max >= 0) and z_style > 0) else 0
  # print('DEBUG: pos_max = {}, neg_max = {}'.format(pos_max, neg_max))
  for token in stage_detail[0]:
    if (token[1] <= abs_power - 1):
      if (token[1] + token[3] >= abs_power):
        pos_token = (1 << token[2]) * ((1 << (abs_power - token[1])) - 1)
      else:
        pos_token = (1 << token[2]) * ((1 << token[3]) - 1)
      # print('DEBUG: token = {}, pos_token = {}'.format(token, pos_token))
      pos_max += pos_token
  for token in stage_detail[1]:
    if (token[1] <= abs_power - 1):
      if (token[1] + token[3] >= abs_power):
        neg_token = (1 << token[2]) * ((1 << (abs_power - token[1])) - 1)
      else:
        neg_token = (1 << token[2]) * ((1 << token[3]) - 1)
      # print('DEBUG: token = {}, neg_token = {}'.format(token, neg_token))
      neg_max += neg_token

  return pos_max, neg_max



# evaluate the range of the FULL reduction plan
def evaluate_full_reduction_range(stage_list):
  pos_max_list, neg_max_list = [], []
  for idx0, stage in enumerate(stage_list):
    MSB_stage = 0
    MSB_pstage = 0 if len(stage[1]) == 0 else MSB_full(max(stage[1], key=MSB_full))
    MSB_nstage = 0 if len(stage[2]) == 0 else MSB_full(max(stage[2], key=MSB_full))
    if(MSB_pstage > MSB_stage): MSB_stage = MSB_pstage
    if(MSB_nstage > MSB_stage): MSB_stage = MSB_nstage
    MSB_stage += 1
    if(idx0 == 0):
      pos_max, neg_max = evaluate_reduction_range((stage[1], stage[2]), MSB_stage, -1, -1, stage[0])
    else:
      pos_max, neg_max = evaluate_reduction_range((stage[1], stage[2]), MSB_stage, pos_max_list[-1], neg_max_list[-1], stage[0])
    pos_max_list += [pos_max]
    neg_max_list += [neg_max]
    # print('DEBUG: (Stage {}) pos_max = {}, neg_max = {}'.format(idx0, pos_max, neg_max))
  return pos_max_list, neg_max_list



# shifting reduction plan generation to the interval [-(3n-1)/2, (3n-1)/2] in the signed case and [-n+1, 0, 2n-1]
def shifting_reduction_gen(number, power, sred_flag):
  global interval_signed_pos_check, interval_unsigned_pos_check, interval_signed_neg_check, interval_unsigned_neg_check

  def interval_pos_check(pm, sf):
    if(sf):
      return interval_signed_pos_check(pm)
    else:
      return interval_unsigned_pos_check(pm)

  def interval_neg_check(nm, sf):
    if(sf):
      return interval_signed_neg_check(nm)
    else:
      return interval_unsigned_neg_check(nm)

  def interval_check(pm, nm, sf):
    if(sf):
      if (interval_signed_pos_check(pm) or interval_signed_neg_check(nm)):
        return True
      else:
        return False
    else:
      if (interval_unsigned_pos_check(pm) or interval_unsigned_neg_check(nm)):
        return True
      else:
        return False

  stage_list = []
  stageno = 0

  abs_power = -power if power < 0 else power
  sign_power = 1 if power > 0 else -1 if power < 0 else 0
  cur_power = power
  last_max = [ ( ((1 << (abs_power-1)) - 1) if sign_power < 0 else ((1 << abs_power) - 1), (1 << (abs_power-1))      if sign_power < 0 else 0 ) ]
  pcheck_f = True
  ncheck_f = True
  z_style = 0

  while(interval_check(last_max[-1][0], last_max[-1][1], sred_flag) and stageno <= 9):
    pos_max, neg_max = 0,0
    # print('DEBUG: stageno = {}, last_pos_max = {}, last_neg_max = {}'.format(stageno, last_max[-1][0], last_max[-1][1]))
    if(stageno == 0):
      stage_detail = shifting_reduction_single_stage_gen(number, cur_power, 0, 0)
      pos_max, neg_max = evaluate_reduction_range(stage_detail, abs(cur_power), -1, -1, 0)
    else:
      if(z_style == 0):
        stage_detail = shifting_reduction_single_stage_gen(number, cur_power, stageno, 0)
        pos_max, neg_max = evaluate_reduction_range(stage_detail, abs(cur_power), -1, -1, 0)
      elif(z_style > 0):
        stage_detail = shifting_reduction_single_stage_gen(number, cur_power, stageno, 1)
        pos_max, neg_max = evaluate_reduction_range(stage_detail, abs(cur_power), last_max[-1][0], last_max[-1][1], 1)
      else: # (z_style < 0)
        stage_detail = shifting_reduction_single_stage_gen(number, cur_power, stageno, -1)
        pos_max, neg_max = evaluate_reduction_range(stage_detail, abs(cur_power), last_max[-1][0], last_max[-1][1], -1)
    stage_list.append((z_style, stage_detail[0], stage_detail[1]))
    # print('DEBUG: stage_detail[0] = {}'.format(stage_detail[0]))
    # print('DEBUG: stage_detail[1] = {}'.format(stage_detail[1]))
    # print('DEBUG: pos_max == {}, neg_max == {}'.format(pos_max, neg_max))
    pcheck_f = interval_pos_check(pos_max, sred_flag)
    ncheck_f = interval_neg_check(neg_max, sred_flag)
    # print('DEBUG: pcheck_f == {}, ncheck_f == {}'.format(pcheck_f, ncheck_f))
    if(pcheck_f and (not ncheck_f)):
      z_style = 1
      cur_power = pos_max.bit_length()
    elif((not pcheck_f) and ncheck_f):
      z_style = -1
      cur_power = neg_max.bit_length()
    else:
      z_style = 0
      if(pos_max > neg_max - 1):
        cur_power = pos_max.bit_length() + 1
      else:
        neg_max_minus = neg_max - 1
        cur_power = neg_max_minus.bit_length() + 1
    if ((pos_max, neg_max) in last_max) and is_2pow_minus1(pos_max):
      rp_idx = last_max.index((pos_max, neg_max))
      stage_list = stage_list[:rp_idx]
      # print('DEBUG: bound repeats -> STOP iterating at stageno = {}'.format(stageno))
      break
    else:
      last_max += [(pos_max, neg_max)]
      stageno += 1
    # print('')
    # print('DEBUG: cur_power = {}, last_pos_max = {}, last_neg_max = {}'.format(cur_power, last_pos_max, last_neg_max))

  return stage_list



# def verify_interval(PID, rv, number, sign_power, range_power, tlist, offset):
#   r = int(pow(2, range_power))
#   for idx1 in range(r):
#     value = offset + idx1
# 
#     value_mod = value % number
# 
#     bin_value = bin_signed_representation(value, sign_power)
# 
#     value_combine = 0
#     for token in tlist:
#       value_token = 0
#       for idx2 in range(token[3]):
#         try:
#           value_token += token[0] * bin_value[token[1] + idx2] * pow(2, token[2] + idx2)
#         except:
#           print('DEBUG: ERROR at token = {} and idx2 = {}'.format(token, idx2), file=sys.stderr)
#           print('                bin_value = {}'.format(bin_value), file=sys.stderr)
#           rv[PID] = 1
#           return False
# 
#       value_token %= number
#       value_combine += value_token
#     value_combine %= number
#     if (value_mod != value_combine):
#       print('DEBUG: ERROR at value = {}'.format(value), file=sys.stderr)
#       print('                value_mod = {}, value_combine = {}'.format(value_mod, value_combine), file=sys.stderr)
#       rv[PID] = 1
#       return False
# 
#     # if ((PID == 0) and ((sum(rv) // 1024) + (sum(rv) % 1024)) == 0):
#     if (PID == 0):
#       rate = float(idx1) / float(r) * 100
#       if(idx1 % 1024 == 0):
#         print('\r{:4.1f}% checked......               '.format(rate), end='', file=sys.stderr)
# 
#   rv[PID] = 1024
#   return True
# 
# def verify_tlist(number, power, tlist):
#   core_count = os.cpu_count()
#   core_depth = len(bin_representation(core_count)) - 1 - 1
#   core_depth = 0 if core_depth < 0 else core_depth
#   core_power = int(pow(2, core_depth))
# 
#   plist = []
# 
#   if(power > 0):
#     min_pow_value = 0
#     ppower = power
#   else:
#     min_pow_value = - pow(2, -power-1)
#     ppower = -power
# 
#   returnValue = Array('i', [0] * core_power)
# 
#   pow_step = ppower - core_depth
#   pow_offset = int(pow(2, pow_step))
#   for idx in range(core_power):
#     process = Process(target=verify_interval, args=(idx, returnValue, number, ppower, pow_step, tlist, min_pow_value + pow_offset * idx))
#     process.start()
#     plist += [process]
#   ErrorFlag = True
#   while((sum(returnValue) // 1024) + (sum(returnValue) % 1024) < core_power):
#     for idx, process in enumerate(plist):
#       if ( not process.is_alive() ):
#         if(returnValue[idx] == 1):
#           ErrorFlag = False
#           break
#     if(ErrorFlag == False):
#       break
#     finishprocess = (sum(returnValue) // 1024) + (sum(returnValue) % 1024)
#     if (finishprocess != 0):
#      print('\r {:d} processes finished......'.format(finishprocess), end='', file=sys.stderr)
#   for process in plist:
#     plist.remove(process)
#   return ErrorFlag



# Analyze the stages into variable list
def analyze_stages(stage_list, number):
  var_lists = []
  naf_n = evaluate_naf(number)
  l_n = len(naf_n)
  # l_n = number.bit_length()
  # n_r = (1 << l_n)

  for idx0, stage in enumerate(stage_list):
    z_style = stage[0]
    stageP = stage[1]
    stageP.sort(key=lambda x: (x[0], -MSB(x), -x[2]), reverse=True)
    stageN = stage[2]
    stageN.sort(key=lambda x: (x[0], -MSB(x), -x[2]), reverse=True)

    # print('DEBUG: stageP = {}'.format(stageP))
    # print('DEBUG: stageN = {}'.format(stageN))

    var_list = (z_style, [], [])

    for token in stageP + stageN:
      # print('DEBUG: For token', token, ': ')
      sgn_idx = 1 if token[0] > 0 else 2
      var_idx = 0
      var_flag = False
      if (len(var_list[sgn_idx]) > 0):
        for var_idx, variable in enumerate(var_list[sgn_idx]):
          if(token[2] >= variable[0]):
            var_flag = True
            break
      # print('var_idx = {} ; '.format(var_idx), end='')
      if(not var_flag):
        nvar_array = [-1] * l_n
        for idx_nv in range(token[3]):
          nvar_array[token[2] + idx_nv] = token[1] + idx_nv
        var_list[sgn_idx].append((MSB(token)+1, nvar_array))
      else:
        nvar_array = var_list[sgn_idx][var_idx][1]
        for idx_nv in range(token[3]):
          nvar_array[token[2] + idx_nv] = token[1] + idx_nv
        var_list[sgn_idx][var_idx] = (MSB(token)+1, nvar_array)
      # print('       var_list = ', var_list)

    # print(var_list)

    var_lists.append(var_list)

  # for idx0 in range(len(var_lists)):
  #   print(    'DEBUG: var_lists[{:>2d}] = ( {},'.format(idx0, var_lists[idx0][0]))
  #   print(    '                         [', end='')
  #   for idx1 in range(len(var_lists[idx0][1])):
  #     if(idx1 != 0):
  #       print(', ')
  #       print('                          ', end='')
  #     print('{}'.format(var_lists[idx0][1][idx1]), end='')
  #   print('], ')
  #   print(    '                         [', end='')
  #   for idx1 in range(len(var_lists[idx0][2])):
  #     if(idx1 != 0):
  #       print(', ')
  #       print('                          ', end='')
  #     print( '{}'.format(var_lists[idx0][2][idx1]), end='')
  #   print('] )')

  return var_lists



########## reduction plan -> RTL in verilog converter    ##########
########## Token: (sign, vp, exp, len, stageno, z_style) ##########

module_template = 'mod{n:d}{ti}{to}{p:d}'

def gen_rtl(stage_list, stage_var_list, number, power, sred_flag):
  global f_fd

  l_n = number.bit_length()
  n_r = (1 << l_n)
  (abs_power, sign_power) = (power, 1) if power >= 0 else (-power, -1)

  pos_max_list, neg_max_list = evaluate_full_reduction_range(stage_list)

  module_name = module_template.format(n=number, ti=('S' if sign_power < 0 else 'U'), to=('S' if sred_flag else 'U'), p=abs(power))

  module_file = Path(module_name + '_shifting.v')

  with module_file.open(mode='w') as f_fd:
    fprint(      'module ' + module_name + ' (')
    fprint(      '  input                       clk,')
    fprint(      '  input                       rst,')
    if(sign_power):
      fprint(    '  input             [{n_msb:<2d} : 0]  inZ,'.format(n_msb = abs_power - 1))
    else:
      fprint(    '  input signed      [{n_msb:<2d} : 0]  inZ,'.format(n_msb = abs_power - 1))
    if(sred_flag):
      fprint(    '  output reg signed [{n_msb:<2d} : 0]  outZ'.format(n_msb = l_n - 1))
    else:
      fprint(    '  output reg        [{n_msb:<2d} : 0]  outZ'.format(n_msb = l_n - 1))
    fprint(      ') ;')
    fprint(      '')

    fprint(      '  localparam FULL_Q  = \'sd{};'.format(number))
    fprint(      '  localparam FULL_Q2 = \'sd{};'.format(number*2))
    if(sred_flag):
      fprint(    '  localparam HALF_Q  = \'sd{};'.format((number-1)//2))
      fprint(    '  localparam HALF_Q3 = \'sd{};'.format((3*number-1)//2))
    fprint(      '')

    if(sign_power):
      fprint(    '  wire signed       [{n_msb:<2d} : 0]  mZ;'.format(n_msb = abs_power - 1))
      fprint(    '  // reg signed        [{n_msb:<2d} : 0]  mZ;'.format(n_msb = abs_power - 1))
    else:
      fprint(    '  wire              [{n_msb:<2d} : 0]  mZ;'.format(n_msb = abs_power - 1))
      fprint(    '  // reg               [{n_msb:<2d} : 0]  mZ;'.format(n_msb = abs_power - 1))
    fprint(      '')

    if(sred_flag): # signed reduction: -(3n-1)//2 <= v <= (3n-1)//2
      if(pos_max_list[-1] > ((3*number-1) // 2)):
        pos_max_over = 2
      elif(pos_max_list[-1] > ((number-1) // 2)):
        pos_max_over = 1
      else:
        pos_max_over = 0
      # pos_max_over  = (pos_max_list[-1] > ((number - 1) // 2))
      neg_max_over  = (neg_max_list[-1] > ((number - 1) // 2))
    else: # unsigned reduction:
      if(pos_max_list[-1] >= 2*number):
        pos_max_over = 2
      elif(pos_max_list[-1] >= number):
        pos_max_over = 1
      else:
        pos_max_over = 0
      # pos_max_over  = (pos_max_list[-1] > number - 1)
      neg_max_over  = True

    endstageno = len(stage_list) - 1
    final_var = 'mZ{}_reg'.format(endstageno)

    for idx0, (pos_max, neg_max, stage_var) in enumerate(zip(pos_max_list, neg_max_list, stage_var_list)):
      var_prefix = 'mZ{}'.format(idx0)

      for idx1, var_token in enumerate(stage_var[1]):
        dl_str = '  wire              [{:<2d} : 0]  ' + var_prefix + '_p{};';
        fprint(dl_str.format(var_token[0]-1, idx1))

      # if((stage_var[0] < 0) or (len(stage_var[1]) != 0)):
      if(pos_max > 0):
        dl_str = '  wire              [{:<2d} : 0]  ' + var_prefix + '_p;';
        fprint(dl_str.format(pos_max.bit_length()-1));
        dl_str = '  reg               [{:<2d} : 0]  ' + var_prefix + '_p_reg;';
        fprint(dl_str.format(pos_max.bit_length()-1));

      for idx1, var_token in enumerate(stage_var[2]):
        dl_str = '  wire              [{:<2d} : 0]  ' + var_prefix + '_n{};';
        fprint(dl_str.format(var_token[0]-1, idx1))

      # if((stage_var[0] > 0) or len(stage_var[2]) != 0):
      if(neg_max > 0):
        dl_str = '  wire              [{:<2d} : 0]  ' + var_prefix + '_n;';
        fprint(dl_str.format(neg_max.bit_length()-1));
        dl_str = '  reg               [{:<2d} : 0]  ' + var_prefix + '_n_reg;';
        fprint(dl_str.format(neg_max.bit_length()-1));

      max_len = max(pos_max.bit_length(), neg_max.bit_length()) + 1;
      dl_str =   '  wire signed       [{:<2d} : 0]  ' + var_prefix + ';';
      fprint(dl_str.format(max_len - 1));
      dl_str =   '  reg signed        [{:<2d} : 0]  ' + var_prefix + '_reg;';
      fprint(dl_str.format(max_len - 1));
      fprint(    '')

    if (pos_max_over > 0):
      fprint(    '  wire                        fPos;')
      if(pos_max_over > 1):
        fprint(  '  wire                        fPos2;')
    if (neg_max_over):
      fprint(    '  wire                        fNeg;')
    if (pos_max_over == 2):
      fprint(    '  reg signed        [{:<2d} : 0]  qshift;'.format(number.bit_length() + 2))
      fprint('')
    elif ((pos_max_over > 0) or neg_max_over):
      fprint(    '  reg signed        [{:<2d} : 0]  qshift;'.format(number.bit_length() + 1))
      fprint('')

    fprint(    '  assign mZ = inZ;')
    fprint(    '  //always @ ( posedge clk ) begin')
    fprint(    '  //  if(rst) begin')
    fprint(    '  //    mZ <= \'sd0;')
    fprint(    '  //  end else begin')
    fprint(    '  //    mZ <= inZ;')
    fprint(    '  //  end')
    fprint(    '  //end')
    fprint(    '')

    for idx0, (pos_max, neg_max, stage_var) in enumerate(zip(pos_max_list, neg_max_list, stage_var_list)):
      var_prefix = 'mZ{}'.format(idx0)
      if(stage_var[0] > 0):
        last_red_var = 'mZ{}_p_reg'.format(idx0-1)
        last_res_var = 'mZ{}_n_reg'.format(idx0-1)
      elif(stage_var[0] < 0):
        last_red_var = 'mZ{}_n_reg'.format(idx0-1)
        last_res_var = 'mZ{}_p_reg'.format(idx0-1)
      else: # stage_var[0] == 0
        last_red_var = 'mZ{}_reg'.format(idx0-1)
        last_res_var = ''
      last_red_var = 'mZ' if(idx0 == 0) else last_red_var

      if(pos_max > 0):
        sum_str =  '  assign ' + var_prefix + '_p = '
        for idx1, var_token in enumerate(stage_var[1]):
          as_str = '  assign ' + var_prefix + '_p{} = '.format(idx1) + '{ '
          for idx2 in range(var_token[0]-1, -1, -1):
            if(idx2 != var_token[0] - 1): as_str += ', '
            v_idx = var_token[1][idx2]
            if(v_idx == -1):
              as_str += '1\'b0'
            else:
              as_str += last_red_var + '[{}]'.format(v_idx)
          as_str += ' };'
          fprint(as_str)
          if(idx1 != 0):
            sum_str += ' + '
          sum_str += var_prefix + '_p{}'.format(idx1)
        if(stage_var[0] < 0):
          if(len(stage_var[1]) != 0):
            sum_str += ' + '
          sum_str += last_res_var
        if((len(stage_var[1]) == 0) and (stage_var[0] >= 0)):
          sum_str += ' \'d0'
        sum_str += ';'
        fprint(sum_str)
        fprint(  '')

        fprint(  '  always @ ( posedge clk ) begin')
        fprint(  '    if(rst) begin')
        fprint(  '      ' + var_prefix + '_p_reg <= \'b0;')
        fprint(  '    end else begin')
        fprint(  '      ' + var_prefix + '_p_reg <= ' + var_prefix + '_p;')
        fprint(  '    end')
        fprint(  '  end')
        fprint(  '')

      if(neg_max > 0):
        sum_str = '  assign ' + var_prefix + '_n = '
        for idx1, var_token in enumerate(stage_var[2]):
          as_str = '  assign ' + var_prefix + '_n{} = '.format(idx1) + '{ '
          for idx2 in range(var_token[0]-1, -1, -1):
            if(idx2 != var_token[0] - 1): as_str += ', '
            v_idx = var_token[1][idx2]
            if(v_idx == -1):
              as_str += '1\'b0'
            else:
              as_str += last_red_var + '[{}]'.format(v_idx)
          as_str += ' };'
          fprint(as_str)
          if(idx1 != 0):
            sum_str += ' + '
          sum_str += var_prefix + '_n{}'.format(idx1)
        if(stage_var[0] > 0):
          if(len(stage_var[2]) != 0):
            sum_str += ' + '
          sum_str += last_res_var
        if((len(stage_var[2]) == 0) and (stage_var[0] <= 0)):
          sum_str += ' \'d0'
        sum_str += ';'
        fprint(sum_str)
        fprint(  '')

        fprint(  '  always @ ( posedge clk ) begin')
        fprint(  '    if(rst) begin')
        fprint(  '      ' + var_prefix + '_n_reg <= \'b0;')
        fprint(  '    end else begin')
        fprint(  '      ' + var_prefix + '_n_reg <= ' + var_prefix + '_n;')
        fprint(  '    end')
        fprint(  '  end')
        fprint(  '')

      fprint(    '  always @ ( posedge clk ) begin')
      fprint(    '    if(rst) begin')
      fprint(    '      ' + var_prefix + '_reg <= \'b0;')
      fprint(    '    end else begin')
      if(pos_max == 0):
        fprint(  '      ' + var_prefix + '_reg <= -' + var_prefix + '_n;')
      elif(neg_max == 0):
        fprint(  '      ' + var_prefix + '_reg <= ' + var_prefix + '_p;')
      else:
        fprint(  '      ' + var_prefix + '_reg <= ' + var_prefix + '_p - ' + var_prefix + '_n;')
      fprint(    '    end')
      fprint(    '  end')
      fprint(    '')

    if(sred_flag): # signed reduction : -(2n-1)//2 <= v <= (3n-1)//2
      if (pos_max_over > 0):
        fprint(  '  assign fPos = (' + final_var + ' > HALF_Q);')
      if (pos_max_over > 1):
        fprint(  '  assign fPos2 = (' + final_var + ' > HALF_Q3);')
      if (neg_max_over):
        fprint(  '  assign fNeg = (' + final_var + ' < -HALF_Q);')
      fprint(    '')
      if ((pos_max_over == 2) and neg_max_over):
        fprint(  '  always @ (*) begin')
        fprint(  '    casez({ fNeg, fPos2, fPos })')
        fprint(  '      3\'b1xx:   qshift =  FULL_Q;')
        fprint(  '      3\'b01x:   qshift = -FULL_Q2;')
        fprint(  '      3\'b001:   qshift = -FULL_Q;')
        fprint(  '      default:  qshift = \'sd0;')
        fprint(  '    endcase')
        fprint(  '  end')
        fprint(  '')
      elif ((pos_max_over == 1) and neg_max_over):
        fprint(  '  always @ (*) begin')
        fprint(  '    casez({ fNeg, fPos })')
        fprint(  '      2\'b1x:   qshift =  FULL_Q;')
        fprint(  '      2\'b01:   qshift = -FULL_Q;')
        fprint(  '      default: qshift = \'sd0;')
        fprint(  '    endcase')
        fprint(  '  end')
        fprint(  '')
      elif ((pos_max_over == 2) and (not neg_max_over)):
        fprint(  '  always @ (*) begin')
        fprint(  '    casez({ fPos2, fPos })')
        fprint(  '      2\'b1x:   qshift = -FULL_Q2;')
        fprint(  '      2\'b01:   qshift = -FULL_Q;')
        fprint(  '      default: qshift = \'sd0;')
        fprint(  '    endcase')
        fprint(  '  end')
        fprint(  '')
      elif ((pos_max_over == 1) and (not neg_max_over)):
        fprint(  '  always @ (*) begin')
        fprint(  '    if(fPos)')
        fprint(  '      qshift = -FULL_Q;')
        fprint(  '    else')
        fprint(  '      qshift = \'sd0;')
        fprint(  '  end')
        fprint(  '')
      elif (neg_max_over): # pos_max_over == 0
        fprint(  '  always @ (*) begin')
        fprint(  '    if(fNeg)')
        fprint(  '      qshift = FULL_Q;')
        fprint(  '    else')
        fprint(  '      qshift = \'sd0;')
        fprint(  '  end')
        fprint(  '')
    else: # unsigned reduction
      if (pos_max_over > 0):
        fprint(  '  assign fPos = (' + final_var + ' >= FULL_Q);')
      if (pos_max_over > 1):
        fprint(  '  assign fPos2 = (' + final_var + ' >= FULL_Q2);')
      fprint(  '  assign fNeg = (' + final_var + ' < 0;')
      fprint(    '')
      if (pos_max_over == 2):
        fprint(  '  always @ (*) begin')
        fprint(  '    casez({ fNeg, fPos2, fPos })')
        fprint(  '      3\'b1xx:   qshift =  FULL_Q;')
        fprint(  '      3\'b01x:   qshift = -FULL_Q2;')
        fprint(  '      3\'b001:   qshift = -FULL_Q;')
        fprint(  '      default:  qshift = \'sd0;')
        fprint(  '    endcase')
        fprint(  '  end')
        fprint(  '')
      elif (pos_max_over == 1):
        fprint(  '  always @ (*) begin')
        fprint(  '    casez({ fNeg, fPos })')
        fprint(  '      2\'b10:   qshift =  FULL_Q;')
        fprint(  '      2\'b01:   qshift = -FULL_Q;')
        fprint(  '      default: qshift = \'sd0;')
        fprint(  '    endcase')
        fprint(  '  end')
        fprint(  '')
      else:
        fprint(  '  always @ (*) begin')
        fprint(  '    if(fNeg)')
        fprint(  '      qshift = FULL_Q;')
        fprint(  '    else')
        fprint(  '      qshift = \'sd0;')
        fprint(  '  end')
        fprint(  '')


    if ((pos_max_over > 0) or neg_max_over):
      fprint(    '  always @ (*) begin')
      fprint(    '    outZ = ' + final_var + ' + qshift;')
      fprint(    '  end')
      fprint(    '  //always @ ( posedge clk ) begin')
      fprint(    '  //  if(rst) begin')
      fprint(    '  //    outZ <= \'sd0;')
      fprint(    '  //  end else begin')
      fprint(    '  //    outZ <= ' + final_var + ' + qshift;')
      fprint(    '  //  end')
      fprint(    '  //end')
    else:
      fprint(    '  always @ (*) begin')
      fprint(    '    outZ = ' + final_var + ';')
      fprint(    '  end')
      fprint(    '  //always @ ( posedge clk ) begin')
      fprint(    '  //  if(rst) begin')
      fprint(    '  //    outZ <= \'sd0;')
      fprint(    '  //  end else begin')
      fprint(    '  //    outZ <= ' + final_var + ';')
      fprint(    '  //  end')
      fprint(    '  //end')
    fprint(      '')

    fprint(      'endmodule')
    fprint(      '')

  return



def gen_tb(stage_list, number, power, sred_flag):
  global f_fd

  l_n = number.bit_length()
  n_r = (1 << l_n)
  (abs_power, sign_power) = (power, 1) if power >= 0 else (-power, -1)
  number12 = (number - 1) // 2

  stagecount = len(stage_list)

  module_name = module_template.format(n=number, ti=('S' if sign_power < 0 else 'U'), to=('S' if sred_flag else 'U'), p=abs(power))

  mk_file = Path('Makefile')
  with mk_file.open(mode='w') as f_fd:
    fprint('SIMULATOR = vcs')
    fprint('ARGUMENT = -full64 -R -debug_access+all +v2k')
    fprint('')
    fprint('VCSRC = /usr/cad/synopsys/CIC/vcs.cshrc')
    fprint('VERDIRC = /usr/cad/synopsys/CIC/verdi.cshrc')
    fprint('')
    fprint('TESTBENCH = ' + module_name + '_tb.v')
    fprint('SOURCE = ' + module_name + '_shifting.v')
    fprint('')
    fprint('.PHONY: clean all ' + module_name)
    fprint('')
    fprint('all: ' + module_name)
    fprint('')
    fprint(module_name + ': $(TESTBENCH) $(SOURCE)')
    fprint('\tcsh -c \'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(TESTBENCH) $(SOURCE) $(ARGUMENT)\'')
    fprint('')
    fprint('clean:')
    fprint('\trm -rf INCA_libs')
    fprint('\trm -rf csrc')
    fprint('\trm -rf simv.daidir')
    fprint('\trm -rf xcelium.d')
    fprint('\trm -rf nWaveLog')
    fprint('\trm -f *.fsdb ncverilog.history ncverilog.log novas.conf novas.rc novas_dump.log ucli.key simv')
  f_fd.close()


  tb_file = Path(module_name + '_tb.v')
  with tb_file.open(mode='w') as f_fd:
    fprint(      '`timescale 1ns/100ps')
    fprint(      '')
    fprint(      'module ' + module_name + '_tb;')
    fprint(      '')
    fprint(      '  parameter HALFCLK = 5;')
    fprint(      '')
    fprint(      '  /* clock setting */')
    fprint(      '  reg clk;')
    fprint(      '    initial begin')
    fprint(      '    clk=1;')
    fprint(      '  end')
    fprint(      '  always #(HALFCLK) clk<=~clk;')
    fprint(      '')
    fprint(      '  /* vcd file setting */')
    fprint(      '  initial begin')
    fprint(      '    $fsdbDumpfile("' + module_name + '_tb.fsdb");')
    fprint(      '    $fsdbDumpvars;')
    fprint(      '    #10000000000;')
    fprint(      '    $finish;')
    fprint(      '  end')
    fprint(      '')

    fprint(      '  wire [255:0] equals;')
    fprint(      '')
    fprint(      '  wire equal_all;')
    fprint(      '  assign equal = &equals;')
    fprint(      '')

    fprint(      '  genvar prefix;')
    fprint(      '  generate')
    fprint(      '    for(prefix = \'d0; prefix < \'d256; prefix = prefix + \'d1) begin : tester')
    fprint(      '      reg rst;')
    fprint(      '')
    fprint(      '      reg [{:<2d}: 0] postfix;'.format(abs_power-9))
    if(sign_power == 1):
      fprint(    '      wire        [{:<2d}: 0] inZ;'.format(abs_power-1))
    else:
      fprint(    '      wire signed [{:<2d}: 0] inZ;'.format(abs_power-1))

    if(not sred_flag):
      fprint(    '      wire        [{:<2d}: 0] outZ;'.format(l_n-1))
      fprint(    '      wire        [{:<2d}: 0]  outZ_ref;'.format(l_n))
      for idx0 in range(stagecount):
        fprint(  '      reg         [{:<2d}: 0]  outZ_ref_c_r{:d};'.format(l_n, idx0))
    else:
      fprint(    '      wire signed [{:<2d}: 0] outZ;'.format(l_n-1))
      fprint(    '      wire signed [{:<2d}: 0]  outZ_ref;'.format(l_n))
      fprint(    '      wire signed [{:<2d}: 0]  outZ_ref_c;'.format(l_n))
      for idx0 in range(stagecount):
        fprint(  '      reg signed  [{:<2d}: 0]  outZ_ref_c_r{:d};'.format(l_n, idx0))
    fprint(      '')

    fprint(      '      assign inZ = { prefix[7:0], postfix };')
    fprint(      '')
    if(sign_power == 1):
      fprint(    '      assign outZ_ref = inZ % {:d}\'d{:d};'.format(l_n, number))
    else:
      fprint(    '      assign outZ_ref = inZ % {:d}\'sd{:d};'.format(l_n + 1, number))
      fprint(    '      assign outZ_ref_c = (outZ_ref >  {ql:d}\'sd{q12:d}) ? (outZ_ref - {ql:d}\'sd{quo:d}) :'.format(ql=l_n+1,q12=number12,quo=number))
      fprint(    '                          (outZ_ref < -{ql:d}\'sd{q12:d}) ? (outZ_ref + {ql:d}\'sd{quo:d}) : outZ_ref;'.format(ql=l_n+1,q12=number12,quo=number))
    fprint(      '')

    fprint(      '      always @ (posedge clk) begin')
    if(not sred_flag):
      fprint(    '        outZ_ref_c_r0 <= outZ_ref;') 
    else:
      fprint(    '        outZ_ref_c_r0 <= outZ_ref_c;')
    for idx0 in range(1, stagecount):
      fprint(    '        outZ_ref_c_r{} <= outZ_ref_c_r{};'.format(idx0, idx0-1))
    fprint(      '      end')
    fprint(      '')

    fprint(      '      wire equal;')
    fprint(      '      wire equalp;')
    fprint(      '      wire equal0;')
    fprint(      '      wire equaln;')
    fprint(      '')

    if(not sred_flag):
      fprint(    '      assign equalp = ( {{ 1\'b0, outZ }} - {:>2d}\'d{:<5d} == outZ_ref_c_r{} );'.format(l_n+1, number, stagecount-1))
      fprint(    '      assign equal0 = ( {{ 1\'b0, outZ }}              == outZ_ref_c_r{} );'.format(stagecount-1))
      fprint(    '      assign equaln = ( {{ 1\'b0, outZ }} + {:>2d}\'d{:<5d} == outZ_ref_c_r{} );'.format(l_n+1, number, stagecount-1))
    else:
      fprint(    '      assign equalp = ( {{ 1\'b0, outZ }} - {:>2d}\'sd{:<5d} == outZ_ref_c_r{} );'.format(l_n+1, number, stagecount-1))
      fprint(    '      assign equal0 = ( {{ 1\'b0, outZ }}               == outZ_ref_c_r{} );'.format(stagecount-1))
      fprint(    '      assign equaln = ( {{ 1\'b0, outZ }} + {:>2d}\'sd{:<5d} == outZ_ref_c_r{} );'.format(l_n+1, number, stagecount-1))
    fprint(      '')

    fprint(      '      //assign equal = equalp | equal0 | equaln;')
    fprint(      '      assign equal = equal0;')
    fprint(      '')
    fprint(      '      assign equals[prefix] = equal;')
    fprint(      '')

    fprint(      '      integer index;')
    fprint(      '      initial begin')
    fprint(      '')
    fprint(      '        rst = 1\'b0;')
    fprint(      '        #(2*HALFCLK);')
    fprint(      '        rst = 1\'b1;')
    fprint(      '        #(2*HALFCLK);')
    fprint(      '        rst = 1\'b0;')
    fprint(      '')

    pwr_prefix = abs_power % 4
    maxstr = '' if (pwr_prefix == 0) else '1' if (pwr_prefix == 1) else '3' if (pwr_prefix == 2) else '7'
    maxstr += 'f' * ((abs_power // 4) - 2)

    fprint(      '        for (index = \'h0; index <= \'h' + maxstr + '; index = index + \'h1) begin')
    fprint(      '')
    fprint(      '            if (!(index & \'hffff) && (prefix == 0)) $display("index == %x", index);')
    fprint(      '')
    fprint(      '            postfix = index;')
    fprint(      '            #(8*HALFCLK);')
    fprint(      '        end')
    fprint(      '')
    fprint(      '        #(16*HALFCLK);')
    fprint(      '        $display("Test Successful.");')
    fprint(      '        $finish;')
    fprint(      '      end ')
    fprint(      '')

    fprint(      '      ' + module_name + ' mod_inst ( .clk(clk), .rst(rst), .inZ(inZ), .outZ(outZ) );')
    fprint(      '    end // tester')
    fprint(      '  endgenerate')
    fprint(      '')

    fprint(      '  always @ (posedge clk) begin')
    fprint(      '    if(!equal_all) begin')
    fprint(      '      $display("WARNING! equals = %t!", $realtime);')
    fprint(      '      $display("equals = %X", equals);')
    fprint(      '      #(16*HALFCLK);')
    fprint(      '      $finish;')
    fprint(      '    end')
    fprint(      '  end')
    fprint(      '')

    fprint(      'endmodule')
    fprint(      '')
  f_fd.close()


  tcl_file = Path(module_name + '_zedboard.tcl')
  with tcl_file.open(mode='w') as f_fd:
    fprint('create_project ' + module_name + ' ' + module_name + '_zedboard -part xc7z020clg484-1')
    fprint('set_property board_part em.avnet.com:zed:part0:1.4 [current_project]')
    fprint('add_files -norecurse {' + module_name + '_shifting.v}')
    fprint('import_files -force -norecurse')
    fprint('import_files -fileset constrs_1 -force -norecurse ../timing.xdc')
    fprint('update_compile_order -fileset sources_1')
    fprint('update_compile_order -fileset sources_1')
    fprint('launch_runs synth_1 -jobs 64')
    fprint('wait_on_run synth_1')
    fprint('launch_runs impl_1 -jobs 64')
    fprint('wait_on_run impl_1')
    fprint('close_project')
  f_fd.close()


  tcl_file = Path(module_name + '_zcu102.tcl')
  with tcl_file.open(mode='w') as f_fd:
    fprint(    'create_project ' + module_name + ' ' + module_name + '_zcu102 -part xczu9eg-ffvb1156-2-e')
    fprint(    'set_property board_part xilinx.com:zcu102:part0:3.3 [current_project]')
    fprint(    'add_files -norecurse {' + module_name + '_shifting.v}')
    fprint(    'import_files -force -norecurse')
    fprint(    'import_files -fileset constrs_1 -force -norecurse ../timing.xdc')
    fprint(    'update_compile_order -fileset sources_1')
    fprint(    'update_compile_order -fileset sources_1')
    fprint(    'launch_runs synth_1 -jobs 64')
    fprint(    'wait_on_run synth_1')
    fprint(    'launch_runs impl_1 -jobs 64')
    fprint(    'wait_on_run impl_1')
    fprint(    'close_project')
  f_fd.close()

  return



# main function
def __main__():
  parser = argparse.ArgumentParser(description='')
  parser.add_argument('number', metavar='N', type=int, help='Positive integer to evaluate the non-adjacent form.')
  parser.add_argument('power', metavar='P', type=int, help='2 to the power of the MSB; negative value if in signed form')
  parser.add_argument('-s', '--signed', action='store_true', help='Set to apply signed reduction generation. Unset to apply unsigned reduction. (Default)') 
  parser.add_argument('-u', '--unsigned', action='store_true', help='Set to apply unsigned reduction generation. Unset to apply unsigned reduction. [Caution: conflict with -s]') 

  try:
    args = parser.parse_args()

    assert (args.number >= 0), Argument_Error

    assert not (args.signed and args.unsigned), Argument_Error
    if(args.unsigned):
      SRed_Flag = False
    else:
      SRed_Flag = True

    set_interval_check(args.number)

    stage_list = shifting_reduction_gen(args.number, args.power, SRed_Flag)
    print_stage_list(stage_list)
    stage_var_list = analyze_stages(stage_list, args.number)

    gen_rtl(stage_list, stage_var_list, args.number, args.power, SRed_Flag)
    gen_tb(stage_list, args.number, args.power, SRed_Flag)

    # print('Verifying the token list for N = {} and P = {}... '.format(args.number, args.power), flush=True, file=sys.stderr)
    # assert verify_tlist(args.number, args.power, token_list), DEBUG_Verify_Error
    # print('OK!', file=sys.stderr)
  except AssertionError as e:
    if (e == Argument_Error):
      parser.print_help()
    elif (e == DEBUG_Verify_Error):
      print('DEBUG: Verification fail.', file=sys.stderr)
    else:
      print(e, file=sys.stderr)
  # except ValueError:
  #   parser.print_help()

__main__()



