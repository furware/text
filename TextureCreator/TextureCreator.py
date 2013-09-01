'''
This script is part of the FURWARE texture creator, a texture
generation script for the FURWARE text text-on-prim script
for Second Life(R).

Please see the included README and LICENSE files in the root
directory for more information.
'''

'''
This is the main texture creator script. It searches for fonts
and associated configuration files/scripts in the "fonts" directory
and builds textures for them in the "output" directory.
'''

import glob
import os

from lib.TexturePainter import TexturePainter
from lib.ScriptReader import ScriptReader

FONTS_DIR   = "fonts"
SCRIPTS_DIR = "scripts"
OUTPUT_DIR  = "output"

if not os.path.exists(OUTPUT_DIR):
    os.mkdir(OUTPUT_DIR)

# Iterate through all directories in the "fonts" directory.
for fontName in os.listdir(FONTS_DIR):
    fontFilePaths = glob.glob(os.path.join(FONTS_DIR, fontName, "*.[o,t]tf")) \
                  + glob.glob(os.path.join(FONTS_DIR, fontName, "*.[O,T]TF"))
    
    # Ignore this font directory is there are no font files inside it.
    if len(fontFilePaths) < 1:
        continue
    
    # We only care about one/the first font file.
    fontFilePath = fontFilePaths[0]
    
    # Try to use chain files in the font directory first.
    chainFilePaths = glob.glob(os.path.join(FONTS_DIR, fontName, "*.chain"))
    
    if len(chainFilePaths) < 1:
        # If no chain files were found, use the chain files in the "scripts" directory.
        chainFilePaths = glob.glob(os.path.join(SCRIPTS_DIR, "*.chain"))
    
    print("Processing \"" + fontName + "\" (\"" + os.path.basename(fontFilePath) + "\")...")
    
    # Process each chain file one after the other. There may be
    # multiple chain files, for instance for building different
    # resolutions of the same font.
    for chainFilePath in chainFilePaths:
        chainName = os.path.basename(chainFilePath)
        
        print("  Executing chain \"" + chainName + "\"...")

        texturePainter = TexturePainter(fontName)
        
        # The runScript function may tell us to stop (for instance, when
        # the "noBuild" command was given or when an error occurred).
        if not texturePainter.runScript(chainName, fontFilePath):
            continue
        
        # Write out the created texture.
        texturePainter.writeTexture()

raw_input("\nDone processing, press return to exit.\n")
