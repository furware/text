'''
This script is part of the FURWARE texture creator, a texture
generation script for the FURWARE text text-on-prim script
for Second Life(R).

Please see the included README and LICENSE files in the root
directory for more information.
'''

'''
This script is the heart of the texture creator. It creates a
texture, executes script files to perform actions on it and
writes the result out to an image file.
'''

import cairo
import itertools
import math
import os

from . import FontFaceCreator
from . import TGAWriter
from ScriptReader import ScriptReader

OUTPUT_DIR = "output"
SCRIPTS_DIR = "scripts"

class GridConfig:
    def __init__(self, args):
        self.imageSize    = (args[0], args[1])
        self.cellSize     = (32, 64)
        self.begin        = (32, 44)
        self.spacing      = (40, 72)
        self.cellCount    = (25, 14)

class CharConfig:
    def __init__(self, args):
        self.offsetX = args[0]
        self.offsetY = args[1]
        self.scaleX  = args[2]
        self.scaleY  = args[3]

class FontConfig:
    def __init__(self, fontConfPath):
        self.offsetX = 0
        self.offsetY = 0
        self.offsetXUnit = ""
        self.offsetYUnit = ""
        self.perCharConfigs = {}
        self.guessingChar = "X"
        self.scale = 0.75
        self.scaleUnit = "cellHeight"
        self.autoShrink = False

        if not os.path.exists(fontConfPath):
            return

        fontConf = ScriptReader(fontConfPath)

        while fontConf.more():
            if fontConf.getCmd() == "offset":
                [self.offsetX, self.offsetY, self.offsetXUnit, self.offsetYUnit] = fontConf.getArgs([int, int, str, str])

            elif fontConf.getCmd() == "scale":
                [self.scale, self.scaleUnit] = fontConf.getArgs([float, str])
            
            elif fontConf.getCmd() == "guessingChar":
                self.guessingChar = fontConf.getArgs([unicode])[0]

            elif fontConf.getCmd() == "enableAutoShrink":
                self.autoShrink = True
            
            elif fontConf.getCmd() == "charOffset":
                args = fontConf.getArgs([unicode, int, int, float, float])
                self.perCharConfigs[args[0]] = CharConfig(args[1:])

    def getCharConfig(self, char):
        try:
            return self.perCharConfigs[char]
        except KeyError:
            return CharConfig([0, 0, 1.0, 1.0])

class FontExtents:
    def __init__(self, cairoContext):
        self.cairoContext = cairoContext

    def update(self, text):
        self.xBearing, self.yBearing, self.xSize, self.ySize, self.xAdvance, self.yAdvance \
            = self.cairoContext.text_extents(text)

