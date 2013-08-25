'''
This script is part of the FURWARE texture creator, a texture
generation script for the FURWARE text text-on-prim script
for Second Life(R).

Please see the included README and LICENSE files in the root
directory for more information.
'''

'''
This script is used to build a pre-compiled convenience package of
the creator for Windows users using py2exe (http://www.py2exe.org/).
'''

from distutils.core import setup
import py2exe
 
setup(console=['TextureCreator.py'])
