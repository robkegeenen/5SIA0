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
import textwrap
  
def parse_options():
	parser = OptionParser('Usage: %prog [options]')
	# General options
	parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
				  default=False, help="Run in verbose mode")
 
	# Input/Output options
	parser.add_option("-o", dest="txtOut",
		help='Filename for the output file',
		default="./memorydump.txt")

	# Input/Output options
	parser.add_option("-g", dest="gmFile",
		help='Filename of the global memory dump file',
		default="./GM_out.txt")

	parser.add_option("-L", dest="dumpLen",
		help='Length of the memory area to be dumped',
		default=98)

	parser.add_option("-O", dest="offset",
		help='Word offset of the image in memory',
		default=4096)

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

length = int(opts.dumpLen)
offset = int(opts.offset)

inputData = open(opts.gmFile, 'r').read()
wordSize = int(opts.wordsize);

binOut = ""

for line in inputData.split('\n')[offset:offset+(length)/wordSize]:	
	for byte in list(reversed(textwrap.wrap(line, 8))):		
		if byte != "xxxxxxxx":			
			binOut += str(int(byte,2)) + "\n"
		else:
			raise ValueError("Unexpected value '" + byte+ "' in output data")

open(opts.txtOut, 'w').write(binOut)

