.SECONDEXPANSION:
# .PHONY: all sntrup761_old sntrup857 sntrup953 sntrup1013 sntrup1013_3prime sntrup1277 sntrup1277_3prime clean
.PHONY: all ntt_p32_163841 ntt_p64_163841 ntt_p128_163841 ntt_p256_163841 ntt_p512_163841 ntt_p1024_163841 ntt_p2048_163841 ntt_p4096_163841 ntt_p8192_163841 ntt_p16384_163841 sntrup653 sntrup653_good3 sntrup761 sntrup761_good3 sntrup857 sntrup953 sntrup1013 sntrup1277 sntrup1277_good3 sntrup1277_good5 clean

VCSRC = /usr/cad/synopsys/CIC/vcs.cshrc
VERDIRC = /usr/cad/synopsys/CIC/verdi.cshrc

STOOL = vcs
PM1 = +define+PRIMEP=653 +define+PCOVER=1024 +define+PRIMEQ=4621
PM1GOOD3 = +define+PRIMEP=653 +define+PCOVER=768 +define+PRIMEQ=4621
PM2 = +define+PRIMEP=761 +define+PCOVER=1024 +define+PRIMEQ=4591
PM2GOOD3 = +define+PRIMEP=761 +define+PCOVER=768 +define+PRIMEQ=4591
PM3 = +define+PRIMEP=857 +define+PCOVER=1024 +define+PRIMEQ=5167
PM4 = +define+PRIMEP=953 +define+PCOVER=1024 +define+PRIMEQ=6343
PM5 = +define+PRIMEP=1013 +define+PCOVER=1024 +define+PRIMEQ=7177
PM6 = +define+PRIMEP=1277 +define+PCOVER=2048 +define+PRIMEQ=7879
PM6GOOD3 = +define+PRIMEP=1277 +define+PCOVER=1536 +define+PRIMEQ=7879
PM6GOOD5 = +define+PRIMEP=1277 +define+PCOVER=1280 +define+PRIMEQ=7879
ARGS = -full64 -R -debug_access+all +v2k

TESTBENCH = tb_ntt.v test_data.v


all: sntrup653 sntrup653_good3 sntrup761 sntrup761_good3_17 sntrup761_good3 sntrup857 sntrup953 sntrup1013 sntrup1277 sntrup1277_good3 sntrup1277_good5


ntt_p32_163841: NTTMODULE = ntt32_163841
ntt_p32_163841: NTTFILE = $(NTTMODULE).v
ntt_p32_163841: BRAMFILE = bram_18_6_P.v
ntt_p32_163841: MODFILE = modmul163841s.v
ntt_p32_163841: PM_SINGLE = +define+PRIMEP=32 +define+PCOVER=32 +define+PRIMEQ=163841
ntt_p32_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 32 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p64_163841: NTTMODULE = ntt64_163841
ntt_p64_163841: NTTFILE = $(NTTMODULE).v
ntt_p64_163841: BRAMFILE = bram_18_7_P.v
ntt_p64_163841: MODFILE = modmul163841s.v
ntt_p64_163841: PM_SINGLE = +define+PRIMEP=64 +define+PCOVER=64 +define+PRIMEQ=163841
ntt_p64_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 64 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p128_163841: NTTMODULE = ntt128_163841
ntt_p128_163841: NTTFILE = $(NTTMODULE).v
ntt_p128_163841: BRAMFILE = bram_18_8_P.v
ntt_p128_163841: MODFILE = modmul163841s.v
ntt_p128_163841: PM_SINGLE = +define+PRIMEP=128 +define+PCOVER=128 +define+PRIMEQ=163841
ntt_p128_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 128 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p256_163841: NTTMODULE = ntt256_163841
ntt_p256_163841: NTTFILE = $(NTTMODULE).v
ntt_p256_163841: BRAMFILE = bram_18_9_P.v
ntt_p256_163841: MODFILE = modmul163841s.v
ntt_p256_163841: PM_SINGLE = +define+PRIMEP=256 +define+PCOVER=256 +define+PRIMEQ=163841
ntt_p256_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 256 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p512_163841: NTTMODULE = ntt512_163841
ntt_p512_163841: NTTFILE = $(NTTMODULE).v
ntt_p512_163841: BRAMFILE = bram_18_10_P.v
ntt_p512_163841: MODFILE = modmul163841s.v
ntt_p512_163841: PM_SINGLE = +define+PRIMEP=512 +define+PCOVER=512 +define+PRIMEQ=163841
ntt_p512_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 512 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p1024_163841: NTTMODULE = ntt1024_163841
ntt_p1024_163841: NTTFILE = $(NTTMODULE).v
ntt_p1024_163841: BRAMFILE = bram_18_11_P.v
ntt_p1024_163841: MODFILE = modmul163841s.v
ntt_p1024_163841: PM_SINGLE = +define+PRIMEP=1024 +define+PCOVER=1024 +define+PRIMEQ=163841
ntt_p1024_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 1024 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p2048_163841: NTTMODULE = ntt2048_163841
ntt_p2048_163841: NTTFILE = $(NTTMODULE).v
ntt_p2048_163841: BRAMFILE = bram_18_12_P.v
ntt_p2048_163841: MODFILE = modmul163841s.v
ntt_p2048_163841: PM_SINGLE = +define+PRIMEP=2048 +define+PCOVER=2048 +define+PRIMEQ=163841
ntt_p2048_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 2048 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p4096_163841: NTTMODULE = ntt4096_163841
ntt_p4096_163841: NTTFILE = $(NTTMODULE).v
ntt_p4096_163841: BRAMFILE = bram_18_13_P.v
ntt_p4096_163841: MODFILE = modmul163841s.v
ntt_p4096_163841: PM_SINGLE = +define+PRIMEP=4096 +define+PCOVER=4096 +define+PRIMEQ=163841
ntt_p4096_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 4096 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p8192_163841: NTTMODULE = ntt8192_163841
ntt_p8192_163841: NTTFILE = $(NTTMODULE).v
ntt_p8192_163841: BRAMFILE = bram_18_14_P.v
ntt_p8192_163841: MODFILE = modmul163841s.v
ntt_p8192_163841: PM_SINGLE = +define+PRIMEP=8192 +define+PCOVER=8192 +define+PRIMEQ=163841
ntt_p8192_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 8192 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


