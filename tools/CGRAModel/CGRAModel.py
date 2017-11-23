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
import re
import errno
from optparse import OptionParser
from optparse import OptionGroup
from Parser import Parser
import xmltodict
from pprint import pprint
from collections import OrderedDict
import math
  
def parse_options():
	parser = OptionParser('Usage: %prog [options]')
	# General options
	parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
				  default=False, help="Run in verbose mode")
 
	# Input/Output options
	parser.add_option("-m", dest="fileModel",
		help='Filename for the model description',
		default="./model.xml")

	# Input/Output options
	parser.add_option("-i", dest="fileInstanceInfo",
		help='Filename for the instance info description',
		default="./instance_info.xml")

	parser.add_option("-S", dest="simulationFolder",
		help='Folder where .txt simulation results can be found',
		default="./")

	parser.add_option("-r", dest="fileReport",
		help='Report file location (output)',
		default="./report.txt")

	parser.add_option("-p", dest="pasmFile",
		help='PASM file',
		default="")	
 
	#parse
	(opts, args) = parser.parse_args()
	return (opts, args)

def __toBin(value, bits=32):
	fmt="{0:0"+str(bits)+"b}"

	if value<0:
		value=(value*-1)-1
		s=fmt.format(int(value))
		s=s.replace('0','t')
		s=s.replace('1','0')
		s=s.replace('t','1')
		return s
	return fmt.format(int(value))

(opts, args) = parse_options()
VERBOSE = opts.verbose

InstanceInfo = xmltodict.parse(open(opts.fileInstanceInfo, 'r').read())
modelInfo = xmltodict.parse(open(opts.fileModel, 'r').read())
reportOut = ""

#calculate path widths --------------------------------------------------------------------------------------------------------
instructionWidths = []
immediateWidths = []

for instructionType in  InstanceInfo['architecture']['ISA']['instructiontypes']:
    width = 0
    isImmediate = 0
    for fieldName, field in  InstanceInfo['architecture']['ISA']['instructiontypes'][instructionType].items():
        if fieldName[0] != '@':
            isImmediate = field['@type'] == 'immediate'

            if '@width' in field:
                width += int(field['@width'])
            else:
                width += int( InstanceInfo['architecture']['ISA']['instructionFieldTypes'][field['@type']]['@width'])
    if not isImmediate:
        instructionWidths.append(width)
    else:
        immediateWidths.append(width)

instructionWidth = min(instructionWidths)
immediateWidth = max(immediateWidths)
dataWidth = int( InstanceInfo['architecture']['Core']['DataPath']['@width'])
decodedWidth = int(InstanceInfo['architecture']['Core']['DecodedInstructions']['@width'])

# retrieve architecture info -----------------------------------------------------------------------------------------------------

functionalUnits = InstanceInfo['architecture']['configuration']['functionalunits']['fu']

#make list of all decoder units, the types connected to them and the number of FUs
decoders = {}

for fu in functionalUnits:
	if fu['@type'] not in ['ID','IU']:
		if fu['@ID'] not in decoders:
			decoders[fu['@ID']] = {}
			decoders[fu['@ID']]['type'] = fu['@type']
			decoders[fu['@ID']]['fuCount'] = 1			
			decoders[fu['@ID']]['instructionWidth'] = instructionWidth 		
		else:
			decoders[fu['@ID']]['fuCount'] += 1
	elif fu['@type'] in ['IU']:
		decoders[fu['@name']] = {}
		decoders[fu['@name']]['type'] = fu['@type']
		decoders[fu['@name']]['fuCount'] = 1
		decoders[fu['@name']]['instructionWidth'] = immediateWidth 

# Extract the traces ------------------------------------------------------------------------------------------------------------------------

traceFile =  os.path.join(opts.simulationFolder,"ABU_out_abu.txt")

trace = open(traceFile, 'r').read().split('\n')
pasm = open(opts.pasmFile, 'r').read().split('\n')

pasmHeader = pasm[0].split("|")
pasmHeader[:] = [item.strip() for item in pasmHeader if item != '']
pasm = pasm[4:len(pasm)]

prevInstruction = {}

for decoder in decoders:	
	decoders[decoder]['pasmIndex'] = pasmHeader.index(decoder)
	decoders[decoder]['profiling'] = {}

	if decoders[decoder]['type'] == "IU":
		prevInstruction[decoder] = "nopi"
	else:
		prevInstruction[decoder] = "nop"

PC = 1

stallLines= []

