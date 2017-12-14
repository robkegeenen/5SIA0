#!/usr/bin/env python

import os
import re
import glob
from DRC import DRC
from network_gen import network_gen
from collections import Counter
import collections
import xmltodict
from pprint import pprint
import shutil
from Templating import TemplateDB
import math

class Instantiate():
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

    def exportDot(self, fname):
        #print outDir + "/" + fname
        f = open(fname,'w')
        f.write("digraph G {nodesep=1\n\t{\n")
        #nodes here
        f.write('\tnode [shape="square" style="filled" fixedsize=true]\n')

        IDnames = ''
        ABUnames = ''
        for decoder in self.drc.config.decoders:
            IDnames = IDnames + " " + decoder
            if self.drc.config.decoders[decoder]['type'] == 'ID':
                f.write('\t' + decoder + ' [label="'+decoder+'" fillcolor="darkgreen" width=1]\n')
            else:
                f.write('\t' + decoder + ' [label="'+decoder+'" fillcolor="green" width=1]\n')

        f.write('\t{rank=same;' + IDnames + '}\n')

        for fuName in self.drc.config.functionalUnits:
            ColorTable = {'ALU':'lightblue','LSU':'red','RF':'yellow','ABU':'violet','MUL':'blue'}

            if self.drc.config.functionalUnits[fuName]['@type'] in ['ABU']:
                ABUnames = ABUnames + " " + fuName

            if self.drc.config.functionalUnits[fuName]['@type'] not in ['ID','IU']:
                f.write('\t' + fuName + ' [label="'+fuName+'" fillcolor="' + ColorTable[self.drc.config.functionalUnits[fuName]['@type']] +'" width=1]\n')

        f.write('\t{rank=source;' + ABUnames + '}\n')
        f.write("\t}\n")
        f.write("\tedge [dir=forward labeldistance=2 arrowhead=normal]\n")
        #edges here
        for decoder in self.drc.config.decoders:
            for fu in self.drc.config.decoders[decoder]['controlledUnits']:
                f.write('\t' + decoder + ' -> ' + fu + ' [color=darkgreen dir=forward]\n')

            for PCinput in self.drc.config.decoders[decoder]['inputs']:
                for inputIndex in PCinput:
                    sourcename = re.split(r'\.',PCinput[inputIndex])[0]
                    sourceindex = re.split(r'\.',PCinput[inputIndex])[1]
                    f.write('\t' + sourcename + ' -> ' + decoder + ' [color=red dir=forward arrowhead=normal headlabel=in' + inputIndex + ' taillabel=out' + sourceindex + ']\n')

        for fuName in self.drc.config.functionalUnits:
            if self.drc.config.functionalUnits[fuName]['@type'] not in ['ID','IU']:
                 if 'input' in self.drc.config.functionalUnits[fuName]:
                     inputList = self.drc.config.functionalUnits[fuName]['input']

                     if not isinstance(inputList,list):
                         inputList = [inputList]

                     for FUinputs in inputList:
                         sourcename = re.split(r'\.',FUinputs['@source'])[0]
                         sourceindex = re.split(r'\.',FUinputs['@source'])[1]
                         f.write('\t' + sourcename + ' -> ' + fuName + ' [color=blue dir=forward arrowhead=normal headlabel=in' + FUinputs['@index'] + ' taillabel=out' + sourceindex + ']\n')

        for fuName in self.drc.config.functionalUnits:
            if '@carry_source' in self.drc.config.functionalUnits[fuName]:
                carry_source = self.drc.config.functionalUnits[fuName]['@carry_source']
                f.write('\t' + carry_source + ' -> ' + fuName + ' [color=darkgray dir=forward arrowhead=normal headlabel=c_in taillabel=c_out style=dotted]\n')

        f.write("}\n")
        f.close()

    def __getPathWidths(self):
        instructionWidths = []
        immediateWidths = []

        for instructionType in self.drc.config['ISA']['instructiontypes']:
            width = 0
            isImmediate = 0
            for fieldName, field in self.drc.config['ISA']['instructiontypes'][instructionType].items():
                if fieldName[0] != '@':
                    isImmediate = field['@type'] == 'immediate'

                    if '@width' in field:
                        width += int(field['@width'])
                    else:
                        width += int(self.drc.config['ISA']['instructionFieldTypes'][field['@type']]['@width'])
            if not isImmediate:
                instructionWidths.append(width)
            else:
                immediateWidths.append(width)

        self.instructionWidth = min(instructionWidths)
        self.immediateWidth = max(immediateWidths)
        self.dataWidth = int(self.drc.config['Core']['DataPath']['@width'])

    def __connectionString(self,connectionName, indexList):
        connectionString = ''
        for index in indexList:
            if connectionString == '':
                connectionString = connectionName + '[' + str(index) + ']' + connectionString
            else:
                connectionString = connectionName + '[' + str(index) + '], ' + connectionString
        return connectionString

    def __instantiateMemory(self,functionalUnit, prefix, index, width, init, writeIndexing,memoryType,postfix,offset, templates, templateName, memtype):
        memTemplate = templates[templateName + '_inst']

        memTemplate = memTemplate.replace("<<MEM_TYPE>>",memtype)
        memTemplate = memTemplate.replace("<<D_WIDTH>>",str(width))
        memTemplate = memTemplate.replace("<<MEM_ADDR_WIDTH>>",prefix+'MEM_ADDR_WIDTH')
        memTemplate = memTemplate.replace("<<MEM_FILE>>",'"' + functionalUnit + '.' + self.designName + '.'+memoryType+'.vbin"' if int(init) != 0 else '""')
        memTemplate = memTemplate.replace("<<DO_INIT>>",str(init))
        memTemplate = memTemplate.replace("<<MEM_WD>>",'w'+prefix+'WriteData' + postfix + ('[' + str(index) + ']' if writeIndexing else ''))
        memTemplate = memTemplate.replace("<<MEM_RA>>",'w'+prefix+'ReadAddress[' + str(index) + offset + ']['+prefix+'MEM_ADDR_WIDTH-1:0]')
        memTemplate = memTemplate.replace("<<MEM_WA>>",'w'+prefix+'WriteAddress' + ('[' + str(index) + ']['+prefix+'MEM_ADDR_WIDTH-1:0]' if writeIndexing else '['+prefix+'MEM_ADDR_WIDTH-1:0]'))
        memTemplate = memTemplate.replace("<<MEM_WE>>",'w'+prefix+'WriteEnable[' + str(index) + offset + ']')
        memTemplate = memTemplate.replace("<<MEM_RE>>",'w'+prefix+'ReadEnable[' + str(index) + offset + ']')
        memTemplate = memTemplate.replace("<<MEM_RD>>",'w'+prefix+'ReadData'+postfix+'[' + str(index) + ']')
        memTemplate = memTemplate.replace("<<UNIT_NAME>>",prefix + functionalUnit)

        return memTemplate


    def __exportComputeVerilog(self, outputFile, outputFileWrapper, templates, outDir, buildNW, configOut=None):
        if configOut==None:
            configOut=outDir + "/instance_info.xml"

        #get template data
        filedata = templates['compute']
        filedataWrapper = templates['compute_wrapper']

        #WORK IN PROFRESS Generating core peripherals
        if 'Peripherals' in self.drc.config['Core']:
            peripherals = self.drc.config['Core']['Peripherals']
        else:
            peripherals = []

        peripheralTypes = self.drc.config['PeripheralTypes']

        if 'Peripherals' in self.drc.config['Core']:
            if not isinstance(peripherals['Peripheral'],list):
                if '@level' in peripherals['Peripheral'] and peripherals['Peripheral']['@level'] == 'core':
                    peripheralList = [peripherals['Peripheral']]
                else:
                    peripheralList = []
            else:
                peripheralList = filter(lambda peripheralsl: ('@level' in peripheralsl and peripheralsl['@level'] == 'core'), peripherals['Peripheral'])
        else:
            peripheralList = []


        addressRanges = []

        #looking for highest end address of port 0 for general arbiter, start addr will always be 0
        endAddressNonCore = []

        #GM address range
        endAddressNonCore.append(int(self.drc.config['Core']['Memory']['GM']['@depth'])*(int(self.drc.config['Core']['Interface']['@width'])/8)-1)

        #Find highest address of DTL bus only if not native
        if self.drc.config['Core']['Memory']['GM']['@interface'] != "native":
            if isinstance(peripherals['Peripheral'],list):
                for peripheral in filter(lambda peripheralsl: ('@level' not in peripheralsl or peripheralsl['@level'] != 'core'), peripherals['Peripheral']):
                    endAddressNonCore.append(int(peripheralTypes[peripheral['@type']]['@addr_range']) + int(peripheral['@addr_offset']) - 1)

        endAddressNonCore = sorted(endAddressNonCore, reverse=True)

        #Append highest address to address ranges for port 0
        addressRanges.append((0,endAddressNonCore[0],"port0",dict()))

        for peripheral in peripheralList:
            start_addr = int(peripheral['@addr_offset'])
            end_addr = int(peripheralTypes[peripheral['@type']]['@addr_range']) + start_addr - 1
            addressRanges.append((start_addr,end_addr,peripheral['@name'],peripheralTypes[peripheral['@type']]['Toplevel_connections']))

        addressRanges = sorted(addressRanges)

        #check if the address spaces do not overlap
        for addressRange in addressRanges:
            start_addr = addressRange[0]
            for checkRange in ([elem for elem in addressRanges if int(elem[0]) >= start_addr]):
                if checkRange[2] != addressRange[2]: #the name is different so it is a different module
                    if addressRange[1] >= checkRange[1]:
                        raise ValueError("Address space of '" + addressRange[2] + "' overlaps with address space of '" +checkRange[2]+ "'")        
       

        #Generate string containing ranges and replace
        rangeString = "\""
        for addressRange in addressRanges:
            if rangeString != "\"":
                rangeString = "." + rangeString
            rangeString = str(addressRange[1]) + "." + str(addressRange[0]) + rangeString

        rangeString = "\"" + rangeString

        filedataWrapper = filedataWrapper.replace("<<NUM_PERIPHERALS>>",str(len(addressRanges)))
        filedataWrapper = filedataWrapper.replace("<<RANGE_PERIPHERALS>>",rangeString)
        filedataWrapper = filedataWrapper.replace("<<STRING_SIZE>>",str(len(rangeString)-2))


        corePeripheralInstantiation = "//Core peripheral instantiations\n\n"
        pioWires = "//inputs and outputs for peripherals\n"
        pioConnections = "\t\t//connections for peripheral IO\n"

        #Generation of peripherals data
        for idx, addressRange in enumerate(addressRanges):
            if addressRange[2] != "port0":
                for peripheral in peripheralList:
                    if peripheral['@name'] == addressRange[2]:
                            pType = peripheral['@type']
            
                filedataPeripheral = templates['Core_Peripheral_inst']

                filedataPeripheral = filedataPeripheral.replace("<<UNIT_NAME>>", "CORE_" + addressRange[2] + "_inst")
                filedataPeripheral = filedataPeripheral.replace("<<UNIT_TYPE>>", "CORE_" + pType)
                filedataPeripheral = filedataPeripheral.replace("<<PERIPHERAL_NUMBER>>", str(idx))

                if addressRange[3] != None and 'connection' in addressRange[3]:
                    for connection in addressRange[3]['connection']:
                        pioWires += "\t" + connection['@type'] + " [" + connection['@width'] + "-1:0] "

                        prefix = ""
                        if (connection['@type'] == "output"):
                            prefix += "o"

                        if (connection['@type'] == "input"):
                            prefix += "i"

                        pioWires += prefix + connection['@name'] + "_" + addressRange[2] + ",\n"
                        pioConnections += "\t\t." + prefix + connection['@name'] + "(" + prefix + connection['@name'] + "_" + addressRange[2] + "),\n"

                filedataPeripheral = filedataPeripheral.replace("<<PERIPHERAL_CONNECTIONS>>", pioConnections)
                corePeripheralInstantiation += filedataPeripheral + "\n"
            

        filedataWrapper = filedataWrapper.replace("<<PERIPHERAL_IO>>", pioWires)
        filedataWrapper = filedataWrapper.replace("<<CORE_PERIPHERALS>>", corePeripheralInstantiation)

        decoderTypeCount = Counter(elemProperties['type'] for elemName, elemProperties in self.drc.config.decoders.items())
        fuTypeCount = Counter(elemProperties['@type'] for elemName, elemProperties in self.drc.config.functionalUnits.items() if elemProperties['@type'] not in ['ID','IU'])

        #assign a numeric index to each LSU, so we can figure out the verilog assignment again later
        indexCounter=0
        for elemName, elemProperties in self.drc.config.functionalUnits.items():
            if elemProperties['@type'] in ['LSU']:
                self.drc.config.functionalUnits[elemName]['index'] = indexCounter
                indexCounter += 1

        #assign a numeric index to each ID and IU (independently), so we can figure out the verilog assignment again later
        decoderIndex = 0
        immediateIndex = 0
        for decoderName, decoderProperties in self.drc.config.decoders.items():
            if decoderProperties['type'] in ['ID']:
               self.drc.config.decoders[decoderName]['index'] = decoderIndex
               self.drc.config.functionalUnits[decoderName]['index'] = decoderIndex
               decoderIndex += 1

            if decoderProperties['type'] in ['IU']:
               self.drc.config.decoders[decoderName]['index'] = immediateIndex
               self.drc.config.functionalUnits[decoderName]['index'] = immediateIndex
               immediateIndex += 1

        orWires = "\twire [NUM_STALL_GROUPS-1:0] wStall_0;\n"
        orWireAssign = "\t\t\t\tassign wStall[gCurrStall] = wStall_0[gCurrStall]"

        for lsu in range(1,fuTypeCount['LSU']):
            orWires += "\twire [NUM_STALL_GROUPS-1:0] wStall_"+str(lsu)+";\n"
            orWireAssign += " | wStall_" + str(lsu) + "[gCurrStall]"

        orWireAssign += ";\n"

        filedata = filedata.replace("<<WOR_WIRES>>",orWires)
        filedata = filedata.replace("<<WOR_ASSIGNS>>",orWireAssign)

        if buildNW == 1: #instantiate and connect all switchboxes
            if 'stallgroups' not in self.drc.config['configuration']:
                raise ValueError("The number of stall groups is undefined in the architecture description")

            numStallGroups = int(self.drc.config['configuration']['stallgroups']['@number'])
            stallConfigWidth = max(int(math.ceil(math.log(numStallGroups,2))),1)
        else:
            #find all stall groups
            stallGroups= {}
            currIndex = 0

            for fu in self.drc.config.functionalUnits:
                fuInfo = self.drc.config.functionalUnits[fu]

                if 'input' in fuInfo:
                    if not isinstance(fuInfo['input'],list):
                        fuInputs = [fuInfo['input']]
                    else:
                        fuInputs = fuInfo['input']

                if fuInfo['@type'] in ['ID','IU']:
                    for fuInput in fuInputs:
                        fuInput = fuInput['@source'].split('.')
                        #lookup source type and configuration
                        if self.drc.config.functionalUnits[fuInput[0]]['@type'] in ['ABU']:
                            #if the abu is configured for branch mode and we are connected to the highest output number (program counter)
                            if str(self.drc.config.functionalUnits[fuInput[0]]['@config']) == '1' and (int(self.drc.config.functionalUnits[fuInput[0]]['connections']['@outputs'])-1) == int(fuInput[1]):
                                if fuInput[0] not in stallGroups:
                                    stallGroups[fuInput[0]] = {}
                                    stallGroups[fuInput[0]]['index'] = currIndex
                                    stallGroups[fuInput[0]]['decoders'] = [fu]
                                    stallGroups[fuInput[0]]['units'] = []
                                    currIndex += 1
                                else:
                                    stallGroups[fuInput[0]]['decoders'] += [fu]

            for fu in self.drc.config.functionalUnits:
                fuInfo = self.drc.config.functionalUnits[fu]

                if fuInfo['@type'] not in ['ID','IU']:
                    for group in stallGroups:
                        if fuInfo['@ID'] in stallGroups[group]['decoders']:
                            stallGroups[group]['units'] += [fu]

            #pprint(stallGroups)

            numStallGroups =  int(len(stallGroups))
            stallConfigWidth = max(int(math.ceil(math.log(numStallGroups,2))),1)


        #fill in parameter values
        filedata = filedata.replace("<<MODULE_NAME>>",self.designName.upper() + '_Compute')
        filedata = filedata.replace("<<D_WIDTH>>",str(self.dataWidth))
        filedata = filedata.replace("<<I_WIDTH>>",str(self.instructionWidth))
        filedata = filedata.replace("<<I_IMM_WIDTH>>",str(self.immediateWidth))
        filedata = filedata.replace("<<NUM_ID>>",str(decoderTypeCount['ID']))
        filedata = filedata.replace("<<NUM_IMM>>",str(decoderTypeCount['IU']))
        filedata = filedata.replace("<<NUM_LDMEM>>",str(fuTypeCount['LSU']))
        filedata = filedata.replace("<<NUM_GDMEM>>",str(fuTypeCount['LSU'])) #number of request ports to global memory still will be equal to num LSU

        #str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))-int(math.log(int(self.drc.config['Core']['Memory']['LM']['@width'])/8,2)))

        filedata = filedata.replace("<<DECODED_WIDTH>>", self.drc.config['Core']['DecodedInstructions']['@width'])
        filedata = filedata.replace("<<INTERFACE_WIDTH>>", self.drc.config['Core']['Interface']['@width'])
        filedata = filedata.replace("<<INTERFACE_ADDR_WIDTH>>", self.drc.config['Core']['Interface']['@addresswidth'])
        filedata = filedata.replace("<<LM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))))
        #filedata = filedata.replace("<<GM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['GM']['@depth']),2)))))
        filedata = filedata.replace("<<IM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['IM']['@depth']),2)))))
        filedata = filedata.replace("<<LM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@addresswidth'])
        filedata = filedata.replace("<<GM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@addresswidth'])
        filedata = filedata.replace("<<IM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        filedata = filedata.replace("<<LM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@width'])
        filedata = filedata.replace("<<GM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@width'])
        filedata = filedata.replace("<<NUM_STALL_GROUPS>>", str(numStallGroups))

        filedataWrapper = filedataWrapper.replace("<<MODULE_NAME>>",self.designName.upper() + '_Compute_Wrapper')
        filedataWrapper = filedataWrapper.replace("<<D_WIDTH>>",str(self.dataWidth))
        filedataWrapper = filedataWrapper.replace("<<I_WIDTH>>",str(self.instructionWidth))
        filedataWrapper = filedataWrapper.replace("<<I_IMM_WIDTH>>",str(self.immediateWidth))
        filedataWrapper = filedataWrapper.replace("<<NUM_ID>>",str(decoderTypeCount['ID']))
        filedataWrapper = filedataWrapper.replace("<<NUM_IMM>>",str(decoderTypeCount['IU']))
        filedataWrapper = filedataWrapper.replace("<<NUM_LDMEM>>",str(fuTypeCount['LSU']))
        filedataWrapper = filedataWrapper.replace("<<NUM_GDMEM>>",str(fuTypeCount['LSU'])) #number of request ports to global memory still will be equal to num LSU
        filedataWrapper = filedataWrapper.replace("<<COMPUTE_NAME>>",self.designName.upper() + '_Compute')

        filedataWrapper = filedataWrapper.replace("<<DECODED_WIDTH>>", self.drc.config['Core']['DecodedInstructions']['@width'])
        filedataWrapper = filedataWrapper.replace("<<INTERFACE_WIDTH>>", self.drc.config['Core']['Interface']['@width'])
        filedataWrapper = filedataWrapper.replace("<<INTERFACE_ADDR_WIDTH>>", self.drc.config['Core']['Interface']['@addresswidth'])
        filedataWrapper = filedataWrapper.replace("<<INTERFACE_BLOCK_WIDTH>>", self.drc.config['Core']['Interface']['@max_blockwidth'])
        filedataWrapper = filedataWrapper.replace("<<LM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))))
        #filedataWrapper = filedataWrapper.replace("<<GM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['GM']['@depth']),2)))))
        filedataWrapper = filedataWrapper.replace("<<IM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['IM']['@depth']),2)))))
        filedataWrapper = filedataWrapper.replace("<<LM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@addresswidth'])
        filedataWrapper = filedataWrapper.replace("<<GM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@addresswidth'])
        filedataWrapper = filedataWrapper.replace("<<IM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        filedataWrapper = filedataWrapper.replace("<<LM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@width'])
        filedataWrapper = filedataWrapper.replace("<<GM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@width'])
        filedataWrapper = filedataWrapper.replace("<<LOADER_OFFSET>>", "32'h" + self.drc.config['Core']['Loader']['@offset'])        

        filedata = filedata.replace("<<SRC_WIDTH>>",str(int(self.drc.config['ISA']['instructionFieldTypes']['input']['@width'])))
        filedata = filedata.replace("<<DEST_WIDTH>>",str(int(self.drc.config['ISA']['instructionFieldTypes']['output']['@width'])))
        filedata = filedata.replace("<<REG_WIDTH>>",str(int(self.drc.config['ISA']['instructionFieldTypes']['register']['@width'])))

        #assign wires for global memory connections
        lsuList = sorted([elem['index'] for elem in  self.drc.config.functionalUnits.values() if elem['@type'] == 'LSU'])
        filedata = filedata.replace("<<GM_WE>>",self.__connectionString('wGM_WriteEnable',lsuList))
        filedata = filedata.replace("<<GM_WA>>",self.__connectionString('wGM_WriteAddress',lsuList))
        filedata = filedata.replace("<<GM_WD>>",self.__connectionString('wGM_WriteData',lsuList))
        filedata = filedata.replace("<<GM_RA>>",self.__connectionString('wGM_ReadAddress',lsuList))
        filedata = filedata.replace("<<GM_RR>>",self.__connectionString('wGM_ReadRequest',lsuList))
        filedata = filedata.replace("<<GM_WR>>",self.__connectionString('wGM_WriteRequest',lsuList))
        filedata = filedata.replace("<<GM_RD>>",self.__connectionString('wGM_ReadData',lsuList))
        filedata = filedata.replace("<<GM_RV>>",self.__connectionString('wGM_ReadDataValid',lsuList))
        filedata = filedata.replace("<<GM_WACC>>",self.__connectionString('wGM_WriteAccept',lsuList))
        filedata = filedata.replace("<<GM_RGNC>>",self.__connectionString('wGM_ReadGrantNextCycle',lsuList))
        filedata = filedata.replace("<<GM_WGNC>>",self.__connectionString('wGM_WriteGrantNextCycle',lsuList))

        #assign wires for local memory connections
        filedata = filedata.replace("<<LM_WE>>",self.__connectionString('wLM_WriteEnable',lsuList))
        filedata = filedata.replace("<<LM_RE>>",self.__connectionString('wLM_ReadEnable',lsuList))
        filedata = filedata.replace("<<LM_WA>>",self.__connectionString('wLM_WriteAddress',lsuList))
        filedata = filedata.replace("<<LM_WD>>",self.__connectionString('wLM_WriteData',lsuList))
        filedata = filedata.replace("<<LM_RA>>",self.__connectionString('wLM_ReadAddress',lsuList))
        filedata = filedata.replace("<<LM_RD>>",self.__connectionString('wLM_ReadData',lsuList))

        #assign wires for instruction memory connections
        idList = [elem['index'] for elem in self.drc.config.decoders.values() if elem['type'] == 'ID']
        immList = [elem['index'] for elem in self.drc.config.decoders.values() if elem['type'] == 'IU']
        filedata = filedata.replace("<<IM_RA>>",self.__connectionString('wIM_IU_ReadAddress',immList) + (', ' if len(immList) != 0 and len(idList) != 0 else '') + self.__connectionString('wIM_ID_ReadAddress',idList))
        filedata = filedata.replace("<<IM_RD>>",self.__connectionString('wIM_IU_ReadData',immList) + (', ' if len(immList) != 0 and len(idList) != 0 else '') + self.__connectionString('wIM_ID_ReadData',idList))
        filedata = filedata.replace("<<IM_RE>>",self.__connectionString('wIM_IU_ReadEnable',immList) + (', ' if len(immList) != 0 and len(idList) != 0 else '') + self.__connectionString('wIM_ID_ReadEnable',idList))

        if (len(idList) != 0):
            filedata = filedata.replace("<<ID_wires>>",'wire [IM_ADDR_WIDTH-1:0] wIM_ID_ReadAddress['+str(len(idList)-1)+':0];\n\twire [I_WIDTH-1:0] wIM_ID_ReadData['+str(len(idList)-1)+':0];\n\twire wIM_ID_ReadEnable['+str(len(idList)-1)+':0];')
            filedata = filedata.replace("<<ID_INS_wires>>",'wire [I_WIDTH-1:0] wIM_ID_Instruction['+str(len(idList)-1)+':0];')
            if buildNW == 0:
                filedata = filedata.replace("<<ID_DECODED_INS_wires>>",'wire [I_DECODED_WIDTH-1:0] wIM_ID_DecodedInstruction['+str(len(idList)-1)+':0];')
            else:
                filedata = filedata.replace("<<ID_DECODED_INS_wires>>",'')

        if (len(immList) != 0):
            filedata = filedata.replace("<<IU_wires>>",'wire [IM_ADDR_WIDTH-1:0] wIM_IU_ReadAddress['+str(len(immList)-1)+':0];\n\twire [I_IMM_WIDTH-1:0] wIM_IU_ReadData['+str(len(immList)-1)+':0];\n\twire wIM_IU_ReadEnable['+str(len(immList)-1)+':0];')
            filedata = filedata.replace("<<IU_INS_wires>>",'wire [I_IMM_WIDTH-1:0] wIM_IU_Instruction['+str(len(immList)-1)+':0];')
        else:
            filedata = filedata.replace("<<IU_wires>>",'')
            filedata = filedata.replace("<<IU_INS_wires>>",'')

        #instantiate wires for data connections
        wireNames = ''

        if (buildNW == 0):
            for functionalUnits in self.drc.config.functionalUnits.values():
                if int(functionalUnits['connections']['@outputs']) != 0:
                    for currIndex in range(0,int(functionalUnits['connections']['@outputs'])):
                        sourceName = functionalUnits['@name']
                        sourceIndex = str(currIndex)
                        wireNames += 'wire [D_WIDTH-1:0] wData_' + sourceName + '_' + sourceIndex + ';\n\t' #+ '_TO_' + destName + '_' + destIndex + ';\n\t'


            #print wireNames
            filedata = filedata.replace("<<DATA_wires>>",wireNames)
            filedata = filedata.replace("<<CONTROL_wires>>","")
        else:
            sizeX = 0
            sizeY = 0

            for functionalUnit in self.drc.config.functionalUnits:
                if int(self.drc.config.functionalUnits[functionalUnit]['@Xloc']) > sizeX:
                    sizeX = int(self.drc.config.functionalUnits[functionalUnit]['@Xloc'])

                if int(self.drc.config.functionalUnits[functionalUnit]['@Yloc']) > sizeY:
                    sizeY = int(self.drc.config.functionalUnits[functionalUnit]['@Yloc'])

            sizeY += 1  #for the outputs of the bottom FUs

            print '\t\tDetected network size: X: ' + str(sizeX+1) + '\tY: ' +  str(sizeY+1)

            networkcfg=self.drc.config['configuration']['network']
            networkcfg['data']['sizeX'] = sizeX
            networkcfg['data']['sizeY'] = sizeY
            if '@width' in networkcfg['data']:
                networkcfg['data']['width'] = int(networkcfg['data']['@width'])
            else:
                networkcfg['data']['width'] = self.dataWidth
            networkcfg['data']['channelsH'] = int(networkcfg['data']['@horizontal'])
            networkcfg['data']['channelsV'] = int(networkcfg['data']['@vertical'])


            networkcfg['control']['sizeX'] = sizeX
            networkcfg['control']['sizeY'] = sizeY

            if '@width' in networkcfg['control']:
                networkcfg['control']['width'] = int(networkcfg['control']['@width'])
            else:
                networkcfg['control']['width'] = self.decodedWidth
            networkcfg['control']['channelsH'] = int(networkcfg['control']['@horizontal'])
            networkcfg['control']['channelsV'] = int(networkcfg['control']['@vertical'])

            network = network_gen(self.drc.config, templates, outDir)

            wireNamesData = ''
            wireNamesControl = ''
            for Y in range(0,sizeY+1):
                for X in range(0,sizeX+1):
                    swb_name = 'X' + str(X) + '_Y' +str(Y)

                    #print swb_name
                    wireNamesData += '//Wires for ' + swb_name + '\n\t'
                    wireNamesControl += '//Wires for ' + swb_name + '\n\t'

                    for port in network.switchboxes[swb_name]['data']['ports']:
                        if port[0] in ['RIGHT','BOTTOM']:
                            if networkcfg['data']['@duplex'] == 'full':
                                wireNamesData += "wire [D_WIDTH*"+str(port[1])+"-1:0] wData_" + swb_name + "_"+port[0]+"_IN;\n\t"
                                wireNamesData += "wire [D_WIDTH*"+str(port[1])+"-1:0] wData_" + swb_name + "_"+port[0]+"_OUT;\n\t"
                            else:
                                wireNamesData += "wire [D_WIDTH*"+str(port[1])+"-1:0] wData_" + swb_name + "_"+port[0]+";\n\t"
                                wireNamesData += "wire ["+str(port[1])+"-1:0] wClaim_" + 'data_' + swb_name + "_" + port[0]+";\n\t"

                    for port in network.switchboxes[swb_name]['control']['ports']:
                        if port[0] in ['RIGHT','BOTTOM']:
                            if networkcfg['control']['@duplex'] == 'full':
                                wireNamesControl += "wire [I_DECODED_WIDTH*"+str(port[1])+"-1:0] wControl_" + swb_name + "_"+port[0]+"_IN;\n\t"
                                wireNamesControl += "wire [I_DECODED_WIDTH*"+str(port[1])+"-1:0] wControl_" + swb_name + "_"+port[0]+"_OUT;\n\t"
                            else:
                                wireNamesControl += "wire [I_DECODED_WIDTH*"+str(port[1])+"-1:0] wControl_" + swb_name + "_"+port[0]+";\n\t"
                                wireNamesControl += "wire ["+str(port[1])+"-1:0] wClaim_" + 'control_' + swb_name + "_" + port[0]+";\n\t"

                    if 'inputs' in network.switchboxes[swb_name]['data']:
                        if network.switchboxes[swb_name]['data']['inputs'] != 0:
                            wireNamesData += "wire [D_WIDTH*"+str(network.switchboxes[swb_name]['data']['inputs'])+"-1:0] wData_" + swb_name + "_FU_IN;\n\t"

                    if 'inputs' in network.switchboxes[swb_name]['control']:
                        if network.switchboxes[swb_name]['control']['inputs'] != 0:
                            wireNamesControl += "wire [I_DECODED_WIDTH*"+str(network.switchboxes[swb_name]['control']['inputs'])+"-1:0] wControl_" + swb_name + "_FU_IN;\n\t"

                    if 'outputs' in network.switchboxes[swb_name]['data']:
                        if network.switchboxes[swb_name]['data']['outputs'] != 0:
                            wireNamesData += "wire [D_WIDTH*"+str(network.switchboxes[swb_name]['data']['outputs'])+"-1:0] wData_" + swb_name + "_FU_OUT;\n\t"

                    if 'outputs' in network.switchboxes[swb_name]['control']:
                        if network.switchboxes[swb_name]['control']['outputs'] != 0:
                            wireNamesControl += "wire [I_DECODED_WIDTH*"+str(network.switchboxes[swb_name]['control']['outputs'])+"-1:0] wControl_" + swb_name + "_FU_OUT;\n\t"

            #print wireNames
            filedata = filedata.replace("<<DATA_wires>>",wireNamesData)
            filedata = filedata.replace("<<CONTROL_wires>>",wireNamesControl)

        #build a chain of reconfigurable units from the FU description
        prevUnit= ''
        self.reconfigurationData = {}
        if (buildNW == 0):
            for functionalUnit in self.drc.config.functionalUnits:
                if int(self.drc.config.functionalUnits[functionalUnit]['reconfiguration']['@bits']) != 0 or self.drc.config.functionalUnits[functionalUnit]['@type'] in ['LSU','IU'] :

                    if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID','IU']:
                        if 'configurationBits' in self.drc.config.decoders[functionalUnit]:
                            configBits = self.drc.config.decoders[functionalUnit]['configurationBits']
                        else:
                            configBits = ""

                        for group in stallGroups:
                            if functionalUnit in stallGroups[group]['decoders']:
                                configBits = self.__toBin(int(stallGroups[group]['index']),stallConfigWidth) + configBits
                    elif self.drc.config.functionalUnits[functionalUnit]['@type'] not in ['LSU']:
                        configBits = self.drc.config.functionalUnits[functionalUnit]['@config']

                        if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ABU']:
                            for group in stallGroups:
                                if functionalUnit in stallGroups[group]['units']:
                                    configBits = self.__toBin(int(stallGroups[group]['index']),stallConfigWidth) + configBits
                    else:                        
                        for group in stallGroups:                        
                            if functionalUnit in stallGroups[group]['units']:
                                configBits = self.__toBin(int(stallGroups[group]['index']),stallConfigWidth)

                    self.reconfigurationData[functionalUnit] = {'sourceUnit':prevUnit,'configData': configBits, 'last':0}
                    prevUnit = functionalUnit
                elif self.drc.config.functionalUnits[functionalUnit]['@type'] in ['LSU','IU']:
                    for group in stallGroups:                        
                        if functionalUnit in stallGroups[group]['units']:
                            configBits = self.__toBin(int(stallGroups[group]['index']),stallConfigWidth)
                else:
                    configBits = ""

                #print functionalUnit,configBits

            if prevUnit != '':
                self.reconfigurationData[prevUnit]['last'] = 1 #mark the last fu in the chain
        else:
            for Y in range(0,sizeY+1):
                for X in range(0,sizeX+1):
                    swb_name = 'X' + str(X) + '_Y' +str(Y)
                    if 'FU' in network.switchboxes[swb_name]:
                        fuType = network.switchboxes[swb_name]['FU']['type']
                        configBits = int(self.drc.config['configuration']['functionalunittypes'][fuType]['reconfiguration']['@bits'])

                        if fuType in ['ABU','ID','LSU','IU']:
                            configBits += stallConfigWidth

                        if configBits > 0:
                            configBitString = configBits * "0"
                            self.reconfigurationData[network.switchboxes[swb_name]['FU']['name']] = {'sourceUnit':prevUnit,'configData': configBitString, 'last':0}
                            prevUnit = network.switchboxes[swb_name]['FU']['name']

            if prevUnit != '':
                self.reconfigurationData[prevUnit]['last'] = 1 #mark the last fu in the chain

        wireNames = ''
        configString = ''
        configLen = 0
        for FU in self.reconfigurationData.items():
            if FU[1]['sourceUnit'] != '': #the first unit in the chain
                wireNames += 'wire wConfig_' + FU[1]['sourceUnit'] + '_TO_' + FU[0] + ';\n\t'

        if buildNW == 1:
            for Y in range(0,sizeY+1):
                for X in range(0,sizeX+1):
                    swb_name = 'X' + str(X) + '_Y' +str(Y)
                    wireNames += 'wire wConfig_SWB_' + swb_name + '_data;\n\t'
                    wireNames += 'wire wConfig_SWB_' + swb_name + '_control;\n\t'

        filedata = filedata.replace("<<CONFIG_wires>>",wireNames)

        #build a chain for state scan in + scan out
        stateChain = []
        index = 0;
        predecessor = ""

        for fu in self.drc.config.functionalUnits:
            fuInfo = self.drc.config.functionalUnits[fu]
            stateChain.append((index, fuInfo['@name'], predecessor))
            predecessor = fuInfo['@name']
            index += 1


        lastFU = ""
        for link in sorted(stateChain):
            self.drc.config.functionalUnits[link[1]]['state'] = {}
            self.drc.config.functionalUnits[link[1]]['state']['sourceUnit'] = link[2]

            if link[2] != "":
                self.drc.config.functionalUnits[link[2]]['state']['sinkUnit'] = link[1]

            lastFU = link[1]

        self.drc.config.functionalUnits[lastFU]['state']['sinkUnit'] = ""

        #instantiate functional units and connect them
        fuString = ''
        stateChainWires = "//state chain wires\n"
        carryWires = ""

        for functionalUnit in self.drc.config.functionalUnits:

            fuTemplate = templates[self.drc.config.functionalUnits[functionalUnit]['@type']+'_inst']

            if 'state' in self.drc.config.functionalUnits[functionalUnit]:
                stateLink = self.drc.config.functionalUnits[functionalUnit]['state']

                if stateLink['sourceUnit']=="":
                    sourceWire = "iStateDataIn"
                else:
                    sourceWire = 'wState_' + stateLink['sourceUnit'] + '_TO_' + functionalUnit
                    stateChainWires += '\t\twire ' + sourceWire + ";\n"
                if stateLink['sinkUnit']=="":
                    sinkWire = "oStateDataOut"
                else:
                    sinkWire = 'wState_' + functionalUnit + '_TO_' + stateLink['sinkUnit']

                fuTemplate = fuTemplate.replace("<<STATE_DATA_IN>>",sourceWire)
                fuTemplate = fuTemplate.replace("<<STATE_DATA_OUT>>",sinkWire)


            fuTemplate = fuTemplate.replace("<<NUM_INPUTS>>",self.drc.config.functionalUnits[functionalUnit]['connections']['@inputs'])
            fuTemplate = fuTemplate.replace("<<NUM_OUTPUTS>>",self.drc.config.functionalUnits[functionalUnit]['connections']['@outputs'])

            #if a unit has reconfiguration bits it should be added the the configuration-chain
            if functionalUnit in self.reconfigurationData:

                if self.reconfigurationData[functionalUnit]['sourceUnit'] == '': #first unit in the scanchain
                    configWireIN = 'iConfigDataIn'
                else:
                     configWireIN = 'wConfig_' + self.reconfigurationData[functionalUnit]['sourceUnit'] + '_TO_' + functionalUnit

                if self.reconfigurationData[functionalUnit]['last'] == 1:
                    if (buildNW == 0):
                        configWireOUT = 'oConfigDataOut'
                    else:
                        configWireOUT = 'wConfig_SWB_X0_Y0_data'
                else:
                    destUnit = [sourceFU for sourceFU, sourceFUInfo in self.reconfigurationData.items() if sourceFUInfo['sourceUnit'] == functionalUnit]

                    if len(destUnit) != 0:
                        configWireOUT = 'wConfig_' + functionalUnit + '_TO_' + destUnit[0]
                    else:
                        configWireOUT = ''
                        raise ValueError("Internal error while looking up source functional unit for cofiguration-chain")

                fuTemplate = fuTemplate.replace("<<CONFIG_DATA_IN>>",configWireIN)
                fuTemplate = fuTemplate.replace("<<CONFIG_DATA_OUT>>",configWireOUT)

            fuTemplate = fuTemplate.replace("<<UNIT_NAME>>",functionalUnit + '_inst')

            #connect instruction wires
            if 'index' in self.drc.config.functionalUnits[functionalUnit] and self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID','IU']: #,'LSU']: LSU??
                fuTemplate = fuTemplate.replace("<<INSTRUCTION_ADDRESS>>",'wIM_'+ self.drc.config.functionalUnits[functionalUnit]['@type'] +'_ReadAddress[' + str(self.drc.config.functionalUnits[functionalUnit]['index']) + ']')
                fuTemplate = fuTemplate.replace("<<INSTRUCTION_RE>>",'wIM_'+ self.drc.config.functionalUnits[functionalUnit]['@type'] +'_ReadEnable[' + str(self.drc.config.functionalUnits[functionalUnit]['index']) + ']')
                fuTemplate = fuTemplate.replace("<<INSTRUCTION_DATA>>",'wIM_'+ self.drc.config.functionalUnits[functionalUnit]['@type'] +'_ReadData[' + str(self.drc.config.functionalUnits[functionalUnit]['index']) + ']')
                fuTemplate = fuTemplate.replace("<<INSTRUCTION>>",'wIM_'+ self.drc.config.functionalUnits[functionalUnit]['@type'] +'_Instruction[' + str(self.drc.config.functionalUnits[functionalUnit]['index']) + ']')

                if buildNW == 0:
                    fuTemplate = fuTemplate.replace("<<INSTRUCTION_DECODED>>",'wIM_'+ self.drc.config.functionalUnits[functionalUnit]['@type'] +'_DecodedInstruction[' + str(self.drc.config.functionalUnits[functionalUnit]['index']) + ']')
                else:
                    if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID']:
                        fuTemplate = fuTemplate.replace("<<INSTRUCTION_DECODED>>","wControl_X" + str(self.drc.config.functionalUnits[functionalUnit]['@Xloc']) + "_Y" + str(int(self.drc.config.functionalUnits[functionalUnit]['@Yloc'])+1) + "_FU_OUT")


            #connect the inputs
            if buildNW == 0:
                if 'input' in self.drc.config.functionalUnits[functionalUnit]:
                    #print self.drc.config.functionalUnits[functionalUnit]['input']

                    inputString = ''
                    for currIndex in range(0,int(self.drc.config.functionalUnits[functionalUnit]['connections']['@inputs'])):
                        inputList = self.drc.config.functionalUnits[functionalUnit]['input']

                        if not isinstance(inputList,list):
                            inputList = [inputList]

                        inputFound = 0
                        for inputProperties in inputList:
                            if (int(inputProperties['@index']) == int(currIndex)):
                                inputFound = 1
                                sourceName = re.split(r'\.',inputProperties['@source'])[0]
                                sourceIndex = re.split(r'\.',inputProperties['@source'])[1]

                        if inputFound == 1:
                            newName = 'wData_' + sourceName + '_' + sourceIndex # + '_TO_' + functionalUnit + '_' + str(currIndex)
                        else:
                            newName = "{D_WIDTH{1'b0}}"

                        if currIndex != 0:
                            inputString = newName + ', ' + inputString
                        else:
                            inputString = newName + inputString

                    if int(self.drc.config.functionalUnits[functionalUnit]['connections']['@inputs']) != 1:
                        inputString = '{' + inputString + '}'
                    else:
                        if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID','IU']:
                            inputString = inputString + '[IM_ADDR_WIDTH-1:0]'

                    fuTemplate = fuTemplate.replace("<<INPUTS>>",inputString)
                else: #check if the unit can have connections but they are just not specified
                    if 'connections' in self.drc.config.functionalUnits[functionalUnit]:
                        if '@inputs' in self.drc.config.functionalUnits[functionalUnit]['connections']:
                            inputString = ''
                            for currIndex in range(0,int(self.drc.config.functionalUnits[functionalUnit]['connections']['@inputs'])):
                                newName = "{D_WIDTH{1'b0}}"
                                if currIndex != 0:
                                    inputString = newName + ', ' + inputString
                                else:
                                    inputString = newName + inputString
                            if int(self.drc.config.functionalUnits[functionalUnit]['connections']['@inputs']) != 1:
                                inputString = '{' + inputString + '}'

                            fuTemplate = fuTemplate.replace("<<INPUTS>>",inputString)
            else: #it is a network CGRA
                swb_name = 'X' + self.drc.config.functionalUnits[functionalUnit]['@Xloc'] + '_Y' + self.drc.config.functionalUnits[functionalUnit]['@Yloc']
                if 'inputs' in network.switchboxes[swb_name]['data']:
                    if network.switchboxes[swb_name]['data']['inputs'] > 0:
                        if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID','IU'] and self.dataWidth >= 16:
                            inputString = "wData_" + swb_name + "_FU_IN[15:0]"
                        else:
                            inputString = "wData_" + swb_name + "_FU_IN"
                        fuTemplate = fuTemplate.replace("<<INPUTS>>",inputString)

            fuTemplate = fuTemplate.replace("<<TEST_ID>>",'"' + self.drc.config.functionalUnits[functionalUnit]['@name'] + '"')

            #connect the outputs
            if buildNW == 0:
                if int(self.drc.config.functionalUnits[functionalUnit]['connections']['@outputs']) != 0:
                    outputString = ''
                    for currIndex in range(0,int(self.drc.config.functionalUnits[functionalUnit]['connections']['@outputs'])):
                        newName = 'wData_' + functionalUnit + '_' + str(currIndex)

                        if currIndex != 0:
                            outputString = newName + ', ' + outputString
                        else:
                            outputString = newName + outputString

                    if int(self.drc.config.functionalUnits[functionalUnit]['connections']['@outputs']) != 1:
                        outputString = '{' + outputString + '}'

                    fuTemplate = fuTemplate.replace("<<OUTPUTS>>",outputString)
            else: #it is a network CGRA
                swb_name = 'X' + self.drc.config.functionalUnits[functionalUnit]['@Xloc'] + '_Y' + str(int(self.drc.config.functionalUnits[functionalUnit]['@Yloc'])+1)

                if 'outputs' in network.switchboxes[swb_name]['data']:
                    if network.switchboxes[swb_name]['data']['outputs'] > 0:
                        outputString = "wData_" + swb_name + "_FU_OUT"
                        fuTemplate = fuTemplate.replace("<<OUTPUTS>>",outputString)

            fuTemplate = fuTemplate.replace("<<TEST_ID>>",'"' + self.drc.config.functionalUnits[functionalUnit]['@name'] + '"')

            #connect any functional unit to it's ID
            if buildNW == 0:
                if '@ID' in self.drc.config.functionalUnits[functionalUnit]:
                    decoderName = self.drc.config.functionalUnits[functionalUnit]['@ID']
                    decoderIndex = self.drc.config.functionalUnits[decoderName]['index']
                    fuTemplate = fuTemplate.replace("<<ID_DECODED>>",'wIM_ID_DecodedInstruction['+str(decoderIndex)+']')
            else:
                fuTemplate = fuTemplate.replace("<<ID_DECODED>>","wControl_X" + str(self.drc.config.functionalUnits[functionalUnit]['@Xloc']) + "_Y" + str(self.drc.config.functionalUnits[functionalUnit]['@Yloc']) + "_FU_IN")

            #connect memory interfaces
            if 'index' in self.drc.config.functionalUnits[functionalUnit] and self.drc.config.functionalUnits[functionalUnit]['@type'] in ['LSU']:
                fuTemplate = fuTemplate.replace("<<LSU_PORT>>",str(self.drc.config.functionalUnits[functionalUnit]['index']))        
                            
            #make carry wires
            if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ALU']:    
                carryWireIn = "1'b0"
                carryWireOut = ""              
                
                #check if it is the carry out is the source for another ALU
                for sourceFU in self.drc.config.functionalUnits: 

                    if '@carry_source' in self.drc.config.functionalUnits[sourceFU]:
                        carry_source = self.drc.config.functionalUnits[sourceFU]['@carry_source']

                        if carry_source == functionalUnit:
                            carryWireOut = "wCARRY_OUT_" + carry_source
                            carryWires += "\n\twire " + carryWireOut + ";"                    

                #print functionalUnit + "  OUT:\t" + carryWireOut

                if '@carry_source' in self.drc.config.functionalUnits[functionalUnit]:
                    carry_source = self.drc.config.functionalUnits[functionalUnit]['@carry_source']
                    carryWireIn = "wCARRY_OUT_" + carry_source                    
                #print functionalUnit + "  IN:\t" + carryWireIn

                fuTemplate = fuTemplate.replace("<<CARRY_IN>>",carryWireIn)
                fuTemplate = fuTemplate.replace("<<CARRY_OUT>>",carryWireOut)                


            if buildNW == 0:    
                if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ALU']: 
                    isStartPoint = True
                    isEndPoint = True
                    
                    if '@carry_source' in self.drc.config.functionalUnits[functionalUnit]:
                        isStartPoint = False
                    
                    #check if it is the carry out is the source for another ALU
                    for sourceFU in self.drc.config.functionalUnits: 
                        if '@carry_source' in self.drc.config.functionalUnits[sourceFU]:
                            carry_source = self.drc.config.functionalUnits[sourceFU]['@carry_source']
                            if carry_source == functionalUnit:
                                isEndPoint=False
                    
                    if isStartPoint and isEndPoint: #unit not in any chain
                        chainConfigBits = "00"
                    elif isStartPoint and not isEndPoint:
                        chainConfigBits = "01"
                    elif not isStartPoint and isEndPoint:
                        chainConfigBits = "10"
                    else:
                        chainConfigBits = "11"

                    #print functionalUnit + "\tStart ? " + str(isStartPoint) + "\tEnd ? " + str(isEndPoint) + "\t" + chainConfigBits

                    self.reconfigurationData[functionalUnit]['configData'] = chainConfigBits + self.reconfigurationData[functionalUnit]['configData']   

                    #print  self.reconfigurationData[functionalUnit]['configData']                             

            fuString += fuTemplate + '\n'
        
        filedata = filedata.replace("<<CARRY_WIRES>>",carryWires)        
        filedata = filedata.replace("<<STATE_WIRES>>",stateChainWires)

        #the line below updates the config bits in the fu type description, this changes it automatically for all ALUs
        self.drc.config['configuration']['functionalunittypes']['ALU']['reconfiguration']['@bits'] = str(int(self.drc.config['configuration']['functionalunittypes']['ALU']['reconfiguration']['@bits']) + 2)        

        if buildNW == 1: #instantiate and connect all switchboxes
            fuString = fuString + "\n\t// Switchbox network =============================================\n"
            for net in ['data','control']:
                for Y in range(0,sizeY+1):
                    for X in range(0,sizeX+1):
                        swb_name = 'X' + str(X) + '_Y' +str(Y)

                        swbTemplate=templates['swb_inst']

                        if net == 'data':
                            prefix = 'wData_'
                        else:
                            prefix = 'wControl_'

                        moduleName = "SWB_" + net + "_" + swb_name
                        portList = ''
                        controlWireString = ''

                        if 'inputs' in network.switchboxes[swb_name][net]:
                            if int(network.switchboxes[swb_name][net]['inputs']) > 0:
                                fuInputs = network.switchboxes[swb_name][net]['inputs']
                                portList += '.oFUInputs('+prefix + swb_name + '_FU_IN),\n\t\t'
                            else:
                                fuInputs = 0
                        else:
                            fuInputs = 0

                        if 'outputs' in network.switchboxes[swb_name][net]:
                            if int(network.switchboxes[swb_name][net]['outputs']) > 0:
                                fuOutputs = network.switchboxes[swb_name][net]['outputs']
                                portList += '.iFUOutputs('+prefix + swb_name + '_FU_OUT),\n\t\t'
                            else:
                                fuOutputs = 0
                        else:
                            fuOutputs = 0

                        for port in network.switchboxes[swb_name][net]['ports']:
                            if networkcfg[net]['@duplex'] == 'full':
                                if port[0] in ['BOTTOM','RIGHT']:
                                    sourceWire_in = prefix + swb_name + "_" + port[0] + "_IN"
                                    sourceWire_out = prefix + swb_name + "_" + port[0] + "_OUT"
                                else:
                                    if port[0] in ['TOP']:
                                        sourceWire_in = prefix + 'X' + str(X) + '_Y' +str(Y-1) + "_BOTTOM_OUT"
                                        sourceWire_out = prefix + 'X' + str(X) + '_Y' +str(Y-1) + "_BOTTOM_IN"
                                    elif port[0] in ['LEFT']:
                                        sourceWire_in = prefix + 'X' + str(X-1) + '_Y' +str(Y) + "_RIGHT_OUT"
                                        sourceWire_out = prefix + 'X' + str(X-1) + '_Y' +str(Y) + "_RIGHT_IN"

                                portList += '.o' + port[0] + '('+sourceWire_out+'),\n\t\t'
                                portList += '.i' + port[0] + '('+sourceWire_in+'),\n\t\t'
                            else:
                                if port[0] in ['BOTTOM','RIGHT']:
                                    sourceWire = prefix + swb_name + "_" + port[0]
                                    claimWire = "wClaim_" + net + "_" + swb_name + "_" + port[0]
                                    #inUseWire = "wInUse_" + swb_name + "_" + port[0]
                                    controlWireString += '.oClaim' + port[0] + '('+claimWire+'),\n\t\t'
                                else:
                                    if port[0] in ['TOP']:
                                        sourceWire = prefix + 'X' + str(X) + '_Y' +str(Y-1) + "_BOTTOM"
                                        #claimWire = "wInUse_" + 'X' + str(X) + '_Y' +str(Y-1) + "_BOTTOM"
                                        inUseWire = "wClaim_" + net + '_X' + str(X) + '_Y' +str(Y-1) + "_BOTTOM"
                                    elif port[0] in ['LEFT']:
                                        sourceWire = prefix + 'X' + str(X-1) + '_Y' +str(Y) + "_RIGHT"
                                        #claimWire = "wInUse_" + 'X' + str(X-1) + '_Y' +str(Y) + "_RIGHT"
                                        inUseWire = "wClaim_" + net + '_X' + str(X-1) + '_Y' +str(Y) + "_RIGHT"

                                    controlWireString += '.iInUse' + port[0] + '('+inUseWire+'),\n\t\t'
                                portList += '.io' + port[0] + '('+sourceWire+'),\n\t\t'

                        configDataIN = "wConfig_SWB_X" + str(X) + "_Y" + str(Y) + "_" + net

                        if X < sizeX:
                           configDataOUT = "wConfig_SWB_X" + str(X+1) + "_Y" + str(Y) + "_" + net
                        else:
                            if Y < sizeY:
                                configDataOUT = "wConfig_SWB_X" + str(0) + "_Y" + str(Y+1) + "_" + net
                            else:
                                if net == 'data':
                                    configDataOUT = "wConfig_SWB_X0_Y0_control"
                                else:
                                    configDataOUT = "oConfigDataOut"

                        swbTemplate = swbTemplate.replace("<<WIDTH>>",str(networkcfg[net]['width']))
                        swbTemplate = swbTemplate.replace("<<NUM_INPUTS>>",str(fuInputs))
                        swbTemplate = swbTemplate.replace("<<NUM_OUTPUTS>>",str(fuOutputs))
                        swbTemplate = swbTemplate.replace("<<SWB_TYPE>>",moduleName)
                        swbTemplate = swbTemplate.replace("<<MODULE_NAME>>",moduleName + "_inst")
                        swbTemplate = swbTemplate.replace("<<WIRES>>",portList)
                        swbTemplate = swbTemplate.replace("<<CONFIG_DATA_IN>>",configDataIN)
                        swbTemplate = swbTemplate.replace("<<CONFIG_DATA_OUT>>",configDataOUT)
                        if networkcfg['data']['@duplex'] == 'full':
                            swbTemplate = swbTemplate.replace("<<CONTROL_WIRES>>","")
                        else:
                            swbTemplate = swbTemplate.replace("<<CONTROL_WIRES>>",controlWireString)

                        fuString = fuString + swbTemplate + '\n'

                fuString = fuString + "\n\t// ===============================================================\n"


        filedata = filedata.replace("<<DECODERS>>",fuString)


        #----------------------------------- calculate the required number of bits to shift to get the state in or out ------------
        unitTypes = {}
        for fuType in self.drc.config['configuration']['functionalunittypes']:
            unitTypes[fuType] = {}
            unitTypes[fuType]['count']=0
            unitTypes[fuType]['bits']=0

        for functionalUnit in self.drc.config.functionalUnits:
            unitTypes[self.drc.config.functionalUnits[functionalUnit]['@type']]['count'] += 1

        GM_MEM_WIDTH = int(self.drc.config['Core']['Memory']['GM']['@width'])
        IM_ADDR_WIDTH = int(self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        GM_BYTE_ENABLES = (GM_MEM_WIDTH / 8)
        GM_BYTE_ENABLES_WIDTH = math.log(GM_BYTE_ENABLES,2)
        TYPE_WIDTH_LSU = 2 #4 possible types (byte, hword, word, dword)

        NUM_OUTPUTS_LSU =int(self.drc.config['configuration']['functionalunittypes']['LSU']['connections']['@outputs'])
        NUM_OUTPUTS_ALU =int(self.drc.config['configuration']['functionalunittypes']['ALU']['connections']['@outputs'])
        NUM_OUTPUTS_MUL =int(self.drc.config['configuration']['functionalunittypes']['MUL']['connections']['@outputs'])

        #number of registers hardcoded, might be better to include them in the xml in the future if we make this configurable
        NUM_REGISTERS_LSU = 16
        NUM_REGISTERS_RF = 16
        NUM_REGISTERS_ABU = 16

        unitTypes['ID']['bits'] = int(self.decodedWidth + 1)
        unitTypes['LSU']['bits'] = int(self.dataWidth*NUM_OUTPUTS_LSU + GM_BYTE_ENABLES_WIDTH+self.dataWidth*NUM_REGISTERS_LSU+TYPE_WIDTH_LSU+7)
        unitTypes['IU']['bits'] =  int(self.immediateWidth + self.dataWidth + 1)
        unitTypes['ALU']['bits'] = int(self.dataWidth*NUM_OUTPUTS_ALU + 1)
        unitTypes['RF']['bits'] = int(self.dataWidth*NUM_REGISTERS_RF)
        unitTypes['ABU']['bits'] = int(IM_ADDR_WIDTH*NUM_REGISTERS_ABU+max(IM_ADDR_WIDTH,self.dataWidth)+2)
        unitTypes['MUL']['bits'] = int(self.dataWidth*NUM_OUTPUTS_MUL + self.dataWidth)

        stateBits = 0

        for fuType in unitTypes:
            stateBits += unitTypes[fuType]['count'] * unitTypes[fuType]['bits']

        filedataWrapper = filedataWrapper.replace("<<STATE_BITS>>", str(stateBits))

        f = open(outDir + "/" + outputFile,'w')
        f.write(filedata)
        f.close

        f = open(outDir + "/" + outputFileWrapper,'w')
        f.write(filedataWrapper)
        f.close

        if int(self.drc.config['Core']['StateSwitch']['@enabled']) == 1:
            print "\t\t + Enabling state switching ... (modify config.vh to disable after HW generation)"
            print "\t\t + Total number of state bits : " + str(stateBits)
            configText = "`define INCLUDE_STATE_CONTROL\n"
        else:
            print "\t\t + Disabling state switching ... (modify config.vh to enable after HW generation)"
            configText = "//`define INCLUDE_STATE_CONTROL\n"

        if int(self.drc.config['Core']['PerformanceCounters']['@enabled']) == 1:
            print "\t\t + Enabling performance counters ... (modify config.vh to disable after HW generation)"
            configText += "`define INCLUDE_PERF_COUNTERS\n"
        else:
            print "\t\t + Disabling performance counters ... (modify config.vh to enable after HW generation)"
            configText += "//`define INCLUDE_PERF_COUNTERS\n" 

        if self.drc.config['Core']['Memory']['GM']['@interface'] == "native":
            print "\t\t + Using native memory interface ... (modify config.vh to change after HW generation)"
            configText += "`define NATIVE_GM_INTERFACE\n"
        else:
            print "\t\t + Using DTL memory interface ... (modify config.vh to change after HW generation)"
            configText += "//`define NATIVE_GM_INTERFACE\n" 

        if int(self.memsyn) == 1:
            print "\t\t + Setting structure for simulation with memories included ... (modify config.vh to change after HW generation)"
            configText += "`define SYN_MEM\n"
        else:
            print "\t\t + Setting structure for simulation with memories excluded ... (modify config.vh to change after HW generation)"
            configText += "//`define SYN_MEM\n"             


        f = open(outDir + "/config.vh",'w')
        f.write(configText)
        f.close

        self.instance_info={}
        self.instance_info['architecture'] = {}
        self.instance_info['architecture']['ISA'] = self.drc.config['ISA']
        self.instance_info['architecture']['Core'] = self.drc.config['Core']
        self.instance_info['architecture']['DataTypes'] = self.drc.config['DataTypes']
        self.instance_info['architecture']['configuration'] = self.drc.config['configuration']

        FUs = []
        for fu in self.drc.config.functionalUnits:
            FUs.append(self.drc.config.functionalUnits[fu])

        self.instance_info['architecture']['configuration']['functionalunits'] = {}
        self.instance_info['architecture']['configuration']['functionalunits']['fu'] = FUs

        self.instance_info['architecture']['configuration']['CGRA_type'] = buildNW
        self.instance_info['architecture']['reconfiguration'] = self.reconfigurationData

        #pprint(self.reconfigurationData)

        if buildNW == 1:
            self.instance_info['architecture']['network'] = network.switchboxes

        f = open(configOut,'w')
        f.write(xmltodict.unparse(self.instance_info,pretty=True))
        f.close        

    def __exportMemoryVerilog(self, outputFile,templates, outDir):
        filedata = templates['memory']

        decoderTypeCount = Counter(elemProperties['type'] for elemName, elemProperties in self.drc.config.decoders.items())
        fuTypeCount = Counter(elemProperties['@type'] for elemName, elemProperties in self.drc.config.functionalUnits.items() if elemProperties['@type'] not in ['ID','IU'])

        filedata = filedata.replace("<<MODULE_NAME>>",self.designName.upper() + '_Memory')
        filedata = filedata.replace("<<D_WIDTH>>",str(self.dataWidth))
        filedata = filedata.replace("<<I_WIDTH>>",str(self.instructionWidth))
        filedata = filedata.replace("<<I_IMM_WIDTH>>",str(self.immediateWidth))
        filedata = filedata.replace("<<NUM_ID>>",str(decoderTypeCount['ID']))
        filedata = filedata.replace("<<NUM_IMM>>",str(decoderTypeCount['IU']))
        filedata = filedata.replace("<<NUM_LDMEM>>",str(fuTypeCount['LSU']))
        #print '\t\tWARNING: For now every LSU is considered to have it\'s own global memory, when the arbiter works this should be 1 in the whole design!'
        #filedata = filedata.replace("<<NUM_GDMEM>>",str(fuTypeCount['LSU'])) #number of request ports to global memory still will be equal to num LSU

        filedata = filedata.replace("<<DECODED_WIDTH>>", self.drc.config['Core']['DecodedInstructions']['@width'])
        filedata = filedata.replace("<<INTERFACE_WIDTH>>", self.drc.config['Core']['Interface']['@width'])
        filedata = filedata.replace("<<INTERFACE_ADDR_WIDTH>>", self.drc.config['Core']['Interface']['@addresswidth'])
        filedata = filedata.replace("<<LM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))))
        #filedata = filedata.replace("<<GM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['GM']['@depth']),2)))))
        filedata = filedata.replace("<<IM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['IM']['@depth']),2)))))
        filedata = filedata.replace("<<LM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@addresswidth'])
        #filedata = filedata.replace("<<GM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@addresswidth'])
        filedata = filedata.replace("<<IM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        filedata = filedata.replace("<<LM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@width'])
        #filedata = filedata.replace("<<GM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@width'])

        LM_String = ''
        IM_String = ''

        if '@type' in self.drc.config['Core']['Memory']:       
            if self.drc.config['Core']['Memory']['@type'] in ['TSMC']:
                memtype = "_" + self.drc.config['Core']['Memory']['@type']
            else:
                memtype = ""
        else:
            memtype = ""

        for functionalUnit in self.drc.config.functionalUnits:
            if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['LSU']:
               #instantiate local memories for the LSUs
               LM_String += self.__instantiateMemory(functionalUnit,'LM_',self.drc.config.functionalUnits[functionalUnit]['index'],'LM_MEM_WIDTH',0,1,'dmem','','', templates, "RAM_SDP_BE", memtype) + '\n'

            if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID']:
               #instantiate instruction memories for the IDs
               IM_String += self.__instantiateMemory(functionalUnit,'IM_',self.drc.config.functionalUnits[functionalUnit]['index'],'I_WIDTH',0,0,'imem','','', templates, "RAM_SDP", memtype) + '\n'

            if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['IU']:
               #instantiate instruction memories for the IUs
               IM_String += self.__instantiateMemory(functionalUnit,'IM_',self.drc.config.functionalUnits[functionalUnit]['index'],'I_IMM_WIDTH',0,0,'imem','_IMM','+NUM_ID', templates, "RAM_SDP", memtype) + '\n'


        #filedata = filedata.replace("<<GLOBAL_MEMORIES>>",GM_String)
        filedata = filedata.replace("<<LOCAL_MEMORIES>>",LM_String)
        filedata = filedata.replace("<<INSTRUCTION_MEMORIES>>",IM_String)

        f = open(outDir + "/" + outputFile,'w')
        f.write(filedata)
        f.close

    def __exportTopLevelVerilog(self, outputFile,templates, outDir, FPGA):
        if FPGA == True:
            filedata = templates['fpgatop']
        else:
            filedata = templates['top']

        decoderTypeCount = Counter(elemProperties['type'] for elemName, elemProperties in self.drc.config.decoders.items())
        fuTypeCount = Counter(elemProperties['@type'] for elemName, elemProperties in self.drc.config.functionalUnits.items() if elemProperties['@type'] not in ['ID','IU'])

        if FPGA == True:
            moduleName = self.designName.upper() + '_FPGA_Top'
        else:
            moduleName = self.designName.upper() + '_Top'

        filedata = filedata.replace("<<MODULE_NAME>>",moduleName)
        filedata = filedata.replace("<<D_WIDTH>>",str(self.dataWidth))
        filedata = filedata.replace("<<I_WIDTH>>",str(self.instructionWidth))
        filedata = filedata.replace("<<I_IMM_WIDTH>>",str(self.immediateWidth))
        filedata = filedata.replace("<<NUM_ID>>",str(decoderTypeCount['ID']))
        filedata = filedata.replace("<<NUM_IMM>>",str(decoderTypeCount['IU']))
        filedata = filedata.replace("<<NUM_LDMEM>>",str(fuTypeCount['LSU']))
        filedata = filedata.replace("<<NUM_GDMEM>>",str(fuTypeCount['LSU'])) #number of request ports to global memory still will be equal to num LSU
        filedata = filedata.replace("<<CORE_NAME>>",self.designName.upper() + '_Core')
        filedata = filedata.replace("<<MAGIC_DMEM_LOAD>>",str(self.magicLoad))

        filedata = filedata.replace("<<DECODED_WIDTH>>", self.drc.config['Core']['DecodedInstructions']['@width'])
        filedata = filedata.replace("<<INTERFACE_WIDTH>>", self.drc.config['Core']['Interface']['@width'])
        filedata = filedata.replace("<<INTERFACE_ADDR_WIDTH>>", self.drc.config['Core']['Interface']['@addresswidth'])
        filedata = filedata.replace("<<INTERFACE_BLOCK_WIDTH>>", self.drc.config['Core']['Interface']['@max_blockwidth'])
        filedata = filedata.replace("<<LM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))))
        filedata = filedata.replace("<<GM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['GM']['@depth']),2)))))
        filedata = filedata.replace("<<IM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['IM']['@depth']),2)))))
        filedata = filedata.replace("<<LM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@addresswidth'])
        filedata = filedata.replace("<<GM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@addresswidth'])
        filedata = filedata.replace("<<IM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        filedata = filedata.replace("<<LM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@width'])
        filedata = filedata.replace("<<GM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@width'])

        if 'Peripherals' in self.drc.config['Core']:
            peripherals = self.drc.config['Core']['Peripherals']
        else:
            peripherals = []

        peripheralTypes = self.drc.config['PeripheralTypes']

        addressRanges = []
        addressRanges.append((0,int(self.drc.config['Core']['Memory']['GM']['@depth'])*(int(self.drc.config['Core']['Interface']['@width'])/8)-1,"GM",dict()))

        if 'Peripherals' in self.drc.config['Core']:
            if not isinstance(peripherals['Peripheral'],list):
                if '@level' in peripherals['Peripheral'] and peripherals['Peripheral']['@level'] != 'core':
                    peripheralList = [peripherals['Peripheral']]
                else:
                    peripheralList = []
            else:
                peripheralList = filter(lambda peripheralsl: ('@level' not in peripheralsl or peripheralsl['@level'] != 'core'), peripherals['Peripheral'])
        else:
            peripheralList = []


        for peripheral in peripheralList:
            start_addr = int(peripheral['@addr_offset'])
            end_addr = int(peripheralTypes[peripheral['@type']]['@addr_range']) + start_addr - 1
            addressRanges.append((start_addr,end_addr,peripheral['@name'],peripheralTypes[peripheral['@type']]['Toplevel_connections']))

        addressRanges = sorted(addressRanges)

        #check if the address spaces do not overlap
        for addressRange in addressRanges:
            start_addr = addressRange[0]
            for checkRange in ([elem for elem in addressRanges if int(elem[0]) >= start_addr]):
                if checkRange[2] != addressRange[2]: #the name is different so it is a different module
                    if addressRange[1] >= checkRange[1]:
                        raise ValueError("Address space of '" + addressRange[2] + "' overlaps with address space of '" +checkRange[2]+ "'")

        pWires = "//----------------------------- peripheral wires\n\n"
        pioWires = "//inputs and outputs for peripherals\n"
        pioConnections = "\t\t//connections for peripheral IO\n"
        peripheralInstantiation = "//peripheral and DTL isolator instantiations\n\n"
        pioWireNames = []
        orWires = ""

        orAssignWires_ReadData = "\tassign wDTL_ARB_ReadData = wDTL_DMEM_GM_ReadData"
        orAssignWires_WriteAccept = "\tassign wDTL_ARB_WriteAccept = wDTL_DMEM_GM_WriteAccept"
        orAssignWires_CommandAccept = "\tassign wDTL_ARB_CommandAccept = wDTL_DMEM_GM_CommandAccept"
        orAssignWires_ReadValid = "\tassign wDTL_ARB_ReadValid = wDTL_DMEM_GM_ReadValid"
        orAssignWires_ReadLast = "\tassign wDTL_ARB_ReadLast = wDTL_DMEM_GM_ReadLast"

        #build the strings for the wires, inputs and outputs and module instantiations
        for addressRange in addressRanges:
            filedataPeripheral = templates['DTL_Address_Isolator_inst']
            filedataPeripheral = filedataPeripheral.replace("<<UNIT_NAME>>", "DTL_Address_Isolator_" + addressRange[2] + "_inst")
            filedataPeripheral = filedataPeripheral.replace("<<PERIPHERAL_NAME>>", addressRange[2])
            filedataPeripheral = filedataPeripheral.replace("<<RANGE_LOW>>", str(addressRange[0]))
            filedataPeripheral = filedataPeripheral.replace("<<RANGE_HIGH>>", str(addressRange[1]))

            pWires += "\t//wires for " + addressRange[2] + "\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_CommandValid;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_WriteAccept;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_ReadValid;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_ReadLast;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_CommandAccept;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_WriteValid;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_CommandReadWrite;\n"
            pWires += "\t" + "wire [INTERFACE_NUM_ENABLES-1:0] wDTL_" + addressRange[2] + "_WriteEnable;\n"
            pWires += "\t" + "wire [INTERFACE_ADDR_WIDTH-1:0] wDTL_" + addressRange[2] + "_Address;\n"
            pWires += "\t" + "wire [INTERFACE_WIDTH-1:0] wDTL_" + addressRange[2] + "_WriteData;\n"
            pWires += "\t" + "wire [INTERFACE_WIDTH-1:0] wDTL_" + addressRange[2] + "_ReadData;\n"
            pWires += "\t" + "wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_" + addressRange[2] + "_BlockSize;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_WriteLast;\n"
            pWires += "\t" + "wire wDTL_" + addressRange[2] + "_ReadAccept;\n\n"

            orWires += "\t" + "wire [INTERFACE_WIDTH-1:0] wDTL_DMEM_" + addressRange[2] + "_ReadData;\n"
            orWires += "\t" + "wire wDTL_DMEM_" + addressRange[2] + "_WriteAccept;\n"
            orWires += "\t" + "wire wDTL_DMEM_" + addressRange[2] + "_CommandAccept;\n"
            orWires += "\t" + "wire wDTL_DMEM_" + addressRange[2] + "_ReadValid;\n"
            orWires += "\t" + "wire wDTL_DMEM_" + addressRange[2] + "_ReadLast;\n"

            if addressRange[2] != "GM":

                orAssignWires_ReadData += " | wDTL_DMEM_"+ addressRange[2] +"_ReadData"
                orAssignWires_WriteAccept += " | wDTL_DMEM_"+ addressRange[2] +"_WriteAccept"
                orAssignWires_CommandAccept += " | wDTL_DMEM_"+ addressRange[2] +"_CommandAccept"
                orAssignWires_ReadValid += " | wDTL_DMEM_"+ addressRange[2] +"_ReadValid"
                orAssignWires_ReadLast += " | wDTL_DMEM_"+ addressRange[2] +"_ReadLast"

                filedataPeripheral += "\n\n" + templates['Peripheral_inst']

                for peripheral in peripheralList:
                    if peripheral['@name'] == addressRange[2]:
                        pType = peripheral['@type']

                filedataPeripheral = filedataPeripheral.replace("<<UNIT_NAME>>", "DTL_" + addressRange[2] + "_inst")
                filedataPeripheral = filedataPeripheral.replace("<<UNIT_TYPE>>", "DTL_" + pType)
                filedataPeripheral = filedataPeripheral.replace("<<PERIPHERAL_NAME>>", addressRange[2])
                filedataPeripheral = filedataPeripheral.replace("<<TEST_ID>>", "\"" + addressRange[2] + "\"")

                if 'connection' in addressRange[3]:
                    for connection in addressRange[3]['connection']:
                        pioWires += "\t" + connection['@type'] + " [" + connection['@width'] + "-1:0] "

                        prefix = ""
                        if (connection['@type'] == "output"):
                            prefix += "o"

                        if (connection['@type'] == "input"):
                            prefix += "i"

                        pioWireNames.append(prefix + connection['@name'] + "_" + addressRange[2])
                        pioWires += prefix + connection['@name'] + "_" + addressRange[2] + ",\n"
                        pioConnections += "\t\t." + prefix + connection['@name'] + "(" + prefix + connection['@name'] + "_" + addressRange[2] + "),\n"

                filedataPeripheral = filedataPeripheral.replace("<<PERIPHERAL_CONNECTIONS>>", pioConnections)

            peripheralInstantiation += filedataPeripheral + "\n"

        #print pioWires
        filedata = filedata.replace("<<PERIPHERAL_IO>>", pioWires)
        filedata = filedata.replace("<<PERIPHERAL_DTL_WIRES>>", pWires)
        filedata = filedata.replace("<<PERIPHERALS>>", peripheralInstantiation)

        orAssigns = orAssignWires_ReadData + ";\n" + orAssignWires_WriteAccept + ";\n" + orAssignWires_CommandAccept + ";\n" + orAssignWires_ReadValid + ";\n" + orAssignWires_ReadLast + ";\n"

        filedata = filedata.replace("<<PERIPHERAL_WOR_WIRES>>", orWires)
        filedata = filedata.replace("<<PERIPHERAL_WOR_ASSIGNS>>", orAssigns)

        stateMemSize = int(math.log(int(self.drc.config['Core']['Memory']['SM']['@depth']),2))
        filedata = filedata.replace("<<STATE_ADDR_RANGE>>", str(stateMemSize))

        f = open(outDir + "/" + outputFile,'w')
        f.write(filedata)
        f.close

        return pioWireNames

    def __exportCoreVerilog(self, outputFile,templates, outDir):
        filedata = templates['core']

        decoderTypeCount = Counter(elemProperties['type'] for elemName, elemProperties in self.drc.config.decoders.items())
        fuTypeCount = Counter(elemProperties['@type'] for elemName, elemProperties in self.drc.config.functionalUnits.items() if elemProperties['@type'] not in ['ID','IU'])

        filedata = filedata.replace("<<MODULE_NAME>>",self.designName.upper() + '_Core')
        filedata = filedata.replace("<<D_WIDTH>>",str(self.dataWidth))
        filedata = filedata.replace("<<I_WIDTH>>",str(self.instructionWidth))
        filedata = filedata.replace("<<I_IMM_WIDTH>>",str(self.immediateWidth))
        filedata = filedata.replace("<<NUM_ID>>",str(decoderTypeCount['ID']))
        filedata = filedata.replace("<<NUM_IMM>>",str(decoderTypeCount['IU']))
        filedata = filedata.replace("<<NUM_LDMEM>>",str(fuTypeCount['LSU']))
        filedata = filedata.replace("<<NUM_GDMEM>>",str(fuTypeCount['LSU'])) #number of request ports to global memory still will be equal to num LSU
        filedata = filedata.replace("<<MEMORY_NAME>>",self.designName.upper() + '_Memory')
        filedata = filedata.replace("<<COMPUTE_NAME>>",self.designName.upper() + '_Compute')

        filedata = filedata.replace("<<DECODED_WIDTH>>", self.drc.config['Core']['DecodedInstructions']['@width'])
        filedata = filedata.replace("<<INTERFACE_WIDTH>>", self.drc.config['Core']['Interface']['@width'])
        filedata = filedata.replace("<<INTERFACE_ADDR_WIDTH>>", self.drc.config['Core']['Interface']['@addresswidth'])
        filedata = filedata.replace("<<INTERFACE_BLOCK_WIDTH>>", self.drc.config['Core']['Interface']['@max_blockwidth'])
        filedata = filedata.replace("<<LM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))))
        #filedata = filedata.replace("<<GM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['GM']['@depth']),2)))))
        filedata = filedata.replace("<<IM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['IM']['@depth']),2)))))
        filedata = filedata.replace("<<LM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@addresswidth'])
        filedata = filedata.replace("<<GM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@addresswidth'])
        filedata = filedata.replace("<<IM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        filedata = filedata.replace("<<LM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@width'])
        filedata = filedata.replace("<<GM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@width'])

        f = open(outDir + "/" + outputFile,'w')
        f.write(filedata)
        f.close

    def __exportTestbenchVerilog(self, outputFile,templates,outDir, pWireNames):
        filedata = templates['testbench']

        decoderTypeCount = Counter(elemProperties['type'] for elemName, elemProperties in self.drc.config.decoders.items())
        fuTypeCount = Counter(elemProperties['@type'] for elemName, elemProperties in self.drc.config.functionalUnits.items() if elemProperties['@type'] not in ['ID','IU'])

        filedata = filedata.replace("<<MODULE_NAME>>",'TB_' + self.designName.upper() + '_Top')
        filedata = filedata.replace("<<DESIGN_NAME>>",self.designName.upper())
        filedata = filedata.replace("<<D_WIDTH>>",str(self.dataWidth))
        filedata = filedata.replace("<<I_WIDTH>>",str(self.instructionWidth))
        filedata = filedata.replace("<<I_IMM_WIDTH>>",str(self.immediateWidth))
        filedata = filedata.replace("<<NUM_ID>>",str(decoderTypeCount['ID']))
        filedata = filedata.replace("<<NUM_IMM>>",str(decoderTypeCount['IU']))
        filedata = filedata.replace("<<NUM_LDMEM>>",str(fuTypeCount['LSU']))
        filedata = filedata.replace("<<NUM_GDMEM>>",str(fuTypeCount['LSU'])) #number of request ports to global memory still will be equal to num LSU
        filedata = filedata.replace("<<DUT_NAME>>",self.designName.upper() + '_Top')
        filedata = filedata.replace("<<MAGIC_DMEM_LOAD>>",str(self.magicLoad))

        filedata = filedata.replace("<<DECODED_WIDTH>>", self.drc.config['Core']['DecodedInstructions']['@width'])
        filedata = filedata.replace("<<INTERFACE_WIDTH>>", self.drc.config['Core']['Interface']['@width'])
        filedata = filedata.replace("<<INTERFACE_ADDR_WIDTH>>", self.drc.config['Core']['Interface']['@addresswidth'])
        filedata = filedata.replace("<<INTERFACE_BLOCK_WIDTH>>", self.drc.config['Core']['Interface']['@max_blockwidth'])

        filedata = filedata.replace("<<LM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['LM']['@depth']),2)))))
        filedata = filedata.replace("<<GM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['GM']['@depth']),2)))))
        filedata = filedata.replace("<<IM_DEPTH_WIDTH>>", str(int(math.ceil(math.log(int(self.drc.config['Core']['Memory']['IM']['@depth']),2)))))
        filedata = filedata.replace("<<LM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@addresswidth'])
        filedata = filedata.replace("<<GM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@addresswidth'])
        filedata = filedata.replace("<<IM_ADDR_WIDTH>>", self.drc.config['Core']['Memory']['IM']['@addresswidth'])
        filedata = filedata.replace("<<LM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['LM']['@width'])
        filedata = filedata.replace("<<GM_MEM_WIDTH>>", self.drc.config['Core']['Memory']['GM']['@width'])
        filedata = filedata.replace("<<LOADER_OFFSET>>", "32'h" + self.drc.config['Core']['Loader']['@offset'])

        currDecoder = [decoderName for decoderName, decoder in self.reconfigurationData.items() if decoder['last'] == 1][0]

        configLength = 0
        configString = ''

        condition = 1

        while condition:
            if self.reconfigurationData[currDecoder]['sourceUnit'] == '':
                condition = 0

#            if currDecoder == 'id_X2Y0':
#                self.reconfigurationData[currDecoder]['configData'] = 'XX'

            configData = self.reconfigurationData[currDecoder]['configData']
            configLength += len(configData)
            configString = configData + ('_' if self.reconfigurationData[currDecoder]['last'] != 1 else '') + configString

            currDecoder = self.reconfigurationData[currDecoder]['sourceUnit']

        configString = "'b" + configString
        filedata = filedata.replace("<<CONFIG_LENGTH>>",str(configLength))
        filedata = filedata.replace("<<CONFIG_DATA>>",str(configString))

        pWires = "";

        for connection in pWireNames:
            pWires += "\t\t." + connection + "(),\n"

        filedata = filedata.replace("<<PERIPHERAL_CONNECTIONS>>",pWires)

        perf_regs = "//active counter registers\n"
        perf_counters = "//counters\n"
        perf_reset = "//reset counters\n"
        perf_write = "//write counters to file\n"

        for functionalUnit in self.drc.config.functionalUnits:
            if self.drc.config.functionalUnits[functionalUnit]['@type'] in ['ID','IU']:
                perf_regs += "\t\t\treg [INTERFACE_WIDTH-1:0] rCounter_" + functionalUnit + ";\n";
                unitPath = "dut."+self.designName.upper()+"_Core_inst."+self.designName.upper()+"_Compute_Wrapper_inst."+self.designName.upper()+"_Compute_inst."+functionalUnit+"_inst"
                counterPath = "dut."+self.designName.upper()+"_Core_inst."+self.designName.upper()+"_Compute_Wrapper_inst"

                perf_counters += "\t\t\t\t\tif("+unitPath+".iInstruction != 0 & !"+unitPath+".rStall)\n\t\t\t\t\t\trCounter_"+functionalUnit+" <= rCounter_"+functionalUnit+" + 1'd1;\n"
                perf_reset += "\t\t\t\t\trCounter_"+functionalUnit+" <= 0;\n"
                perf_write += "\t\t\t\t\t\t$fwrite(file_perf,\"active cycles ("+functionalUnit+"): %d, utilization: %d percent\\n\", rCounter_"+functionalUnit+", (rCounter_"+functionalUnit+"*100)/("+counterPath+".rCycleCounter - "+counterPath+".rStallCounter));\n" 

        filedata = filedata.replace("<<PERF_REGS>>", perf_regs)
        filedata = filedata.replace("<<PERF_COUNTERS>>", perf_counters)
        filedata = filedata.replace("<<PERF_RESET>>", perf_reset)
        filedata = filedata.replace("<<PERF_WRITE>>", perf_write)

        f = open(outDir + "/" + outputFile,'w')
        f.write(filedata)
        f.close

    def __init__(self, fname, designName, templateDir, outDir, outputDOT, buildNW, magicLoad, memsyn, configOut=None):

        if os.path.exists(outDir):
            shutil.rmtree(outDir)
        os.makedirs(outDir)

        #scan the template dir and all subfolder for templates and put them in a dictionary
        templates=TemplateDB(templateDir)

        self.designName = designName
        self.magicLoad = magicLoad
        self.memsyn = memsyn

        print "----------------------------------------------"
        print "Elaborating design '" +self.designName + "'"
        print "----------------------------------------------"        

        if int(buildNW) == 1:
            print 'INFO: Generating design with switchbox network'
        else:
            print 'INFO: Generating design WITHOUT switchbox network (direct connections)'

        print "- Loading design and DRC check ..."
        self.drc = DRC(fname, int(buildNW))
        self.decodedWidth = int(self.drc.config['Core']['DecodedInstructions']['@width'])

        if outputDOT!=None and int(buildNW) == 0:
            print "- Exporting DOT graph ..."
            self.exportDot(outputDOT)

        print "- Exporting Verilog ..."
        self.__getPathWidths()

        print "\tData path width   :", self.dataWidth
        print "\tInstruction width :", self.instructionWidth
        print "\tImmediate width   :", self.immediateWidth
        print "\tDecoded width     :", self.decodedWidth        

        print "\n\t- exporting compute description and wrapper ..."
        self.__exportComputeVerilog(self.designName + '_compute.v', self.designName + '_compute_wrapper.v', templates,outDir, int(buildNW), configOut=configOut)

        print "\t- exporting memory description ..."
        self.__exportMemoryVerilog(self.designName + '_memory.v', templates,outDir)

        print "\t- exporting top-level description ..."
        self.__exportCoreVerilog(self.designName + '_core.v', templates,outDir)
        print "\t\t+ FPGA"
        pWireNames = self.__exportTopLevelVerilog(self.designName + "_fpgatop.v", templates,outDir, True)
        print "\t\t+ Simulation"
        pWireNames = self.__exportTopLevelVerilog(self.designName + "_top.v", templates,outDir, False)

        print "\t- exporting testbench ..."
        self.__exportTestbenchVerilog(self.designName + '_testbench.v', templates,outDir,pWireNames)


if __name__ == "__main__":

    Cfg = Instantiate("binarization.xml","binarization","./templates/","./generated/")