ntt_p16384_163841: NTTMODULE = ntt16384_163841
ntt_p16384_163841: NTTFILE = $(NTTMODULE).v
ntt_p16384_163841: BRAMFILE = bram_18_15_P.v
ntt_p16384_163841: MODFILE = modmul163841s.v
ntt_p16384_163841: PM_SINGLE = +define+PRIMEP=16384 +define+PCOVER=16384 +define+PRIMEQ=163841
ntt_p16384_163841: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 16384 -q0 163841
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM_SINGLE) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup653: NTTMODULE = ntt653_4621_by_163841_249857
sntrup653: NTTFILE = $(NTTMODULE).v
sntrup653: BRAMFILE = bram_36_11_P.v
sntrup653: MODFILE = mod4621S33.v mod4621Svec33.v modmul163841s.v modmul249857s.v
sntrup653: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 653 -q0 4621 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM1) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup653_good3: NTTMODULE = ntt653good3_4621_by_163841_249857
sntrup653_good3: NTTFILE = $(NTTMODULE).v
sntrup653_good3: BRAMFILE = bram_36_11_P.v
sntrup653_good3: MODFILE = mod4621S33.v mod4621Svec33.v modmul163841s.v modmul249857s.v
sntrup653_good3: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_nttGood3_test_gen_sage.py -p 653 -q0 4621 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM1GOOD3) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup761: NTTMODULE = ntt761_4591_by_163841_249857
sntrup761: NTTFILE = $(NTTMODULE).v
sntrup761: BRAMFILE = bram_36_11_P.v
sntrup761: MODFILE = mod4591S33.v mod4591Svec33.v modmul163841s.v modmul249857s.v
sntrup761: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 761 -q0 4591 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM2) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup761_good3_17: NTTMODULE = ntt761good3_4591_by_114689_120833
sntrup761_good3_17: NTTFILE = $(NTTMODULE).v
sntrup761_good3_17: BRAMFILE = bram_34_11_P.v
sntrup761_good3_17: MODFILE = mod4591S33.v mod4591Svec33.v modmul114689s.v modmul120833s.v
sntrup761_good3_17: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_nttGood3_test_gen_sage.py -p 761 -q0 4591 -qs 114689 120833
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM2GOOD3) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup761_good3: NTTMODULE = ntt761good3_4591_by_163841_249857
sntrup761_good3: NTTFILE = $(NTTMODULE).v
sntrup761_good3: BRAMFILE = bram_36_11_P.v
sntrup761_good3: MODFILE = mod4591S33.v mod4591Svec33.v modmul163841s.v modmul249857s.v
sntrup761_good3: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_nttGood3_test_gen_sage.py -p 761 -q0 4591 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM2GOOD3) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup761_old: TESTBENCH = ref/tb_ntt_good3ntt512.v ref/data_rom.v
sntrup761_old: NTTFILE = ref/ntt761good3_4591_by_7681_12289_15361.v
sntrup761_old: BRAMFILE = ref/bram.v
sntrup761_old: MODFILE = mod4591S33.v mod4591Svec33.v modmul7681s.v mod12289s.v modmul15361s.v
sntrup761_old: $$(NTTFILE) $$(BRAMFILE) $$(MODFILE) $$(TESTBENCH)
	# test_data_gen/poly_mul_nttGood3_test_gen_sage.py -p 761 -q0 4591 -qs 7681 12289 15361
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup761_oldred: TESTBENCH = ref/tb_ntt_good3ntt512.v ref/data_rom.v
sntrup761_oldred: NTTFILE = ref/ntt_7681_12289_15361_red.v
sntrup761_oldred: BRAMFILE = ref/bram.v
sntrup761_oldred: MODFILE = mod4591S33.v mod4591Svec33.v modmul7681s.v mod12289s.v modmul15361s.v
sntrup761_oldred: $$(NTTFILE) $$(BRAMFILE) $$(MODFILE) $$(TESTBENCH)
	# test_data_gen/poly_mul_nttGood3_test_gen_sage.py -p 761 -q0 4591 -qs 7681 12289 15361
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup857: NTTMODULE = ntt857_5167_by_163841_249857
sntrup857: NTTFILE = $(NTTMODULE).v
sntrup857: BRAMFILE = bram_36_11_P.v
sntrup857: MODFILE = mod5167S34.v mod5167Svec34.v modmul163841s.v modmul249857s.v
sntrup857: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 857 -q0 5167 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM3) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup953: NTTMODULE = ntt953_6343_by_163841_249857
sntrup953: NTTFILE = $(NTTMODULE).v
sntrup953: BRAMFILE = bram_36_11_P.v
sntrup953: MODFILE = mod6343S35.v mod6343Svec35.v modmul163841s.v modmul249857s.v
sntrup953: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 953 -q0 6343 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM4) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup1013: NTTMODULE = ntt1013_7177_by_163841_249857
sntrup1013: NTTFILE = $(NTTMODULE).v
sntrup1013: BRAMFILE = bram_36_11_P.v
sntrup1013: MODFILE = mod7177S35.v mod7177Svec35.v modmul163841s.v modmul249857s.v
sntrup1013: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 1013 -q0 7177 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM5) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup1277: NTTMODULE = ntt1277_7879_by_163841_249857
sntrup1277: NTTFILE = $(NTTMODULE).v
sntrup1277: BRAMFILE = bram_36_12_P.v
sntrup1277: MODFILE = mod7879S36.v mod7879Svec36.v modmul163841s.v modmul249857s.v
sntrup1277: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_fullntt_test_gen_sage.py -p 1277 -q0 7879 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM6) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup1277_good3: NTTMODULE = ntt1277good3_7879_by_163841_249857
sntrup1277_good3: NTTFILE = $(NTTMODULE).v
sntrup1277_good3: BRAMFILE = bram_36_12_P.v
sntrup1277_good3: MODFILE = mod7879S36.v mod7879Svec36.v modmul163841s.v modmul249857s.v
sntrup1277_good3: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_nttGood3_test_gen_sage.py -p 1277 -q0 7879 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM6GOOD3) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


sntrup1277_good5: NTTMODULE = ntt1277good5_7879_by_163841_249857
sntrup1277_good5: NTTFILE = $(NTTMODULE).v
sntrup1277_good5: BRAMFILE = bram_36_12_P.v
sntrup1277_good5: MODFILE = mod7879S36.v mod7879Svec36.v modmul163841s.v modmul249857s.v
sntrup1277_good5: $(NTTFILE) $$(BRAMFILE) $$(MODFILE) $(TESTBENCH)
	# test_data_gen/poly_mul_nttGood5_test_gen_sage.py -p 1277 -q0 7879 -qs 163841 249857
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(STOOL) $(PM6GOOD5) +define+NTTMODULE=$(NTTMODULE) $(TESTBENCH) $(NTTFILE) $(BRAMFILE) $(MODFILE) $(ARGS)'


clean:
	rm -rf INCA_libs
	rm -rf csrc
	rm -rf simv.daidir
	rm -rf xcelium.d
	rm -rf nWaveLog
	rm -f *.fsdb ncverilog.history ncverilog.log novas.conf novas.rc novas_dump.log ucli.key simv

