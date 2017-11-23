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

class Assembler():
    def __init__(self, archFile):
        from Config import Config
        self.Cfg = Config(archFile)    
        self.labelList={}    


    def __resolveImmediate(self, s):
       #try to make a number out of string
        try:   
            n=str(s).strip().lower()
            if n[0:2]=='0b':
                return int(n, 2)
            if n[0:2]=='0x':
                return int(n,16)
            else:
                return int(n)
        except:
            return None
        
    def __resolveLabel(self, s, lineNumber=0):
        #try to resolve label
        try:
            if s[0]=='$':
                #we are dealing with a label.
                
                #see if it has an abs or relative extension:
                if len(s.split('.'))==1:
                    #no extention
                    return self.labelList[s]

                #possibly an extention (could also be a label with a dot in it)
                label='.'.join(s.split('.')[:-1])
                ext=s.split('.')[-1]

                if ext=='rel':
                    return (self.labelList[label]-lineNumber-int(self.Cfg['Core']['Branchslots']['@slots']))

                elif ext=='abs':
                    return self.labelList[label]

                #no extension
                return self.labelList[s]
                

        except:
            return None

    def __resolveMnemonic(self, instrType, mnemonic):
        try: 
            return self.Cfg.instructions[instrType][mnemonic]['@opcode']
        except:
            return None

    def __resolveDataType(self, s):
       #try to make a number out of string
        datatype=str(s).strip()
        if datatype=='BYTE':
            return 0
        if datatype=='HWORD':
            return 1
        if datatype=='WORD':
            return 2                
        if datatype=='DWORD':
            return 3                
        else:
            return None

    def __resolveSignType(self, s):
       #try to make a number out of string
        signtype=str(s).strip()   
        if signtype=='BYTE':
            return 6
        if signtype=='HWORD':
            return 2
        if signtype=='WORD':
            return 5                
        else:
            return None            


    def __toBin(self, value, bits=32):
        fmt="{0:0"+str(bits)+"b}"

        if value<0:
            value=(value*-1)-1
            s=fmt.format(int(value))
            s=s.replace('0','t')
            s=s.replace('1','0')
            s=s.replace('t','1')
            return s

        return fmt.format(int(value))

    def __toHex(self, value, bits=32):
        from math import ceil
        fmt="{0:0"+str(int(ceil(bits/4)))+"X}"
        return fmt.format(int(value)& (pow(2,bits)-1))


    def __extractLabels(self, instructionList):
        pureInstructions=[]
        instructionCounter=0
        for instructionInfo in instructionList:
            instruction = instructionInfo['instruction']
            if instruction['type']=='label':
               self.labelList[instruction["target"]]=instructionCounter
            else:
                pureInstructions+=[instructionInfo]
                instructionCounter+=1
        return pureInstructions

    def assembleText(self, instructionList):
        output=[]
        
        minBinLength=9999
        maxBinLength=0

        #extract labels from list
        instructionList=self.__extractLabels(instructionList)

        for instructionIdx, instructionInfo in enumerate(instructionList):
            instruction = instructionInfo['instruction']
            
            #for error reporting
            sourceLineNumber=instructionInfo['sourceLineNumber']
            sourceLine = instructionInfo['sourceLine']

            binStr=''
            instrType=instruction['type']
            totalWidth=0
            for fieldName, field in self.Cfg['ISA']['instructiontypes'][instrType].items():
                if fieldName[0]=='@':
                    continue #this is an attribute in the config, not a sub-field
                fieldType=field["@type"]
                if fieldType!='unused':
                    fieldValue=instruction[fieldName]

                #find out with of field (can be overriden in instructiontypes section)
                width=int(self.Cfg['ISA']['instructionFieldTypes'][fieldType]['@width'])
                if '@width' in field:
                    width=int(field['@width'])
                totalWidth+=width

                #special opcode field
                if fieldType=='mnemonic':
                    opcode=self.__resolveMnemonic(instrType, fieldValue)
                    if opcode==None:
                        return  (False, "Encountered illegal mnemonic on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"" )
                    binStr+=self.__toBin(opcode, width)

                elif fieldType=='unused':
                    binStr+=self.__toBin(0, width)

                elif fieldType.startswith('immediate'):
                    if fieldValue.startswith('$'):
                        #secretly a label
                        label=self.__resolveLabel(fieldValue, instructionIdx)
                        if label==None:
                            return (False, "Could not resolve label "+str(fieldValue)+" on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                        binStr+=self.__toBin(label, width)
                    else:
                        #actual immediate value
                        imm=self.__resolveImmediate(fieldValue)
                        if imm==None:
                            return (False, "Could not resolve immediate on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                        binStr+=self.__toBin(imm, width)
			if len(self.__toBin(imm, width)) >  width:
				return (False, "Illegal immediate value on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                elif fieldType.startswith('datatype'):
                    dataType=self.__resolveDataType(fieldValue)
                    if dataType==None:
                        return (False, "Could not resolve data type on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                    binStr+=self.__toBin(dataType, width)
                elif fieldType.startswith('signtype'):
                    dataType=self.__resolveSignType(fieldValue)
                    if dataType==None:
                        return (False, "Could not resolve sign extention type on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                    binStr=self.__toBin(dataType, width) +binStr #this one is concatenated to the head instead of the tail!!
                else:
                    #unknown field, try to generate a value
                    try:
                        binStr+=self.__toBin(fieldValue, width)
			if len(self.__toBin(fieldValue, width)) > width:
				 return (False, "Illegal argument value on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                    except:
                        return (False, "Could not generate a value from field "+str(fieldType)+" on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")


            #update instruction info with the assembled binary and hex strings
            instructionInfo.update({
                'bin':                  binStr, #binary string
                'hex':                  self.__toHex(int(binStr,2), totalWidth), #hex string
                'int':                  int(binStr,2), #integer value of the instruction
            })

            if len(instructionInfo['bin']) > maxBinLength:
                maxBinLength = len(instructionInfo['bin'])

            if len(instructionInfo['bin']) < minBinLength:
                minBinLength = len(instructionInfo['bin'])

            output+=[instructionInfo]

        if minBinLength != maxBinLength:
            return (False, "Mixed instruction lengths in single column, did you use 'nop' instead of 'nopi' or vice versa?")            
        
        return (True, output)

    def __chunks(self, l, n):
        #Yield successive n-sized chunks from l.
        for i in xrange(0, len(l), n):
            yield l[i:i+n]

    def assembleData(self, dataEntries):
        memory=[]

        dataPathWidth= int(self.Cfg['Core']['DataPath']['@width'])
        for entryInfo in dataEntries:
            entry=entryInfo['data']
            sourceLineNumber=entryInfo['sourceLineNumber']
            sourceLine=entryInfo['sourceLine']

            dataType=entry['dataType']
            width = int(self.Cfg['DataTypes'][dataType]['@width'])
            
            if width>dataPathWidth:
                for e in entry['elements']:
                    value = self.__resolveImmediate(e)
                    if value==None:
                        return (False, "Encountered invalid data element \""+str(e)+"\" on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                    binStr = self.__toBin(e,width)
                    hexEntry=[] 
                    for el in self.__chunks(binStr, dataPathWidth):
                        #sanity check on values if larger than biggest unsigned, or smaller than most megative signed
                        if (int(el,2)>pow(2,width)-1) or (int(el,2)<-1*pow(2,width-1)):
                            return (False, "Encountered data element \""+str(el)+"\" which does not fit in type \""+str(dataType)+"\" of width \""+str(width)+"\" on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                        hexEntry+=[self.__toHex(int(el,2), dataPathWidth) ]
    
                    memory+=hexEntry

            else:
                elementsPerMemLine=int(dataPathWidth/width)
                for memLine in self.__chunks(entry['elements'], elementsPerMemLine):
                    #reverse and zero pad memline
                    memLine=[0]*(elementsPerMemLine-len(memLine))+memLine[::-1]

                    intMemLine=[]
                    for e in memLine:
                        value = self.__resolveImmediate(e) 
                        if value==None:
                            return (False, "Encountered invalid data element \""+str(e)+"\" on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                        intMemLine+=[value]

                    hexEntry=[]
                    for e in intMemLine:
                        #sanity check on values if larger than biggest unsigned, or smaller than most megative signed
                        if (int(e)>pow(2,width)-1) or (int(e)<-1*pow(2,width-1)):
                            return (False, "Encountered data element \""+str(e)+"\" which does not fit in type \""+str(dataType)+"\" of width \""+str(width)+"\" on line "+str(sourceLineNumber)+": \""+str(sourceLine)+"\"")
                        hexEntry+=[ self.__toHex(e,width)]

                    memory+=[''.join(hexEntry)]

        mem=[]
        for entry in memory:
            mem+=[{
                'hex':entry,
                'bin':self.__toBin(int(entry,16), dataPathWidth),
            }]

        return (True, mem)


    def assemble(self, textSection, dataSection, CLEAR_LABEL_LIST=True):
        if CLEAR_LABEL_LIST:
            #clear the labelList, for new jobs this is required. stream parsing disabled this
            self.labelList={}

        success, text=self.assembleText(textSection)
        if not success:
            return (False, text)

        success, data=self.assembleData(dataSection)
        if not success:
            return (False, data)

        return (True, {'text':text, 'data':data} )

    def assembleStreams(self, streams):
        #clear the labelList
        self.labelList={}

        #first step is to extract all the labels! (from all streams, as we need to combine them)
        for streamName, parsed in streams.items():
            streams[streamName]['instructions']=self.__extractLabels(parsed['instructions'])

        #after the label extraction, we can assemble this thing
        assembled={}
        for streamName, parsed in streams.items():
            assembled[streamName]=self.assemble(parsed['instructions'], parsed['data'], False)

        return assembled

    #override the call function
    def __call__(self, streams):
        return self.assembleStreams(streams)
