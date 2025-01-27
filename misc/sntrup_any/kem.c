#ifdef KAT
#include <stdio.h>
#endif

#include <stdlib.h> /* for abort() in case of OpenSSL failures */
#include "params.h"

#include "randombytes.h"
#include "crypto_hash_sha512.h"
#ifdef LPR
#include "crypto_stream_aes256ctr.h"
#endif

#include "int8.h"
#include "int16.h"
#include "int32.h"
#include "uint16.h"
#include "uint32.h"
#include "crypto_sort_uint32.h"
#include "Encode.h"
#include "Decode.h"

#include "intervaluegen/intervaluegen.h"

/* #define RQ_ENCODE_TEST */
/* #define ROUND_ENCODE_TEST */
/* #define RQ_DECODE_TEST */
/* #define ROUND_DECODE_TEST */
/* ----- masks */

#ifndef LPR

/* return -1 if x!=0; else return 0 */
static int int16_nonzero_mask(int16 x)
{
  uint16 u = x; /* 0, else 1...65535 */
  uint32 v = u; /* 0, else 1...65535 */
  v = -v; /* 0, else 2^32-65535...2^32-1 */
  v >>= 31; /* 0, else 1 */
  return -v; /* 0, else -1 */
}

#endif

/* return -1 if x<0; otherwise return 0 */
static int int16_negative_mask(int16 x)
{
  uint16 u = x;
  u >>= 15;
  return -(int) u;
  /* alternative with gcc -fwrapv: */
  /* x>>15 compiles to CPU's arithmetic right shift */
}

/* ----- arithmetic mod 3 */

typedef int8 small;

/* F3 is always represented as -1,0,1 */
/* so ZZ_fromF3 is a no-op */

/* x must not be close to top int16 */
static small F3_freeze(int16 x)
{
  return int32_mod_uint14(x+1,3)-1;
}

/* ----- arithmetic mod q */

#define q12 ((q-1)/2)
typedef int16 Fq;
/* always represented as -q12...q12 */
/* so ZZ_fromFq is a no-op */

/* x must not be close to top int32 */
static Fq Fq_freeze(int32 x)
{
  return int32_mod_uint14(x+q12,q)-q12;
}

#ifndef LPR

static Fq Fq_recip(Fq a1)
{ 
  int i = 1;
  Fq ai = a1;

  while (i < q-2) {
    ai = Fq_freeze(a1*(int32)ai);
    i += 1;
  }
  return ai;
} 

#endif

/* ----- Top and Right */

#ifdef LPR
#define tau 16

static int8 Top(Fq C)
{
  return (tau1*(int32)(C+tau0)+16384)>>15;
}

static Fq Right(int8 T)
{
  return Fq_freeze(tau3*(int32)T-tau2);
}
#endif

/* ----- small polynomials */

#ifndef LPR

/* 0 if Weightw_is(r), else -1 */
static int Weightw_mask(small *r)
{
  int weight = 0;
  int i;

  for (i = 0;i < p;++i) weight += r[i]&1;
  return int16_nonzero_mask(weight-w);
}

/* R3_fromR(R_fromRq(r)) */
static void R3_fromRq(small *out,const Fq *r)
{
  int i;
  for (i = 0;i < p;++i) out[i] = F3_freeze(r[i]);
}

/* h = f*g in the ring R3 */
static void R3_mult(small *h,const small *f,const small *g)
{
  small fg[p+p-1];
  small result;
  int i,j;

  for (i = 0;i < p;++i) {
    result = 0;
    for (j = 0;j <= i;++j) result = F3_freeze(result+f[j]*g[i-j]);
    fg[i] = result;
  }
  for (i = p;i < p+p-1;++i) {
    result = 0;
    for (j = i-p+1;j < p;++j) result = F3_freeze(result+f[j]*g[i-j]);
    fg[i] = result;
  }

  for (i = p+p-2;i >= p;--i) {
    fg[i-p] = F3_freeze(fg[i-p]+fg[i]);
    fg[i-p+1] = F3_freeze(fg[i-p+1]+fg[i]);
  }

  for (i = 0;i < p;++i) h[i] = fg[i];
}

/* returns 0 if recip succeeded; else -1 */
static int R3_recip(small *out,const small *in)
{ 
  small f[p+1],g[p+1],v[p+1],r[p+1];
  int i,loop,delta;
  int sign,swap,t;
  
  for (i = 0;i < p+1;++i) v[i] = 0;
  for (i = 0;i < p+1;++i) r[i] = 0;
  r[0] = 1;
  for (i = 0;i < p;++i) f[i] = 0;
  f[0] = 1; f[p-1] = f[p] = -1;
  for (i = 0;i < p;++i) g[p-1-i] = in[i];
  g[p] = 0;
    
  delta = 1; 

  for (loop = 0;loop < 2*p-1;++loop) {
    for (i = p;i > 0;--i) v[i] = v[i-1];
    v[0] = 0;
    
    sign = -g[0]*f[0];
    swap = int16_negative_mask(-delta) & int16_nonzero_mask(g[0]);
    delta ^= swap&(delta^-delta);
    delta += 1;
    
    for (i = 0;i < p+1;++i) {
      t = swap&(f[i]^g[i]); f[i] ^= t; g[i] ^= t;
      t = swap&(v[i]^r[i]); v[i] ^= t; r[i] ^= t;
    }
  
    for (i = 0;i < p+1;++i) g[i] = F3_freeze(g[i]+sign*f[i]);
    for (i = 0;i < p+1;++i) r[i] = F3_freeze(r[i]+sign*v[i]);

    for (i = 0;i < p;++i) g[i] = g[i+1];
    g[p] = 0;
  }
  
  sign = f[0];
  for (i = 0;i < p;++i) out[i] = sign*v[p-1-i];
  
  return int16_nonzero_mask(delta);
} 

