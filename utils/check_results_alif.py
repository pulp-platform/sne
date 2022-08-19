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

import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1 import ImageGrid
import shutil
import os
import argparse
import hashlib
import sys

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def printcolor(string,color):
    print(color + string + bcolors.ENDC)

parser = argparse.ArgumentParser(description='Generate scripts for synthesis and simulation.')
parser.add_argument('-slices', dest='slices', help='Number of slices in the current configuration')
parser.add_argument('-simdir', dest='simdir',default='/sim', help='simulation directory')
parser.add_argument('-plot', dest='plot',default=False,action="store_true", help='plot data')
parser.add_argument('-layer', dest='layer', help='only one slice')
parser.add_argument('-kernels', dest='kernels', help='only one slice')
parser.add_argument('-steps', dest='steps', help='only one slice')
args = parser.parse_args()
if(int(args.layer)==0):
    print('SIMULATING DEFAULT CONVOLUTIONAL LAYER WITH '+args.slices+' SLICES')
elif (int(args.layer)==1):
    print('SIMULATING OPTIMIZED CONVOLUTIONAL LAYER WITH '+args.slices+' SLICES')
else :
    print('SIMULATING FULLY CONNECTED LAYER WITH '+args.slices+' SLICES')
np.set_printoptions(threshold=np.inf)

directory_base = os.path.dirname(os.path.normpath(os.getcwd()))

sim_steps = int(args.steps)

def split(word): 
    return [char for char in word]  

def remove_adjacent(nums):
  i = 1
  while i < len(nums):    
    if nums[i] == nums[i-1]:
      nums.pop(i)
      i -= 1  
    i += 1
  return nums

spike_sne_plot = np.zeros((32, 32))
spike_sne_plot_time = np.zeros((32, 32, sim_steps))
model_data_plot_time = np.zeros((32, 32, sim_steps))

time_sne_o = []

filepath = directory_base + args.simdir + '/output.txt'
filepath_golden = directory_base + args.simdir + '/spike_out.txt'

CONV_LAYER = int(args.kernels)

with open(filepath) as fp:
   line = fp.readline()
   cnt = 1
   sim_time = 0
   while line:
        if (cnt > (150003)):
            string = split(line)
            if 'x' in line:
                break
            spike_sne_X = int(string[6] + string[7]            ,16)
            spike_sne_Y = int(string[4] + string[5]            ,16)
            time        = int(string[0] + string[1] + string[2],16)
            SID         = int(string[3]                        ,16)
            time_sne_o.append(time)
            if(string[0]=='7'):
                sim_time = int(string[4]+string[5]+string[6]+string[7],16);
            if(string[0]=='2'):
                spike_sne_plot_time[spike_sne_Y,spike_sne_X,sim_time] = spike_sne_plot_time[spike_sne_Y,spike_sne_X,sim_time] + 1;
                spike_sne_plot[spike_sne_Y,spike_sne_X] = spike_sne_plot[spike_sne_Y,spike_sne_X] + 1

        line = fp.readline()
        cnt += 1

time_sne_o = remove_adjacent(time_sne_o)
model_data_plot = np.zeros((32, 32))
with open(filepath_golden) as fp:
   line = fp.readline()
   cnt = 0
   sim_time = 0
   while line:
        if (1):
            string = split(line)
            if 'x' in line:
                break
            spike_sne_X = int(string[6] + string[7]            ,16)
            spike_sne_Y = int(string[4] + string[5]            ,16)
            time        = int(string[0] + string[1] + string[2],16)
            SID         = int(string[3]                        ,16)
            time_sne_o.append(time)
            if(string[0]=='7'):
                sim_time = int(string[4]+string[5]+string[6]+string[7],16);
            if(string[0]=='2'):
                model_data_plot_time[spike_sne_Y,spike_sne_X,sim_time] = model_data_plot_time[spike_sne_Y,spike_sne_X,sim_time] + 1;
                model_data_plot[spike_sne_Y,spike_sne_X] = model_data_plot[spike_sne_Y,spike_sne_X] + 1

        line = fp.readline()
        cnt += 1

directory_base = os.path.dirname(os.path.normpath(os.getcwd()))

errors = 0
time_errors = 0

for y in range(0,32):
    for x in range(0,32):
        
        if(int(args.layer)==2): #FC Layer
            model_data_norm = model_data_plot[x,y]*int(args.slices)
        else:
            model_data_norm = model_data_plot[x,y]*int(args.slices)
        if model_data_norm != spike_sne_plot[x,y]:
            errors = errors + 1

for y in range(0,32):
    for x in range(0,32):
        for t in range(0,sim_steps):
            if(int(args.layer)==2): #FC Layer
                model_data_norm = model_data_plot_time[x,y,t]*int(args.slices)
            else:
                model_data_norm = model_data_plot_time[x,y,t]*int(args.slices)
                
            if model_data_norm != spike_sne_plot_time[x,y,t]:
                time_errors = time_errors + 1


if (errors/(32*32*8)) < 0.01 :
    printcolor("[Info] FUNCTIONAL TEST PASSED!!",bcolors.OKGREEN)
else: 
    printcolor("[Info] FUNCTIONAL TEST FAILED!!",bcolors.FAIL)

if args.plot:

    fig, (ax1, ax2) = plt.subplots(figsize=(15, 5), ncols=2)
    out = ax1.imshow(model_data_plot, cmap='hot', interpolation='nearest')
    ax1.set_xticks(np.arange(0,32,1), minor=True);
    ax1.set_yticks(np.arange(0,32,1), minor=True);
    ax1.set_title('model output')

    # Major ticks
    ax1.set_xticks(np.arange(0, 32, 8));
    ax1.set_yticks(np.arange(0, 32, 8));
    # Labels for major ticks
    ax1.set_xticklabels(np.arange(0, 32, 8));
    ax1.set_yticklabels(np.arange(0, 32, 8));
    ax1.grid(color='silver', linestyle='-', linewidth=0.2, which='minor')
    ax1.grid(color='y', linestyle='-', linewidth=0.5, which='major')
    fig.colorbar(out, ax=ax1)
    plt.tight_layout()

    out = ax2.imshow(spike_sne_plot, cmap='hot', interpolation='nearest')
    ax2.set_xticks(np.arange(0,32,1), minor=True);
    ax2.set_yticks(np.arange(0,32,1), minor=True);
    ax2.set_title('SNE output')
    # Major ticks
    ax2.set_xticks(np.arange(0, 32, 8));
    ax2.set_yticks(np.arange(0, 32, 8));
    # Labels for major ticks
    ax2.set_xticklabels(np.arange(0, 32, 8));
    ax2.set_yticklabels(np.arange(0, 32, 8));
    ax2.grid(color='silver', linestyle='-', linewidth=0.2, which='minor')
    ax2.grid(color='y', linestyle='-', linewidth=0.5, which='major')
    fig.colorbar(out, ax=ax2)
    plt.tight_layout()
    plt.show()