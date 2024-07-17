#!/usr/bin/sage
#####!/usr/bin/env python3

import sys
import math

depth = 8
maxdepth = 18
log10maxdepth2 = int(math.floor(math.log10(maxdepth // 2 + 1))+1)
maxdecdepth = int(math.floor(math.log10(pow(2,maxdepth)))+1)
maxhexdepth = int(math.ceil(maxdepth / 4))

FCols = 1

def bin_representation(number):
  assert (number >= 0)
  if(number == 0):
    return [0]
  elif(number == 1):
    return [1]
  else:
    quotient, remainder = divmod(number, 2)
    return [remainder] + bin_representation(quotient)

def ehw(number):
  x = number
  xh = x // 2
  x3 = x + xh
  c = xh ^^ x3
  np = x3 & c
  nm = xh & c
  bin_np = bin_representation(np)
  bin_nm = bin_representation(nm)
  return sum(bin_np) + sum(bin_nm)
  # return bin_np, bin_nm

def primeformat():
  global depth, maxdepth, maxdecdepth, maxhexdepth, log10maxdepth

  x = max(4, maxdepth)
  fs = '<(\'d)' + ' ' * max(maxdecdepth - 4, 0) + ', (\'h)' + ' ' * max(maxhexdepth - 4, 0) + ', (\'b)' ; x -= 4
  if( x % 10 == 1 ):
    fs += ' ' * 10
    x -= 10
  else:
    fs += ' ' * ((x-1) % 10)
    x -= ((x-1) % 10)
  fs += '{:d}'.format(int(math.floor((x % 100) / 10)))
  x -= 1
  while(x > 0):
    fs += (' ' * 9)
    fs += '{:d}'.format(int(math.floor((x % 100) / 10)-1))
    x -= 10
  fs += '  '
  fs += (' ' * log10maxdepth2)
  fs += '>'

  fs0 = fs

  fs = '<'; x = max(3, maxdecdepth - 1)
  while(x >= 0):
    fs += '{:1d}'.format(x % 10)
    x -= 1
  fs += ', '; x = max(3, maxhexdepth - 1)
  while(x >= 0):
    fs += '{:1d}'.format(x % 10)
    x -= 1
  fs += ', '; x = max(3, maxdepth - 1)
  while(x >= 0):
    fs += '{:1d}'.format(x % 10)
    x -= 1
  fs += ', '
  fs += (' ' * log10maxdepth2)
  fs += '>'

  fs1 = fs

  return fs0, fs1

def goodprime():
  S = []
  for index in range(1, power(2, maxdepth-depth)):
    x = index * power(2, depth) + 1
    if(is_prime(x) and ehw(x) <= maxehw):
      S += [x]
  fs0, fs1 = primeformat()
  for index in range(FCols):
    if(index != 0): print(', ', end='')
    print(fs0, end='')
  print('')
  for index in range(FCols):
    if(index != 0): print(', ', end='')
    print(fs1, end='')
  print('')
  for index, value in enumerate(S):
    if(mod(index,FCols) != 0):
      print(', ', end='')
    else:
      if(index != 0): print('')
    fs = '[{{:{:d}d}}, {{:0{:d}X}}, {{:{:d}b}}, {{:{:d}d}}]'.format(max(maxdecdepth, 4), max(maxhexdepth, 4), max(maxdepth, 4), log10maxdepth2)
    # fs = '[{{:{:d}d}}, {{:0{:d}X}}, {{:{:d}b}}]'.format(max(maxdecdepth, 4), max(maxhexdepth, 4), max(maxdepth, 4))
    print(fs.format(value, value, value, ehw(value)), end='')
  print('')
  for index in range(FCols):
    if(index != 0): print(', ', end='')
    print(fs0, end='')
  print('')
  for index in range(FCols):
    if(index != 0): print(', ', end='')
    print(fs1, end='')
  print('')


def main():
  global depth, maxdepth, maxdecdepth, maxhexdepth, maxehw, FCols
  cli_args = sys.argv[1:]

  try:
    assert len(cli_args) <= 4
    if(len(cli_args) >= 1):
      depth = int(cli_args[0])
    if(len(cli_args) >= 2):
      maxdepth = int(cli_args[1])
      maxdecdepth = int(math.floor(math.log10(pow(2,maxdepth)))+1)
      maxhexdepth = int(math.ceil(maxdepth / 4))
    assert depth >= 1 and depth <= maxdepth
    if(len(cli_args) >= 3):
      maxehw = int(cli_args[2])
    if(len(cli_args) >= 4):
      FCols = int(cli_args[3])
    goodprime()
  except AssertionError:
    print('  Usage: {a:s} {{NTT Depth}} {{Prime Maximum length}}'.format(a=sys.argv[0]))


main()