#ifdef INTERVALUE_GEN
static int R3_recip_intervalues(small *out,const small *in)
{ 
  small f[p+1],g[p+1],v[p+1],r[p+1];
  int i,loop,delta;
  int sign,swap,t;

  char vectorname[256];
  
  for (i = 0;i < p+1;++i) v[i] = 0;
  for (i = 0;i < p+1;++i) r[i] = 0;
  r[0] = 1;
  for (i = 0;i < p;++i) f[i] = 0;
  f[0] = 1; f[p-1] = f[p] = -1;
  for (i = 0;i < p;++i) g[p-1-i] = in[i];
  g[p] = 0;
    
  delta = 1; 

  ivg_print_int8array("r3_v_0", v, p+1);
  ivg_print_int8array("r3_r_0", r, p+1);
  ivg_print_int8array("r3_f_0", f, p+1);
  ivg_print_int8array("r3_g_0", g, p+1);

  for (loop = 0;loop < 2*p-1;++loop) {
    for (i = p;i > 0;--i) v[i] = v[i-1];
    v[0] = 0;
    
    sign = -g[0]*f[0];
    swap = int16_negative_mask(-delta) & int16_nonzero_mask(g[0]);
    delta ^= swap&(delta^-delta);
    delta += 1;
    
    for (i = 0;i < p+1;++i) {
      t = swap&(f[i]^g[i]); f[i] ^= t; g[i] ^= t;
      t = swap&(v[i]^r[i]); v[i] ^= t; r[i] ^= t;
    }
  
    for (i = 0;i < p+1;++i) g[i] = F3_freeze(g[i]+sign*f[i]);
    for (i = 0;i < p+1;++i) r[i] = F3_freeze(r[i]+sign*v[i]);

    for (i = 0;i < p;++i) g[i] = g[i+1];
    g[p] = 0;

    sprintf(vectorname, "r3_v_%d", loop+1);
    ivg_print_int8array(vectorname, v, p+1);
    sprintf(vectorname, "r3_r_%d", loop+1);
    ivg_print_int8array(vectorname, r, p+1);
    sprintf(vectorname, "r3_f_%d", loop+1);
    ivg_print_int8array(vectorname, f, p+1);
    sprintf(vectorname, "r3_g_%d", loop+1);
    ivg_print_int8array(vectorname, g, p+1);
  }
  
  sign = f[0];
  for (i = 0;i < p;++i) out[i] = sign*v[p-1-i];
  
  return int16_nonzero_mask(delta);
} 
#endif

#endif

/* ----- polynomials mod q */

/* h = f*g in the ring Rq */
static void Rq_mult_small(Fq *h,const Fq *f,const small *g)
{
  Fq fg[p+p-1];
  Fq result;
  int i,j;

  for (i = 0;i < p;++i) {
    result = 0;
    for (j = 0;j <= i;++j) result = Fq_freeze(result+f[j]*(int32)g[i-j]);
    fg[i] = result;
  }
  for (i = p;i < p+p-1;++i) {
    result = 0;
    for (j = i-p+1;j < p;++j) result = Fq_freeze(result+f[j]*(int32)g[i-j]);
    fg[i] = result;
  }

  for (i = p+p-2;i >= p;--i) {
    fg[i-p] = Fq_freeze(fg[i-p]+fg[i]);
    fg[i-p+1] = Fq_freeze(fg[i-p+1]+fg[i]);
  }

  for (i = 0;i < p;++i) h[i] = fg[i];
}

#ifndef LPR

/* h = 3f in Rq */
static void Rq_mult3(Fq *h,const Fq *f)
{
  int i;
  
  for (i = 0;i < p;++i) h[i] = Fq_freeze(3*f[i]);
}

