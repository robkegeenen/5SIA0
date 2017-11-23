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

import math
from pprint import pprint
import os
from Templating import TemplateDB

class swb_gen():
	def __fullConnection(self,outputPort, inputPorts, configOffset, connectionList,options,dataBypass):

		outputString = ''
		controlString = ''

		if options['duplex'] == 'full':
			inputPrefix = 'i'
			outputPrefix = 'w'
		else:
			inputPrefix = 'io'
			outputPrefix = 'r'			

		for outputChannel in range(0,outputPort[1]):
			index=0
			count=0
			caseString = '\t\t\t1\'d'+str(index)+'\t:\t' + (outputPrefix if outputPort[0] != 'FUInputs' else 'w') + outputPort[0] + '['+str(outputChannel+1)+"*WIDTH-1-:WIDTH] = {WIDTH{1'b0}};\n"					
			index+=1
			count+=1
			for inputPort in inputPorts:									
				if inputPort != outputPort:
					if (options['alu_bypass'] == 'cross' and inputPort[0] == 'FUOutputs' and outputPort[0] != 'FUInputs' and dataBypass==1):
						count += inputPort[1]-1								
					else:	

						count += inputPort[1]


			numConfigBits = int(math.ceil(math.log(count,2)))

			for inputPort in inputPorts:			
				if inputPort != outputPort:											
					for inputChannel in range(0,inputPort[1]):									
						if not(options['alu_bypass'] == 'cross' and inputPort[0] == 'FUOutputs' and outputPort[0] != 'FUInputs' and inputChannel==0 and dataBypass==1):
							caseString += '\t\t\t'+str(numConfigBits) + '\'d' + str(index)+'\t:\t' + (outputPrefix if outputPort[0] != 'FUInputs' else 'w') + outputPort[0] + '['+str(outputChannel+1)+'*WIDTH-1-:WIDTH] = ' + (inputPrefix if inputPort[0] != 'FUOutputs' else 'i')+inputPort[0]+'['+str(inputChannel+1)+'*WIDTH-1-:WIDTH];\n'									
							connectionList += [dict({'inputPort':inputPort[0], 
													 'inputChannel' : str(inputChannel),
													 'outputPort':outputPort[0],
													 'outputChannel':str(outputChannel),
													 'configBits':str(numConfigBits-1+configOffset)+':'+str(configOffset),
													 'configValue':str(index)
													 })]
							index += 1
				
			if options['duplex'] != 'full':
				if outputPort[0] != 'FUInputs':						
					if outputPort[0] in ['LEFT','TOP']:
						controlString += 'assign wEnable' + outputPort[0] + '[' + str(outputChannel) +'] = !iInUse' + outputPort[0] + '[' + str(outputChannel) +'] & (wConfig[' + str(numConfigBits-1+configOffset)+':'+str(configOffset) + '] != 0);\n\t'	
					else:
						controlString += 'assign wEnable' + outputPort[0] + '[' + str(outputChannel) +'] = (wConfig[' + str(numConfigBits-1+configOffset)+':'+str(configOffset) + '] != 0);\n\t'
						controlString += 'assign oClaim' + outputPort[0] + '[' + str(outputChannel) +'] = (wConfig[' + str(numConfigBits-1+configOffset)+':'+str(configOffset) + '] != 0);\n\t'

			caseString += '\t\t\tdefault\t:\t' + (outputPrefix if outputPort[0] != 'FUInputs' else 'w') + outputPort[0] + '['+str(outputChannel+1)+"*WIDTH-1-:WIDTH] = {WIDTH{1'b0}};\n"				
			caseString = '\t\tcase (wConfig['+str(numConfigBits-1+configOffset)+':'+str(configOffset)+'])\n' + caseString + '\t\tendcase\n'

			sensitivityList = ''
			for port in inputPorts:
				sensitivityList += (inputPrefix if port[0] != 'FUOutputs' else 'i') + port[0] + ' or '
			sensitivityList += 'wConfig['+str(numConfigBits-1+configOffset)+':'+str(configOffset)+']'
		
			caseString = '\talways @(' + sensitivityList + ') begin\n' + caseString + '\tend\n\n'			

			configOffset += numConfigBits
			outputString += caseString
						
		return (outputString,configOffset,connectionList, controlString)


	def __init__(self,availablePorts, numFUInputs, numFUOutputs, dataWidth, templates, outDir, outputFilePrefix, network, options, dataBypass):		
		configOffset=0

		template = templates['swb_'+network]

		outputPortList = availablePorts
		inputPortList = availablePorts

		wireString = ''
		outputWires = ''
		controlWireString = ''
		outputRegisters = ''
		enableWireString = ''
		outputAssignString = ''
		controlString = ''
		bufferString = ''

		for port in availablePorts:
			if options['duplex'] != 'full':
				if port[0] in ['BOTTOM','RIGHT']:  
					controlWireString += 'output ['+str(port[1])+'-1:0] oClaim' + port[0] + ',\n\t'					
				else:					
					controlWireString += 'input ['+str(port[1])+'-1:0] iInUse' + port[0] + ',\n\t'

				wireString += 'inout tri ['+str(port[1])+'*WIDTH-1:0] io' + port[0] + ',\n\t'
				outputRegisters+= 'reg ['+str(port[1])+'*WIDTH-1:0] r' + port[0] + ';\n\t'
				enableWireString += 'wire ['+str(port[1])+'-1:0] wEnable' + port[0] + ';\n\t'

				for X in range(0,port[1]):
					outputAssignString += 'assign io' + port[0] + '[' + str(X+1) + '*WIDTH-1-:WIDTH] = (wEnable' + port[0] +'[' + str(X) + ']) ? r' + port[0] + '[' + str(X+1) + '*WIDTH-1-:WIDTH] : \'bZ;\n\t'				
			else:
				wireString += 'output ['+str(port[1])+'*WIDTH-1:0] o' + port[0] + ',\n\t'
				wireString += 'input ['+str(port[1])+'*WIDTH-1:0] i' + port[0] + ',\n\t'

				outputWires += 'reg ['+str(port[1])+'*WIDTH-1:0] w'  + port[0] + ';\n\t'				

				bufferString += "DATA_Buffer #(.WIDTH("+str(port[1])+ "*WIDTH)) buffer_swb_"+port[0]+"(.iData(w"+port[0]+"), .oData(o"+port[0]+"));\n\t"

		if numFUInputs != 0:
			wireString += 'output [FU_INPUTS*WIDTH-1:0] oFUInputs,\n\t'
			outputWires += 'reg ['+str(numFUInputs)+'*WIDTH-1:0] wFUInputs;\n\t'
			bufferString += "DATA_Buffer #(.WIDTH("+str(numFUInputs)+ "*WIDTH)) buffer_FU (.iData(wFUInputs), .oData(oFUInputs));\n\t"
			outputPortList = availablePorts + [('FUInputs',numFUInputs)]

		if numFUOutputs != 0:
			wireString += 'input [FU_OUTPUTS*WIDTH-1:0] iFUOutputs,\n\t'
			inputPortList = availablePorts + [('FUOutputs',numFUOutputs)]

		connectionString = ''
		self.connectionList = []

		for port in outputPortList:	
			caseString,configOffset,self.connectionList,controlStringPartial = self.__fullConnection(port,inputPortList, configOffset, self.connectionList, options,dataBypass)
			connectionString += caseString
			controlString += controlStringPartial
		
		template = template.replace("<<MODULE_NAME>>",'SWB_'+outputFilePrefix)
		template = template.replace("<<WIDTH>>",str(dataWidth))
		template = template.replace("<<NUM_INPUTS>>",str(numFUInputs))
		template = template.replace("<<NUM_OUTPUTS>>",str(numFUOutputs))
		if options['duplex'] != 'full':			
			template = template.replace("<<CONTROL_WIRES>>",controlWireString)
			template = template.replace("<<CONTROL_ASSIGNMENT>>",controlString)
			template = template.replace("<<ENABLE_WIRES>>",enableWireString)
			template = template.replace("<<OUTPUT_ASSIGNMENT>>",outputAssignString)
			template = template.replace("<<OUTPUT_REGISTERS>>",outputRegisters)
			template = template.replace("<<OUTPUT_WIRES>>","")
			template = template.replace("<<OUTPUT_BUFFERS>>","")
		else:
			template = template.replace("<<CONTROL_WIRES>>","")
			template = template.replace("<<CONTROL_ASSIGNMENT>>","")
			template = template.replace("<<ENABLE_WIRES>>","")
			template = template.replace("<<OUTPUT_ASSIGNMENT>>","")
			template = template.replace("<<OUTPUT_REGISTERS>>","")
			template = template.replace("<<OUTPUT_WIRES>>",outputWires)
			template = template.replace("<<OUTPUT_BUFFERS>>",bufferString)
		template = template.replace("<<WIRES>>",wireString)
		template = template.replace("<<CONFIG_LENGTH>>",str(configOffset))
		template = template.replace("<<CONNECTIONS>>",connectionString)

		switchboxDir=os.path.join(outDir,'Switchboxes')
		if not os.path.exists(switchboxDir):
			os.makedirs(switchboxDir)

		f = open(os.path.join(switchboxDir,outputFilePrefix+'.v'),'w')
		f.write(template)
		f.close

		f = open(os.path.join(switchboxDir,outputFilePrefix+'.con'),'w')
		f.write(str(self.connectionList))
		f.close

		self.numBits = configOffset		

if __name__ == "__main__":
	templates = TemplateDB("./templates")
	outDir = "./generated"
	outputFilePrefix = "swb_data"

	dataWidth = 8
	unitInputs = 4
	unitOutputs = 2

	availablePorts = [('LEFT',4),('RIGHT',4),('TOP',4),('BOTTOM',4)]

	switchbox = swb_gen(availablePorts, unitInputs, unitOutputs, dataWidth, templates, outDir, outputFilePrefix,'data')	
	pprint([elem for elem in switchbox.connectionList if elem['outputPort'] == 'BOTTOM' and elem['inputPort'] == 'TOP' ])





