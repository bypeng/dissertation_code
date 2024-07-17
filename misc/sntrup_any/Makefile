.PHONY: all clean kat_kem.rsp653 kat653 kat_kem.rsp761 kat761 kat_kem.rsp857 kat857 kat_kem.rsp953 kat953 kat_kem.rsp1013 kat1013 kat_kem.rsp1277 kat1277

all: kat_kem.rsp653 kat_kem.rsp761 kat_kem.rsp857 kat_kem.rsp953 kat_kem.rsp1013 kat_kem.rsp1277


kat_kem.rsp653: kat653
	./kat653 > kat_kem653.int 7> kat_kem653.com 8> kat_kem653.req 9> kat_kem653.rsp

kat653: nist/kat_kem.c nist/rng.c nist/rng.h randombytes.h Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c
	gcc -O3 -march=native -mtune=native -Wall -I. -Isubroutines -DKAT -DSIZE653 -DINTERVALUE_GEN -DKATNUM=`cat KATNUM` "-DCRYPTO_NAMESPACE(x)=x" -o kat653 nist/kat_kem.c nist/rng.c Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c -lcrypto -ldl 

kat_kem.rsp761: kat761
	./kat761 > kat_kem761.int 7> kat_kem761.com 8> kat_kem761.req 9> kat_kem761.rsp

kat761: nist/kat_kem.c nist/rng.c nist/rng.h randombytes.h Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c
	gcc -O3 -march=native -mtune=native -Wall -I. -Isubroutines -DKAT -DSIZE761 -DINTERVALUE_GEN -DKATNUM=`cat KATNUM` "-DCRYPTO_NAMESPACE(x)=x" -o kat761 nist/kat_kem.c nist/rng.c Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c -lcrypto -ldl 

kat_kem.rsp857: kat857
	./kat857 > kat_kem857.int 7> kat_kem857.com 8> kat_kem857.req 9> kat_kem857.rsp

kat857: nist/kat_kem.c nist/rng.c nist/rng.h randombytes.h Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c
	gcc -O3 -march=native -mtune=native -Wall -I. -Isubroutines -DKAT -DSIZE857 -DINTERVALUE_GEN -DKATNUM=`cat KATNUM` "-DCRYPTO_NAMESPACE(x)=x" -o kat857 nist/kat_kem.c nist/rng.c Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c -lcrypto -ldl 

kat_kem.rsp953: kat953
	./kat953 > kat_kem953.int 7> kat_kem953.com 8> kat_kem953.req 9> kat_kem953.rsp

kat953: nist/kat_kem.c nist/rng.c nist/rng.h randombytes.h Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c
	gcc -O3 -march=native -mtune=native -Wall -I. -Isubroutines -DKAT -DSIZE953 -DINTERVALUE_GEN -DKATNUM=`cat KATNUM` "-DCRYPTO_NAMESPACE(x)=x" -o kat953 nist/kat_kem.c nist/rng.c Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c -lcrypto -ldl 

kat_kem.rsp1013: kat1013
	./kat1013 > kat_kem1013.int 7> kat_kem1013.com 8> kat_kem1013.req 9> kat_kem1013.rsp

kat1013: nist/kat_kem.c nist/rng.c nist/rng.h randombytes.h Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c
	gcc -O3 -march=native -mtune=native -Wall -I. -Isubroutines -DKAT -DSIZE1013 -DINTERVALUE_GEN -DKATNUM=`cat KATNUM` "-DCRYPTO_NAMESPACE(x)=x" -o kat1013 nist/kat_kem.c nist/rng.c Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c -lcrypto -ldl 

kat_kem.rsp1277: kat1277
	./kat1277 > kat_kem1277.int 7> kat_kem1277.com 8> kat_kem1277.req 9> kat_kem1277.rsp

kat1277: nist/kat_kem.c nist/rng.c nist/rng.h randombytes.h Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c
	gcc -O3 -march=native -mtune=native -Wall -I. -Isubroutines -DKAT -DSIZE1277 -DINTERVALUE_GEN -DKATNUM=`cat KATNUM` "-DCRYPTO_NAMESPACE(x)=x" -o kat1277 nist/kat_kem.c nist/rng.c Decode.c Encode.c int32.c kem.c uint32.c subroutines/crypto_hash_sha512.c subroutines/crypto_sort_uint32.c subroutines/crypto_stream_aes256ctr.c intervaluegen/intervaluegen.c -lcrypto -ldl 

clean:
	rm -f kat_kem*.com kat_kem*.int kat_kem*.req kat_kem*.rsp
	rm -f kat653 kat761 kat857 kat953 kat1013 kat1277
	rm -f *.json