/* out = 1/(3*in) in Rq */
/* returns 0 if recip succeeded; else -1 */
static int Rq_recip3(Fq *out,const small *in)
{ 
  Fq f[p+1],g[p+1],v[p+1],r[p+1];
  int i,loop,delta;
  int swap,t;
  int32 f0,g0;
  Fq scale;

  #ifdef INTERVALUE_GEN_NONEED
    char vectorname[256]; 
  #endif

  for (i = 0;i < p+1;++i) v[i] = 0;
  for (i = 0;i < p+1;++i) r[i] = 0;
  #ifdef INTERVALUE_GEN_NONEED
    r[0] = 1;
  #else
    r[0] = Fq_recip(3);
  #endif
  for (i = 0;i < p;++i) f[i] = 0;
  f[0] = 1; f[p-1] = f[p] = -1;
  #ifdef INTERVALUE_GEN_NONEED
    for (i = 0;i < p;++i) g[p-1-i] = Fq_freeze(3*in[i]);
  #else
    for (i = 0;i < p;++i) g[p-1-i] = in[i];
  #endif
  g[p] = 0;

  delta = 1;

  #ifdef INTERVALUE_GEN_NONEED
    ivg_print_int16array("rq_v_0", v, p+1);
    ivg_print_int16array("rq_r_0", r, p+1);
    ivg_print_int16array("rq_f_0", f, p+1);
    ivg_print_int16array("rq_g_0", g, p+1);
  #endif

  for (loop = 0;loop < 2*p-1;++loop) {
    for (i = p;i > 0;--i) v[i] = v[i-1];
    v[0] = 0;

    swap = int16_negative_mask(-delta) & int16_nonzero_mask(g[0]);
    delta ^= swap&(delta^-delta);
    delta += 1;

    for (i = 0;i < p+1;++i) {
      t = swap&(f[i]^g[i]); f[i] ^= t; g[i] ^= t;
      t = swap&(v[i]^r[i]); v[i] ^= t; r[i] ^= t;
    }

    f0 = f[0];
    g0 = g[0];
    for (i = 0;i < p+1;++i) g[i] = Fq_freeze(f0*g[i]-g0*f[i]);
    for (i = 0;i < p+1;++i) r[i] = Fq_freeze(f0*r[i]-g0*v[i]);

    for (i = 0;i < p;++i) g[i] = g[i+1];
    g[p] = 0;

    #ifdef INTERVALUE_GEN_NONEED
      sprintf(vectorname, "rq_v_%d", loop+1);
      ivg_print_int16array(vectorname, v, p+1);
      sprintf(vectorname, "rq_r_%d", loop+1);
      ivg_print_int16array(vectorname, r, p+1);
      sprintf(vectorname, "rq_f_%d", loop+1);
      ivg_print_int16array(vectorname, f, p+1);
      sprintf(vectorname, "rq_g_%d", loop+1);
      ivg_print_int16array(vectorname, g, p+1);
    #endif
  }

  scale = Fq_recip(f[0]);
  for (i = 0;i < p;++i) out[i] = Fq_freeze(scale*(int32)v[p-1-i]);

  return int16_nonzero_mask(delta);
}

#endif

/* ----- rounded polynomials mod q */

static void Round(Fq *out,const Fq *a)
{
  int i;
  for (i = 0;i < p;++i) out[i] = a[i]-F3_freeze(a[i]);
}

/* ----- sorting to generate short polynomial */

static void Short_fromlist(small *out,const uint32 *in)
{
  uint32 L[p];
  int i;

  for (i = 0;i < w;++i) L[i] = in[i]&(uint32)-2;
  for (i = w;i < p;++i) L[i] = (in[i]&(uint32)-3)|1;
  crypto_sort_uint32(L,p);
  for (i = 0;i < p;++i) out[i] = (L[i]&3)-1;
}

/* ----- underlying hash function */

#define Hash_bytes 32

/* e.g., b = 0 means out = Hash0(in) */
static void Hash_prefix(unsigned char *out,int b,const unsigned char *in,int inlen)
{
  unsigned char x[inlen+1];
  unsigned char h[64];
  int i;

  x[0] = b;
  for (i = 0;i < inlen;++i) x[i+1] = in[i];
  crypto_hash_sha512(h,x,inlen+1);
  for (i = 0;i < 32;++i) out[i] = h[i];
}

/* ----- higher-level randomness */

static uint32 urandom32(void)
{
  unsigned char c[4];
  uint32 out[4];

  randombytes(c,4);
  out[0] = (uint32)c[0];
  out[1] = ((uint32)c[1])<<8;
  out[2] = ((uint32)c[2])<<16;
  out[3] = ((uint32)c[3])<<24;
  return out[0]+out[1]+out[2]+out[3];
}

static void Short_random(small *out)
{
  uint32 L[p];
  int i;

  for (i = 0;i < p;++i) L[i] = urandom32();
  Short_fromlist(out,L);
}

#ifndef LPR

static void Small_random(small *out)
{
  int i;

  for (i = 0;i < p;++i) out[i] = (((urandom32()&0x3fffffff)*3)>>30)-1;
}

#endif

/* ----- Streamlined NTRU Prime Core */

#ifndef LPR

