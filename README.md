4d-plugin-core-printing
=======================

Read and change 4D's current print settings on macOS through the Core Printing API (`PMPageFormat` / `PMPrintSettings`), list the printers known to the system, and save or restore the whole print configuration as XML text. The plugin works on the same page format and print settings objects that 4D itself uses for `PRINT SETTINGS`, `PRINT RECORD`, `Print form` and the other print commands, so a value you set here is what the next 4D print job uses. Results are `Longint`, `Real` and `Text` values, plus two `Text` arrays for the printer list.

## Maintainer release workflow

**Bump version** is manual: select the source branch in Actions and choose `patch`,
`minor`, or `major`. It checks out the immutable dispatch commit, validates the
coordinated source metadata, and pushes exactly one source-only commit to that
branch. It creates no tag and starts no Build. The branch must still advertise
the selected SHA; a missing/nonexecutable pre-push guard or any intervening
advance, rewind, deletion, or same-result update fails closed. Pushes are
nonforce and disable following tags, including repository-level defaults.

**Build** is a separate manual workflow with **zero inputs**. Select the branch
or commit to build in Actions; every checkout uses the dispatch's `github.sha`.
The strict source `X.Y.Z` determines the new `vX.Y.Z` tag and the
`Core Printing-X.Y.Z.zip` / `Core Printing-X.Y.Z.dmg` assets. Publication is
serialized across branches without cancelling a running build. It checks remote
tags and all authenticated release-list pages (including drafts) both before
building and after the universal build, verification, signing, notarization, and
DMG stapling have succeeded. API/auth/network/malformed-response failures are
errors, not proof of absence.

Source authority is coordinated `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` (three configurations each), root `Info.plist`, and
`English.lproj/InfoPlist.strings`. The modernization commit `c9709c3` introduced
both project keys at `14.3.0`, matching the root plist; its Bump header explicitly
promised coordination of both keys despite updating only one in its old body.
This migration keeps `14.3.0` and repairs only the stale localized `1.0` metadata.
Applicable literal version fields co-bump; supported Xcode references, absent
`CFBundleVersion`, BOM, line endings, and file modes are preserved. Committed
prebuilt bundle metadata/binaries, 4D database files, localization counters,
manifest/schema versions, and the bundled 4D SDK are not source-release fields.

Publication is create-only: POST a new exact-SHA Git ref, verify it remotely,
POST a new public non-prerelease release with the original empty-notes policy,
then upload assets separately to the returned new release ID. Existing tags or
draft/published releases are never reused, even for the same SHA. There is no
DELETE, PATCH, overwrite, clobber, rollback, or automatic retry.

**Recovery:** a failure may retain the tag, release, and already uploaded assets.
Inspect the failed step and the remote state, including drafts, before deciding
on a manual recovery. Do not blindly rerun Build for the same version: retained
state intentionally blocks it. Maintainers must explicitly resolve any partial
publication outside these workflows or choose a new source version via Bump.

Native behavior is unchanged: macOS uses the committed 4D SDK, Carbon/Core
Printing headers, and system Cocoa, AppKit, and CoreGraphics frameworks, targets macOS `11.5`, and builds both
`arm64` and `x86_64`. The existing prebuilt-library and resource checks remain.
The committed Windows64 `.4DX` ships as-is; there is no Windows build or new
branch restriction. Modern Xcode compatibility of the legacy SDK/Core Printing
APIs and validity of the prebuilt Windows binary remain native caveats, not
reasons to bypass build/signing/notary/staple gates. Certificate and notary secret
names and packaging/resources are unchanged.

Local workflow regressions (no native build or signing):
`python3 -B -m unittest discover -s .github/tests -v` and
`actionlint .github/workflows/*.yml`.

