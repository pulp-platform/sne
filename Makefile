# ----------------------------------------------------------------------
# Copyright (C) 2021-2022, ETH Zurich and University of Bologna.
#
# Author: Alfio Di Mauro <adimauro@student.ethz.ch>
# Author: Arpan Suravi Prasad <prasadar@student.ethz.ch>
#
# ----------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the License); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL=bash
BENDER_SIM_BUILD_DIR = sim

VOPT           ?= vopt
VSIM           ?= vsim
VLIB           ?= vlib
VMAP           ?= vmap
VLOG_ARGS      ?= -suppress vlog-2583 -svinputport=net +define+NGGROUPS=$(NGGROUPS) +define+SLICES=$(SLICES) +define+NEURONS=$(NEURONS) +define+LAYER=$(LAYER) 

checkout: bender
	@./bender update

bender:
ifeq (,$(wildcard ./bender))
	curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init | bash -s -- 0.22.0
	touch bender
endif

.PHONY: bender-rm
bender-rm:
	rm -f bender

scripts: scripts-vsim

scripts-fpga: | Bender.lock
	mkdir -p fpga/pulpissimo/tcl/generated
	./bender script vivado -t fpga -t xilinx > $(BENDER_FPGA_SCRIPTS_DIR)/compile.tcl

scripts-vsim: | Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl

$(BENDER_SIM_BUILD_DIR)/compile.tcl: Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl

#build the RTL platform
build: $(BENDER_SIM_BUILD_DIR)/compile.tcl
	@test -f Bender.lock || { echo "ERROR: Bender.lock file does not exist. Did you run make checkout in bender mode?"; exit 1; }
	@test -f $(BENDER_SIM_BUILD_DIR)/compile.tcl || { echo "ERROR: sim/compile.tcl file does not exist. Did you run make scripts in bender mode?"; exit 1; }
	$(MAKE) -C sim BENDER=bender build

opt:
	$(MAKE) -C sim BENDER=$(BENDER) opt

## Remove the RTL model files
clean:
	rm -rf $(VSIM_PATH)
	$(MAKE) -C sim BENDER=$(BENDER) clean

all: checkout scripts
	cd sim && $(MAKE) BENDER=bender all 