/* h,(f,ginv) = KeyGen() */
static void KeyGen(Fq *h,small *f,small *ginv)
{
  small g[p];
  Fq finv[p];
  
  for (;;) {
    Small_random(g);
    if (R3_recip(ginv,g) == 0) break;
  }
  #ifdef INTERVALUE_GEN_NONEED
    R3_recip_intervalues(ginv, g);
  #endif
  Short_random(f);
  Rq_recip3(finv,f); /* always works */
  Rq_mult_small(h,finv,g);

  #ifdef INTERVALUE_GEN
    ivg_print_int8array("g", g, p);
    ivg_print_int8array("f", f, p);
    ivg_print_int8array("ginv", ginv, p);
    //ivg_print_int16array("1/3f", finv, p);
    //ivg_print_int16array("g/3f", h, p);
  #endif
}

/* c = Encrypt(r,h) */
static void Encrypt(Fq *c,const small *r,const Fq *h)
{
  Fq hr[p];

  Rq_mult_small(hr,h,r);
  Round(c,hr);
}

/* c = Encrypt(r,h) */
static void Encrypt_w_ivg(Fq *c,const small *r,const Fq *h)
{
  Fq hr[p];

  #ifdef INTERVALUE_GEN
    ivg_print_int8array("r", r, p);
  #endif

  Rq_mult_small(hr,h,r);

  #ifdef INTERVALUE_GEN_NONEED
    ivg_print_int16array("hr", hr, p);
  #endif

  Round(c,hr);
  
  #ifdef INTERVALUE_GEN_NONEED
    ivg_print_int16array("round(hr)", c, p);
  #endif

}

/* r = Decrypt(c,(f,ginv)) */
static void Decrypt(small *r,const Fq *c,const small *f,const small *ginv)
{
  Fq cf[p];
  Fq cf3[p];
  small e[p];
  small ev[p];
  int mask;
  int i;

  Rq_mult_small(cf,c,f);
  Rq_mult3(cf3,cf);

  R3_fromRq(e,cf3);

  R3_mult(ev,e,ginv);

  #ifdef INTERVALUE_GEN_NONEED
    ivg_print_int16array("cf3", cf3, p);
    ivg_print_int8array("e", e, p);
    ivg_print_int8array("ev", ev, p);
  #endif

  mask = Weightw_mask(ev); /* 0 if weight w, else -1 */
  for (i = 0;i < w;++i) r[i] = ((ev[i]^1)&~mask)^1;
  for (i = w;i < p;++i) r[i] = ev[i]&~mask;
}
  
#endif

/* ----- NTRU LPRime Core */

#ifdef LPR

/* (G,A),a = KeyGen(G); leaves G unchanged */
static void KeyGen(Fq *A,small *a,const Fq *G)
{
  Fq aG[p];

  Short_random(a);
  Rq_mult_small(aG,G,a);
  Round(A,aG);
}

/* B,T = Encrypt(r,(G,A),b) */
static void Encrypt(Fq *B,int8 *T,const int8 *r,const Fq *G,const Fq *A,const small *b)
{
  Fq bG[p];
  Fq bA[p];
  int i;

  Rq_mult_small(bG,G,b);
  Round(B,bG);
  Rq_mult_small(bA,A,b);
  for (i = 0;i < I;++i) T[i] = Top(Fq_freeze(bA[i]+r[i]*q12));
}

/* r = Decrypt((B,T),a) */
static void Decrypt(int8 *r,const Fq *B,const int8 *T,const small *a)
{
  Fq aB[p];
  int i;

  Rq_mult_small(aB,B,a);
  for (i = 0;i < I;++i)
    r[i] = -int16_negative_mask(Fq_freeze(Right(T[i])-aB[i]+4*w+1));
}
    
#endif

/* ----- encoding I-bit inputs */

#ifdef LPR

#define Inputs_bytes (I/8)
typedef int8 Inputs[I]; /* passed by reference */

static void Inputs_encode(unsigned char *s,const Inputs r)
{
  int i;
  for (i = 0;i < Inputs_bytes;++i) s[i] = 0;
  for (i = 0;i < I;++i) s[i>>3] |= r[i]<<(i&7);
}

#endif

/* ----- Expand */

#ifdef LPR

static const unsigned char aes_nonce[16] = {0};

static void Expand(uint32 *L,const unsigned char *k)
{
  int i;
  if (crypto_stream_aes256ctr((unsigned char *) L,4*p,aes_nonce,k) != 0) abort();
  for (i = 0;i < p;++i) {
    uint32 L0 = ((unsigned char *) L)[4*i];
    uint32 L1 = ((unsigned char *) L)[4*i+1];
    uint32 L2 = ((unsigned char *) L)[4*i+2];
    uint32 L3 = ((unsigned char *) L)[4*i+3];
    L[i] = L0+(L1<<8)+(L2<<16)+(L3<<24);
  }
}

#endif

/* ----- Seeds */

#ifdef LPR

#define Seeds_bytes 32

static void Seeds_random(unsigned char *s)
{
  randombytes(s,Seeds_bytes);
}

#endif

/* ----- Generator, HashShort */

#ifdef LPR

/* G = Generator(k) */
static void Generator(Fq *G,const unsigned char *k)
{
  uint32 L[p];
  int i;

  Expand(L,k);
  for (i = 0;i < p;++i) G[i] = uint32_mod_uint14(L[i],q)-q12;
}

