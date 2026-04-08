# Integration Testing Methodology for map2pdb

## Overview
This document defines an exhaustive integration testing strategy for `map2pdb`. The objective is to verify that `map2pdb` correctly converts Delphi-generated `.map` files into Microsoft-compatible `.pdb` files across all supported target platforms and language features, with zero data loss.

## Pre-requisites & Setup
To reproduce and run this test suite, the following must be available in the environment:
- **Delphi Command-Line Compilers:** Ensure `dcc32`, `dcc64`, `dcclinux64`, `dccaarm`, etc. are accessible via the system `PATH` (typically loaded via `rsvars.bat`).
- **LLVM PDB Utils:** `llvm-pdbutil.exe` must be installed (usually via the LLVM Windows installer) and accessible. Verified default path: `C:\Program Files\LLVM\bin\llvm-pdbutil.exe`.
- **Microsoft DIA / cvdump:** `cvdump.exe` must be downloaded from the [Microsoft PDB repository](https://github.com/microsoft/microsoft-pdb/tree/master/cvdump) and placed in a known tools directory.
- **PowerShell:** Version 5.1+ or PowerShell Core to execute the orchestration scripts.

## Target Platforms
- **Win32** (dcc32)
- **Win64** (dcc64)
- **Linux64** (dcclinux64) - Tests GNU/ELF map parsing
- **Android / Android64** (dccaarm / dccaarm64)
- *(Optional)* macOS / iOS for total coverage

## The Testing Pipeline
The integration test suite is automated via a PowerShell script and follows this pipeline for each test project:

1. **Compilation:** Compile the project using the target platform's Delphi compiler with detailed map files and full debug information enabled (`-GD`, `-$D+`, `-B`).
2. **Conversion:** Execute `map2pdb` to convert the generated `.map` file to `.pdb`.
3. **Validation (Structural):** Run `llvm-pdbutil verify` on the `.pdb` to catch low-level structural corruption.
4. **Validation (Semantic):** Run `cvdump` on the `.pdb` to ensure Microsoft DIA toolchain compatibility (used by WinDbg, VTune).
5. **Content Verification (Round-Trip):** Run `llvm-pdbutil dump -symbols -lines` to extract the symbols and lines from the `.pdb`. A validation script parses this dump and cross-references it with the original `.map` file to ensure 100% representation (no dropped symbols or lines).

## Test Project Archetypes
To thoroughly exercise the conversion process, the suite must include projects with diverse characteristics:
1. **Minimal Console App:** Baseline testing, core RTL only.
2. **Complex Generics:** Stress-tests symbol demangling and exceedingly long symbol names (e.g., heavy use of `System.Generics.Collections`).
3. **VCL / FMX GUI Apps:** Large map files, resources, and complex unit initialization sections.
4. **Shared Library (DLL/SO):** Tests exported symbols and entry points.
5. **Overloads & Inlining:** Tests duplicate names, mangled names, and line number mappings for heavily inlined code.
6. **Packages (BPLs):** Tests projects compiled with runtime packages and boundaries.

## Suggestions for Improvement
- **Automated Tool Fetching:** Integrate the downloading of `cvdump.exe` directly into the test setup script to reduce manual setup.
- **CI/CD Integration:** Run this pipeline automatically on GitHub Actions (using self-hosted runners with Delphi installed) whenever a change is made.
- **Fuzzing / Corrupt Maps:** Include malformed `.map` files in the pipeline to ensure `map2pdb` warns and exits gracefully rather than crashing.