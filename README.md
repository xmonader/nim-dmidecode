# nim-dmidecode
dmidecode parser in nim


## Example

```nim
let sample1 = """
# dmidecode 3.1
Getting SMBIOS data from sysfs.
SMBIOS 2.6 present.

Handle 0x0001, DMI type 1, 27 bytes
System Information
        Manufacturer: LENOVO
        Product Name: 20042
        Version: Lenovo G560
        Serial Number: 2677240001087
        UUID: CB3E6A50-A77B-E011-88E9-B870F4165734
        Wake-up Type: Power Switch
        SKU Number: Calpella_CRB
        Family: Intel_Mobile
"""

import dmidecode, tables

var obj : Table[string, dmidecode.Section]
obj = parseDMI(sample)
for secname, sec in obj:
    echo secname & " with " & $len(sec.props)
    for k, p in sec.props:
        echo "k : " & k & " => " & p.val 
        if len(p.items) > 0:
            for i in p.items:
                echo "\t\t I: ", i

```


## Tutorial
a while ago at work (https://github.com/zero-os/0-core) we needed to parse some dmidecode output, and it sounds like an good problem with enough concepts to get my feet wet in nim.

### nimble ready!
```bash
mkdir dmidecode
nimble init
```

### So how does dmidecode output look like?
```
# dmidecode 3.1
Getting SMBIOS data from sysfs.
SMBIOS 2.6 present.

Handle 0x0001, DMI type 1, 27 bytes
System Information
        Manufacturer: LENOVO
        Product Name: 20042
        Version: Lenovo G560
        Serial Number: 2677240001087
        UUID: CB3E6A50-A77B-E011-88E9-B870F4165734
        Wake-up Type: Power Switch
        SKU Number: Calpella_CRB
        Family: Intel_Mobile
```

or 

```
Getting SMBIOS data from sysfs.
SMBIOS 2.6 present.

Handle 0x0000, DMI type 0, 24 bytes
BIOS Information
        Vendor: LENOVO
        Version: 29CN40WW(V2.17)
        Release Date: 04/13/2011
        ROM Size: 2048 kB
        Characteristics:
                PCI is supported
                BIOS is upgradeable
                BIOS shadowing is allowed
                Boot from CD is supported
                Selectable boot is supported
                EDD is supported
                Japanese floppy for NEC 9800 1.2 MB is supported (int 13h)
                Japanese floppy for Toshiba 1.2 MB is supported (int 13h)
                5.25"/360 kB floppy services are supported (int 13h)
                5.25"/1.2 MB floppy services are supported (int 13h)
                3.5"/720 kB floppy services are supported (int 13h)
                3.5"/2.88 MB floppy services are supported (int 13h)
                8042 keyboard services are supported (int 9h)
                CGA/mono video services are supported (int 10h)
                ACPI is supported
                USB legacy is supported
                BIOS boot specification is supported
                Targeted content distribution is supported
        BIOS Revision: 1.40
```
### DMI structure
- DMIDecode output is some meta like comments, versions and one or more sections
- Section: consists of a 
    * handle line
    * title line
    * one or more indented properties
- Property: consists of 
    * key
    * optional value
    * optional list of indented items


### Mapping DMI to nim structures
So ourplan is to have an api like
```nim
dmifile = parseDMI(source)
dmifile["section1"]["property1].value
```

Let's describe the document structure we have
```nim
import  sequtils, tables, strutils

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

```
As our parsing will depend on the indentation level we can use this handy function to get the indentation level of a line (number of spaces before the first asciiLetter)

```
proc getIndentLevel(line: string) : int = 
    for i, c in pairs(line):
        if not c.isSpaceAscii():
            return i
    return 0
```

It'd have been nicer to use `takewhile`, but it's not available in nim stdlib
```python
    getindentlevel = lambda l:  len(list(takewhile(lambda c: c.isspace(), l)))
```

### Parsing DMI source into nim structures
There're many ways to parse the DMI (e.g using regex which would be fairly simple "feel free to implement it" and kindly send me a PR to update this tutorial)
```
proc parseDMI* (source: string) : Table[string, Section]=
```
In plain english for output like this
```
Getting SMBIOS data from sysfs.
SMBIOS 2.6 present.

Handle 0x0000, DMI type 0, 24 bytes
BIOS Information
        Vendor: LENOVO
        Version: 29CN40WW(V2.17)
        Release Date: 04/13/2011
        ROM Size: 2048 kB
        Characteristics:
                PCI is supported
                BIOS is upgradeable
                BIOS shadowing is allowed
                Boot from CD is supported
                Selectable boot is supported
                EDD is supported
                Japanese floppy for NEC 9800 1.2 MB is supported (int 13h)
                Japanese floppy for Toshiba 1.2 MB is supported (int 13h)
                5.25"/360 kB floppy services are supported (int 13h)
                5.25"/1.2 MB floppy services are supported (int 13h)
                3.5"/720 kB floppy services are supported (int 13h)
                3.5"/2.88 MB floppy services are supported (int 13h)
                8042 keyboard services are supported (int 9h)
                CGA/mono video services are supported (int 10h)
                ACPI is supported
                USB legacy is supported
                BIOS boot specification is supported
                Targeted content distribution is supported
        BIOS Revision: 1.40
```

we have couple of states
```nim
type 
    ParserState = enum
        noOp, sectionName, readKeyValue, readList
```
- noOp: no action yet
- sectionName: read sectionName
- readKeyValue: read a line has colon `:` in it into a key value pair
- readList: when the next line has greater indentation level than the property line

so our state is noOp until we reach line 
```Handle 0x0000, DMI type 0, 24 bytes```
then moves to sectionName
for line ```BIOS Information``` then state changes to reading properties
```
        Vendor: LENOVO
        Version: 29CN40WW(V2.17)
        Release Date: 04/13/2011
        ROM Size: 2048 kB
        Characteristics:
```
then we notice the indentation on the next line 
```
                PCI is supported
``` 
is greater than the one on the current line
```
        Characteristics:
```
so state moves into readList to read the items related to property `Characterstics`
```
                PCI is supported
                BIOS is upgradeable
                BIOS shadowing is allowed
                Boot from CD is supported
                Selectable boot is supported
                EDD is supported
                Japanese floppy for NEC 9800 1.2 MB is supported (int 13h)
                Japanese floppy for Toshiba 1.2 MB is supported (int 13h)
                5.25"/360 kB floppy services are supported (int 13h)
                5.25"/1.2 MB floppy services are supported (int 13h)
                3.5"/720 kB floppy services are supported (int 13h)
                3.5"/2.88 MB floppy services are supported (int 13h)
                8042 keyboard services are supported (int 9h)
                CGA/mono video services are supported (int 10h)
                ACPI is supported
                USB legacy is supported
                BIOS boot specification is supported
                Targeted content distribution is supported
```
and again it notices the indentation is of the next line 
```
        BIOS Revision: 1.40
```

is less than the current line 
```
                Targeted content distribution is supported
```
so state switches again into `readKeyValue`

- if we encounter an empty line:
    * if not in parsing state then it's a noOp we ignore meta and empty lines
    * if in parsing state `current Section isn't nil` we finish parsing the section object


```nim

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

```

Feel free to send PRs regarding idiomatic nim, tests, improvements to the tutorial, .. etc :)