/* out = HashShort(r) */
static void HashShort(small *out,const Inputs r)
{
  unsigned char s[Inputs_bytes];
  unsigned char h[Hash_bytes];
  uint32 L[p];

  Inputs_encode(s,r);
  Hash_prefix(h,5,s,sizeof s);
  Expand(L,h);
  Short_fromlist(out,L);
}

#endif
  
/* ----- NTRU LPRime Expand */

#ifdef LPR

/* (S,A),a = XKeyGen() */
static void XKeyGen(unsigned char *S,Fq *A,small *a)
{
  Fq G[p];

  Seeds_random(S);
  Generator(G,S);
  KeyGen(A,a,G);
}

/* B,T = XEncrypt(r,(S,A)) */
static void XEncrypt(Fq *B,int8 *T,const int8 *r,const unsigned char *S,const Fq *A)
{
  Fq G[p];
  small b[p];

  Generator(G,S);
  HashShort(b,r);
  Encrypt(B,T,r,G,A,b);
}

#define XDecrypt Decrypt

#endif

/* ----- encoding small polynomials (including short polynomials) */

#define Small_bytes ((p+3)/4)

/* these are the only functions that rely on p mod 4 = 1 */

static void Small_encode(unsigned char *s,const small *f)
{
  small x;
  int i;

  for (i = 0;i < p/4;++i) {
    x = *f++ + 1;
    x += (*f++ + 1)<<2;
    x += (*f++ + 1)<<4;
    x += (*f++ + 1)<<6;
    *s++ = x;
  }
  x = *f++ + 1;
  *s++ = x;
}

static void Small_decode(small *f,const unsigned char *s)
{
  unsigned char x;
  int i;

  for (i = 0;i < p/4;++i) {
    x = *s++;
    *f++ = ((small)(x&3))-1; x >>= 2;
    *f++ = ((small)(x&3))-1; x >>= 2;
    *f++ = ((small)(x&3))-1; x >>= 2;
    *f++ = ((small)(x&3))-1;
  }
  x = *s++;
  *f++ = ((small)(x&3))-1;
}

/* ----- encoding general polynomials */

#ifndef LPR

static void Rq_encode(unsigned char *s,const Fq *r)
{
  uint16 R[p],M[p];
  int i;
  
  //for (i = 0;i < p;++i) R[i] = r[i]+q12;

#ifdef RQ_ENCODE_TEST
  FILE *fp;
  fp = fdopen(7, "a");

  fprintf(fp, "%d\n", p);
#endif

  for (i = 0;i < p;++i) {
    R[i] = r[i]+q12;

#ifdef RQ_ENCODE_TEST
    fprintf(fp, "%04x ", R[i]);
#endif

  }

#ifdef RQ_ENCODE_TEST
  fprintf(fp, "\n%d\n", Rq_bytes);
#endif

  for (i = 0;i < p;++i) M[i] = q;
  Encode(s,R,M,p);

#ifdef RQ_ENCODE_TEST
  for (i = 0;i < Rq_bytes; ++i)
    fprintf(fp, "%02x ", s[i]);
  fprintf(fp, "\n");
  fflush(fp);
#endif

}

static void Rq_decode(Fq *r,const unsigned char *s)
{
  uint16 R[p],M[p];
  int i;

  for (i = 0;i < p;++i) M[i] = q;

#ifdef RQ_DECODE_TEST
  FILE *fp;
  fp = fdopen(7, "a");

  fprintf(fp, "%d\n", Rq_bytes);
  for (i = 0;i < Rq_bytes; ++i)
    fprintf(fp, "%02x ", s[i]);

  fprintf(fp, "\n%d\n", p);
#endif

  Decode(R,s,M,p);
  //for (i = 0;i < p;++i) r[i] = ((Fq)R[i])-q12;
  for (i = 0;i < p;++i) {
    
#ifdef RQ_DECODE_TEST
    fprintf(fp, "%04x ", R[i]);
#endif

    r[i] = ((Fq)R[i])-q12;
  }

#ifdef RQ_DECODE_TEST
  fprintf(fp, "\n");
  fflush(fp);
#endif

}

#ifdef INTERVALUE_GEN
static void Rq_encode_w_ivg(char *s_name, unsigned char *s, char *r_name, char *r_name_offset, const Fq *r)
{
  uint16 R[p],M[p];
  int i;

  ivg_print_int16array(r_name, r, p);

  for (i = 0;i < p;++i) R[i] = r[i]+q12;

  ivg_print_uint16array(r_name_offset, R, p);

  for (i = 0;i < p;++i) M[i] = q;
  Encode(s,R,M,p);

  ivg_print_uint8array(s_name, s, Rq_bytes);

}

static void Rq_decode_w_ivg(char *r_name, char *r_name_offset, Fq *r, char *s_name, const unsigned char *s)
{
  uint16 R[p],M[p];
  int i;

  ivg_print_uint8array(s_name, s, Rq_bytes);

  for (i = 0;i < p;++i) M[i] = q;

  Decode(R,s,M,p);

  ivg_print_uint16array(r_name_offset, R, p);

  for (i = 0;i < p;++i) r[i] = ((Fq)R[i])-q12;

  ivg_print_int16array(r_name, r, p);

}
#endif

