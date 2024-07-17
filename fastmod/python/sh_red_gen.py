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
  interval_unsigned_neg_check = partial(interval_unsigned_check, n=number)
  return





########## reduction plan data structure related functions ##########
########## Token: (sign, vp, exp, len, stageno, z_style)   ##########

# Find the position of MSB of the token
def MSB(x):
  return x[2] + x[3] - 1

# Find the MSB index of the token
def MSB_full(x):
  return x[1] + x[3] - 1



# Print the list storing the stage plan
def print_stage_list(stage_list):
  if(stage_list == []):
    print('NO STAGES')
    return

  stage_combined = []

  for idx0, stage in enumerate(stage_list):
    print('Stage {}:'.format(idx0))
    s_temp = stage[0]
    s_sign = stage[1]

    if (s_sign == 0):
      stage_combined = s_temp.copy()
    else:
      sc_t = stage_combined
      stage_combined = []
      for item in sc_t:
        if(item[0] != s_sign):
          stage_combined.append(item)
      stage_combined += s_temp
      # stage_combined.sort(key=lambda x: (x[4], x[0], x[2], MSB(x)), reverse=True)

    # MSB_all = MSB(max(s_temp, key=MSB))
    MSB_all = MSB(max(stage_combined, key=MSB))

    for idx1 in range(MSB_all, -1, -1):
      print(' {:7d}'.format(idx1), end='')
    print(' ')
    for idx1 in range(MSB_all + 1):
      print('--------', end='')
    print('-')

    # for item in s_temp:
    for item in stage_combined:
      MSB_item = MSB(item)
      for idx1 in range(MSB_all - MSB_item):
        print('        ', end='')
      for idx1 in range(item[3], 0, -1):
        if ( (item[1]+idx1-1 == 0) and (item[0] == -1) ):
          # if(s_sign > 0):
          if(item[5] > 0):
            # print('  -zp{}_0'.format(idx0), end='')
            print('  -zp{}_0'.format(item[4]), end='')
          # elif(s_sign < 0):
          elif(item[5] < 0):
            # print('  -zn{}_0'.format(idx0), end='')
            print('  -zn{}_0'.format(item[4]), end='')
          else:
            # print('   -z{}_0'.format(idx0), end='')
            print('   -z{}_0'.format(item[4]), end='')
        else:
          idx_current = item[1]+idx1-1
          # if(s_sign > 0):
          if(item[5] > 0):
            z_fstr = 'zp{s}_{idx:d}'
          # elif(s_sign < 0):
          elif(item[5] < 0):
            z_fstr = 'zn{s}_{idx:d}'
          else:
            print(' ', end='')
            z_fstr = 'z{s}_{idx:d}'
          if(idx_current < 10):
            print(' ', end='')
          if(item[0] < 0):
            print(' -', end='')
          else:
            print('  ', end='')
          # print(z_fstr.format(s=idx0, idx=idx_current), end='')
          print(z_fstr.format(s=item[4], idx=idx_current), end='')
      print('')

    print('pos_max = {pm:d} (0x{pm:x}; 0b{pm:b}), neg_max = -{nm:d} (0x{nm:x}; 0b{nm:b})'.format(pm=stage[4], nm=stage[5]))

      # print('                                  {}'.format(item))
  return



# evaluate the new token list of the combination of t1 and t2 for the case the ADDITION works
def integrate_sync_vectors(t1, t2):
  if(t1[4] != t2[4]):
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



