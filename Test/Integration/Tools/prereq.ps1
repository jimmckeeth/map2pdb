# map2pdb Integration Test Prerequisites Checker
# This script ensures that all tools required for the integration test suite are installed and accessible.

function Test-Command {
    param([string]$Command)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

Write-Host "Checking prerequisites for map2pdb integration tests..." -ForegroundColor Cyan

# 1. LLVM (Required for llvm-pdbutil)
if (Test-Command "llvm-pdbutil.exe") {
    Write-Host "[OK] LLVM (llvm-pdbutil) is installed." -ForegroundColor Green
} else {
    Write-Host "[MISSING] LLVM is not found. Attempting to install via winget..." -ForegroundColor Yellow
    winget install LLVM.LLVM
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to install LLVM via winget. Please install it manually from https://releases.llvm.org/" -ForegroundColor Red
    }
}

# 2. cvdump.exe (Should be in the Tools folder)
$ToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cvdump = Join-Path $ToolsDir "cvdump.exe"
if (Test-Path $cvdump) {
    Write-Host "[OK] cvdump.exe found in tools directory." -ForegroundColor Green
} else {
    Write-Host "[MISSING] cvdump.exe not found in $ToolsDir." -ForegroundColor Yellow
    Write-Host "Attempting to download cvdump.exe..." -ForegroundColor Gray
    Invoke-WebRequest -Uri "https://github.com/microsoft/microsoft-pdb/raw/refs/heads/master/cvdump/cvdump.exe" -OutFile $cvdump
    if (Test-Path $cvdump) {
        Write-Host "[OK] cvdump.exe downloaded successfully." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to download cvdump.exe. Please download it manually from https://github.com/microsoft/microsoft-pdb/tree/master/cvdump" -ForegroundColor Red
    }
}

# 3. Delphi Compilers (Check for dcc32 at least)
if (Test-Command "dcc32.exe") {
    Write-Host "[OK] Delphi compilers (dcc32) found in PATH." -ForegroundColor Green
} else {
    Write-Host "[WARNING] Delphi compilers not found in PATH." -ForegroundColor Yellow
    Write-Host "Ensure you have run 'rsvars.bat' or added the Delphi bin directory to your PATH." -ForegroundColor Gray
}

Write-Host "Prerequisite check complete." -ForegroundColor Cyan
