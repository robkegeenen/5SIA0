#!/usr/bin/env python

import os
import re
import errno
from optparse import OptionParser
from optparse import OptionGroup
from Parser import Parser
from pprint import pprint
from collections import OrderedDict
import math
import json
  
def parse_options():
	parser = OptionParser('Usage: %prog [options]')
	# General options
	parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
				  default=False, help="Run in verbose mode")
 
	# Input/Output options
	parser.add_option("-D", dest="swbDir",
		help='Path to the switchbox RTL folder',
		default="./switchboxes")

	# Input/Output options
	parser.add_option("-o", dest="outputFile",
		help='Filename of the target JSON file',
		default="./output.json")

	# Input/Output options
	parser.add_option("-t", dest="templateFile",
		help='Path to the JSON template',
		default="../template.json")
	#parse
	(opts, args) = parser.parse_args()
	return (opts, args)

(opts, args) = parse_options()
VERBOSE = opts.verbose

replaceString = ""

if os.path.exists(os.path.join(opts.swbDir)):
	for file in os.listdir(opts.swbDir):
	    if file.endswith(".v"):
	         replaceString += "\"" + file + "\",\n\t\t\t\t\t\t\t\t"
else:
	print "Switchbox folder does not exist..."

fileContents = open(opts.templateFile, 'r').read()

fileContents = fileContents.replace("<<SWITCHBOXES>>",replaceString)			

if not os.path.exists(os.path.dirname(opts.outputFile)):
	os.makedirs(os.path.dirname(opts.outputFile))

open(opts.outputFile, 'w').write(fileContents)


			



