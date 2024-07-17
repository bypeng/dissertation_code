SIMULATOR = vcs
ARGUMENT = -full64 -R -debug_access+all +v2k

VCSRC = /usr/cad/synopsys/CIC/vcs.cshrc
VERDIRC = /usr/cad/synopsys/CIC/verdi.cshrc

TESTBENCH = mod4591S33_tb.v
SOURCE = mod4591S33.v mod4591Svec33.v

.PHONY: clean all mod4591S33

all: mod4591S33

mod4591S33: $(TESTBENCH) $(SOURCE)
	csh -c 'source $(VCSRC) ; source $(VERDIRC) ; $(SIMULATOR) $(TESTBENCH) $(SOURCE) $(ARGUMENT)'

clean:
	rm -rf INCA_libs
	rm -rf csrc
	rm -rf simv.daidir
	rm -rf xcelium.d
	rm -rf nWaveLog
	rm -f *.fsdb ncverilog.history ncverilog.log novas.conf novas.rc novas_dump.log ucli.key simv