# evaluate the new token list of the combination of t1 and t2 for the case the SUBTRACTION works
def integrate_subtract_vectors(t1, t2):
  if(t1[4] != t2[4]):
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

  if ((ta[1] - ta[2]) == (tb[1] - tb[2] - 1) and (ta[0] != tb[0])): # partial(ta) = -2 * partial(tb) (part TBD)
  
    # print('DEBUG: ta = {}, tb = {}'.format(ta, tb))

    if (ta[2] > MSB(tb) + 1):
      return False, to_list

    tb_h_select = False
    if (MSB(ta) == MSB(tb)):
      #   ta +---...
      #   tb +----...
      # tb_u +
      to = (tb[0], tb[1] + tb[3] - 1, tb[2] + tb[3] - 1, 1, stageno, z_style)
      to_list += [to]
      tb_h_select = True
    elif (MSB(ta) != MSB(tb) + 1):
      #   ta +-------+
      #   tb     +---...
      # ta_u +-+
      to = (ta[0],  ta[1] + (MSB(tb) - ta[2]) + 2, MSB(tb) + 2, ta[3] - (MSB(tb) - ta[2]) - 2, stageno, z_style)
      to_list += [to]

    if (ta[2] > tb[2] + 1):
      #   ta +-------+
      #   tb     +-------+
      # tb_l           +-+
      to = (tb[0], tb[1], tb[2], ta[2] - tb[2] - 1, stageno, z_style)
      to_list += [to]
      # t_ov     +----+
      if (tb_h_select):
        to = (ta[0], ta[1], ta[2] - 1, tb[3] - (ta[2] - tb[2] - 1) - 1, stageno, z_style)
      else:
        to = (ta[0], ta[1], ta[2] - 1, tb[3] - (ta[2] - tb[2] - 1), stageno, z_style)
      to_list += [to]
    elif (ta[2] < tb[2] + 1):
      #   ta +-----------+
      #   tb     +---+
      # ta_l         +---+
      to = (ta[0], ta[1], ta[2], tb[2] - ta[2] + 1, stageno, z_style)
      to_list += [to]
      # t_ov     +---+
      if (tb_h_select):
        to = (ta[0], tb[1], tb[2], tb[3]-1, stageno, z_style)
      else:
        to = (ta[0], tb[1], tb[2], tb[3], stageno, z_style)
      if (to[3] != 0):
        to_list += [to]
    else: # ta[2] == tb[2] + 1)
      #   ta +------+
      #   tb     +---+
      # t_ov     +---+
      if (tb_h_select):
        to = (ta[0], tb[1], tb[2], tb[3]-1, stageno, z_style)
      else:
        to = (ta[0], tb[1], tb[2], tb[3], stageno, z_style)
      if (to[3] != 0):
        to_list += [to]

    return True, to_list

  elif ((ta[1] - ta[2] - 1) == (tb[1] - tb[2]) and (ta[0] != tb[0])): # partial(tb) = -2 * partial(ta) (part TBD)

    if (ta[2] > MSB(tb) - 1):
      return False, to_list

    #   ta +-------...
    #   tb     +---...
    # ta_u +---+
    to = (ta[0], ta[1] + (MSB(tb) - ta[2]), MSB(tb), ta[3] - (MSB(tb) - ta[2]), stageno, z_style)
    to_list += [to]

    if (ta[2] > tb[2] - 1):
      #   ta +-------+
      #   tb     +-------+
      # tb_l         +---+
      to = (tb[0], tb[1], tb[2], tb[3] - (MSB(tb) - ta[2]), stageno, z_style)
      to_list += [to]
      # t_ov      +--+
      to = (tb[0], ta[1], ta[2], MSB(tb) - ta[2], stageno, z_style)
      to_list += [to]
    elif(ta[2] < tb[2] - 1):
      #   ta +-----------+
      #   tb     +---+
      # ta_l           +-+
      to = (ta[0], ta[1], ta[2], tb[2] - ta[2] - 1, stageno, z_style)
      to_list += [to]
      # t_ov      +---+
      to = (tb[0], tb[1], tb[2] - 1, tb[3], stageno, z_style)
      to_list += [to]
    else: # ta[2] == tb[2] - 1)
      #   ta +--------+
      #   tb     +---+
      # t_ov      +---+
      to = (tb[0], tb[1], tb[2] - 1, tb[3], stageno, z_style)
      to_list += [to]

    return True, to_list

  return False, to_list



