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

class LIF(object):
	"""
	Simplified leaky integrate and fire model, the membrane potential dacays linearly
	"""
	def __init__(self,vth=16,vmem=0,vleak=0,vreset=0,vrest=0,neuron_ID=0):
		super(LIF, self).__init__()
		self.vth = np.clip(int(vth),0,255)
		self.vmem = np.clip(int(vmem),0,255)
		self.vleak = np.clip(int(vleak),0,255)
		self.vreset = np.clip(int(vreset),0,255)
		self.vrest  = np.clip(int(vrest),0,255)
		self.neuron_ID = neuron_ID

		self.time = 0
		self.tlast_spike = 0
		self.tlast_update = 0
		self.__vmem =  np.empty(shape=0)
		self.__avth =  np.empty(shape=0)
		self.__so   =  np.empty(shape=0)
		self.__si   =  np.empty(shape=0)

	def reset(self):
		self.vth = 0
		self.vmem = 0
		self.vleak = 0

	def get_traces(self):
		return self.__vmem, self.__avth

	def get_spikes(self):
		return self.__so

	def trace(self):
		self.__vmem = np.append(self.__vmem,self.vmem)
		self.__avth = np.append(self.__avth,self.vth)

	def timestep(self,timestep):
		self.time = self.time + timestep

	def voltagestep(self,spike,weight):
		if spike:
			if self.vmem > self.vrest:
				self.vmem = np.clip(np.clip(self.vmem + np.clip(weight,0,15)*2,0,255) - self.vleak,0,255)
			else:
				self.vmem = np.clip(np.clip(self.vmem + np.clip(weight,0,15)*2,0,255) + self.vleak,0,255)

	def spikestep(self):

		if self.vmem > self.vth:
			self.vmem = self.vreset
			self.__so = np.append(self.__so,1)
			return (self.neuron_ID)
		else:
			self.__so = np.append(self.__so,0)
			return 0

class ALIF(object):
	"""
	Adaptive LIF model

	This model feature an exponential decay of the membrane voltage.
	Each spike causes an additional contribution to be added to the threshold voltage, which decay exponentially to the original value 

	"""
	def __init__(self,vth=64,vmem=0,vleak=0,vreset=0,vrest=0,neuron_ID=0):
		super(ALIF, self).__init__()
		self.vth = np.clip(int(vth),-128,127)
		self.avth = 0
		self.vmem = np.clip(int(vmem),-128,127)
		self.vleak = np.clip(int(vleak),-128,127)
		self.vreset = np.clip(int(vreset),-128,127)
		self.vrest  = np.clip(int(vrest),-128,127)
		self.neuron_ID = neuron_ID
		self.LUT = np.logspace(7.9,7.04,base=2,num=32,dtype=int)
		self.avth_scale = 1
		self.vmem_scale = 16
		self.tref = 2
		self.aoi  = 0


		self.time = 0
		self.tlast_spike = 0
		self.tlast_update = 0
		self.__vmem = np.empty(shape=0)
		self.__avth = np.empty(shape=0)
		self.__so   = np.empty(shape=0)
		self.__si   = np.empty(shape=0)

	def reset(self):
		self.vth = 0
		self.vmem = 0
		self.vleak = 0

	def get_traces(self):
		return self.__vmem, self.__avth

	def get_spikes(self):
		return self.__so

	def LUT_func(self,t,scale):
		"""
		Approximated exponential behaviour implemented with power of 2

		"""
		ts = int(t*scale)
		tr = int(np.floor(ts) % 32)
		lut_idx = tr
		
		r = np.clip((int(np.floor(ts)) >> 5),0,31)
		return int(self.LUT[int(lut_idx)]) >> int(r)

	def trace(self):
		self.__vmem = np.append(self.__vmem,self.vmem)
		self.__avth = np.append(self.__avth,self.avth + self.vth)

	def timestep(self,timestep):
		self.time = self.time + timestep

	def voltagestep(self,spike,weight,debug, aoi,layer):
		if(layer==1):
			self.aoi = aoi
		else:
			self.aoi = 1
		steps = self.time - self.tlast_update

		if spike and aoi:
			debug.write(f'BEFORE------IF--->vmem={self.vmem}, avth={self.avth}, time={self.time}, tlast_update={self.tlast_update}, LUT_vmem = {self.LUT_func(steps,self.vmem_scale)}, LUT_avth = {self.LUT_func(steps,self.avth_scale)}, Weight={weight}\n')
			self.vmem = np.clip(int((int(int(self.vmem)*int(self.LUT_func(steps,self.vmem_scale)))/256)) + int(np.clip(weight,-8,7)*4),-128,127)
			self.avth =  np.clip(int(((int(self.avth)*int(self.LUT_func(steps,self.avth_scale)))/256)),-128,127)
			debug.write(f'AFTER------IF--->vmem={self.vmem}, avth={self.avth}, time={self.time}, tlast_update={self.tlast_update}, LUT_vmem = {self.LUT_func(steps,self.vmem_scale)}, LUT_avth = {self.LUT_func(steps,self.avth_scale)}\n')
		else:
			if((aoi==0) and (layer==1)):
				return self.vmem
			debug.write(f'BEFORE-----ELSE--->vmem={self.vmem}, avth={self.avth}, time={self.time}, tlast_update={self.tlast_update}\n')
			self.vmem = np.clip(int(((int(self.vmem)*int(self.LUT_func(steps,self.vmem_scale)))/256)),-128,127) 
			self.avth = np.clip(int(((int(self.avth)*int(self.LUT_func(steps,self.avth_scale)))/256)),-128,127)
			debug.write(f'AFTER------ELSE--->vmem={self.vmem}, avth={self.avth}, time={self.time}, tlast_update={self.tlast_update}\n')
		self.tlast_update = self.time

		return self.vmem

	def spikestep(self,ng,n,op_file,debug,group_enable):

		if ((self.time - self.tlast_spike) >= self.tref) and group_enable and self.aoi:
			if self.vmem > (self.avth + self.vth):
				self.vmem = self.vmem - (self.vth)
				self.avth = np.clip((self.avth + 4),-128,127)
				self.tlast_spike = self.time
				self.__so = np.append(self.__so,1)
				gx = int(ng%4)
				gy = int(np.floor(ng//4))
				x = int(gx*6 + int(np.floor(n%8)))
				y = int(gy*6 + int(np.floor(n//8)))
				op_file.write("%01x%03x%02x%02x\n" % (2,self.time,y,x))
				debug.write(f'************Spike Generated ({y,x})****************\n')
				return (self.neuron_ID)

		self.__so = np.append(self.__so,0)
		return 0