#!/usr/bin/env python

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

VERBOSE = False

def parse_options():
	parser = OptionParser('Usage: %prog [options]')
	# General options
	parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
				  default=False, help="Run in verbose mode")
 
	# Input/Output options
	parser.add_option("-b", dest="outBin",
		help='Filename for the header binary (output)',
		default="./out.hbin")

	# Input/Output options
	parser.add_option("-m", dest="outMap",
		help='Filename for the mapping description (output)',
		default="./mapping.xml")

	parser.add_option("-i", dest="instanceFile",
		help='Location of the CGRA instance file',
		default="./instance_info.xml")

	parser.add_option("-p", dest="pnrFile",
		help='Place and Route file (optional input)',
		default=None)
 
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

def __getPathWidths(configData):
    instructionWidths = []
    immediateWidths = []

    for instructionType in configData['architecture']['ISA']['instructiontypes']:
        width = 0
        isImmediate = 0
        for fieldName, field in configData['architecture']['ISA']['instructiontypes'][instructionType].items():
            if fieldName[0] != '@':
                isImmediate = field['@type'] == 'immediate'

                if '@width' in field:
                    width += int(field['@width'])
                else:
                    width += int(configData['architecture']['ISA']['instructionFieldTypes'][field['@type']]['@width'])
        if not isImmediate:
            instructionWidths.append(width)
        else:
            immediateWidths.append(width)

    instructionWidth = min(instructionWidths)
    immediateWidth = max(immediateWidths)
    
    return (instructionWidth, immediateWidth)

(opts, args) = parse_options()
VERBOSE = opts.verbose

configData = xmltodict.parse(open(opts.instanceFile, 'r').read())
interfaceWidth = int(configData['architecture']['Core']['Interface']['@width'])

if opts.pnrFile!=None:
	placerouteData = xmltodict.parse(open(opts.pnrFile, 'r').read())

configurations = {}