# Generate the single stage reduction plan
def linear_reduction_single_stage_gen(number, power, stageno, z_style):
  if(power > 0):
    if(z_style == -1):
      token_list = [(-1, 0, 0, power, stageno, z_style)]
    else:
      token_list = [(1, 0, 0, power, stageno, z_style)]

  else:
    token_list = [(1, 0, 0, -power-1, stageno, z_style)]
    sign_mod = number - pow(2, -power-1) % number
    bin_sign_mod = evaluate_naf(sign_mod)
    for idx in range(len(bin_sign_mod)):
      if (bin_sign_mod[idx] != 0):
        to = (bin_sign_mod[idx], -power-1, idx, 1, stageno, z_style)
        token_list.append(to)
  bin_num_signed = evaluate_naf(number)
  bin_num = bin_representation(number)
  target = len(bin_num_signed) - 1

  DEBUG_x = 0
  showtoggle = False
  # while ( (MSB(max(token_list, key=MSB)) > target) and (DEBUG_x < 1)):
  while (MSB(max(token_list, key=MSB)) >= target):
    for idx1, item in enumerate(token_list):
      if (MSB(item) >= target):
        if (item[2] < target):
          templitem = (item[0], item[1] - item[2] + target, target, MSB(item) - target + 1, stageno, z_style)
          item =      (item[0], item[1]                   , item[2] , target - item[2], stageno, z_style)
          token_list[idx1] = item
        else:
          templitem = item
          token_list.remove(item)
        for idx2 in range(target):
          if(bin_num_signed[idx2] != 0):
            moveitem = (-templitem[0]*bin_num_signed[idx2], templitem[1], templitem[2] - target + idx2, templitem[3], stageno, z_style)
            token_list.append(moveitem)
    itg_flag = True
    while(itg_flag):
      itg_flag = False
      for idx1, item1 in enumerate(token_list):
        for idx2, item2 in enumerate(token_list[idx1+1:]):
          itg_flag, itg_list = integrate_sync_vectors(item1, item2)
          if(itg_flag):
            token_list.remove(item1)
            token_list.remove(item2)
            token_list += itg_list
            break
        if(itg_flag): break
    itg_flag = True
    while(itg_flag):
      itg_flag = False
      for idx1, item1 in enumerate(token_list):
        for idx2, item2 in enumerate(token_list[idx1+1:]):
          itg_flag, itg_list = integrate_subtract_vectors(item1, item2)
          if(itg_flag):
            token_list.remove(item1)
            token_list.remove(item2)
            token_list += itg_list
            break
        if(itg_flag): break
    DEBUG_x = DEBUG_x + 1

  # print('Stage 1 result:')
  # print_token_list(token_list)
  token_list.sort(key=lambda x: (x[0], x[2], MSB(x)), reverse=True)
  return token_list



# Extract the value of bit p
def extract_p(stage_detail, power):
  pos_value = 0
  neg_value = 0
  for token in stage_detail:
    if (token[1] <= power) and (token[1] + token[3] - 1 >= power):
      if(token[0] > 0):
        pos_value += (1 << (token[2] + power - token[1]))
      else:
        neg_value += (1 << (token[2] + power - token[1]))
  return pos_value, neg_value



# evaluate the range of the reduction plan with given last-stage range
def evaluate_reduction_range(stage_detail, power, last_pos_max, last_neg_max):
  if (power > 0):
    if ((last_pos_max == -1) or (last_pos_max >= (1 << power))):
      last_pos_max = (1 << power) - 1
    last_neg_max = 0
    abs_power = power
    sign_power = 1
  elif (power < 0):
    if ((last_pos_max == -1) or (last_pos_max >= (1 << (-power - 1)))):
      last_pos_max = (1 << (-power - 1)) - 1
    if ((last_neg_max == -1) or (last_neg_max >  (1 << (-power - 1)))):
      last_neg_max = (1 << (-power - 1))
    if(last_neg_max - 1 > last_pos_max):
      last_pos_max = last_neg_max - 1
    last_neg_max = 0
    abs_power = -power
    sign_power = -1
  else: # power == 0
    return 0, 0

  if (sign_power == 1):
    if (last_pos_max == 0):
      return 0,0
    elif (last_pos_max == ((1 << abs_power) - 1)):
      pos_max = 0
      neg_max = 0
      for token in stage_detail:
        if(token[0] > 0):
          if (token[1] <= abs_power - 1):
            if (token[1] + token[3] >= abs_power) :
              pos_max += (1 << token[2]) * ((1 << (abs_power - token[1])) - 1)
            else:
              pos_max += (1 << token[2]) * ((1 << token[3]) - 1)
        else:
          if (token[1] <= abs_power - 1):
            if (token[1] + token[3] >= abs_power) :
              neg_max += (1 << token[2]) * ((1 << (abs_power - token[1])) - 1)
            else:
              neg_max += (1 << token[2]) * ((1 << token[3]) - 1)
      return pos_max, neg_max
    else:
      l_pm = last_pos_max.bit_length()

      pos_max_1, neg_max_1 = evaluate_reduction_range(stage_detail, l_pm-1, -1, 0)

      last_pos_max_minus = last_pos_max - (1 << (l_pm - 1))
      l_pm_minus = last_pos_max_minus.bit_length()
      pos_msb, neg_msb = extract_p(stage_detail, l_pm - 1)
      pos_lsb, neg_lsb = evaluate_reduction_range(stage_detail, l_pm_minus, last_pos_max_minus, 0)
      pos_max_2 = pos_msb + pos_lsb
      neg_max_2 = neg_msb + neg_lsb

      pos_max = max(pos_max_1, pos_max_2)
      neg_max = max(neg_max_1, neg_max_2)

      return pos_max, neg_max
  else:
    if (last_pos_max == 0):
      return 0,0
    else:
      pos_max = 0
      neg_max = 0
      for token in stage_detail:
        if(token[0] > 0):
          if (token[1] <= abs_power - 1):
            if (token[1] + token[3] >= abs_power) :
              pos_max += (1 << token[2]) * ((1 << (abs_power - token[1])) - 1)
            else:
              pos_max += (1 << token[2]) * ((1 << token[3]) - 1)
        else:
          if (token[1] <= abs_power - 1):
            if (token[1] + token[3] >= abs_power) :
              neg_max += (1 << token[2]) * ((1 << (abs_power - token[1])) - 1)
            else:
              neg_max += (1 << token[2]) * ((1 << token[3]) - 1)
      return pos_max, neg_max



