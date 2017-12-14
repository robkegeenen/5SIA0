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
import textwrap
  
def parse_options():
	parser = OptionParser('Usage: %prog [options]')
	# General options
	parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
				  default=False, help="Run in verbose mode")
 
	# Input/Output options
	parser.add_option("-o", dest="pgmOut",
		help='Filename for the output image',
		default="./image_out.pgm")

	# Input/Output options
	parser.add_option("-g", dest="gmFile",
		help='Filename of the global memory dump file',
		default="./GM_out.txt")

	parser.add_option("-W", dest="imageWidth",
		help='Width of the output image',
		default=98)

	parser.add_option("-H", dest="imageHeight",
		help='Height of the output image',
		default=98)

	parser.add_option("-S", dest="scaleFactor",
		help='Scale the pixel values by this factor',
		default=1)

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

image_height = int(opts.imageHeight)
image_width = int(opts.imageWidth)
image_offset = int(opts.offset)

inputData = open(opts.gmFile, 'r').read()
wordSize = int(opts.wordsize);

binOut = ""

for line in inputData.split('\n')[image_offset:image_offset+(image_width*image_height)/wordSize]:	
	for byte in list(reversed(textwrap.wrap(line, 8))):		
		if byte != "xxxxxxxx":			
			binOut += chr(int(byte,2)*(int(opts.scaleFactor)))
		else:
			raise ValueError("Unexpected value '" + byte+ "' in output data")

binOut = "P5\n# created by the edge detect application\n" + str(image_width) + " " + str(image_height) + "\n255\n" + binOut

open(opts.pgmOut, 'w').write(binOut)

