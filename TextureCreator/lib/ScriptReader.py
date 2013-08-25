'''
This script is part of the FURWARE texture creator, a texture
generation script for the FURWARE text text-on-prim script
for Second Life(R).

Please see the included README and LICENSE files in the root
directory for more information.
'''

'''
This script is a wrapper for loading script and config files.
'''

import codecs
import re

class ScriptReader:
    def __init__(self, scriptPath):
        scriptFile = codecs.open(scriptPath, "r", "utf-8")
        self.tokenList = []
        self.rawArgList = []
        for line in scriptFile:
            if line[0] == "#":
                continue
            cleanedLine = line.rstrip("\n")
            tokens = cleanedLine.split()
            if len(tokens):
                self.tokenList.append(tokens)
                self.rawArgList.append(cleanedLine[len(tokens[0])+1:])
        scriptFile.close()
        self.curLine = 0
    
    # Shall return True iff there is at least one more line
    # to parse the the moment this function is called.
    def more(self):
        if self.curLine >= len(self.tokenList):
            return False
        
        self.tokens = self.tokenList[self.curLine]
        self.rawArg = self.rawArgList[self.curLine]
        self.curLine += 1
        
        return True
    
    def getCmd(self):
        return self.tokens[0]
    
    def getArgs(self, specs):
        if len(specs)+1 != len(self.tokens):
            raise Exception("Invalid argument list.")
        result = []
        for i in range(0, len(specs)):
            result.append(specs[i](self.tokens[i+1]))
        return result
    
    def getRawArg(self):
        return self.rawArg
