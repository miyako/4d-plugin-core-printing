#!/usr/bin/env python3
"""Device-free macOS regression against actual sources and full bundled SDK."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "aa8b727c9bf5f8ec19a106d556295f2712b0215d"
CASES = ("path", "bytes", "copy", "gray", "size", "thumbnail", "arrays", "scalars")


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true",
                        help="Require named defects in immutable baseline to fail")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="core-printing-ownership-") as directory:
        work = Path(directory)
        source = ROOT
        if args.baseline:
            source = work / "baseline"
            source.mkdir()
            archive = subprocess.run(
                ["git", "archive", BASELINE, "4D Plugin API", "4DPlugin.cpp",
                 "4DPlugin.h"], cwd=ROOT, check=True, stdout=subprocess.PIPE,
            ).stdout
            subprocess.run(["tar", "-x", "-C", str(source)], input=archive, check=True)
        api = source / "4D Plugin API"
        sdk_hash = hashlib.sha256((api / "4DPluginAPI.c").read_bytes()).hexdigest()
        if sdk_hash != "4bb7227ee541a9419762f1c666cea3c708ba4ec0cd61a1ab714529a3271eb399":
            raise SystemExit("Regression requires the full unchanged bundled SDK")
        common = ["xcrun", "clang++", "-std=c++11", "-x", "objective-c++",
                  "-include", "Carbon/Carbon.h", "-include", "Cocoa/Cocoa.h",
                  "-I", str(api), "-I", str(api / "Classes"),
                  "-Wno-deprecated-declarations", "-Wno-deprecated-register",
                  "-Wno-parentheses", "-Wno-unused-value",
                  "-fsanitize=address,undefined", "-fno-omit-frame-pointer", "-g"]
        # Compile the real dispatcher without executing any printing command.
        subprocess.run(common + ["-fsyntax-only", str(source / "4DPlugin.cpp")], check=True)
        binary = work / "ownership"
        subprocess.run(common + [str(api / "4DPluginAPI.c")] +
                       [str(p) for p in sorted((api / "Classes").glob("*.cpp"))] +
                       [str(ROOT / "tests/native_ownership.mm"), "-framework", "Cocoa",
                        "-framework", "Carbon", "-o", str(binary)], check=True)
        env = dict(os.environ, ASAN_OPTIONS="detect_leaks=0:halt_on_error=1",
                   UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1")
        for case in CASES:
            result = subprocess.run([str(binary), case], env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            print(result.stdout, end="")
            if args.baseline and case not in ("arrays", "scalars"):
                if result.returncode == 0:
                    raise SystemExit(f"Baseline unexpectedly passed {case}")
                marker = ("double disposal" if case == "path" else
                          "AddressSanitizer: heap-buffer-overflow" if case == "copy" else
                          "all picture references released")
                if marker not in result.stdout:
                    raise SystemExit(f"Baseline failed {case} for an unexpected reason")
                print(f"EXPECTED BASELINE FAILURE: {case}")
            elif result.returncode:
                raise SystemExit(f"Failed {case}: exit {result.returncode}")


if __name__ == "__main__":
    run()
