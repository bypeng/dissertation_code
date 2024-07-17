
DEC_SRC=decode.v barrett.v bram.v
DEC_TB_SRC=decode_tb.v

ENC_SRC=encode.v bram.v
ENC_TB_SRC=encode_tb.v

TB_ENC_DATA_4621=encode_p653q4621_memP_ref.v rp653param.v params10.v
TB_ENC_DATA_1541=encode_p653q1541_memP_ref.v rp653param.v params10.v
TB_DEC_DATA_4621=decode_p653q4621_memP_ref.v rp653param.v params10.v
TB_DEC_DATA_1541=decode_p653q1541_memP_ref.v rp653param.v params10.v
TB_ENC_DATA_4591=encode_p761q4591_memP_ref.v rp761param.v params10.v
TB_ENC_DATA_1531=encode_p761q1531_memP_ref.v rp761param.v params10.v
TB_DEC_DATA_4591=decode_p761q4591_memP_ref.v rp761param.v params10.v
TB_DEC_DATA_1531=decode_p761q1531_memP_ref.v rp761param.v params10.v
TB_ENC_DATA_5167=encode_p857q5167_memP_ref.v rp857param.v params10.v
TB_ENC_DATA_1723=encode_p857q1723_memP_ref.v rp857param.v params10.v
TB_DEC_DATA_5167=decode_p857q5167_memP_ref.v rp857param.v params10.v
TB_DEC_DATA_1723=decode_p857q1723_memP_ref.v rp857param.v params10.v
TB_ENC_DATA_6343=encode_p953q6343_memP_ref.v rp953param.v params10.v
TB_ENC_DATA_2115=encode_p953q2115_memP_ref.v rp953param.v params10.v
TB_DEC_DATA_6343=decode_p953q6343_memP_ref.v rp953param.v params10.v
TB_DEC_DATA_2115=decode_p953q2115_memP_ref.v rp953param.v params10.v
TB_ENC_DATA_7177=encode_p1013q7177_memP_ref.v rp1013param.v params10.v
TB_ENC_DATA_2393=encode_p1013q2393_memP_ref.v rp1013param.v params10.v
TB_DEC_DATA_7177=decode_p1013q7177_memP_ref.v rp1013param.v params10.v
TB_DEC_DATA_2393=decode_p1013q2393_memP_ref.v rp1013param.v params10.v
TB_ENC_DATA_7879=encode_p1277q7879_memP_ref.v rp1277param.v params11.v
TB_ENC_DATA_2627=encode_p1277q2627_memP_ref.v rp1277param.v params11.v
TB_DEC_DATA_7879=decode_p1277q7879_memP_ref.v rp1277param.v params11.v
TB_DEC_DATA_2627=decode_p1277q2627_memP_ref.v rp1277param.v params11.v

VCSRC = /usr/cad/synopsys/CIC/vcs.cshrc
VERDIRC = /usr/cad/synopsys/CIC/verdi.cshrc

SIMULATOR = vcs
ARGUMENT = -full64 -R -debug_access+all +v2k
CC_4621= +define+Q4621
CC_1541= +define+Q1541
CC_4591= +define+Q4591
CC_1531= +define+Q1531
CC_5167= +define+Q5167
CC_1723= +define+Q1723
CC_6343= +define+Q6343
CC_2115= +define+Q2115
CC_7177= +define+Q7177
CC_2393= +define+Q2393
CC_7879= +define+Q7879
CC_2627= +define+Q2627

.PHONY: clean all enc4621 dec4621 enc1541 dec1541 enc4591 dec4591 enc1531 dec1531 enc5167 dec5167 enc1723 dec1723 enc6343 dec6343 enc2115 dec2115 enc7177 dec7177 enc2393 dec2393 enc7879 dec7879 enc2627 dec2627



all: all_enc all_dec

all_enc: enc4621 enc1541 enc4591 enc1531 enc5167 enc1723 enc6343 enc2115 enc7177 enc2393 enc7879 enc2627

all_dec: dec4621 dec1541 dec4591 dec1531 dec5167 dec1723 dec6343 dec2115 dec7177 dec2393 dec7879 dec2627



