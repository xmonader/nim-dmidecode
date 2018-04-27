# dmidecode
# Copyright xmonader
# Parse DMIDecode output into reasonable structures.

import  sequtils, tables, strutils

type 
    ParserState = enum
        noOp, sectionName, readKeyValue, readList

type 
    Property* = ref object
        val*: string
        items*: seq[string]
type
    Section* = ref object
        handleLine*, title*: string
        props* : Table[string, Property]


method addItem(this: Property, item: string) =
    this.items.add(item)

proc getIndentLevel(line: string) : int = 
    for i, c in pairs(line):
        if not c.isSpaceAscii():
            return i
    return 0

proc parseDMI* (source: string) : Table[string, Section]=
    
    var
        state : ParserState = noOp
        lines = strutils.splitLines(source)
        sects = initTable[string, Section]()
        
        p: Property = nil
        s: Section = nil 
        k, v: string
    for i, l in pairs(lines):
        if l.startsWith("Handle"):
            s = new Section
            s.props = initTable[string, Property]()
            s.handleline = l
            state = sectionName
            continue 

        if l == "": # can be just new line before reading any sections. 
            if s != nil:
                sects[s.title] = s
            continue
        
        if state == sectionName:  # current line is the title line
            s.title = l
            state = readKeyValue  # change state into reading key value pairs
        elif state == readKeyValue:
            let pair = l.split({':'})
            k = pair[0].strip()
            if len(pair) == 2:
                v = pair[1].strip()
            else:                 # value can be empty
                v = ""
            p = Property(val: v)
            p.items = newSeq[string]()
            p.val = v

            # current line indentation is <  nextline indentation => change state to readList
            if i < len(lines) and (getIndentlevel(l) < getIndentlevel(lines[i+1])) :
                state = readList
            else:
                # add key/value pair directly
                s.props[k] = p
        elif state == readList:
            # keep adding the current line to current property items and if dedented => change state to readKeyValue
            p.add_item(l.strip())
            if getindentlevel(l) > getindentlevel(lines[i+1]):
                state = readKeyValue 
                s.props[k] = p

    return sects