#
# Faria Tesseract OCR Installation Script for Windows
# Downloads and installs Tesseract OCR from UB-Mannheim releases
#
# Usage: .\install-tesseract.ps1 [-InstallDir DIR]
#
# Default install location: C:\Program Files\Tesseract-OCR
#

param(
    [string]$InstallDir = "C:\Program Files\Tesseract-OCR",
    [switch]$Help
)

# Configuration
$TesseractVersion = "5.5.0"
$TesseractDate = "20241111"

if ($Help) {
    Write-Host "Faria Tesseract OCR Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-tesseract.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: C:\Program Files\Tesseract-OCR)"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "This script downloads Tesseract from UB-Mannheim releases."
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria Tesseract OCR Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and $InstallDir -like "C:\Program Files*") {
    Write-Host "Warning: Installing to Program Files requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Please run this script as Administrator, or use -InstallDir to specify a different location." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Example: .\install-tesseract.ps1 -InstallDir `"$env:USERPROFILE\.faria\tesseract`"" -ForegroundColor Yellow
    exit 1
}

# Detect architecture
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

Write-Host "Detecting system..." -ForegroundColor Yellow
Write-Host "  OS: Windows"
Write-Host "  Architecture: $Arch"

# Check if Tesseract is already installed
$existingTesseract = Get-Command tesseract -ErrorAction SilentlyContinue
if ($existingTesseract) {
    $version = & tesseract --version 2>&1 | Select-Object -First 1
    Write-Host ""
    Write-Host "Tesseract is already installed:" -ForegroundColor Green
    Write-Host "  $version"
    Write-Host "  Path: $($existingTesseract.Source)"
    Write-Host ""
    $response = Read-Host "Do you want to reinstall/upgrade? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping installation." -ForegroundColor Green
        exit 0
    }
}

# Determine download URL
switch ($Arch) {
    "AMD64" {
        $TesseractAsset = "tesseract-ocr-w64-setup-$TesseractVersion.$TesseractDate.exe"
    }
    "x86" {
        $TesseractAsset = "tesseract-ocr-w32-setup-$TesseractVersion.$TesseractDate.exe"
    }
    default {
        Write-Host "Unsupported architecture: $Arch" -ForegroundColor Red
        exit 1
    }
}

$TesseractUrl = "https://github.com/UB-Mannheim/tesseract/releases/download/v$TesseractVersion/$TesseractAsset"

Write-Host ""
Write-Host "Installation configuration:" -ForegroundColor Yellow
Write-Host "  Install directory: $InstallDir"
Write-Host "  Tesseract version: $TesseractVersion"
Write-Host "  Installer: $TesseractAsset"
Write-Host ""

# Create temp directory
$TempDir = Join-Path $env:TEMP "faria-tesseract-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # Download Tesseract installer
    Write-Host "Downloading Tesseract installer..." -ForegroundColor Yellow
    Write-Host "  URL: $TesseractUrl"

    $InstallerPath = Join-Path $TempDir $TesseractAsset

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $TesseractUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = 'Continue'

    Write-Host "Download complete." -ForegroundColor Green
    Write-Host ""
    Write-Host "Running installer..." -ForegroundColor Yellow
    Write-Host "  Please follow the installer prompts."
    Write-Host "  Recommended: Install to default location and add to PATH."
    Write-Host ""

    # Run installer
    Start-Process -FilePath $InstallerPath -Wait

    # Verify installation
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    $tesseractCmd = Get-Command tesseract -ErrorAction SilentlyContinue
    if ($tesseractCmd) {
        $version = & tesseract --version 2>&1 | Select-Object -First 1
        Write-Host "  Tesseract: OK" -ForegroundColor Green
        Write-Host "    Version: $version"
        Write-Host "    Path: $($tesseractCmd.Source)"
    } else {
        Write-Host "  Tesseract: Not found in PATH" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Tesseract may have been installed but not added to PATH." -ForegroundColor Yellow
        Write-Host "Please add the installation directory to your PATH manually,"
        Write-Host "or restart your terminal/PowerShell session."
    }

    # Print success message
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tesseract OCR has been installed."
    Write-Host ""
    Write-Host "If tesseract is not found, you may need to:" -ForegroundColor Yellow
    Write-Host "  1. Add the installation directory to your PATH"
    Write-Host "  2. Restart your terminal/PowerShell session"
    Write-Host ""
    Write-Host "Default installation path: C:\Program Files\Tesseract-OCR"
    Write-Host ""

} finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
