#
# Faria Tesseract OCR Installation Script for Windows
#
# Primary path  : MSYS2/MinGW64 (reliable in CI and any machine with msys2/setup-msys2)
# Fallback path : UB-Mannheim NSIS installer (for machines without MSYS2)
#
# Usage: .\install-tesseract.ps1 [-InstallDir DIR]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Force,
    [switch]$Help
)

# Configuration
# UB-Mannheim releases embed the build date in the version string (e.g. 5.4.0.20240606).
$TesseractVersion = "5.4.0.20240606"
$TesseractDir     = "$InstallDir\tesseract"

if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot '_common.ps1')
}

$PkgConfigDir = Get-MSYS2PkgConfigDir

if ($Help) {
    Write-Host "Faria Tesseract OCR Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-tesseract.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Force           Reinstall even if already present"
    Write-Host "  -Help            Show this help message"
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria Tesseract OCR Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "Architecture: $Arch"
Write-Host "Install directory: $TesseractDir"
Write-Host ""

if ($Arch -ne "AMD64") {
    Write-Host "Error: Only x86_64 (AMD64) Windows is supported." -ForegroundColor Red
    exit 1
}

# ── Already installed? ────────────────────────────────────────────────────────
$tessExe = "$TesseractDir\tesseract.exe"
if ((Test-Path $tessExe) -and -not $Force) {
    $ver = (& $tessExe --version 2>&1 | Select-Object -First 1)
    Write-Host "Tesseract already installed: $ver" -ForegroundColor Green
    exit 0
}

# ── Helper: register .pc files with MSYS2 pkg-config ─────────────────────────
function Register-TesseractPkgConfig {
    param([string]$SrcPkgConfigDir)
    New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null
    foreach ($pc in @("tesseract.pc", "lept.pc")) {
        $src = "$SrcPkgConfigDir\$pc"
        if (Test-Path $src) {
            $dst = "$PkgConfigDir\$pc"
            # Skip when MSYS2 source dir IS the target dir (dynamic path detection resolves to same location)
            if ([System.IO.Path]::GetFullPath($src).ToLower() -eq [System.IO.Path]::GetFullPath($dst).ToLower()) {
                Write-Host "  $pc already in pkgconfig dir (source = destination)." -ForegroundColor Green
                continue
            }
            Copy-Item $src $dst -Force
            Write-Host "  $pc registered in MSYS2 pkgconfig dir." -ForegroundColor Green
        }
    }
}

# ── PRIMARY: MSYS2/MinGW64 Tesseract ─────────────────────────────────────────
# When msys2/setup-msys2@v2 pre-installs mingw-w64-x86_64-tesseract-ocr the
# UB-Mannheim NSIS installer (which hangs in headless CI) is never needed.
$msys2Base    = "C:\msys64\mingw64"
$msys2TessExe = "$msys2Base\bin\tesseract.exe"

# Also search PATH for tesseract (handles non-default MSYS2 install paths).
# setup-msys2@v2 adds the MSYS2 bin dir to PATH, so Get-Command is reliable.
if (-not (Test-Path $msys2TessExe)) {
    $tessCmd = Get-Command tesseract -ErrorAction SilentlyContinue
    if ($tessCmd -and ($tessCmd.Source -match "mingw64|msys64")) {
        $msys2TessExe = $tessCmd.Source
        $msys2Base    = Split-Path -Parent (Split-Path -Parent $tessCmd.Source)
        Write-Host "MSYS2 Tesseract found on PATH: $msys2TessExe" -ForegroundColor Yellow
    }
}

if (Test-Path $msys2TessExe) {
    Write-Host "MSYS2 Tesseract detected — populating $TesseractDir from MSYS2..." -ForegroundColor Yellow
    Write-Host ""

    New-Item -ItemType Directory -Force -Path $TesseractDir | Out-Null

    # tesseract.exe
    Copy-Item $msys2TessExe "$TesseractDir\tesseract.exe" -Force
    Write-Host "  tesseract.exe: copied" -ForegroundColor Green

    # tessdata — copy .traineddata files
    $msys2Tessdata = "$msys2Base\share\tessdata"
    $TessdataPath  = "$TesseractDir\tessdata"
    if (Test-Path $msys2Tessdata) {
        New-Item -ItemType Directory -Force -Path $TessdataPath | Out-Null
        Get-ChildItem $msys2Tessdata -Filter "*.traineddata" |
            Copy-Item -Destination $TessdataPath -Force
        Write-Host "  tessdata: copied" -ForegroundColor Green
    }

    # Headers: tesseract/ and leptonica/
    New-Item -ItemType Directory -Force -Path "$TesseractDir\include" | Out-Null
    foreach ($hdr in @("tesseract", "leptonica")) {
        $src = "$msys2Base\include\$hdr"
        if (Test-Path $src) {
            Copy-Item $src "$TesseractDir\include\$hdr" -Recurse -Force
            Write-Host "  include/${hdr}: copied" -ForegroundColor Green
        }
    }

    # Import libs needed for CGO linking
    New-Item -ItemType Directory -Force -Path "$TesseractDir\lib" | Out-Null
    foreach ($pattern in @("libtesseract*", "liblept*")) {
        Get-ChildItem "$msys2Base\lib" -Filter $pattern -ErrorAction SilentlyContinue |
            Copy-Item -Destination "$TesseractDir\lib\" -Force
    }
    Write-Host "  lib: import libs copied" -ForegroundColor Green

    # pkg-config .pc files — copy to $TesseractDir\lib\pkgconfig AND MSYS2 dir
    $msys2PkgConfig = "$msys2Base\lib\pkgconfig"
    New-Item -ItemType Directory -Force -Path "$TesseractDir\lib\pkgconfig" | Out-Null
    foreach ($pc in @("tesseract.pc", "lept.pc")) {
        $src = "$msys2PkgConfig\$pc"
        if (Test-Path $src) {
            Copy-Item $src "$TesseractDir\lib\pkgconfig\$pc" -Force
        }
    }
    Register-TesseractPkgConfig -SrcPkgConfigDir $msys2PkgConfig

    # Set TESSDATA_PREFIX
    Set-UserEnv -Name "TESSDATA_PREFIX" -Value $TessdataPath
    Write-Host "TESSDATA_PREFIX set to: $TessdataPath" -ForegroundColor Green
    Write-Host ""

    # Verify
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    $ver = (& "$TesseractDir\tesseract.exe" --version 2>&1 | Select-Object -First 1)
    Write-Host "  Tesseract: $ver" -ForegroundColor Green

    if (Test-Path "$TesseractDir\include\leptonica") {
        Write-Host "  Leptonica headers: OK" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Tesseract Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Source: MSYS2 ($msys2Base)"
    Write-Host "Installed to: $TesseractDir"
    Write-Host "TESSDATA_PREFIX: $TessdataPath"
    Write-Host ""
    exit 0
}

# ── FALLBACK: UB-Mannheim NSIS installer ─────────────────────────────────────
Write-Host "MSYS2 not found — using UB-Mannheim NSIS installer..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Tesseract version: $TesseractVersion"

$TesseractAsset = "tesseract-ocr-w64-setup-$TesseractVersion.exe"
$TesseractUrl   = "https://github.com/UB-Mannheim/tesseract/releases/download/v$TesseractVersion/$TesseractAsset"
Write-Host "Installer: $TesseractAsset"
Write-Host ""

$TempDir = Join-Path $env:TEMP "faria-tesseract-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # ── Download installer ────────────────────────────────────────────────────
    Write-Host "Downloading Tesseract installer..." -ForegroundColor Yellow
    Write-Host "  URL: $TesseractUrl"
    $InstallerPath = Join-Path $TempDir $TesseractAsset
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $TesseractUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "  Download complete." -ForegroundColor Green
    Write-Host ""

    # ── Silent NSIS install ───────────────────────────────────────────────────
    # /S = silent mode, /D = destination (must be last arg, no quotes around path)
    Write-Host "Running silent installer to $TesseractDir..." -ForegroundColor Yellow
    $proc = Start-Process -FilePath $InstallerPath `
                          -ArgumentList @("/S", "/D=$TesseractDir") `
                          -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Installer exited with code $($proc.ExitCode)"
    }
    Write-Host "  Installer finished." -ForegroundColor Green
    Write-Host ""

    # ── Set TESSDATA_PREFIX ───────────────────────────────────────────────────
    $TessdataPath = "$TesseractDir\tessdata"
    Set-UserEnv -Name "TESSDATA_PREFIX" -Value $TessdataPath
    Write-Host "TESSDATA_PREFIX set to: $TessdataPath" -ForegroundColor Green
    Write-Host ""

    # ── Register pkg-config .pc files ─────────────────────────────────────────
    Register-TesseractPkgConfig -SrcPkgConfigDir "$TesseractDir\lib\pkgconfig"

    # ── Verify ────────────────────────────────────────────────────────────────
    Write-Host "Verifying installation..." -ForegroundColor Yellow

    if (Test-Path $tessExe) {
        $ver = (& $tessExe --version 2>&1 | Select-Object -First 1)
        Write-Host "  Tesseract: $ver" -ForegroundColor Green
    } else {
        Write-Host "  tesseract.exe: NOT FOUND at $tessExe" -ForegroundColor Red
        exit 1
    }

    if (Test-Path "$TesseractDir\include\leptonica") {
        Write-Host "  Leptonica headers: OK" -ForegroundColor Green
    } else {
        Write-Host "  Leptonica headers: not found (CGO may not work)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Tesseract Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed to: $TesseractDir"
    Write-Host "TESSDATA_PREFIX: $TessdataPath"
    Write-Host ""

} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
