ABS_BENCHMARK_PATH=$(shell pwd -P)
ABS_ROOT_PATH=$(shell cd $(ROOT_DIR) && pwd -P)
ABS_BENCHMARKS_ROOT=$(ABS_ROOT_PATH)/benchmarks/
BENCHMARK=$(subst $(ABS_BENCHMARKS_ROOT),,$(ABS_BENCHMARK_PATH))

BUILD_ROOT=$(ROOT_DIR)/build
BENCHMARK_ROOT=$(BUILD_ROOT)/$(BENCHMARK)
PLATFORM_SOURCE=$(ROOT_DIR)/platforms/$(PLATFORM)/architecture.xml
RTL_ROOT=$(BENCHMARK_ROOT)/RTL
CONFIG_ROOT=$(BENCHMARK_ROOT)/config
VBIN_ROOT=$(BENCHMARK_ROOT)/VBIN
SIM_ROOT=$(BENCHMARK_ROOT)/simulation
ASIC_ROOT=$(BENCHMARK_ROOT)/ASIC
BIN_ROOT=$(BENCHMARK_ROOT)/binary
DATA_FILE=$(VBIN_ROOT)/data.vbin
HBIN_FILE=$(CONFIG_ROOT)/configuration.hbin
BIN_FILE=$(BIN_ROOT)/out.bin

PLATFORM_COMMON=$(CGRA_ROOT)/platforms/Common

ASM=cgra-as.py
HW=cgra-hw.py
BC=BitConfig.py
BB=BinaryBuilder.py
MODEL=CGRAModel.py
IMGOUT=ImageConvertOut.py
IMGIN=ImageConvertIn.py
JT=JSONTemplater.py
WRAPGEN=$(ASIC_TOOLS_ROOT)/python/CreateWrapper.py
SYNGEN=$(ASIC_TOOLS_ROOT)/python/ScriptGenerator.py

