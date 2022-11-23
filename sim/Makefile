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

.PHONY: build lib clean sim simc

TB = $(TESTBENCH)
mkfile_path := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

VOPT				?= vopt
VSIM				?= vsim
VLIB				?= vlib
VMAP				?= vmap
VSIM_FLAGS           = ""
SIMDIR               = /sim

all: genstim simc checkres

sim:
	$(VSIM) -64 vopt_tb \
		-suppress vsim-3009 -suppress vsim-8683 -suppress vsim-13288\
		+UVM_NO_RELNOTES -stats -t ps \
		$(VSIM_FLAGS)  \
		-do "run -all; quit"

simc:
	$(VSIM) -64 vopt_tb \
		-suppress vsim-3009 -suppress vsim-8683 -suppress vsim-13288\
		+UVM_NO_RELNOTES -stats -t ps \
		$(VSIM_FLAGS)  \
		-do "run -all; quit"

opt:
	$(VOPT) +acc=npr -o vopt_tb $(TB) -work work

build:
	$(VSIM) -c -do 'source compile.tcl; quit'

lib:
	@$(VLIB) work
	$(VMAP) work $(mkfile_path)/work

clean:
	@mkdir -p work
	rm -r work 
	@touch modelsim.ini
	rm modelsim.ini

genstim:
ifeq ($(LAYER),2)
	echo "standalone test not supported in this repository"
else
	mkdir -p ../.tmp
	cd ../vsne_conv/ && python sne_test.py -simdir=/sim -rndmseed=83545 -kernels=$(KERNELS) -layer=$(LAYER)
endif	

checkres:
ifeq ($(LAYER),2)
	echo "standalone test not supported in this repository"
else
	cd ../utils && python check_results_alif.py -slices=8 -simdir="${SIMDIR}" -layer="${LAYER}" -kernels="${KERNELS}" -steps=700
endif