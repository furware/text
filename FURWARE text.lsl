////////////////////////////////////////////////////////////
//                                                        //
//                                     _cg####ggi_        //
//                                   _g00000000000o_      //
//                                  ,0000^.omggc.000¡     //
//                                  000   ,F ¯°0#¡000L    //
//  FURWARE text                   #00 ¡ ¡0     000#00 ^  //
//                                 #0 ]O 00      #0 00 #L //
//  Version 2.0.1-git               0 #0 0O      J0 #0 0O //
//  Open Source                     v #00#0¡     #0 0 ]0O //
//                                    J000000c_ J0   c00^ //
//                                     0000c^00@NN ,#000  //
//                                      `0000@ggg#0000^   //
//                                        ^°0000000^^     //
//                                                        //
////////////////////////////////////////////////////////////

////////// DOCUMENTATION ///////////////////////////////////

/*

A user's manual as well as documentation for developers
is available on the Second Life (R) Wiki at

http://wiki.secondlife.com/wiki/FURWARE_text

*/

////////// LICENSE /////////////////////////////////////////

/*

MIT License

Copyright (c) 2010-2013 Ochi Wolfe, FURWARE, the contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

////////// CONTRIBUTORS ////////////////////////////////////

/*

ElectaFox Spark - Fixes for compatibility with OpenSim.
Ochi Wolfe      - Initial development from 2010 to 2013.

*/

////////// CONSTANTS ///////////////////////////////////////

// Index offsets and stride size of data in "boxDataList".
integer     BOX_DATA            = 0;    // The referenced data has type "string".
integer     BOX_CONF            = 1;    // The referenced data has type "string".
integer     BOX_STATUS          = 2;    // The referenced data has type "integer".
integer     BOX_GEOM            = 3;    // The referenced data has type "rotation".
integer     BOX_STRIDE          = 4;

// Tags used to remember the kind of the last performed action.
integer     ACTION_CONTENT      = 1;    // Text or style may have been modified.
integer     ACTION_ADD_BOX      = 2;    // A virtual text box was added.
integer     ACTION_DEL_BOX      = 3;    // A virtual text box was deleted.

// String of displayable characters, in the order of the font texture.
string      CHARS               = "";   // Populated in state_entry.

////////// VARIABLES ///////////////////////////////////////

// Global status
integer     primCount;      // Used to check for prim count changes.
integer     lastAction;     // The kind of the last performed action.

// Per-box data (box = virtual text box)
integer     boxDataLength;  // Length of the "boxDataList".
list        boxNameList;    // List of virtual text boxes' names.
list        boxDataList;    // Strided list of virtual text box data.

// Per-set data (set = physical display)
integer     setCount;       // Number of display sets.
list        setDataList;    // Strided list of display set data.

// Per-prim data
list        primLinkList;   // List of the prims' link indices
list        primFillList;   // Tells us which faces are showing non-blanks.
list        primLayerList;  // Contains layer assignments for each face.

// Memory for templates
list        tmplNameList;   // Names of stored templates.
list        tmplDataList;   // Contents of stored templates.

// Global configuration
integer     gNotify;        // Whether notifications shall be sent when done.
string      gConfAll;       // Base configuration for all boxes everywhere.
string      gConfRoot;      // Base configuration for root boxes.
string      gConfNonRoot;   // Base configuration for non-root boxes.

// Default configuration
string      dAlign;         // Text alignment.
string      dTrim;          // Whitespace trimming at begin/end.
string      dWrap;          // Text wrapping mode.
rotation    dColor;         // Text color.
string      dFont;          // Text font.
string      dBorder;        // Border type around virtual text box.
string      dTags;          // Use of inline style tags (<!...>).
integer     dForce;         // Force refresh, overriding cached face-filled state.

// Current configuration
string      cAlign;         // See above.
string      cTrim;
string      cWrap;
rotation    cColor;
string      cFont;
string      cBorder;
string      cTags;
integer     cForce;

// Prim data cache
integer     cacheIndex = -1;    // Index of currently cached prim data.
integer     cacheDirty;         // Bit 0 set = layer dirty, bit 1 set = stat dirty.
integer     cacheLink;          // Link number cache.
integer     cacheFill;          // Face-filled state cache.
integer     cacheLayer;         // Layer cache.

// Shared data between refresh() and draw(),
// just to avoid lots of parameter passing
integer     setAuxIndex;
integer     setColCount;
integer     setFaceCount;
integer     boxStatus;

////////// FUNCTIONS ///////////////////////////////////////

