4d-plugin-core-printing
=======================

Platform
--------
4D Carbon 10.6+
4D Cocoa 10.8+

```
$orientation:=CP Get orientation 
CP SET ORIENTATION ($orientation)

$scale:=CP Get scale 
CP SET SCALE ($scale)

$copies:=CP Get copies 
CP SET COPIES ($copies)

$page:=CP Get first page 
CP SET FIRST PAGE ($page)

$name:=CP get job name 
CP SET JOB NAME ($name)

$page:=CP get last page 
CP SET LAST PAGE ($page)

$collate:=CP get collate 
CP SET COLLATE ($collate)

$duplex:=CP get duplex 
CP SET DUPLEX ($duplex)

CP GET PRINTER LIST (ARRAY;ARRAY)

$printer:=CP get default printer 
CP SET DEFAULT PRINTER ($printer)

$state:=CP get printer state ($printer)

$format:=CP XML Get page format 
CP XML SET PAGE FORMAT ($format)

$settings:=CP XML Get print settings 
CP XML SET PRINT SETTINGS ($settings)
```
