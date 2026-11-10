# Native ownership regression

On macOS with the existing Xcode command-line tools:

```sh
python3 tests/run_native_ownership.py --baseline
python3 tests/run_native_ownership.py
```

The same harness requires six named failures from immutable baseline
`aa8b727c9bf5f8ec19a106d556295f2712b0215d`, then requires every case to pass
against the working sources. It compiles every wrapper and the **full unchanged**
bundled `4DPluginAPI.c`, instruments them with ASan/UBSan, and intercepts only
`gCall4D`. The actual dispatcher is syntax-checked, never executed. Temporary
builds and baseline extraction are removed automatically. There is no signing,
packaging, publication, printer discovery, filesystem picture read or real
print command. Synthetic engine command IDs run only in the shim.

The six baseline failures are path double disposal; byte-loading retained
temporary leak; picture-copy UTF-16 heap overread; and grayscale, size and
thumbnail overwritten-empty-picture leaks. Fixed paths must balance all tracked
strings (including allocated empties), handles and picture reference counts.
Each runs with allocated/null empty strings and unchanged/replaced picture
outputs. Owning picture handoffs survive argument cleanup.

Text assertions cover ASCII, BMP, surrogate-pair supplementary text and empty
strings with exact lengths, contents and terminators. Charset conversion takes
byte capacities and returns payload **bytes**, excluding the terminator; the
zero-initialized caller buffer supplies termination. The shim uses CoreFoundation
for UTF conversion, not invented UTF-16 unit counts. Array tests exercise slot
zero, independent accepted transfers, copied borrowed inputs surviving original
owner clear, replacement, shrink, final clear and rejected type/index/data/null
descriptor destinations retaining caller ownership. Scalar wrappers copy before
owner disposal and use the content setter for parameters/returns.

LeakSanitizer is disabled on macOS; explicit allocation/reference registries
require zero balances instead. No allocation-failure behavior is certified.
In particular, normal array success tests do not certify the SDK resize
allocation-failure count corruption. This is not real 4D-host or Windows testing.

## Bounded audit inventory and contracts

Audited baseline: `aa8b727c9bf5f8ec19a106d556295f2712b0215d`.
Canonical guidance: `miyako/skills` file
`4d-skills/skills/4dplugin/SKILL.md`, revision
`e6b492fcb81e5e1a7f7db723594b420e63bf6eb9` (miyako/skills#71).

The only bundled SDK engine implementation is `4D Plugin API/4DPluginAPI.c`,
SHA-256 `4bb7227ee541a9419762f1c666cea3c708ba4ec0cd61a1ab714529a3271eb399`.
Its repository provenance is commit
`c9709c3cdf2918973e98dd6c9138270c72ee3861`; upstream release identity is
unverified. The v14 implementation/v13 header comments are not release evidence.
SDK internals, headers and exports are unchanged.

| Surface | Inventory and reachability | Ownership result |
| --- | --- | --- |
| Entry/dispatcher | `4DPlugin.cpp`, `4DPlugin.h`, prefix PCH | Actual switch cases 1-24 match all commands in both manifests. No hidden native entry implementation. SDK `FourDPackex` calls `PluginMain`. |
| Command metadata | Root `manifest.json` and bundle `Contents/Resources/manifest.json`; root/bundle constants and Info.plists | Both manifests match; command 17 is `CP GET PRINTER LIST(&Y;&Y)`. `&Y` proves capability, not safety. Scalar text commands 11, 12, 18-21, 22-24 also traced. |
| Scalar text | `C_TEXT.cpp/.h`, `C_TYPES.h` | Borrowed parameter descriptors become independent C++ strings. Parameter/return writes call engine-backed `PA_SetUnistring`, not descriptor transfer. NSString/CF copy/create owners released by callers; no confirmed lifetime defect in dispatched code. |
| Text arrays | `ARRAY_TEXT.cpp/.h` | Reads copy before owner mutation; writes create one independent allocation per slot and do not dispose after accepted transfer. Both printer output arrays are independently owned. No Poppler-style post-transfer disposal. |
| Picture wrappers | `C_PICTURE.cpp/.h`, CPicture and C_PICTURE | Compiled but no current dispatcher call. Fix single path-string owner, clear retained picture output argument, release `setBytes` temporary, avoid allocating values immediately overwritten by shallow setters, and convert bytes to UTF-16 units. Existing retained/borrowed handoff detachment preserved. |
| Pointer wrapper | `C_POINTER.cpp/.h` | Compiled, dispatcher-dormant. Getter metadata reconstruction uses filler/tag/index/type/name. Deferred: header says clear pointer getter result, but engine forwarding does not establish whether this metadata representation owns a value. No speculative clear or relabel. |
| Other scalars | `C_INTEGER`, `C_LONGINT`, `C_REAL`, `C_DATE`, `C_TIME`, each `.cpp/.h` | Numeric/date/time value copies, no string owners. |
| Other arrays | `ARRAY_BOOLEAN`, `ARRAY_INTEGER`, `ARRAY_LONGINT`, `ARRAY_REAL`, `ARRAY_DATE`, `ARRAY_TIME`, each `.cpp/.h` | Numeric/date/time copies and SDK array handles, no native string descriptors. |
| Blob wrappers | `C_BLOB.cpp/.h`, CBytes and C_BLOB | Binary copies and C++ text conversion buffers; no shallow PA string transfer. Unrelated blob buffer/index behavior not changed. |
| SDK surface | `4DPluginAPI.c/.h/.def`, `EntryPoints.h`, `PrivateTypes.h`, `PublicTypes.h`, `Flags.h`, license | Read actual used implementations, signatures, ABI/engine forwarding and exports. No object/collection getter API in this SDK and no JSON Parse, method execution or callback helper in first-party code. Command helper calls are synchronous picture commands with no owning function result. |
| Build/project | `Core Printing.xcodeproj/project.pbxproj`, workspace and scheme metadata, PCH | Target Sources includes SDK, dispatcher and all 16 wrapper `.cpp` files (9 scalar/blob/pointer/picture + 7 arrays), even dormant wrappers; API header includes every wrapper. No other tracked native source or alternate platform SDK. Windows bundle is prebuilt, not rebuilt. |

SDK lines 244-270 create/dispose/set string content; 3523-3657 construct
variables and may allocate empty string/picture values; 3826-3831 and 3852-3857
shallow-set string/picture descriptors. Lines 4266-4283 return a borrowed array
descriptor. Lines 4444-4460 dispose the old array string and transfer the
incoming descriptor only for Unicode arrays with non-null data, index
`0 <= i <= fNbElements`, and non-null descriptor pointer. Rejections do not
consume caller ownership. `PA_SetStringField` explicitly remains non-owning.
`PA_ReturnString` calls the content setter, unlike array transfer.
Picture duplicate lines 447-454 explicitly retain for flag 1. Charset conversion
lines 4775-4792 explicitly returns bytes. Command execution lines 5257-5290
passes parameter pointers synchronously; ownership is tracked per argument.

Deferred gaps: engine-only `PA_GetPictureData` format-string and application-path
output ownership are not established by this bundled SDK. The shim returns no
picture representations (checks the error before consuming text), so it makes
no assertion about that ambiguous ownership. No object/collection reference
contract is synthesized where the APIs are absent. SDK resize allocation-failure
count corruption is unrelated and remains unmodified. No real 4D host, Windows,
device state, print jobs or private documents were exercised.

Both existing workflows are manual `workflow_dispatch` only. The native
regression is an unsigned direct compile, not the release workflow or an Xcode
product build. Existing manual build/sign/notarize/package/publish and source
version workflows remain byte-for-byte unchanged.