enc4621: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_4621)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_4621) $(CC_4621) $(ARGUMENT)'
	rm -f params.v

dec4621: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_4621)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_4621) $(CC_4621) $(ARGUMENT)'
	rm -f params.v

enc1541: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_1541)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_1541) $(CC_1541) $(ARGUMENT)'
	rm -f params.v

dec1541: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_1541)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_1541) $(CC_1541) $(ARGUMENT)'
	rm -f params.v


enc4591: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_4591)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_4591) $(CC_4591) $(ARGUMENT)'
	rm -f params.v

dec4591: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_4591)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_4591) $(CC_4591) $(ARGUMENT)'
	rm -f params.v

enc1531: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_1531)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_1531) $(CC_1531) $(ARGUMENT)'
	rm -f params.v

dec1531: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_1531)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_1531) $(CC_1531) $(ARGUMENT)'
	rm -f params.v


enc5167: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_5167)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_5167) $(CC_5167) $(ARGUMENT)'
	rm -f params.v

dec5167: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_5167)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_5167) $(CC_5167) $(ARGUMENT)'
	rm -f params.v

enc1723: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_1723)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_1723) $(CC_1723) $(ARGUMENT)'
	rm -f params.v

dec1723: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_1723)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_1723) $(CC_1723) $(ARGUMENT)'
	rm -f params.v


enc6343: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_6343)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_6343) $(CC_6343) $(ARGUMENT)'
	rm -f params.v

dec6343: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_6343)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_6343) $(CC_6343) $(ARGUMENT)'
	rm -f params.v

enc2115: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_2115)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_2115) $(CC_2115) $(ARGUMENT)'
	rm -f params.v

dec2115: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_2115)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_2115) $(CC_2115) $(ARGUMENT)'
	rm -f params.v


enc7177: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_7177)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_7177) $(CC_7177) $(ARGUMENT)'
	rm -f params.v

dec7177: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_7177)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_7177) $(CC_7177) $(ARGUMENT)'
	rm -f params.v

enc2393: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_2393)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_2393) $(CC_2393) $(ARGUMENT)'
	rm -f params.v

dec2393: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_2393)
	rm -f params.v
	ln -s params10.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_2393) $(CC_2393) $(ARGUMENT)'
	rm -f params.v


enc7879: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_7879)
	rm -f params.v
	ln -s params11.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_7879) $(CC_7879) $(ARGUMENT)'
	rm -f params.v

dec7879: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_7879)
	rm -f params.v
	ln -s params11.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_7879) $(CC_7879) $(ARGUMENT)'
	rm -f params.v

enc2627: $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_2627)
	rm -f params.v
	ln -s params11.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(ENC_TB_SRC) $(ENC_SRC) $(TB_ENC_DATA_2627) $(CC_2627) $(ARGUMENT)'
	rm -f params.v

dec2627: $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_2627)
	rm -f params.v
	ln -s params11.v params.v
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(DEC_TB_SRC) $(DEC_SRC) $(TB_DEC_DATA_2627) $(CC_2627) $(ARGUMENT)'
	rm -f params.v



clean:
	rm -rf INCA_libs
	rm -rf csrc
	rm -rf simv.daidir
	rm -rf xcelium.d
	rm -rf nWaveLog
	rm -f *.fsdb ncverilog.history ncverilog.log novas.conf novas.rc novas_dump.log ucli.key simv



help:
	@echo "Supported targets:"
	@echo "------------------"
	# @echo "all:                              Build all simulation targets and simulate."
	# @echo "top:                              Build the top simulation target and simulate."
	@echo "enc4621/4591/5167/6343/7177/7879: Build the enc with pipe simulation target and simulate Rq Encode."
	@echo "dec4621/4591/5167/6343/7177/7879: Build the dec with pipe simulation target and simulate Rq Decode."
	@echo "enc1541/1531/1723/2115/2393/2627: Build the enc with pipe simulation target and simulate Round Encode."
	@echo "dec1541/1531/1723/2115/2393/2627: Build the dec with pipe simulation target and simulate Round Decode."
	@echo "clean:                            Delete all build/simulation files."



#===================================================================
# EOF Makefile
#===================================================================

