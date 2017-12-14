#!/usr/bin/env python

#/********************************************************/
#/*                      LICENSE:			 */
#/*------------------------------------------------------*/
#/* These files can be used for the Embedded Computer    */
#/* Architecture course (5SIA0) at Eindhoven University  */
#/* of technology. You are not allowed to distribute     */
#/* these files to others.                               */
#/* This header must be retained at all times		 */
#/********************************************************/

import os
import glob
from pprint import pprint
from swb_gen import swb_gen
from Config import Config
import svgwrite
from svgwrite import cm, mm

class network_gen():
	def drawNetwork(self, sizeX, sizeY, network, outDir):			
		swb_spacing = 400
		swb_size = 50
		fu_size = 150
		networkColor = svgwrite.rgb(0,0,0)
		inputColor = svgwrite.rgb(0,0,255)
		outputColor = svgwrite.rgb(255,0,0)

		dwg = svgwrite.Drawing(outDir + '/' + network + '.svg', debug=True)
		dwg.add(dwg.rect((0,0),('100%','100%'),None,None,fill=svgwrite.rgb(255,255,255))) #background fill

		for Y in range(0,sizeY+1):
			for X in range(0,sizeX+1):
				swb_name = 'X' + str(X) + '_Y' +str(Y)

				#switchbox square
				dwg.add(dwg.rect((X*swb_spacing,Y*swb_spacing),(swb_size,swb_size),None,None,fill=networkColor))

				#loop through all ports
				for port in self.switchboxes[swb_name][network]['ports']:
										
					if (port[0] == 'LEFT'):												
						numPorts = port[1];
						portSpacing = swb_size / numPorts;

						for swb in range(0,numPorts):							
							line = dwg.add(dwg.line((X*swb_spacing, Y*swb_spacing+(swb+0.5)*portSpacing), (X*swb_spacing-swb_spacing+swb_size, Y*swb_spacing+(swb+0.5)*portSpacing),stroke=networkColor, fill='none'))
					
					if (port[0] == 'TOP'):
						numPorts = port[1];
						portSpacing = swb_size / numPorts;

						for swb in range(0,numPorts):							
							line = dwg.add(dwg.line((X*swb_spacing+(swb+0.5)*portSpacing, Y*swb_spacing), (X*swb_spacing+(swb+0.5)*portSpacing, (Y-1)*swb_spacing+swb_size),stroke=networkColor, fill='none'))						
					
					if 'inputs' in self.switchboxes[swb_name][network]:
						if int(self.switchboxes[swb_name][network]['inputs']) != 0:
							line = dwg.add(dwg.line((X*swb_spacing+swb_size, Y*swb_spacing+swb_size), (X*swb_spacing+swb_spacing/3,Y*swb_spacing+swb_spacing/3),stroke=inputColor, fill='none', stroke_width=3))					

					if 'outputs' in self.switchboxes[swb_name][network]:
						if int(self.switchboxes[swb_name][network]['outputs']) != 0:
							line = dwg.add(dwg.line((X*swb_spacing+swb_size, Y*swb_spacing), (X*swb_spacing+swb_spacing/3,(Y-1)*swb_spacing+swb_spacing/3+fu_size),stroke=outputColor, fill='none',stroke_width=3))					

					if 'FU' in self.switchboxes[swb_name]:
						if self.switchboxes[swb_name]['FU']['type'] == "LSU":
							color = svgwrite.rgb(255,0,0)
						elif self.switchboxes[swb_name]['FU']['type'] == "RF":
							color = svgwrite.rgb(255,255,0)
						elif self.switchboxes[swb_name]['FU']['type'] == "ABU":
							color = svgwrite.rgb(255,0,255)								
						elif self.switchboxes[swb_name]['FU']['type'] == "IU":
							color = svgwrite.rgb(0,128,0)																
						elif self.switchboxes[swb_name]['FU']['type'] == "ID":
							color = svgwrite.rgb(0,255,0)																								
						elif self.switchboxes[swb_name]['FU']['type'] == "MUL":
							color = svgwrite.rgb(0,0,255)																															
						else:
							color = svgwrite.rgb(0,128,255)
						
						dwg.add(dwg.rect((X*swb_spacing+swb_spacing/3,Y*swb_spacing+swb_spacing/3),(fu_size,fu_size),None,None,fill=color))
						dwg.add(dwg.text(self.switchboxes[swb_name]['FU']['type'], insert=(X*swb_spacing+swb_spacing/3+20,Y*swb_spacing+swb_spacing/3+fu_size/2+15), fill='black', style = "font-size:30px; font-family:Arial"))
		dwg.save()

	#============================================================================================================
	def getNetwork(self, sizeX, sizeY, dataWidth, availablePorts, functionalUnits, network,options):		
		for Y in range(0,sizeY+1):
			for X in range(0,sizeX+1):
				swb_name = 'X' + str(X) + '_Y' +str(Y)

				#clear port list for this switchbox
				ports = []
				self.switchboxes[swb_name][network] = {}

				#loop through all ports
				for port in availablePorts:
					#detect if port should be on a certain side (due to geometry)
					if (X > 0 and port[0] == 'LEFT'):												
						ports.append((port[0],port[1]))
					elif (X < sizeX and port[0] == 'RIGHT'):
						ports.append((port[0],port[1]))
					if (Y > 0 and port[0] == 'TOP'):
						ports.append((port[0],port[1]))
					elif (Y < sizeY and port[0] == 'BOTTOM'):
						ports.append((port[0],port[1]))

					#loop through all functional units and check if there is one that has to be connected to the current switchbox
					for functionalUnit in functionalUnits:
						if int(functionalUnits[functionalUnit]['@Xloc']) == X and int(functionalUnits[functionalUnit]['@Yloc']) == Y:
							self.switchboxes[swb_name]['FU'] = {}
							self.switchboxes[swb_name]['FU']['name'] = functionalUnits[functionalUnit]['@name']
							self.switchboxes[swb_name]['FU']['type'] = functionalUnits[functionalUnit]['@type']

							if 'control' in functionalUnits[functionalUnit]:
								self.switchboxes[swb_name]['FU']['idtype'] = functionalUnits[functionalUnit]['control']['@idtype']

							self.switchboxes[swb_name]['FU']['reconfiguration'] = functionalUnits[functionalUnit]['reconfiguration']
							
							if functionalUnits[functionalUnit]['@type'] not in ['ID']:
								if network == 'data':
									self.switchboxes[swb_name][network]['inputs'] = int(functionalUnits[functionalUnit]['connections']['@inputs'])
								else:
									if functionalUnits[functionalUnit]['@type'] not in ['IU']:
										self.switchboxes[swb_name][network]['inputs'] = 1
									else:
										self.switchboxes[swb_name][network]['inputs'] = 0
							else:
								if network == 'data':
									if dataWidth == 8:
										self.switchboxes[swb_name][network]['inputs'] = 2
									else:
										self.switchboxes[swb_name][network]['inputs'] = 1
								else:
									self.switchboxes[swb_name][network]['inputs'] = 0

						if int(functionalUnits[functionalUnit]['@Xloc']) == X and int(functionalUnits[functionalUnit]['@Yloc']) == Y-1:							
							if functionalUnits[functionalUnit]['@type'] not in ['ID']:
								if network == 'data':
									self.switchboxes[swb_name][network]['outputs'] = int(functionalUnits[functionalUnit]['connections']['@outputs'])
								else:
									self.switchboxes[swb_name][network]['outputs'] = 0
							else:
								if network == 'data':
									if dataWidth == 8:
										self.switchboxes[swb_name][network]['outputs'] = 0
									else:
										self.switchboxes[swb_name][network]['outputs'] = 0								
								else:
									self.switchboxes[swb_name][network]['outputs'] = 1									

				self.switchboxes[swb_name][network]['ports'] = ports

	def generateSwitchBoxes(self, sizeX, sizeY, dataWidth, templates, outDir, network,options):		
		totalConfigBits = 0
    
		for Y in range(0,sizeY+1):
			for X in range(0,sizeX+1):
				swb_name = 'X' + str(X) + '_Y' +str(Y)
				
				outputFilePrefix = network + '_' + swb_name
				availablePorts = self.switchboxes[swb_name][network]['ports']

				if 'inputs' in self.switchboxes[swb_name][network]:
					unitInputs = int(self.switchboxes[swb_name][network]['inputs'])
				else:
					unitInputs = int(0)
				
				if 'outputs' in self.switchboxes[swb_name][network]:
					unitOutputs = int(self.switchboxes[swb_name][network]['outputs'])
				else:
					unitOutputs = int(0)
				
				dataBypass = 0
				if Y > 0:
					if 'FU' in self.switchboxes['X' + str(X) + '_Y' +str(Y-1)]:
						if self.switchboxes['X' + str(X) + '_Y' +str(Y-1)]['FU']['type'] in ['ALU'] and network=='data':
							dataBypass = 1

				new_swb = swb_gen(availablePorts, unitInputs, unitOutputs, dataWidth, templates, outDir, outputFilePrefix, network, options, dataBypass)
				self.switchboxes[swb_name][network]['configBits'] = new_swb.numBits
				self.switchboxes[swb_name][network]['connections'] = new_swb.connectionList
				totalConfigBits +=  new_swb.numBits
		
		return totalConfigBits
				#pprint([elem for elem in switchbox.connectionList if elem['outputPort'] == 'BOTTOM' and elem['inputPort'] == 'TOP' ])


	#============================================================================================================
	def __init__(self, config, templates, outDir):
			
		self.config=config	
		 
		self.switchboxes = {}

		networkcfg=self.config['configuration']['network']
		for Y in range(0,networkcfg['data']['sizeY']+1):
			for X in range(0,networkcfg['data']['sizeX']+1):
				swb_name = 'X' + str(X) + '_Y' +str(Y)				
				self.switchboxes[swb_name] = {}
		
		for network in networkcfg:		
			options = {}
			if '@duplex' in networkcfg[network]:
				options['duplex'] = networkcfg[network]['@duplex']
			else:
				options['duplex'] = 'full'

			if '@alu_bypass' in networkcfg[network]:	
				options['alu_bypass'] = networkcfg[network]['@alu_bypass']
			else:
				options['alu_bypass'] = 'cross'				

			availablePorts = [('LEFT',networkcfg[network]['channelsH']),('RIGHT',networkcfg[network]['channelsH']),('TOP',networkcfg[network]['channelsV']),('BOTTOM',networkcfg[network]['channelsV'])]
			self.getNetwork(networkcfg[network]['sizeX'], networkcfg[network]['sizeY'], networkcfg[network]['width'], availablePorts, self.config.functionalUnits, network, options)
			self.drawNetwork(networkcfg[network]['sizeX'], networkcfg[network]['sizeY'],network, outDir)
			ConfigBits = self.generateSwitchBoxes(networkcfg[network]['sizeX'], networkcfg[network]['sizeY'], networkcfg[network]['width'], templates, outDir, network, options)
			print "\t\tTotal number of configuration bits in network '"+network+"' = " + str(ConfigBits)		

		#print self.switchboxes

if __name__ == "__main__":
	print "Cannot run standalone" 
