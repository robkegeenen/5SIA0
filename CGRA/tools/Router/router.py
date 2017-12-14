#!/usr/bin/env python2.7

import wx
import wx.lib.scrolledpanel
import xmltodict
import os
import heapq
import re
import random
import time
import copy
import collections
import sys
from pprint import pprint
from ast import literal_eval as make_tuple

class app(wx.Frame):
    def __init__(self):
        self.X_dist = 170
        self.Y_dist = 170
        self.FU_X_size = 70
        self.FU_Y_size = 70
        self.SWB_X_offset = 70
        self.SWB_Y_offset = 70
        self.SWB_X_size = 55
        self.SWB_Y_size = 55
        self.step_size = 4

        self.colour = {'MUL': 'dodgerblue', 'ID': 'lime', 'IU': 'forestgreen', 'RF': 'yellow', 'LSU': 'red', 'ABU': 'violet', 'ALU': 'lightblue'}
        self.pathColors = ['#0000FF','#00FF00','#FF0000']

        self.scale = 1.0
        self.dirname = ""
        self.filename = ""
        self.configData = {}
        self.prData = {}
        self.prData['place_and_route'] = {}
        self.prData['place_and_route']['route'] = {}
        self.prData['place_and_route']['route']['data'] = {}
        self.prData['place_and_route']['route']['control'] = {}
        self.prData['place_and_route']['place'] = {}
        self.prData['place_and_route']['place']['fu'] = []
        self.buttonInfo = {}
        self.selectedFU = ()
        self.highlightPath = {}

        # Every wx app must create one App object
        # before it does anything else using wx.
        self.app = wx.App()

        # Set up the main window
        self.frame = wx.Frame.__init__(self, parent=None, title='CGRA viewer', size=(900, 900))
        #self.panel = wx.Panel(self)        

        screenSize = wx.DisplaySize()
        self.screenWidth = screenSize[0]
        self.screenHeight = screenSize[1]        

        self.panel = wx.lib.scrolledpanel.ScrolledPanel(self,-1) #, size=(self.screenWidth ,self.screenHeight), pos=(0,0), style=wx.SIMPLE_BORDER)
        self.panel.SetupScrolling()
        self.panel.SetBackgroundColour('#C0C0C0')
        self.panel.Bind(wx.EVT_PAINT, self.event_DrawConnections)
        self.panel.Bind(wx.EVT_RIGHT_DOWN, self.event_RightClickPanel)


        self.statusbar = self.CreateStatusBar()
        self.SetStatusBar(self.statusbar)	       

        self.menubar = wx.MenuBar()
        self.build_menu()
        self.SetMenuBar(self.menubar)

        self.toolbar = self.CreateToolBar()
        self.build_toolbar()
        self.toolbar.Realize()        
     
    def build_menu(self):
        open_menu = wx.Menu()
        open_CGRADescription = open_menu.Append(wx.ID_ANY, 'CGRA description ...')
        open_PlaceAndRoute = open_menu.Append(wx.ID_ANY, 'Place and route ...')        

        file_menu = wx.Menu()
        new_PlaceAndRoute = file_menu.Append(wx.ID_NEW, '&New')
        open_f = file_menu.AppendMenu(wx.ID_ANY, '&Open', open_menu)
        save_placeAndRoute = file_menu.Append(wx.ID_SAVE, '&Save P&R as ...')
        file_menu.AppendSeparator()
        menu_quit = wx.MenuItem(file_menu, wx.ID_EXIT, '&Quit\tCtrl+W')
        file_menu.AppendItem(menu_quit)

        #bind menu clicks to functions
        self.Bind(wx.EVT_MENU, self.event_openCGRADescription, open_CGRADescription)
        self.Bind(wx.EVT_MENU, self.event_openPlaceAndRoute, open_PlaceAndRoute)     
        self.Bind(wx.EVT_MENU, self.event_SavePlaceAndRoute, save_placeAndRoute)            
        self.Bind(wx.EVT_MENU, self.event_NewPlaceAndRoute, new_PlaceAndRoute)      

        self.menubar.Append(file_menu, '&File')      

    def build_toolbar(self)  :
        self.toolbar_ShowDataNetwork = self.toolbar.AddRadioTool(wx.ID_ANY, bitmap = wx.Bitmap('png/62.png'), shortHelp='View data network')
        self.toolbar_ShowControlNetwork = self.toolbar.AddRadioTool(wx.ID_ANY, bitmap = wx.Bitmap('png/61.png'), shortHelp='View control network')
        self.toolbar.AddSeparator()
        #self.toolbar_ZoomOut = self.toolbar.AddRadioTool(wx.ID_ANY, bitmap = wx.Bitmap('png/14.png'), shortHelp='Zoom out')
        #self.toolbar_ZoomIn = self.toolbar.AddRadioTool(wx.ID_ANY, bitmap = wx.Bitmap('png/13.png'), shortHelp='Zoom in')
        #self.toolbar.AddSeparator()

        self.Bind(wx.EVT_MENU, self.event_ChangeNetwork, self.toolbar_ShowDataNetwork)
        self.Bind(wx.EVT_MENU, self.event_ChangeNetwork, self.toolbar_ShowControlNetwork)

        #self.Bind(wx.EVT_MENU, self.event_ZoomOut, self.toolbar_ZoomOut)
        #self.Bind(wx.EVT_MENU, self.event_ZoomIn, self.toolbar_ZoomIn)

    def clearPanel(self, newWidth, newHeight):
        self.panel.Destroy()
        self.panel = wx.lib.scrolledpanel.ScrolledPanel(self,-1, size=(newWidth ,newHeight), pos=(0,0), style=wx.SIMPLE_BORDER)
        self.panel.SetupScrolling()
        self.panel.SetBackgroundColour('#C0C0C0')    
        self.panel.Bind(wx.EVT_PAINT, self.event_DrawConnections) 
        self.panel.Bind(wx.EVT_RIGHT_DOWN, self.event_RightClickPanel)
        self.Refresh()   

    def processConfig(self):
        maxX = 0
        maxY = 0
        functionalUnits = self.configData['architecture']['configuration']['functionalunits']['fu']

        for FU in functionalUnits:  
            if int(FU['@Xloc']) > maxX:
                maxX = int(FU['@Xloc'])
                            
            if int(FU['@Yloc']) > maxY:
                maxY = int(FU['@Yloc'])

        self.clearPanel((maxX+2)*self.X_dist, (maxY+2)*self.Y_dist)        
        self.buttonInfo = {}
        self.selectedFU = ()

        networks = self.configData['architecture']['network']

        for swb in networks:            
            Xloc = int(swb.split('_')[0].replace('X',''))
            Yloc = int(swb.split('_')[1].replace('Y',''))
            button = wx.Button(self.panel,name=swb, label="SWB",pos=((self.X_dist*(Xloc+1)-self.SWB_X_offset)*self.scale,(self.Y_dist*(Yloc+1)-self.SWB_Y_offset)*self.scale),size=(self.SWB_X_size*self.scale,self.SWB_Y_size*self.scale))     
            button.Bind(wx.EVT_BUTTON, self.event_clickSWB)            
            button.SetFont(wx.Font(10 * self.scale, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL,True))           
            button.SetToolTip(wx.ToolTip("X: " + str(Xloc) + "    Y: " + str(Yloc)))

        for FU in functionalUnits:            
            button = wx.Button(self.panel,name=FU['@name'], label=FU['@type'],pos=(self.X_dist*(int(FU['@Xloc'])+1)*self.scale,self.Y_dist*(int(FU['@Yloc'])+1)*self.scale),size=(self.FU_X_size*self.scale,self.FU_Y_size*self.scale))     
            self.buttonInfo[FU['@name']] = (FU['@Xloc'],FU['@Yloc'],button)
            button.Bind(wx.wx.EVT_LEFT_DOWN, self.event_clickFU)                                    
            button.Bind(wx.wx.EVT_RIGHT_DOWN, self.event_rightclickFU)
            button.SetFont(wx.Font(10 * self.scale, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL,True))          
            button.SetToolTip(wx.ToolTip("X: " + FU['@Xloc'] + "    Y: " + FU['@Yloc']))

    #GUI events ----------------------------------------------------------------------------------
    def event_DrawConnections(self, e):        
        canvas = wx.PaintDC(e.GetEventObject())
        self.panel.DoPrepareDC(canvas)
        canvas.Clear()        
        arrows_list =  {'TOP': ((-3,0),(3,0),(0,-3)), 'BOTTOM': ((-3,0),(3,0),(0,3)),
                    'LEFT': ((0,-3),(0,3),(-3,0)), 'RIGHT': ((0,-3),(0,3),(3,0)),
                    'FUInputs': ((0,0),(-3,0),(0,-3)), 'FUOutputs': ((1,0),(4,0),(1,-3))}        

        if self.configData != {}:
            if self.toolbar_ShowDataNetwork.IsToggled():
                network = "data"
            else:
                network = "control"

            networks = self.configData['architecture']['network']

            if self.prData != {}:
                connectionInfo = self.prData['place_and_route']['route'][network]
            else:
                connectionInfo = {}


            for swb in networks:
                #print "-------------------------------", swb

                if connectionInfo == None:
                    connectionInfo = []

                if swb in connectionInfo:
                    if not isinstance(connectionInfo[swb]['connection'],list):
                        swbConnections = [connectionInfo[swb]['connection']]
                    else:
                        swbConnections = connectionInfo[swb]['connection']
                else:
                    swbConnections = {}
                  
                Xloc = int(swb.split('_')[0].replace('X',''))
                Yloc = int(swb.split('_')[1].replace('Y',''))      

                highlight = []

                if self.selectedFU != () and self.highlightPath != {}:                    
                    if swb in self.highlightPath:
                        highlight = self.highlightPath[swb]

                if 'inputs' in networks[swb][network]:
                    nrInputs = int(networks[swb][network]['inputs'])
                    centerXswb = ((self.X_dist*(Xloc+1)-self.SWB_X_offset+self.SWB_X_size/2)*self.scale)
                    centerYswb = ((self.Y_dist*(Yloc+1)-self.SWB_Y_offset+self.SWB_Y_size/2)*self.scale)
                    centerXfu = ((self.X_dist*(Xloc+1)+self.FU_X_size/2)*self.scale)
                    centerYfu = ((self.Y_dist*(Yloc+1)+self.FU_Y_size/2)*self.scale)
                    offset = self.step_size*self.scale*(nrInputs-1)
                    
                    for i in range(0,nrInputs):
                        canvas.SetPen(wx.Pen('#A0A0A0',2*self.scale)) 
                        for connection in swbConnections:                                  
                            if connection['@destination'].split('.')[0] == "FUInputs" and int(connection['@destination'].split('.')[1]) == int(i):
                                canvas.SetPen(wx.Pen('#A00000',2*self.scale))               
                            for paths in highlight:                                
                                if paths[1].split('.')[0] == "FUInputs" and int(paths[1].split('.')[1]) == int(i): 
                                    canvas.SetPen(wx.Pen(paths[2],2*self.scale))                                              
                        canvas.DrawLine(centerXswb+offset/2-self.step_size*self.scale*(nrInputs-1-i), centerYswb-offset/2+self.step_size*self.scale*(nrInputs-1-i), centerXfu+offset/2-self.step_size*self.scale*(nrInputs-1-i), centerYfu-offset/2+self.step_size*self.scale*(nrInputs-1-i)) 
      
                if 'outputs' in networks[swb][network]:
                    nrOutputs = int(networks[swb][network]['outputs'])
                    centerXswb = ((self.X_dist*(Xloc+1)-self.SWB_X_offset+self.SWB_X_size/2)*self.scale)
                    centerYswb = ((self.Y_dist*(Yloc+1)-self.SWB_Y_offset+self.SWB_Y_size/2)*self.scale)
                    centerXfu = ((self.X_dist*(Xloc+1)+self.FU_X_size/2)*self.scale)
                    centerYfu = ((self.Y_dist*(Yloc+0)+self.FU_Y_size/2)*self.scale)
                    offset = self.step_size*self.scale*(nrOutputs-1)                    

                    for i in range(0,nrOutputs):
                        canvas.SetPen(wx.Pen('#A0A0A0',2*self.scale))  
                        for connection in swbConnections:           
                            if connection['@source'].split('.')[0] == "FUOutputs" and int(connection['@source'].split('.')[1]) == int(i):                                
                                canvas.SetPen(wx.Pen('#A00000',2*self.scale))              
                            for paths in highlight:                                
                                if paths[0].split('.')[0] == "FUOutputs" and int(paths[0].split('.')[1]) == int(i): 
                                    canvas.SetPen(wx.Pen(paths[2],2*self.scale))              
                        canvas.DrawLine(centerXswb-offset/2+self.step_size*self.scale*i, centerYswb-offset/2+self.step_size*self.scale*i, centerXfu-offset/2+self.step_size*self.scale*i, centerYfu-offset/2+self.step_size*self.scale*i) 


                for port in networks[swb][network]['ports']:
                    port = make_tuple(port)                
                    
                    if port[0] == 'RIGHT':
                        separation = ((self.SWB_Y_size-10)/2)/(int(port[1])+1)                        
                        for i in range(0,int(port[1])):   
                            canvas.SetPen(wx.Pen('#A0A0A0',2*self.scale))        
                            for connection in swbConnections:                                  
                                if connection['@destination'].split('.')[0] == port[0] and int(connection['@destination'].split('.')[1]) == int(i):
                                    canvas.SetPen(wx.Pen('#A00000',2*self.scale))  
                                for paths in highlight:                                
                                    if paths[1].split('.')[0] == port[0] and int(paths[1].split('.')[1]) == int(i): 
                                        canvas.SetPen(wx.Pen(paths[2],2*self.scale))                                                       
                            Y = ((self.Y_dist*(Yloc+1)-self.SWB_Y_offset+self.SWB_Y_size/2-separation*(int(port[1])-i))*self.scale)
                            X = ((self.X_dist*(Xloc+1)-self.SWB_X_offset+self.SWB_X_size)*self.scale)
                            L = (self.X_dist - self.SWB_X_size)*self.scale
                            canvas.DrawPolygon(arrows_list[port[0]], xoffset=X+L-3*self.scale, yoffset=Y)
                            canvas.DrawLine(X, Y, X+L, Y)                                         
                    if port[0] == 'LEFT':
                        separation = ((self.SWB_Y_size-10)/2)/(int(port[1])+1)                        
                        for i in range(0,int(port[1])):             
                            canvas.SetPen(wx.Pen('#A0A0A0',2*self.scale))               
                            for connection in swbConnections:                                  
                                if connection['@destination'].split('.')[0] == port[0] and int(connection['@destination'].split('.')[1]) == int(i):
                                    canvas.SetPen(wx.Pen('#A00000',2*self.scale))                                           
                                for paths in highlight:                                
                                    if paths[1].split('.')[0] == port[0] and int(paths[1].split('.')[1]) == int(i): 
                                        canvas.SetPen(wx.Pen(paths[2],2*self.scale))                                                       
                            Y = ((self.Y_dist*(Yloc+1)-self.SWB_Y_offset+self.SWB_Y_size/2+separation*(int(port[1])-(int(port[1])-1-i)))*self.scale)
                            X = ((self.X_dist*(Xloc)-self.SWB_X_offset+self.SWB_X_size)*self.scale)
                            L = (self.X_dist - self.SWB_X_size)*self.scale
                            canvas.DrawPolygon(arrows_list[port[0]], xoffset=X+3*self.scale, yoffset=Y)
                            canvas.DrawLine(X, Y, X+L, Y)                                   
                    if port[0] == 'BOTTOM':
                        separation = ((self.SWB_X_size-10)/2)/(int(port[1])+1)
                        for i in range(0,int(port[1])):                            
                            canvas.SetPen(wx.Pen('#A0A0A0',2*self.scale))
                            for connection in swbConnections:                                  
                                if connection['@destination'].split('.')[0] == port[0] and int(connection['@destination'].split('.')[1]) == int(i):
                                    canvas.SetPen(wx.Pen('#A00000',2*self.scale))                                           
                                for paths in highlight:                                
                                    if paths[1].split('.')[0] == port[0] and int(paths[1].split('.')[1]) == int(i): 
                                        canvas.SetPen(wx.Pen(paths[2],2*self.scale))                                                       
                            X = ((self.X_dist*(Xloc+1)-self.SWB_X_offset+self.SWB_X_size/2-separation*(int(port[1])-i))*self.scale)
                            Y = ((self.Y_dist*(Yloc+1)-self.SWB_Y_offset+self.SWB_Y_size)*self.scale)
                            L = (self.Y_dist - self.SWB_Y_size)*self.scale
                            canvas.DrawPolygon(arrows_list[port[0]], xoffset=X, yoffset=Y+L-3*self.scale)
                            canvas.DrawLine(X, Y, X, Y+L)                                      
                    if port[0] == 'TOP':
                        separation = ((self.SWB_X_size-10)/2)/(int(port[1])+1)
                        for i in range(0,int(port[1])):                            
                            canvas.SetPen(wx.Pen('#A0A0A0',2*self.scale))
                            for connection in swbConnections:                                  
                                if connection['@destination'].split('.')[0] == port[0] and int(connection['@destination'].split('.')[1]) == int(i):
                                    canvas.SetPen(wx.Pen('#A00000',2*self.scale))                                           
                                for paths in highlight:                                
                                    if paths[1].split('.')[0] == port[0] and int(paths[1].split('.')[1]) == int(i): 
                                        canvas.SetPen(wx.Pen(paths[2],2*self.scale))                                                       
                            X = ((self.X_dist*(Xloc+1)-self.SWB_X_offset+self.SWB_X_size/2+separation*(int(port[1])-(int(port[1])-1-i)))*self.scale)
                            Y = ((self.Y_dist*(Yloc)-self.SWB_Y_offset+self.SWB_Y_size)*self.scale)
                            L = (self.Y_dist - self.SWB_Y_size)*self.scale
                            canvas.DrawPolygon(arrows_list[port[0]], xoffset=X, yoffset=Y+3*self.scale)
                            canvas.DrawLine(X, Y, X, Y+L)  

    def event_openCGRADescription(self,e):  
        dlg = wx.FileDialog(self, "Choose CGRA description", self.dirname, "", "*.xml", wx.OPEN)

        if dlg.ShowModal() == wx.ID_OK:
            self.filename = dlg.GetFilename()
            self.dirname = dlg.GetDirectory()

            self.configData = xmltodict.parse(open(os.path.join( self.dirname, self.filename), 'r').read())

            if 'architecture' in self.configData:
                self.processConfig()
                self.prData = {}
                self.prData['place_and_route'] = {}
                self.prData['place_and_route']['route'] = {}
                self.prData['place_and_route']['route']['data'] = {}
                self.prData['place_and_route']['route']['control'] = {}
                self.prData['place_and_route']['place'] = {}
                self.prData['place_and_route']['place']['fu'] = []
            else:
                print "Wrong file type, did you load an instance info?"

        dlg.Destroy()
        self.Refresh()

    def event_openPlaceAndRoute(self,e):      
        dlg = wx.FileDialog(self, "Choose Place and Route file", self.dirname, "", "*.xml", wx.OPEN)

        if dlg.ShowModal() == wx.ID_OK:
            self.filename = dlg.GetFilename()
            self.dirname = dlg.GetDirectory()

            self.prData = xmltodict.parse(open(os.path.join( self.dirname, self.filename), 'r').read())

            if 'place_and_route' in self.prData:
                #self.processPR()
                print
            else:
                print "Wrong file type, did you load a place and route file?"

        dlg.Destroy()


        #self.buttonInfo["id_X2Y3"][2].SetLabel("Here!")
        for fu in self.prData['place_and_route']['place']['fu']:
            locName = 'X' + fu['@Xloc'] + 'Y' + fu['@Yloc']

            for button in self.buttonInfo:
                btnLoc = button.rsplit('_',1)
                if locName == btnLoc[1]:                    
                    self.buttonInfo[button][2].SetBackgroundColour(self.colour[fu['@type']])
                    self.buttonInfo[button][2].SetLabel(fu['@name'])
            

        self.Refresh()

    def event_SavePlaceAndRoute(self, e):
        dlg = wx.FileDialog(self, "Choose a file", self.dirname, "", "*.xml", \
                wx.SAVE | wx.OVERWRITE_PROMPT)

        if dlg.ShowModal() == wx.ID_OK:
            self.filename = dlg.GetFilename()
            self.dirname = dlg.GetDirectory()

            file_handler = open(os.path.join(self.dirname, self.filename), 'w')
            xmltodict.unparse(self.prData, output = file_handler, pretty=True)

            file_handler.close()

        dlg.Destroy()    

    def event_NewPlaceAndRoute(self, e):
        self.prData = {}
        self.prData['place_and_route'] = {}
        self.prData['place_and_route']['route'] = {}
        self.prData['place_and_route']['route']['data'] = {}
        self.prData['place_and_route']['route']['control'] = {}
        self.prData['place_and_route']['place'] = {}
        self.prData['place_and_route']['place']['fu'] = []

        for button in self.buttonInfo:
            self.buttonInfo[button][2].SetBackgroundColour(wx.NullColour)

            for fu in self.configData['architecture']['configuration']['functionalunits']['fu']:
                if fu['@name'] == button:
                    self.buttonInfo[button][2].SetLabel(fu['@type'])    

        self.Refresh()

    def event_clickFU(self, e):
        button = e.GetEventObject()
        self.buttonFU = button
        self.fuframe = wx.Frame(self,style=wx.DEFAULT_FRAME_STYLE & ~wx.RESIZE_BORDER, size=(300, 200) )      
        self.fuframe.MakeModal(True)
        self.fuframe.Bind(wx.EVT_CLOSE, self.event_CloseFUFrame)
        self.fuframe.panel = wx.Panel(self.fuframe, wx.ID_ANY)
          
        self.fuInfo = {}
        functionalUnits = self.configData['architecture']['configuration']['functionalunits']['fu']
        for fu in functionalUnits:
            if fu['@name'] == button.GetName():                
                self.fuInfo = fu

        stallgroups = []
        for i in range(0,int(self.configData['architecture']['configuration']['stallgroups']['@number'])):
            stallgroups.append(str(i))

        if self.prData != {}:
            placeInfo = self.prData['place_and_route']['place']
        else:
            placeInfo = {}

        self.fuPlaceInfo = {}
        if 'fu' in placeInfo:
            for fu in placeInfo['fu']:
                if fu['@Xloc'] == self.fuInfo['@Xloc'] and fu['@Yloc'] == self.fuInfo['@Yloc']:
                    self.fuPlaceInfo = fu

        self.fuframe.lbl1 = wx.StaticText(self.fuframe.panel,-1,style = wx.ALIGN_RIGHT, label="maps to:", pos=(10,10))
        self.fuframe.name = wx.TextCtrl(self.fuframe.panel, size=(180, 30), pos=(100,0))
        if self.fuPlaceInfo != {}:
            self.fuframe.name.AppendText(self.fuPlaceInfo['@name'])

        if 'reconfiguration' in self.fuInfo:
            if int(self.fuInfo['reconfiguration']['@bits']) > 0:
                self.fuframe.lbl2 = wx.StaticText(self.fuframe.panel,-1,style = wx.ALIGN_RIGHT, label="configuration:", pos=(10,50))
                self.fuframe.config = wx.TextCtrl(self.fuframe.panel, size=(180, 30), pos=(100,40))
                if self.fuPlaceInfo != {}:
                    self.fuframe.config.AppendText(self.fuPlaceInfo['@config'])


        if self.fuInfo['@type'] in ['ID', 'ABU', 'LSU','IU']:
            self.fuframe.lbl3 = wx.StaticText(self.fuframe.panel,-1,style = wx.ALIGN_RIGHT, label="stall group:", pos=(10,90))
            self.fuframe.stallgroup = wx.Choice(self.fuframe.panel,-1,size=(180,30),pos=(100,80),choices=stallgroups)

            if self.fuPlaceInfo != {}:
                self.fuframe.stallgroup.SetSelection(int(self.fuPlaceInfo['@stallgroup']))
            #else:
                #self.fuframe.stallgroup.SetSelection(0)

        self.fuframe.buttonSave = wx.Button(self.fuframe.panel,name="btnSave", label="Save placement",size=(150,50), pos=(0,150))     
        self.fuframe.buttonDel = wx.Button(self.fuframe.panel,name="btnDel", label="Remove placement",size=(150,50), pos=(150,150))   
        self.fuframe.buttonSave.Bind(wx.wx.EVT_LEFT_DOWN, self.event_clickFUSave)                                    
        self.fuframe.buttonDel.Bind(wx.wx.EVT_LEFT_DOWN, self.event_clickFUDel)    

        self.fuframe.Show()

    def event_CloseFUFrame(self, e):
        self.fuframe.MakeModal(False)     
        self.fuframe.Destroy()        

    def event_rightclickFU(self, e):        

        button = e.GetEventObject()        
        self.selectedFU = self.buttonInfo[button.GetName()]    
        self.highlightPath = {}    

        swb = 'X' + str(self.selectedFU[0]) + '_Y' + str(int(self.selectedFU[1])+1)

        if self.configData != {}:
            if self.toolbar_ShowDataNetwork.IsToggled():
                network = "data"
            else:
                network = "control"

            networks = self.configData['architecture']['network']

            if self.prData != {}:
                connectionInfo = self.prData['place_and_route']['route'][network]
            else:
                connectionInfo = {}

            if connectionInfo == None:
                connectionInfo = []                

            if swb in connectionInfo:
                if not isinstance(connectionInfo[swb]['connection'],list):
                    swbConnections = [connectionInfo[swb]['connection']]
                else:
                    swbConnections = connectionInfo[swb]['connection']
            else:
                swbConnections = {}       
            
            for connection in swbConnections:      
                if connection['@source'].split('.')[0] == 'FUOutputs':                    
                    #print connection['@source'] + " --> " + connection['@destination'] + '\t (' + str(int(self.selectedFU[0])) + ', ' +  str(int(self.selectedFU[1])+1) + ')'
                    self.recursive_path_follow(1,connection['@destination'], int(self.selectedFU[0]), int(self.selectedFU[1])+1, int(connection['@source'].split('.')[1]))
                    if swb not in self.highlightPath:
                        self.highlightPath[swb] = []
                    
                    self.highlightPath[swb].append( ( connection['@source'],  connection['@destination'], self.pathColors[int(connection['@source'].split('.')[1])]))                    
            
        self.Refresh()

    def recursive_path_follow (self, level, destination, X, Y,index):

        source = None

        if destination.split('.')[0] == 'LEFT':
            source = 'RIGHT.' + str(destination.split('.')[1])
            X = X - 1
            Y = Y

        if destination.split('.')[0] == 'RIGHT':
            source = 'LEFT.' + str(destination.split('.')[1])
            X = X + 1
            Y = Y

        if destination.split('.')[0] == 'TOP':
            source = 'BOTTOM.' + str(destination.split('.')[1])
            X = X
            Y = Y - 1

        if destination.split('.')[0] == 'BOTTOM':
            source = 'TOP.' + str(destination.split('.')[1])
            X = X
            Y = Y + 1

        swb = 'X' + str(X) + '_Y' + str(Y)        

        if self.configData != {} and source != None:
            if self.toolbar_ShowDataNetwork.IsToggled():
                network = "data"
            else:
                network = "control"

            networks = self.configData['architecture']['network']        

            if self.prData != {}:
                connectionInfo = self.prData['place_and_route']['route'][network]
            else:
                connectionInfo = {}

            if connectionInfo == None:
                connectionInfo = []                

            if swb in connectionInfo:
                if not isinstance(connectionInfo[swb]['connection'],list):
                    swbConnections = [connectionInfo[swb]['connection']]
                else:
                    swbConnections = connectionInfo[swb]['connection']
            else:
                swbConnections = {}       

            for connection in swbConnections:   
                if connection['@source'] == source:                    
                    #print int(level)*'\t' + source + " --> " + connection['@destination'] + '\t (' + str(X) + ', ' +  str(Y) + ')'
                    self.recursive_path_follow(level+1,connection['@destination'], X,Y, index)
                    if swb not in self.highlightPath:
                        self.highlightPath[swb] = []
                    
                    self.highlightPath[swb].append ((connection['@source'], connection['@destination'],self.pathColors[index]))


    def event_RightClickPanel(self,e):
        self.selectedFU = ()        
        self.highlightPath = {}
        self.Refresh()

    def event_clickFUSave(self, e): 
        newPlacement = {}
        newPlacement['@type'] = self.fuInfo['@type']
        newPlacement['@Xloc'] = self.fuInfo['@Xloc']
        newPlacement['@Yloc'] = self.fuInfo['@Yloc']
        newPlacement['@name'] = self.fuframe.name.GetValue()        

        if not isinstance(self.prData['place_and_route']['place']['fu'],list):
            self.prData['place_and_route']['place']['fu'] = [self.prData['place_and_route']['place']['fu']]
        else:
            self.prData['place_and_route']['place']['fu'] = self.prData['place_and_route']['place']['fu']

        for fu in self.prData['place_and_route']['place']['fu']:
            if self.fuInfo['@Xloc'] == fu['@Xloc'] and self.fuInfo['@Yloc'] == fu['@Yloc']:
                self.prData['place_and_route']['place']['fu'].remove(fu)

        if 'reconfiguration' in self.fuInfo:
            if int(self.fuInfo['reconfiguration']['@bits']) > 0:
                newPlacement['@config'] = self.fuframe.config.GetValue()

        if self.fuInfo['@type'] in ['ID', 'ABU', 'LSU','IU']:
            newPlacement['@stallgroup'] = self.fuframe.stallgroup.GetString(self.fuframe.stallgroup.GetSelection())

        self.buttonFU.SetBackgroundColour(self.colour[self.fuInfo['@type']])
        self.buttonFU.SetLabel(newPlacement['@name'])
        self.prData['place_and_route']['place']['fu'].append(newPlacement)
        self.fuframe.MakeModal(False)     
        self.fuframe.Destroy()  


    def event_clickFUDel(self, e):    
        if self.fuPlaceInfo != {} and self.prData != {}:
            self.prData['place_and_route']['place']['fu'].remove(self.fuPlaceInfo)
            self.buttonFU.SetBackgroundColour(wx.NullColour)
            self.buttonFU.SetLabel(self.fuInfo['@type'])
            self.fuframe.MakeModal(False)     
            self.fuframe.Destroy()        
        else:
            dlg = wx.MessageDialog(self.fuframe, "Cannot remove FU because it is not placed", "Error", wx.OK | wx.ICON_ERROR)
            dlg.ShowModal()
            dlg.Destroy()            

        
    def event_clickSWB(self, e):
        button = e.GetEventObject()
        swb = button.GetName()
        self.currentSWB = swb
        self.swbframe = wx.Frame(self,style=wx.DEFAULT_FRAME_STYLE & ~wx.RESIZE_BORDER, size=(410, 300))      
        self.swbframe.MakeModal(True)
        self.swbframe.Bind(wx.EVT_CLOSE, self.event_CloseSWBFrame)
        self.swbframe.panel = wx.Panel(self.swbframe, wx.ID_ANY)
        self.swbframe.routes = wx.ListBox(self.swbframe.panel,-1,size=(400,200),pos=(0,0))               
        self.swbframe.buttonAdd = wx.Button(self.swbframe.panel,name="btnAdd", label="Add route",size=(100,50), pos=(0,250))     
        self.swbframe.buttonDel = wx.Button(self.swbframe.panel,name="btnDel", label="Delete route",size=(100,50), pos=(100,250))     
        self.swbframe.buttonAdd.Bind(wx.wx.EVT_LEFT_DOWN, self.event_clickSWBAdd)                                    
        self.swbframe.buttonDel.Bind(wx.wx.EVT_LEFT_DOWN, self.event_clickSWBDel)                                    

        if self.configData != {}:
            if self.toolbar_ShowDataNetwork.IsToggled():
                network = "data"
            else:
                network = "control"

            networks = self.configData['architecture']['network']

            if self.prData != {}:
                connectionInfo = self.prData['place_and_route']['route'][network]
            else:
                connectionInfo = {}

            if connectionInfo == None:
                connectionInfo = []                

            if swb in connectionInfo:
                if not isinstance(connectionInfo[swb]['connection'],list):
                    swbConnections = [connectionInfo[swb]['connection']]
                else:
                    swbConnections = connectionInfo[swb]['connection']
            else:
                swbConnections = {}       

            for connection in swbConnections:      
                self.swbframe.routes.InsertItems([str(connection['@source'] + " --> " + connection['@destination'])],0)        

            inConnectionStrings = []
            outConnectionStrings = []

            for port in networks[swb][network]['ports']:
                port = make_tuple(port)            
                for i in range(0,int(port[1])):
                    inConnectionStrings.append(port[0]+"."+str(i))
                    outConnectionStrings.append(port[0]+"."+str(i))
            if 'inputs' in networks[swb][network]:
                nrInputs = int(networks[swb][network]['inputs'])               
                for i in range(0,nrInputs):
                    outConnectionStrings.append("FUInputs."+str(i))
            if 'outputs' in networks[swb][network]:
                nrOutputs = int(networks[swb][network]['outputs'])
                for i in range(0,nrOutputs):                    
                    inConnectionStrings.append("FUOutputs."+str(i))

            self.swbframe.inputChoice = wx.Choice(self.swbframe.panel,-1,size=(180,30),pos=(0,200),choices=inConnectionStrings)
            self.swbframe.inputChoice.SetSelection(0)
            self.swbframe.lbl1 = wx.StaticText(self.swbframe.panel,-1,style = wx.ALIGN_RIGHT, label="->", pos=(185,200))
            font = wx.Font(24, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL,wx.FONTWEIGHT_NORMAL, False )
            self.swbframe.lbl1.SetFont(font)
            self.swbframe.outputChoice = wx.Choice(self.swbframe.panel,-1,size=(180,30),pos=(220,200),choices=outConnectionStrings)
            self.swbframe.outputChoice.SetSelection(0)

        self.swbframe.Show()

    def event_clickSWBAdd(self, e):        
        newSource = self.swbframe.inputChoice.GetString(self.swbframe.inputChoice.GetSelection())
        newDest = self.swbframe.outputChoice.GetString(self.swbframe.outputChoice.GetSelection())
        
        if self.toolbar_ShowDataNetwork.IsToggled():
            network = "data"
        else:
            network = "control"

        networks = self.configData['architecture']['network']

        if self.prData != {}:
            connectionInfo = self.prData['place_and_route']['route'][network]
        else:
            connectionInfo = {}

        if connectionInfo == None:
            connectionInfo = [] 

        if self.currentSWB in connectionInfo:
            if not isinstance(connectionInfo[self.currentSWB]['connection'],list):
                swbConnections = [connectionInfo[self.currentSWB]['connection']]
            else:
                swbConnections = connectionInfo[self.currentSWB]['connection']
        else:
            swbConnections = {}       

        outputUsed = False
        for connection in swbConnections:               
            if connection['@destination'] == newDest:
                outputUsed = True                

        if not outputUsed:
            if newSource.split('.')[0] != newDest.split('.')[0]:
                if self.prData['place_and_route']['route'][network] == None:
                    self.prData['place_and_route']['route'][network] = {}

                if self.currentSWB not in self.prData['place_and_route']['route'][network]:
                    self.prData['place_and_route']['route'][network][self.currentSWB] = {}

                if 'connection' not in self.prData['place_and_route']['route'][network][self.currentSWB]:
                    self.prData['place_and_route']['route'][network][self.currentSWB]['connection'] = []

                newConnection = {}
                newConnection['@source'] = newSource
                newConnection['@destination'] = newDest
                #pprint(self.prData['place_and_route']['route'][network][self.currentSWB]['connection'])

                if not isinstance(self.prData['place_and_route']['route'][network][self.currentSWB]['connection'],list):
                    self.prData['place_and_route']['route'][network][self.currentSWB]['connection'] = [self.prData['place_and_route']['route'][network][self.currentSWB]['connection']]

                self.prData['place_and_route']['route'][network][self.currentSWB]['connection'].append(newConnection)     
                self.swbframe.routes.InsertItems([str(newConnection['@source'] + " --> " + newConnection['@destination'])],0)   
                self.Refresh()
            else:
                dlg = wx.MessageDialog(self.swbframe, "Cannot use same port for input and output", "Error", wx.OK | wx.ICON_ERROR)
                dlg.ShowModal()
                dlg.Destroy()
        else:
            dlg = wx.MessageDialog(self.swbframe, "The output is already used", "Error", wx.OK | wx.ICON_ERROR)
            dlg.ShowModal()
            dlg.Destroy()

    
    def event_clickSWBDel(self, e):        
        if self.swbframe.routes.GetSelection() >= 0:
            selectedRoute = self.swbframe.routes.GetString(self.swbframe.routes.GetSelection()).split(' --> ')
            remConnection = {}
            remConnection['@source'] = selectedRoute[0]
            remConnection['@destination'] = selectedRoute[1]

            if self.toolbar_ShowDataNetwork.IsToggled():
                network = "data"
            else:
                network = "control"

            if not isinstance(self.prData['place_and_route']['route'][network][self.currentSWB]['connection'],list):
                self.prData['place_and_route']['route'][network][self.currentSWB]['connection'] = [self.prData['place_and_route']['route'][network][self.currentSWB]['connection']]
       
            self.prData['place_and_route']['route'][network][self.currentSWB]['connection'].remove(remConnection)

            if len(self.prData['place_and_route']['route'][network][self.currentSWB]['connection']) == 0:
                self.prData['place_and_route']['route'][network].pop(self.currentSWB)
            self.swbframe.routes.Delete(self.swbframe.routes.GetSelection())

            self.Refresh()
        else:
            dlg = wx.MessageDialog(self.swbframe, "No route selected", "Error", wx.OK | wx.ICON_ERROR)
            dlg.ShowModal()
            dlg.Destroy()            

    def event_CloseSWBFrame(self, e):                
        self.swbframe.MakeModal(False)     
        self.swbframe.Destroy()   

    def event_ChangeNetwork(self, e):      
        self.selectedFU = ()
        self.highlightPath = {}  
        self.Refresh()

    def event_ZoomOut(self, e):
        if self.scale > 0.5:
            self.scale = self.scale - 0.1
            self.Refresh()

    def event_ZoomIn(self, e):
        if self.scale < 2.5:
            self.scale = self.scale + 0.1
            self.Refresh()

    def run(self):
        self.Show()
        self.app.MainLoop()






application = app()
application.run()