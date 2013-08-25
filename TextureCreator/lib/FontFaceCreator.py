'''
This script is part of the FURWARE texture creator, a texture
generation script for the FURWARE text text-on-prim script
for Second Life(R).

Please see the included README and LICENSE files in the root
directory for more information.
'''

'''
This script loads a font file using the FreeType library
for usage with (py)cairo. This is merely a workaround because
the python binding to cairo currently doesn't support loading
of fonts from a file. The function is based on the code from
http://www.cairographics.org/freetypepython/
'''

import cairo
import ctypes
import ctypes.util

_freetypeInitialized = False

class PycairoContext(ctypes.Structure):
    _fields_ = [
        ("PyObject_HEAD", ctypes.c_byte * object.__basicsize__),
        ("ctx", ctypes.c_void_p),
        ("base", ctypes.c_void_p)
    ]

def fontFaceFromFile(filename):
    global _freetypeInitialized
    global _freetype_so
    global _cairo_so
    global _ft_lib
    global _surface

    CAIRO_STATUS_SUCCESS = 0
    FT_Err_Ok = 0

    if not _freetypeInitialized:
        # Find shared libraries.
        freetypeLibName = ctypes.util.find_library("freetype")
        if not freetypeLibName:
            raise Exception("FreeType library not found.")
        
        cairoLibName = ctypes.util.find_library("cairo")
        if not cairoLibName:
            raise Exception("Cairo library not found.")
        
        _freetype_so = ctypes.CDLL(freetypeLibName)
        _cairo_so = ctypes.CDLL(cairoLibName)

        _cairo_so.cairo_ft_font_face_create_for_ft_face.restype  =  ctypes.c_void_p
        _cairo_so.cairo_ft_font_face_create_for_ft_face.argtypes = [ctypes.c_void_p, ctypes.c_int]
        _cairo_so.cairo_set_font_face.argtypes                   = [ctypes.c_void_p, ctypes.c_void_p]
        _cairo_so.cairo_font_face_status.argtypes                = [ctypes.c_void_p]
        _cairo_so.cairo_status.argtypes                          = [ctypes.c_void_p]

        # Initialize FreeType.
        _ft_lib = ctypes.c_void_p()
        
        if _freetype_so.FT_Init_FreeType(ctypes.byref(_ft_lib)) != FT_Err_Ok:
            raise Exception("Error initialising FreeType library.")

        _surface = cairo.ImageSurface(cairo.FORMAT_A8, 0, 0)

        _freetypeInitialized = True

    # Create FreeType face.
    ftFace = ctypes.c_void_p()
    cairo_ctx = cairo.Context(_surface)
    cairo_t = PycairoContext.from_address(id(cairo_ctx)).ctx

    if _freetype_so.FT_New_Face(_ft_lib, filename.encode("utf-8"), 0, ctypes.byref(ftFace)) != FT_Err_Ok:
        raise Exception("Error creating FreeType font face for " + filename)

    # Create Cairo font face for FreeType face.
    cr_face = _cairo_so.cairo_ft_font_face_create_for_ft_face(ftFace, 0)
    if CAIRO_STATUS_SUCCESS != _cairo_so.cairo_font_face_status(cr_face):
        raise Exception("Error creating cairo font face for " + filename)

    _cairo_so.cairo_set_font_face(cairo_t, cr_face)
    if CAIRO_STATUS_SUCCESS != _cairo_so.cairo_status(cairo_t):
        raise Exception("Error creating cairo font face for " + filename)

    face = cairo_ctx.get_font_face()

    return face
