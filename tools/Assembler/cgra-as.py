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
from optparse import OptionParser
from optparse import OptionGroup

from Parser import Parser
from Assembler import Assembler
from Formatter import Formatter

import sys

VERBOSE = False

def parse_options():
    parser = OptionParser('Usage: %prog [options] file')
    # General options
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose",
                      default=False, help="Run in verbose mode")
    
    # Input/Output options
    parser.add_option("-o", dest="outDir", help='Output Directory', default=os.path.abspath('.'))
    parser.add_option("-d", dest="designName", help='Design name used to determine output file names',  default='design')
    parser.add_option("-c","--arch-file", dest="archFile", 
        help='Architecture description file (in xml format)',
    )
    parser.add_option("-f", "--fmt", 
        type="choice", 
        action="store",
        dest="outputfmt", 
        choices=['vbin', 'mif'],
        default='vbin',
        help='Output file format')
    
    #parse
    (opts, args) = parser.parse_args()
    return (opts, args)


if __name__ == '__main__':
    (opts, args) = parse_options()
    VERBOSE = opts.verbose

    #check if input is defined
    if len(args) < 1:
        print >>sys.stderr, '%s: no input file'%sys.argv[0]
        exit(-1)
    if len(args) > 1:
        print >>sys.stderr, '%s: too many input files'%sys.argv[0]
        exit(-1)
    srcFile=args[0]

    #get a suffix for default output files
    suffix='vbin'
    if opts.outputfmt.lower() =='mif':
        suffix= 'mif'

    #dictionary to hold all streams
    streams={}

    
    #################################
    # parse all streams in file
    #
    parser=Parser(opts.archFile)
    for streamName, result in parser(srcFile).items():
     
        #set names depending on stream name
        reportStreamName    = ' stream "%s"'%(streamName)    if streamName!='' else ''
        inreportStreamName  = ' in stream "%s"'%(streamName) if streamName!='' else ''

        #Error handling and message printing of the parsing
        success, parsed = result
        if success==False:
            if VERBOSE:
                print >>sys.stderr, 'Error while parsing'+reportStreamName
            print >>sys.stderr, parsed
            exit(-1)
     
        if VERBOSE:
            print 'Parsed Text Section'+inreportStreamName+':'
            import json
            print json.dumps(parsed['instructions'], indent=4)
            print 'Parsed Data Section'+inreportStreamName+':'
            print json.dumps(parsed['data'], indent=4)

        #pack for assembling
        streams[streamName]=parsed
    



    #################################
    # assemble all parsed streams 
    #
    assembler=Assembler(opts.archFile)
    for streamName, result in assembler(streams).items():

        #set names depending on stream name
        reportStreamName    = ' stream "%s"'%(streamName)    if streamName!='' else ''
        inreportStreamName  = ' in stream "%s"'%(streamName) if streamName!='' else ''


        #Error handling and message printing of the assembling
        success, asm=result #assembler(parsed['instructions'], parsed['data'])
        if success==False:
            if VERBOSE:
                print >>sys.stderr,'Error while assembling'+reportStreamName
            print >>sys.stderr, asm
            exit(-1)

        #pack the assembled streams for the formatter
        streams[streamName] = asm


    #################################
    # format all streams
    #
    for streamName, asm in streams.items():

        #format the parsed code according to output option
        formatter = Formatter()
        if opts.outputfmt.lower() =='vbin':
            text, data = formatter.verilog(asm)
        elif opts.outputfmt.lower() =='mif':
            text, data = formatter.mif(asm)

        #pack the formated streams for the output generation
        streams[streamName]=(text, data)


    
    #################################
    # write out all streams
    #
    for streamName, result in streams.items():

        #extract text and data sections
        text, data = result

        #generate output names
        outFile             = os.path.join(opts.outDir, '.'.join([streamName,opts.designName,'imem',suffix])) 
        outMemFile          = os.path.join(opts.outDir, '.'.join([streamName,opts.designName,'dmem',suffix])) 

        #write output code
        if text!=None:
            if VERBOSE:
                print 'Writing', outFile
            with open(outFile, 'wt') as f:
                f.write(text)

        #write output data
        if data!=None:
            if VERBOSE:
                print 'Writing', outMemFile
            with open(outMemFile, 'wt') as f:
                f.write(data)
    
    exit(0)