# linear reduction plan generation to the interval [-(3n-1)/2, (3n-1)/2] in the signed case and [-n+1, 0, 2n-1]
def linear_reduction_gen(number, power, sred_flag):
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

  stage_detail = linear_reduction_single_stage_gen(number, power, 0, 0)
  # print('Token list for N = {} and P = {} -- stage 0:'.format(number, power))
  abs_power = -power if power < 0 else power
  sign_power = 1 if power > 0 else -1 if power < 0 else 0
  last_pos_max = ((1 << (abs_power-1)) - 1) if sign_power < 0 else ((1 << abs_power) - 1)
  last_neg_max =  (1 << (abs_power-1))      if sign_power < 0 else 0

  pos_max, neg_max = evaluate_reduction_range(stage_detail, power, last_pos_max, last_neg_max)

  stage_list.append( (stage_detail, 0, last_pos_max, last_neg_max, pos_max, neg_max) )
  # print_stage_list(stage_list)

  # print('Stage 0: pos_max = {pm:d} (0x{pm:x}; 0b{pm:b}), neg_max = -{nm:d} (0x{nm:x}; 0b{nm:b})'.format(pm=pos_max, nm=neg_max))
  stageno = 1
  last_pos_max = pos_max
  last_neg_max = neg_max
  # while(interval_check(last_pos_max, last_neg_max, sred_flag)):
  while(interval_check(last_pos_max, last_neg_max, sred_flag) and stageno <= 100):
    if(not interval_neg_check(last_neg_max, sred_flag)):
      l_pm = last_pos_max.bit_length()
      stage_detail = linear_reduction_single_stage_gen(number, l_pm, stageno, 1)
      pos_max_stage, neg_max_stage = evaluate_reduction_range(stage_detail, l_pm, last_pos_max, 0)
      stage_list.append( (stage_detail, 1, last_pos_max, 0, pos_max_stage, neg_max_stage + last_neg_max) )
      last_pos_max = pos_max_stage
      last_neg_max = neg_max_stage + last_neg_max
    elif(not interval_pos_check(last_pos_max, sred_flag)):
      l_nm = last_neg_max.bit_length()
      stage_detail = linear_reduction_single_stage_gen(number, l_nm, stageno, -1)
      pos_max_stage, neg_max_stage = evaluate_reduction_range(stage_detail, l_nm, last_neg_max, 0)
      stage_list.append( (stage_detail, -1, 0, last_neg_max, pos_max_stage + last_pos_max, neg_max_stage) )
      last_pos_max = pos_max_stage + last_pos_max
      last_neg_max = neg_max_stage
    else:
      if(last_pos_max > last_neg_max - 1):
        l_m = last_pos_max.bit_length() + 1
      else:
        last_neg_max_minus = last_neg_max - 1
        l_m = last_neg_max_minus.bit_length() + 1
      stage_detail = linear_reduction_single_stage_gen(number, l_m, stageno, 0)
      pos_max, neg_max = evaluate_reduction_range(stage_detail, l_m, -1, -1)
      stage_list.append( (stage_detail, 0, last_pos_max, last_neg_max, pos_max, neg_max) )
      last_pos_max = pos_max
      last_neg_max = neg_max
    # print('Stage {st:d}: pos_max = {pm:d} (0x{pm:x}; 0b{pm:b}), neg_max = -{nm:d} (0x{nm:x}; 0b{nm:b})'.format(st=stageno, pm=last_pos_max, nm=last_neg_max))
    # print_stage_list(stage_list)
    # print('='*120)
    stageno += 1

  # print_stage_list(stage_list)

  # print('Verifying the token list for N = {} and P = {}... '.format(args.number, args.power), flush=True, file=sys.stderr)
  # assert verify_tlist(args.number, args.power, token_list), DEBUG_Verify_Error
  # print('OK!', file=sys.stderr)
  return stage_list