class TexturePainter:
    def __init__(self, outputName):
        self.debugGrid = False
        self.outputName = outputName
        self.defaultOutputName = outputName

    def runScript(self, scriptName, defaultFont):
        scriptPath = os.path.join(os.path.dirname(defaultFont), scriptName)
        if not os.path.exists(scriptPath):
            # Then try the default scripts directory.
            scriptPath = os.path.join(SCRIPTS_DIR, scriptName)
            if not os.path.exists(scriptPath):
                print("      WARNING: Script \"" + scriptName + "\" not found.")
                return False
        
        script = ScriptReader(scriptPath)
        
        while script.more():
            if script.getCmd() == "runScript":
                if not self.runScript(script.getRawArg(), defaultFont):
                    return False
            
            elif script.getCmd() == "noBuild":
                return False
            
            elif script.getCmd() == "setOutputName":
                self.outputName = script.getRawArg()
            
            elif script.getCmd() == "setOutputNameSuffix":
                self.outputName = self.defaultOutputName + script.getRawArg()
            
            elif script.getCmd() == "init":
                self.init(script.getArgs([int, int, float, float]))
            
            elif script.getCmd() == "setCellSize":
                self.gridConfig.cellSize = script.getArgs([int, int])
            
            elif script.getCmd() == "setCellOffset":
                self.gridConfig.begin = script.getArgs([int, int])
            
            elif script.getCmd() == "setCellSpacing":
                self.gridConfig.spacing = script.getArgs([int, int])
            
            elif script.getCmd() == "setCellCount":
                self.gridConfig.cellCount = script.getArgs([int, int])
            
            elif script.getCmd() == "drawLineBetweenCells":
                self.lineBetweenCells(*[int(arg) for arg in script.getArgs([int, int, int, int, int, int, int, int, int])])
            
            elif script.getCmd() == "drawRectBetweenCells":
                self.rectangleBetweenCells(*[int(arg) for arg in script.getArgs([int, int, int, int, int, int, int, int, int])])
            
            elif script.getCmd() == "drawFilledRectBetweenCells":
                self.rectangleBetweenCells(*[int(arg) for arg in script.getArgs([int, int, int, int, int, int, int, int, int])], filled = True)
            
            elif script.getCmd() == "drawChars":
                for char in script.getRawArg():
                    self.drawChar(char)
            
            elif script.getCmd() == "loadFont":
                fontPath = script.getRawArg()
                if fontPath == "":
                    fontPath = defaultFont
                self.loadFont(fontPath)
            
            elif script.getCmd() == "jumpToCell":
                self.jumpToCell(*script.getArgs([int, int]))
            
            elif script.getCmd() == "drawDebugGrid":
                self.debugGrid = True
                
                self.cairoContext.save()
                self.cairoContext.set_source_rgb(0,0,0)
                self.cairoContext.set_matrix(cairo.Matrix(
                    xx = self.gridConfig.imageSize[0],
                    yy = self.gridConfig.imageSize[1]
                ))
                self.cairoContext.rectangle(0,0,1,1)
                self.cairoContext.fill()
                self.cairoContext.restore()

                self.cairoContext.save()
                self.cairoContext.set_source_rgb(0.5,0.5,0.5)
                thickness = 2
                for y in range(0, self.gridConfig.cellCount[1]):
                    for x in range(0, self.gridConfig.cellCount[0]):
                        dx = self.gridConfig.cellSize[0]/2 + thickness/2
                        dy = self.gridConfig.cellSize[1]/2 + thickness/2
                        self.rectangleBetweenCells(thickness, x, y, x, y, -dx, -dy, dx, dy)
                self.cairoContext.restore()
            
            else:
                print("      ERROR: Unknown script command \"" + script.getCmd() + "\".")
                return False
            
        return True

    def writeTexture(self):
        self.cairoSurface.flush()
        buf = self.cairoSurface.get_data()

        arr = bytearray(buf)

        if not self.debugGrid:
            arr[0::4] = itertools.repeat(255, self.gridConfig.imageSize[0] * self.gridConfig.imageSize[1])
            arr[1::4] = itertools.repeat(255, self.gridConfig.imageSize[0] * self.gridConfig.imageSize[1])
            arr[2::4] = itertools.repeat(255, self.gridConfig.imageSize[0] * self.gridConfig.imageSize[1])

        targetPath = os.path.join(OUTPUT_DIR, self.outputName + ".tga")

        TGAWriter.writeTGA(self.gridConfig.imageSize[0], self.gridConfig.imageSize[1], 8, 32, arr, targetPath)

    def init(self, args):
        imageSizeX = int(math.floor(args[2] * args[0]))
        imageSizeY = int(math.floor(args[3] * args[1]))
        
        self.gridConfig = GridConfig([imageSizeX, imageSizeY])
        
        self.cairoSurface = cairo.ImageSurface(cairo.FORMAT_ARGB32, imageSizeX, imageSizeY)

        self.cairoContext = cairo.Context(self.cairoSurface)
        self.cairoContext.set_matrix(cairo.Matrix(
            xx = args[2], yy = args[3]
        ))

        self.cairoContext.set_source_rgb(1,1,1)

        fontOptions = cairo.FontOptions()
        fontOptions.set_antialias(cairo.ANTIALIAS_GRAY)
        fontOptions.set_hint_style(cairo.HINT_STYLE_NONE)

        self.cairoContext.set_font_options(fontOptions)

        self.currentRow = 0
        self.currentCol = 0

    def loadFont(self, fontPath):
        self.fontConfig = FontConfig(os.path.join(os.path.dirname(fontPath), "font.conf"))

        fontFace = FontFaceCreator.fontFaceFromFile(fontPath)

        self.cairoContext.set_font_face(fontFace)
        self.fontSize = self.fontConfig.scale * self.convertScaleUnit(self.fontConfig.scaleUnit)
        self.cairoContext.set_font_size(self.fontSize)

        self.fontExtents = FontExtents(self.cairoContext)
        self.fontExtents.update(self.fontConfig.guessingChar)

        self.guessedYOffset = self.fontExtents.ySize / 2

    def jumpToCell(self, x, y):
        self.currentCol = int(x)
        self.currentRow = int(y)

    def drawChar(self, char):
        fontSizeX = self.fontSize
        fontSizeY = self.fontSize

        if self.fontConfig.autoShrink:
            self.cairoContext.set_font_size(1)
            self.fontExtents.update(char)

            if self.fontExtents.xSize > 0:
                widthGuess = self.gridConfig.cellSize[0] / self.fontExtents.xSize
                if widthGuess < self.fontSize:
                    fontSizeX = widthGuess
        
        charConfig = self.fontConfig.getCharConfig(char)
        
        fontSizeX *= charConfig.scaleX
        fontSizeY *= charConfig.scaleY
        
        self.cairoContext.set_font_matrix(cairo.Matrix(xx = fontSizeX, yy = fontSizeY))
        self.fontExtents.update(char)

        xOffset = -self.fontExtents.xAdvance / 2
        yOffset = self.guessedYOffset

        xOffset += self.fontConfig.offsetX * self.convertScaleUnit(self.fontConfig.offsetXUnit)
        yOffset += self.fontConfig.offsetY * self.convertScaleUnit(self.fontConfig.offsetYUnit)

        xOffset += charConfig.offsetX
        yOffset += charConfig.offsetY
        
        x = self.gridConfig.begin[0] + self.currentCol * self.gridConfig.spacing[0] + xOffset
        y = self.gridConfig.begin[1] + self.currentRow * self.gridConfig.spacing[1] + yOffset
        
        self.cairoContext.move_to(x, y)
        self.cairoContext.show_text(char)
        
        self.currentCol += 1
        if self.currentCol >= self.gridConfig.cellCount[0]:
            self.currentRow += 1
            self.currentCol = 0

    def cellPos(self, x, y):
        return (
            self.gridConfig.begin[0] + x * self.gridConfig.spacing[0],
            self.gridConfig.begin[1] + y * self.gridConfig.spacing[1]
        )

    def lineBetweenCells(self, lineWidth, x0, y0, x1, y1, dx0 = 0, dy0 = 0, dx1 = 0, dy1 = 0):
        self.cairoContext.set_line_width(lineWidth)
        beg = self.cellPos(x0, y0)
        end = self.cellPos(x1, y1)
        begD = (dx0, dy0)
        endD = (dx1, dy1)
        self.cairoContext.move_to(beg[0]+begD[0], beg[1]+begD[1])
        self.cairoContext.line_to(end[0]+endD[0], end[1]+endD[1])
        self.cairoContext.stroke()

    def rectangleBetweenCells(self, lineWidth, begX, begY, endX, endY, \
                              begDX = 0, begDY = 0, endDX = 0, endDY = 0, filled = False):
        self.cairoContext.set_line_width(lineWidth)
        beg = self.cellPos(begX, begY)
        end = self.cellPos(endX, endY)
        begD = (begDX, begDY)
        endD = (endDX, endDY)
        self.cairoContext.rectangle(
            beg[0]+begD[0],
            beg[1]+begD[1],
            end[0]-beg[0]-begD[0]+endD[0],
            end[1]-beg[1]-begD[1]+endD[1]
        )
        if filled:
            self.cairoContext.fill()
        else:
            self.cairoContext.stroke()

    def convertScaleUnit(self, unitString):
        if unitString == "cellWidth":
            return self.gridConfig.cellSize[0]
        elif unitString == "cellHeight":
            return self.gridConfig.cellSize[1]
        return 1