#endif

/* ----- encoding rounded polynomials */

static void Rounded_encode(unsigned char *s,const Fq *r)
{
  uint16 R[p],M[p];
  int i;

  //for (i = 0;i < p;++i) R[i] = ((r[i]+q12)*10923)>>15;
#ifdef ROUND_ENCODE_TEST
  FILE *fp;
  fp = fdopen(7, "a");

  fprintf(fp, "%d\n", p);
#endif

  for (i = 0;i < p;++i) {
    R[i] = ((r[i]+q12)*10923)>>15;

#ifdef ROUND_ENCODE_TEST
    fprintf(fp, "%04x ", R[i]);
#endif

  }

#ifdef ROUND_ENCODE_TEST
  fprintf(fp, "\n%d\n", Rounded_bytes);
#endif

  for (i = 0;i < p;++i) M[i] = (q+2)/3;
  Encode(s,R,M,p);

#ifdef ROUND_ENCODE_TEST
  for (i = 0;i < Rounded_bytes; ++i)
    fprintf(fp, "%02x ", s[i]);
  fprintf(fp, "\n");
  fflush(fp);
#endif

}

static void Rounded_decode(Fq *r,const unsigned char *s)
{
  uint16 R[p],M[p];
  int i;

  for (i = 0;i < p;++i) M[i] = (q+2)/3;

#ifdef ROUND_DECODE_TEST
  FILE *fp;
  fp = fdopen(7, "a");

  fprintf(fp, "%d\n", Rounded_bytes);
  for (i = 0;i < Rounded_bytes; ++i)
    fprintf(fp, "%02x ", s[i]);

  fprintf(fp, "\n%d\n", p);
#endif

  Decode(R,s,M,p);
  //for (i = 0;i < p;++i) r[i] = R[i]*3-q12;

  for (i = 0;i < p;++i) {

#ifdef ROUND_DECODE_TEST
    fprintf(fp, "%04x ", R[i]);
#endif

    r[i] = R[i]*3-q12;
  }

#ifdef ROUND_DECODE_TEST
  fprintf(fp, "\n");
  fflush(fp);
#endif

}

#ifdef INTERVALUE_GEN
static void Rounded_encode_w_ivg(char *s_name, unsigned char *s, char *r_name, char *r_name_offset, const Fq *r)
{
  uint16 R[p],M[p];
  int i;

  ivg_print_int16array(r_name, r, p);

  for (i = 0;i < p;++i) R[i] = ((r[i]+q12)*10923)>>15;

  ivg_print_uint16array(r_name_offset, R, p);

  for (i = 0;i < p;++i) M[i] = (q+2)/3;

  Encode(s,R,M,p);

  ivg_print_uint8array(s_name, s, Rounded_bytes);

}

static void Rounded_decode_w_ivg(char *r_name, char *r_name_offset, Fq *r, char *s_name, const unsigned char *s)
{
  uint16 R[p],M[p];
  int i;

  ivg_print_uint8array(s_name, s, Rounded_bytes);

  for (i = 0;i < p;++i) M[i] = (q+2)/3;

  Decode(R,s,M,p);

  ivg_print_uint16array(r_name_offset, R, p);

  for (i = 0;i < p;++i) r[i] = R[i]*3-q12;

  ivg_print_int16array(r_name, r, p);

}
#endif


/* ----- encoding top polynomials */

#ifdef LPR

#define Top_bytes (I/2)

static void Top_encode(unsigned char *s,const int8 *T)
{
  int i;
  for (i = 0;i < Top_bytes;++i)
    s[i] = T[2*i]+(T[2*i+1]<<4);
}

static void Top_decode(int8 *T,const unsigned char *s)
{
  int i;
  for (i = 0;i < Top_bytes;++i) {
    T[2*i] = s[i]&15;
    T[2*i+1] = s[i]>>4;
  }
}

#endif

/* ----- Streamlined NTRU Prime Core plus encoding */

#ifndef LPR

typedef small Inputs[p]; /* passed by reference */
#define Inputs_random Short_random
#define Inputs_encode Small_encode
#define Inputs_bytes Small_bytes

#define Ciphertexts_bytes Rounded_bytes
#define SecretKeys_bytes (2*Small_bytes)
#define PublicKeys_bytes Rq_bytes

/* pk,sk = ZKeyGen() */
static void ZKeyGen(unsigned char *pk,unsigned char *sk)
{
  Fq h[p];
  small f[p],v[p];

  KeyGen(h,f,v);
  Rq_encode(pk,h);
  Small_encode(sk,f); sk += Small_bytes;
  Small_encode(sk,v);
}

/* C = ZEncrypt(r,pk) */
static void ZEncrypt(unsigned char *C,const Inputs r,const unsigned char *pk)
{
  Fq h[p];
  Fq c[p];
  Rq_decode(h,pk);
  Encrypt(c,r,h);
  Rounded_encode(C,c);
}

