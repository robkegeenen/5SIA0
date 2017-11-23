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

import re
class Parser():
    def __init__(self, archFile):
        from Config import Config
        self.Cfg = Config(archFile)        

        #build regex for data entries
        types='|'.join(self.Cfg['DataTypes'].keys())
        self.dataEntryRegex=re.compile("^\s*([^\s:]+)\s*:\s+\.("+types+")\s+((\s*[^\s,]+\s*,)*\s*[^\s,]+)\s*$")


        #regex of valid operations per instructiontype
        operationsPerType={}
        for instructionTypeName, instructionList in self.Cfg.instructions.items():
            operationsPerType[instructionTypeName]="|".join([ instDesciption['@mnemonic'] for _, instDesciption in instructionList.items()])
               
        #construct list of regex for each instructionType
        self.instructionRegexes={}
        for instructionTypeName, instructionType in self.Cfg['ISA']['instructiontypes'].items():
            self.instructionRegexes[instructionTypeName]=[]
            for fieldName, field in instructionType.items():
                if fieldName[0]=='@':
                    continue #this is an attribute, not a sub_field in the xml config

                fieldTypeName=field['@type']
                fieldType=self.Cfg['ISA']['instructionFieldTypes'][fieldTypeName]

                #opcode is a special field, allowed values are constructed from the instruction names of the various classes
                if fieldTypeName=="mnemonic":
                    self.instructionRegexes[instructionTypeName]+=[('mnemonic', "("+operationsPerType[instructionTypeName]+")", "("+fieldType["@separator"]+"|$)")]

                #the 'unused' field is not for the parser, skip it
                elif fieldTypeName=="unused":
                    continue

                #add the regex to the list
                else:
                    if '@regex' not in fieldType:
                        raise ValueError('instructionFieldTypes '+fieldTypeName+' does not specify a regex')
                    self.instructionRegexes[instructionTypeName]+=[(fieldName, fieldType['@regex'], "("+fieldType["@separator"]+"|$)")]

            #remove trailing separator from last field in instruction
            lastRegex=self.instructionRegexes[instructionTypeName][-1]
            self.instructionRegexes[instructionTypeName][-1]=(lastRegex[0],lastRegex[1],"$")

        #add regex for label
        self.label_token = '(\$[^\s;:]+)'
        self.instructionRegexes['label']=[('target',self.label_token, ""), (None, '(:)', "$") ]

    def __generateErrorMsg(self, msg, got, expected, idx, lineLenLimit=20):
        expected = expected.strip()
        if expected=='':
            expected="end of line"

        #get rid of spaces in source line
        trim_got=got.lstrip()
        leading_spaces=(len(got)-len(trim_got))
        idx=idx-leading_spaces
        trim_got=trim_got.strip()

        #zoom in on a piece of lineLenLimit, centred around idx
        start=0
        end=len(trim_got)
        if len(trim_got)>lineLenLimit:
            postIdx=len(trim_got)-idx

            #not enough characters post Idx to center around Idx, clip whats needed from front
            if postIdx<(lineLenLimit/2):
                start=len(trim_got)-lineLenLimit
                end=len(trim_got)
                idx-=start

            #not enough characters pre Idx to center around Idx, clip whats needed from back
            elif idx<(lineLenLimit/2):
                start=0
                end=lineLenLimit
            
            #plenty of space on both sides
            else:
                start=idx-(lineLenLimit/2)
                end=idx+(lineLenLimit/2)
                idx-=start

        trim_got=trim_got[start:end]

        err_preamble="%(msg)s, got: \""%locals()
        err=err_preamble+"%(trim_got)s\" expected \"%(expected)s\"\n"%locals()

        
        err+='-'*(len(err_preamble)+idx)+'^'

        return err

    #parse a command from the given line
    def __parseCmd(self, line, fullLine=None, columnOffset=0):
        
        #used for error reporting
        if fullLine==None:
            fullLine=line

        commented_line=line

        #remove comments
        line, comment=self.__removeComments(line)
        
        #check for empty line
        if line.strip()=='':
            return (True, [])

        #test different instruction types
        isValid={}
        validCnt=0
        bestColumnIndex=0 #to keep track of which possibly type matches best
        for instrType, regexes in self.instructionRegexes.items():
            #start with invalid assumption
            isValid[instrType]=False

            #set index to 0
            columnIdx=0

            #for all tokens in this instruction type
            typeMatches=True
            parsedValues={'type':instrType}
            for fieldName, token,separator  in regexes:
                
                #check for next expected token
                if re.match("^\s*"+token+"\s*", line[columnIdx:]):
                    
                    #extract token value
                    m=re.match("^\s*"+token, line[columnIdx:])
                    if fieldName!=None:
                        parsedValues[fieldName]=m.group(1).strip()
                    columnIdx+=len(m.group(0))

                    #find and remove separator
                    m=re.match('^\s*'+separator, line[columnIdx:])
                    if m:
                        columnIdx+=len(m.group(0))
                    else:
                        #did not find separator, that's a fail
                        m=re.match('^\s*', line[columnIdx:])
                        columnIdx+=len(m.group(0))
                        if columnIdx>=bestColumnIndex:
                            bestColumnIndex=columnIdx 
                            err=self.__generateErrorMsg("unexpected Token", fullLine, separator[1:-3], columnIdx+columnOffset)
                        typeMatches=False
                        break
                
                #could not find expected token 
                else:
                    if columnIdx>=bestColumnIndex:
                        bestColumnIndex=columnIdx
                        err=self.__generateErrorMsg("unexpected Token", fullLine, token, columnIdx+columnOffset)
                    typeMatches=False
                    break
            
            if typeMatches:
                #check if line is consumed all the way, otherwise this is not a match!
                if line[columnIdx:].strip()=='':
                    isValid[instrType]=parsedValues
                    validCnt+=1
                else:
                    #there was trailing junk
                    if columnIdx>=bestColumnIndex:
                        bestColumnIndex=columnIdx
                        err=self.__generateErrorMsg("unexpected Token", fullLine, token, columnIdx+columnOffset)
                    
        #if more than 1 valid, we have a problem
        if validCnt>1:
            err="Multiple instruction types matched to line: "+commented_line.rstrip()+"\n"
            err+="Possible matches are :"+', '.join([Type for Type, val in isValid.items() if val!=False])
            return (False, (err, bestColumnIndex+1))

        #if less than 1 valid, no match
        if validCnt<1:
            return (False, (err, bestColumnIndex+1))

        #return the results  
        for Type, parsedVals in isValid.items():
            if parsedVals !=False:     
                return (True, parsedVals)

        #this should not be possible
        return (False, 'logic error')


    def __removeComments(self, line):
        return line.split(';')[0].rstrip(), (';'.join(line.split(';')[1:])).strip() if len(line.split(';'))>1 else ''

    def __parseDataEntry(self, line):
         #remove comments
        line, comment=self.__removeComments(line)

        #check if line is empty
        if line.strip()=='':
            return (True, None)

        #try to match regex to this line
        m=re.match(self.dataEntryRegex, line)
        if m==None:
            return (False, "Malformed data entry: \""+str(line)+"\"")

        name,dtype,args,_ =  m.groups()
        return (True, {
            'name':name,
            'dataType':dtype,
            'elements': [a.strip() for a in args.strip().split(',')],
        })


    def parse(self, lines, lineNumberOffset=0, codeName=''):
        #regular parse, i.e., the are not a tuple with a column offset and original line, therefore we add them here:
        lines=[ (line, 0, line)  for line in lines]

        #return as dictionary for compatibility with parallel parse
        return {codeName:self.__parseColumnOffset(lines, lineNumberOffset=lineNumberOffset)}

    def __parseColumnOffset(self, lines, lineNumberOffset=0):
        parsedCmds=[]
        parsedDataEntries=[]
        lineNumber=lineNumberOffset
        
        section=None
        for line, columnOffset, fullLine in lines:
            lineNumber+=1
            
            #remove comments
            line, comment = self.__removeComments(line)

            if line=='':
                continue
            
            #test for new section
            if line.strip()[0]=='.':
                section=line.strip()
                if section not in [".data", ".text"]:
                    return (False, "Encountered unknown section on line "+str(lineNumber-1)+": \""+section+"\"")
                continue
            
            if section==None: 
                return (False, "Encountered line outside section on line "+str(lineNumber)+": \""+line+"\"") #do not need to report fullLine here

            elif section==".data":
                success, entry = self.__parseDataEntry(line)
                if success and entry!=None:
                    parsedDataEntries+=[{'data':entry, 'sourceLineNumber':lineNumber, 'sourceLine':line}]
                if not success:
                    err= "Error on line "+str(lineNumber)+"\n"
                    err+= entry
                    return (False, err)

            elif section==".text":
                success, result = self.__parseCmd(line, fullLine=fullLine, columnOffset=columnOffset)
                if not success:
                    err= "Error on line "+str(lineNumber)+" column "+str(result[1]+columnOffset)+"\n"
                    err+=result[0]
                    return (False, err)

                #if result is [], then it was an empty (or comment only), line
                #in that case ignore it
                if result!=[]:
                    parsedCmds+=[{'instruction':result, 'sourceLineNumber':lineNumber, 'sourceLine':line, 'comment':comment }]
            
            else:
                return (False, "How did you get here?")


        return (True, {'instructions':parsedCmds, 'data':parsedDataEntries})

    def parseSingleFile(self, fname):
        with open(fname,'rt') as f:
            return self.parse(f.readlines(), codeName=fname)

    def parseFile(self, fname):
        with open(str(fname),'rt') as f:
            lines=f.readlines()

        #detect if parallel file based on file extention, or single stream
        if fname.endswith('pasm'):
            return self.parseParallel(lines)
        else:
            return self.parse(lines)
    

    def parseParallel(self, lines):
        
        #first do some proprocessing:
        # - check each line starts and ends with |, 
        # - blank ------ lines
        # - split into columns and insert nops where needed
        pre_processed_lines=[]
        active_section=None
        columnType={}
        for lineNumber, line in enumerate(lines):
                        
            #ignore empty lines
            if self.__removeComments(line)[0].strip()=='':
                pre_processed_lines.append((None, 0)) #special code empty line (as we don't know in how many columns we need to split this empty line yet)
                continue

            #strip line, but remember by how much for correct error reporting
            leadingWhitespace=len(line) - len(line.lstrip())
            trailingWhitespace=len(line) - len(line.rstrip())
            sline=line.strip()

            #check if line starts and ends with '|'
            if sline[0]!='|':
                colIdx=leadingWhitespace
                err = "Error on line "+str(lineNumber+1)+" column "+str(colIdx+1)+"\n"
                err+= self.__generateErrorMsg('Syntax Error', line, '|', colIdx)
                return (False, err)
            if sline[-1]!='|':
                colIdx=len(line)-trailingWhitespace-1
                err = "Error on line "+str(lineNumber+1)+" column "+str(colIdx+1)+"\n"
                err+= self.__generateErrorMsg('Syntax Error', line, '|', colIdx)
                return {'': (False, err)}

            #split into columns
            tsline  = sline[1:-1]
            columns = tsline.split('|')
            scolumns= [self.__removeComments(c)[0].strip() for c in columns]
           
            #if ALL(!) columns are all empty, we can skip this line
            if scolumns==['']*len(scolumns):
                empty_line=[]
                offset=leadingWhitespace+1 #+1 for first '|'
                for segment in tsline.split('|'):
                    empty_line.append((segment, offset))
                    offset+=len(segment)+1 #+1 for the splitter | that was removed
                pre_processed_lines.append(empty_line)
                continue

            #if ALL(!) columns are dashes (----), we can also skip it
            if sum([0 if scol=='-'*len(scol) else 1 for scol in scolumns])==0:
                empty_line=[]
                offset=leadingWhitespace+1 #+1 for first '|'
                for segment in tsline.split('|'):
                    empty_line.append((segment.replace('-',' '), offset))
                    offset+=len(segment)+1 #+1 for the splitter | that was removed
                pre_processed_lines.append(empty_line)
                continue



            #################################################################################################
            # Because the immediate unit has a different instruction width, we need to distinguish between 
            # regular columns and immediate columns when nops are inserted. 
            # To distinguish we use the .itext/.idata sections.
            # Here, we filter the .itext and .idata out and replace them with regular .text and .data
            # But of course not without making a note these columns are 'immediate' types
            # In principle it is allowed to change the type of the column along the way

            #set to regular column type if regular text or data section is encountered
            for idx, scol in enumerate(scolumns):
                if scol in ['.text', '.data']:
                    columnType[idx]='regular'

            #scan for an 'itext/idata attribute'
            #this indicates this is an immediate unit column, which is used in the auto insertion of nop/nopi
            for idx, scol in enumerate(scolumns):
                if scol in ['.itext', '.idata']:
                    columns[idx]=scol[0]+scol[2:] #remove the 'i', and annotate this collumn as being i-type
                    scolumns[idx]=columns[idx]
                    columnType[idx]='immediate'




            #.data and .text sections are only allowed alligned, enforce this here
            sectionChange=None
            for scol in scolumns:
                if scol in ['.data', '.text']:
                    sectionChange=scol
                    break
            if sectionChange:
                for idx, scol in enumerate(scolumns):
                    if scol != sectionChange:
                        err_idx= sum([ len(c) for c in columns[:idx]])+2+leadingWhitespace+idx
                        err = "Error on line "+str(lineNumber+1)+" column "+str(err_idx+1)+"\n"
                        err+= self.__generateErrorMsg(sectionChange+' sections must be alligned!', line, sectionChange, err_idx)
                        return {'': (False, err)}
                
                #update the active section
                active_section=sectionChange


            #now we do pre-processing, insert nops where needed, and check labeled lines do not contain code
            if active_section=='.text':
                
                #detect if there is a label in this row:
                labelInCol=None
                for idx, scol in enumerate(scolumns):
                    if re.match("^\s*"+self.label_token+"\s*", scol):
                        labelInCol=idx
                        break

                if labelInCol==None:
                    #no labels in this row, auto insert a nop when there is an empty column
                    for idx, scol in enumerate(scolumns):
                        if scol=='':
                            if columnType[idx]=='regular':
                                columns[idx]=('nop ;auto inserted nop', len(columns[idx]))
                            elif columnType[idx]=='immediate':
                                columns[idx]=('nopi ;auto inserted nopi', len(columns[idx]))
                            else:
                                print 'Unrecognized column type!'
                else:
                    #there is a label in this column, return error if there is any other text
                    for idx, scol in enumerate(scolumns):
                        if idx!=labelInCol and scol!='':
                            err_idx= sum([ len(c) for c in columns[:idx]])+2+leadingWhitespace+idx
                            err = "Error on line "+str(lineNumber+1)+" column "+str(err_idx+1)+"\n"
                            err+= self.__generateErrorMsg('No code allowed in labeled rows', line, '|', err_idx)
                            return {'': (False, err)}

            #add to pre_processed_lines
            new_line=[]
            offset=leadingWhitespace+1 #+1 for first '|'
            for c in columns:
                
                if isinstance(c, tuple):
                    #if c is a tuple, it was replaced by a nop(i) in the previous section
                    #therefore we need to add the old size of c to the offset (second part of the tuple)
                    c, lenc = c
                else:
                    lenc=len(c)
                
                new_line.append((c, offset))
                offset+=lenc+1 #+1 for the splitter | that was removed
            pre_processed_lines.append(new_line)

        


        #now lets parse the header
        headerIdx=None
        for idx, line in  enumerate(pre_processed_lines):
            if [ segment for segment, offset in line]!=['']*len(line):
                #we found the header!
                headerIdx=idx
                break
        if headerIdx==None:
            return {'':(False, 'Unable to find a header')}
        
        #split into header section and code lines
        header      =[name for name, offset in pre_processed_lines[headerIdx]]
        code_lines  =pre_processed_lines[headerIdx+1:]

        #replace empty lines with empty lines per column
        code_lines=[ [('', 0)]*len(header) if line[0]==None else line for line in code_lines]
        #check if each code line has to correct number of columns:
        for idx, line in enumerate(code_lines):
            if len(line)<len(header):
                return {'':(False, 'Not enough columns on Line '+str(headerIdx+idx))}
            if len(line)>len(header):
                return {'':(False, 'Too many columns on Line '+str(headerIdx+idx))}


        #time to get code for each column and generate separated files
        code={}
        for columnIdx, cname in enumerate(header):
            name = cname.strip()
            code[name]= [ (line[columnIdx][0], line[columnIdx][1], lines[lineIdx+headerIdx+1]) for lineIdx, line in enumerate(code_lines)]

        #finally do the actual parsing!
        parsed={}
        for cname in code:
            parsed[cname]=self.__parseColumnOffset(code[cname])

        return parsed

    def parseParallelFile(self, fname):
        with open(fname,'rt') as f:
            return self.parseParallel(f.readlines())

    def __call__(self, fname):
        return self.parseFile(fname)

if __name__ == "__main__":
    p=Parser("ArchitectureConfiguration.xml")
