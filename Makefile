ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
OUT_DIR  := $(ROOT_DIR)/out
SIMV     := $(OUT_DIR)/simv

VCS      ?= vcs
VERDI    ?= verdi
TEST     ?= spi_full_sweep_test
SEED     ?= 1
LOG_FILE := $(OUT_DIR)/logs/$(TEST).log
WAVE_FILE := $(OUT_DIR)/waves/$(TEST).vcd
REPORT_FILE := $(OUT_DIR)/final_report.txt

VCS_FLAGS := -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -lca
VCS_FLAGS += -debug_access+all -kdb +v2k +lint=TFIPC-L
VCS_FLAGS += -top spi_tb_top
VCS_FLAGS += -f tb/filelist.f

.PHONY: all compile run full_sweep report verdi clean

all: report

compile: $(SIMV)

$(SIMV): tb/filelist.f tb/spi_if.sv tb/spi_uvm_pkg.sv tb/spi_tb_top.sv source/spi_master.sv source/spi_slave.sv source/spi_mem.sv source/spi_master_slave_top.sv
	mkdir -p $(OUT_DIR)/logs $(OUT_DIR)/waves
	cd $(ROOT_DIR) && $(VCS) $(VCS_FLAGS) -o $(SIMV) -l $(OUT_DIR)/logs/compile.log

run: compile
	mkdir -p $(OUT_DIR)/logs $(OUT_DIR)/waves
	cd $(ROOT_DIR) && $(SIMV) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_NO_RELNOTES \
		+ntb_random_seed=$(SEED) \
		+WAVE_FILE=$(WAVE_FILE) \
		-l $(LOG_FILE)

full_sweep:
	$(MAKE) run TEST=spi_full_sweep_test SEED=$(SEED)

report: run
	sed -n 's/.*\(SPI full sweep result:.*\)/\1/p' $(LOG_FILE) > $(REPORT_FILE)
	sed -n 's/.*\(SPI full sweep overall .*\)/\1/p' $(LOG_FILE) >> $(REPORT_FILE)

verdi: run
	cd $(ROOT_DIR) && $(VERDI) -full64 -f tb/filelist.f -ssf $(WAVE_FILE) &

clean:
	rm -rf $(OUT_DIR) csrc simv.daidir ucli.key DVEfiles novas.rc verdiLog .vcs_lib_lock