#ifdef INTERVALUE_GEN
static void ZEncrypt_w_ivg(unsigned char *C,const Inputs r,const unsigned char *pk)
{
  Fq h[p];
  Fq c[p];
  #ifdef INTERVALUE_GEN_NONEED
    Rq_decode_w_ivg("h", "h_offset", h, "h_pack", pk);
  #else
    Rq_decode(h,pk);
  #endif
  Encrypt_w_ivg(c,r,h);
  #ifdef INTERVALUE_GEN_NONEED
    Rounded_encode_w_ivg("c_pack", C, "c", "c_offset", c);
  #else
    Rounded_encode(C,c);
  #endif
}
#endif

/* r = ZDecrypt(C,sk) */
static void ZDecrypt(Inputs r,const unsigned char *C,const unsigned char *sk)
{
  small f[p],v[p];
  Fq c[p];

  Small_decode(f,sk); sk += Small_bytes;
  Small_decode(v,sk);
  Rounded_decode(c,C);
  Decrypt(r,c,f,v);
}

#endif

/* ----- NTRU LPRime Expand plus encoding */

#ifdef LPR

#define Ciphertexts_bytes (Rounded_bytes+Top_bytes)
#define SecretKeys_bytes Small_bytes
#define PublicKeys_bytes (Seeds_bytes+Rounded_bytes)

static void Inputs_random(Inputs r)
{
  unsigned char s[Inputs_bytes];
  int i;

  randombytes(s,sizeof s);
  for (i = 0;i < I;++i) r[i] = 1&(s[i>>3]>>(i&7));
}

/* pk,sk = ZKeyGen() */
static void ZKeyGen(unsigned char *pk,unsigned char *sk)
{
  Fq A[p];
  small a[p];

  XKeyGen(pk,A,a); pk += Seeds_bytes;
  Rounded_encode(pk,A);
  Small_encode(sk,a);
}

/* c = ZEncrypt(r,pk) */
static void ZEncrypt(unsigned char *c,const Inputs r,const unsigned char *pk)
{
  Fq A[p];
  Fq B[p];
  int8 T[I];

  Rounded_decode(A,pk+Seeds_bytes);
  XEncrypt(B,T,r,pk,A);
  Rounded_encode(c,B); c += Rounded_bytes;
  Top_encode(c,T);
}

/* r = ZDecrypt(C,sk) */
static void ZDecrypt(Inputs r,const unsigned char *c,const unsigned char *sk)
{
  small a[p];
  Fq B[p];
  int8 T[I];

  Small_decode(a,sk);
  Rounded_decode(B,c);
  Top_decode(T,c+Rounded_bytes);
  XDecrypt(r,B,T,a);
}

#endif

/* ----- confirmation hash */

#define Confirm_bytes 32

/* h = HashConfirm(r,pk,cache); cache is Hash4(pk) */
static void HashConfirm(unsigned char *h,const unsigned char *r,const unsigned char *pk,const unsigned char *cache)
{
#ifndef LPR
  unsigned char x[Hash_bytes*2];
  int i;

  Hash_prefix(x,3,r,Inputs_bytes);

  for (i = 0;i < Hash_bytes;++i) x[Hash_bytes+i] = cache[i];
#else
  unsigned char x[Inputs_bytes+Hash_bytes];
  int i;

  for (i = 0;i < Inputs_bytes;++i) x[i] = r[i];
  for (i = 0;i < Hash_bytes;++i) x[Inputs_bytes+i] = cache[i];
#endif
  Hash_prefix(h,2,x,sizeof x);
}

#ifdef INTERVALUE_GEN
static void HashConfirm_w_ivg(unsigned char *h,const unsigned char *r,const unsigned char *pk,const unsigned char *cache)
{
#ifndef LPR
  unsigned char x[Hash_bytes*2];
  int i;

  Hash_prefix(x,3,r,Inputs_bytes);

  //ivg_print_uint8array("r_packed", r, Inputs_bytes);
  //ivg_print_uint8array("Hash3(r)", x, Hash_bytes);

  for (i = 0;i < Hash_bytes;++i) x[Hash_bytes+i] = cache[i];
#else
  unsigned char x[Inputs_bytes+Hash_bytes];
  int i;

  for (i = 0;i < Inputs_bytes;++i) x[i] = r[i];
  for (i = 0;i < Hash_bytes;++i) x[Inputs_bytes+i] = cache[i];
#endif
  Hash_prefix(h,2,x,sizeof x);

  ivg_print_uint8array("HashConfirm", h, Hash_bytes);
}
#endif

/* ----- session-key hash */

