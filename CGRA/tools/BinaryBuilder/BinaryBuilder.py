#!/usr/bin/env python

import os
import re
from optparse import OptionParser
from optparse import OptionGroup
from Parser import Parser
import xmltodict
from pprint import pprint

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

def parse_options():
	parser = OptionParser('Usage: %prog [options] file')
	# General options
	parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
				  default=False, help="Run in verbose mode")
 
	# Input/Output options
	parser.add_option("-o", dest="outFile",
		help='Name of the output file',
		default="out.bin")

	# Input/Output options
	parser.add_option("-d", dest="designName",
		help='Name of the CGRA design',
		default="CGRA")	

	# Input/Output options
	parser.add_option("-V", dest="vbinDir",
		help='Directory with assembler output files (vbin files)',
		default="./")	

	# Input/Output options
	parser.add_option("-m", dest="mappingFile",
		help='Mapping XML file',
		default="./fu_mapping.xml")		

	parser.add_option("-b", dest="configBin",
		help='Binary file for CGRA configuration',
		default="./out.hbin")		

	#parse
	(opts, args) = parser.parse_args()
	return (opts, args)

(opts, args) = parse_options()
VERBOSE = opts.verbose

configData = xmltodict.parse(open(opts.mappingFile, 'r').read())['architecture']
mappingData = configData['fu_mapping']
fuCount = xmltodict.parse(open(opts.mappingFile, 'r').read())['architecture']['fu_count']

interfaceWidth = int(configData['Core']['Interface']['@width'])

binaryBuffer = []

for mapping in mappingData:
	if mapping['type'] in ['ID','IU']:		
		if mapping['placeFU'] != "" and mapping['placeFU'] != None:
			fileName = opts.vbinDir + "/" + mapping['placeFU'] + '.' + opts.designName + ".imem.vbin"
			vbinData = open(fileName, 'r').read()
			if VERBOSE:
				print "vbin file: " + fileName
		else:
			if mapping['type'] not in ['IU']:
				InstructionWidth = configData['Core']['InstructionWidth']['instruction']
			else:
				InstructionWidth = configData['Core']['InstructionWidth']['immediate']

			for file in os.listdir(opts.vbinDir):
				if file.endswith(".vbin"):
					if file != "data.vbin":						
						lineCount=0;
						vbinData = open(os.path.join(opts.vbinDir, file), 'r').read()	
						for line in vbinData.split("\n"):
							if(line.strip()[0:2] != "//" and line.strip()[0:1] != "@" and line.strip() != ""): #if it is not a comment or offet indicator										
								lineCount+=1
						break

			vbinData = lineCount*((int(InstructionWidth)*"0")+"\n")	
		
		lineOut = ""
		tempBuffer = ""		
		index = 0
		numFit = 0

		for line in vbinData.split("\n"):
			if(line.strip()[0:2] != "//" and line.strip()[0:1] != "@" and line.strip() != ""): #if it is not a comment or offet indicator				
				instruction = re.split(r'//',line)[0].strip()
				numFit = int(interfaceWidth)/len(instruction)
				
				if numFit != 0:
					lineOut += "0"*((int(interfaceWidth) /numFit)-len(instruction)) + instruction							
				else:					
					upperPart = instruction[0:-int(interfaceWidth)] #get the bit that is too long (we assume it is less than interfaceWidth)					
					lowerPart = instruction[len(upperPart): len(instruction)]
					upperPart = "0"*(int(interfaceWidth)-len(upperPart)) + upperPart
					tempBuffer += upperPart + "\n" + lowerPart + "\n"							

				if len(lineOut) == int(interfaceWidth):
					tempBuffer += lineOut + "\n"					
					lineOut = ""
					index += 1				

		#add the last bit if necessary		
		if numFit > 1:			
			if len(lineOut) < int(interfaceWidth) and lineOut.strip() != "":				
				tempBuffer += "0"*(int(interfaceWidth) - len(lineOut)) + lineOut
							
		if mapping['type'] == 'ID':
			type = 0
			connectIndex = int(mapping['connectIndex'])
		else:
			type = 1	
			connectIndex = int(mapping['connectIndex']) + int(fuCount['ID'])
					
		lineCount = len(tempBuffer.splitlines())
		
		subHeader = __toBin(numFit,2)
		subHeader = subHeader + __toBin(type,2)
		subHeader = subHeader + __toBin(connectIndex,12)
		subHeader = subHeader + __toBin(lineCount,16)

		#print lineCount
		
		tempBuffer = subHeader + "\n" + tempBuffer
		
		if VERBOSE:
			print mapping['placeFU'] + "("+str(connectIndex)+"):"
			print tempBuffer			

		binData = ""

		for line in tempBuffer.split("\n"):
			if line != "":
				for Y in range(0,int(interfaceWidth)/8):
					binData += chr(int(line.strip()[((interfaceWidth/8)-1-Y)*8:(((interfaceWidth/8)-1-Y)+1)*8],2))

		if VERBOSE:
			print "length = " + str(len(binData))
			print "------------------------------------\n"					

		binaryBuffer.append((mapping['connectIndex'],mapping['type'],lineCount,binData))		

binarySorted = sorted([elem for elem in binaryBuffer if elem[1] == 'ID']) + sorted([elem for elem in binaryBuffer if elem[1] == 'IU'])

headerLength = len(binarySorted) 
headerOffset = headerLength
header = ""
instructionSection = ""

for item in binarySorted:
	if item[1] == 'ID':
		type = 0
	else:
		type = 1

	subHeader = __toBin(type,2)
	subHeader = subHeader + __toBin(item[0],14)
	subHeader = subHeader + __toBin(headerOffset,16)

	#print headerOffset

	#print subHeader

	for Y in range(0,int(interfaceWidth)/8):
		header += chr(int(subHeader.strip()[((interfaceWidth/8)-1-Y)*8:(((interfaceWidth/8)-1-Y)+1)*8],2))	
	
	instructionSection += item[3]	
	headerOffset += item[2]

	if VERBOSE:
		print "length("+item[1]+"_"+item[0]+") = " + str(len(item[3]))

configBin = open(opts.configBin, 'r').read()

endMarkerBin=""
endMarker = "1"*int(interfaceWidth)
for Y in range(0,int(interfaceWidth)/8):
	endMarkerBin += chr(int(endMarker.strip()[((interfaceWidth/8)-1-Y)*8:(((interfaceWidth/8)-1-Y)+1)*8],2))	

if VERBOSE:
	print "config length = " + str(len(configBin))
	print "header length = " + str(len(header))
	print "instruction length = " + str(len(instructionSection))

binOut = configBin + header + instructionSection + endMarkerBin

open(opts.outFile, 'w').write(binOut)



				
		
		
		