| Command | Returns | Purpose |
|:--|:--|:--|
| [CP Get orientation](#cp-get-orientation) | `Longint` | Page orientation of the current page format |
| [CP SET ORIENTATION](#cp-set-orientation) | | Set the page orientation |
| [CP Get scale](#cp-get-scale) | `Real` | Scaling percentage of the current page format |
| [CP SET SCALE](#cp-set-scale) | | Set the scaling percentage |
| [CP Get copies](#cp-get-copies) | `Longint` | Number of copies |
| [CP SET COPIES](#cp-set-copies) | | Set the number of copies |
| [CP Get first page](#cp-get-first-page) | `Longint` | First page of the page range |
| [CP SET FIRST PAGE](#cp-set-first-page) | | Set the first page of the page range |
| [CP get last page](#cp-get-last-page) | `Longint` | Last page of the page range |
| [CP SET LAST PAGE](#cp-set-last-page) | | Set the last page of the page range |
| [CP get job name](#cp-get-job-name) | `Text` | Print job name |
| [CP SET JOB NAME](#cp-set-job-name) | | Set the print job name |
| [CP get duplex](#cp-get-duplex) | `Longint` | Duplex (two-sided) mode |
| [CP SET DUPLEX](#cp-set-duplex) | | Set the duplex mode |
| [CP get collate](#cp-get-collate) | `Longint` | Collation on (1) or off (0) |
| [CP SET COLLATE](#cp-set-collate) | | Turn collation on or off |
| [CP GET PRINTER LIST](#cp-get-printer-list) | 2 `Text` arrays | IDs and display names of the system's printers |
| [CP get default printer](#cp-get-default-printer) | `Text` | ID of the system default printer |
| [CP SET DEFAULT PRINTER](#cp-set-default-printer) | | Change the system default printer |
| [CP get printer state](#cp-get-printer-state) | `Longint` | Idle / processing / stopped state of a printer |
| [CP XML Get page format](#cp-xml-get-page-format) | `Text` | Current page format as XML |
| [CP XML Get print settings](#cp-xml-get-print-settings) | `Text` | Current print settings as XML |
| [CP XML SET PAGE FORMAT](#cp-xml-set-page-format) | | Replace the current page format from XML |
| [CP XML SET PRINT SETTINGS](#cp-xml-set-print-settings) | | Replace the current print settings from XML |

**Platforms:** macOS only (Apple silicon and Intel, macOS 11.5 or later). The Windows bundle slot holds a stub with no commands implemented.

---

## Requirements & platform notes

- **macOS only.** The commands call the macOS Core Printing framework. The bundle contains a `Windows64` binary, but there is no Windows implementation: don't call these commands on Windows.
- **The commands act on 4D's own print objects.** Each call asks 4D for its current `PMPageFormat` (page setup: orientation, scale, paper) or `PMPrintSettings` (print dialog: copies, page range, duplex, collation, job name), opening a printer session if none is open. A change is seen by the next 4D print job and by dialogs 4D opens later (for example `PRINT SETTINGS`). It is not saved anywhere else.
- **Failure is silent.** No command raises a 4D error. If 4D has no page format or print settings to give (for example no printer is installed), or the underlying call fails, getters return `0`, `0.0` or `""`, and setters do nothing. See [Error handling & troubleshooting](#error-handling--troubleshooting).
- **Values are not validated.** Setters pass your value to Core Printing as is. Use the constants listed in each command; out-of-range values may be stored and then rejected or ignored by the printer driver.
- **Printers are identified by ID, not by display name.** [CP GET PRINTER LIST](#cp-get-printer-list) returns both. [CP get default printer](#cp-get-default-printer), [CP SET DEFAULT PRINTER](#cp-set-default-printer) and [CP get printer state](#cp-get-printer-state) use the ID (the CUPS queue name, for example `HP_OfficeJet_Pro_9010_series`).
- Every parameter is mandatory: no command has an optional form.

---

## CP Get orientation

### Syntax

```
orientation := CP Get orientation
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Longint` | Orientation of the current page format, or `0` on failure |

| Value | Meaning |
|:--|:--|
| `1` | Portrait |
| `2` | Landscape |
| `3` | Reverse portrait |
| `4` | Reverse landscape |

### Description

Returns the orientation of 4D's current page format. Apple notes that current drivers treat reverse portrait and reverse landscape as portrait and landscape.

### Example

From the plugin's README:

```4d
$orientation:=CP Get orientation 
CP SET ORIENTATION ($orientation)
```

```4d
If (CP Get orientation=2)
	ALERT("The next print job is set to landscape.")
End if
```

---

## CP SET ORIENTATION

### Syntax

```
CP SET ORIENTATION ( orientation )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `orientation` | `Longint` | `1` portrait, `2` landscape, `3` reverse portrait, `4` reverse landscape |

### Description

Sets the orientation of 4D's current page format. The value is not checked.

### Example

```4d
CP SET ORIENTATION (2)  // landscape
```

---

## CP Get scale

### Syntax

```
scale := CP Get scale
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Real` | Scaling of the current page format, in percent (`100` = actual size), or `0` on failure |

### Description

Returns the scaling percentage of 4D's current page format.

### Example

From the plugin's README:

```4d
$scale:=CP Get scale 
CP SET SCALE ($scale)
```

---

## CP SET SCALE

### Syntax

```
CP SET SCALE ( scale )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `scale` | `Real` | Scaling in percent, for example `50` for half size |

### Description

Sets the scaling percentage of 4D's current page format. The value is not checked: pass a positive number.

### Example

```4d
CP SET SCALE (75)
```

---

## CP Get copies

### Syntax

```
copies := CP Get copies
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Longint` | Number of copies in the current print settings, or `0` on failure |

### Example

From the plugin's README:

```4d
$copies:=CP Get copies 
CP SET COPIES ($copies)
```

---

## CP SET COPIES

### Syntax

```
CP SET COPIES ( copies )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `copies` | `Longint` | Number of copies, `1` or more |

### Description

Sets the number of copies in 4D's current print settings. The value is not checked: a negative number is converted to a very large unsigned count, so pass `1` or more.

### Example

```4d
CP SET COPIES (3)
```

---

## CP Get first page

### Syntax

```
page := CP Get first page
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Longint` | First page of the page range (`1` by default), or `0` on failure |

### Example

From the plugin's README:

```4d
$page:=CP Get first page 
CP SET FIRST PAGE ($page)
```

---

## CP SET FIRST PAGE

### Syntax

```
CP SET FIRST PAGE ( page )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `page` | `Longint` | First page to print, `1` or more |

### Example

```4d
CP SET FIRST PAGE (2)
CP SET LAST PAGE (5)
```

---

## CP get last page

### Syntax

```
page := CP get last page
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Longint` | Last page of the page range, or `0` on failure |

### Description

When the range is "all pages", Core Printing reports a very large last page. In a standalone test with default print settings this was `2147483647` (the largest `Longint`); the value 4D's own settings report has not been checked.

### Example

From the plugin's README:

```4d
$page:=CP get last page 
CP SET LAST PAGE ($page)
```

---

## CP SET LAST PAGE

### Syntax

```
CP SET LAST PAGE ( page )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `page` | `Longint` | Last page to print, greater than or equal to the first page |

### Example

```4d
CP SET FIRST PAGE (1)
CP SET LAST PAGE (1)  // first page only
```

---

## CP get job name

### Syntax

```
name := CP get job name
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Text` | Job name in the current print settings, or `""` if none is set |

### Description

The job name is the title shown in the macOS print queue. It is empty until someone sets it.

### Example

From the plugin's README:

```4d
$name:=CP get job name 
CP SET JOB NAME ($name)
```

---

## CP SET JOB NAME

### Syntax

```
CP SET JOB NAME ( name )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `name` | `Text` | Job name to show in the print queue |

### Example

```4d
CP SET JOB NAME ("Invoices "+String(Current date))
```

---

## CP get duplex

### Syntax

```
mode := CP get duplex
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Longint` | Duplex mode, or `0` if none is set or on failure |

| Value | Meaning |
|:--|:--|
| `1` | One-sided |
| `2` | Two-sided, long-edge binding (no tumble) |
| `3` | Two-sided, short-edge binding (tumble) |
| `4` | One-sided, tumbled |

### Description

Returns `0` when the print settings hold no duplex value yet (Core Printing reports an error in that case, which the plugin turns into `0`).

### Example

From the plugin's README:

```4d
$duplex:=CP get duplex 
CP SET DUPLEX ($duplex)
```

---

## CP SET DUPLEX

### Syntax

```
CP SET DUPLEX ( mode )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `mode` | `Longint` | `1` one-sided, `2` long-edge, `3` short-edge, `4` one-sided tumbled |

### Description

Sets the duplex mode in 4D's current print settings. A printer without a duplex unit ignores it.

### Example

```4d
CP SET DUPLEX (2)  // two-sided, long-edge binding
```

---

## CP get collate

### Syntax

```
collate := CP get collate
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Longint` | `1` if copies are collated, `0` if not or on failure |

### Example

From the plugin's README:

```4d
$collate:=CP get collate 
CP SET COLLATE ($collate)
```

---

## CP SET COLLATE

### Syntax

```
CP SET COLLATE ( collate )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `collate` | `Longint` | `1` (any non-zero value) to collate copies, `0` not to |

### Description

Since the review fixes, any non-zero value turns collation on. Before, only the low 8 bits of the value were used, so `256` meant "off".

### Example

```4d
CP SET COPIES (2)
CP SET COLLATE (1)
```

---

## CP GET PRINTER LIST

### Syntax

```
CP GET PRINTER LIST ( ids ; names )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `ids` | `Text array` | Receives the printer IDs |
| `names` | `Text array` | Receives the printer display names, in the same order |

### Description

Fills both arrays with the printers macOS knows about (local and shared queues, including fax queues). Element `n` of `ids` and element `n` of `names` describe the same printer. If the list can't be read, both arrays come back with no elements.

Since the review fixes, a printer with no ID or no name gets `""` in that array, so the two arrays always have the same size. Before, the element was skipped and the arrays could fall out of step.

### Example

From the plugin's README:

```4d
CP GET PRINTER LIST (ARRAY;ARRAY)
```

```4d
ARRAY TEXT($ids;0)
ARRAY TEXT($names;0)
CP GET PRINTER LIST ($ids;$names)
For ($i;1;Size of array($ids))
	$state:=CP get printer state ($ids{$i})
	// $names{$i} is the name to show the user, $ids{$i} the value to pass to the other commands
End for
```

---

## CP get default printer

### Syntax

```
id := CP get default printer
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Text` | ID of the system default printer, or `""` if there is none |

### Example

From the plugin's README:

```4d
$printer:=CP get default printer 
CP SET DEFAULT PRINTER ($printer)
```

---

## CP SET DEFAULT PRINTER

### Syntax

```
CP SET DEFAULT PRINTER ( id )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `id` | `Text` | Printer ID, as returned in the first array of [CP GET PRINTER LIST](#cp-get-printer-list) |

### Description

Makes the printer with this ID the **system-wide default printer** for the current macOS user. This affects every application, not only 4D, and lasts after 4D quits. The ID must match exactly (case-sensitive). If no printer has this ID, nothing happens.

It does not change the printer in 4D's current print settings directly. Whether 4D picks up the new default before its next print job has not been checked; test it with your 4D version.

### Example

```4d
$previous:=CP get default printer
CP SET DEFAULT PRINTER ("HP_OfficeJet_Pro_9010_series")
// ... print ...
CP SET DEFAULT PRINTER ($previous)
```

---

## CP get printer state

### Syntax

```
state := CP get printer state ( id )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `id` | `Text` | Printer ID, as returned in the first array of [CP GET PRINTER LIST](#cp-get-printer-list) |
| Result | `Longint` | `3` idle, `4` processing, `5` stopped, or `0` if the printer isn't found |

### Description

Since the review fixes, `0` is also returned when the state can't be read. Before, the result could be a random value in that case.

### Example

From the plugin's README:

```4d
$state:=CP get printer state ($printer)
```

```4d
Case of 
	: ($state=3)
		// idle
	: ($state=4)
		// printing
	: ($state=5)
		ALERT("The printer queue is stopped.")
	Else 
		ALERT("Unknown printer.")
End case 
```

---

## CP XML Get page format

### Syntax

```
xml := CP XML Get page format
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Text` | 4D's current page format as an XML property list, or `""` on failure |

### Description

Serializes the whole page format (paper, orientation, scale, margins…) to a property list in Core Printing's minimal XML format. Store the text and pass it later to [CP XML SET PAGE FORMAT](#cp-xml-set-page-format) to restore the same page setup. The keys are Apple's and may change between macOS versions; treat the text as opaque.

### Example

From the plugin's README:

```4d
$format:=CP XML Get page format 
CP XML SET PAGE FORMAT ($format)
```

---

## CP XML Get print settings

### Syntax

```
xml := CP XML Get print settings
```

| Parameter | Type | Description |
|:--|:--|:--|
| Result | `Text` | 4D's current print settings as an XML property list, or `""` on failure |

### Description

Same as [CP XML Get page format](#cp-xml-get-page-format), for the print settings (copies, page range, duplex, collation, job name, and driver-specific options). Restore it with [CP XML SET PRINT SETTINGS](#cp-xml-set-print-settings).

### Example

From the plugin's README:

```4d
$settings:=CP XML Get print settings 
CP XML SET PRINT SETTINGS ($settings)
```

## Native development

See [the device-free ownership regression and audit inventory](tests/README.md)
for unsigned macOS checks using the actual wrappers and bundled SDK.

---

## CP XML SET PAGE FORMAT

### Syntax

```
CP XML SET PAGE FORMAT ( xml )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `xml` | `Text` | Text returned earlier by [CP XML Get page format](#cp-xml-get-page-format) |

### Description

Rebuilds a page format from the XML and copies it over 4D's current page format. If the text isn't a valid page format, nothing changes. Before the review fixes, invalid text could crash 4D.

### Example

```4d
// save the page setup the user chose
PRINT SETTINGS
$format:=CP XML Get page format
// ... later, restore it without showing the dialog
CP XML SET PAGE FORMAT ($format)
```

---

## CP XML SET PRINT SETTINGS

### Syntax

```
CP XML SET PRINT SETTINGS ( xml )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `xml` | `Text` | Text returned earlier by [CP XML Get print settings](#cp-xml-get-print-settings) |

### Description

Rebuilds print settings from the XML and copies them over 4D's current print settings. If the text isn't valid print settings, nothing changes. Before the review fixes, invalid text could crash 4D.

### Example

```4d
$settings:=CP XML Get print settings
CP XML SET PRINT SETTINGS ($settings)
```

---

## Error handling & troubleshooting

- **No error is ever raised.** Getters return `0`, `0.0` or `""` and setters do nothing when 4D has no page format or print settings, or when Core Printing refuses the call. Read the value back with the matching getter if you need to confirm a change.
- **`0` from a getter can mean "not set".** [CP get duplex](#cp-get-duplex) returns `0` until a duplex mode is stored, and [CP get job name](#cp-get-job-name) returns `""` until a job name is set.
- **Setters don't check ranges.** A negative copy count or scale is stored as is and may produce an unexpected job. Use the values in each command's table.
- **Use the printer ID, not the name.** [CP SET DEFAULT PRINTER](#cp-set-default-printer) and [CP get printer state](#cp-get-printer-state) compare against the ID (first array of [CP GET PRINTER LIST](#cp-get-printer-list)), case-sensitively. A display name returns `0` or does nothing.
- **Changing the default printer is system-wide.** [CP SET DEFAULT PRINTER](#cp-set-default-printer) changes the default for every application of the current macOS user, and the change persists. Restore the previous ID when you're done.
- **Changes are not saved with the database.** Use the XML commands to store and restore a configuration.
- **XML from another Mac or printer.** Restoring XML saved on another Mac or for another printer may be partly ignored by the driver. If the XML can't be parsed at all, nothing changes.
- **Windows.** The commands are not implemented on Windows.

---

## Quick reference

```4d
$orientation:=CP Get orientation
CP SET ORIENTATION (2)
$scale:=CP Get scale
CP SET SCALE (100)

CP SET COPIES (2)
CP SET COLLATE (1)
CP SET FIRST PAGE (1)
CP SET LAST PAGE (3)
CP SET DUPLEX (2)
CP SET JOB NAME ("Report")

ARRAY TEXT($ids;0)
ARRAY TEXT($names;0)
CP GET PRINTER LIST ($ids;$names)
$default:=CP get default printer
$state:=CP get printer state ($default)

$format:=CP XML Get page format
$settings:=CP XML Get print settings
CP XML SET PAGE FORMAT ($format)
CP XML SET PRINT SETTINGS ($settings)
```
