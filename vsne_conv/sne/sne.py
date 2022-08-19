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

import numpy as np; 
import sne.neurons as neurons
from time import time
import multiprocessing
from itertools import repeat

np.random.seed(0)

def euclidean_division(x, y):
	quotient = int(np.asarray(x) // y)
	remainder = int(np.asarray(x) % y)
	#print(f"{quotient} remainder {remainder}")
	return remainder, quotient

def extract_times(NEURONS,NEURON_GROUPS,spikes):
	spike_times = [[[] for _ in range(0,NEURONS)] for _ in range(0,NEURON_GROUPS)]
	for g in range(0,NEURON_GROUPS):
		for n in range(0,NEURONS):
			spike_times[g][n] = np.nonzero(spikes[g][n])[0]
	return spike_times

class neuron_group(object):
	"""
	cluster of 64 neurons
	weights = 3x3 array

	"""
	def __init__(self,weights,group_ID,neuron_n,crops,overlaps,silence,steps):
		super().__init__()
		self.neuron_n = neuron_n
		self.group_ID = group_ID
		self.neurons = []
		self.NIDs = []
		self.neuron_n_2p = np.power(self.neuron_n,2)
		self.indexes = range(0,self.neuron_n_2p)
		self.group_enable = 0
		self.crop_x0 = crops[0]
		self.crop_xc = crops[1]
		self.crop_y0 = crops[2]
		self.crop_yc = crops[3]

		self.xo = overlaps[0]
		self.yo = overlaps[1]

		self.silencex = silence[0]
		self.silencey = silence[1]

		self.weights = weights

		self.__vmem = np.empty(shape=(np.power(self.neuron_n,2),steps))
		self.__avth = np.empty(shape=(np.power(self.neuron_n,2),steps))
		self.__so   = np.empty(shape=(np.power(self.neuron_n,2),steps))

		# instantiates neurons
		for n in range(0,np.power(self.neuron_n,2)):
			self.neurons.append(neurons.ALIF(neuron_ID=n))
			self.NIDs.append(n)

	def get_traces(self):
		for n in range(0,np.power(self.neuron_n,2)):
			self.__vmem[n], self.__avth[n] = self.neurons[n].get_traces()
		return self.__vmem, self.__avth

	def get_spikes(self):
		for n in range(0,np.power(self.neuron_n,2)):
			self.__so[n] = self.neurons[n].get_spikes()
		return self.__so

	def floating_kernel(self,yi,xi,yr,xr,yo,xo,channel,debug):
		w=0
		aoi = 0
		xk = int((8 + (xi - xr + 1 + xo)) % 8)
		yk = int((8 + (yi - yr + 1 + yo)) % 8)

		if ((xk >= 0) and (yk >= 0)) and ((xk < 3) and (yk < 3)):
			w = self.weights[channel,yk,xk]
			aoi = 1
			debug.write(f'NEURON=({yr,xr}),({yk,xk})\n')

		# check wether we are at the border, in case silence the neuron
		if (xr in self.silencex) or (yr in self.silencey):
			return 0, aoi
		else:
			return w, aoi

	def filter(self,idx,idy):
		if (idx >= self.crop_x0) and (idy >= self.crop_y0) and (idx < self.crop_xc) and (idy < self.crop_yc):
			return True
		else:
			return False

	def timestep(self,timestep):
		## update the simulation time inside neurons
		[self.neurons[n].timestep(timestep) for n in self.indexes]

	def trace(self):
		## update the simulation time inside neurons
		[self.neurons[n].trace() for n in self.indexes]
	
	def _voltage_step(self,n,spike,idx,idy,group_enable,debug,layer,channel):
		#span linearly the neurons but pretend they are 2D
		xr , yr = euclidean_division(n,self.neuron_n)
		xi = int(idx % self.neuron_n)
		yi = int(idy % self.neuron_n)
		w,aoi = self.floating_kernel(yi,xi,yr,xr,self.yo,self.xo,channel,debug)
		## update the membrane potential	
		if(group_enable):
			self.neurons[n].voltagestep(spike,w,debug,aoi,layer)
		else : 
			self.neurons[n].voltagestep(spike,0)

	def voltagestep(self,spike,idx,idy,debug,layer,channel):
		#if we are in the region of interest
		if self.filter(idx,idy):
			#update all group neurons
			self.group_enable = 1

			for n in self.indexes:
				self._voltage_step(n,spike,idx,idy,1,debug,layer,channel)
		else:
			self.group_enable = 0
			#update all group neurons	
			return

	def spikestep(self,ng,op_file,debug):
		[self.neurons[n].spikestep(ng,n,op_file,debug,self.group_enable) for n in self.indexes]

	def get_NIDs(self):
		return self.NIDs

	def print_NIDs(self):
		for n in range(0,self.neuron_n):
			print("NID_" + str(self.NIDs[n]))

class sne(object):
	"""cluster of 16 neuron groups"""
	def __init__(self,weights,group_n,neuron_n,crops,overlaps,silence,steps):
		super().__init__()
		start = time()
		self.group_n = group_n
		self.neuron_n = neuron_n
		self.group_n_2p = np.power(self.group_n,2)
		self.indexes = range(0,self.group_n_2p)
		self.groups = []
		self.GIDs = []

		self.crops = crops
		self.overlaps = overlaps
		self.silence = silence

		self.__vmem = np.empty(shape=(np.power(self.group_n,2),np.power(self.neuron_n,2),steps))
		self.__avth = np.empty(shape=(np.power(self.group_n,2),np.power(self.neuron_n,2),steps))
		self.__so   = np.empty(shape=(np.power(self.group_n,2),np.power(self.neuron_n,2),steps))
		preinit = time()
		for g in range(0,np.power(self.group_n,2)):
			self.groups.append(neuron_group(weights=weights[g],group_ID=g,neuron_n=self.neuron_n,crops=self.crops[g],overlaps=self.overlaps[g],silence=self.silence,steps=steps))
			self.GIDs.append(g)
		postinit = time()

	def voltagestep(self,spike,idx,idy,debug,layer,channel):
		for n in range(0,np.power(self.group_n,2)):
			debug.write(f'%%%%%%%%%%%%%%%GID={n}%%%%%%%%%%%%%%%%%%%%\n')
			self.groups[n].voltagestep(spike,idx,idy,debug,layer,channel)

	def timestep(self,timestep):
		[self.groups[n].timestep(timestep) for n in self.indexes]

	def spikestep(self,op_file,debug):
		[self.groups[n].spikestep(n,op_file,debug) for n in self.indexes]

	def trace(self):
		## update the simulation time inside neurons
		[self.groups[n].trace() for n in self.indexes]

	def get_traces(self):
		for n in range(0,np.power(self.group_n,2)):
			self.__vmem[n], self.__avth[n] = (self.groups[n].get_traces()) 
		return self.__vmem, self.__avth

	def get_spikes(self):
		for n in range(0,np.power(self.group_n,2)):
			self.__so[n] = self.groups[n].get_spikes()
		return self.__so

	def get_GIDs(self):
		return self.GIDs

	def print_GIDs(self):
		for g in range(0,self.group_n):
			print("GID_" + str(self.GIDs[g]))
		





