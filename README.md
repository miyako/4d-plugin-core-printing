4d-plugin-core-printing
=======================

##Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|🆗|🆗|🚫|🚫|

Commands
---

```c
// --- Page Format
CP_Get_orientation
CP_SET_ORIENTATION
CP_Get_scale
CP_SET_SCALE

// --- Print Settings
CP_Get_copies
CP_SET_COPIES
CP_Get_first_page
CP_SET_FIRST_PAGE
CP_get_last_page
CP_SET_LAST_PAGE
CP_get_job_name
CP_SET_JOB_NAME
CP_get_duplex
CP_SET_DUPLEX
CP_get_collate
CP_SET_COLLATE

// --- Printer
CP_GET_PRINTER_LIST
CP_get_default_printer
CP_SET_DEFAULT_PRINTER
CP_get_printer_state

// --- XML
CP_XML_Get_page_format
CP_XML_Get_print_settings
CP_XML_SET_PAGE_FORMAT
CP_XML_SET_PRINT_SETTINGS
```

Examples
---

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