/* k = HashSession(b,y,z) */
static void HashSession(unsigned char *k,int b,const unsigned char *y,const unsigned char *z)
{
#ifndef LPR
  unsigned char x[Hash_bytes+Ciphertexts_bytes+Confirm_bytes];
  int i;

  Hash_prefix(x,3,y,Inputs_bytes);
  for (i = 0;i < Ciphertexts_bytes+Confirm_bytes;++i) x[Hash_bytes+i] = z[i];
#else
  unsigned char x[Inputs_bytes+Ciphertexts_bytes+Confirm_bytes];
  int i;

  for (i = 0;i < Inputs_bytes;++i) x[i] = y[i];
  for (i = 0;i < Ciphertexts_bytes+Confirm_bytes;++i) x[Inputs_bytes+i] = z[i];
#endif
  Hash_prefix(k,b,x,sizeof x);
}

/* ----- Streamlined NTRU Prime and NTRU LPRime */

/* pk,sk = KEM_KeyGen() */
static void KEM_KeyGen(unsigned char *pk,unsigned char *sk)
{
  int i;

  ZKeyGen(pk,sk); sk += SecretKeys_bytes;
  for (i = 0;i < PublicKeys_bytes;++i) *sk++ = pk[i];
  randombytes(sk,Inputs_bytes);
  #ifdef INTERVALUE_GEN
    ivg_print_uint8array("rho", sk, Inputs_bytes);
  #endif
  sk += Inputs_bytes;
  Hash_prefix(sk,4,pk,PublicKeys_bytes);
}

/* c,r_enc = Hide(r,pk,cache); cache is Hash4(pk) */
static void Hide(unsigned char *c,unsigned char *r_enc,const Inputs r,const unsigned char *pk,const unsigned char *cache)
{
  Inputs_encode(r_enc,r);
#ifdef KAT
  {
    int j;
    printf("Hide r_enc: ");
    for (j = 0;j < Inputs_bytes;++j) printf("%02x",r_enc[j]);
    printf("\n");
  }
#endif
  ZEncrypt(c,r,pk);
  c += Ciphertexts_bytes;
  HashConfirm(c,r_enc,pk,cache);
}

#ifdef INTERVALUE_GEN
static void Hide_w_ivg(unsigned char *c,unsigned char *r_enc,const Inputs r,const unsigned char *pk,const unsigned char *cache)
{
  Inputs_encode(r_enc,r);
#ifdef KAT
  {
    int j;
    printf("Hide r_enc: ");
    for (j = 0;j < Inputs_bytes;++j) printf("%02x",r_enc[j]);
    printf("\n");
  }
#endif
  #ifdef INTERVALUE_GEN
    ZEncrypt_w_ivg(c,r,pk);
  #else
    ZEncrypt(c,r,pk);
  #endif
  c += Ciphertexts_bytes;
  HashConfirm_w_ivg(c,r_enc,pk,cache);
}
#endif

/* c,k = Encap(pk) */
static void Encap(unsigned char *c,unsigned char *k,const unsigned char *pk)
{
  Inputs r;
  unsigned char r_enc[Inputs_bytes];
  unsigned char cache[Hash_bytes];

  Hash_prefix(cache,4,pk,PublicKeys_bytes);
  #ifdef INTERVALUE_GEN
    //ivg_print_uint8array("Hash4(pk)", cache, Hash_bytes); 
  #endif
  Inputs_random(r);
  #ifdef INTERVALUE_GEN
  Hide_w_ivg(c,r_enc,r,pk,cache);
  #else
  Hide(c,r_enc,r,pk,cache);
  #endif
  HashSession(k,1,r_enc,c);
}

/* 0 if matching ciphertext+confirm, else -1 */
static int Ciphertexts_diff_mask(const unsigned char *c,const unsigned char *c2)
{
  uint16 differentbits = 0;
  int len = Ciphertexts_bytes+Confirm_bytes;

  while (len-- > 0) differentbits |= (*c++)^(*c2++);
  return (1&((differentbits-1)>>8))-1;
}

/* k = Decap(c,sk) */
static void Decap(unsigned char *k,const unsigned char *c,const unsigned char *sk)
{
  const unsigned char *pk = sk + SecretKeys_bytes;
  const unsigned char *rho = pk + PublicKeys_bytes;
  const unsigned char *cache = rho + Inputs_bytes;
  Inputs r;
  unsigned char r_enc[Inputs_bytes];
  unsigned char cnew[Ciphertexts_bytes+Confirm_bytes];
  int mask;
  int i;

  ZDecrypt(r,c,sk);
  Hide(cnew,r_enc,r,pk,cache);
  mask = Ciphertexts_diff_mask(c,cnew);
  for (i = 0;i < Inputs_bytes;++i) r_enc[i] ^= mask&(r_enc[i]^rho[i]);
  HashSession(k,1+mask,r_enc,c);
}

/* ----- crypto_kem API */

#include "crypto_kem.h"

int crypto_kem_keypair(unsigned char *pk,unsigned char *sk)
{
  KEM_KeyGen(pk,sk);
  return 0;
}

int crypto_kem_enc(unsigned char *c,unsigned char *k,const unsigned char *pk)
{
  Encap(c,k,pk);
  return 0;
}

int crypto_kem_dec(unsigned char *k,const unsigned char *c,const unsigned char *sk)
{
  Decap(k,c,sk);
  return 0;
}