for line in trace:

	if line.split() != []:		
		lineType = line.split()[0]

		if (lineType=="S"):
			stallAddr = int(line.split()[1])-2
			stallCount = int(line.split()[2])			
			stallLines.append((stallAddr,stallCount))			

		if (lineType=="B"):
			nextAddr = int(line.split()[1])
			nextTarget = int(line.split()[2])
		
			while(True):
				pasm_PC = pasm[PC].split("|")
				pasm_PC[:] = [item.strip() for item in pasm_PC if item != '']				
				
				if pasm_PC != []:
					for decoder in decoders:
						instruction = pasm_PC[decoders[decoder]['pasmIndex']].strip()

						if instruction != "":
							instruction = instruction.split()[0]
							if instruction[0] == ";":
								instruction = ""

						if instruction == "":
							if decoders[decoder]['type'] == "IU":
								instruction = "nopi"
							else:
								instruction = "nop"

						if not instruction in decoders[decoder]['profiling']:
							decoders[decoder]['profiling'][instruction] = {}
							decoders[decoder]['profiling'][instruction]['count'] = 1
							decoders[decoder]['profiling'][instruction]['notoggle'] = 0
						else:
							decoders[decoder]['profiling'][instruction]['count'] += 1
							if instruction == prevInstruction[decoder]:
								decoders[decoder]['profiling'][instruction]['notoggle'] += 1									

						prevInstruction[decoder] = instruction		
									
					found = False
					for stallIndex in range(0,len(stallLines)):
						if stallLines[stallIndex][0] == PC and stallLines[stallIndex][1] > 0:
							stallLines[stallIndex] = (stallLines[stallIndex][0],stallLines[stallIndex][1]-1)
							found = True										
							
					if not found:		
						if (PC != nextAddr):						
							PC += 1
						else:							
							PC = nextTarget	
							stallLines= []								
							break													
				else:
					break


# Calculate energy ----------------------------------------------------------------------------------

reportOut += "\n----------------------------------\n"
reportOut += "|        Energy report:          |\n"
reportOut += "----------------------------------\n\n"

instructionCount = ""

totalEnergy = 0.0
for decoder in decoders:
	profilingData = decoders[decoder]['profiling']
	decoderType = decoders[decoder]['type']
	decoderEnergy = 0.0
	
	instructionCount += "------------------------------------------------------------ " + decoder + " :\n"

	for instruction in profilingData:
		profilingData[instruction]['energy'] = float(modelInfo['model']['energy'][decoderType][instruction]['@energy_op']) * float(profilingData[instruction]['count']) * float(decoders[decoder]['fuCount']) 
		profilingData[instruction]['energy'] += float(modelInfo['model']['energy']['ID']['decoding']['@energy_op']) * (float(profilingData[instruction]['count']) - float(profilingData[instruction]['notoggle']))
		profilingData[instruction]['energy'] += float(modelInfo['model']['energy']['ID']['decoding_repeat']['@energy_op']) * float(profilingData[instruction]['notoggle'])
		
		instructionCount += "\t" + instruction + "\t:\tcount: " + str(profilingData[instruction]['count'])+"\tno toggle:\t" + str(profilingData[instruction]['notoggle']) + "\n"

		decoderEnergy += profilingData[instruction]['energy']
	
	reportOut += "Energy for FUs ("+str(decoders[decoder]['fuCount'])+") and ID for '"+decoder+"':\t"+str(decoderEnergy) + " pJ\n"
	totalEnergy += decoderEnergy

reportOut += "\nTotal energy:\t" + str(totalEnergy) + " pJ\n"

if VERBOSE:
	print instructionCount

# Calculate energy ----------------------------------------------------------------------------------

reportOut += "\n----------------------------------\n"
reportOut += "|         Area report:           |\n"
reportOut += "----------------------------------\n\n"

fuCount = {}

for fu in functionalUnits:
	fuType = fu['@type']

	if 'input' in fu:		
		if not isinstance(fu['input'],list):
			inputs = [fu['input']]
		else:
			inputs = fu['input']

	wireCount =  len(inputs)
		

	if fuType not in fuCount:
		fuCount[fuType] = {}
		fuCount[fuType]['fuCount'] = 1		
		fuCount[fuType]['wireCount'] = wireCount
	else:
		fuCount[fuType]['fuCount'] += 1
		fuCount[fuType]['wireCount'] += wireCount

	if fu not in ['IU','ID']:
		fuCount[fuType]['wireCount'] += 1 #+1 for decoded instruction wire

totalWireArea = 0.0
totalFUArea = 0.0

for fu in fuCount:
	fuArea = float(modelInfo['model']['area'][fu]['@area_um2']) * float(fuCount[fu]['fuCount'])
	wireArea = float(modelInfo['model']['area']['wire']['@area_um2']) * float(fuCount[fu]['wireCount'])
	fuCount[fu]['fuArea'] = fuArea
	fuCount[fu]['wireArea'] = wireArea
	reportOut += "Area for FU type '"+fu+"' ("+str(fuCount[fu]['fuCount'])+"):\t" + str(fuArea) + " um^2\tWire area ("+str(fuCount[fu]['wireCount'])+"):\t" + str(wireArea) + " um^2\tTotal area:\t" + str(fuArea+wireArea) + " um^2\n"

	totalWireArea += wireArea
	totalFUArea += fuArea

reportOut += "\nTotal FU area:\t" + str(totalFUArea) + " um^2\tTotal wire area:\t" + str(totalWireArea) + " um^2\tTotal area:\t" + str(totalFUArea+totalWireArea) + " um^2\n"


reportOut += "\n----------------------------------\n"
reportOut += "|      Performance report:       |\n"
reportOut += "----------------------------------\n\n"

perfFile = os.path.join(opts.simulationFolder,"performance_info.txt")

perfinfo = open(perfFile, 'r').read()

reportOut += perfinfo

if VERBOSE:
	print reportOut


open(opts.fileReport, 'w').write(reportOut)
	






