# map2pdb Integration Test Orchestrator
# This script compiles test projects, converts them via map2pdb, and validates the output.

param(
    [string]$Config = "Debug",
    [string[]]$Platforms = @("Win32", "Win64", "Linux64"),
    [string]$PdbUtilPath = "C:\Program Files\LLVM\bin\llvm-pdbutil.exe",
    [string]$CvDumpPath = "$PSScriptRoot\Tools\cvdump.exe"
)

# Handle cases where $Platforms might be passed as a single comma-separated string
if ($Platforms.Count -eq 1 -and $Platforms[0] -like "*,*") {
    $Platforms = $Platforms[0].Split(",").Trim()
}

# Anchor paths to the script location
$RootDir = (Get-Item "$PSScriptRoot\..\..\..").FullName
$TestSamplesDir = Join-Path $PSScriptRoot "Samples"
$Map2PdbExe = Join-Path $RootDir "map2pdb\Bin\Win32\Release\map2pdb.exe"
$BuildScript = Join-Path $PSScriptRoot "Tools\DelphiBuildDPROJ.ps1"
$LogsDir = Join-Path $PSScriptRoot "Logs"

# Ensure Logs directory exists
if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir | Out-Null }

# Check for map2pdb.exe, build if missing
if (-not (Test-Path $Map2PdbExe)) {
    Write-Host ">>> map2pdb.exe not found. Attempting to build..." -ForegroundColor Yellow
    $Map2PdbDproj = Join-Path $RootDir "map2pdb\Source\map2pdb.dproj"
    if (Test-Path $Map2PdbDproj) {
        & $BuildScript -ProjectFile $Map2PdbDproj -Config Release -Platform Win32
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Map2PdbExe)) {
            Write-Host "[ERROR] Failed to build map2pdb.exe." -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] map2pdb.exe built successfully." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] map2pdb source project not found at $Map2PdbDproj." -ForegroundColor Red
        exit 1
    }
}

$GlobalResults = @()

# -----------------------------------------------------------------------------
# Function: Run-Validation
# -----------------------------------------------------------------------------
function Run-Validation {
    param([string]$PdbPath, [string]$LogBase)
    
    $ValidationResult = @{
        Pdb = $PdbPath
        Structural = $false
        Semantic = $false
    }

    # 1. llvm-pdbutil dump -summary
    Write-Host "  - Running llvm-pdbutil dump -summary..." -ForegroundColor Gray
    $LogFile = "$LogBase-pdbutil.log"
    & $PdbUtilPath dump -summary $PdbPath > $LogFile 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ValidationResult.Structural = $true
        Write-Host "    [OK] Structural validation passed." -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] Structural validation failed. See $LogFile" -ForegroundColor Red
    }

    # 2. cvdump
    if (Test-Path $CvDumpPath) {
        Write-Host "  - Running cvdump..." -ForegroundColor Gray
        $LogFile = "$LogBase-cvdump.log"
        & $CvDumpPath $PdbPath > $LogFile 2>&1
        if ($LASTEXITCODE -eq 0) {
            $ValidationResult.Semantic = $true
            Write-Host "    [OK] Semantic validation passed." -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] Semantic validation failed. See $LogFile" -ForegroundColor Red
        }
    }

    return $ValidationResult
}

# -----------------------------------------------------------------------------
# Main Loop
# -----------------------------------------------------------------------------
$ProjectDirs = Get-ChildItem -Path $TestSamplesDir -Directory

foreach ($ProjDir in $ProjectDirs) {
    $DprojFile = Get-ChildItem -Path $ProjDir.FullName -Filter "*.dproj" | Select-Object -First 1
    if ($null -eq $DprojFile) { continue }
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($DprojFile.Name)

    Write-Host "`n>>> Testing Project: $ProjectName" -ForegroundColor Cyan -BackgroundColor Black

    foreach ($Platform in $Platforms) {
        # Skip Linux64 for VCL projects (VCL is Windows only)
        if ($ProjectName -like "*VCL*" -and $Platform -eq "Linux64") {
            Write-Host "  Platform: $Platform ($Config) - SKIPPED (VCL is Windows only)" -ForegroundColor Gray
            continue
        }

        Write-Host "  Platform: $Platform ($Config)" -ForegroundColor Yellow
        $LogBase = Join-Path $LogsDir "$ProjectName-$Platform"
        
        # 1. Compile (Run in separate process to avoid environment pollution)
        Write-Host "  - Compiling..." -ForegroundColor Gray
        $BuildLog = "$LogBase-build.log"
        
        # We use a separate powershell.exe process so that rsvars.bat doesn't pollute our current session
        $BuildCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$BuildScript`" -ProjectFile `"$($DprojFile.FullName)`" -Config $Config -Platform $Platform"
        Write-Host "    Executing: $BuildCmd" -ForegroundColor Gray
        cmd /c "$BuildCmd > `"$BuildLog`" 2>&1"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [FAIL] Compilation failed. See $BuildLog" -ForegroundColor Red
            $GlobalResults += [PSCustomObject]@{ Project = $ProjectName; Platform = $Platform; Status = "Compile Fail" }
            continue
        }

        # 2. Find Map File (Check common locations)
        $MapFile = "$ProjectName.map"
        $PossiblePaths = @(
            (Join-Path $ProjDir.FullName "$Platform\$Config\$MapFile"),
            (Join-Path $ProjDir.FullName "$Config\$Platform\$MapFile"),
            (Join-Path $ProjDir.FullName $MapFile)
        )
        
        $MapPath = $null
        foreach ($P in $PossiblePaths) {
            if (Test-Path $P) { $MapPath = $P; break }
        }

        if ($null -eq $MapPath) {
            Write-Host "    [FAIL] Map file not found. Searched: $($PossiblePaths -join ', ')" -ForegroundColor Red
            $GlobalResults += [PSCustomObject]@{ Project = $ProjectName; Platform = $Platform; Status = "Map Missing" }
            continue
        }

        # 3. Convert to PDB
        Write-Host "  - Converting to PDB..." -ForegroundColor Gray
        $ConvertLog = "$LogBase-convert.log"
        & $Map2PdbExe -v $MapPath > $ConvertLog 2>&1
        
        $PdbPath = [System.IO.Path]::ChangeExtension($MapPath, ".pdb")
        if (-not (Test-Path $PdbPath)) {
            Write-Host "    [FAIL] Conversion failed. See $ConvertLog" -ForegroundColor Red
            $GlobalResults += [PSCustomObject]@{ Project = $ProjectName; Platform = $Platform; Status = "Convert Fail" }
            continue
        }
        Write-Host "    [OK] PDB generated." -ForegroundColor Green

        # 4. Validate
        $Val = Run-Validation -PdbPath $PdbPath -LogBase $LogBase
        
        $Status = "PASS"
        if (-not $Val.Structural) { $Status = "FAIL" }
        if ((Test-Path $CvDumpPath) -and (-not $Val.Semantic)) { $Status = "FAIL" }

        $GlobalResults += [PSCustomObject]@{ Project = $ProjectName; Platform = $Platform; Status = $Status }
    }
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
Write-Host "`n" + ("=" * 60)
Write-Host "INTEGRATION TEST SUMMARY" -ForegroundColor White
Write-Host ("=" * 60)
$GlobalResults | Format-Table -AutoSize
Write-Host ("=" * 60)

$Failed = $GlobalResults | Where-Object { $_.Status -notin @("PASS", "SKIPPED") }
if ($Failed) {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All integration tests passed!" -ForegroundColor Green
    exit 0
}