refresh() {
    llSetTimerEvent(0.0);
    
    integer boxDataIndex;
    integer step = BOX_STRIDE;
    integer end = boxDataLength;
    
    if (lastAction != ACTION_ADD_BOX) { // Last action is NOT adding a box -> iterate backwards
        boxDataIndex = boxDataLength - BOX_STRIDE;
        step = end = -BOX_STRIDE;
    }
    
    while (boxDataIndex != end) {
        boxStatus = llList2Integer(boxDataList, boxDataIndex + BOX_STATUS);
        
        if (boxStatus & 0x1000) { // Dirty
            // Set the factory default settings.
            cAlign  = dAlign  = "left";
            cTrim   = dTrim   = "on";
            cWrap   = dWrap   = "word";
            cColor  = dColor  = <1.0, 1.0, 1.0, 1.0>;
            cFont   = dFont   = "f974fdfc-8fbd-2f29-2b38-3c34411c1fcc";
            cBorder = dBorder = "";
            cTags   = dTags   = "on";
            cForce  = dForce  = FALSE;
            
            integer     setIndex        = (boxStatus >> 4) & 0xFF;
            rotation    boxGeometry     = llList2Rot(boxDataList, boxDataIndex + BOX_GEOM);
            
            // Load set data.
            vector setGeometry = llList2Vector(setDataList, 2*setIndex);
            setAuxIndex = llList2Integer(setDataList, 2*setIndex+1);
            
            // Load box config.
            set(gConfAll, TRUE, TRUE);
            if (boxDataIndex / BOX_STRIDE < setCount) {
                set(gConfRoot, TRUE, TRUE);
            } else {
                set(gConfNonRoot, TRUE, TRUE);
            }
            set(llList2String(boxDataList, boxDataIndex + BOX_CONF), TRUE, TRUE);
            
            integer boxX    = (integer)boxGeometry.x;
            integer boxY    = (integer)boxGeometry.y;
            integer boxW    = (integer)boxGeometry.z;
            integer boxH    = (integer)boxGeometry.s;
            integer boxR    = boxX+boxW-1;
            integer boxB    = boxY+boxH-1;
            
            setColCount     = (integer)setGeometry.x;
            setFaceCount    = (integer)setGeometry.z;
            
            integer borderTT = !!(~llSubStringIndex(cBorder, "T"));
            integer borderRR = !!(~llSubStringIndex(cBorder, "R"));
            integer borderBB = !!(~llSubStringIndex(cBorder, "B"));
            integer borderLL = !!(~llSubStringIndex(cBorder, "L"));
            
            integer borderT = borderTT || (~llSubStringIndex(cBorder, "t"));
            integer borderR = borderRR || (~llSubStringIndex(cBorder, "r"));
            integer borderB = borderBB || (~llSubStringIndex(cBorder, "b"));
            integer borderL = borderLL || (~llSubStringIndex(cBorder, "l"));
            
            integer borderSt;
            if      (~llSubStringIndex(cBorder, "1")) borderSt = 1;
            else if (~llSubStringIndex(cBorder, "2")) borderSt = 2;
            
            if (boxStatus & 0x2000) { // Potentially need to refresh borders?
                integer i;
                
                if (borderT) {
                    for (i = boxX+borderL; i <= boxR-borderR; ++i) draw(235 + 25*borderSt, i, boxY);
                }
                
                if (borderR) {
                    if (borderT) draw(227 - borderRR + 25*borderTT + 3*borderSt, boxR, boxY);
                    for (i = boxY+borderT; i <= boxB-borderB; ++i) draw(262 + borderSt, boxR, i);
                    if (borderB) draw(277 - borderRR - 25*borderBB + 3*borderSt, boxR, boxB);
                }
                
                if (borderB) {
                    for (i = boxR-borderR; i >= boxX+borderL; --i) draw(235 + 25*borderSt, i, boxB);
                }
                
                if (borderL) {
                    if (borderB) draw(275 + borderLL - 25*borderBB + 3*borderSt, boxX, boxB);
                    for (i = boxB-borderB; i >= boxY+borderT; --i) draw(262 + borderSt, boxX, i);
                    if (borderT) draw(225 + borderLL + 25*borderTT + 3*borderSt, boxX, boxY);
                }
            }
            
            boxX += borderL;
            boxY += borderT;
            boxR -= borderR;
            boxB -= borderB;
            boxW -= borderL + borderR;
            boxH -= borderT + borderB;
            
            if (boxW > 0 && boxH > 0) {
                // Prepare data.
                string text = llList2String(boxDataList, boxDataIndex + BOX_DATA);
                
                integer textLength = llStringLength(text);
                integer textIndex;
                
                list part;
                integer partLength;
                integer partIndex;
                
                integer dataNewLine = TRUE;
                string token;
                integer tokenLength;
                
                integer boxRow;
                while (boxRow < boxH) {
                    list line;
                    integer lineLength;
                    
                    list tagPosList;
                    list tagCmdList;
                    integer tagCmdListLength;
                    string tagCommand;
                    
                    integer spacesTail;
                    integer textMode = TRUE;
                    integer rowDone;
                    integer skipRestOfLine;
                    integer lastTokenWasSpace;
                    
                    // Parsing loop.
                    while ((partIndex < partLength || textIndex < textLength) && !rowDone) {
                        if (partIndex >= (partLength-1) && textIndex < textLength) {
                            part = llParseString2List(
                                llGetSubString(text, textIndex, textIndex+boxW),
                                [], [" ", "\n", "<!", ">"]
                            );
                            partLength = llGetListLength(part);
                            partIndex = 0;
                            tokenLength = 0;
                        }
                        
                        if (!tokenLength) {
                            token = llList2String(part, partIndex);
                            tokenLength = llStringLength(token);
                        }
                        
                        integer dataAdvance = TRUE;
                        integer tokenLengthPrev = tokenLength;
                        
                        // Text mode takes care of all tokens that are not enclosed by <! ... >.
                        if (textMode) {
                            if ((cTags == "on") && (token == "<!")) {
                                textMode = FALSE;
                            } else if (token == "\n") {
                                dataNewLine = TRUE;
                                rowDone = TRUE;
                            } else if (!skipRestOfLine) {
                                dataNewLine = FALSE;
                                integer tokenIsSpace = (token == " ");
                                
                                if ((cTrim != "off") && tokenIsSpace) {
                                    if (lineLength) {
                                        ++spacesTail;
                                        line += [0];
                                    }
                                } else {
                                    integer spaceLeft = boxW - lineLength - spacesTail;
                                    integer toAppend;
                                    
                                    if (tokenLength <= spaceLeft) {
                                        toAppend = tokenLength;
                                        lineLength += spacesTail;
                                        spacesTail = 0;
                                    } else {
                                        if ((cWrap != "word") || !lastTokenWasSpace) {
                                            if (spaceLeft > 0) {
                                                toAppend = spaceLeft;
                                                lineLength += spacesTail;
                                                spacesTail = 0;
                                            }
                                        }
                                        
                                        if (cWrap != "none") {
                                            rowDone = TRUE;
                                            dataAdvance = FALSE;
                                        } else {
                                            skipRestOfLine = TRUE;
                                        }
                                    }
                                    
                                    integer i;
                                    for (i = 0; i < toAppend; ++i, --tokenLength, ++lineLength) {
                                        integer charPos = llSubStringIndex(CHARS, llGetSubString(token, i, i));
                                        if (~charPos) line += [charPos]; else line += [68]; // 68 = "?"
                                    }
                                    
                                    if ((cWrap != "none") && tokenLength) {
                                        token = llGetSubString(token, -tokenLength, -1);
                                    }
                                }
                                
                                lastTokenWasSpace = tokenIsSpace;
                            }
                        // Tag mode takes care of all tokens within <! ... >.
                        } else {
                            if (token == ">") {
                                if (dataNewLine) {
                                    set(tagCommand, TRUE, FALSE);
                                } else {
                                    tagPosList += [lineLength+spacesTail];
                                    tagCmdList += [tagCommand];
                                    ++tagCmdListLength;
                                }
                                tagCommand = "";
                                textMode = TRUE;
                            } else {
                                tagCommand += token;
                            }
                        }
                        
                        if (dataAdvance) {
                            ++partIndex;
                            tokenLength = 0;
                        }
                        
                        textIndex += (tokenLengthPrev - tokenLength);
                    }
                    
                    integer nextTagListIndex;
                    integer nextTagCharIndex = -1;
                    if (tagCmdListLength) {
                        nextTagCharIndex = llList2Integer(tagPosList, 0);
                    }
                    
                    integer lineIndex;
                    if (cAlign != "left") {
                        integer delta = boxW - lineLength;
                        if (cAlign == "center") delta /= 2;
                        lineIndex -= delta;
                    }
                    
                    integer x;
                    for (x = boxX; x <= boxR; ++x, ++lineIndex) {
                        integer pos;
                        if (lineIndex >= 0 && lineIndex < lineLength) {
                            while (nextTagListIndex < tagCmdListLength && lineIndex >= nextTagCharIndex) {
                                set(llList2String(tagCmdList, nextTagListIndex++), FALSE, FALSE);
                                nextTagCharIndex = llList2Integer(tagPosList, nextTagListIndex);
                            }
                            pos = llList2Integer(line, lineIndex);
                        }
                        draw(pos, x, boxY + boxRow);
                    }
                    
                    while (nextTagListIndex < tagCmdListLength) {
                        set(llList2String(tagCmdList, nextTagListIndex++), FALSE, FALSE);
                    }
                    
                    ++boxRow;
                }
            }
            
            // Mark box as clean.
            boxDataList = llListReplaceList(
                boxDataList, [boxStatus & 0xFFF], boxDataIndex + BOX_STATUS, boxDataIndex + BOX_STATUS
            );
        }
        
        boxDataIndex += step;
    }
    
    draw(-1, 0, 0); // Flush cache.
    lastAction = 0;
    
    if (gNotify) {
        llMessageLinked(LINK_SET, 0, "", "fw_done");
    }
}

