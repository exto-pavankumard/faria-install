#
# Faria MuPDF Installation Script for Windows
# Installs MuPDF for PDF processing
#
# Usage: .\install-mupdf.ps1 [OPTIONS]
#
# This script downloads pre-built MuPDF binaries or uses Chocolatey.
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria MuPDF Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-mupdf.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "This script installs MuPDF using pre-built binaries or Chocolatey."
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria MuPDF Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# MuPDF version
$MuPDFVersion = "1.24.9"
$BinDir = "$InstallDir\bin"

# Detect architecture
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "Detecting system..." -ForegroundColor Yellow
Write-Host "  Architecture: $Arch"
Write-Host ""

# Check if MuPDF is already installed
$MuToolCmd = Get-Command mutool -ErrorAction SilentlyContinue
$MuToolPath = "$BinDir\mutool.exe"

if ($MuToolCmd) {
    $MuToolVersion = (& mutool -v 2>&1 | Select-Object -First 1)
    Write-Host "MuPDF is already installed:" -ForegroundColor Green
    Write-Host "  Version: $MuToolVersion"
    Write-Host "  Path: $($MuToolCmd.Source)"
    Write-Host ""
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping installation." -ForegroundColor Green
        exit 0
    }
} elseif (Test-Path $MuToolPath) {
    Write-Host "MuPDF is already installed:" -ForegroundColor Green
    Write-Host "  Path: $MuToolPath"
    Write-Host ""
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping installation." -ForegroundColor Green
        exit 0
    }
}

# Create directories
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# Try to install via Chocolatey first (if available)
$ChocoCmd = Get-Command choco -ErrorAction SilentlyContinue
if ($ChocoCmd) {
    Write-Host "Chocolatey detected. Installing MuPDF via Chocolatey..." -ForegroundColor Yellow
    Write-Host ""

    try {
        choco install mupdf -y
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  Installation Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "MuPDF has been installed via Chocolatey."
            Write-Host "The mutool command should now be available in PATH."
            Write-Host ""
            exit 0
        }
    } catch {
        Write-Host "Chocolatey installation failed, falling back to manual download..." -ForegroundColor Yellow
    }
}

# Determine download URL based on architecture
if ($Arch -eq "ARM64") {
    # ARM64 builds might not be available, try x64
    Write-Host "Note: ARM64 builds may not be available, using x64 version..." -ForegroundColor Yellow
    $MuPDFAsset = "mupdf-$MuPDFVersion-windows.zip"
} else {
    $MuPDFAsset = "mupdf-$MuPDFVersion-windows.zip"
}

# MuPDF official download URL
$MuPDFUrl = "https://mupdf.com/downloads/archive/$MuPDFAsset"
$DownloadPath = "$env:TEMP\$MuPDFAsset"

Write-Host "Downloading MuPDF $MuPDFVersion..." -ForegroundColor Yellow
Write-Host "  From: $MuPDFUrl"
Write-Host ""

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $MuPDFUrl -OutFile $DownloadPath -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "  Download complete." -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download MuPDF manually from:" -ForegroundColor Yellow
    Write-Host "  https://mupdf.com/downloads/index.html"
    Write-Host ""
    Write-Host "Or install via Chocolatey:" -ForegroundColor Yellow
    Write-Host "  choco install mupdf"
    Write-Host ""
    exit 1
}

# Extract the archive
Write-Host "Extracting MuPDF..." -ForegroundColor Yellow

try {
    $ExtractDir = "$env:TEMP\mupdf-extract"
    if (Test-Path $ExtractDir) {
        Remove-Item -Recurse -Force $ExtractDir
    }

    Expand-Archive -Path $DownloadPath -DestinationPath $ExtractDir -Force

    # Find the extracted folder
    $ExtractedFolder = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1

    if ($ExtractedFolder) {
        # Copy mutool.exe to bin directory
        $MuToolSource = Get-ChildItem -Path $ExtractedFolder.FullName -Recurse -Filter "mutool.exe" | Select-Object -First 1
        if ($MuToolSource) {
            Copy-Item -Path $MuToolSource.FullName -Destination $MuToolPath -Force
            Write-Host "  Installed mutool.exe to: $MuToolPath" -ForegroundColor Green
        } else {
            throw "Could not find mutool.exe in extracted archive"
        }

        # Also copy mudraw if available
        $MuDrawSource = Get-ChildItem -Path $ExtractedFolder.FullName -Recurse -Filter "mudraw.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($MuDrawSource) {
            Copy-Item -Path $MuDrawSource.FullName -Destination "$BinDir\mudraw.exe" -Force
        }

        # Copy mupdf-gl if available (GUI viewer)
        $MuPDFGLSource = Get-ChildItem -Path $ExtractedFolder.FullName -Recurse -Filter "mupdf-gl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($MuPDFGLSource) {
            Copy-Item -Path $MuPDFGLSource.FullName -Destination "$BinDir\mupdf-gl.exe" -Force
        }
    } else {
        throw "Could not find extracted MuPDF folder"
    }

    # Cleanup
    Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $ExtractDir -ErrorAction SilentlyContinue

} catch {
    Write-Host "  Extraction failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please extract manually and copy mutool.exe to:" -ForegroundColor Yellow
    Write-Host "  $BinDir"
    Write-Host ""
    exit 1
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow

if (Test-Path $MuToolPath) {
    # Try to get version
    try {
        $Version = (& $MuToolPath -v 2>&1 | Select-Object -First 1)
        Write-Host "  MuPDF: OK" -ForegroundColor Green
        Write-Host "    Version: $Version"
        Write-Host "    Path: $MuToolPath"
    } catch {
        Write-Host "  MuPDF: OK (installed)" -ForegroundColor Green
        Write-Host "    Path: $MuToolPath"
    }
} else {
    Write-Host "  MuPDF: Could not verify installation" -ForegroundColor Yellow
}

# Print success message
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "MuPDF has been installed to: $BinDir"
Write-Host ""
Write-Host "To use MuPDF commands globally, add to your PATH:" -ForegroundColor Yellow
Write-Host "  `$env:PATH += `";$BinDir`""
Write-Host ""
Write-Host "Or Faria will automatically detect it in: $InstallDir"
Write-Host ""
