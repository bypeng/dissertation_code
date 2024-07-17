#!/usr/bin/sage
#####!/usr/bin/env python3

import sys

#quotient = 0
#rootNo = 512

def bit_rev(x, x_size):
  r = 0
  for index in range(0, x_size):
    r = (r << 1) + (x & 1)
    x >>= 1
  return r

def find_gen(quotient, rootNo):
  # S = [];
  for gen in range(2, quotient):
    if(mod(power(gen, rootNo / 2), quotient) == quotient - 1):
      # S += [gen]
      break
  # print('Quotient = {q}:'.format(q=quotient))
  # print(S[0:10])
  print('Quotient = {q}: Gen = {g}'.format(q=quotient, g=gen))
  return gen

def gen_gen(gen, quo, rootNo):
  I = list(range(0, rootNo / 2))
  rL = rootNo.bit_length() - 2
  Ibr = map(lambda x : bit_rev(x, rL), I)
  R = mod(power(2,16), quo)
  S = map(lambda x : int(mod(power(gen, x), quo)), I)
  # S = map(lambda x : int(mod(power(gen, x) * R, quo)), Ibr)
  S = map(lambda x : x - quo if 2 * x + 1 > quo else x, S)
  for index, value in enumerate(S):
    # if(mod(index,16) != 0):
    #   print(', ', end='')
    # else:
    #   if(index != 0): print('')
    # print(value, end='')
    print('        data[{i:d}] <= {v:d};'.format(i=index, v=value))
  #print(S)
  print()

def main():
  cli_args = sys.argv[1:]

  try:
    assert len(cli_args) == 1 or len(cli_args) == 2
    quotient = int(cli_args[0])
    if(len(cli_args) == 2):
      rootNo = int(cli_args[1])
    else:
      rootNo = 512
    assert is_prime(quotient)
    gen = find_gen(quotient, rootNo)
    gen_gen(gen, quotient, rootNo)
  except AssertionError:
    print('  Usage: {a:s} {{Quotient}} [{{root No.}}]'.format(a=sys.argv[0]))
    print('         Quotient: needs to be a prime.');

main()

