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

class Template():
    def __init__(self, fname):

        self.filename=fname
        self.name='.'.join(os.path.basename(self.filename).split('.')[0:-1])

        #read file contents into memory
        self.content=None
        if os.path.exists(self.filename) and os.path.isfile(self.filename):
            with open(self.filename, 'rt') as f: 
                self.content = f.read()

    def __str__(self):
        return str(self.content)

    def __repr__(self):
        return self.__str__()


class TemplateDB(dict):
    def __init__(self, dirname, extensions=['.tpl'], *args):
        #init parent class
        dict.__init__(self, args)

        self.dirname=dirname

        #scan directory for files with matching extentions
        self.scanDir(dirname, extensions)
        
    def scanDir(self, dirname, extensions=['.tpl']):
        for root, dirs, files in os.walk(dirname):
            for fname in files:
                for ext in extensions:
                    if fname.endswith(ext):
                        t=Template(os.path.join(os.path.abspath(root), fname))
                        self.__setitem__(t.name, str(t))

    def __getitem__(self, key):
        if key not in self.keys():
            err=['']
            err+=['Trying to access template "%s" that was not found in directory:'%(key)]
            err+=[self.dirname]
            err+=['Availabe templates are:']
            for key in self.keys():
                err+=['\t'+key]
            err+=['Template "%s" not found'%(key)]
            raise Exception('\n  '.join(err))

        return dict.__getitem__(self, key)


