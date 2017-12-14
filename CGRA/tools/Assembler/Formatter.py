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

from operator import itemgetter
from math import log, ceil
import datetime


#format assembled code into a specific output format
class Formatter():
    def mif(self, asm):
        
        if asm['text']==[]:
            text=None
        else:
            #first get lenghts of various parts
            prog_len            = len(asm['text'])
            prog_len_base_10    = max(3,int(ceil(log(prog_len,10)))+1)
            bit_width           = max([len(entry['bin']) for entry in asm['text']])
            max_instruction     = max([len(entry['sourceLine']) for entry in asm['text']])
            max_comment         = max(max([len(entry['comment']) for entry in asm['text']]), len('comment'))

            column_header='--\t'+'idx'.ljust(prog_len_base_10)+':\t'+'inst'.ljust(bit_width)+'; -- '+'Source Code'.ljust(max_instruction+1)+'\t% '+'Comment'.ljust(max_comment) 


            #generate text section
            text =['-- Generated on '+self.__now()]
            text+=['']
            text+=["WIDTH=%d;"%(bit_width)]
            text+=["DEPTH=%d;"%(prog_len)]
            text+=["ADDRESS_RADIX=UNS;"]
            text+=["DATA_RADIX=BIN;"]

            text+=["CONTENT BEGIN"]
            text+=['-'*len(column_header)]
            text+=[column_header]
            text+=['-'*len(column_header)]
            for idx, entry in enumerate(asm['text']):
                text+= [''.join([
                    '\t', 
                    str(idx).ljust(prog_len_base_10),
                    ':\t',
                    entry['bin'],
                    '; -- ',
                    entry['sourceLine'].ljust(max_instruction+1),
                    '\t% ',
                    entry['comment'],
                    ])]
            text+=["END;\n"]
            
            #convert text to one string
            text='\n'.join(text)

        if asm['data']==[]:
            data=None
        else:
            #generate data section
            bit_width           = max([len(entry['bin']) for entry in asm['data']])
            data_len            = len(asm['data'])
            data_len_base_10    = max(3,int(ceil(log(data_len,10)))+1)
            data_width_base_10  = int(ceil(log(pow(2,bit_width),10)))+1

            data =['-- Generated on '+self.__now()]
            data+=['']
            data+=["WIDTH=%d;"%(bit_width)]
            data+=["DEPTH=%d;"%(data_len)]
            data+=["ADDRESS_RADIX=UNS;"]
            data+=["DATA_RADIX=BIN;"]
            data+=["CONTENT BEGIN"]
            for idx, entry in enumerate(asm['data']):
                data+= [''.join([
                    '\t', 
                    str(idx).ljust(data_len_base_10),
                    ':\t',
                    entry['bin'],
                    '; -- ',
                    '0x'+entry['hex'],
                    '\t',
                    str(int(entry['bin'], 2)).ljust(data_width_base_10),
                    ' '.join([ repr(chr(int(entry['bin'][i:i+8],2))) for i in range(0, len(entry['bin']), 8)]),
                    ])]
            data+=["END;\n"]

            #convert text to one string
            data='\n'.join(data)

        return (text, data)

    def __now(self):
        return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def __fmt(self, fmt, text):
        return '\n'.join([fmt%dict(entry.items() + {'idx':str(idx).ljust(4, ' ')}.items()) for idx, entry in enumerate(text)])

    def verilog(self, asm):
        
        if asm['text']==[]:
            text=None
        else:
            #first get lenghts of various parts
            bit_width           = max([len(entry['bin']) for entry in asm['text']])
            max_instruction     = max([len(entry['sourceLine']) for entry in asm['text']])
            max_comment         = max(max([len(entry['comment']) for entry in asm['text']]), len('comment'))

            column_header='//inst'.ljust(bit_width)+'\t// '+'Source Code'.ljust(max_instruction+1)+'\t% '+'Comment'.ljust(max_comment) 


            #generate text section
            text =['// Generated on '+self.__now()]
            text+=['']

            text+=['/'*(len(column_header)+2)]
            text+=[column_header]
            text+=['/'*(len(column_header)+2)]
            text+=["@0"]
            for entry in asm['text']:
                text+= [''.join([
                    entry['bin'],
                    '\t// ',
                    entry['sourceLine'].ljust(max_instruction+1),
                    '\t% ',
                    entry['comment'],
                    ])]
            
            #convert text to one string
            text='\n'.join(text)


        #generate data section
        if asm['data']==[]:
            data=None
        else:
            bit_width           = max([len(entry['bin']) for entry in asm['data']])
            data_len            = len(asm['data'])
            data_len_base_10    = max(3,int(ceil(log(data_len,10)))+1)
            data_width_base_10  = int(ceil(log(pow(2,bit_width),10)))+1

            data =['// Generated on '+self.__now()]
            data+=['']
            data+=['@0']
            for entry in asm['data']:
                data+= [''.join([
                    entry['bin'],
                    ' // ',
                    '0x'+entry['hex'],
                    '\t',
                    str(int(entry['bin'], 2)).ljust(data_width_base_10),
                    ' '.join([ repr(chr(int(entry['bin'][i:i+8],2))) for i in range(0, len(entry['bin']), 8)]),
                    ])]

            #convert text to one string
            data='\n'.join(data)
 

        return (text, data)
