#
# Faria Tesseract OCR Installation Script for Windows
# Downloads and installs Tesseract OCR from UB-Mannheim releases (silent NSIS install)
#
# Usage: .\install-tesseract.ps1 [-InstallDir DIR]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Force,
    [switch]$Help
)

# Configuration
$TesseractVersion = "5.5.0"
$TesseractDate    = "20241111"
$TesseractDir     = "$InstallDir\tesseract"
$PkgConfigDir     = "C:\msys64\mingw64\lib\pkgconfig"

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

# Only x86_64 supported (UB-Mannheim ships AMD64 builds)
if ($Arch -ne "AMD64") {
    Write-Host "Error: Only x86_64 (AMD64) Windows is supported by the UB-Mannheim installer." -ForegroundColor Red
    exit 1
}

# ── Already installed? ────────────────────────────────────────────────────────
$tessExe = "$TesseractDir\tesseract.exe"
if ((Test-Path $tessExe) -and -not $Force) {
    $ver = (& $tessExe --version 2>&1 | Select-Object -First 1)
    Write-Host "Tesseract already installed: $ver" -ForegroundColor Green
    exit 0
}

$TesseractAsset = "tesseract-ocr-w64-setup-$TesseractVersion.$TesseractDate.exe"
$TesseractUrl   = "https://github.com/UB-Mannheim/tesseract/releases/download/v$TesseractVersion/$TesseractAsset"

Write-Host "Tesseract version: $TesseractVersion"
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
    # /S = silent, /D = destination (must be last arg, no quotes around path)
    Write-Host "Running silent installer to $TesseractDir..." -ForegroundColor Yellow
    Start-Process -FilePath $InstallerPath -ArgumentList "/S /D=$TesseractDir" -Wait -NoNewWindow
    Write-Host "  Installer finished." -ForegroundColor Green
    Write-Host ""

    # ── Set TESSDATA_PREFIX ───────────────────────────────────────────────────
    $TessdataPath = "$TesseractDir\tessdata"
    Set-UserEnv -Name "TESSDATA_PREFIX" -Value $TessdataPath
    Write-Host "TESSDATA_PREFIX set to: $TessdataPath" -ForegroundColor Green
    Write-Host ""

    # ── Register pkg-config .pc files ─────────────────────────────────────────
    # UB-Mannheim bundles .pc files under lib\pkgconfig\
    New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null

    $pcFiles = @("tesseract.pc", "lept.pc")
    foreach ($pc in $pcFiles) {
        $pcSrc = "$TesseractDir\lib\pkgconfig\$pc"
        if (Test-Path $pcSrc) {
            $pcDest = "$PkgConfigDir\$pc"
            Copy-Item $pcSrc $pcDest -Force
            # Fix prefix path
            $prefix = ($TesseractDir -replace '\\', '/').TrimEnd('/')
            (Get-Content $pcDest) -replace 'prefix=.*', "prefix=$prefix" |
                Set-Content $pcDest
            Write-Host "  $pc registered." -ForegroundColor Green
        } else {
            Write-Host "  Warning: $pcSrc not found — skipping $pc registration." -ForegroundColor Yellow
        }
    }
    Write-Host ""

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

    $pkgTest = Get-Command pkg-config -ErrorAction SilentlyContinue
    if ($pkgTest) {
        & pkg-config --exists tesseract lept 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  pkg-config --exists tesseract lept: OK" -ForegroundColor Green
        } else {
            Write-Host "  pkg-config --exists tesseract lept: FAILED (may need new shell session)" -ForegroundColor Yellow
        }
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
