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

Ochi Wolfe - Initial development from 2010 to 2013.

*/

default {
    state_entry() {
        llListen(-2783468, "", NULL_KEY, "");
    }
    
    listen(integer channel, string name, key id, string message) {
        if (llGetOwnerKey(id) != llGetOwner()) return;
        
        list tokens = llParseString2List(message, [";"], []);
        
        llSetObjectName(llList2String(tokens, 0));
        llSetColor((vector)llList2String(tokens, 1), ALL_SIDES);
        
        float scale = (float)llList2String(tokens, 2);
        if (scale != 1.0) {
            llSetScale(scale * llGetScale());
        }
        
        llRemoveInventory(llGetScriptName());
    }
    
    on_rez(integer startParam) {
        if (!startParam) {
            llOwnerSay("Warning: This object is meant to be rezzed by the FURWARE display creator.");
            llOwnerSay("The script inside this object will delete itself in one minute.");
            llSetTimerEvent(60.0);
        }
    }
    
    timer() {
        llRemoveInventory(llGetScriptName());
    }
}