if 'network' in configData['architecture']:	
	networkData = configData['architecture']['network']
	for network in ['data','control']:
		networkSize = (int(configData['architecture']['configuration']['network'][network]['sizeX'])+1,int(configData['architecture']['configuration']['network'][network]['sizeY'])+1)
		print "- Generating configuration for network '" + network + "'"
		configStringList = {}
		#for swb in swbConfig[network]:
		for swb in placerouteData['place_and_route']['route'][network]:		
			swbConnections = placerouteData['place_and_route']['route'][network][swb]['connection']				
			connections = networkData[swb][network]['connections']

			if VERBOSE:
				print swb

			configBitsList = {}
			for connection in connections:					
				configBitsList[int(re.split(r'\:',connection['configBits'])[0])] = (int(re.split(r'\:',connection['configBits'])[1]),'')

			if not isinstance(swbConnections,list):
				swbConnections = [swbConnections]

			for config in swbConnections:
				sourcePort = re.split(r'\.',config['@source'])[0]
				sourceChannel = re.split(r'\.',config['@source'])[1]
				destPort = re.split(r'\.',config['@destination'])[0]
				destChannel = re.split(r'\.',config['@destination'])[1]

				if VERBOSE:
					print '\t' + sourcePort + '[' + sourceChannel + '] \t -> \t ' + destPort + '[' + destChannel + ']'			

				connectionFound = 0				
				for connection in connections:          
					if connection['outputPort'] == destPort and connection['outputChannel'] == destChannel and connection['inputPort'] == sourcePort and connection['inputChannel'] == sourceChannel:
						connectionFound = 1             
						upperBit = int(re.split(r'\:',connection['configBits'])[0])
						lowerBit = int(re.split(r'\:',connection['configBits'])[1])

						if configBitsList[upperBit][1] == '':
							configBitsList[upperBit] = (lowerBit,connection['configValue'])
						else:
							raise ValueError("Output " + destPort + '[' + destChannel + '] is used multiple times' ) 

				if connectionFound == 0:
					raise ValueError("Connection at switchbox '" +network+"."+swb+ "' " + sourcePort + '[' + sourceChannel + ']-> ' + destPort + '[' + destChannel + '] cannot be made.' )  

			sortedBits = sorted([elem for elem in configBitsList])
			configString = ''

			for upperBit in sortedBits:
				lowerBit = configBitsList[upperBit][0]      
				configWidth = upperBit - lowerBit + 1

				if configBitsList[upperBit][1] == '':
					configValue = 0
				else:
					configValue = int(configBitsList[upperBit][1])

				#print upperBit,':',lowerBit,'\t',configValue
				configString = __toBin(configValue,configWidth) + configString
			
			configStringList[swb] = {}
			configStringList[swb]['connections'] = networkData[swb][network]['connections']
			configStringList[swb]['configuration'] = configString
			configStringList[swb]['configurationLength'] = upperBit+1

			if VERBOSE:
				print '\tConfiguration string: \t' + configString
		
		configLength = 0
		configString = ""

		for Y in range(0,networkSize[1]):
			for X in range(0,networkSize[0]):
				swb_name = 'X' + str(X) + '_Y' +str(Y)
				
				if swb_name in configStringList:
					configStringPartial = configStringList[swb_name]['configuration']
				else:
					connections = networkData[swb_name][network]['connections']
					highestBit = 0
					for connection in connections:
						extractedBit = int(re.split(r'\:',connection['configBits'])[0])
						if extractedBit > highestBit:
							highestBit = extractedBit

					configStringPartial = ("0") * (highestBit+1)

				#print swb_name, len(configStringPartial),configStringPartial
				configLength += len(configStringPartial)			
				configString = configString + configStringPartial			

		configurations[network] = configString
		if VERBOSE:
			print '\n--------------------------------------------------\nNetwork configuration for network \'' + network + '\' (length='+str(configLength)+'):\n' + configString

	print "- Generating configuration for functional units"

	reconfigurationData = configData['architecture']['reconfiguration']
	functionalUnitsChip = configData['architecture']['configuration']['functionalunits']['fu']
	functionalUnitTypes = configData['architecture']['configuration']['functionalunittypes']

	currDecoder = [decoderName for decoderName, decoder in reconfigurationData.items() if decoder['last'] == '1'][0]

	configLength = 0
	configString = ''
	condition = 1   
	mappingTable = []

	configIndex = len(reconfigurationData)-1

	fuCount = {}

	for FU in functionalUnitsChip:
		if FU['@type'] in fuCount:
			fuCount[FU['@type']] += 1
		else:
			fuCount[FU['@type']] = 1	
	
	while condition==1:
		if reconfigurationData[currDecoder]['sourceUnit'] == None:
			condition = 0		

		for FU in functionalUnitsChip:

			if FU['@name'] == currDecoder:
				configLen = int(functionalUnitTypes[FU['@type']]['reconfiguration']['@bits'])				

				placeFUFound = False

				for placeFU in placerouteData['place_and_route']['place']['fu']: 
					if placeFU['@Xloc'] == FU['@Xloc'] and placeFU['@Yloc'] == FU['@Yloc']:
						placeFUFound = True			

						configValue = ""

						if '@config' in placeFU:
							#print "Config: " + placeFU['@config']
							configValue = __toBin(placeFU['@config'],configLen)			
							#print configValue

						carryConfig="00"

						if placeFU['@type']	in ['ALU']:
							if '@carry_config' in placeFU:
								if placeFU['@carry_config'] == "start":
									carryConfig = "01"
								if placeFU['@carry_config'] == "middle":
									carryConfig = "11"
								if placeFU['@carry_config'] == "end":
									carryConfig = "10"
								if placeFU['@carry_config'] == "none":
									carryConfig = "00"

								configValue = carryConfig + configValue[configLen-1:configLen]								

						if '@stallgroup' in placeFU:
							#print "StallGroup: " + placeFU['@stallgroup']
							numStallGroups = int(configData['architecture']['configuration']['stallgroups']['@number'])
							stallConfigWidth = max(int(math.ceil(math.log(numStallGroups,2))),1)      
							configValue = __toBin(placeFU['@stallgroup'],stallConfigWidth) + configValue
							configLen += stallConfigWidth
							#print configValue

						mapping = {}
						mapping['chipFU'] = FU['@name']
						mapping['placeFU'] = placeFU['@name']
						mapping['configIndex'] = configIndex						
						mapping['configValue'] = configValue
						mapping['type'] = FU['@type']
						if 'index' in FU:
							mapping['connectIndex'] = FU['index']						
						mappingTable.append(mapping)
						configString = configValue + configString
						configIndex = configIndex - 1

				if not placeFUFound:
					configLen = int(FU['reconfiguration']['@bits'])
					configValue = configLen*"0"
					
					if FU['@type'] in ['ID','IU','LSU']:						
						numStallGroups = int(configData['architecture']['configuration']['stallgroups']['@number'])
						stallConfigWidth = max(int(math.ceil(math.log(numStallGroups,2))),1)      
						configValue = __toBin(0,stallConfigWidth) + configValue
						configLen += stallConfigWidth					

					mapping = {}
					mapping['chipFU'] = FU['@name']
					mapping['placeFU'] = ""
					mapping['configIndex'] = configIndex						
					mapping['configValue'] = configValue
					mapping['type'] = FU['@type']
					if 'index' in FU:
						mapping['connectIndex'] = FU['index']						
					mappingTable.append(mapping)					
					configString = configValue + configString
					configIndex = configIndex - 1					

					print 'INFO: Could not cross reference function unit \''+FU['@name']+'\'in instance description and place-and-route file, unit is unused...'								

		currDecoder = reconfigurationData[currDecoder]['sourceUnit']

	

	#add the immediate units to the mapping
	for FU in functionalUnitsChip:
		if FU['@type'] == 'IU':
			for placeFU in placerouteData['place_and_route']['place']['fu']: 
				if placeFU['@Xloc'] == FU['@Xloc'] and placeFU['@Yloc'] == FU['@Yloc']:					
					mapping = {}
					mapping['chipFU'] = FU['@name']
					mapping['placeFU'] = placeFU['@name']
					mapping['type'] = FU['@type']
					if 'index' in FU:
						mapping['connectIndex'] = FU['index']						
					mappingTable.append(mapping)

		#print currDecoder
	configurations['functionalUnits'] = configString
	if VERBOSE:
		print str(len(configString)) + "'b" + configString 	

	configString = configurations['functionalUnits'] + configurations['data'] + configurations['control']
	configLength = len(configurations['functionalUnits']) + len(configurations['data']) + len(configurations['control'])

