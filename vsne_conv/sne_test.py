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

import matplotlib
import math
import shutil
import os
import numpy as np
import matplotlib.pyplot as plt
import hjson
from time import time

from sne.neurons import ALIF
from sne.neurons import LIF
from sne.sne import sne
from sne.sne import euclidean_division as neuron_addr
from sne.sne import extract_times as extract_times
import sys

import argparse
# import ray
directory_base = os.path.dirname(os.path.normpath(os.getcwd()))
parser = argparse.ArgumentParser(description='Generate scripts for synthesis and simulation.')
parser.add_argument('-simdir', dest='simdir',default='/sim', help='simulation directory')
parser.add_argument('-rndmseed', dest='rndmseed',default=37465, help='seed for random stimuli generation')
parser.add_argument('-layer', dest='layer', help='only one slice')
parser.add_argument('-kernels', dest='kernels', help='number of channels')
# ray.init(num_cpus=1, num_gpus=1)
args = parser.parse_args()
if __name__ ==  '__main__':

	np.random.seed(seed=int(args.rndmseed))
	print('Random seed='+str(int(args.rndmseed)))
	layer = int(args.layer)
	if(layer==2):
		sys.exit("NOT CONVOLUTIONAL LAYER")
	work_dir = directory_base + str("/.tmp")
	sim_folder = directory_base + args.simdir

	f = open('sne.hjson','r')
	dict_sne = hjson.load(f)

	NEURONS = int(dict_sne['configuration']['neurons']['number'])
	NEURON_GROUPS = int(dict_sne['configuration']['groups']['number'])
	STEPS = int(dict_sne['simulation']['steps'])

	weight_option = dict_sne['weights']['mode']
	weight_min = int(dict_sne['weights']['min_value'])
	weight_max = int(dict_sne['weights']['max_value'])

	l2_fname = '/l2_stim_sne.txt'
	op_fname = '/spike_out.txt'
	dbg_fname = '/debug_golden_model.txt' 
	exp_fname = '/expected_stimuli.txt'
	l2file    = open(work_dir + l2_fname,"w")
	op_file = open(work_dir + op_fname,"w")
	debug = open(work_dir + dbg_fname,"w")
	exp_file = open(work_dir + exp_fname,"w")

	t = np.linspace(0,STEPS,num=STEPS)
	
	CONV_LAYER = int(args.kernels)
	w3x3 = np.ones((NEURON_GROUPS,CONV_LAYER,3,3))*weight_min
	channels = int(CONV_LAYER*1.125)
	l2file.write("%02x%06x\n"%(1,CONV_LAYER+64))
	# exp_file.write("%02x%06x\n"%(1,channels))
	# print(channels)
	ctr=0
	rand_fc = 7
	val_4 = 0
	channels = int(CONV_LAYER*1.125)
	# print(channels)
	KERNEL_SIZE = 3
	# l2file.write("01000012\n")
	# l2file.write("%02x%06x\n"%(1,channels))
	buffer_s=np.zeros(CONV_LAYER>>2,dtype=int)
	for i in range(0,CONV_LAYER):
	    val = 0
	    for k_x in range(0,KERNEL_SIZE):
	        for k_y in range(0,KERNEL_SIZE):
	            rand = np.random.randint(2,8)
	            # rand = rand_fc
	            val = val*16+rand
	            for g in range(0,NEURON_GROUPS):
	                w3x3[g,i,KERNEL_SIZE-1-k_x,KERNEL_SIZE-1-k_y]=rand
	    val1 = val >> 4
	    val2 = val & 0xF
	    l2file.write("%08x\n"%val1)
	    val_4 = val_4*16+val2
	    if(i%4==3):
	        buffer_s[ctr]=(val_4)
	        ctr= ctr + 1
	        val_4=0
	# print(len(buffer_s))
	# print(buffer_s)

	for i in range(0,64):
		radix_0=w3x3[0,i,0,0]
		radix_1=w3x3[0,i+64,0,0]
		radix_2=w3x3[0,i+128,0,0]
		radix_3=w3x3[0,i+192,0,0]
		l2file.write("%04x%01x%01x%01x%01x\n"%(0,int(radix_3),int(radix_2),int(radix_1),int(radix_0)))

	crops = np.zeros((NEURON_GROUPS,4))
	overlaps = np.zeros((NEURON_GROUPS,2))
	silence = np.zeros((NEURON_GROUPS,2,2))
	# print(w3x3[0,0])
	OVERLAP_X = 2
	OVERLAP_Y = 2

	# calculate crops and overlaps for a square arrangement of groups/ input regions
	for g in range(0,NEURON_GROUPS):
	    g_x, g_y = neuron_addr(g,4)
	    x0 = g_x*(np.sqrt(NEURONS) - OVERLAP_X)
	    xc = g_x*(np.sqrt(NEURONS) - OVERLAP_X) + np.sqrt(NEURONS) 
	    y0 = g_y*(np.sqrt(NEURONS) - OVERLAP_Y)
	    yc = g_y*(np.sqrt(NEURONS) - OVERLAP_Y) + np.sqrt(NEURONS) 
	    crops[g] = [x0,xc,y0,yc]
	    overlaps[g] = [OVERLAP_X*g_x,OVERLAP_Y*g_y]
	    silence[g] = [[0,7],[0,7]]

    # print(crops)
	preinst = time()
	# instantiate the sne model
	_alif_sne = sne(weights=w3x3,group_n=int(np.sqrt(NEURON_GROUPS)),neuron_n=int(np.sqrt(NEURONS)),crops=crops,overlaps=overlaps,silence=silence,steps=STEPS)
	postinst = time()

	spike_i = np.zeros((NEURON_GROUPS,NEURONS,STEPS))
	spike_o = np.zeros((NEURON_GROUPS,NEURONS,STEPS))

	ng_sqrt = np.sqrt(NEURON_GROUPS)
	n_sqrt  = np.sqrt(NEURONS)
	_alif_sne.timestep(0)

	list1=[]
	list2=[]
	list3=[]
	list4=[]
	

	list1.append("%08x\n" % (2*(STEPS)+2+10000))
	list1.append("50000000\n")
	list2.append("50000000\n")
	list3.append("50000000\n")
	list4.append("50000000\n")
	stim = np.zeros(STEPS)
	kernel_sel = np.zeros(STEPS)
	list1.append("40000000\n")
	time_step = 0
	# with tqdm(total=STEPS, position=0, leave=True) as pbar:
	print("Generating stimuli, this operation might take some time..."),
	for idx in range(0,STEPS):
		rand_time = np.random.randint(0,5)
		_alif_sne.timestep(rand_time)

		time_step = time_step + rand_time
		list1.append("%01x%07x\n" % (5,time_step))
		list2.append("%01x%07x\n" % (5,time_step))
		list3.append("%01x%07x\n" % (5,time_step))
		list4.append("%01x%07x\n" % (5,time_step))
		exp_file.write("%01x%07x\n" % (5,time_step))
		
		for spikes in range (0,20):
			coord = np.random.randint(8,12)
			x = 2*(coord%5) + np.random.randint(3,6)
			y = 2*(coord%5) + np.random.randint(5,8)
			debug.write(f'-----------------------------------SPIKE=({y,x})-------------------------\n')
			for ng in range(0,NEURON_GROUPS):
				if(x>=crops[ng][0] and x<crops[ng][1] and y>=crops[ng][2] and y<crops[ng][3]):
					g=ng
					break
			nx = int(x-crops[ng][0])
			ny = int(y-crops[ng][2])
			n  = int(ny*n_sqrt + nx)

			presim = time()
			kernel_num = np.random.randint(0,CONV_LAYER)
			_alif_sne.voltagestep(1,x, y,debug,layer,kernel_num)

			if spikes<5:
				list1.append("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
				exp_file.write("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
			elif spikes<10:
				list2.append("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
				exp_file.write("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
			elif spikes<15:
				list3.append("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
				exp_file.write("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
			else:
				list4.append("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))
				exp_file.write("%01x%01x%02x%02x%02x\n" % (2,0,kernel_num,y,x))

			postsim = time()
			spike_i[g][n] = 1
			op_file.write("%01x%07x\n"%(7,time_step))
			_alif_sne.spikestep(op_file,debug)	
			# pbar.update()

	# print(postsim-presim)
	l2file.write("00000000\n")
	l2file.write("000014B4\n")
	l2file.write("00002454\n")
	l2file.write("000033F4\n")
	list1.append("90000000\n")
	list2.append("90000000\n")
	list3.append("90000000\n")
	list4.append("90000000\n")
	list1.append("90000000\n")
	list2.append("90000000\n")
	list3.append("90000000\n")
	list4.append("90000000\n")

	count= 0;
	OFFSET = 6;
	for i in range(0,OFFSET):
		count = count + 1
		l2file.write("00000000\n")
	for i in range(0,len(list1)):
		count = count + 1
		l2file.write(list1[i])

	for i in range(count,1000):
		l2file.write("00000000\n")
		count = count+1
	for i in range(0,len(list2)):
		count = count+1
		l2file.write(list2[i])

	for i in range(count,2000):
		count = count+1
		l2file.write("00000000\n")
	for i in range(0,len(list3)):
		count = count+1
		l2file.write(list3[i])

	for i in range(count,3000):
		l2file.write("00000000\n")
		count = count+1
	for i in range(0,len(list4)):
		l2file.write(list4[i])
		count = count+1

	l2file.close() 
	op_file.close()
	debug.close()
	exp_file.close()
	shutil.copy2(work_dir + l2_fname, sim_folder)
	shutil.copy2(work_dir + op_fname, sim_folder)
	# shutil.copy2(work_dir + dbg_fname, sim_folder)
	# shutil.copy2(work_dir + exp_fname, sim_folder)
	# vmem, avth = np.array(_alif_sne.get_traces())
	# spike_o    = np.array(_alif_sne.get_spikes())

	colors1 = ['C{}'.format(i) for i in range(NEURONS)]

	lineoffsets1 = np.linspace(0,NEURONS-1,NEURONS)
	linelengths1 = np.ones(NEURONS)*0.5

	