draw(integer char, integer x, integer y) {
    integer newCacheIndex = -1;
    if (~char) newCacheIndex = setAuxIndex + y*setColCount + x/setFaceCount;
    
    if (newCacheIndex != cacheIndex) {
        if (~cacheIndex) {
            // Stat cache dirty
            if (cacheDirty & 2) primFillList = llListReplaceList(
                primFillList, [cacheFill], cacheIndex, cacheIndex
            );
            // Layer cache dirty
            if (cacheDirty & 1) primLayerList = llListReplaceList(
                primLayerList, [cacheLayer], cacheIndex, cacheIndex
            );
            cacheDirty = 0;
        }
        
        cacheIndex = newCacheIndex;
        
        if (~cacheIndex) {
            cacheLink  = llList2Integer(primLinkList,  cacheIndex);
            cacheFill  = llList2Integer(primFillList,  cacheIndex);
            cacheLayer = llList2Integer(primLayerList, cacheIndex);
        }
    }
    
    if (!~char) return;
    
    integer face = x % setFaceCount;
    integer layer = (cacheLayer >> 4*face) & 0xF;
    integer boxLayer = (boxStatus & 0xF);
    
    if ((0x10000 << layer) & boxStatus) { // Layer override
        cacheLayer = (cacheLayer & ~(0xF << 4*face)) | (boxLayer << 4*face);
        cacheDirty = cacheDirty | 1;
    } else if (layer != boxLayer) {
        return;
    }
    
    integer filled = cForce || char;
    integer statDiffers = (filled ^ ((cacheFill >> face) & 1));
    
    if (filled || statDiffers) {
        if (statDiffers) {
            cacheFill = (cacheFill & ~(1 << face)) | (filled << face);
            cacheDirty = cacheDirty | 2;
        }
        
        llSetLinkPrimitiveParamsFast(cacheLink, [
            PRIM_TEXTURE, face, cFont, <0.03125, 0.0625, 0.0>,
                <0.0390625 * (char % 25), -0.0703125 * (char / 25), 0.0>, 0.0,
            PRIM_COLOR, face, <cColor.x, cColor.y, cColor.z>, filled * cColor.s
        ]);
    }
}

