#
# Faria OpenCV Installation Script for Windows
# Installs OpenCV for image processing
#
# Usage: .\install-opencv.ps1 [OPTIONS]
#
# This script downloads pre-built OpenCV binaries or uses Chocolatey.
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria OpenCV Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-opencv.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "This script installs OpenCV using pre-built binaries or Chocolatey."
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria OpenCV Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# OpenCV version
$OpenCVVersion = "4.10.0"
$OpenCVDir = "$InstallDir\lib\opencv"

# Detect architecture
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "Detecting system..." -ForegroundColor Yellow
Write-Host "  Architecture: $Arch"
Write-Host ""

# Check if OpenCV is already installed
$ExistingOpenCV = $null

# Check in install directory
if (Test-Path "$OpenCVDir\build\x64\vc16\bin\opencv_world*.dll") {
    $ExistingOpenCV = (Get-Item "$OpenCVDir\build\x64\vc16\bin\opencv_world*.dll" | Select-Object -First 1).Name
}

# Check via environment variable
if (-not $ExistingOpenCV -and $env:OPENCV_DIR) {
    if (Test-Path "$env:OPENCV_DIR\build\x64\vc16\bin\opencv_world*.dll") {
        $ExistingOpenCV = (Get-Item "$env:OPENCV_DIR\build\x64\vc16\bin\opencv_world*.dll" | Select-Object -First 1).Name
        Write-Host "OpenCV is already installed:" -ForegroundColor Green
        Write-Host "  Found: $ExistingOpenCV"
        Write-Host "  Location: $env:OPENCV_DIR"
        Write-Host ""
        $response = Read-Host "Do you want to reinstall? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Skipping installation." -ForegroundColor Green
            exit 0
        }
    }
}

if ($ExistingOpenCV -and -not $env:OPENCV_DIR) {
    Write-Host "OpenCV is already installed:" -ForegroundColor Green
    Write-Host "  Found: $ExistingOpenCV"
    Write-Host "  Location: $OpenCVDir"
    Write-Host ""
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping installation." -ForegroundColor Green
        exit 0
    }
}

# Create install directory
New-Item -ItemType Directory -Force -Path $OpenCVDir | Out-Null

# Try to install via Chocolatey first (if available)
$ChocoCmd = Get-Command choco -ErrorAction SilentlyContinue
if ($ChocoCmd) {
    Write-Host "Chocolatey detected. Installing OpenCV via Chocolatey..." -ForegroundColor Yellow
    Write-Host ""

    try {
        choco install opencv -y
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  Installation Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "OpenCV has been installed via Chocolatey."
            Write-Host "The OPENCV_DIR environment variable should be set automatically."
            Write-Host ""
            exit 0
        }
    } catch {
        Write-Host "Chocolatey installation failed, falling back to manual download..." -ForegroundColor Yellow
    }
}

# Download pre-built binaries
Write-Host "Downloading OpenCV $OpenCVVersion pre-built binaries..." -ForegroundColor Yellow
Write-Host ""

$OpenCVAsset = "opencv-$OpenCVVersion-windows.exe"
$OpenCVUrl = "https://github.com/opencv/opencv/releases/download/$OpenCVVersion/$OpenCVAsset"
$DownloadPath = "$env:TEMP\$OpenCVAsset"

try {
    Write-Host "  Downloading from: $OpenCVUrl"
    Write-Host "  This may take a few minutes (~250 MB)..."
    Write-Host ""

    # Use BITS for better download performance
    $BitsJob = Start-BitsTransfer -Source $OpenCVUrl -Destination $DownloadPath -ErrorAction Stop

    Write-Host "  Download complete." -ForegroundColor Green
    Write-Host ""
} catch {
    # Fallback to Invoke-WebRequest
    Write-Host "  BITS transfer failed, using WebRequest..." -ForegroundColor Yellow
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $OpenCVUrl -OutFile $DownloadPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        Write-Host "  Download complete." -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "  Download failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please download OpenCV manually from:" -ForegroundColor Yellow
        Write-Host "  https://opencv.org/releases/"
        Write-Host ""
        Write-Host "Or install via Chocolatey:" -ForegroundColor Yellow
        Write-Host "  choco install opencv"
        Write-Host ""
        exit 1
    }
}

# Extract the self-extracting archive
Write-Host "Extracting OpenCV..." -ForegroundColor Yellow

try {
    # The OpenCV Windows release is a self-extracting 7z archive
    # We can run it with -o to specify output directory
    $ExtractDir = "$env:TEMP\opencv-extract"
    if (Test-Path $ExtractDir) {
        Remove-Item -Recurse -Force $ExtractDir
    }

    # Run the self-extracting exe with silent extraction
    Start-Process -FilePath $DownloadPath -ArgumentList "-o`"$ExtractDir`"", "-y" -Wait -NoNewWindow

    # Move the extracted opencv folder to install directory
    $ExtractedFolder = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
    if ($ExtractedFolder) {
        if (Test-Path $OpenCVDir) {
            Remove-Item -Recurse -Force $OpenCVDir
        }
        Move-Item -Path $ExtractedFolder.FullName -Destination $OpenCVDir -Force
        Write-Host "  Extracted to: $OpenCVDir" -ForegroundColor Green
    } else {
        throw "Could not find extracted OpenCV folder"
    }

    # Cleanup
    Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $ExtractDir -ErrorAction SilentlyContinue

} catch {
    Write-Host "  Extraction failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "The OpenCV installer may require manual extraction." -ForegroundColor Yellow
    Write-Host "Please run: $DownloadPath"
    Write-Host "And extract to: $OpenCVDir"
    Write-Host ""
    exit 1
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow

$OpenCVDll = Get-ChildItem -Path "$OpenCVDir" -Recurse -Filter "opencv_world*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($OpenCVDll) {
    Write-Host "  OpenCV: OK" -ForegroundColor Green
    Write-Host "    Found: $($OpenCVDll.Name)"
    Write-Host "    Path: $($OpenCVDll.DirectoryName)"
} else {
    Write-Host "  OpenCV: Could not verify installation" -ForegroundColor Yellow
    Write-Host "    Please check $OpenCVDir manually"
}

# Print success message
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "OpenCV has been installed to: $OpenCVDir"
Write-Host ""
Write-Host "To use OpenCV, set the environment variable:" -ForegroundColor Yellow
Write-Host "  `$env:OPENCV_DIR = `"$OpenCVDir`""
Write-Host ""
Write-Host "Or add to your system PATH:" -ForegroundColor Yellow
if ($OpenCVDll) {
    Write-Host "  $($OpenCVDll.DirectoryName)"
}
Write-Host ""
