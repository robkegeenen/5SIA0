#!/usr/bin/python

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
from jinja2 import Template
from jinja2 import FileSystemLoader
from jinja2.environment import Environment
import imp
import inspect

class Template():
    def __init__(self, templateFile, archFile=None):
        self.loadTemplate(templateFile)

        #Init dictionary of functions that are available in the template
        self.functions={}

        #set config
        self.setArchConf(archFile)

        #add builtin types and functions (min, max, int, float, etc)
        self.addFunctions({ f:eval("__builtins__."+f) for f in dir(__builtins__) if f!='print' and f[0] != "_" and str(eval(f+'.__class__'))=="<type 'type'>"})
        self.addFunctions({ f:eval("__builtins__."+f) for f in dir(__builtins__) if f!='print' and f[0] != "_" and str(eval(f+'.__class__'))=="<type 'builtin_function_or_method'>"})
     
        #add an import function, so a template can import it's own modules dynamically:
        #syntax: {% set re = import("re") %}
        def importModule(moduleName):
            #try to import the specified module
            try:
                f, filename, description=imp.find_module(moduleName) 
                return imp.load_module(moduleName, f, filename, description)
            except ImportError, err:
                print 'ImportError:', err
                return None
        self.addFunctions({'import':importModule})

        from datetime import datetime
        self.addFunctions({'generationDate':datetime.now().strftime('%Y-%M-%d %H:%M')})

        #add some typicall modules by default:
        self.addModule("math", False) #from math import *
        self.addModule("re")          #import re
        self.addModule("os")          #import os
        self.addModule("sys")         #import sys


    def addFunctions(self, d):
        #supply a dictionary with functionName:<function object>
        self.functions.update(d)

    def addFunction(self, func):
        self.addFunctions({func.__name__:func})

    def addVariable(self, varName, value):
        self.addFunctions({varName:value})

    def addModule(self, moduleName, prefixWithModuleName=True):
        #try to import the specified module
        try:
            f, filename, description=imp.find_module(moduleName) 
            mod=imp.load_module(moduleName, f, filename, description)
        except ImportError, err:
            print 'ImportError:', err
            return False

        #if we can prefix, just import the whole module
        #i.e. import Module
        if prefixWithModuleName:
            self.addFunctions({moduleName:mod})
            return True

        #no prefix, just import all the functions 
        #from Module import *
        self.addFunctions({name:func for name, func in inspect.getmembers(mod, inspect.isroutine) if name!='_'})
        return True

    def loadTemplate(self, fname):
        #get template from file
        loader  = FileSystemLoader(os.path.dirname(fname))
        env     = Environment(loader=loader)
        relpath = os.path.relpath(fname, os.path.dirname(fname))
        self.template = env.get_template(relpath)

    def setArchConf(self,archFile):
        if archFile!=None:
            from Config import Config
            cfg = Config(archFile)    
            self.functions['cfg']=cfg
            self.functions['archFile']=os.path.abspath(archFile)

    def render(self, archFile=None):
        self.setArchConf(archFile)
        return self.template.render(self.functions)

    def renderToFile(self, fname, archFile=None):
        with open(fname, 'wt') as f:
            f.write(self.render(archFile))
        return True

if __name__ == "__main__":
    archFile="ArchitectureConfiguration.xml"
    
    t=Template("test.v", archFile)
    t.renderToFile("testOut.v")
