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
import xmltodict

class Config():
    def __init__(self, fname):
        self.fname=fname

        #list of files that are included when this config was parsed
        self.includeFiles=[]

        #parse the config file
        self.config=self.__parse(fname)

        #find and store instructions per instructiontype, listed by their mnemonic name
        self.instructions={}

        #first create dictionary with entries for all defined instruction types
        for instTypeName in self.config['ISA']['instructiontypes']:
            self.instructions[instTypeName]={} 

		#go through instructions and collect under correct type
        for instrName, inst in self.config['ISA']['instructions'].items():
            if isinstance(inst, list):
                raise ValueError("instruction '%s' defined more than once! Check the config file"%instrName)

            if inst['@type'] not in self.instructions:
                raise ValueError("instruction with undefined type "+str(inst['@type']))
            self.instructions[inst['@type']][inst['@mnemonic']]=inst

        #find and store functional units and their connections
        self.functionalUnits={}
        if 'functionalunits' in self.config['configuration']:
            for fulistname, fulist in self.config['configuration']['functionalunits'].items():
                for fu in fulist:
                    if fu['@name'] in self.functionalUnits:
                        raise ValueError("functional unit name '%s' defined more than once! Check the config file"%fu['@name'])

                    if fu['@type'] not in self.config['configuration']['functionalunittypes']:
                        raise ValueError("functional unit with undefined type: "+str(fu['@type']))

                    self.functionalUnits[fu['@name']] = dict(fu.items() + self.config['configuration']['functionalunittypes'][fu['@type']].items())
		
        #search the HDL parameters defined in the configuration
        self.hdl_params=self.__collectHDLParams(self.config)

    def __collectHDLParams(self, cfg):
        #if leaf, return (should not happen, we select leafs by the @ sign)
        if not isinstance(cfg, dict):
            return {}

        #add params of this leaf
        if '@hdl_param' in cfg:
            value=cfg[[key for key in cfg if key!='@hdl_param' and key[0]=='@'][0]]
            key = cfg['@hdl_param']
            params={key:value}

            #remove hdl_param entries from the config
            del cfg['@hdl_param']
        else:
            params={}

        #for each branch, explore
        for key in cfg:
            if key[0]!='@':
                params.update(self.__collectHDLParams(cfg[key]))

        return params

    def __parse(self, fname):
        with open(fname, 'rt') as f:
            config=xmltodict.parse(f.read())
        config=config['architecture']
        
        #recursively resolve includes
        if 'Includes' in config:
            for key, params in config['Includes'].items():
                if not '@file' in params:
                    print 'Warning, found include in file %s, but no "file" was specified'%(self.fname)
                    continue
                incFile = params['@file']

                #incFile is relative to the parent file, so resolve the actual path!
                parent_dir=os.path.dirname(fname)
                incFile=os.path.normpath(os.path.join(parent_dir, incFile))

                #include the file and merge the configs
                inc_config = self.__parse(incFile)
                config = self.__merge(config, inc_config)

                #add the include file to list of included files
                self.includeFiles+=[incFile]

            #remove the includes field after processing
            del config['Includes']

        return config

    def __merge(self, cfg_root, cfg_leaf):
        #merge two configurations
        #root overrides the leaf
        for key in cfg_root:
            #check if override attribute is true
            override = ('@override' in cfg_root[key]) and (cfg_root[key]['@override'].lower()=='true')

            if (key[0]!='@') and (key in cfg_leaf) and (not override):
                #add to the leaf node
                cfg_leaf[key]=self.__merge(cfg_root[key], cfg_leaf[key])
            else:
                #override the leaf node
                cfg_leaf[key]=cfg_root[key]

            #remove the override attribute after processing
            if override:
                del cfg_leaf[key]['@override']
        
        return cfg_leaf

    def xml(self): 
        from dicttoxml import dicttoxml
        return xmltodict.unparse({'architecture':self.config},pretty=True)

    def save(self, fname):
        with open(fname, 'wt') as f:
            f.write(self.xml())

    def __getitem__(self, key):
        if key not in self.config:
            raise KeyError
        return self.config[key]

    def __str__(self):
        import json
        return json.dumps(self.config, indent=4)

if __name__ == "__main__":
    Cfg = Config("../../Configurations/default.xml")
    #print Cfg.hdl_params
    print Cfg
