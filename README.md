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