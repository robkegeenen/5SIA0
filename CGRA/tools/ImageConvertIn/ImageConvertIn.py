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
	parser.add_option("-o", dest="vbinFile",
		help='Filename for the output data binary',
		default="./data.vbin")

	# Input/Output options
	parser.add_option("-i", dest="pgmFile",
		help='Filename of the ginput image',
		default="./GM_out.txt")

	parser.add_option("-b", dest="wordsize",
		help='Size (in bytes) of one memory word',
		default=4)

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

inputData = open(opts.pgmFile, 'r').read()

wordSize = opts.wordsize;
binaryData = ""
storeBinaryData = False

for line in inputData.split('\n'):
	if storeBinaryData == True:		
		binaryData = binaryData + line

	if line == "255":
		storeBinaryData = True

binaryList = list(binaryData)
binaryList += [chr(0)] * (wordSize - (len(binaryList) % wordSize))
binaryDataOut = [list(binaryList)[n:n+wordSize] for n in range(0, len(list(binaryList)), wordSize)]

binOut = ""
for word in binaryDataOut:
	charList = [ord(i) for i in list(reversed(word))]
	binWord = ""
	for char in charList:
		binWord += __toBin(char,8)
	binOut += binWord + "\n"

open(opts.vbinFile, 'w').write(binOut)

