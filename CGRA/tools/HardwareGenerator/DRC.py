#!/usr/bin/env python

import os
import re
from Config import Config
from collections import Counter

class DRC():

    def __init__(self, fname, buildNW):

        self.config = Config(fname)

        #This class performs the following checks (generation without switchboxes):        
        #(1)		check if all referenced IDs exist
        #(2)		check all FUs are same type on same ID
        #(3)		check that all IDs have controlled FUs
        #(4) 		resolve ID self.configuration bits
        #(5) 		check that the number of connections for PC from ID to ABU are correct (1 for {16,32}-bit and 2 for 8-bit)
        #(6)        check that all referenced program counter sources do exist 
        #(7)		check that input reference is within bounds
        #(8)		check that no input has multiple sources (8-bit PC has to reference 2 inputs for concatenation order)
        #(9)		check that all IDs have the program counter connecton to a FU of type ABU or IU (for ID's with only one instruction)
        
        #(10)		check if there are FUs without inputs (ABU and LSU are allowed to have no inputs)
        #(11)		check all referenced FUs exist for data network
        #(12)		check all inputs and outputs exist
        #(13)		check that each input index has max 1 source (0 is allowed, means unconnected)
        #(14)		check that alu out 0 does not loop back to its own inputs (out.0 is the unbuffered output)
        #(15)		check if there are outputs that are never used
        #(16)		check FU self.configuration bits

        #(17)       if ALU has a carry chain source then check if it exists, if it  is an ALU and that it is not referring to itself.
        # --------------------------------------------------------------------------
        #This class performs the following checks (generation with switchboxes):
        #(A)          
                

        self.config.decoders = {}

        #make a list of all IDs in the design
        for fuName in self.config.functionalUnits:
           if self.config.functionalUnits[fuName]['@type'] in ['ID','IU']:
               self.config.decoders[fuName] = {'controlledUnits': []}
               self.config.decoders[fuName]['type'] = self.config.functionalUnits[fuName]['@type']

        for fuName in self.config.functionalUnits:
            if self.config.functionalUnits[fuName]['@type'] not in ['ID','IU']:                
                #if '@ID' in self.config.functionalUnits[fuName] and buildNW == 1:
                #    raise ValueError("Input file '" + fname + "' seems to contain a description intended for non-switchbox networks")
                    
                if '@Xloc' in self.config.functionalUnits[fuName] and buildNW == 0:
                    raise ValueError("Input file '" + fname + "' seems to contain a description intended for switchbox networks")


        if (buildNW == 0):
            #add all non-IDs to their controlling ID and check for ID existance
            for fuName in self.config.functionalUnits:
               if self.config.functionalUnits[fuName]['@type'] not in ['ID','IU']:
                   if self.config.functionalUnits[fuName]['@ID'] in self.config.functionalUnits: 		#(1)
                       #if the list is not empty...
                       if self.config.decoders[self.config.functionalUnits[fuName]['@ID']]['controlledUnits'] == []:
                           #just add the FU to the list
                           self.config.decoders[self.config.functionalUnits[fuName]['@ID']]['controlledUnits'].append(fuName)
                       else:
                           #otherwise, check if it is of the same type as the first one in the list (2)
                           if self.config.functionalUnits[fuName]['@type'] == self.config.functionalUnits[self.config.decoders[self.config.functionalUnits[fuName]['@ID']]['controlledUnits'][0]]['@type']:
                               self.config.decoders[self.config.functionalUnits[fuName]['@ID']]['controlledUnits'].append(fuName)
                           else:
                              raise ValueError("functional units connected to ID '" + str(self.config.functionalUnits[fuName]['@ID']) + "' are not all of the same type")
                   else:
                       raise ValueError("functional unit '" + fuName +"' refers to undefined decoder: "+str(self.config.functionalUnits[fuName]['@ID']))
        
            observedFUs = []
        
            for decoder in self.config.decoders:
                if self.config.decoders[decoder]['controlledUnits'] != [] or self.config.decoders[decoder]['type'] == 'IU':	 #(3)
        
                    if self.config.decoders[decoder]['type'] != 'IU':
                        #since all units are already verified to be the same we just resolve the first one in the list for its self.configuration bits (4)
                        self.config.decoders[decoder]['configurationBits'] = self.__toBin(self.config.functionalUnits[self.config.decoders[decoder]['controlledUnits'][0]]['control']['@idtype'],int(self.config.functionalUnits[decoder]['reconfiguration']['@bits']))

                    self.config.decoders[decoder]['inputs'] = []

                    if isinstance(self.config.functionalUnits[decoder]['input'], list):
                        for decoderInput in self.config.functionalUnits[decoder]['input']:
                            self.config.decoders[decoder]['inputs'].append(dict({decoderInput['@index']:decoderInput['@source']}))
                    else:
                       self.config.decoders[decoder]['inputs'].append(dict({self.config.functionalUnits[decoder]['input']['@index']:self.config.functionalUnits[decoder]['input']['@source']}))
               
                    datapathWidth = int(self.config['Core']['DataPath']['@width']) #we need the width because for datawidth the program counter connection is a special case
        
                    if datapathWidth != 8: # (5)
                        numAllowedInputs = int(self.config.functionalUnits[decoder]['connections']['@inputs'])
                    else:
                        numAllowedInputs = int(self.config.functionalUnits[decoder]['connections']['@inputs'])+1
        
                    if len(self.config.decoders[decoder]['inputs']) != numAllowedInputs:
                        raise ValueError("decoder '" + decoder +"' has " +str(len(self.config.decoders[decoder]['inputs']))+ " inputs where " + str(numAllowedInputs)+ " is expected")
        
                    for decoderInputs in self.config.decoders[decoder]['inputs']:
                        for inputIndex in decoderInputs:
                            if len(Counter(elem.keys()[0] for elem in self.config.decoders[decoder]['inputs'])) == numAllowedInputs: 	#(8)
                                if re.split(r'\.',decoderInputs[inputIndex])[0] in self.config.functionalUnits:   # (6)
                                    if re.split(r'\.',decoderInputs[inputIndex])[1] < self.config.functionalUnits[re.split(r'\.',decoderInputs[inputIndex])[0]]['connections']['@outputs']:	#(7)						
                                        if self.config.functionalUnits[re.split(r'\.',decoderInputs[inputIndex])[0]]['@type'] not in ['ABU']:
                                            raise ValueError("Program counter source FU type from source '"+decoderInputs[inputIndex]+"' for decoder '" + decoder +"' is not of type ABU")
        
                                        if re.split(r'\.',decoderInputs[inputIndex])[0] not in observedFUs:
                                            observedFUs.append(re.split(r'\.',decoderInputs[inputIndex])[0])
                                    else:
                                        raise ValueError("Program counter source FU output index '" + decoderInputs[inputIndex] + "' for decoder '" + decoder +"' is out of bounds ("+self.config.functionalUnits[re.split(r'\.',decoderInputs[inputIndex])[0]]['connections']['@outputs']+")")
                                else:
                                    raise ValueError("Program counter source FU '" + re.split(r'\.',decoderInputs[inputIndex])[0] + "' for decoder '" + decoder +"' does exist in the design")
                            else:
                                raise ValueError("decoder '" + decoder +"' has multiple sources for input " + str(inputIndex))
                    
                else:
                   raise ValueError("decoder '" + decoder +"' does not control any functional units")
    
            for fuName in self.config.functionalUnits:
                if self.config.functionalUnits[fuName]['@type'] not in ['ID','IU']:
    
                    if 'input' in self.config.functionalUnits[fuName]: #there are some inputs defined (10)
    
                        inputList = self.config.functionalUnits[fuName]['input']
    
                        if not isinstance(inputList,list):
                            inputList = [inputList]
    
                        for FUInput in inputList:
    
                            if re.split(r'\.',FUInput['@source'])[0] not in self.config.functionalUnits: #(11)
                                raise ValueError("input source '"+FUInput['@source']+"' of functional unit '" + fuName +"' refers to a functional unit that does not exist")
            
                            if re.split(r'\.',FUInput['@source'])[1] >= self.config.functionalUnits[re.split(r'\.',FUInput['@source'])[0]]['connections']['@outputs']:	#(12)
                                raise ValueError("input source index '"+FUInput['@source']+"' of functional unit '" + fuName +"' is out of bounds of source outputs (" + str(self.config.functionalUnits[re.split(r'\.',FUInput['@source'])[0]]['connections']['@outputs']) + ")")
            
                            if FUInput['@index'] >= self.config.functionalUnits[fuName]['connections']['@inputs']:	#(12)
                                raise ValueError("input index '"+ FUInput['@index']+"' of functional unit '" + fuName +"' is out of bounds (" + str(self.config.functionalUnits[fuName]['connections']['@inputs']) + ")")
            
                            if self.config.functionalUnits[fuName]['@type'] in ['ALU']:
                                if re.split(r'\.',FUInput['@source'])[0] == fuName: #loops back to itself, not a problem if it is a buffered output ...
                                    if '@config' in self.config.functionalUnits[fuName]:
                                        if int(self.config.functionalUnits[fuName]['@config']) == 0:
                                            if re.split(r'\.',FUInput['@source'])[1] in ['0']: #if it is one of the unbuffered outputs #(14)                                        
                                                raise ValueError("input '"+ FUInput['@index'] +"' of functional unit '" + fuName +"' loops back to itself via an unbuffered output")
                
                            if re.split(r'\.',FUInput['@source'])[0] not in observedFUs:
                                observedFUs.append(re.split(r'\.',FUInput['@source'])[0])
            
                        inputCounts = Counter(elem['@index'] for elem in inputList)
                        for inputIndex in inputCounts:
                            if inputCounts[inputIndex] > 1: #(13)
                                raise ValueError("input '"+ str(inputIndex) +"' of functional unit '" + fuName +"' is has more than one source")
            
                    elif self.config.functionalUnits[fuName]['@type'] not in ['ABU','LSU']: #the ABU can be used without inputs and so can the LSU. Strictly speaking ABU must be in branch mode for no input case
                                                                                       #but it may be a bit overdone to actually start checking the self.configuration bits here.
                        raise ValueError("functional unit '" + fuName +"' does not have any inputs specified")
            
                    if '@self.config' in self.config.functionalUnits[fuName]: #(16)
                        if str(len(self.config.functionalUnits[fuName]['@config'])) != self.config.functionalUnits[fuName]['reconfiguration']['@bits']:
                            raise ValueError("Configuration length ("+str(len(self.config.functionalUnits[fuName]['@config']))+") for functional unit '" + fuName +"' does not match the FU specification ("+self.config.functionalUnits[fuName]['reconfiguration']['@bits']+")")
            
                    if self.config.functionalUnits[fuName]['reconfiguration']['@bits'] != '0': #(16)
                        if '@config' not in self.config.functionalUnits[fuName]:
                            raise ValueError("Configuration expected for functional unit '" + fuName +"' but none given")
                    
            for fuName in self.config.functionalUnits: #(15)
                if self.config.functionalUnits[fuName]['@type'] not in ['ID']:
                    if fuName not in observedFUs: 
                        if self.config.functionalUnits[fuName]['@type'] not in ['LSU']:
                            raise ValueError("All outputs of functional unit '" + fuName +"' are unconnected (the functional unit is never used)")                      
                        else:
                            print "WARNING: All outputs of functional unit '" + fuName +"' are unconnected"

            for fuName in self.config.functionalUnits: #(17)
                if '@carry_source' in self.config.functionalUnits[fuName]:
                    carry_source = self.config.functionalUnits[fuName]['@carry_source']
                    if carry_source in self.config.functionalUnits:
                        if self.config.functionalUnits[carry_source]['@type'] in ['ALU']:
                            if carry_source == fuName:
                                raise ValueError("Referenced carry source '"+carry_source+"' of FU '" + fuName +"' cannot reference to itself")                          
                        else:
                            raise ValueError("Referenced carry source '"+carry_source+"' of FU '" + fuName +"' is not an ALU")                          
                    else:
                        raise ValueError("Referenced carry source '"+carry_source+"' of FU '" + fuName +"' does not exist")                          

        else: #-- for CGRA with switchboxes:    
            for fuName in self.config.functionalUnits:
                if '@Xloc' not in self.config.functionalUnits[fuName] or '@Yloc' not in self.config.functionalUnits[fuName]:
                    raise ValueError("Functional unit '" + fuName +"' is missing a location specifier (Xloc or Yloc)")      

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

if __name__ == "__main__":
    Cfg = DRC("test.xml")         

 

