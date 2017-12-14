ABS_BENCHMARK_PATH=$(shell pwd -P)
ABS_ROOT_PATH=$(shell cd $(ROOT_DIR) && pwd -P)
ABS_BENCHMARKS_ROOT=$(ABS_ROOT_PATH)/benchmarks/
BENCHMARK=$(subst $(ABS_BENCHMARKS_ROOT),,$(ABS_BENCHMARK_PATH))

BUILD_ROOT=$(ROOT_DIR)/build
BENCHMARK_ROOT=$(BUILD_ROOT)/$(BENCHMARK)
RTL_ROOT=$(CGRA_ROOT)/platforms/ARM_M0/RTL
VBIN_ROOT=$(BENCHMARK_ROOT)/VBIN
SIM_ROOT=$(BENCHMARK_ROOT)/simulation
ASIC_ROOT=$(BENCHMARK_ROOT)/ASIC
BIN_ROOT=$(BENCHMARK_ROOT)/binary
DATA_FILE=$(VBIN_ROOT)/data.vbin
BIN_FILE=$(BIN_ROOT)/ram.bin

ARM_LIBS_DIR=$(CGRA_ROOT)/platforms/ARM_M0/libs
ARM_LD_SCRIPT=$(CGRA_ROOT)/platforms/ARM_M0/linkerscript/linkerscript.ld
ARM_SYN_SCRIPT=$(CGRA_ROOT)/platforms/ARM_M0/ASIC/tsmc40_arm.json
ARM_SYN_SCRIPT_TSMC=$(CGRA_ROOT)/platforms/ARM_M0/ASIC/tsmc40_arm_tsmc.json

SYNGEN=$(ASIC_TOOLS_ROOT)/python/ScriptGenerator.py