def verify_interval(PID, rv, number, sign_power, range_power, tlist, offset):
  r = int(pow(2, range_power))
  for idx1 in range(r):
    value = offset + idx1

    value_mod = value % number

    bin_value = bin_signed_representation(value, sign_power)

    value_combine = 0
    for token in tlist:
      value_token = 0
      for idx2 in range(token[3]):
        try:
          value_token += token[0] * bin_value[token[1] + idx2] * pow(2, token[2] + idx2)
        except:
          print('DEBUG: ERROR at token = {} and idx2 = {}'.format(token, idx2), file=sys.stderr)
          print('                bin_value = {}'.format(bin_value), file=sys.stderr)
          rv[PID] = 1
          return False

      value_token %= number
      value_combine += value_token
    value_combine %= number
    if (value_mod != value_combine):
      print('DEBUG: ERROR at value = {}'.format(value), file=sys.stderr)
      print('                value_mod = {}, value_combine = {}'.format(value_mod, value_combine), file=sys.stderr)
      rv[PID] = 1
      return False

    # if ((PID == 0) and ((sum(rv) // 1024) + (sum(rv) % 1024)) == 0):
    if (PID == 0):
      rate = float(idx1) / float(r) * 100
      if(idx1 % 1024 == 0):
        print('\r{:4.1f}% checked......               '.format(rate), end='', file=sys.stderr)

  rv[PID] = 1024
  return True

def verify_tlist(number, power, tlist):
  core_count = os.cpu_count()
  core_depth = len(bin_representation(core_count)) - 1 - 1
  core_depth = 0 if core_depth < 0 else core_depth
  core_power = int(pow(2, core_depth))

  plist = []

  if(power > 0):
    min_pow_value = 0
    ppower = power
  else:
    min_pow_value = - pow(2, -power-1)
    ppower = -power

  returnValue = Array('i', [0] * core_power)

  pow_step = ppower - core_depth
  pow_offset = int(pow(2, pow_step))
  for idx in range(core_power):
    process = Process(target=verify_interval, args=(idx, returnValue, number, ppower, pow_step, tlist, min_pow_value + pow_offset * idx))
    process.start()
    plist += [process]
  ErrorFlag = True
  while((sum(returnValue) // 1024) + (sum(returnValue) % 1024) < core_power):
    for idx, process in enumerate(plist):
      if ( not process.is_alive() ):
        if(returnValue[idx] == 1):
          ErrorFlag = False
          break
    if(ErrorFlag == False):
      break
    finishprocess = (sum(returnValue) // 1024) + (sum(returnValue) % 1024)
    if (finishprocess != 0):
     print('\r {:d} processes finished......'.format(finishprocess), end='', file=sys.stderr)
  for process in plist:
    plist.remove(process)
  return ErrorFlag



# Analyze the stages into variable list
def analyze_stages(stage_list, number):
  var_lists = []
  l_n = number.bit_length()
  n_r = (1 << l_n)

  for item in stage_list:
    stage = item[0].copy()
    stage.sort(key=lambda x:  (x[0], -MSB(x), -x[2]), reverse=True)

    print_stage_list([(stage, 1, item[2], item[3], item[4], item[5])])

    var_list = ([], [])

    for token in stage:
      sgn_idx = 0 if token[0] > 0 else 1
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
      # print('For token', token, ': ')
      # print(var_list)

    # print(var_list)

    var_lists.append(var_list)

  return var_lists



########## reduction plan -> RTL in verilog converter    ##########
########## Token: (sign, vp, exp, len, stageno, z_style) ##########

module_template = 'mod{n:d}{t}{p:d}'

def gen_rtl(stage_list, stage_var_list, number, power, sred_flag):
  global f_fd

  if(sred_flag):
    module_name = module_template.format(n=number, t='S', p=abs(power))
  else:
    module_name = module_template.format(n=number, t='U', p=abs(power))
  module_file = Path(module_name + '_linear.v')

  l_n = number.bit_length()
  n_r = (1 << l_n)
  (abs_power, sign_power) = (power, 1) if power >= 0 else (-power, -1)

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







    fprint(      'endmodule')
    fprint(      '')

  return



def gen_tb(number, power, sred_flag):
  global f_fd

  if(sred_flag):
    module_name = module_template.format(n=number, t='S', p=abs(power))
  else:
    module_name = module_template.format(n=number, t='U', p=abs(power))
  tb_file = Path(module_name + '_tb.v')

  with tb_file.open(mode='w') as f_fd:
    pass


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
    stage_list = linear_reduction_gen(args.number, args.power, SRed_Flag)
    # print_stage_list(stage_list)
    stage_var_list = analyze_stages(stage_list, args.number)
    gen_rtl(stage_list, stage_var_list, args.number, args.power, SRed_Flag)
    # gen_tb(args.number, args.power, SRed_Flag)

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