set(string data, integer startOfLine, integer setDefaults) {
    if (data == "") return;
    
    list parts = llParseString2List(data, [";"], []);
    integer partCount = llGetListLength(parts);
    integer part;
    for (part = 0; part < partCount; ++part) {
        list tokens = llParseString2List(llList2String(parts, part), ["="], []);
        if (llGetListLength(tokens) > 1) {
            string tag = llStringTrim(llList2String(tokens, 0), STRING_TRIM);
            string valUpper = llStringTrim(llList2String(tokens, 1), STRING_TRIM);
            string valLower = llToLower(valUpper);
            integer valIsDef = (valLower == "def");
            
            if (tag == "c") {
                if      (valIsDef)                   cColor = dColor;
                else if (valLower == "rand")         cColor = <llFrand(1.0), llFrand(1.0), llFrand(1.0), 1.0>;
                else if (valLower == "white")        cColor = <1.0, 1.0, 1.0, 1.0>;
                else if (valLower == "black")        cColor = <0.0, 0.0, 0.0, 1.0>;
                else if (valLower == "darkred")      cColor = <0.5, 0.0, 0.0, 1.0>;
                else if (valLower == "darkgreen")    cColor = <0.0, 0.5, 0.0, 1.0>;
                else if (valLower == "darkblue")     cColor = <0.0, 0.0, 0.5, 1.0>;
                else if (valLower == "darkcyan")     cColor = <0.0, 0.5, 0.5, 1.0>;
                else if (valLower == "darkmagenta")  cColor = <0.5, 0.0, 0.5, 1.0>;
                else if (valLower == "darkyellow")   cColor = <0.5, 0.5, 0.0, 1.0>;
                else if (valLower == "gray")         cColor = <0.5, 0.5, 0.5, 1.0>;
                else if (valLower == "red")          cColor = <1.0, 0.0, 0.0, 1.0>;
                else if (valLower == "green")        cColor = <0.0, 1.0, 0.0, 1.0>;
                else if (valLower == "blue")         cColor = <0.0, 0.0, 1.0, 1.0>;
                else if (valLower == "cyan")         cColor = <0.0, 1.0, 1.0, 1.0>;
                else if (valLower == "magenta")      cColor = <1.0, 0.0, 1.0, 1.0>;
                else if (valLower == "yellow")       cColor = <1.0, 1.0, 0.0, 1.0>;
                else if (valLower == "silver")       cColor = <0.75, 0.75, 0.75, 1.0>;
                else {
                    valLower = "<" + valLower + ">";
                    cColor = (rotation)valLower;
                    if (cColor == ZERO_ROTATION) {
                        vector tmp = (vector)valLower;
                        cColor = <tmp.x, tmp.y, tmp.z, 1.0>;
                    }
                }
            }
            
            else if (tag == "f") {
                if (valIsDef) cFont = dFont; else cFont = valUpper;
            }
            
            else if (tag == "style") {
                integer tmplIndex = llListFindList(tmplNameList, [valUpper]);
                if (~tmplIndex) {
                    set(llList2String(tmplDataList, tmplIndex), startOfLine, setDefaults);
                } else {
                    llOwnerSay("FW text: Style var \"" + valUpper + "\" not found.");
                }
            }
            
            else if (startOfLine) {
                if (tag == "w") {
                    if (valIsDef) cWrap = dWrap; else cWrap = valLower;
                } else if (tag == "t") {
                    if (valIsDef) cTrim = dTrim; else cTrim = valLower;
                } else if (tag == "a") {
                    if (valIsDef) cAlign = dAlign; else cAlign = valLower;
                } else if (tag == "border") {
                    if (valIsDef) cBorder = dBorder; else cBorder = valUpper;
                } else if (tag == "tags") {
                    if (valIsDef) cTags = dTags; else cTags = valLower;
                } else if (tag == "force") {
                    if (valIsDef) cForce = dForce; else cForce = (valLower == "on");
                }
            }
        }
    }
    
    if (setDefaults) {
        dAlign  = cAlign;
        dTrim   = cTrim;
        dWrap   = cWrap;
        dColor  = cColor;
        dFont   = cFont;
        dBorder = cBorder;
        dTags   = cTags;
        dForce  = cForce;
    }
}