else:
	print "\t- Could not find a network description, treating description as a hard-wired CGRA"

	reconfigurationData = configData['architecture']['reconfiguration']
	functionalUnitsChip = configData['architecture']['configuration']['functionalunits']['fu']
	functionalUnitTypes = configData['architecture']['configuration']['functionalunittypes']

	fuCount = {}
	for FU in functionalUnitsChip:
		if FU['@type'] in fuCount:
			fuCount[FU['@type']] += 1
		else:
			fuCount[FU['@type']] = 1	
	
	currDecoder = [decoderName for decoderName, decoder in reconfigurationData.items() if decoder['last'] == '1'][0]

	configLength = 0
	configString = ''
	condition = 1   
	mappingTable = []

	configIndex = len(reconfigurationData)-1
	
	while condition==1:
		if reconfigurationData[currDecoder]['sourceUnit'] == None:
			condition = 0

		for FU in functionalUnitsChip:
			if FU['@name'] == currDecoder:						
				configLen = int(functionalUnitTypes[FU['@type']]['reconfiguration']['@bits'])
				configValue = reconfigurationData[FU['@name']]['configData']
				#print FU, configLen, configValue
				mapping = {}
				mapping['chipFU'] = FU['@name']
				mapping['placeFU'] = currDecoder
				mapping['configIndex'] = configIndex						
				mapping['configValue'] = configValue
				mapping['type'] = FU['@type']
				if 'index' in FU:
					mapping['connectIndex'] = FU['index']						
				mappingTable.append(mapping)
				configString = configValue + configString
				configIndex = configIndex - 1
				#print FU['@name']

		currDecoder = reconfigurationData[currDecoder]['sourceUnit']	

	#add the immediate units to the mapping
	for FU in functionalUnitsChip:
		if FU['@type'] == 'IU':		
			mapping = {}
			mapping['chipFU'] = FU['@name']
			mapping['placeFU'] = FU['@name']
			mapping['type'] = FU['@type']
			if 'index' in FU:
				mapping['connectIndex'] = FU['index']						
			mappingTable.append(mapping)

	#print currDecoder
	configurations['functionalUnits'] = configString

	configString = configurations['functionalUnits']
	configLength = len(configurations['functionalUnits'])
	#print configString,"   ",configLength


paddingBits = interfaceWidth - (configLength % interfaceWidth)

if paddingBits != 0: #padding required
	configString = configString + ("0" * paddingBits)
	configLength += paddingBits

if VERBOSE:
	print "\n\nConfig String: " + configString + "\n\n"

configWords = (configLength) / interfaceWidth
configHeader = ""
verboseHeader = ""
configString = configString + __toBin(configWords,32)

if VERBOSE:
	print 'Configuration: ---------------------'

for X in range(0,configWords+1):		
	headerSubString = ""
	subString = configString[X*interfaceWidth:(X+1)*interfaceWidth]	

	for Y in range(0,interfaceWidth/8):
		headerSubString += chr(int(subString[((interfaceWidth/8)-1-Y)*8:(((interfaceWidth/8)-1-Y)+1)*8],2))	

	configHeader =  headerSubString + configHeader
	verboseHeader = str(X) + ':\t' + subString + "\n" + verboseHeader 

if VERBOSE:
	print  verboseHeader
	print len(configHeader)

(instructionWidth, immediateWidth) = __getPathWidths(configData)

configData['architecture']['Core']['InstructionWidth']={}
configData['architecture']['Core']['InstructionWidth']['instruction']=instructionWidth;
configData['architecture']['Core']['InstructionWidth']['immediate']=immediateWidth;

mappingTableOut={}
mappingTableOut['architecture']={}
mappingTableOut['architecture']['Core'] = configData['architecture']['Core']
mappingTableOut['architecture']['fu_count'] = fuCount
mappingTableOut['architecture']['fu_mapping'] = mappingTable

open(opts.outBin, 'w').write(configHeader)
open(opts.outMap, 'w').write(xmltodict.unparse(mappingTableOut,pretty=True))


