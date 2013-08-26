'''
This script is part of the FURWARE texture creator, a texture
generation script for the FURWARE text text-on-prim script
for Second Life(R).

Please see the included README and LICENSE files in the root
directory for more information.
'''

import struct, array

def writeTGA(width, height, bitsPerColor, bitsPerPixel, data, path):
    FORMAT = "<BBBHHBHHHHBB"
    
    header = struct.pack(FORMAT,
        0,             # Offset
        0,             # ColorType
        2,             # ImageType
        0,             # PaletteStart
        0,             # PaletteLen
        bitsPerColor,  # PalBits
        0,             # XOrigin
        0,             # YOrigin
        width,         # Width
        height,        # Height
        bitsPerPixel,  # BPP
        32             # Orientation
    )

    file = open(path, "wb")
    file.write(header)
    file.write(data)
    file.close()