setDirty(integer action, integer first, integer last, integer isConf,
         integer newLayerOverrideBits, integer setIndex, integer withData, string data) {
    integer i;
    for (i = first; i <= last; i += BOX_STRIDE) {
        integer setMatches = TRUE;
        if (~setIndex) {
            setMatches = (((llList2Integer(boxDataList, i + BOX_STATUS) >> 4) & 0xFF) == setIndex);
        }
        
        if (setMatches) {
            integer j;
            
            if (withData) {
                j = i + isConf;
                boxDataList = llListReplaceList(boxDataList, [data], j, j);
            }
            
            j = i + BOX_STATUS;
            boxDataList = llListReplaceList(
                boxDataList, [
                    llList2Integer(boxDataList, j) | 0x1000 | (isConf * 0x2000) | (newLayerOverrideBits << 16)
                ], j, j
            );
        }
    }
    
    if (!lastAction) {
        llSetTimerEvent(0.05);
        lastAction = action;
    }
}

////////// STATES //////////////////////////////////////////

default {
    state_entry() {
        llOwnerSay("FURWARE text is starting...");
        
        CHARS = llBase64ToString(
            "IGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6QUJDREVGR0hJSktMTU5PUFFS" +
            "U1RVVldYWVowMTIzNDU2Nzg5Liw6OyE/IifCtGBefistKi9cfCgpW117fTw+" +
            "PUAkJSYjX8Ogw6HDosOjw6TDpcOmwqrDp8Oww6jDqcOqw6vDrMOtw67Dr8Ox" +
            "w7LDs8O0w7XDtsO4xZPCusOexaHDn8O5w7rDu8O8w73Dv8W+w4DDgcOCw4PD" +
            "hMOFw4bDh8OQw4jDicOKw4vDjMONw47Dj8ORw5LDk8OUw5XDlsOYxZLDvsWg" +
            "w5nDmsObw5zDncW4xb3CosKj4oKswqXCp8K1wqHCv8Kpwq7CscOXw7fCt8Kw" +
            "wrnCssKzwqvCu8Ks4oCm4oC54oC64oCTwrzCvcK+4oSi4oCiICAgICAgICAg" +
            "ICAgICAgICAgICAgICAgICAgIOKUjOKUrOKUkOKUj+KUs+KUk+KVlOKVpuKV" +
            "l+KVtuKUgOKVtOKVt+KVuyDilK/ilrLil4Dilrzilrbil4vil5Til5Hil5Xi" +
            "l4/ilJzilLzilKTilKPilYvilKvilaDilazilaPilbrilIHilbjilILilIPi" +
            "lZHilL/ihpHihpDihpPihpLihrrihrvimJDimJHimJLilJTilLTilJjilJfi" +
            "lLvilJvilZrilanilZ0g4pWQIOKVteKVuSDilLfilKDilYLilKjihpXihpTi" +
            "mYDimYLimqDihLninYzijJbiiKHijJvijJrimarimavimaDimaPimaXimabi" +
            "moDimoHimoLimoPimoTimoXinJTinJjimLrimLnilqDil77ilqzilq7ilog="
        );
        
        // Remember prim count to detect changes later on.
        primCount = llGetObjectPrimCount(llGetKey())+llGetNumberOfPrims()*!!llGetAttached();
        
        // Determine which link IDs to iterate.
        integer linkMin;
        integer linkMax;
        if (primCount > 1) {
            linkMin = 1;
            linkMax = primCount;
        }
        
        // Fetch data from prims.
        list sets;
        integer dataLength;
        while (linkMin <= linkMax) {
            list tokens = llParseStringKeepNulls(llGetLinkName(linkMin), [":"], []);
            if (llList2String(tokens, 0) == "FURWARE text mesh") {
                string setStr = llList2String(tokens, 1);
                if (setStr != "") {
                    integer set1 = llListFindList(sets, [setStr]);
                    if (!~set1) {
                        set1 = llGetListLength(sets);
                        sets += [setStr];
                    }
                    
                    primLinkList += [
                        (set1 << 20) |
                        ((llList2Integer(tokens, 2) & 0x3FF) << 10) |
                        (llList2Integer(tokens, 3) & 0x3FF),
                        llList2Integer(tokens, 4), linkMin
                    ];
                    ++dataLength;
                }
            }
            ++linkMin;
        }
        
        // Abort if not a single element was found.
        if (!dataLength) {
            llOwnerSay("FW text: No text 2.x prims found.");
            return;
        }
        
        // Sort the data according to their set1-row-col values.
        primLinkList = llListSort(primLinkList, 3, TRUE);
        
        // Parse the gathered data.
        integer dataIndex;
        integer setrowcol = llList2Integer(primLinkList, dataIndex);
        integer set2 = (setrowcol >> 20) & 0x3FF;
        integer row = (setrowcol >> 10) & 0x3FF;
        integer nextSet;
        integer nextRow;
        
        do { // set2
            
            integer rowCount;
            integer colCount;
            integer faceCount;
            
            integer setAuxPtr = dataIndex;
            
            do { // Row
                
                ++rowCount;
                integer newColCount;
                
                do { // Col
                    
                    ++newColCount;
                    integer link = llList2Integer(primLinkList, 3*dataIndex+2);
                    integer newFaceCount = llList2Integer(primLinkList, 3*dataIndex+1);
                    if (!newFaceCount) newFaceCount = llGetLinkNumberOfSides(link);
                    
                    if (faceCount) {
                        if (newFaceCount != faceCount) {
                            llOwnerSay("FW text: All prims within a set need to have the same number of faces.");
                            setCount = 0;
                            return;
                        }
                    } else {
                        faceCount = newFaceCount;
                    }
                    
                    llSetLinkPrimitiveParamsFast(link, [
                        PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT,
                        <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0
                    ]);
                    
                    setrowcol = llList2Integer(primLinkList, 3*(++dataIndex));
                    nextSet = (setrowcol >> 20) & 0x3FF;
                    nextRow = (setrowcol >> 10) & 0x3FF;
                    
                } while (dataIndex < dataLength && set2 == nextSet && row == nextRow);
                
                if (colCount) {
                    if (newColCount != colCount) {
                        llOwnerSay("FW text: All rows within a set need to have the same number of prims.");
                        setCount = 0;
                        return;
                    }
                } else {
                    colCount = newColCount;
                }
                
                row = nextRow;
                
            } while (dataIndex < dataLength && set2 == nextSet);
            
            setDataList += [<colCount, rowCount, faceCount>, setAuxPtr];
            boxNameList += [llList2String(sets, set2)];
            boxDataList += ["", "", setCount << 4, <0, 0, colCount*faceCount, rowCount>];
            
            boxDataLength += BOX_STRIDE;
            ++setCount;
            
            set2 = nextSet;
            
        } while (dataIndex < dataLength);
        
        primLinkList = llDeleteSubList(primLinkList, 0, 1);
        primLinkList = llList2ListStrided(primLinkList, 0, -1, 3);
        while (dataIndex--) primFillList += [0];
        primLayerList = primFillList;
        
        llOwnerSay("FURWARE text started with " + (string)setCount + " set(s).");
        llMessageLinked(LINK_SET, 0, "", "fw_ready");
    }
    
    link_message(integer sender, integer num, string str, key id) {
        if (!setCount) return;
        if (llGetSubString(id, 0, 2) != "fw_") return;
        
        list tokens = llParseStringKeepNulls(id, [":"], []);
        string token0 = llStringTrim(llList2String(tokens, 0), STRING_TRIM);
        
        integer isConf = (token0 == "fw_conf");
        
        if (token0 == "fw_data" || isConf) {
            if (lastAction && lastAction != ACTION_CONTENT) refresh();
            
            integer tokenCount = llGetListLength(tokens);
            if (tokenCount < 2) tokenCount = 2;
            
            integer t;
            for (t = 1; t < tokenCount; ++t) {
                list boxTokens = llParseStringKeepNulls(llList2String(tokens, t), [";"], []);
                integer boxTokenCount = llGetListLength(boxTokens);
                
                string boxToken0 = llStringTrim(llList2String(boxTokens, 0), STRING_TRIM);
                string boxToken1 = llStringTrim(llList2String(boxTokens, 1), STRING_TRIM);
                
                integer first = 0;
                integer last = boxDataLength - BOX_STRIDE;
                integer setIndex = -1;
                
                if (boxToken0 != "") {
                    first = llListFindList(boxNameList, [boxToken0]);
                    
                    if (!~first) {
                        llOwnerSay(token0 + ": Box \"" + boxToken0 + "\" not found.");
                        jump SkipBox;
                    }
                    
                    first *= BOX_STRIDE;
                    setIndex = (llList2Integer(boxDataList, first + BOX_STATUS) >> 4) & 0xFF;
                }
                
                if (boxToken1 != "") {
                    last = llListFindList(boxNameList, [boxToken1]);
                    
                    if (!~last) {
                        llOwnerSay(token0 + ": Box \"" + boxToken1 + "\" not found.");
                        jump SkipBox;
                    }
                    
                    last *= BOX_STRIDE;
                    integer secondSetIndex = (llList2Integer(boxDataList, last + BOX_STATUS) >> 4) & 0xFF;
                    
                    if ((~setIndex) && setIndex != secondSetIndex) {
                        llOwnerSay(token0 + ": Box sets must match when specifying a range.");
                        jump SkipBox;
                    }
                    
                    setIndex = secondSetIndex;
                } else if (boxTokenCount == 1 && ~setIndex) {
                    last = first;
                }
                
                setDirty(ACTION_CONTENT, first, last, isConf, 0, setIndex, TRUE, str);
                
                @SkipBox;
            }
            
            return;
        }
        
        string token1 = llStringTrim(llList2String(tokens, 1), STRING_TRIM);
        
        if (token0 == "fw_var") {
            if (lastAction && lastAction != ACTION_CONTENT) refresh();
            
            if (token1 == "") {
                llOwnerSay("fw_var: No variable name given.");
                return;
            }
            
            integer tmplIndex = llListFindList(tmplNameList, [token1]);
            if (~tmplIndex) {
                tmplNameList = llDeleteSubList(tmplNameList, tmplIndex, tmplIndex);
                tmplDataList = llDeleteSubList(tmplDataList, tmplIndex, tmplIndex);
            }
            
            if (str != "") {
                tmplNameList += [token1];
                tmplDataList += [str];
            }
            
            setDirty(ACTION_CONTENT, 0, boxDataLength - BOX_STRIDE, TRUE, 0, -1, FALSE, "");
            
            return;
        }
        
        if (token0 == "fw_defaultconf") {
            if (lastAction && lastAction != ACTION_CONTENT) refresh();
            
            integer first = -1;
            integer last = boxDataLength - BOX_STRIDE;
            
            if (token1 == "") {
                gConfAll = str;
                first = 0;
            } else if (token1 == "root") {
                gConfRoot = str;
                first = 0;
                last = setCount * BOX_STRIDE - BOX_STRIDE;
            } else if (token1 == "nonroot") {
                gConfNonRoot = str;
                first = setCount * BOX_STRIDE;
            }
            
            if (~first) {
                setDirty(ACTION_CONTENT, first, last, TRUE, 0, -1, FALSE, "");
            }
            
            return;
        }
        
        string token2 = llStringTrim(llList2String(tokens, 2), STRING_TRIM);
        string token3 = llStringTrim(llList2String(tokens, 3), STRING_TRIM);
        string token4 = llStringTrim(llList2String(tokens, 4), STRING_TRIM);
        
        if (token0 == "fw_addbox") {
            if (token1 == "") {
                llOwnerSay("fw_addbox: Box name cannot be empty.");
                return;
            }
            
            if (lastAction && lastAction != ACTION_ADD_BOX) refresh();
            
            integer boxNameIndex = llListFindList(boxNameList, [token1]);
            
            if (~boxNameIndex) {
                llOwnerSay("fw_addbox: Box \"" + token1 + "\" already exists.");
                return;
            }
            
            integer parNameIndex = llListFindList(boxNameList, [token2]);
            
            if (!~parNameIndex) {
                llOwnerSay("fw_addbox: No parent box \"" + token2 + "\".");
                return;
            }
            
            integer boxDataIndex = BOX_STRIDE * boxNameIndex;
            integer parDataIndex = BOX_STRIDE * parNameIndex;
            
            integer setIndex = (llList2Integer(boxDataList, parDataIndex + BOX_STATUS) >> 4) & 0xFF;
            
            integer layersUsed;
            integer b;
            for (b = 0; b < boxDataLength; b += BOX_STRIDE) {
                if (setIndex == ((llList2Integer(boxDataList, b + BOX_STATUS) >> 4) & 0xFF)) {
                    layersUsed = layersUsed | (1 << (llList2Integer(boxDataList, b + BOX_STATUS) & 0xF));
                }
            }
            
            if (layersUsed == 0xFFFF) {
                llOwnerSay("fw_addbox: No layer available.");
                return;
            }
            
            integer boxLayer;
            while (layersUsed & (1 << boxLayer)) ++boxLayer;
            
            rotation boxGeom = (rotation)("<" + token3 + ">");
            rotation parGeom = llList2Rot(boxDataList, parDataIndex + BOX_GEOM);
            vector   setGeom = llList2Vector(setDataList, 2*setIndex);
            
            boxGeom.x += parGeom.x;
            boxGeom.y += parGeom.y;
            
            if (boxGeom.x < 0 || boxGeom.y < 0 ||
                boxGeom.z < 1 || boxGeom.s < 1 ||
                (boxGeom.x + boxGeom.z) > (setGeom.x * setGeom.z) ||
                (boxGeom.y + boxGeom.s) > setGeom.y)
            {
                llOwnerSay("fw_addbox: Invalid box geometry.");
                return;
            }
            
            boxNameList += [token1];
            boxDataList += [str, token4, (setIndex << 4) | boxLayer, boxGeom];
            
            setDirty(ACTION_ADD_BOX, boxDataLength, boxDataLength, TRUE, 0xFFFF, -1, FALSE, "");
            boxDataLength += BOX_STRIDE;
            
            return;
        }
        
        if (token0 == "fw_delbox") {
            if (lastAction && lastAction != ACTION_DEL_BOX) refresh();
            
            integer tokenCount = llGetListLength(tokens);
            
            integer t;
            for (t = 1; t < tokenCount; ++t) {
                string boxName = llStringTrim(llList2String(tokens, t), STRING_TRIM);
                integer boxNameIndex = llListFindList(boxNameList, [boxName]);
                
                if (!(~boxNameIndex) || (boxNameIndex < setCount)) {
                    llOwnerSay("fw_delbox: Box \"" + boxName + "\" doesn't exist.");
                    jump SkipDelBox;
                }
                
                integer boxDataIndex = BOX_STRIDE * boxNameIndex;
                integer boxStatus = llList2Integer(boxDataList, boxDataIndex + BOX_STATUS);
                
                setDirty(ACTION_DEL_BOX, 0, boxDataIndex - BOX_STRIDE, TRUE,
                         1 << (boxStatus & 0xF), (boxStatus >> 4) & 0xFF, FALSE, "");
                
                boxNameList = llDeleteSubList(boxNameList, boxNameIndex, boxNameIndex);
                boxDataList = llDeleteSubList(boxDataList, boxDataIndex, boxDataIndex + BOX_STRIDE - 1);
                
                boxDataLength -= BOX_STRIDE;
                
                @SkipDelBox;
            }
            
            return;
        }
        
        if (token0 == "fw_touchquery") {
            // Need to flush first so that BOX_STATUS only contains the set index and box layer.
            if (lastAction) refresh();
            
            string reply = "::::::" + str;
            
            integer link = (integer)token1;
            integer face = (integer)token2;
            
            list primNameTokens = llParseStringKeepNulls(llGetLinkName(link), [":"], []);
            
            if (llList2String(primNameTokens, 0) == "FURWARE text mesh") {
                integer rootIndex = llListFindList(boxNameList, [llList2String(primNameTokens, 1)]);
                
                if (~rootIndex) {
                    integer auxIndex = llListFindList(primLinkList, [link]);
                    if (~auxIndex) {
                        integer layer = (llList2Integer(primLayerList, auxIndex) >> (4*face)) & 0xF;
                        integer boxIndex = llListFindList(boxDataList, [(rootIndex << 4) | layer]);
                        
                        if (~boxIndex) {
                            boxIndex -= BOX_STATUS;
                            
                            vector   setGeom = llList2Vector(setDataList, 2*rootIndex);
                            rotation boxGeom = llList2Rot(boxDataList, boxIndex + BOX_GEOM);
                            
                            integer x = llList2Integer(primNameTokens, 3) * (integer)setGeom.z + face;
                            integer y = llList2Integer(primNameTokens, 2);
                            
                            reply = llList2String(boxNameList, boxIndex/BOX_STRIDE) + ":" +
                                    (string)(x - (integer)boxGeom.x) + ":" +
                                    (string)(y - (integer)boxGeom.y) + ":" +
                                    llList2String(boxNameList, rootIndex) + ":" +
                                    (string)x + ":" +
                                    (string)y + ":" + str;
                        }
                    }
                }
            }
            
            llMessageLinked(sender, 0, reply, "fw_touchreply");
            
            return;
        }
        
        if (token0 == "fw_notify") {
            gNotify = (str == "on");
            return;
        }
        
        if (token0 == "fw_memory") {
            llOwnerSay((string)llGetFreeMemory() + " bytes free");
            return;
        }
        
        if (token0 == "fw_reset") {
            llResetScript();
        }
    }
    
    timer() {
        refresh();
    }
    
    changed(integer change) {
        if (change & CHANGED_LINK) {
            if (llGetObjectPrimCount(llGetKey())+llGetNumberOfPrims()*!!llGetAttached() != primCount) {
                llResetScript();
            }
        }
    }
}