PASM_FILES=$(wildcard *.pasm)
COMPARE_FILES=$(wildcard ./compare/*)
COMPARE_DEPEND=$(COMPARE_FILES:./compare/%=$(SIM_ROOT)/%)	
PR_FILE=$(wildcard place_and_route.xml)

ifeq ($(PR_FILE),)
HW_OPTIONS="-s0"
BC_OPTIONS=""
else		
HW_OPTIONS="-s1"
BC_OPTIONS="-pplace_and_route.xml"
endif

ifeq ($(MEMTYPE),)
MEMTYPE=1
endif

.PHONY : clean sim run compare all performance report image input_image

all: $(BIN_FILE) $(DATA_FILE)	

$(SIM_ROOT)/work/*: $(BIN_FILE) $(DATA_FILE)
	-@mkdir -p $(SIM_ROOT)
	-@rm -rf $(SIM_ROOT)/work $(SIM_ROOT)/*.v $(SIM_ROOT)/*.vh $(SIM_ROOT)/*.vhd $(SIM_ROOT)/*.bin $(SIM_ROOT)/*.vbin
	-@find $(RTL_ROOT) -mindepth 1 -type f -exec cp -t $(SIM_ROOT) -i '{}' +
	cd $(SIM_ROOT) && vlib ./work
	cd $(SIM_ROOT) && vlog -lint -nologo -vlog01compat *.v -work ./work
	cd $(SIM_ROOT) && vcom  ./*.vhd -work ./work	
	cp $(BIN_FILE) $(SIM_ROOT)/out.bin
	cp $(DATA_FILE) $(SIM_ROOT)/data.vbin	

sim: $(SIM_ROOT)/work/*
	cd $(SIM_ROOT) && vsim +notimingchecks -novopt TB_CGRA_Top -do "do wave.do; run -all" 	

run $(SIM_ROOT)/performance_info.txt $(SIM_ROOT)/*out_*.txt $(SIM_ROOT)/GM_out.txt $(COMPARE_DEPEND):: $(SIM_ROOT)/work/*	
	cd $(SIM_ROOT) && vsim +notimingchecks -c TB_CGRA_Top -do "run -all" 	

compare: $(COMPARE_DEPEND)
	@for compare_file in $(COMPARE_FILES:./compare/%=%); do\
		diff -qs ./compare/$$compare_file $(SIM_ROOT)/$$compare_file; \
	done

performance: $(SIM_ROOT)/performance_info.txt
	@cat $(SIM_ROOT)/performance_info.txt

report: $(SIM_ROOT)/*out_*.txt $(CONFIG_ROOT)/instance_info.xml
	-@mkdir -p $(BENCHMARK_ROOT)/report
	$(MODEL) -m $(PLATFORM_COMMON)/model/model.xml -S $(SIM_ROOT) -i $(CONFIG_ROOT)/instance_info.xml -r $(BENCHMARK_ROOT)/report/report.txt -p $(ABS_BENCHMARK_PATH)/$(PASM_FILES) -v

image: $(SIM_ROOT)/GM_out.txt
	$(IMGOUT) $(IMG_OUT_OPTS) -g $(SIM_ROOT)/GM_out.txt -o $(BENCHMARK_ROOT)/report/output_image.pgm

input_image ./data.vbin: 
	$(IMGIN) -i $(INPUT_IMAGE) -o "data.vbin"

clean:
	-@rm -rf transcript
	-@rm -rf $(BENCHMARK_ROOT)
	
$(VBIN_ROOT)/*CGRA*.vbin : $(PLATFORM_SOURCE) ${PASM_FILES} $(PLATFORM_COMMON)/*.xml
	-@mkdir -p $(CONFIG_ROOT)
	-@mkdir -p $(VBIN_ROOT)
	$(ASM) ${PASM_FILES} -c $(PLATFORM_SOURCE) -d CGRA -o $(VBIN_ROOT)	

$(DATA_FILE) : ./data.vbin
	cp ./data.vbin $(DATA_FILE)

$(CONFIG_ROOT)/instance_info.xml: $(PLATFORM_SOURCE) $(PLATFORM_COMMON)/RTL $(PLATFORM_COMMON)/RTL $(PLATFORM_COMMON)/*.xml
	-@mkdir -p $(CONFIG_ROOT)
	-@mkdir -p $(RTL_ROOT)
	-@mkdir -p $(BENCHMARK_ROOT)/report
	$(HW) $(PLATFORM_SOURCE) $(HW_OPTIONS) -d CGRA -g $(BENCHMARK_ROOT)/report/architecture.dot -T $(PLATFORM_COMMON)/templates -O $(RTL_ROOT) -c $(CONFIG_ROOT)/instance_info.xml -M $(MEMTYPE)
	-@yes | cp -R $(PLATFORM_COMMON)/RTL/* $(RTL_ROOT)	

$(HBIN_FILE) : $(CONFIG_ROOT)/instance_info.xml	
	$(BC) $(BC_OPTIONS) -i $(CONFIG_ROOT)/instance_info.xml -b $(CONFIG_ROOT)/configuration.hbin -m $(CONFIG_ROOT)/mapping.xml

$(BIN_FILE) : $(HBIN_FILE) $(VBIN_ROOT)/*CGRA*.vbin
	-@mkdir -p $(CONFIG_ROOT)
	-@mkdir -p $(BIN_ROOT)
	$(BB) -d CGRA -V $(VBIN_ROOT) -m $(CONFIG_ROOT)/mapping.xml -b $(HBIN_FILE) -o $(BIN_FILE)

$(CONFIG_ROOT)/cgra.json: $(CONFIG_ROOT)/instance_info.xml
	$(JT) -t $(PLATFORM_COMMON)/ASIC/tsmc40_cgra.json.tpl -o $(CONFIG_ROOT)/cgra.json -D $(RTL_ROOT)/Switchboxes

asic_synth: $(BIN_FILE) $(DATA_FILE) $(CONFIG_ROOT)/cgra.json
	@echo "Synthesis: --------------------------------------"
	-@mkdir -p $(ASIC_ROOT)/source_code
	-@rm -rf $(ASIC_ROOT)/source_code/*.v $(ASIC_ROOT)/source_code/*.vh $(ASIC_ROOT)/source_code/*.vhd $(ASIC_ROOT)/source_code/*.bin $(ASIC_ROOT)/source_code/*.vbin
	-@find $(RTL_ROOT) -mindepth 1 -type f -exec cp -t $(ASIC_ROOT)/source_code -i '{}' +
	$(WRAPGEN) -i $(ASIC_ROOT)/source_code/CGRA_compute_wrapper.v -o $(ASIC_ROOT)/source_code/CGRA_WRAPPER.v -m CGRA_Compute_Wrapper_WR -M CGRA_Compute_Wrapper -s ../synthesis/CGRA_Compute_Wrapper.sdf -p ../p+r/data_out/optRoute.sdf
	$(SYNGEN) -O $(ASIC_ROOT) $(CONFIG_ROOT)/cgra.json -T $(ASIC_TOOLS_ROOT)/templates
	cp $(BIN_FILE) $(ASIC_ROOT)/source_code/out.bin
	cp $(DATA_FILE) $(ASIC_ROOT)/source_code/data.vbin	
	cd $(ASIC_ROOT)/synthesis && make synth
	cd $(ASIC_ROOT)/simulation && make sim_syn
	cd $(ASIC_ROOT)/synthesis && make power

asic_pr: $(ASIC_ROOT)/synthesis/rpt/CGRA_Compute_Wrapper_tcf.power
	@echo "Place and Route: ---------------------------------"
	cd $(ASIC_ROOT)/p+r && make PR
	cd $(ASIC_ROOT)/simulation && make sim_pr
	cd $(ASIC_ROOT)/synthesis && make power_pr



$(CONFIG_ROOT)/cgra_tsmc.json: $(CONFIG_ROOT)/instance_info.xml
	$(JT) -t $(PLATFORM_COMMON)/ASIC/tsmc40_cgra_tsmcmem.json.tpl -o $(CONFIG_ROOT)/cgra_tsmc.json -D $(RTL_ROOT)/Switchboxes

asic_synth_tsmc: $(BIN_FILE) $(DATA_FILE) $(CONFIG_ROOT)/cgra_tsmc.json
	@echo "Synthesis: --------------------------------------"
	-@mkdir -p $(ASIC_ROOT)/source_code
	-@rm -rf $(ASIC_ROOT)/source_code/*.v $(ASIC_ROOT)/source_code/*.vh $(ASIC_ROOT)/source_code/*.vhd $(ASIC_ROOT)/source_code/*.bin $(ASIC_ROOT)/source_code/*.vbin
	-@find $(RTL_ROOT) -mindepth 1 -type f -exec cp -t $(ASIC_ROOT)/source_code -i '{}' +
	$(WRAPGEN) -i $(ASIC_ROOT)/source_code/CGRA_core.v -o $(ASIC_ROOT)/source_code/CGRA_WRAPPER.v -m CGRA_Core_WR -M CGRA_Core -s ../synthesis/CGRA_Core.sdf -p ../p+r/data_out/optRoute.sdf
	$(SYNGEN) -O $(ASIC_ROOT) $(CONFIG_ROOT)/cgra_tsmc.json -T $(ASIC_TOOLS_ROOT)/templates
	cp $(BIN_FILE) $(ASIC_ROOT)/source_code/out.bin
	cp $(DATA_FILE) $(ASIC_ROOT)/source_code/data.vbin	
	cd $(ASIC_ROOT)/synthesis && make synth
	cd $(ASIC_ROOT)/simulation && make sim_syn
	cd $(ASIC_ROOT)/synthesis && make power

asic_pr_tsmc: $(ASIC_ROOT)/synthesis/rpt/CGRA_Core_tcf.power
	@echo "Place and Route: ---------------------------------"
	cd $(ASIC_ROOT)/p+r && make PR
	cd $(ASIC_ROOT)/simulation && make sim_pr
	cd $(ASIC_ROOT)/synthesis && make power_pr