COMPARE_FILES=$(wildcard ./compare/*)
COMPARE_DEPEND=$(COMPARE_FILES:./compare/%=$(SIM_ROOT)/%)
IMGOUT=ImageConvertOut.py

CC=arm-none-eabi-gcc

.PHONY : clean sim run compare all performance report image input_image

all: $(BIN_FILE) $(DATA_FILE)	

$(SIM_ROOT)/work/*: $(BIN_FILE) $(DATA_FILE)
	-@mkdir -p $(SIM_ROOT)
	-@rm -rf $(SIM_ROOT)/work $(SIM_ROOT)/*.v $(SIM_ROOT)/*.vh $(SIM_ROOT)/*.vhd $(SIM_ROOT)/*.bin $(SIM_ROOT)/*.vbin
	-@find $(RTL_ROOT) -mindepth 1 -type f -exec cp -t $(SIM_ROOT) -i '{}' +
	cd $(SIM_ROOT) && vlib ./work
	cd $(SIM_ROOT) && vlog -lint -nologo -vlog01compat *.v -work ./work
	cp $(BIN_FILE) $(SIM_ROOT)/ram.bin
	cp $(DATA_FILE) $(SIM_ROOT)/data.vbin	

sim: $(SIM_ROOT)/work/*
	cd $(SIM_ROOT) && vsim -novopt +notimingchecks cortexm0ds_tb -do "do wave.do; run -all" 	

run $(SIM_ROOT)/GM_out.txt $(COMPARE_DEPEND):: $(SIM_ROOT)/work/*	
	cd $(SIM_ROOT) && vsim +notimingchecks -c cortexm0ds_tb -do "run -all" 	

compare: $(COMPARE_DEPEND)
	@for compare_file in $(COMPARE_FILES:./compare/%=%); do\
		diff -qs ./compare/$$compare_file $(SIM_ROOT)/$$compare_file; \
	done

image: $(SIM_ROOT)/GM_out.txt
	-@mkdir -p $(BENCHMARK_ROOT)/report
	$(IMGOUT) $(IMG_OUT_OPTS) -g $(SIM_ROOT)/GM_out.txt -o $(BENCHMARK_ROOT)/report/output_image.pgm

clean:
	-@rm -rf transcript
	-@rm -rf $(BENCHMARK_ROOT)
	
$(DATA_FILE) : ./data.vbin
	-@mkdir -p $(VBIN_ROOT)
	cp ./data.vbin $(DATA_FILE)

$(BIN_FILE) : main.c	
	-@mkdir -p $(BIN_ROOT)
	$(CC) -O3 -o $(BIN_ROOT)/main.o -c -std=gnu99 -Wall -O3 -mcpu=cortex-m0 -mthumb -mtune=cortex-m0.small-multiply main.c
	$(CC) -O3 -o $(BIN_ROOT)/syscalls.o -c -std=gnu99 -Wall -O3 -mcpu=cortex-m0 -mthumb -mtune=cortex-m0.small-multiply -static -fpic -Wno-unused-function $(ARM_LIBS_DIR)/syscalls.c
	arm-none-eabi-ar -cvrs $(BIN_ROOT)/libarm_m0_syscalls.a $(BIN_ROOT)/syscalls.o
	arm-none-eabi-ranlib $(BIN_ROOT)/libarm_m0_syscalls.a
	arm-none-eabi-g++ -o $(BIN_ROOT)/ram.elf -T $(ARM_LD_SCRIPT) -mcpu=cortex-m0 -mthumb $(BIN_ROOT)/main.o -L./ $(BIN_ROOT)/libarm_m0_syscalls.a
	arm-none-eabi-objcopy -O binary $(BIN_ROOT)/ram.elf $(BIN_ROOT)/ram.bin

asic_synth: $(BIN_FILE) $(DATA_FILE)
	@echo "Synthesis: --------------------------------------"
	-@mkdir -p $(ASIC_ROOT)/source_code
	-@rm -rf $(ASIC_ROOT)/source_code/*.v $(ASIC_ROOT)/source_code/*.vh $(ASIC_ROOT)/source_code/*.vhd $(ASIC_ROOT)/source_code/*.bin $(ASIC_ROOT)/source_code/*.vbin
	-@find $(RTL_ROOT) -mindepth 1 -type f -exec cp -t $(ASIC_ROOT)/source_code -i '{}' +
	$(SYNGEN) -O $(ASIC_ROOT) $(ARM_SYN_SCRIPT) -T $(ASIC_TOOLS_ROOT)/templates
	cp $(BIN_FILE) $(ASIC_ROOT)/source_code/ram.bin
	cp $(DATA_FILE) $(ASIC_ROOT)/source_code/data.vbin	
	cd $(ASIC_ROOT)/synthesis && make synth
	cd $(ASIC_ROOT)/simulation && make sim_syn
	cd $(ASIC_ROOT)/synthesis && make power

asic_synth_tsmc: $(BIN_FILE) $(DATA_FILE)
	@echo "Synthesis: --------------------------------------"
	-@mkdir -p $(ASIC_ROOT)/source_code
	-@rm -rf $(ASIC_ROOT)/source_code/*.v $(ASIC_ROOT)/source_code/*.vh $(ASIC_ROOT)/source_code/*.vhd $(ASIC_ROOT)/source_code/*.bin $(ASIC_ROOT)/source_code/*.vbin
	-@find $(RTL_ROOT) -mindepth 1 -type f -exec cp -t $(ASIC_ROOT)/source_code -i '{}' +
	$(SYNGEN) -O $(ASIC_ROOT) $(ARM_SYN_SCRIPT_TSMC) -T $(ASIC_TOOLS_ROOT)/templates
	cp $(BIN_FILE) $(ASIC_ROOT)/source_code/ram.bin
	cp $(DATA_FILE) $(ASIC_ROOT)/source_code/data.vbin	
	cd $(ASIC_ROOT)/synthesis && make synth
	cd $(ASIC_ROOT)/simulation && make sim_syn
	cd $(ASIC_ROOT)/synthesis && make power	

asic_pr: $(ASIC_ROOT)/synthesis/rpt/CORTEXM0DS_tcf.power
	@echo "Place and Route: ---------------------------------"
	cd $(ASIC_ROOT)/p+r && make PR
	cd $(ASIC_ROOT)/simulation && make sim_pr
	cd $(ASIC_ROOT)/synthesis && make power_pr

asic_pr_tsmc: $(ASIC_ROOT)/synthesis/rpt/CORTEXM0DS_tcf.power
	@echo "Place and Route: ---------------------------------"
	cd $(ASIC_ROOT)/p+r && make PR
	cd $(ASIC_ROOT)/simulation && make sim_pr
	cd $(ASIC_ROOT)/synthesis && make power_pr

