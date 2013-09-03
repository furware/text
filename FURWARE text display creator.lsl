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

integer listenChannel;
integer listenHandle;

string  inputType;

string  setName = "default";
integer numRows = 4;
integer numCols = 4;
integer primType = 8;

integer cur;
integer row;
integer col;
float scale;

newListen() {
    llListenRemove(listenHandle);
    listenChannel = -llFloor(1000000+llFrand(1000000));
    listenHandle = llListen(listenChannel, "", llGetOwner(), "");
    llSetTimerEvent(300.0);
}

dialogSetup() {
    newListen();
    inputType = "";
    llDialog(llGetOwner(), "Current settings:\n\n" +
                           "Name of display: \"" + setName + "\"\n" +
                           "Prim type: " + (string)primType + "-face mesh\n" +
                           (string)numRows + " row(s), " + (string)numCols + " column(s)\n" +
                           "Total: " + (string)(numRows*numCols) + " prim(s), " + (string)numRows + " x " + (string)(numCols*primType) +
                               " = " + (string)(numRows*numCols*primType) + " chars",
                           ["Create", "Set rows", "Set cols",
                            "Set name", "Prim type", "Help"], listenChannel);
}

dialogInput(string type, string text) {
    newListen();
    inputType = type;
    llTextBox(llGetOwner(), text, listenChannel);
}

rez() {
    integer percent = 100;
    if (numRows*numCols > 1) {
        percent = llFloor(100 * ((float)cur / (numRows*numCols-1)));
    }
    
    llSetText("Creating display... Click to abort.\nErstelle Display... Klicke zum Abbrechen.\n" + (string)percent + "%\n ", <1.0, 1.0, 0.0>, 1.0);
    
    rotation rot = llGetRot();
    float width = 0.125*primType;
    vector pos = (<0.0, -((width/2.0)*(numCols-1)), 1.0> + <0.0, width*col, 0.25*(numRows-row-1)>);
    
    if (!cur) {
        scale = 1.0;
        while (llVecMag(scale * pos) > 9.9) {
            scale /= 2.0;
        }
    }
    
    llRezObject("FURWARE text mesh " + (string)primType, llGetPos() + scale * pos * rot, ZERO_VECTOR, rot, 1);
}

default {
    state_entry() {
        llSetText("Click to create a display.\nKlicke um ein Display zu erstellen.\n ", <0.51764, 0.70588, 0.28220>, 1.0);
        
        llOwnerSay("\n\tYou can find extensive instructions at http://wiki.secondlife.com/wiki/FURWARE_text" +
                   "\n\tEine ausführliche Anleitung findest du unter http://wiki.secondlife.com/wiki/FURWARE_text");
    }
    
    on_rez(integer startParam) {
        llResetScript();
    }
    
    timer() {
        llOwnerSay("\n\tDialog timed out.\n\tWartezeit für Dialog ist abgelaufen.");
        llSetTimerEvent(0.0);
        llListenRemove(listenHandle);
    }
    
    listen(integer channel, string name, key id, string message) {
        if (inputType == "") {
            if (message == "Create") {
                state Create;
            } else if (message == "Prim type") {
                dialogInput("type", "\nFaces per prim:\nSeiten pro Prim:\n\n(Number between 1 and 8)");
            } else if (message == "Set rows") {
                dialogInput("rows", "\nNumber of rows:\nAnzahl der Zeilen:\n\n(Number between 1 and 256)");
            } else if (message == "Set cols") {
                dialogInput("cols", "\nNumber of columns:\nAnzahl der Spalten:\n\n(Number between 1 and 256)");
            } else if (message == "Set name") {
                dialogInput("name", "\nName of this display:\nName des Displays:\n\n(Length 1 to 16, no \":\", \";\", or newline)");
            } else if (message == "Help") {
                llLoadURL(llGetOwner(), "An extensive manual is available online." +
                                        "\nEine ausführliche Anleitung ist online verfügbar.",
                                        "http://wiki.secondlife.com/wiki/FURWARE_text");
            }
            return;
        } else if (inputType == "type") {
            integer newPrimType = (integer)message;
            if (newPrimType >= 1 && newPrimType <= 8) {
                primType = newPrimType;
            } else {
                llOwnerSay("Prim face count must be between 1 and 8.");
            }
        } else if (inputType == "rows") {
            integer newNumRows = (integer)message;
            if (newNumRows >= 1 && newNumRows <= 256) {
                numRows = newNumRows;
            } else {
                llOwnerSay("Row count must be between 1 and 256.");
            }
        } else if (inputType == "cols") {
            integer newNumCols = (integer)message;
            if (newNumCols >= 1 && newNumCols <= 256) {
                numCols = newNumCols;
            } else {
                llOwnerSay("Column count must be between 1 and 256.");
            }
        } else if (inputType == "name") {
            integer nameLength = llStringLength(message);
            if (nameLength >= 1 && nameLength <= 16 && llGetListLength(llParseStringKeepNulls(message, [":", ";", "\n"], [])) == 1) {
                setName = message;
            } else {
                llOwnerSay("Set name length must be between 1 and 16 and may not contain ':', ';' or newlines.");
            }
        }
        
        dialogSetup();
    }
    
    touch_start(integer numDetected) {
        if (llDetectedKey(0) != llGetOwner()) return;
        dialogSetup();
    }
    
    state_exit() {
        llSetTimerEvent(0.0);
        llListenRemove(listenHandle);
    }
}

state Create {
    state_entry() {
        cur = 0;
        row = 0;
        col = 0;
        
        rez();
    }
    
    on_rez(integer startParam) {
        llResetScript();
    }
    
    touch_start(integer numDetected) {
        if (llDetectedKey(0) != llGetOwner()) return;
        llOwnerSay("\n\tDisplay creation aborted.\n\tDiplay-Erstellung abgebrochen.");
        state default;
    }
    
    object_rez(key id) {
        if (llGetOwnerKey(id) != llGetOwner()) {
            llOwnerSay("\n\tSorry, it seems like I wasn't able to rez all elements (parcel full?)." +
                       "\n\tEntschuldige, es scheint als ob ich nicht alle Elemente rezzen konnte (Land voll?).");
            state default;
        }
        
        vector color = <1.0, 1.0, 1.0>;
        if ((col+row)%2) color = <0.7, 0.7, 0.7>;
        
        llRegionSayTo(id, -2783468, "FURWARE text mesh:" + setName + ":" + (string)row + ":" + (string)col + ":" + (string)primType + ";" + (string)color + ";" + (string)scale);
        
        ++cur;
        ++col;
        if (col >= numCols) {
            col = 0;
            ++row;
        }
        
        if (row >= numRows) {
            state default;
        } else {
            rez();
        }
    }
}
