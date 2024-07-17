#ifndef crypto_kem_H
#define crypto_kem_H

#include "paramsmenu.h"

#if defined(SIZE653)
#include "crypto_kem_sntrup653.h"
#define crypto_kem_keypair crypto_kem_sntrup653_keypair
#define crypto_kem_enc crypto_kem_sntrup653_enc
#define crypto_kem_dec crypto_kem_sntrup653_dec
#define crypto_kem_PUBLICKEYBYTES crypto_kem_sntrup653_PUBLICKEYBYTES
#define crypto_kem_SECRETKEYBYTES crypto_kem_sntrup653_SECRETKEYBYTES
#define crypto_kem_BYTES crypto_kem_sntrup653_BYTES
#define crypto_kem_CIPHERTEXTBYTES crypto_kem_sntrup653_CIPHERTEXTBYTES
#define crypto_kem_PRIMITIVE "sntrup653"


#elif defined(SIZE761)
#include "crypto_kem_sntrup761.h"
#define crypto_kem_keypair crypto_kem_sntrup761_keypair
#define crypto_kem_enc crypto_kem_sntrup761_enc
#define crypto_kem_dec crypto_kem_sntrup761_dec
#define crypto_kem_PUBLICKEYBYTES crypto_kem_sntrup761_PUBLICKEYBYTES
#define crypto_kem_SECRETKEYBYTES crypto_kem_sntrup761_SECRETKEYBYTES
#define crypto_kem_BYTES crypto_kem_sntrup761_BYTES
#define crypto_kem_CIPHERTEXTBYTES crypto_kem_sntrup761_CIPHERTEXTBYTES
#define crypto_kem_PRIMITIVE "sntrup761"


#elif defined(SIZE857)
#include "crypto_kem_sntrup857.h"
#define crypto_kem_keypair crypto_kem_sntrup857_keypair
#define crypto_kem_enc crypto_kem_sntrup857_enc
#define crypto_kem_dec crypto_kem_sntrup857_dec
#define crypto_kem_PUBLICKEYBYTES crypto_kem_sntrup857_PUBLICKEYBYTES
#define crypto_kem_SECRETKEYBYTES crypto_kem_sntrup857_SECRETKEYBYTES
#define crypto_kem_BYTES crypto_kem_sntrup857_BYTES
#define crypto_kem_CIPHERTEXTBYTES crypto_kem_sntrup857_CIPHERTEXTBYTES
#define crypto_kem_PRIMITIVE "sntrup857"


#elif defined(SIZE953)
#include "crypto_kem_sntrup953.h"
#define crypto_kem_keypair crypto_kem_sntrup953_keypair
#define crypto_kem_enc crypto_kem_sntrup953_enc
#define crypto_kem_dec crypto_kem_sntrup953_dec
#define crypto_kem_PUBLICKEYBYTES crypto_kem_sntrup953_PUBLICKEYBYTES
#define crypto_kem_SECRETKEYBYTES crypto_kem_sntrup953_SECRETKEYBYTES
#define crypto_kem_BYTES crypto_kem_sntrup953_BYTES
#define crypto_kem_CIPHERTEXTBYTES crypto_kem_sntrup953_CIPHERTEXTBYTES
#define crypto_kem_PRIMITIVE "sntrup953"

#elif defined(SIZE1013)
#include "crypto_kem_sntrup1013.h"
#define crypto_kem_keypair crypto_kem_sntrup1013_keypair
#define crypto_kem_enc crypto_kem_sntrup1013_enc
#define crypto_kem_dec crypto_kem_sntrup1013_dec
#define crypto_kem_PUBLICKEYBYTES crypto_kem_sntrup1013_PUBLICKEYBYTES
#define crypto_kem_SECRETKEYBYTES crypto_kem_sntrup1013_SECRETKEYBYTES
#define crypto_kem_BYTES crypto_kem_sntrup1013_BYTES
#define crypto_kem_CIPHERTEXTBYTES crypto_kem_sntrup1013_CIPHERTEXTBYTES
#define crypto_kem_PRIMITIVE "sntrup1013"

#elif defined(SIZE1277)
#include "crypto_kem_sntrup1277.h"
#define crypto_kem_keypair crypto_kem_sntrup1277_keypair
#define crypto_kem_enc crypto_kem_sntrup1277_enc
#define crypto_kem_dec crypto_kem_sntrup1277_dec
#define crypto_kem_PUBLICKEYBYTES crypto_kem_sntrup1277_PUBLICKEYBYTES
#define crypto_kem_SECRETKEYBYTES crypto_kem_sntrup1277_SECRETKEYBYTES
#define crypto_kem_BYTES crypto_kem_sntrup1277_BYTES
#define crypto_kem_CIPHERTEXTBYTES crypto_kem_sntrup1277_CIPHERTEXTBYTES
#define crypto_kem_PRIMITIVE "sntrup1277"

#endif

#endif
